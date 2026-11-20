const assert = require('node:assert/strict');
const test = require('node:test');
const { load } = require('./post-card-fixture.cjs');
test('upgraded installations remove the old installation ID while preserving notice history', () => {
  const disk = new Map([['device_id', 'old-install-id'], ['seen_announcement_news', 'fingerprint']]);
  let flushes = 0;
  const preferences = { getPreferencesSync: () => ({
    hasSync: key => disk.has(key),
    deleteSync: key => disk.delete(key),
    flushSync: () => { flushes++; }
  }) };
  const { removeLegacyInstallId } = load('services/LegacySupportData', {
    '@kit.ArkData': { preferences }, '@kit.ArkTS': {}, '@kit.AssetStoreKit': {}
  });
  removeLegacyInstallId({});
  removeLegacyInstallId({});
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
    '@kit.ArkData': {},
    '@kit.AssetStoreKit': { asset },
    '@kit.ArkTS': { util: { TextDecoder: { create: () => ({ decodeToString: bytes => decoder.decode(bytes) }) } } }
  });
  await removeLegacySupportData();
  assert.deepEqual(pages, [0, 32]);
  assert.deepEqual(removed, ['harmonyx_supporter_v1', 'harmonyx_supporter_account_v2_123']);
  assert.equal(items.length, 32);
});
