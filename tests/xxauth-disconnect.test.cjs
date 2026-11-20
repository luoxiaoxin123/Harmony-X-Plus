const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const { load } = require('./post-card-fixture.cjs');

test('application source has no XXAuth network client or endpoint', () => {
  const root = path.resolve(__dirname, '../entry/src/main/ets');
  const forbidden = /xxauth\.com|XXAuthService|XXAuthPopupHost|\/entitlements\/download\//i;
  for (const file of fs.readdirSync(root, { recursive: true })) {
    if (!/\.(ets|ts|js)$/.test(file)) { continue; }
    assert.doesNotMatch(fs.readFileSync(path.join(root, file), 'utf8'), forbidden, file);
  }
});

test('previously installed chat decorations are previewed and applied offline per account', () => {
  const context = { filesDir: '/app' };
  const directory = context.filesDir + '/chat_decorations';
  const packagePath = directory + '/paper-frame/1.0';
  const files = new Set([packagePath + '/frame.png', packagePath + '/bubble.png']);
  const alice = new Map([
    ['decoration:installed:paper-frame', JSON.stringify({
      id: 'paper-frame', version: '1.0', frameUri: 'https://example.test/obsolete',
      framePath: '/old-install/frame.png', bubbleTextColor: '#FFFFFF', sliceLeft: 6
    })],
    ['decoration:installed:incomplete', JSON.stringify({ id: 'incomplete', version: '1.0' })],
    ['decoration:installed:invalid', JSON.stringify({ id: 'invalid', version: '..' })]
  ]);
  let preferences = alice;
  const storage = new Map();
  const { chatDecorationService: service, CHAT_DECORATION_REVISION_KEY: revision } = load(
    'services/ChatDecorationService', {
      '@kit.CoreFileKit': {
        fileIo: { listFileSync: folder => {
          assert.equal(folder, directory);
          return ['paper-frame', 'staging', 'incomplete', 'invalid'];
        }, accessSync: name => files.has(name) },
        fileUri: { getUriFromPath: name => 'file://' + name }
      },
      './XChatActions': {
        xChatActions: { localString: (_context, key, fallback) => preferences.get(key) ?? fallback,
          saveLocal: (_context, key, value) => preferences.set(key, value) }
      }
    }, storage);

  const items = service.listInstalled(context);
  assert.deepEqual(items.map(item => item.id), ['paper-frame']);
  assert.equal(items[0].frameUri, 'file://' + packagePath + '/frame.png');
  assert.equal(service.apply(context, items[0], 'frame').frameId, 'paper-frame');
  assert.equal(service.apply(context, items[0], 'bubble').bubbleTextColor, '#FFFFFF');
  assert.equal(service.selection(context).sliceLeft, 6);
  assert.equal(service.clear(context, 'bubble').bubbleId, '');
  assert.equal(storage.get(revision), 3);

  preferences = new Map();
  assert.deepEqual(service.listInstalled(context), []);
  assert.equal(service.selection(context).frameId, '');
});
