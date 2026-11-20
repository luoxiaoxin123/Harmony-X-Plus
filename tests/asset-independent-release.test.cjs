const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function load(relativePath, dependencies = {}) {
  const filename = 'entry/src/main/ets/' + relativePath + '.ets';
  const output = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const exports = {};
  new Function('require', 'exports', output)(name => {
    assert.ok(Object.hasOwn(dependencies, name), 'unexpected dependency ' + name);
    return dependencies[name];
  }, exports);
  return exports;
}

test('post length uses X weights for CJK, normalized accents, emoji and link boundaries', () => {
  const { weightedPostLength, STANDARD_POST_CHARACTERS } = load('utils/PostCharacterCount', {
    './XPostTextPatterns': load('utils/XPostTextPatterns')
  });
  assert.equal(weightedPostLength('鸿'.repeat(140)), STANDARD_POST_CHARACTERS);
  assert.equal(weightedPostLength('鸿'.repeat(140) + '!'), 281);
  assert.equal(weightedPostLength('cafe\u0301 👨‍👩‍👧‍👦 👍🏽'), 10);
  assert.equal(weightedPostLength('example.com xyz.def'), 31);
  assert.equal(weightedPostLength('https://example.com/path?q=test.'), 24);
  assert.equal(weightedPostLength('hello@example.com'), 17);
  assert.equal(weightedPostLength('@alice 你好 @bob', 'alice'), 9);
  assert.equal(weightedPostLength('@alice_2 hi', 'alice'), 11);
});

test('composer drafts migrate legacy fields and restore mixed attachment order and ALT', () => {
  const storage = new Map([
    ['draft_compose_updated_at', 1],
    ['draft_compose_text', 'old draft'],
    ['draft_compose_images', '["a.jpg","b.jpg"]'],
    ['draft_compose_gif', 'c.gif']
  ]);
  const pref = {
    getSync: (key, fallback) => storage.get(key) ?? fallback,
    putSync: (key, value) => storage.set(key, value),
    flushSync() {}
  };
  const media = load('models/ComposerMedia');
  const { ComposerDraftStore } = load('services/ComposerDraftStore', {
    '../models/ComposerMedia': media,
    '../models/ComposerOptions': { ComposerOptions: class { static restore() { return {}; } } },
    '@kit.ArkData': { preferences: { getPreferencesSync: () => pref } }
  });
  const drafts = new ComposerDraftStore();
  const draft = drafts.load({}, 'compose');
  assert.deepEqual(draft.media.map(item => [item.uri, item.type]), [['a.jpg', 1], ['b.jpg', 1], ['c.gif', 2]]);
  draft.media = [new media.ComposerMedia('intro.mp4', 3), ...draft.media];
  draft.media[1].alt = 'A tree near the window';
  draft.media = media.addComposerMedia(draft.media, new media.ComposerMedia('other.gif', 2));
  drafts.save({}, 'compose', draft);
  assert.deepEqual(drafts.load({}, 'compose').media.map(item => [item.uri, item.alt]), [
    ['intro.mp4', ''], ['a.jpg', 'A tree near the window'], ['b.jpg', ''], ['c.gif', '']
  ]);
  drafts.clear({}, 'compose');
  assert.deepEqual(drafts.load({}, 'compose').media, []);
});

test('photo filename preserves configured field order and original gallery index', () => {
  const { photoFilenameTitle } = load('services/PhotoFilenameStore', { '@kit.ArkData': {} });
  assert.equal(photoFilenameTitle(['index', 'author', 'code', 'date', 'post'], '2026-11-20', '@alice', 7,
    'https://pbs.twimg.com/media/test%3Acode.jpg?format=jpg&name=orig', '123'),
  'HarmonyX-8-alice-test_code-2026-11-20-123');
  assert.equal(photoFilenameTitle(['author', 'code', 'post'], '', '', -1, 'file:///local.jpg', ''), '');
});
