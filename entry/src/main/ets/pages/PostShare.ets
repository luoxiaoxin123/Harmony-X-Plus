import { image } from '@kit.ImageKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { Tweet, MediaAttachment } from '../models/Tweet';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { ProxyMediaImage } from '../components/ProxyMediaImage';

export interface PostShareRoute {
  post: Tweet;
  includeReplies?: boolean;
}

@Builder
export function PostShareBuilder(): void { PostSharePage() }

@Component
struct PostSharePage {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.status_bar_height') private top: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private bottom: number = 0;
  @State private route: PostShareRoute | null = null;
  @State private copying: boolean = false;

  private screenshotPosts(): Tweet[] {
    if (this.route === null) { return []; }
    const post: Tweet = this.route.post;
    if (this.route.includeReplies === false) { return [post]; }
    const posts: Tweet[] = (post.replyContext ?? []).filter((ancestor: Tweet): boolean => ancestor.id !== post.id).slice(-9);
    posts.push(post);
    return posts;
  }

  private async copySnapshot(): Promise<void> {
    if (this.copying) { return; }
    this.copying = true;
    let pixels: image.PixelMap | undefined;
    try {
      pixels = await this.getUIContext().getComponentSnapshot().get('post-share-screenshot',
        { waitUntilRenderFinished: true, scale: 1.5 });
      await pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_PIXELMAP, pixels));
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.photo_copied') });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.photo_copy_failed') });
    } finally {
      if (pixels !== undefined) { try { await pixels.release(); } catch (error) {} }
      this.copying = false;
    }
  }

  @Builder
  private ScreenshotPreview(): void {
    Column({ space: 16 }) {
      ForEach(this.screenshotPosts(), (post: Tweet): void => {
        Column({ space: 8 }) {
          Text(post.author.name).fontFamily(this.appFontFamily).fontWeight(FontWeight.Bold).width('100%')
          Text('@' + post.author.username).fontFamily(this.appFontFamily).fontSize(13)
            .fontColor($r('app.color.text_secondary')).width('100%')
          Text(post.text).fontFamily(this.appFontFamily).fontSize(16).width('100%')
          ForEach((post.attachments ?? []).filter((item: MediaAttachment): boolean => item.type === 'photo').slice(0, 4),
            (item: MediaAttachment): void => {
              Stack() { ProxyMediaImage({ url: item.previewUrl || item.mediaUrl, fillParent: true }) }
                .width('100%').height(150).clip(true).borderRadius(12)
            }, (item: MediaAttachment): string => item.id)
        }.width('100%').alignItems(HorizontalAlign.Start).padding(14)
          .borderRadius(14).backgroundColor($r('app.color.bg_card'))
      }, (post: Tweet): string => post.id)
    }.width('100%').constraintSize({ maxWidth: 470 }).padding(12)
      .backgroundColor($r('app.color.bg_page')).id('post-share-screenshot')
  }

  build(): void {
    HdsNavDestination() {
      Column({ space: 8 }) {
        if (this.route !== null) {
          Row({ space: 8 }) {
            Button($r('app.string.post_share_copy_screenshot')).enabled(!this.copying)
              .onClick((): void => { void this.copySnapshot(); })
          }.width('100%').justifyContent(FlexAlign.Center)
        }
        Scroll() {
          if (this.route !== null) { this.ScreenshotPreview() }
        }.width('100%').layoutWeight(1)
      }.width('100%').height('100%').padding({ top: this.top + 56, bottom: this.bottom })
      .backgroundColor($r('app.color.bg_page'))
    }.titleMode(HdsNavDestinationTitleMode.MINI)
      .titleBar({ content: { title: { mainTitle: $r('app.string.post_share_screenshot') } } })
      .onReady((context: NavDestinationContext): void => {
        const route: PostShareRoute | undefined = context.pathInfo.param as PostShareRoute | undefined;
        if (route?.post !== undefined) { this.route = route; }
      })
  }
}
