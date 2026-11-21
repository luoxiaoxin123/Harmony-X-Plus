const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

const source = fs.readFileSync('entry/src/main/ets/components/StockQuoteCard.ets', 'utf8');
const code = source.slice(source.indexOf('export function stockTicker'), source.indexOf('@Component'));
const moduleExports = {};
new Function('exports', ts.transpileModule(code, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText)(moduleExports);
const { stockTicker } = moduleExports;

test('market cards recognise stock tags in Chinese and English and filter out prices or URL components', () => {
  assert.equal(stockTicker('刚买了股票。$NVDA'), 'NVDA');
  assert.equal(stockTicker('Berkshire ($brk.b)'), 'BRK.B');
  assert.equal(stockTicker('https://example.test/$BA and $70.51'), '');
  assert.equal(stockTicker('https://example.test/$BA and $AAPL'), 'AAPL');
  assert.equal(stockTicker('before$MSFT or $not_a_symbol'), '');
});
