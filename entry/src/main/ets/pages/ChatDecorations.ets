import { common } from '@kit.AbilityKit';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { chatDecorationService, ChatDecorationInstall, ChatDecorationSelection } from '../services/ChatDecorationService';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { cardSurfaceColor, pageSurfaceColor, secondaryButtonSurfaceColor } from '../utils/ThemeColors';
import { xPrivateStore } from '../services/XPrivateStore';

export interface ChatDecorationsRouteParam {
  conversationId: string;
}

@Builder
export function ChatDecorationsBuilder(): void { ChatDecorationsPage(); }

@Component
struct ChatDecorationsPage {
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.status_bar_height') private statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private bottomInset: number = 0;
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.title_bar_style_mode') private titleBarStyleMode: number = 0;
  @StorageLink('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @Consume('pageStack') private pageStack: NavPathStack;
  @State private installedItems: ChatDecorationInstall[] = [];
  @State private selection: ChatDecorationSelection = new ChatDecorationSelection();
  @State private role: string = 'frame';
  private account: string = '';
  private active: boolean = true;
  private scroller: Scroller = new Scroller();

  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext; }

  private text(resource: Resource): string {
    return this.context().resourceManager.getStringSync(resource);
  }

  aboutToAppear(): void {
    this.active = true;
    this.account = xPrivateStore.load(this.context()).cacheIdentity();
    this.selection = chatDecorationService.selection(this.context());
    this.installedItems = chatDecorationService.listInstalled(this.context());
  }

  aboutToDisappear(): void { this.active = false; }

  private valid(): boolean {
    return this.active && this.account === xPrivateStore.load(this.context()).cacheIdentity();
  }

  private selectedId(): string {
    return this.role === 'frame' ? this.selection.frameId : this.selection.bubbleId;
  }

  private hasSelection(): boolean {
    return this.selection.frameId.length > 0 || this.selection.bubbleId.length > 0;
  }

  private toast(resource: Resource): void {
    this.getUIContext().getPromptAction().showToast({
      message: this.text(resource),
      duration: 1800
    });
  }

  private useItem(item: ChatDecorationInstall): void {
    if (!this.valid()) { return; }
    try {
      if (this.selectedId() === item.id) {
        this.selection = chatDecorationService.clear(this.context(), this.role);
      } else {
        this.selection = chatDecorationService.apply(this.context(), item, this.role);
        this.toast($r('app.string.chat_decoration_applied'));
      }
    } catch (error) {
      this.toast($r('app.string.chat_action_failed'));
    }
  }

  private reset(): void {
    if (!this.valid() || !this.hasSelection()) { return; }
    this.selection = chatDecorationService.clear(this.context(), 'frame');
    this.selection = chatDecorationService.clear(this.context(), 'bubble');
    this.toast($r('app.string.chat_decoration_reset_done'));
  }

  @Builder
  private RoleTabs(): void {
    Row() {
      Button($r('app.string.chat_decoration_frame'))
        .layoutWeight(1).height(42).borderRadius(21)
        .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
        .fontColor(this.role === 'frame' ? $r('app.color.text_on_accent') : $r('app.color.text_primary'))
        .backgroundColor(this.role === 'frame' ? this.accentColor : Color.Transparent)
        .onClick((): void => { this.role = 'frame'; })
      Button($r('app.string.chat_decoration_bubble'))
        .layoutWeight(1).height(42).borderRadius(21)
        .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
        .fontColor(this.role === 'bubble' ? $r('app.color.text_on_accent') : $r('app.color.text_primary'))
        .backgroundColor(this.role === 'bubble' ? this.accentColor : Color.Transparent)
        .onClick((): void => { this.role = 'bubble'; })
    }.width('100%').padding(3).borderRadius(24)
      .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
  }

  @Builder
  private FramePreview(item: ChatDecorationInstall): void {
    Stack({ alignContent: Alignment.Center }) {
      Column().width(72).height(72).borderRadius(36).backgroundColor(this.accentColor)
      Text(item.id.substring(0, 1).toUpperCase()).fontFamily(this.appFontFamily).fontSize(24)
        .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_on_accent'))
      Image(item.frameUri)
        .width(118).height(118).objectFit(ImageFit.Contain)
        .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
    }.width(122).height(122)
  }

  @Builder
  private BubblePreview(item: ChatDecorationInstall): void {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%').height(94).backgroundImage(item.bubbleUri)
        .backgroundImageSize({ width: '100%', height: '100%' })
        .backgroundImageResizable({ slice: {
          left: item.sliceLeft.toString() + 'px', right: item.sliceRight.toString() + 'px',
          top: item.sliceTop.toString() + 'px', bottom: item.sliceBottom.toString() + 'px'
        } })
      Text($r('app.string.chat_decoration_sample_text')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M')).fontColor(item.bubbleTextColor)
        .maxLines(2).textAlign(TextAlign.Center).padding({ left: 38, right: 38 })
    }.width('100%').height(94)
  }

  @Builder
  private ItemCard(item: ChatDecorationInstall): void {
    Column({ space: 14 }) {
      Row({ space: 8 }) {
        Text(item.id.replace(/-/g, ' ')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).layoutWeight(1)
        if (this.selectedId() === item.id) {
          Text($r('app.string.chat_decoration_in_use')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_S')).fontColor(this.accentColor)
        }
      }.width('100%')
      if (this.role === 'frame') { this.FramePreview(item); }
      else { this.BubblePreview(item); }
      Row() {
        Blank()
        Button(this.selectedId() === item.id ? $r('app.string.chat_decoration_remove') : $r('app.string.chat_decoration_use'))
          .height(40).padding({ left: 18, right: 18 }).borderRadius(20)
          .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
          .fontColor(this.selectedId() === item.id ? this.accentColor : $r('app.color.text_on_accent'))
          .backgroundColor(this.selectedId() === item.id ?
            secondaryButtonSurfaceColor(this.displayMode, this.darkSurface) : this.accentColor)
          .onClick((): void => { this.useItem(item); })
      }.width('100%')
    }.width('100%').padding(18).borderRadius(22)
      .backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface))
  }

  @Builder
  private Content(): void {
    Column({ space: 16 }) {
      if (this.installedItems.length === 0) {
        Text($r('app.string.chat_decoration_empty')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center).width('100%').padding({ top: 32, bottom: 32 })
      } else {
        this.RoleTabs()
        ForEach(this.installedItems, (item: ChatDecorationInstall) => {
          this.ItemCard(item)
        }, (item: ChatDecorationInstall): string => item.id)
      }
      if (this.hasSelection()) {
        Button($r('app.string.chat_decoration_reset')).width('100%').height(46).borderRadius(23)
          .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_primary'))
          .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
          .onClick((): void => { this.reset(); })
      }
    }.width('100%').padding({ left: 16, right: 16, top: this.statusBarHeight + 80,
      bottom: this.bottomInset + 28 })
  }

  build(): void {
    HdsNavDestination() {
      Scroll(this.scroller) {
        this.Content()
      }.width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .bindToScrollable([this.scroller])
    .titleBar({ avoidLayoutSafeArea: true,
      content: { title: { mainTitle: $r('app.string.chat_decoration') } },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode,
        this.darkSurface, this.titleBarStyleMode)
    })
    .backgroundColor(pageSurfaceColor(this.displayMode, this.darkSurface))
    .onBackPressed((): boolean => {
      ResponsiveLayout.closeContentDestination(this.pageStack);
      return true;
    })
  }
}
