const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function extract(file, type, names) {
  const source = fs.readFileSync(`entry/src/main/ets/${file}.ets`, 'utf8').replace(`struct ${type}`, `class ${type}`);
  const parsed = ts.createSourceFile(file + '.ts', source, ts.ScriptTarget.Latest, true);
  const target = parsed.statements.find(n => ts.isClassDeclaration(n) && n.name.text === type);
  return names.map(name => target.members.find(n => n.name?.getText(parsed) === name).getText(parsed)).join('\n');
}
function compile(body, deps) {
  const output = ts.transpileModule(body, { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText;
  const result = {};
  new Function('exports', ...Object.keys(deps), output)(result, ...Object.values(deps));
  return result;
}
function stackFixture() {
  let paths = [];
  const calls = [];
  return {
    calls, get paths() { return paths; }, size: () => paths.length,
    getAllPathName: () => paths.map(p => p.name), getParamByIndex: i => paths[i]?.param,
    pushPath(path, animated) { calls.push(['push', animated]); paths.push(path); },
    replacePath(path, animated) { calls.push(['replace', animated]); paths[paths.length - 1] = path; },
    popToIndex(index, animated) { calls.push(['popTo', index, animated]); paths = paths.slice(0, index + 1); },
    pop() { calls.push(['pop']); paths.pop(); }, clear() { calls.push(['clear']); paths = []; }
  };
}
const nav = compile(fs.readFileSync('entry/src/main/ets/utils/NavigationGuard.ets', 'utf8'), {}).NavigationGuard;
const branch = compile(fs.readFileSync('entry/src/main/ets/utils/RootContentNavigation.ets', 'utf8')
  .replace(/^import .*;\s*/m, ''), { NavigationGuard: nav }).RootContentNavigation;

test('reopening a conversation renders the cached messages before starting the network refresh', () => {
  const cached = { messages: [{ id: 'old' }, { id: 'new' }], oldest: 'old', hasMore: true };
  const Conversation = compile(`export class Conversation {
    ${extract('pages/DmConversation', 'DmConversationPage', ['aboutToAppear', 'restoreWebHistory'])}
  }`, {
    photoAccessHelper: { PhotoViewMIMETypes: { IMAGE_TYPE: 'image' } }, PhotoSource: { ALL: 'all' }, RECENT_PHOTO_MAX_AGE: 1000,
    KeyboardAvoidMode: { RESIZE: 1 }, getContext: () => ({}), chatMediaOutbox: { subscribe() {} },
    chatBackgroundStore: { load() {} }, chatDecorationService: { selection() {} },
    xPrivateClient: { isSignedIn: () => true, hasChatOAuth: () => false },
    xPrivateStore: { load: () => ({ cacheIdentity: () => 'account-a' }) },
    xChatService: { cachedWebHistory: () => cached, webHistoryGeneration: () => 3 }
  }).Conversation;
  const page = new Conversation();
  let loaded = false;
  Object.assign(page, {
    recentPhotoOptions: {}, loading: true, observeKeyboard() {}, readRoute() { this.conversationId = '100-200'; },
    getUIContext: () => ({ setKeyboardAvoidMode() {} }), syncOutbox() {}, loadContact() {},
    load(reset) {
      assert.equal(reset, true);
      assert.deepEqual(this.messages, cached.messages);
      assert.notEqual(this.messages, cached.messages);
      assert.equal(this.webOldest, 'old');
      assert.equal(this.hasMore, true);
      assert.equal(this.loading, false);
      loaded = true;
    }
  });
  page.aboutToAppear();
  assert.equal(loaded, true);
});

test('chat rows use one visible timeline for message times, grouping and search', () => {
  let merges = 0;
  const Conversation = compile(`export class Conversation {
    ${extract('pages/DmConversation', 'DmConversationPage', ['updateVisibleMessages', 'showTime', 'groupEnd', 'mediaSend'])}
  }`, {
    ChatMediaOutbox: { timeline(messages) { merges++; return messages.slice(); } }
  }).Conversation;
  const messages = [
    { id: 'a', text: 'one', timestampMs: 10, outgoing: true },
    { id: 'b', text: 'two', timestampMs: 20, outgoing: true },
    { id: 'c', text: 'one again', timestampMs: 300500, outgoing: true }
  ];
  const page = Object.assign(new Conversation(), {
    messages, searchQuery: '', mediaSends: [{ id: 'b' }, { id: 'pending' }]
  });
  page.updateVisibleMessages();
  assert.deepEqual(messages.map((_row, index) => page.showTime(index)), [true, false, true]);
  assert.deepEqual(messages.map((_row, index) => page.groupEnd(index)), [false, true, true]);
  assert.equal(merges, 1);
  assert.equal(page.mediaSend('b'), undefined);
  assert.equal(page.mediaSend('pending').id, 'pending');
  page.searchQuery = ' ONE ';
  page.updateVisibleMessages();
  assert.deepEqual(page.visibleTimeline.map(row => row.id), ['a', 'c']);
  assert.equal(page.showTime(1), true);
  assert.equal(merges, 2);
});

test('repost attribution opens the person who reposted and leaves the original post author intact', () => {
  const Card = compile(`export class Card { ${extract('components/TweetCard', 'TweetCard', ['openRepostAuthor'])} }`, {}).Card;
  const card = new Card();
  const original = { id: '100', username: 'author' };
  const reposter = { id: '200', username: 'reposter' };
  card.tweet = { id: 'post', author: original, repostAuthor: reposter };
  const opened = [];
  card.onAuthorTapped = post => opened.push(post.author);
  card.openRepostAuthor();
  assert.deepEqual(opened, [reposter]);
  assert.equal(card.tweet.author, original);
});

test('desktop conversation selection replaces one detail branch and never empties the roster', () => {
  const Root = compile(`export class Root { ${extract('pages/Index', 'Index', ['openConversation'])} }`, {
    RootContentNavigation: branch, promptAction: {}, $r: v => v
  }).Root;
  const root = new Root(), stack = stackFixture(), modes = [];
  Object.assign(root, { navPathStack: stack, isDesktopLayout: () => true,
    updateNavigationMode() { modes.push(this.desktopRoute); }, syncDesktopRoute() {} });
  const row = id => ({ conversationId: id, from: 'peer' });
  root.openConversation(row('100-200'));
  assert.deepEqual(modes, ['DmConversation'], 'split mode is established before the first push');
  root.openConversation(row('100-300'));
  assert.equal(stack.size(), 1);
  assert.equal(stack.paths[0].param.conversationId, '100-300');
  assert.deepEqual(stack.calls.map(c => c[0]), ['push', 'replace']);
  root.openConversation(row('100-300'));
  assert.equal(stack.calls.length, 2, 'clicking the selected peer keeps its instance');
  stack.pushPath({ name: 'DmInfo' });
  root.openConversation(row('100-200'));
  assert.equal(stack.size(), 1);
  assert.equal(stack.paths[0].param.conversationId, '100-200');
  assert.ok(!stack.calls.some(c => c[0] === 'clear'));
});

function infoFixture() {
  let unlocked = false, pending, deletes = 0, confirms = 0, fail = false, valid = true;
  const stack = stackFixture();
  stack.pushPath({ name: 'DmConversation', param: { conversationId: '100-200' } });
  stack.pushPath({ name: 'DmInfo' });
  const service = { isUnlocked: () => unlocked,
    async deleteConversation() { deletes++; if (fail) throw Error('network failure'); }, setConversationInfo() {} };
  const Info = compile(`export class Info { ${extract('pages/DmInfo', 'DmInfoPage', ['act', 'closeDeletedConversation'])} }`, {
    xChatService: service, promptAction: { async showDialog() { confirms++; return { index: 1 }; } }, $r: v => v
  }).Info;
  const page = new Info();
  Object.assign(page, { route: { conversationId: '100-200' }, busy: false, error: '',
    valid: () => valid, text: r => r, pageStack: stack, chatUnlockRequest: { request: action => { pending = action; } } });
  return { page, stack, unlock: () => { unlocked = true; }, pending: () => pending,
    state: () => ({ deletes, confirms }), fail: () => { fail = true; }, invalidate: () => { valid = false; } };
}
test('cold-start info deletion waits for PIN recovery, then confirms and closes the deleted branch', async () => {
  const f = infoFixture();
  await f.page.act('delete');
  assert.deepEqual(f.state(), { deletes: 0, confirms: 0 });
  assert.equal(f.stack.size(), 2);
  f.unlock(); f.pending()();
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(f.state(), { deletes: 1, confirms: 1 });
  assert.equal(f.stack.size(), 0);
});
test('cancelled recovery or a departed info page never performs deferred deletion', async () => {
  const f = infoFixture();
  await f.page.act('delete');
  assert.equal(f.state().deletes, 0);
  f.unlock(); f.invalidate(); f.pending()();
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(f.state(), { deletes: 0, confirms: 0 });
  assert.equal(f.stack.size(), 2);
});
test('failed server deletion retains the open chat and releases the busy state', async () => {
  const f = infoFixture(); f.unlock(); f.fail();
  await f.page.act('delete');
  assert.equal(f.stack.size(), 2);
  assert.equal(f.page.busy, false);
  assert.equal(f.page.error, 'app.string.chat_action_failed');
});
test('identity recovery resumes an inbox action without requiring another inbox fetch', async () => {
  let prepare = 0, unlock = 0;
  const Root = compile(`export class Root { ${extract('pages/Index', 'Index', ['unlockChat'])} }`, {
    xChatService: { async prepare() { prepare++; }, async unlock() { unlock++; } },
    xPrivateStore: { load: () => ({ cacheIdentity: () => 'a' }) }, getContext: () => ({})
  }).Root;
  const root = new Root();
  Object.assign(root, { chatUnlocking: false, chatUnlockAttempts: -1, showChatUnlock: true,
    chatUnlockAccount: 'a', loadMessages() { throw Error('inbox rate limited'); }, text: r => r });
  await root.unlockChat('0000');
  assert.equal(prepare, 1); assert.equal(unlock, 1);
  assert.equal(root.chatUnlockSucceeded, true); assert.equal(root.showChatUnlock, false);
  assert.equal(root.chatUnlocking, false);
});
