const assert = require('node:assert/strict');
const test = require('node:test');
const { load } = require('./post-card-fixture.cjs');
const { XXAuthPopupPolicy: policy } = load('services/XXAuthPopupPolicy');

test('public announcements omit old promotion records and render plain text', () => {
  const legacyRecords = Array.from({ length: 7 }, (_, i) =>
    ({ id: String(i), priority: i + 10, title: 'App promotion', content: 'Install this app' }));
  const rows = [
    ...legacyRecords,
    { id: 'legacy-link', priority: -2, title: '\u94fe\u63a5', content: 'https://example.com/ad' },
    { id: 'low', priority: 0, title: 'News', content: 'Low priority' },
    { id: 'high', priority: 5, title: 'Notice', content: '//\u63d0\u9192\n<p>High &amp; new</p><script>hidden()</script>' },
    { id: 'hidden', priority: 8, title: 'Hidden', content: '//\u5173\u95ed' }
  ];
  const panels = policy.publicAnnouncements(rows).map(row => policy.announcement(row));
  assert.deepEqual(panels.map(panel => panel.id), ['high', 'low']);
  assert.equal(panels[0].content, 'High & new');
  assert.equal(panels[0].kind, 'announcement');
  assert.equal(panels[0].repeat, true);
  assert.equal(panels[0].link, '');
});

test('version comparison uses public stable metadata and never creates a forced update', () => {
  const release = { version: 'v3.10.0', channel: 'stable', download_url: 'https://example.com/download',
    change_log: 'Release notes', force_update: true };
  const update = policy.update(release, '3.9.0');
  assert.equal(update.version, 'v3.10.0');
  assert.equal(update.link, release.download_url);
  assert.equal(update.forced, undefined);
  assert.equal(policy.update({ ...release, download_url: 'javascript:alert(1)' }, '3.9.0').link, '');
  for (const version of ['3.8.9', '3.9.0', 'v3.9.0', 'invalid', '3.10.0-beta']) {
    assert.equal(policy.update({ ...release, version }, '3.9.0'), undefined);
  }
  assert.equal(policy.update({ ...release, channel: 'beta' }, '3.9.0'), undefined);
});

test('XXAuth public reads send only the application identifier and clean up each HTTP request', async () => {
  const calls = [];
  let destroyed = 0;
  const http = { RequestMethod: { GET: 'GET' }, HttpDataType: { STRING: 'string' },
    createHttp: () => ({
      request: async (url, options) => {
        calls.push({ url, options });
        const data = url.includes('/latest') ? { version: '3.9.0' } : [];
        return { responseCode: 200, result: JSON.stringify({ code: 0, data }) };
      },
      destroy: () => { destroyed++; }
    })
  };
  const { XXAuthService, XXAUTH_APP_ID } = load('services/XXAuthService', { '@ohos.net.http': http });
  const service = new XXAuthService();
  for (const method of ['announcements', 'articles', 'versions', 'latestVersion']) {
    assert.equal((await service[method]()).ok, true);
  }
  assert.deepEqual(calls.map(({ url }) => url.replace('https://api.xxauth.com/open/v1', '')),
    ['/announcements', '/articles', '/version/list?platform=harmonyos', '/version/latest?platform=harmonyos']);
  for (const { options } of calls) {
    assert.equal(options.method, 'GET');
    assert.deepEqual(options.header, { app_id: XXAUTH_APP_ID, Accept: 'application/json' });
    assert.equal(options.extraData, undefined);
  }
  assert.equal(destroyed, 4);
});

test('upgraded installations remove the old installation ID while preserving notice history', () => {
  const disk = new Map([['device_id', 'old-install-id'], ['seen_announcement_news', 'fingerprint']]);
  let flushes = 0;
  const preferences = { getPreferencesSync: () => ({
    hasSync: key => disk.has(key),
    deleteSync: key => disk.delete(key),
    flushSync: () => { flushes++; }
  }) };
  const { XXAuthPopupStore } = load('services/XXAuthPopupStore', { '@kit.ArkData': { preferences } });
  const store = new XXAuthPopupStore();
  store.removeLegacyInstallId({});
  store.removeLegacyInstallId({});
  assert.deepEqual([...disk], [['seen_announcement_news', 'fingerprint']]);
  assert.equal(flushes, 1);
});

test('legacy cleanup reads aliases only and removes both redemption formats across pages', async () => {
  const decoder = new TextDecoder();
  const items = ['harmonyx_supporter_v1', ...Array.from({ length: 31 }, (_, i) => 'account-' + i),
    'harmonyx_supporter_account_v2_123', 'harmonyx_supporter_account_v2_other'];
  const removed = [];
  const pages = [];
  const Tag = { ALIAS: 'alias', RETURN_TYPE: 'return-type', RETURN_LIMIT: 'limit', RETURN_OFFSET: 'offset' };
  const asset = { Tag, ReturnType: { ATTRIBUTES: 1 }, ErrorCode: { NOT_FOUND: 24000002 },
    query: async query => {
      assert.equal(query.get(Tag.RETURN_TYPE), 1);
      const offset = query.get(Tag.RETURN_OFFSET);
      pages.push(offset);
      return items.slice(offset, offset + query.get(Tag.RETURN_LIMIT))
        .map(alias => new Map([[Tag.ALIAS, new TextEncoder().encode(alias)]]));
    },
    remove: async query => {
      const alias = decoder.decode(query.get(Tag.ALIAS));
      removed.push(alias);
      items.splice(items.indexOf(alias), 1);
    }
  };
  const { removeLegacySupportData } = load('services/LegacySupportData', {
    '@kit.AssetStoreKit': { asset },
    '@kit.ArkTS': { util: { TextDecoder: { create: () => ({ decodeToString: bytes => decoder.decode(bytes) }) } } }
  });
  await removeLegacySupportData();
  assert.deepEqual(pages, [0, 32]);
  assert.deepEqual(removed, ['harmonyx_supporter_v1', 'harmonyx_supporter_account_v2_123']);
  assert.equal(items.length, 32);
});
