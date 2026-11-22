const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const { load } = require('./post-card-fixture.cjs');

const { webChatDraftScript } = load('services/XChatWebDraft', {
  '@kit.AbilityKit': {}, '@kit.ArkUI': {}, '@kit.ArkWeb': {},
  './ProxyStore': {}, './XUserAgent': {}, './XWebCookieBridge': {}
});
const text = 'look\nhttps://x.com/i/status/123';

function webPage() {
  const location = { origin: 'https://x.com', pathname: '/i/chat/200-100' };
  const old = 'message-text-old';
  const nodes = [];
  let clicks = 0;
  let menu = [];
  class Textarea {
    content = '';
    get value() { return this.content; }
    set value(value) { this.content = value; }
    dispatchEvent() {}
  }
  const box = new Textarea();
  const list = { querySelectorAll: () => nodes, getBoundingClientRect: () => ({ left: 0, right: 600 }) };
  const button = { getAttribute: () => null, click: () => { clicks++; box.value = ''; } };
  const panel = { querySelector: selector => selector.includes('textarea') ? box :
    selector.includes('message-list') || selector.includes('message-scroller') ? list : button };
  const digits = [];
  const shadow = { querySelector: selector => {
    const position = /Digit (\d)/.exec(selector);
    return position ? digits[Number(position[1]) - 1] ?? null : panel;
  }, querySelectorAll: selector => selector === '*' ? [] : menu };
  const document = { cookie: 'twid=u%3D100;', querySelector: () => null,
    querySelectorAll: selector => selector === '*' ? [{ shadowRoot: shadow }] : [] };
  const run = (action, previous = [], expires = Date.now() + 1000, digit = '', position = -1, reaction) => JSON.parse(vm.runInNewContext(
    webChatDraftScript('100', '100-200', text, action, previous, expires, digit, position, reaction),
    { document, location, URL, HTMLTextAreaElement: Textarea, HTMLInputElement: Textarea, Event: class {}, MouseEvent: class {} }));
  const add = (id, outgoing = true) => nodes.push({ innerText: text, getAttribute: () => id,
    getBoundingClientRect: () => ({ left: outgoing ? 430 : 10, right: outgoing ? 590 : 170, width: 160 }) });
  const cardBounds = () => ({ left: 430, right: 590, width: 160 });
  const addCard = (id, href) => nodes.push({ innerText: 'look card text', getAttribute: () => id,
    querySelector: selector => selector === 'time' ? { dateTime: '2026-11-22T09:00:00Z' } :
      { innerText: 'look', getBoundingClientRect: cardBounds },
    querySelectorAll: () => [{ href }],
    getBoundingClientRect: cardBounds });
  const lock = () => { for (let i = 0; i < 4; i++) digits.push(Object.assign(new Textarea(), { maxLength: 1, focus() {} })); };
  return { run, box, document, location, add, addCard, old, lock, digits, nodes, setMenu: value => { menu = value; }, clicks: () => clicks };
}

test('hidden share stages text, submits once, then confirms only a new outgoing bubble', () => {
  const page = webPage();
  page.add(page.old);
  assert.equal(page.run('prepare').status, 'staged');
  assert.equal(page.box.value, text);
  assert.equal(page.run('prepare').status, 'ready');
  assert.equal(page.clicks(), 0);
  const result = page.run('submit');
  assert.deepEqual(result, { status: 'submitted', previous: [page.old] });
  assert.equal(page.clicks(), 1);
  assert.equal(page.run('confirm', result.previous).status, 'waiting');
  page.add('message-text-incoming', false);
  assert.equal(page.run('confirm', result.previous).status, 'waiting');
  page.add('message-text-new');
  assert.equal(page.run('confirm', result.previous).status, 'confirmed');
  assert.equal(page.clicks(), 1);
});

test('hidden share leaves an existing draft alone and will not submit after content changes', () => {
  const page = webPage();
  page.box.value = 'original draft';
  assert.equal(page.run('prepare').status, 'occupied');
  assert.equal(page.run('submit').status, 'waiting');
  assert.equal(page.box.value, 'original draft');
  assert.equal(page.clicks(), 0);
});

test('a link share confirms a new post card only if the status and note match', () => {
  const page = webPage();
  page.run('prepare');
  const result = page.run('submit');
  page.addCard('message-other', 'https://x.com/author/status/1234');
  assert.equal(page.run('confirm', result.previous).status, 'waiting');
  page.addCard('message-card', 'https://x.com/author/status/123');
  assert.equal(page.run('confirm', result.previous).status, 'confirmed');
});

test('hidden share is scoped to the official origin, exact account, conversation and deadline', () => {
  const page = webPage();
  assert.equal(page.run('submit', [], Date.now() - 1).status, 'unavailable');
  page.location.origin = 'https://fake.x.com';
  assert.equal(page.run('prepare').status, 'unavailable');
  page.location.origin = 'https://x.com';
  page.location.pathname = '/i/chat/100-201';
  assert.equal(page.run('prepare').status, 'wrong_conversation');
  page.location.pathname = '/i/chat/100-200';
  page.document.cookie = 'twid=u%3D100; twid=u%3D201';
  assert.equal(page.run('prepare').status, 'wrong_account');
  assert.equal(page.box.value, '');
  assert.equal(page.clicks(), 0);
});

test('an official Chat PIN challenge is detected inside shadow DOM and filled one digit at a time', () => {
  const page = webPage();
  page.lock();
  assert.equal(page.run('prepare').status, 'pin_required');
  assert.equal(page.run('history').status, 'pin_required');
  page.location.pathname = '/login';
  assert.equal(page.run('unlock', [], Date.now() + 1000, '1', 0).status, 'waiting');
  page.location.pathname = '/i/chat/pin/recovery';
  assert.equal(page.run('unlock', [], Date.now() + 1000, '2', 1).status, 'pin_required');
  assert.deepEqual(page.digits.map(box => box.value), ['', '', '', '']);
  for (let i = 0; i < 4; i++) {
    assert.equal(page.run('unlock', [], Date.now() + 1000, String(i + 1), i).status, i === 3 ? 'pin_attempted' : 'pin_digit');
  }
  assert.deepEqual(page.digits.map(box => box.value), ['1', '2', '3', '4']);
  assert.equal(page.clicks(), 0);
});

test('history reads the requested conversation in place and includes visible post links', () => {
  const page = webPage();
  page.addCard('message-card', 'https://x.com/author/status/123');
  assert.deepEqual(page.run('history'), { status: 'history', messages: [{ id: 'card', text: 'look', outgoing: true,
    timestamp: Date.parse('2026-11-22T09:00:00Z'), postUrl: 'https://x.com/author/status/123' }] });
  assert.equal(page.run('earlier').status, 'scrolled');
  assert.equal(page.clicks(), 0);
});

test('history reads the sender from the message row even when a wide bubble has no usable alignment', () => {
  const page = webPage();
  const centered = () => ({ left: 4, right: 596, width: 592 });
  function add(id, classes, sender) {
    const message = { getAttribute: key => key === 'data-testid' ? 'message-text-' + id : null,
      innerText: id, getBoundingClientRect: centered };
    const row = {
      getAttribute: key => key === 'data-testid' ? 'message-' + id : key === 'data-sender-id' ? sender : null,
      classList: { contains: name => classes.includes(name) }, getBoundingClientRect: centered,
      querySelector: selector => selector.startsWith('[data-testid') ? message : null
    };
    message.closest = () => row;
    page.nodes.push(row, message);
  }
  add('mine', ['justify-end']);
  add('theirs', ['justify-end'], '200');
  add('unknown', []);
  assert.deepEqual(page.run('history').messages.map(row => [row.id, row.outgoing]),
    [['mine', true], ['theirs', false], ['unknown', undefined]]);
});

test('the Web reaction clicks only the selected message and waits for its reaction state to change', () => {
  const page = webPage();
  let presses = 0;
  let opened = 0;
  let chips = [];
  const button = (attrs, click, inMenu = false) => ({
    textContent: attrs['data-emoji'] || '',
    getAttribute: key => attrs[key] ?? null, getClientRects: () => [1],
    querySelector: () => null, closest: () => inMenu ? {} : null, click
  });
  const toggle = () => {
    presses++;
    chips = chips.length > 0 ? [] : [button({'data-emoji': '👍', 'aria-pressed': 'true'}, toggle)];
    page.setMenu([]);
  };
  const target = {
    getAttribute: key => key === 'data-testid' ? 'message-target' : null,
    querySelectorAll: () => chips,
    querySelector: () => null,
    getBoundingClientRect: () => ({ left: 0, right: 10, top: 0, bottom: 10 }),
    dispatchEvent() { opened++; page.setMenu([button({'data-emoji': '👍'}, toggle, true)]); }
  };
  page.nodes.push(target);
  const reaction = { id: 'target', emoji: '👍', remove: false };
  const run = (action, previous, request = reaction) => page.run(action, previous, Date.now() + 1000, '', -1, request);
  assert.equal(run('reaction_open', [], { ...reaction, id: 'other' }).status, 'waiting');
  assert.equal(opened, 0);
  const before = run('reaction_open', []);
  assert.equal(before.status, 'reaction_opened');
  assert.equal(run('reaction_confirm', before.previous).status, 'waiting');
  const submitted = run('reaction_choose', before.previous);
  assert.equal(submitted.status, 'reaction_submitted');
  assert.equal(run('reaction_confirm', submitted.previous).status, 'reacted');
  assert.equal(presses, 1);
  const removal = { ...reaction, remove: true };
  const removed = run('reaction_open', [], removal);
  assert.equal(removed.status, 'reaction_submitted');
  assert.equal(run('reaction_confirm', removed.previous, removal).status, 'reacted');
  assert.equal(presses, 2);
});
