import { LengthMetrics } from '@kit.ArkUI';
import type { Tweet, MediaAttachment } from '../models/Tweet';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { ProxyAvatar } from './ProxyAvatar';
import { activateInputKey } from '../utils/InputSupport';

@Component
export struct DeviceTimeline {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.status_bar_height') private statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private bottomInset: number = 0;
  @Prop watch: boolean = false;
  @Prop signedIn: boolean = false;
  @Prop activeFeed: number = 0;
  @Prop posts: Tweet[] = [];
  @Prop refreshing: boolean = false;
  private scroller: Scroller = new Scroller();
  onFocusItem: (id: string) => void = (_id: string): void => {};
  onFeed: (mode: number) => void = (_mode: number): void => {};
  onOpen: (post: Tweet) => void = (_post: Tweet): void => {};
  onVideo: (post: Tweet, item: MediaAttachment) => void = (_post: Tweet, _item: MediaAttachment): void => {};
  onSection: (section: string) => void = (_section: string): void => {};
  onMore: () => void = (): void => {};

  private watchInset(): number { return this.watch ? 24 : 48; }

  @Builder
  private Shortcut(label: Resource, key: string): void {
    Button(label).constraintSize({ minHeight: this.watch ? 42 : 52 })
      .fontFamily(this.appFontFamily).id('device-' + key)
      .onFocus((): void => this.onFocusItem('device-' + key))
      .onClick((): void => this.onSection(key))
  }

  @Builder
  private Post(post: Tweet): void {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        ProxyAvatar({ url: post.author.avatarUrl ?? '', avatarSize: 34, radius: 17,
          fallbackText: post.author.name.slice(0, 1), fallbackColor: post.author.avatarColor })
        Text(post.author.name).fontFamily(this.appFontFamily)
          .fontSize(this.watch ? 15 : 21).fontWeight(FontWeight.Medium)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.width('100%')
      Text(post.text.length > 0 ? post.text : '@' + post.author.username)
        .width('100%').fontFamily(this.appFontFamily).fontSize(this.watch ? 14 : 20)
        .maxLines(this.watch ? 3 : 4).textOverflow({ overflow: TextOverflow.Ellipsis })
    }.width('100%').padding(this.watch ? 14 : 20).borderRadius(this.watch ? 25 : 18)
      .backgroundColor($r('app.color.bg_card')).alignItems(HorizontalAlign.Start)
      .id('device-post-' + post.id).focusable(true).focusOnTouch(true).accessibilityGroup(true)
      .onFocus((): void => this.onFocusItem('device-post-' + post.id))
      .onKeyEvent((event: KeyEvent): boolean => activateInputKey(event, (): void => this.onOpen(post)))
      .onClick((): void => this.onOpen(post))
  }

  build(): void {
    List({ scroller: this.scroller, space: this.watch ? 8 : 14 }) {
      ListItem() {
        Column({ space: 8 }) {
          Text($r('app.string.home_title')).fontFamily(this.appFontFamily)
            .fontSize(this.watch ? 19 : 32).fontWeight(FontWeight.Bold).width('100%')
          if (this.signedIn) {
            Row({ space: 6 }) {
              Button($r('app.string.home_for_you')).defaultFocus(true).id('device-for-you')
                .type(ButtonType.Capsule).fontSize(this.watch ? 12 : 17)
                .fontWeight(this.activeFeed === 0 ? FontWeight.Bold : FontWeight.Normal)
                .constraintSize({ minHeight: 42 })
                .onFocus((): void => this.onFocusItem('device-for-you')).onClick((): void => this.onFeed(0))
              Button($r('app.string.home_following')).id('device-following')
                .type(ButtonType.Capsule).fontSize(this.watch ? 12 : 17)
                .fontWeight(this.activeFeed === 1 ? FontWeight.Bold : FontWeight.Normal)
                .constraintSize({ minHeight: 42 })
                .onFocus((): void => this.onFocusItem('device-following')).onClick((): void => this.onFeed(1))
            }.justifyContent(FlexAlign.Center).width('100%')
          } else {
            this.Shortcut($r('app.string.login_title'), 'login')
          }
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, space: { main: LengthMetrics.vp(6), cross: LengthMetrics.vp(6) } }) {
            this.Shortcut($r('app.string.search_action'), 'search')
            this.Shortcut($r('app.string.tab_alerts'), 'alerts')
            if (this.watch) {
              this.Shortcut($r('app.string.side_bookmarks'), 'bookmarks')
              this.Shortcut($r('app.string.messages_title'), 'messages')
              this.Shortcut($r('app.string.side_spaces'), 'spaces')
              this.Shortcut($r('app.string.action_reply'), 'compose')
            }
            this.Shortcut($r('app.string.device_full_features'), 'full')
          }.width('100%')
        }.width('100%').alignItems(HorizontalAlign.Center)
      }
      ForEach(this.posts, (post: Tweet): void => {
        ListItem() {
          Column({ space: 4 }) {
            this.Post(post)
            if (this.watch && (post.attachments ?? []).some((item: MediaAttachment): boolean => item.type === 'video')) {
              Button($r('app.string.compose_video_label')).constraintSize({ minHeight: 42 })
                .onClick((): void => {
                  const item: MediaAttachment | undefined = (post.attachments ?? []).find(
                    (media: MediaAttachment): boolean => media.type === 'video');
                  if (item !== undefined) { this.onVideo(post, item); }
                })
            }
          }.width('100%')
        }
      }, (post: Tweet): string => post.id)
      if (this.refreshing) {
        ListItem() { LoadingProgress().width(30).height(30).margin(12) }
      }
    }.width('100%').height('100%').padding({ left: this.watchInset(), right: this.watchInset() })
      .contentStartOffset(this.statusBarHeight + 12).contentEndOffset(this.bottomInset + 16)
      .scrollBar(BarState.Off).focusable(true).focusOnTouch(true).onReachEnd(this.onMore)
  }
}
