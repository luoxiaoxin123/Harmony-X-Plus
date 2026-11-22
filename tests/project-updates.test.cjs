const test = require('node:test');
const assert = require('node:assert/strict');
const { load } = require('./post-card-fixture.cjs');

const { newerProjectRelease } = load('services/ProjectUpdates', { '@kit.AbilityKit': {}, '@kit.NetworkKit': {} });
const { PROJECT_RELEASES_URL } = load('utils/ProjectLinks');

function release(tag, properties = {}) {
  return { tag_name: tag, html_url: `${PROJECT_RELEASES_URL}/tag/${tag}`, ...properties };
}

test('update selection matches the installed release channel and compares beta counters numerically', () => {
  const body = JSON.stringify([release('v4.0.0-beta.9', { prerelease: true }), release('v3.9.0'),
    release('v4.0.0-beta.20', { prerelease: true }), release('v4.0.0-beta.100', { draft: true })]);
  assert.equal(newerProjectRelease(body, '4.0.0-beta.18.1.gae2b4b5').version, '4.0.0-beta.20');
  assert.equal(newerProjectRelease(body, '3.9.0').version, '');
  assert.equal(newerProjectRelease(JSON.stringify([release('v4.0.0')]), '4.0.0-beta.18.1.gae2b4b5').version, '4.0.0');
});

test('the notice only links to a newer release published in this repository', () => {
  const body = JSON.stringify([release('v4.1.0', { html_url: 'https://outside.example/releases/tag/v4.1.0' }),
    release('v4.0.1'), release('nightly')]);
  assert.equal(newerProjectRelease(body, '4.0.0').url, `${PROJECT_RELEASES_URL}/tag/v4.0.1`);
  assert.equal(newerProjectRelease(body, '4.0.1').url, '');
});

test('two-part releases and three-part equivalents use the same version ordering', () => {
  const body = JSON.stringify([release('v0.1'), release('v0.2-beta.1', { prerelease: true })]);
  assert.equal(newerProjectRelease(body, '0.1-beta.30.1.g0123456').version, '0.2-beta.1');
  assert.equal(newerProjectRelease(body, '0.1.0-beta.30.1.g0123456').version, '0.2-beta.1');
  assert.equal(newerProjectRelease(JSON.stringify([release('v0.1')]), '0.1-beta.30.1.g0123456').version, '0.1');
  assert.equal(newerProjectRelease(JSON.stringify([release('v0.1.0')]), '0.1').version, '');
  assert.equal(newerProjectRelease(JSON.stringify([release('v0.2')]), '0.1.0').version, '0.2');
});

test('foreground release lookup sends a public GET without cookies or identifiers', async () => {
  const storage = new Map();
  const requests = [];
  const { projectUpdates, PROJECT_UPDATE_KEY } = load('services/ProjectUpdates', {
    '@kit.AbilityKit': { bundleManager: { getBundleInfoForSelfSync: () => ({ versionName: '4.0.0' }),
      BundleFlag: { GET_BUNDLE_INFO_WITH_APPLICATION: 1 } } },
    '@kit.NetworkKit': { http: { RequestMethod: { GET: 'GET' }, createHttp: () => ({
      request: async (url, options) => {
        requests.push({ url, options });
        return { responseCode: 200, result: [release('v4.0.1')] };
      }, destroy() {}
    }) } }
  }, storage);
  await projectUpdates.check();
  assert.equal(requests[0].url, 'https://api.github.com/repos/luoxiaoxin123/Harmony-X-Plus/releases?per_page=30');
  assert.deepEqual(Object.keys(requests[0].options.header), ['Accept', 'User-Agent']);
  assert.equal(requests[0].options.method, 'GET');
  assert.equal(requests[0].options.extraData, undefined);
  assert.equal(storage.get(PROJECT_UPDATE_KEY).version, '4.0.1');
});
