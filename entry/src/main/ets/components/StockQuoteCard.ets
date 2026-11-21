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

@Component
export struct StockQuoteCard {
  @Prop symbol: string = '';
  @Prop initialExpanded: boolean = false;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @State private expanded: boolean = false;
  @State private dark: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();
  private chartOrigin: string = 'https://www.tradingview.com/chart/?symbol=';

  aboutToAppear(): void {
    this.expanded = this.initialExpanded;
  }

  onWillApplyTheme(theme: Theme): void {
    this.dark = ColorMetrics.resourceColor(theme.colors.backgroundPrimary).red < 128;
  }

  private loadChart(): void {
    if (!/^[A-Z]{1,6}(?:[.-][A-Z]{1,3})?$/.test(this.symbol)) { return; }
    const config: string = JSON.stringify({
      symbol: this.symbol, width: '100%', height: '100%', locale: 'en',
      dateRange: '1D', colorTheme: this.dark ? 'dark' : 'light', isTransparent: false, autosize: true
    });
    const html: string = '<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">' +
      '<style>html,body,.tradingview-widget-container{margin:0;height:100%;width:100%;overflow:hidden}' +
      '.tradingview-widget-container__widget{height:calc(100% - 24px)}' +
      '.tradingview-widget-copyright{text-align:center;font:12px sans-serif;padding-top:4px}</style></head>' +
      '<body><div class="tradingview-widget-container"><div class="tradingview-widget-container__widget"></div>' +
      '<div class="tradingview-widget-copyright"><a href="' + this.chartOrigin +
      encodeURIComponent(this.symbol) + '" rel="noopener">TradingView</a></div>' +
      '<script src="https://s3.tradingview.com/external-embedding/embed-widget-mini-symbol-overview.js" async>' +
      config + '</script></div></body></html>';
    this.controller.loadData(html, 'text/html', 'UTF-8', 'https://www.tradingview.com/');
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
        .onClick((): void => { this.expanded = !this.expanded; }).monopolizeEvents(true)
      if (this.expanded) {
        Web({ src: 'about:blank', controller: this.controller, incognitoMode: true })
          .width('100%').height(166)
          .javaScriptAccess(true).fileAccess(false).mixedMode(MixedMode.None)
          .monopolizeEvents(true)
          .onControllerAttached((): void => this.loadChart())
          .onLoadIntercept((event): boolean => {
            const url: string = event.data.getRequestUrl();
            if (event.data.isMainFrame() && url.startsWith(this.chartOrigin + encodeURIComponent(this.symbol))) {
              openExternalLink(this.getUIContext().getHostContext() as common.UIAbilityContext, url);
              return true;
            }
            return url !== 'about:blank' && !/^https:\/\/(?:[a-z0-9-]+\.)?tradingview\.com(?:\/|$)/i.test(url);
          })
      }
    }.width('100%').border({ width: 1, color: $r('app.color.divider') }).borderRadius(12).clip(true)
  }
}
