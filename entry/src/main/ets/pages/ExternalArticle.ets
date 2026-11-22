import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo } from '@kit.CoreFileKit';
import { webview } from '@kit.ArkWeb';
import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { openExternalLink } from '../utils/PostEntities';

const READ_CONTENT: string = `(() => {
  const root = document.querySelector('article, [role="main"] article, main, [role="main"]');
  if (!root) return '';
  const copy = root.cloneNode(true);
  copy.querySelectorAll('script, style, noscript, nav, aside, footer, form, figure, [hidden], [aria-hidden="true"]')
    .forEach(node => node.remove());
  const blocks = [...copy.querySelectorAll('h2, h3, p, blockquote, pre, li')]
    .map(node => (node.textContent || '').replace(/\s+/g, ' ').trim()).filter(Boolean);
  const body = blocks.join('\n\n').slice(0, 180000);
  return body.length >= 120 ? JSON.stringify({ title: (root.querySelector('h1')?.textContent || document.title).trim(), body }) : '';
})()`;

interface ArticleContent {
  url: string;
  title: string;
  body: string;
}

@Builder
export function ExternalArticleBuilder(): void { ExternalArticlePage() }

@Component
struct ExternalArticlePage {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.status_bar_height') private top: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private bottom: number = 0;
  @State private url: string = '';
  @State private loading: boolean = false;
  @State private webActive: boolean = false;
  @State private saved: boolean = false;
  @State private title: string = '';
  @State private body: string = '';
  @State private fontSize: number = 18;
  private controller: webview.WebviewController = new webview.WebviewController();
  private scroller: Scroller = new Scroller();
  private attempt: number = 0;
  private timer: number = -1;
  private positionTimer: number = -1;
  private restoredOffset: number = 0;

  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext; }

  private store(): preferences.Preferences {
    return preferences.getPreferencesSync(this.context(), { name: 'harmonyx_external_articles' });
  }

  private documentKey(): string {
    let hash: number = 2166136261;
    for (let index: number = 0; index < this.url.length; index++) {
      hash = Math.imul(hash ^ this.url.charCodeAt(index), 16777619);
    }
    return (hash >>> 0).toString(16) + '-' + this.url.length.toString();
  }

  private filePath(): string { return this.context().filesDir + '/article-' + this.documentKey() + '.json'; }

  private loadSaved(): boolean {
    try {
      const article: ArticleContent = JSON.parse(fileIo.readTextSync(this.filePath())) as ArticleContent;
      if (article.url !== this.url || typeof article.body !== 'string' || typeof article.title !== 'string') { return false; }
      this.title = article.title;
      this.body = article.body;
      this.saved = true;
      return true;
    } catch (error) { return false; }
  }

  private saveArticle(): void {
    const article: ArticleContent = { url: this.url, title: this.title, body: this.body };
    const path: string = this.filePath();
    try {
      const file: fileIo.File = fileIo.openSync(path + '.tmp',
        fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.WRITE_ONLY);
      try { fileIo.writeSync(file.fd, JSON.stringify(article)); }
      finally { fileIo.closeSync(file.fd); }
      fileIo.renameSync(path + '.tmp', path);
      this.saved = true;
    } catch (error) {
      try { fileIo.unlinkSync(path + '.tmp'); } catch (cleanupError) {}
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.offline_save_failed') });
    }
  }

  private show(url: string): void {
    if (!/^https?:\/\//i.test(url) || url.length > 4096) { return; }
    this.url = url;
    try {
      const store: preferences.Preferences = this.store();
      this.fontSize = Math.max(14, Math.min(32, Number(store.getSync('font_size', 18))));
      const position: string = store.getSync('position_' + this.documentKey(), '') as string;
      const cut: number = position.lastIndexOf('|');
      if (cut > 0 && position.slice(0, cut) === this.url) { this.restoredOffset = Number(position.slice(cut + 1)); }
    } catch (error) {}
    if (!this.loadSaved()) { this.retry(); }
  }

  private retry(): void {
    this.clearLoadTimer();
    this.controller = new webview.WebviewController();
    const attempt: number = ++this.attempt;
    this.loading = true;
    this.webActive = true;
    this.timer = setTimeout((): void => { this.finishLoad(attempt); }, 16000);
  }

  private clearLoadTimer(): void {
    if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
  }

  private finishLoad(attempt: number): void {
    if (attempt !== this.attempt) { return; }
    this.clearLoadTimer();
    this.loading = false;
    this.webActive = false;
    this.attempt++;
  }

  private async extract(attempt: number): Promise<void> {
    try {
      const raw: string = await this.controller.runJavaScript(READ_CONTENT);
      if (attempt !== this.attempt) { return; }
      const decoded: string = JSON.parse(raw) as string;
      const article: ArticleContent = JSON.parse(decoded) as ArticleContent;
      if (typeof article.body !== 'string' || article.body.length < 120 || typeof article.title !== 'string') { return; }
      this.title = article.title.slice(0, 400);
      this.body = article.body.slice(0, 180000);
      this.finishLoad(attempt);
    } catch (error) { /* A later page-end event or the timeout handles this load. */ }
  }

  private adjustFont(step: number): void {
    this.fontSize = Math.max(14, Math.min(32, this.fontSize + step));
    try {
      const store: preferences.Preferences = this.store();
      store.putSync('font_size', this.fontSize);
      store.flushSync();
    } catch (error) {}
  }

  private savePosition(): void {
    if (this.positionTimer >= 0) { clearTimeout(this.positionTimer); this.positionTimer = -1; }
    if (this.body.length === 0) { return; }
    try {
      const offset: number = Math.max(0, Math.round(this.scroller.currentOffset().yOffset));
      const store: preferences.Preferences = this.store();
      store.putSync('position_' + this.documentKey(), this.url + '|' + offset.toString());
      store.flushSync();
    } catch (error) {}
  }

  aboutToDisappear(): void {
    this.clearLoadTimer();
    this.attempt++;
    this.savePosition();
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.webActive && this.url.length > 0) {
          Web({ src: this.url, controller: this.controller }).width(1).height(1).opacity(0)
            .javaScriptAccess(true).fileAccess(false).domStorageAccess(false)
            .onPageEnd((): void => { void this.extract(this.attempt); })
            .onErrorReceive((event): void => {
              if (event.request.isMainFrame()) { this.finishLoad(this.attempt); }
            })
            .onHttpErrorReceive((event): void => {
              if (event.request.isMainFrame() && event.response.getResponseCode() >= 400) { this.finishLoad(this.attempt); }
            })
        }
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            if (this.body.length > 0) {
              Button('A−').accessibilityText($r('app.string.external_article_smaller')).onClick((): void => this.adjustFont(-2))
              Button('A+').accessibilityText($r('app.string.external_article_larger')).onClick((): void => this.adjustFont(2))
              Button(this.saved ? $r('app.string.external_article_saved') : $r('app.string.external_article_save'))
                .enabled(!this.saved).onClick((): void => this.saveArticle())
            }
            Blank()
            Button($r('app.string.post_link_open')).enabled(this.url.length > 0)
              .onClick((): void => openExternalLink(this.context(), this.url))
          }.width('100%').padding({ left: 12, right: 12 })
          if (this.body.length > 0) {
            Scroll(this.scroller) {
              Column({ space: 14 }) {
                Text(this.title).fontFamily(this.appFontFamily).fontSize(this.fontSize + 8)
                  .fontWeight(FontWeight.Bold).width('100%')
                Text(this.body).fontFamily(this.appFontFamily).fontSize(this.fontSize).lineHeight(this.fontSize * 1.55)
                  .width('100%').copyOption(CopyOptions.LocalDevice)
              }.alignItems(HorizontalAlign.Start).constraintSize({ maxWidth: 760 }).padding(20)
            }.width('100%').layoutWeight(1)
              .onAppear((): void => {
                if (this.restoredOffset > 0) {
                  const offset: number = this.restoredOffset;
                  this.restoredOffset = 0;
                  setTimeout((): void => this.scroller.scrollTo({ xOffset: 0, yOffset: offset }), 80);
                }
              })
              .onDidScroll((): void => {
                if (this.positionTimer >= 0) { clearTimeout(this.positionTimer); }
                this.positionTimer = setTimeout((): void => this.savePosition(), 450);
              })
          } else {
            Column({ space: 12 }) {
              if (this.loading) {
                LoadingProgress().width(36).height(36)
              } else {
                Text($r('app.string.external_article_unavailable')).fontFamily(this.appFontFamily)
                Button($r('app.string.card_retry')).enabled(this.url.length > 0).onClick((): void => this.retry())
              }
            }.justifyContent(FlexAlign.Center).layoutWeight(1).width('100%').padding(16)
          }
        }.width('100%').height('100%').padding({ top: this.top + 56, bottom: this.bottom })
      }.width('100%').height('100%').backgroundColor($r('app.color.bg_page'))
    }.titleMode(HdsNavDestinationTitleMode.MINI)
      .titleBar({ content: { title: { mainTitle: $r('app.string.external_article_read') } } })
      .onReady((context: NavDestinationContext): void => this.show(String(context.pathInfo.param ?? '')))
  }
}
