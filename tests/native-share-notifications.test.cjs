const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function load(source, modules = {}, globals = {}) {
  const module = { exports: {} };
  const code = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText;
  new Function('require', 'module', 'exports', ...Object.keys(globals), code)(id => {
    assert.ok(modules[id], 'unexpected module ' + id); return modules[id];
  }, module, module.exports, ...Object.values(globals));
  return module.exports;
}

const composerMedia = load(fs.readFileSync('entry/src/main/ets/models/ComposerMedia.ets', 'utf8'));

function methods(file, name, names) {
  const source = fs.readFileSync(file, 'utf8').replace('struct ' + name, 'class ' + name);
  const parsed = ts.createSourceFile(file + '.ts', source, ts.ScriptTarget.Latest, true);
  const cls = parsed.statements.find(node => ts.isClassDeclaration(node) && node.name.text === name);
  return 'export class Subject {\n' + names.map(name => {
    const member = cls.members.find(node => node.name?.getText(parsed) === name);
    assert.ok(member, name); return member.getText(parsed);
  }).join('\n') + '\n}';
}

function delivery() {
  let active = 'account-a', now = 0, fail = false, onAgent = () => {};
  let previews = false;
  const published = [], storage = new Map(), agents = [];
  const pref = { getSync: (key, fallback) => storage.get(key) ?? fallback,
    putSync: (key, value) => storage.set(key, value), flushSync() {} };
  const { NotificationDeliveryService } = load(fs.readFileSync('entry/src/main/ets/services/NotificationDeliveryService.ets', 'utf8'), {
    '@kit.AbilityKit': { wantAgent: { OperationType: { START_ABILITY: 1 }, WantAgentFlags: { UPDATE_PRESENT_FLAG: 1 },
      getWantAgent: async info => { agents.push(info); onAgent(); return info; } } },
    '@kit.BasicServicesKit': { intelligentScene: { isDoNotDisturbEnabled: async () => false } },
    '@kit.ArkData': { preferences: { getPreferencesSync: () => pref } },
    '@kit.NotificationKit': { notificationManager: { isNotificationEnabled: async () => true, setBadgeNumber: async () => {},
      addSlot: async () => {}, SlotType: { SOCIAL_COMMUNICATION: 1 }, ContentType: { NOTIFICATION_CONTENT_BASIC_TEXT: 1 },
      publish: async request => { if (fail) { fail = false; throw new Error('offline'); } published.push({ request, time: now }); } } },
    '@ohos.hilog': { default: { warn() {} } }, './AccountStore': { accountStore: { activeId: () => active } },
    './NotificationSettingsStore': { notificationSettingsStore: { loadMessagePreview: () => previews } }
  }, { Date: { now: () => now }, $r: key => key, setTimeout: (fn, delay) => { now += delay; queueMicrotask(fn); } });
  const service = new NotificationDeliveryService();
  const publishMessages = service.publishUnreadMessages.bind(service);
  service.publishUnreadMessages = (context, ...args) => publishMessages({
    ...context, resourceManager: { getStringSync: () => 'New message' }
  }, ...args);
  return { service, published, agents, storage, preview: () => { previews = true; },
    switch: value => { active = value; }, fail: () => { fail = true; }, agent: fn => { onAgent = fn; } };
}
const notice = id => ({ id, unread: true, authorName: 'Author', text: 'body', postText: '', time: '', targetPostId: 'post', authorUsername: 'author' });
const message = id => ({ id, unread: 1, from: 'Sender', preview: 'hello', time: '', conversationId: 'conversation', username: 'sender' });

test('social and DM batches share throttling and concurrent refreshes publish each row once', async () => {
  const f = delivery();
  const counts = await Promise.all([
    f.service.publishUnread({}, [notice('n1'), notice('n2')], 2, 3, false),
    f.service.publishUnreadMessages({}, [message('m1')], 1, 3, false),
    f.service.publishUnread({}, [notice('n1'), notice('n2')], 2, 3, false)
  ]);
  assert.deepEqual(counts, [2, 1, 0]);
  assert.deepEqual(f.published.map(row => row.time), [0, 250, 500]);
  assert.ok(f.agents.every(agent => agent.wants[0].parameters.accountId === 'account-a'));
});

test('chat notifications omit message text by default and use decrypted previews when opted in', async () => {
  const f = delivery();
  await f.service.publishUnreadMessages({}, [message('private')], 1, 1, false);
  f.preview();
  await f.service.publishUnreadMessages({}, [message('visible')], 1, 1, false);
  await f.service.publishUnreadMessages({}, [{ ...message('locked'), preview: '' }], 1, 1, false);
  assert.deepEqual(f.published.map(row => row.request.content.normal.text), ['New message', 'hello', 'New message']);
});

test('deduplication and notification identities are separated by account', async () => {
  const f = delivery();
  await f.service.publishUnread({}, [notice('same')], 1, 1, false);
  f.switch('account-b');
  await f.service.publishUnread({}, [notice('same')], 1, 1, false);
  assert.equal(f.published.length, 2);
  assert.notEqual(f.published[0].request.id, f.published[1].request.id);
  assert.notEqual(f.published[0].request.groupName, f.published[1].request.groupName);
  assert.equal(f.agents[1].wants[0].parameters.accountId, 'account-b');
});

test('switching accounts during WantAgent creation stops the old batch', async () => {
  const f = delivery();
  f.agent(() => f.switch('account-b'));
  assert.equal(await f.service.publishUnread({}, [notice('1'), notice('2')], 2, 2, false), 0);
  assert.equal(f.published.length, 0);
});

test('failed publications remain retryable without blocking later rows or batches', async () => {
  const f = delivery(); f.fail();
  assert.equal(await f.service.publishUnread({}, [notice('1'), notice('2')], 2, 2, false), 1);
  assert.equal(await f.service.publishUnread({}, [notice('1'), notice('2')], 2, 2, false), 1);
  assert.deepEqual(f.published.map(row => row.request.appMessageId), ['account-a:2', 'account-a:1']);
});

test('messages read while queued are skipped before the system publish', async () => {
  const f = delivery();
  f.agent(() => f.service.markUnreadMessagesSeen({}, [message('1')]));
  assert.equal(await f.service.publishUnreadMessages({}, [message('1')], 1, 1, false), 0);
  assert.equal(f.published.length, 0);
});

test('the next incoming message in an existing thread gets its own notification', async () => {
  const f = delivery();
  const first = { ...message('100-200'), conversationId: '100:200', latestSequenceId: '42' };
  const second = { ...first, conversationId: '100-200', latestSequenceId: '43' };
  assert.equal(await f.service.publishUnreadMessages({}, [first], 1, 1, false), 1);
  assert.equal(await f.service.publishUnreadMessages({}, [first], 1, 1, false), 0);
  assert.equal(await f.service.publishUnreadMessages({}, [second], 1, 1, false), 1);
  assert.equal(await f.service.publishUnreadMessages({}, [{ ...second, latestSequenceId: '44', muted: true }], 1, 1, false), 0);
  assert.deepEqual(f.published.map(row => row.request.appMessageId),
    ['account-a:dm:100-200:42', 'account-a:dm:100-200:43']);
});

test('tap-to-share resumes multiple recipients after PIN and retries only the unsuccessful share', async () => {
  const calls = [];
  let unlocked = false;
  let rejectPin = true;
  let rejectSecond = true;
  const { Subject } = load(methods('entry/src/main/ets/components/PostShareSheetHost.ets',
    'PostShareSheetHost', ['sendSelected', 'canContinueSend', 'recipientParticipants']), {}, {
    xPrivateClient: { sessionIdentity: () => 'viewer', isSignedIn: () => true, hasChatOAuth: () => true },
    xChatService: {
      async prepare(_context, ids) { calls.push(['prepare', ...ids]); },
      isUnlocked: () => unlocked,
      hasBackup: () => true,
      async unlock(pin) {
        assert.equal(pin, '1234');
        calls.push('unlock');
        if (rejectPin) { throw new Error('InvalidPin'); }
        unlocked = true;
      },
      conversationTransport: () => 'encrypted',
      async sharePost(...args) {
        calls.push(args);
        if (args[0] === '100-300' && rejectSecond) { throw new Error('send_http_503'); }
      }
    },
    postShareUrl: () => 'https://x.com/example/status/123',
    chatFailureMessage: (_context, reason) => reason.replace('_http_', ' HTTP '),
    $r: name => name
  });
  const alice = { conversationId: '100-200', title: 'Alice', participantIds: [], group: false };
  const bob = { conversationId: '100-300', title: 'Bob', participantIds: [], group: false };
  const subject = Object.assign(new Subject(), {
    account: 'viewer', current: { post: { id: '123' } }, selected: [alice, bob], sentIds: [], linkRecipients: [],
    webUnconfirmed: new Set(),
    note: ' note ', open: true,
    context: () => ({ resourceManager: { getStringSync: name => name } }),
    getUIContext: () => ({ getPromptAction: () => ({ showToast: () => calls.push('sent') }) })
  });
  await subject.sendSelected();
  assert.equal(subject.askingPin, true);
  assert.equal(subject.sending, false);
  await subject.sendSelected('1234');
  assert.equal(subject.sendError, 'app.string.dm_pin_incorrect');
  assert.equal(subject.open, true);
  rejectPin = false;
  await subject.sendSelected('1234');
  assert.deepEqual(subject.selected, [bob]);
  assert.deepEqual(subject.sentIds, ['100-200']);
  assert.match(subject.sendError, /Bob.*HTTP 503/);
  assert.equal(subject.webRecipient, bob);
  assert.equal(subject.open, true);
  rejectSecond = false;
  await subject.sendSelected();
  assert.equal(subject.open, false);
  assert.equal(subject.sending, false);
  const url = 'https://x.com/example/status/123';
  assert.deepEqual(calls, [['prepare'], ['prepare'], 'unlock', ['prepare'], 'unlock', ['prepare', '100', '200'],
    ['100-200', '123', url, 'note'], ['prepare', '100', '300'], ['100-300', '123', url, 'note'],
    ['prepare', '100', '300'], ['100-300', '123', url, 'note'], 'sent']);
});

test('a legacy conversation sends a raw link only after that separate action is chosen', async () => {
  const plaintext = [];
  const contact = { id: '200' };
  const { Subject } = load(methods('entry/src/main/ets/components/PostShareSheetHost.ets',
    'PostShareSheetHost', ['sendSelected', 'canContinueSend', 'recipientParticipants', 'sendLegacyLink']), {}, {
    xPrivateClient: { sessionIdentity: () => 'viewer', viewerId: () => '100', isSignedIn: () => false },
    xChatService: { prepare: async () => {}, isUnlocked: () => true, conversationTransport: () => 'plaintext',
      async sharePost() { throw new Error('recipient_key_unavailable'); } },
    chatContactService: { async load(_context, id) { assert.equal(id, '200'); return contact; },
      async sendPlaintext(_context, receiver, id, text) { plaintext.push([receiver, id, text]); } },
    postShareUrl: () => 'https://x.com/example/status/123',
    chatFailureMessage: (_context, reason) => reason,
    $r: name => name
  });
  const subject = Object.assign(new Subject(), {
    account: 'viewer', current: { post: { id: '123' } }, selected: [{ conversationId: '100-200', title: 'Alice', group: false }],
    note: 'note', open: true, sentIds: [], linkRecipients: [], webUnconfirmed: new Set(),
    context: () => ({ resourceManager: { getStringSync: name => name } }),
    getUIContext: () => ({ getPromptAction: () => ({ showToast() {} }) })
  });
  await subject.sendSelected();
  assert.deepEqual(plaintext, []);
  assert.deepEqual(subject.linkRecipients, ['100-200']);
  await subject.sendSelected(undefined, true);
  assert.deepEqual(plaintext, [[contact, '100-200', 'note\nhttps://x.com/example/status/123']]);
  assert.equal(subject.open, false);
});

test('the original share button resumes hidden X Chat with one native PIN entry', async () => {
  const attempts = [];
  const { Subject } = load(methods('entry/src/main/ets/components/PostShareSheetHost.ets',
    'PostShareSheetHost', ['sendSelected', 'sendWithWebChat', 'canContinueSend']), {}, {
    xPrivateClient: { sessionIdentity: () => 'viewer', viewerId: () => '100', isSignedIn: () => true,
      hasChatOAuth: () => false },
    AppStorage: { get: () => true },
    async sendXChatWebDraft(_context, _ui, viewer, recipient, text, isCurrent, pin) {
      assert.equal(isCurrent(), true);
      attempts.push({ viewer, recipient, text, pin });
      return attempts.length === 1 ? 'pin_required' : 'confirmed';
    },
    postShareUrl: () => 'https://x.com/i/status/123',
    $r: name => name
  });
  const recipients = [{ conversationId: '100-200', title: 'Alice' }, { conversationId: '100-300', title: 'Bob' }];
  let toasts = 0;
  const subject = Object.assign(new Subject(), {
    account: 'viewer', current: { post: { id: '123' } }, selected: recipients, open: true,
    note: 'look', sentIds: [], webUnconfirmed: new Set(), context: () => ({}),
    getUIContext: () => ({ getPromptAction: () => ({ showToast() { toasts++; } }) })
  });
  await subject.sendSelected();
  assert.equal(subject.askingPin, true);
  assert.equal(subject.open, true);
  await subject.sendSelected('1234');
  assert.equal(subject.askingPin, false);
  assert.equal(subject.open, false);
  assert.equal(toasts, 1);
  assert.deepEqual(attempts.map(item => [item.recipient, item.pin]), [
    ['100-200', ''], ['100-200', '1234'], ['100-300', '']
  ]);
  assert.equal(attempts[1].text, 'look\nhttps://x.com/i/status/123');
});

test('native pull state still starts refresh and times out cleanly without a second inbox request', async () => {
  let resolveFetch;
  let fetches = 0;
  let indicatorTimeout;
  const { Subject } = load(methods('entry/src/main/ets/pages/Index.ets', 'Index', ['refreshMessages', 'loadMessages']), {}, {
    getContext() { return {}; },
    accountStore: { activeId: () => 'viewer' },
    CHAT_REFRESH_INDICATOR_MS: 20000,
    setTimeout(callback) { indicatorTimeout = callback; return 1; },
    clearTimeout() {}
  });
  const subject = Object.assign(new Subject(), {
    messagesRefreshing: true, messagesRefreshPullOffset: 34,
    fetchMessages() { fetches++; return new Promise(resolve => { resolveFetch = resolve; }); }
  });
  const refresh = subject.refreshMessages();
  assert.equal(fetches, 1);
  indicatorTimeout();
  await refresh;
  assert.equal(subject.messagesRefreshing, false);
  assert.equal(subject.messagesRefreshPullOffset, 0);
  assert.equal(subject.messagesLoading, true);
  const retry = subject.refreshMessages();
  assert.equal(fetches, 1);
  resolveFetch();
  await retry;
  assert.equal(subject.messagesLoading, false);
  assert.equal(subject.messagesRefreshing, false);
});

function share(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'harmonyx-share-test-')).replace(/\\/g, '/');
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  let closed = 0;
  const api = { OpenMode: { READ_ONLY: 0, CREATE: 1, WRITE_ONLY: 2, TRUNC: 4 },
    mkdirSync: (target, recursive = false) => fs.mkdirSync(target, { recursive }),
    open: async target => ({ fd: fs.openSync(target, 'r'), path: target }),
    openSync: target => ({ fd: fs.openSync(target, 'w') }),
    copyFile: async (fd, target) => fs.writeFileSync(target, fs.readFileSync(fd)),
    closeSync: file => { fs.closeSync(file.fd); closed++; }, writeSync: (fd, value) => fs.writeSync(fd, value),
    readTextSync: target => fs.readFileSync(target, 'utf8'), accessSync: target => fs.existsSync(target),
    rmdirSync: target => { assert.ok(target.startsWith(root + '/share-inbox/')); fs.rmSync(target, { recursive: true }); } };
  const parents = { jpg: ['image'], gif: ['gif', 'image'], mp4: ['video'], heic: ['image'] };
  const { ExternalShareStore } = load(fs.readFileSync('entry/src/main/ets/services/ExternalShareStore.ets', 'utf8'), {
    '../models/ComposerMedia': composerMedia,
    '@ohos.file.fs': { default: api }, '@ohos.util': { default: { generateRandomUUID: () => 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' } },
    '@ohos.data.uniformTypeDescriptor': { default: { UniformDataType: { IMAGE: 'image', VIDEO: 'video', GIF: 'gif' },
      getTypeDescriptor: type => ({ belongsTo: parent => parents[type]?.includes(parent) ?? false }) } }
  });
  const context = { getApplicationContext: () => ({ filesDir: root }) };
  return { root, api, context, store: new ExternalShareStore(), closed: () => closed,
    record: (filename, type, content = 'bytes') => { const uri = root + '/' + filename; fs.writeFileSync(uri, content); return { uri, utd: type }; } };
}

test('share copies survive revoking original files and preserve media kind and basename', async t => {
  const f = share(t);
  const records = [f.record('photo.jpg', 'jpg'), f.record('animation.gif', 'gif'), f.record('video.mp4', 'mp4'), { utd: 'text', content: 'caption' }];
  const payload = await f.store.stage(f.context, records);
  records.filter(row => row.uri).forEach(row => fs.unlinkSync(row.uri));
  const read = f.store.read(f.context, payload.id);
  assert.equal(read.text, 'caption');
  assert.deepEqual(read.files.map(file => file.type), [1, 2, 3]);
  assert.deepEqual(read.files.map(file => file.filename), ['photo.jpg', 'animation.gif', 'video.mp4']);
  assert.ok(read.files.every(file => fs.readFileSync(file.uri, 'utf8') === 'bytes'));
  assert.equal(f.closed(), 4);
});

test('partial import failure rolls back the batch rather than silently discarding media', async t => {
  const f = share(t);
  await assert.rejects(f.store.stage(f.context, [f.record('ok.jpg', 'jpg'), { utd: 'jpg', uri: f.root + '/missing.jpg' }]));
  assert.deepEqual(fs.readdirSync(f.root + '/share-inbox'), []);
  assert.equal(f.closed(), 1);
});

test('incoming IDs cannot escape the share sandbox', t => {
  const f = share(t);
  for (const id of ['../secret', 'a/b', 'a'.repeat(31), 'A'.repeat(32), '']) {
    assert.equal(f.store.read(f.context, id), null); f.store.discard(f.context, id);
  }
  assert.equal(fs.existsSync(f.root), true);
});

test('post imports allow mixed media in order with a 20-item limit and one GIF', t => {
  const f = share(t);
  const payload = types => ({ files: types.map(type => ({ type })) });
  assert.equal(f.store.canPost(payload([1, 1, 1, 2])), true);
  assert.equal(f.store.canPost(payload(Array.from({ length: 20 }, () => 1))), true);
  assert.equal(f.store.canPost(payload(Array.from({ length: 21 }, () => 1))), false);
  assert.equal(f.store.canPost(payload([3])), true);
  assert.equal(f.store.canPost(payload([1, 3])), true);
  assert.equal(f.store.canPost(payload([2, 2])), false);
});

test('shared DM files enter the existing attachment pipeline once and retain the caption', () => {
  const payload = { id: 'share', text: 'caption', files: [{ uri: '/private/photo.jpg', type: 1 }, { uri: '/private/movie.mp4', type: 3 }] };
  const { Subject } = load(methods('entry/src/main/ets/pages/DmConversation.ets', 'DmConversationPage', ['readRoute', 'addAttachments']), {}, {
    xChatActions: { localString: () => '' }, getContext: () => ({}),
    xChatMedia: { selectedFile: (uri, type) => ({ uri, type }) }, XChatMedia: { mediaSlots: files => files.length, MAX_MEDIA_ATTACHMENTS: 10 },
    promptAction: { showToast: () => assert.fail('should not truncate') }
  });
  const page = new Subject();
  Object.assign(page, { pageStack: { getParamByName: () => [{ conversationId: 'c', title: 'Person', group: true, participantIds: [], sharedPayload: payload }] },
    attachments: [], sharedImportId: '', discardAttachment() { this.attachments = []; } });
  page.readRoute(); page.readRoute();
  assert.equal(page.draft, 'caption'); assert.equal(page.attachments.length, 2);
  assert.deepEqual(page.attachments.map(file => file.type), [1, 3]);
});

test('window teardown removes exact callbacks and tolerates an already destroyed window', () => {
  const { Subject } = load(methods('entry/src/main/ets/entryability/EntryAbility.ets', 'EntryAbility', ['releaseWindowListeners', 'onWindowStageDestroy']), {},
    { hilog: { info() {}, warn() {} }, DOMAIN: 0, TAG: '',
      startupSession: { cancel() {} }, antiPeepProtection: { detachWindow() {} },
      videoHdrCapability: { stop() {} } });
  const calls = [], page = new Subject(), size = () => {}, area = () => {};
  Object.assign(page, { observedWindow: { off: (event, callback) => { calls.push([event, callback]); if (event === 'windowSizeChange') throw new Error(); } },
    windowSizeListener: size, avoidAreaListener: area, windowStage: {} });
  page.onWindowStageDestroy(); page.onWindowStageDestroy();
  assert.deepEqual(calls, [['windowSizeChange', size], ['avoidAreaChange', area]]);
  assert.equal(page.observedWindow, null); assert.equal(page.windowStage, null);
});

test('the app language controls dates independently of the system and refreshes only on locale changes', () => {
  let preferred = 'it', system = 'zh-CN';
  const storage = new Map();
  const localization = { i18n: { System: { getAppPreferredLanguage: () => preferred,
    getSystemLanguage: () => system, is24HourClock: () => true } } };
  const locale = load(fs.readFileSync('entry/src/main/ets/utils/AppLocale.ets', 'utf8'), { '@kit.LocalizationKit': localization },
    { AppStorage: { get: key => storage.get(key), setOrCreate: (key, value) => storage.set(key, value) } });
  const post = load(fs.readFileSync('entry/src/main/ets/utils/PostTime.ets', 'utf8'), { '@kit.LocalizationKit': localization, './AppLocale': locale });
  const chat = load(fs.readFileSync('entry/src/main/ets/utils/ChatTime.ets', 'utf8'), { '@kit.LocalizationKit': localization, './AppLocale': locale });
  const timestamp = Date.parse('2026-10-02T14:25:00Z');
  assert.equal(locale.effectiveAppLocale(), 'it');
  assert.equal(post.formatPostTime('2026-10-02T14:25:00Z', timestamp + 60000), new Intl.NumberFormat('it', {
    style: 'unit', unit: 'minute', unitDisplay: 'narrow', useGrouping: false }).format(1));
  assert.equal(chat.chatMessageTime(timestamp), chat.chatMessageTime(timestamp, '', 'it'));
  locale.publishAppLocale();
  const clock = storage.get('harmonyx.post_time_now');
  locale.publishAppLocale(); assert.equal(storage.get('harmonyx.post_time_now'), clock);
  preferred = 'en'; locale.publishAppLocale();
  assert.equal(storage.get(locale.STORAGE_KEY_APP_LOCALE), 'en');
  assert.ok(storage.get('harmonyx.post_time_now') > clock);
  preferred = 'default'; assert.equal(locale.effectiveAppLocale(), system);
});

test('shared content does not overwrite an existing composer draft without the editor confirmation', async () => {
  let choice = 0, saves = 0;
  const { Subject } = load(methods('entry/src/main/ets/components/ReplyComposer.ets', 'ReplyComposerPage', ['importSharedPayload']), {}, {
    getContext: () => ({}), accountStore: { activeId: () => 'account' }, $r: value => value,
    promptAction: { showDialog: async () => ({ index: choice }) },
    ComposerMedia: composerMedia.ComposerMedia,
    ComposerOptions: class { hasSettings() { return false; } }
  });
  const page = new Subject();
  Object.assign(page, { sharedImportId: '', composerPageActive: true, draft: 'existing', attachments: [new composerMedia.ComposerMedia('/old.jpg', 1)],
    composeOptions: { hasSettings: () => false }, text: value => value, scheduleDraftSave: () => saves++ });
  const payload = { id: 'share-1', text: 'caption',
    files: [{ uri: '/video.mp4', type: 3 }, { uri: '/new.jpg', type: 1 }, { uri: '/gif.gif', type: 2 }] };
  await page.importSharedPayload(payload);
  assert.equal(page.draft, 'existing'); assert.deepEqual(page.attachments.map(item => item.uri), ['/old.jpg']); assert.equal(saves, 0);
  choice = 1; await page.importSharedPayload({ ...payload, id: 'share-2' });
  assert.equal(page.draft, 'caption'); assert.deepEqual(page.attachments.map(item => item.uri), ['/video.mp4', '/new.jpg', '/gif.gif']); assert.equal(saves, 1);
});
