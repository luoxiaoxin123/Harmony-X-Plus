const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');
const vm = require('node:vm');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

const source = fs.readFileSync('entry/src/main/ets/components/XLoginWebContent.ets', 'utf8');
const stateSource = source.slice(source.indexOf('export const X_LOGIN_URL'), source.indexOf('  @Builder'))
  .replace('export const', 'const')
  .replace('export struct', 'class')
  .replace(/@\w+(?:\([^\n)]*\))?\s*/g, '');
const stateScript = ts.transpileModule(stateSource + '\n}\nthis.LoginContent = XLoginWebContent;', {
  compilerOptions: { target: ts.ScriptTarget.ES2022 }
}).outputText;

function fixture() {
  const proxyCalls = [];
  const timers = new Map();
  let nextTimer = 0;
  const globals = {
    $r: name => name,
    DEFAULT_APP_FONT_FAMILY: 'system',
    DISPLAY_MODE_SYSTEM: 'system',
    webview: { WebviewController: class {} },
    xUserAgent: { value: () => 'test-agent' },
    proxyStore: { applyToWebStack: () => new Promise(resolve => proxyCalls.push(resolve)) },
    setTimeout: (callback, delay) => { timers.set(++nextTimer, { callback, delay }); return nextTimer; },
    clearTimeout: id => timers.delete(id)
  };
  vm.runInNewContext(stateScript, globals);
  const content = new globals.LoginContent();
  content.active = true;
  return { content, proxyCalls, timers };
}

test('login waits for the selected proxy and a web document without a paint times out', async () => {
  const { content, proxyCalls, timers } = fixture();
  const loading = content.load();
  assert.equal(content.stage, 'preparing');
  proxyCalls[0]();
  await loading;
  assert.equal(content.stage, 'loading');

  const timeout = [...timers.values()][0];
  assert.equal(timeout.delay, 20000);
  timeout.callback();
  assert.equal(content.stage, 'failed');
  assert.equal(content.failureMessage, 'app.string.auth_web_paint_timeout');
  assert.equal(timers.size, 0);
});

test('retry reapplies the proxy with a new controller and stops waiting on first paint', async () => {
  const { content, proxyCalls, timers } = fixture();
  const first = content.load();
  proxyCalls[0]();
  await first;
  const oldController = content.controller;
  content.fail('app.string.auth_web_load_failed', 'HTTP 403');
  assert.equal(content.failureDetail, 'HTTP 403');

  const retry = content.load();
  assert.equal(content.stage, 'preparing');
  proxyCalls[1]();
  await retry;
  assert.notEqual(content.controller, oldController);
  content.firstPaint();
  assert.equal(content.stage, 'ready');
  assert.equal(timers.size, 0);
});

test('a late proxy callback cannot mount web content after timeout or dismissal', async () => {
  const { content, proxyCalls, timers } = fixture();
  const first = content.load();
  [...timers.values()][0].callback();
  proxyCalls[0]();
  await first;
  assert.equal(content.stage, 'failed');

  const retry = content.load();
  content.aboutToDisappear();
  proxyCalls[1]();
  await retry;
  assert.equal(content.stage, 'preparing');
  assert.equal(timers.size, 0);
});

test('only a handled OAuth redirect ends the wait before first paint', async () => {
  const { content, proxyCalls, timers } = fixture();
  const load = content.load();
  proxyCalls[0]();
  await load;
  content.onIntercept = url => url === 'harmonyx://callback';
  assert.equal(content.intercept('https://x.com/'), false);
  assert.equal(timers.size, 1);
  assert.equal(content.intercept('harmonyx://callback'), true);
  assert.equal(content.stage, 'ready');
  assert.equal(timers.size, 0);
});
