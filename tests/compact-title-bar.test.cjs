const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function load(file, dependencies = {}) {
  const exports = {};
  const output = ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  new Function('require', 'exports', output)(id => {
    assert.ok(dependencies[id], id);
    return dependencies[id];
  }, exports);
  return exports;
}

const { RootTitleBarLayout: layout } = load('entry/src/main/ets/utils/RootTitleBarLayout.ets');
const indexSource = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const indexTree = ts.createSourceFile('index.ts', indexSource.replace('struct Index', 'class Index'),
  ts.ScriptTarget.Latest, true);
const indexClass = indexTree.statements.find(node =>
  ts.isClassDeclaration(node) && node.name && node.name.text === 'Index');
function indexMethod(name) {
  const member = indexClass.members.find(node => node.name && node.name.getText(indexTree) === name);
  assert.ok(member, name);
  return member.getText(indexTree);
}

test('root title-bar morph starts with the page switch and stays short', () => {
  const duration = /const TITLE_BAR_MORPH_DURATION_MS = (\d+);/.exec(indexSource);
  assert.ok(duration);
  assert.ok(Number(duration[1]) <= 200);
  const schedule = indexMethod('scheduleChromeTab');
  assert.ok(schedule.indexOf('animateTo') < schedule.indexOf('setTimeout('));
  assert.match(schedule, /this\.chromeTab = index/);
  assert.match(schedule, /this\.chromeTabSettled = index/);
  // The shared scroll state now owns both title-bar and bottom-bar visibility.
  assert.match(indexMethod('titleBarShouldHide'), /this\.titleBarHidden/);
  assert.match(indexMethod('setChromeHidden'), /this\.setTitleBarHidden\(hidden\)/);
});

test('collapsed chrome keeps the HDS status-bar band for immersive gradient blur', () => {
  const params = indexMethod('titleBarDynamicHideParams');
  assert.match(params, /hideTitleArea: hidden/);
  assert.match(params, /hideBottomBuilder: hidden/);
  assert.match(params, /hideStatusBar: false/);
  assert.match(params, /mode: HideMode\.SCROLL_UP/);
  assert.match(indexSource, /\.dynamicHideTitleBar\(this\.titleBarDynamicHideParams\(\)\)/);
  assert.doesNotMatch(indexSource, /collapsed-status-bar-blur/);
  const titleBar = fs.readFileSync('entry/src/main/ets/utils/DestinationTitleBar.ets', 'utf8');
  assert.match(titleBar, /ScrollEffectType\.IMMERSIVE_GRADIENT_BLUR/);
});

function indexHarness(methods, globals) {
  const source = `class Harness { ${methods.map(indexMethod).join('\n')} }`;
  const js = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
  return new Function(...Object.keys(globals), js + '\nreturn Harness;')(...Object.values(globals));
}

test('the Home spacer keeps its expanded height while the overlay changes during a scroll', () => {
  const states = { Idle: 0, Scroll: 1, Fling: 2 };
  const Harness = indexHarness(['homeContentTopInset', 'homeHeaderCollapseDepth', 'onFeedScroll'], {
    HOME_TAB_INDEX: 0, HOME_HEADER_COLLAPSE_DEPTH_VP: 36, FAB_SWITCH_DEPTH: 160,
    RootTitleBarLayout: layout, ScrollState: states
  });
  let offset = 0;
  const root = Object.assign(new Harness(), { currentTab: 0, statusBarHeight: 32, homeHeaderCollapseEnabled: true,
    homeHeaderCollapsed: false, autoHideFab: true, isDesktopLayout: () => false, supportsHdsNavigation: () => true,
    useTitleBarLogo: () => true, homeSpaceHeight: () => 0, rootTitleBarContentClearance: () => 0,
    getHomeScroller: () => ({ currentOffset: () => ({ yOffset: offset }) }), currentHomeOffset: () => offset,
    rememberHomeVisibleItem: () => {},
    setHomeHeaderCollapsed: collapsed => { root.homeHeaderCollapsed = collapsed; }, onChromeScroll: () => {} });
  assert.match(indexMethod('HomeStatusLine'), /height\(this\.homeContentTopInset\(false\)\)/);
  assert.equal(root.homeContentTopInset(false), 136);
  assert.equal(root.homeHeaderCollapseDepth(), 96);
  offset = 180;
  root.onFeedScroll(180, states.Scroll);
  assert.equal(root.homeHeaderCollapsed, true);
  assert.equal(root.homeContentTopInset(false), 136);
  offset = 115;
  root.onFeedScroll(-65, states.Scroll);
  assert.equal(root.homeHeaderCollapsed, false);
  root.onFeedScroll(96, states.Idle);
  assert.equal(root.homeHeaderCollapsed, false);
  offset = 180;
  root.onFeedScroll(65, states.Scroll);
  assert.equal(root.homeHeaderCollapsed, true);
  offset = 0;
  root.onFeedScroll(-180, states.Idle);
  assert.equal(root.homeHeaderCollapsed, false);
});

test('the Home refresh gesture and spinner use the same threshold', () => {
  const home = indexMethod('HomeTab');
  assert.match(home, /\.refreshOffset\(HOME_REFRESH_TRIGGER_OFFSET_VP\)/);
  assert.match(home, /triggerOffset: HOME_REFRESH_TRIGGER_OFFSET_VP/);
  const distance = Number(/const HOME_REFRESH_TRIGGER_OFFSET_VP = (\d+)/.exec(indexSource)?.[1]);
  assert.ok(distance > 64);
});

test('home chrome finishes fading before the native title slot is hidden', () => {
  const completions = [];
  const Harness = indexHarness(['setHomeHeaderCollapsed'], { Curve: { EaseInOut: 'ease' } });
  const root = Object.assign(new Harness(), { homeHeaderCollapsed: false, homeHeaderParked: false,
    homeHeaderMotion: 0, reduceMotion: false, preferredMotionDuration: 300,
    getUIContext: () => ({ animateTo: (options, update) => { update(); completions.push(options.onFinish); } }) });
  root.setHomeHeaderCollapsed(true);
  assert.equal(root.homeHeaderCollapsed, true);
  assert.equal(root.homeHeaderParked, false);
  root.setHomeHeaderCollapsed(false);
  completions.shift()();
  assert.equal(root.homeHeaderParked, false);
  root.setHomeHeaderCollapsed(true);
  completions.pop()();
  assert.equal(root.homeHeaderParked, true);
  root.setHomeHeaderCollapsed(false);
  assert.equal(root.homeHeaderParked, false);
});

test('rightward drags open the drawer from For You in portrait without claiming a photo strip', () => {
  const Harness = indexHarness(['canOpenDrawerFromHome', 'judgeHomeDrawerSwipe', 'finishHomeDrawerSwipe'], {
    HOME_TAB_INDEX: 0, POST_SWIPE_OFF: 0, SourceType: { TouchScreen: 'touch' },
    GestureJudgeResult: { REJECT: false, CONTINUE: true }, GestureControl: { GestureType: { PAN_GESTURE: 1 } }
  });
  let opened = 0;
  const root = Object.assign(new Harness(), { currentTab: 0, homeFeedMode: 0, activeHomeTopicId: '',
    windowWidth: 390, windowHeight: 844, showSideDrawer: false, refreshing: false, postSwipeRight: 0,
    navPathStack: { size: () => 0 }, isDesktopLayout: () => false, openSideDrawer: () => opened++ });
  const event = { source: 'touch' };
  const gesture = { getTag: () => 'home-open-drawer', isBuiltIn: () => false };
  const pager = { getTag: () => '', isBuiltIn: () => true, getType: () => 1,
    getEventTargetInfo: () => ({ getId: () => 'home-feed-pager' }) };
  assert.equal(root.homeDrawerSwipeStarted, undefined);
  assert.equal(root.judgeHomeDrawerSwipe({ ...event, offsetX: 6 }, pager, []), false);
  assert.equal(root.judgeHomeDrawerSwipe({ ...event, offsetX: -6 }, pager, []), true);
  assert.equal(root.judgeHomeDrawerSwipe(event, gesture, [{
    getEventTargetInfo: () => ({ getId: () => 'post-photo-list-0' })
  }]), false);
  assert.equal(root.judgeHomeDrawerSwipe(event, gesture, []), true);
  root.homeDrawerSwipeStarted = true;
  root.finishHomeDrawerSwipe({ offsetX: 65, offsetY: 20 });
  assert.equal(opened, 1);
  root.homeFeedMode = 1;
  assert.equal(root.judgeHomeDrawerSwipe(event, gesture, []), false);
  assert.equal(root.judgeHomeDrawerSwipe({ ...event, offsetX: 6 }, pager, []), true);
  root.homeFeedMode = 0;
  root.windowWidth = 1100;
  assert.equal(root.judgeHomeDrawerSwipe(event, gesture, []), false);
});

test('compact header removes the displaced rows while retaining Explore categories', () => {
  for (const [tab, normal, compact] of [[0, 54, 12], [1, 100, 64], [2, 52, 12], [3, 56, 12], [4, 0, 12]]) {
    assert.equal(layout.bottomHeight(tab, true, false, 0, false), normal);
    assert.equal(layout.bottomHeight(tab, false, false, 0, false), compact);
  }
  assert.equal(layout.bottomHeight(0, true, false, 0, false),
    layout.labelsHeight(0, true, 0, false));
  assert.equal(layout.labelsHeight(2, true, 0, false), 52);
  assert.equal(layout.labelsHeight(2, false, 0, false), 0);
  assert.equal(layout.labelsHeight(1, false, 0, false), 52);
  assert.equal(layout.bottomHeight(1, false, false, 0, true), 12);
  assert.equal(layout.labelsHeight(1, false, 0, true), 0);
});

test('home Space recommendations remain below the compact identity row without a timeline gap', () => {
  assert.equal(layout.bottomHeight(0, false, false, 60, false), 72);
  assert.equal(layout.labelsHeight(0, false, 60, false), 60);
  assert.equal(layout.contentTopInset(0, false, 32, false, 60), 168);
  assert.equal(layout.bottomHeight(0, true, true, 60, false), 0);
  assert.equal(layout.labelsHeight(0, true, 60, false), 114);
});

test('feed avoidance follows the visible controls in both settings', () => {
  for (const tab of [0, 2, 3]) {
    assert.equal(layout.contentTopInset(tab, false, 32, false, 0), 108);
  }
  assert.equal(layout.contentTopInset(0, true, 32, false, 0), 136);
  assert.equal(layout.contentTopInset(0, true, 32, true, 0), 40);
  assert.equal(layout.contentTopInset(2, true, 32, false, 0), 148);
  assert.equal(layout.contentTopInset(3, true, 32, false, 0), 144);
  assert.equal(layout.contentTopInset(1, true, 32, false, 0) -
    layout.contentTopInset(1, false, 32, false, 0), 36);
});

test('large-screen content starts below the full page indicator and Space capsule', () => {
  for (const status of [0, 32]) {
    for (const [tab, logo, space] of [[0, true, 0], [0, true, 60], [0, false, 60],
      [1, true, 0], [1, false, 0], [2, true, 0]]) {
      const edge = (tab === 1 ? 0 : status) + layout.labelsOffset(tab, logo) +
        layout.labelsHeight(tab, logo, space, false);
      assert.ok(layout.contentTopInset(tab, logo, status, false, space, 8) >= edge + 8,
        `Tab ${tab}, logo ${logo}, status ${status}, Space ${space}`);
    }
    assert.equal(layout.contentTopInset(0, true, status, true, 0, 8), status + 8);
    for (const tab of [0, 2, 3, 4]) {
      assert.equal(layout.contentTopInset(tab, false, status, false, 0, 8), status + 76);
    }
  }
});

function appearanceFixture(initial = {}) {
  const values = new Map(Object.entries(initial));
  const pref = { getSync: (key, fallback) => values.has(key) ? values.get(key) : fallback,
    putSync: (key, value) => values.set(key, value), flushSync() {} };
  const f = load('entry/src/main/ets/services/AppearanceStore.ets', {
    '@kit.AbilityKit': { ConfigurationConstant: {} },
    '@kit.BasicServicesKit': { deviceInfo: { deviceType: 'phone' } },
    '@kit.ArkData': { preferences: { getPreferencesSync: () => pref } },
    '../utils/AccentPalette': load('entry/src/main/ets/utils/AccentPalette.ets')
  });
  return { ...f, store: new f.AppearanceStore(), values };
}

test('existing installations retain the logo and compact choice survives other appearance saves', () => {
  const f = appearanceFixture();
  const settings = f.store.load({});
  assert.equal(settings.titleBarLogoEnabled, true);
  assert.equal(settings.titleBarLogoAutoContrast, true);
  settings.titleBarLogoEnabled = false;
  settings.titleBarLogoAutoContrast = false;
  f.store.save({}, settings);
  assert.equal(f.values.get('title_bar_logo'), false);
  assert.equal(f.values.get('title_bar_logo_auto_contrast'), false);
  const restored = f.store.load({});
  assert.equal(restored.titleBarLogoEnabled, false);
  assert.equal(restored.titleBarLogoAutoContrast, false);
  restored.accentColor = '#AB1234';
  restored.autoHideFab = false;
  f.store.save({}, restored);
  assert.equal(f.store.load({}).titleBarLogoEnabled, false);
  assert.equal(f.store.load({}).titleBarLogoAutoContrast, false);
  restored.titleBarLogoEnabled = true;
  restored.titleBarLogoAutoContrast = true;
  f.store.save({}, restored);
  assert.equal(f.store.load({}).titleBarLogoEnabled, true);
  assert.equal(f.store.load({}).titleBarLogoAutoContrast, true);
});

test('title-bar logo uses matching transparent SVG marks for light and dark modes', () => {
  const logoSource = fs.readFileSync('entry/src/main/ets/components/RootTitleBarLogo.ets', 'utf8');
  const iconSource = fs.readFileSync('entry/src/main/ets/services/AppIconStore.ets', 'utf8');
  assert.match(logoSource, /titleBarLogoForeground\(this\.iconName\)/);
  assert.match(logoSource, /STORAGE_KEY_TITLE_BAR_LOGO_AUTO_CONTRAST/);
  assert.match(logoSource, /APP_ICON_X_BLACK/);
  assert.match(logoSource, /APP_ICON_X_WHITE/);
  assert.match(logoSource, /if \(this\.shouldTintX\(\)\)/);
  assert.match(logoSource, /titleBarLogoForeground\(this\.isDarkMode\(\) \? APP_ICON_X_WHITE : APP_ICON_X_BLACK\)/);
  assert.match(iconSource, /if \(name === APP_ICON_DEFAULT \|\| name === APP_ICON_X_BLACK\) \{\s*return \$r\('app\.media\.title_bar_logo_foreground'\);/);
  const dark = fs.readFileSync('entry/src/main/resources/base/media/title_bar_logo_foreground.svg', 'utf8');
  const light = fs.readFileSync('entry/src/main/resources/base/media/title_bar_logo_white.svg', 'utf8');
  assert.match(dark, /<path d="[^"]+" fill="#000000"/);
  assert.equal(dark.replace('fill="#000000"', 'fill="white"'), light);
});

test('special icon foregrounds bypass the X-only monochrome filter', () => {
  const logoSource = fs.readFileSync('entry/src/main/ets/components/RootTitleBarLogo.ets', 'utf8');
  assert.match(logoSource, /return this\.autoContrast && \(this\.iconName === APP_ICON_DEFAULT/);
  assert.match(logoSource, /this\.iconName === APP_ICON_X_BLACK/);
  assert.match(logoSource, /this\.iconName === APP_ICON_X_WHITE/);
  assert.match(logoSource, /else \{\s*Image\(titleBarLogoForeground\(this\.iconName\)\)/s);
});

test('every selectable app icon has a packaged foreground for title-bar tinting', () => {
  const source = fs.readFileSync('entry/src/main/ets/services/AppIconStore.ets', 'utf8');
  const mappings = [
    ['classic', 'app_icon_classic_foreground'],
    ['spectrum', 'app_icon_spectrum_foreground'],
    ['outline', 'app_icon_outline_foreground'],
    ['brush', 'app_icon_brush_foreground'],
    ['blossom', 'app_icon_blossom_foreground'],
    ['blue_bird', 'app_icon_blue_bird_foreground'],
    ['twitter_blue', 'app_icon_twitter_blue_foreground'],
    ['twitter_white', 'app_icon_twitter_white_foreground'],
    ['x_black', 'app_icon_x_black_foreground'],
    ['x_white', 'app_icon_x_white_foreground'],
    ['frog_white', 'frog_foreground'],
    ['frog_black', 'frog_foreground'],
    ['zombie_x', 'zombie_x_foreground'],
    ['mid_autumn', 'app_icon_mid_autumn_foreground']
  ];
  for (const [name, resource] of mappings) {
    assert.match(source, new RegExp(name));
    assert.match(source, new RegExp(`app\.media\.${resource}`));
    assert.ok(fs.existsSync(`AppScope/resources/base/media/${resource}.png`), resource);
  }
});

test('adaptive logo color resources exist in every locale', () => {
  const root = 'entry/src/main/resources';
  const localeDirs = fs.readdirSync(root).filter(name => {
    const file = `${root}/${name}/element/string.json`;
    return fs.existsSync(file);
  });
  assert.ok(localeDirs.length >= 20);
  for (const locale of localeDirs) {
    const strings = JSON.parse(fs.readFileSync(`${root}/${locale}/element/string.json`, 'utf8')).string;
    assert.ok(strings.some(item => item.name === 'settings_title_bar_logo_auto_contrast'), locale);
    assert.ok(strings.some(item => item.name === 'settings_title_bar_logo_auto_contrast_desc'), locale);
  }
});

test('compact button choice persists across logo toggles and unrelated display changes', () => {
  const f = appearanceFixture();
  const settings = f.store.load({});
  assert.equal(settings.compactSwitchStyle, f.COMPACT_SWITCH_TABS);
  settings.compactSwitchStyle = f.COMPACT_SWITCH_BUTTONS;
  settings.titleBarLogoEnabled = false;
  f.store.save({}, settings);
  const restarted = f.store.load({});
  assert.equal(restarted.compactSwitchStyle, f.COMPACT_SWITCH_BUTTONS);
  restarted.titleBarLogoEnabled = true;
  restarted.fontScale = 1.25;
  f.store.save({}, restarted);
  assert.equal(f.store.load({}).compactSwitchStyle, f.COMPACT_SWITCH_BUTTONS);
  restarted.compactSwitchStyle = f.COMPACT_SWITCH_TABS;
  f.store.save({}, restarted);
  assert.equal(f.store.load({}).compactSwitchStyle, f.COMPACT_SWITCH_TABS);
});

test('invalid compact styles migrate to tabs without discarding the hidden logo choice', () => {
  for (const value of ['other', '', 1, true]) {
    const f = appearanceFixture({ compact_switch_style: value, title_bar_logo: false });
    const settings = f.store.load({});
    assert.equal(settings.compactSwitchStyle, f.COMPACT_SWITCH_TABS);
    assert.equal(settings.titleBarLogoEnabled, false);
  }
});

test('native segmented tabs survive restart, logo toggles and unrelated appearance saves', () => {
  const f = appearanceFixture({ compact_switch_style: 'segmented', title_bar_logo: false });
  const settings = f.store.load({});
  assert.equal(settings.compactSwitchStyle, f.COMPACT_SWITCH_SEGMENTED);
  settings.titleBarLogoEnabled = true;
  settings.fontScale = 1.25;
  f.store.save({}, settings);
  const restarted = f.store.load({});
  assert.equal(restarted.compactSwitchStyle, f.COMPACT_SWITCH_SEGMENTED);
  assert.equal(restarted.titleBarLogoEnabled, true);
  restarted.titleBarLogoEnabled = false;
  f.store.save({}, restarted);
  assert.equal(f.values.get('compact_switch_style'), 'segmented');
  for (const style of [f.COMPACT_SWITCH_TABS, f.COMPACT_SWITCH_BUTTONS, f.COMPACT_SWITCH_SEGMENTED]) {
    restarted.compactSwitchStyle = style;
    f.store.save({}, restarted);
    assert.equal(f.store.load({}).compactSwitchStyle, style);
  }
});

const { XNotificationParser: parser } = load('entry/src/main/ets/services/XNotificationParser.ets', {
  './XTimelineParser': require('./post-card-fixture.cjs').load('services/XTimelineParser'),
  '../utils/UserIdentity': load('entry/src/main/ets/utils/UserIdentity.ets'),
  '@ohos.hilog': { default: { info() {}, warn() {}, error() {} } }
});
const { NotificationFilters: filters } = load('entry/src/main/ets/utils/NotificationFilters.ets');
const user = (id, fields = {}) => ({ user_results: { result: { rest_id: id,
  core: { name: id, screen_name: id }, ...fields } } });
const row = (id, icon, users) => ({ entryId: id, content: { itemContent: {
  __typename: 'TimelineNotification', icon, rich_message: { text: id }, template: { from_users: users }
} } });
function notifications(entries) {
  return parser.parsePage(JSON.stringify({ data: { notification_timeline: {
    instructions: [{ type: 'TimelineAddEntries', entries }]
  } } }));
}

test('notification tabs filter real actor flags and preserve the unfiltered page and cursors', () => {
  const page = notifications([
    row('mention', 'mention', [user('a')]),
    row('reply', 'reply', [user('b', { verification: { is_blue_verified: true } })]),
    row('like', 'heart', [user('c'), user('d', { legacy: { verified: true } })]),
    row('unknown', 'person', []),
    { content: { entryType: 'TimelineTimelineCursor', cursorType: 'Bottom', value: 'more' } }
  ]);
  assert.ok(page);
  assert.equal(page.cursor, 'more');
  assert.equal(page.items.length, 4);
  assert.equal(filters.apply(page.items, 0), page.items);
  assert.deepEqual(filters.apply(page.items, 1).map(row => row.id), ['mention', 'reply']);
  assert.deepEqual(filters.apply(page.items, 2).map(row => row.id), ['reply', 'like']);
  assert.equal(page.items.length, 4);
  assert.equal(filters.apply(page.items, 2).every(row => row.fromVerifiedAccount), true);
});

test('organization and direct blue verification are accepted and absent flags stay unverified', () => {
  const page = notifications([
    row('organization', 'person', [user('a', { verification: { is_verified_organization: true } })]),
    row('blue', 'heart', [user('b', { is_blue_verified: true })]),
    row('plain', 'heart', [user('c', { verification: { is_blue_verified: false } })])
  ]);
  assert.deepEqual(filters.apply(page.items, 2).map(row => row.id), ['organization', 'blue']);
});
