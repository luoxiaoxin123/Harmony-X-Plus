import { webview } from '@kit.ArkWeb';
import { ColorMetrics } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { openExternalLink } from '../utils/PostEntities';

// Match a ticker in post text without interpreting prices, URL paths or
// snippets from the post as a symbol.
export function stockTicker(text: string): string {
  const body: string = text.replace(/https?:\/\/\S+/gi, '');
  const match: RegExpMatchArray | null = body.match(/(?:^|[^a-z0-9_$])\$([a-z]{1,6}(?:[.-][a-z]{1,3})?)(?![a-z0-9_])/i);
  return match === null ? '' : match[1].toUpperCase();
}

const WIDGET_URL: string = 'https://s.tradingview.com/embed-widget/symbol-overview/';
const CHART_URL: string = 'https://www.tradingview.com/chart/?symbol=';

@Component
export struct StockQuoteCard {
  @Prop @Watch('resetChart') symbol: string = '';
  @Prop initialExpanded: boolean = false;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @State private expanded: boolean = false;
  @State private dark: boolean = false;
  @State private ready: boolean = false;
  @State private failed: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();
  private chartGeneration: number = 0;
  private probeTimer: number = -1;

  aboutToAppear(): void {
    this.expanded = this.initialExpanded;
  }

  aboutToDisappear(): void { this.cancelProbe(); }

  onWillApplyTheme(theme: Theme): void {
    const dark: boolean = ColorMetrics.resourceColor(theme.colors.backgroundPrimary).red < 128;
    if (this.dark !== dark) {
      this.dark = dark;
      this.resetChart();
    }
  }

  private widgetUrl(): string {
    const config: string = JSON.stringify({
      symbols: [[this.symbol, this.symbol + '|1D']], width: '100%', height: '100%',
      dateRanges: ['1d|1'], colorTheme: this.dark ? 'dark' : 'light', isTransparent: false, autosize: true
    });
    return WIDGET_URL + '?locale=en&symbol=' + encodeURIComponent(this.symbol) +
      '&theme=' + (this.dark ? 'dark' : 'light') + '#' + encodeURIComponent(config);
  }

  private cancelProbe(): void {
    this.chartGeneration++;
    if (this.probeTimer >= 0) { clearTimeout(this.probeTimer); this.probeTimer = -1; }
  }

  private resetChart(): void {
    this.cancelProbe();
    this.ready = false;
    this.failed = false;
  }

  private probeChart(generation: number, deadline: number): void {
    this.probeTimer = setTimeout(async (): Promise<void> => {
      this.probeTimer = -1;
      if (generation !== this.chartGeneration) { return; }
      let rendered: boolean = false;
      try {
        rendered = await this.controller.runJavaScript(
          'Boolean(location.href === ' + JSON.stringify(this.widgetUrl()) +
          ' && document.querySelector("canvas") && document.body.innerText.trim())') === 'true';
      } catch (error) { }
      if (generation !== this.chartGeneration) { return; }
      if (rendered) { this.ready = true; }
      else if (Date.now() >= deadline) { this.failed = true; }
      else { this.probeChart(generation, deadline); }
    }, 500);
  }

  private openChart(): void {
    openExternalLink(this.getUIContext().getHostContext() as common.UIAbilityContext,
      CHART_URL + encodeURIComponent(this.symbol));
  }

  build(): void {
    Column() {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 8 }) {
          Text('$' + this.symbol).fontFamily(this.appFontFamily).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.post_stock_quote')).fontFamily(this.appFontFamily).layoutWeight(1)
            .fontColor($r('app.color.text_secondary'))
          SymbolGlyph(this.expanded ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
            .fontSize(16).fontColor([$r('app.color.text_secondary')])
        }.width('100%')
      }.backgroundColor(Color.Transparent).width('100%').height(38).padding({ left: 10, right: 10 })
        .onClick((): void => { this.resetChart(); this.expanded = !this.expanded; }).monopolizeEvents(true)
      if (this.expanded) {
        if (this.failed) {
          Row({ space: 12 }) {
            Button($r('app.string.common_retry')).fontFamily(this.appFontFamily)
              .fontColor($r('app.color.text_primary')).backgroundColor(Color.Transparent)
              .onClick((): void => this.resetChart()).monopolizeEvents(true)
            Button('TradingView ↗').fontFamily(this.appFontFamily)
              .fontColor($r('app.color.text_primary')).backgroundColor(Color.Transparent)
              .onClick((): void => this.openChart()).monopolizeEvents(true)
          }.width('100%').justifyContent(FlexAlign.Center)
        } else {
          Stack({ alignContent: Alignment.Center }) {
            Web({ src: this.widgetUrl(), controller: this.controller, incognitoMode: true })
              .width('100%').height(180).opacity(this.ready ? 1 : 0)
              .javaScriptAccess(true).fileAccess(false).mixedMode(MixedMode.None)
              .monopolizeEvents(true)
              .onControllerAttached((): void => {
                this.cancelProbe();
                this.probeChart(this.chartGeneration, Date.now() + 12000);
              })
              .onPageBegin((): void => {
                this.resetChart();
                this.probeChart(this.chartGeneration, Date.now() + 12000);
              })
              .onLoadIntercept((event): boolean => {
                const url: string = event.data.getRequestUrl();
                if (event.data.isMainFrame()) { return url !== 'about:blank' && !url.startsWith(WIDGET_URL); }
                return !/^https:\/\/(?:[a-z0-9-]+\.)*(?:tradingview\.com|tradingview-widget\.com)(?:\/|$)/i.test(url);
              })
            if (!this.ready) {
              LoadingProgress().width(26).height(26).color($r('app.color.text_secondary'))
            }
          }.width('100%').height(180).clip(true)
        }
      }
    }.width('100%').border({ width: 1, color: $r('app.color.divider') }).borderRadius(12).clip(true)
  }
}
