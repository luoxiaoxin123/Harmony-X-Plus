import { common } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { DISPLAY_MODE_DARK, DISPLAY_MODE_LIGHT, DISPLAY_MODE_SYSTEM } from '../services/AppearanceStore';
import { WebProxyCredential, proxyStore } from '../services/ProxyStore';
import { xUserAgent } from '../services/XUserAgent';
import { pageSurfaceColor } from '../utils/ThemeColors';

export const X_LOGIN_URL: string = 'https://x.com/i/flow/login';
const FIRST_PAINT_TIMEOUT_MS: number = 20000;
type LoginWebStage = 'preparing' | 'loading' | 'ready' | 'failed';

@Component
export struct XLoginWebContent {
  @Prop url: string = X_LOGIN_URL;
  @Prop insideSheet: boolean = false;
  onPageLoaded: () => void = (): void => {};
  onIntercept: (url: string) => boolean = (): boolean => false;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') private displayMode: string = DISPLAY_MODE_SYSTEM;
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @State private stage: LoginWebStage = 'preparing';
  @State private failureMessage: Resource = $r('app.string.auth_web_load_failed');
  @State private failureDetail: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();
  private readonly userAgent: string = xUserAgent.value();
  private attempt: number = 0;
  private paintTimer: number = -1;
  private active: boolean = false;

  aboutToAppear(): void {
    this.active = true;
    void this.load();
  }

  aboutToDisappear(): void {
    this.active = false;
    this.attempt++;
    this.stopPaintTimer();
  }

  private stopPaintTimer(): void {
    if (this.paintTimer >= 0) {
      clearTimeout(this.paintTimer);
      this.paintTimer = -1;
    }
  }

  private async load(): Promise<void> {
    const attempt: number = ++this.attempt;
    this.stopPaintTimer();
    this.stage = 'preparing';
    this.paintTimer = setTimeout((): void => {
      if (this.attempt === attempt) {
        this.fail($r('app.string.auth_web_paint_timeout'));
      }
    }, FIRST_PAINT_TIMEOUT_MS);
    try {
      await proxyStore.applyToWebStack();
      if (this.active && this.attempt === attempt && this.stage === 'preparing') {
        this.controller = new webview.WebviewController();
        this.stage = 'loading';
      }
    } catch (error) {
      if (this.attempt === attempt) { this.fail($r('app.string.auth_web_load_failed')); }
    }
  }

  private fail(message: Resource, detail: string = ''): void {
    if (!this.active || this.stage === 'failed') { return; }
    this.stopPaintTimer();
    this.failureMessage = message;
    this.failureDetail = detail;
    this.stage = 'failed';
  }

  private firstPaint(): void {
    if (!this.active || this.stage !== 'loading') { return; }
    this.stopPaintTimer();
    this.stage = 'ready';
  }

  private intercept(url: string): boolean {
    if (!this.active || !this.onIntercept(url)) { return false; }
    this.firstPaint();
    return true;
  }

  private webDarkMode(): WebDarkMode {
    if (this.displayMode === DISPLAY_MODE_DARK) { return WebDarkMode.On; }
    return this.displayMode === DISPLAY_MODE_LIGHT ? WebDarkMode.Off : WebDarkMode.Auto;
  }

  private async testInBrowser(): Promise<void> {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      await context.startAbility({ action: 'ohos.want.action.viewData', entities: ['entity.system.browsable'],
        uri: X_LOGIN_URL });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.login_browser_failed') });
    }
  }

  @Builder
  private ErrorContent(): void {
    Scroll() {
      Column({ space: 12 }) {
        Text(this.failureMessage).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
          .fontColor($r('app.color.text_primary')).textAlign(TextAlign.Center)
        if (this.failureDetail.length > 0) {
          Text(this.failureDetail).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
            .fontColor($r('app.color.text_secondary'))
        }
        Button($r('app.string.card_retry')).id('auth-web-retry').defaultFocus(true)
          .fontFamily(this.appFontFamily).backgroundColor(this.accentColor)
          .onClick((): void => { void this.load(); })
        Button($r('app.string.auth_web_test_browser')).fontFamily(this.appFontFamily)
          .fontColor(this.accentColor).backgroundColor(Color.Transparent)
          .onClick((): void => { void this.testInBrowser(); })
      }.width('100%').padding(16)
    }.width('100%').height('100%').align(Alignment.Center).scrollBar(BarState.Auto)
  }

  build(): void {
    Stack({ alignContent: Alignment.Center }) {
      if (this.stage === 'loading' || this.stage === 'ready') {
        // In the clipped onboarding sheet, draw with the ArkUI canvas.
        Web({ src: this.url, controller: this.controller,
          renderMode: this.insideSheet ? RenderMode.SYNC_RENDER : RenderMode.ASYNC_RENDER })
          .width('100%').height('100%')
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .userAgent(this.userAgent)
          .darkMode(this.webDarkMode())
          .forceDarkAccess(this.displayMode === DISPLAY_MODE_DARK)
          .backgroundColor(pageSurfaceColor(this.displayMode, this.darkSurface))
          .onHttpAuthRequest((event): boolean => {
            if (event === undefined || event === null) { return false; }
            const credential: WebProxyCredential = proxyStore.webCredential();
            if (!credential.usable) {
              event.handler.cancel();
              return false;
            }
            return event.handler.confirm(credential.username, credential.password);
          })
          .onErrorReceive((event): void => {
            const code: number = event.error.getErrorCode();
            // Redirects and cancelled navigations may report Chromium ERR_ABORTED.
            if (event.request.isMainFrame() && code !== -3) {
              const name: RegExpMatchArray | null = event.error.getErrorInfo().match(/\bERR_[A-Z0-9_]+\b/);
              this.fail($r('app.string.auth_web_load_failed'), name?.[0] ?? String(code));
            }
          })
          .onHttpErrorReceive((event): void => {
            const code: number = event.response.getResponseCode();
            if (event.request.isMainFrame() && code >= 400) {
              this.fail($r('app.string.auth_web_load_failed'), 'HTTP ' + code.toString());
            }
          })
          .onRenderExited((): void => { this.fail($r('app.string.auth_web_load_failed')); })
          .onFirstContentfulPaint((): void => { this.firstPaint(); })
          .onPageEnd((): void => { if (this.active) { this.onPageLoaded(); } })
          .onLoadIntercept((event): boolean => event !== undefined && this.intercept(event.data.getRequestUrl()))
      }
      if (this.stage === 'failed') {
        this.ErrorContent()
      } else if (this.stage !== 'ready') {
        Column({ space: 8 }) {
          LoadingProgress().width(24).height(24).color(this.accentColor)
          Text($r('app.string.auth_loading')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
        }.padding(16).borderRadius(16).backgroundColor(pageSurfaceColor(this.displayMode, this.darkSurface))
          .hitTestBehavior(HitTestMode.None)
      }
    }.width('100%').layoutWeight(1)
  }
}
