import { common, bundleManager } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { Tweet, MediaAttachment } from '../models/Tweet';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { ExternalSharePayload } from '../services/ExternalShareStore';
import { ProxyMediaImage } from '../components/ProxyMediaImage';
import { copyPostLink } from '../utils/PostLinkCopy';
import { postShareUrl, sharePost } from '../utils/SharePost';
import type { DmComposeRouteParam } from './DmCompose';

export interface PostShareRoute {
  post: Tweet;
  includeReplies?: boolean;
  preview?: boolean;
}

@Builder
export function PostShareBuilder(): void { PostSharePage() }

@Component
struct PostSharePage {
  @Consume('pageStack') private pageStack: NavPathStack;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.status_bar_height') private top: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private bottom: number = 0;
  @State private comment: string = '';
  @State private route: PostShareRoute | null = null;
  @State private snapshot: boolean = false;
  @State private copying: boolean = false;
  @State private telegramAvailable: boolean = false;
  @State private emailAvailable: boolean = false;

  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext; }

  private openRoute(route: PostShareRoute): void {
    if (route === undefined || route.post === undefined) { return; }
    this.route = route;
    this.snapshot = route.preview === true;
    try { this.telegramAvailable = bundleManager.canOpenLink('tg://msg_url'); } catch (error) {}
    try { this.emailAvailable = bundleManager.canOpenLink('mailto:'); } catch (error) {}
  }

  private async openApp(link: string): Promise<void> {
    try {
      await this.context().startAbility({ action: 'ohos.want.action.viewData', uri: link });
    } catch (error) { this.getUIContext().getPromptAction().showToast({ message: $r('app.string.share_failed') }); }
  }

  private startDirectMessage(post: Tweet): void {
    const payload: ExternalSharePayload = new ExternalSharePayload();
    payload.id = 'post-share-' + Date.now().toString();
    const message: string = this.comment.trim();
    payload.text = message.length > 0 ? message + '\n' + postShareUrl(post) : postShareUrl(post);
    const params: DmComposeRouteParam = { sharedPayload: payload };
    this.pageStack.pushPath({ name: 'DmCompose', param: params });
  }

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

  @Builder
  private ShareActions(post: Tweet): void {
    Column({ space: 12 }) {
      Text(post.text).maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        .fontFamily(this.appFontFamily)
      TextArea({ text: this.comment, placeholder: $r('app.string.post_share_message') }).height(80).maxLength(1000)
        .onChange((value: string): void => { this.comment = value; })
      Button($r('app.string.post_share_dm')).width('100%').onClick((): void => this.startDirectMessage(post))
      Button($r('app.string.post_link_copy')).width('100%')
        .onClick((): void => { void copyPostLink(this.getUIContext(), postShareUrl(post)); })
      Button($r('app.string.post_share_system')).width('100%')
        .onClick((): void => { void sharePost(this.context(), post); })
      Button($r('app.string.post_share_screenshot')).width('100%').onClick((): void => { this.snapshot = true; })
      if (this.telegramAvailable) {
        Button('Telegram').width('100%').onClick((): void => {
          void this.openApp('tg://msg_url?url=' + encodeURIComponent(postShareUrl(post)) + '&text=' + encodeURIComponent(this.comment));
        })
      }
      if (this.emailAvailable) {
        Button($r('app.string.post_share_email')).width('100%').onClick((): void => {
          void this.openApp('mailto:?body=' + encodeURIComponent((this.comment.trim() + '\n' + postShareUrl(post)).trim()));
        })
      }
    }.width('100%').constraintSize({ maxWidth: 560 }).padding(18)
  }

  build(): void {
    HdsNavDestination() {
      Column({ space: 8 }) {
        if (this.route !== null && this.snapshot) {
          Row({ space: 8 }) {
            Button($r('app.string.action_share')).onClick((): void => { this.snapshot = false; })
            Button($r('app.string.post_share_copy_screenshot')).enabled(!this.copying)
              .onClick((): void => { void this.copySnapshot(); })
          }.width('100%').justifyContent(FlexAlign.Center)
        }
        Scroll() {
          if (this.route !== null) {
            if (this.snapshot) { this.ScreenshotPreview() }
            else { this.ShareActions(this.route.post) }
          }
        }.width('100%').layoutWeight(1)
      }.width('100%').height('100%').padding({ top: this.top + 56, bottom: this.bottom })
      .backgroundColor($r('app.color.bg_page'))
    }.titleMode(HdsNavDestinationTitleMode.MINI)
      .titleBar({ content: { title: { mainTitle: $r('app.string.action_share') } } })
      .onReady((context: NavDestinationContext): void => this.openRoute(context.pathInfo.param as PostShareRoute))
  }
}
