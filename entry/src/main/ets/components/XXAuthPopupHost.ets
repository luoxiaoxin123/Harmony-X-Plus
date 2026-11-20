import { TouchHdrLight } from './TouchHdrLight';
import { bundleManager, common } from '@kit.AbilityKit';
import { hdsEffect } from '@kit.UIDesignKit';
import { HdsButton } from './HdsButton';
import { XXAuthAnnouncement, XXAuthArticle, XXAuthPanel, XXAuthResult, XXAuthVersion } from '../models/XXAuth';
import { xxAuthService } from '../services/XXAuthService';
import { XXAuthPopupPolicy } from '../services/XXAuthPopupPolicy';
import { XXAUTH_POPUP_REQUEST, xxAuthPopupStore } from '../services/XXAuthPopupStore';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { DEFAULT_SHEET_MATERIAL_ENABLED, DEFAULT_SHEET_MATERIAL_LEVEL, STORAGE_KEY_SHEET_MATERIAL_ENABLED,
  STORAGE_KEY_SHEET_MATERIAL_LEVEL } from '../services/SheetMaterialSettingsStore';
import { sheetMaterialOptions } from '../utils/SheetMaterial';
import { pageSurfaceColor, fieldSurfaceColor } from '../utils/ThemeColors';

@Component
export struct XXAuthPopupHost {
  @Prop @Watch('onBlockedChanged') blocked: boolean = true;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(XXAUTH_POPUP_REQUEST) @Watch('onRequest') private popupRequest: string = '';
  @StorageProp('harmonyx.foreground_tick') @Watch('onForeground') private foregroundTick: number = 0;
  @StorageProp('harmonyx.app_foreground') private appForeground: boolean = true;
  @StorageProp('harmonyx.window_height') private windowHeight: number = 800;
  @StorageProp('harmonyx.breakpoint') private breakpoint: string = 'sm';
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_ENABLED) private sheetMaterialEnabled: boolean = DEFAULT_SHEET_MATERIAL_ENABLED;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_LEVEL) private sheetMaterialLevel: number = DEFAULT_SHEET_MATERIAL_LEVEL;
  @State private visible: boolean = false;
  @State private panel: XXAuthPanel = new XXAuthPanel();
  @State private manualMode: string = '';
  @State private loading: boolean = false;
  @State private failed: boolean = false;
  @State private linkFailed: boolean = false;
  @State private opening: boolean = false;
  @State private experienceLight: hdsEffect.PointLightSourceType = hdsEffect.PointLightSourceType.NONE;
  @State private announcements: XXAuthAnnouncement[] = [];
  @State private articles: XXAuthArticle[] = [];
  @State private versions: XXAuthVersion[] = [];
  @State private latest: string = '';
  @State private checkMessage: Resource = $r('app.string.update_no_release');
  private pending: XXAuthPanel[] = [];
  private shown: string[] = [];
  private timer: number = -1;
  private alive: boolean = false;
  private refreshing: boolean = false;
  private lastRefresh: number = 0;
  private manualRevision: number = 0;
  private lastRequest: string = '';

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  aboutToAppear(): void {
    this.alive = true;
    this.lastRequest = this.popupRequest;
    this.refresh();
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.manualRevision++;
    if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
    this.pending = [];
  }

  private versionName(): string {
    try {
      return bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION).versionName;
    } catch (error) { return ''; }
  }

  private onForeground(): void {
    if (Date.now() - this.lastRefresh >= 60000) { this.refresh(); }
    else { this.scheduleNext(); }
  }

  private onBlockedChanged(): void {
    if (this.blocked) {
      if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
      if (this.manualMode.length === 0) { this.visible = false; }
      return;
    }
    this.scheduleNext();
  }

  private async refresh(): Promise<void> {
    if (!this.alive || this.refreshing) { return; }
    this.refreshing = true;
    this.lastRefresh = Date.now();
    try {
      const announcementsTask: Promise<XXAuthResult<XXAuthAnnouncement[]>> = xxAuthService.announcements();
      const versionTask: Promise<XXAuthResult<XXAuthVersion>> = xxAuthService.latestVersion();
      const announcements: XXAuthResult<XXAuthAnnouncement[]> = await announcementsTask;
      const latest: XXAuthResult<XXAuthVersion> = await versionTask;
      if (!this.alive) { return; }
      const panels: XXAuthPanel[] = announcements.ok && announcements.data instanceof Array ?
        XXAuthPopupPolicy.publicAnnouncements(announcements.data).map(
          (item: XXAuthAnnouncement): XXAuthPanel => XXAuthPopupPolicy.announcement(item)) : [];
      const update: XXAuthPanel | undefined = latest.ok && latest.data !== undefined ?
        XXAuthPopupPolicy.update(latest.data, this.versionName()) : undefined;
      if (update !== undefined) { panels.unshift(update); }
      this.pending = panels;
      this.scheduleNext();
    } finally { this.refreshing = false; }
  }

  private scheduleNext(): void {
    if (!this.alive || this.visible || this.blocked || !this.appForeground || this.timer >= 0 ||
      this.manualMode.length > 0 || this.pending.length === 0) { return; }
    this.timer = setTimeout((): void => {
      this.timer = -1;
      if (!this.alive || this.visible || this.blocked || !this.appForeground || this.manualMode.length > 0) { return; }
      const item: XXAuthPanel | undefined = this.pending.find((candidate: XXAuthPanel): boolean =>
        this.shown.indexOf(candidate.fingerprint) < 0 && xxAuthPopupStore.shouldShow(this.context(), candidate));
      if (item === undefined) { return; }
      this.panel = item;
      this.loading = false;
      this.failed = false;
      this.linkFailed = false;
      this.shown.push(item.fingerprint);
      this.visible = true;
    }, 400);
  }

  private onRequest(): void {
    if (!this.alive || this.popupRequest === this.lastRequest) { return; }
    this.lastRequest = this.popupRequest;
    const kind: string = this.popupRequest.split(':')[0];
    if (kind === 'announcements' || kind === 'articles' || kind === 'versions' || kind === 'update') {
      this.openManual(kind);
    }
  }

  private async openManual(kind: string): Promise<void> {
    this.manualMode = kind;
    this.panel = new XXAuthPanel();
    this.visible = true;
    this.loading = true;
    this.failed = false;
    this.linkFailed = false;
    const revision: number = ++this.manualRevision;
    if (kind === 'announcements') {
      const result: XXAuthResult<XXAuthAnnouncement[]> = await xxAuthService.announcements();
      if (!this.isCurrent(revision)) { return; }
      this.failed = !result.ok;
      this.announcements = result.ok && result.data instanceof Array ? XXAuthPopupPolicy.publicAnnouncements(result.data) : [];
    } else if (kind === 'articles') {
      const result: XXAuthResult<XXAuthArticle[]> = await xxAuthService.articles();
      if (!this.isCurrent(revision)) { return; }
      this.failed = !result.ok;
      this.articles = result.ok && result.data instanceof Array ? result.data.filter(
        (item: XXAuthArticle): boolean => typeof item.content === 'string' && item.content.indexOf('//关闭') < 0) : [];
    } else if (kind === 'versions') {
      const latestTask: Promise<XXAuthResult<XXAuthVersion>> = xxAuthService.latestVersion();
      const result: XXAuthResult<XXAuthVersion[]> = await xxAuthService.versions();
      const latest: XXAuthResult<XXAuthVersion> = await latestTask;
      if (!this.isCurrent(revision)) { return; }
      this.failed = !result.ok || (!latest.ok && latest.status !== 404);
      this.versions = result.ok && result.data instanceof Array ? result.data : [];
      this.latest = latest.ok ? latest.data?.version ?? '' : '';
    } else if (kind === 'update') {
      const result: XXAuthResult<XXAuthVersion> = await xxAuthService.latestVersion();
      if (!this.isCurrent(revision)) { return; }
      this.failed = !result.ok && result.status !== 404;
      const latest: XXAuthVersion | undefined = result.ok ? result.data : undefined;
      const current: string = this.versionName();
      const update: XXAuthPanel | undefined = latest === undefined ? undefined : XXAuthPopupPolicy.update(latest, current);
      this.checkMessage = latest !== undefined && typeof latest.version === 'string' &&
        XXAuthPopupPolicy.versionParts(latest.version).length === 3 && XXAuthPopupPolicy.versionParts(current).length === 3 ?
        $r('app.string.update_up_to_date') : $r('app.string.update_no_release');
      if (update !== undefined) { this.panel = update; }
    }
    this.loading = false;
  }

  private isCurrent(revision: number): boolean {
    return this.alive && this.visible && revision === this.manualRevision;
  }

  private dismiss(): void {
    if (this.manualMode.length === 0) { xxAuthPopupStore.markRead(this.context(), this.panel); }
    this.visible = false;
  }

  private async openLink(): Promise<void> {
    if (this.opening || this.panel.link.length === 0) { return; }
    this.opening = true;
    this.linkFailed = false;
    const fingerprint: string = this.panel.fingerprint;
    try {
      await this.context().startAbility({ action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'], uri: this.panel.link });
      if (this.alive && this.visible && this.panel.fingerprint === fingerprint) { this.dismiss(); }
    } catch (error) {
      if (this.alive && this.visible && this.panel.fingerprint === fingerprint) { this.linkFailed = true; }
    } finally { this.opening = false; }
  }

  private title(): ResourceStr {
    if (this.panel.kind === 'update') { return $r('app.string.update_available'); }
    if (this.manualMode === 'articles') { return $r('app.string.xxauth_articles'); }
    if (this.manualMode === 'versions') { return $r('app.string.xxauth_versions'); }
    if (this.manualMode === 'update') { return $r('app.string.settings_check_update'); }
    return $r('app.string.xxauth_announcements');
  }

  private options(): SheetOptions {
    return sheetMaterialOptions({ width: 560, height: Math.max(240, Math.min(580, this.windowHeight - 80)),
      showClose: false, dragBar: false, backgroundColor: pageSurfaceColor(this.displayMode, this.darkSurface),
      onWillDismiss: (action: DismissSheetAction): void => { this.dismiss(); action.dismiss(); },
      onDisappear: (): void => {
        this.visible = false;
        this.manualMode = '';
        this.manualRevision++;
        this.experienceLight = hdsEffect.PointLightSourceType.NONE;
        this.scheduleNext();
      }
    }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.breakpoint);
  }

  @Builder
  private BodyText(value: ResourceStr): void {
    Text(value).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
      .fontColor($r('app.color.text_primary')).width('100%')
  }

  @Builder
  private ContentCard(title: ResourceStr, content: ResourceStr): void {
    Column({ space: 10 }) {
      Text(title).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary')).width('100%')
      this.BodyText(content)
    }.width('100%').padding(16).borderRadius(20)
      .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
  }

  @Builder
  private HdrButtonLight(active: boolean): void {
    TouchHdrLight({ active: active, cornerRadius: 23 })
  }

  @Builder
  private Content(): void {
    Column({ space: 20 }) {
      Row({ space: 12 }) {
        Text(this.title()).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).layoutWeight(1)
        HdsButton({ barWidth: 40, barHeight: 52, iconResource: $r('sys.symbol.xmark'), iconSize: 18,
            iconColor: [$r('app.color.text_primary')], useImmersiveMaterial: true,
            enablePressLight: false, onButtonClick: (): void => this.dismiss() })
          .accessibilityText($r('app.string.xxauth_close'))
      }.width('100%')
      Scroll() {
        Column({ space: 16 }) {
          if (this.loading) {
            LoadingProgress().width(32).height(32)
          } else if (this.failed) {
            this.BodyText($r('app.string.xxauth_load_failed'))
            Button($r('app.string.xxauth_retry')).onClick((): void => { this.openManual(this.manualMode); })
          } else if (this.panel.kind.length > 0) {
            if (this.panel.title.length > 0) { this.BodyText(this.panel.title) }
            if (this.panel.version.length > 0) { this.BodyText(this.panel.version) }
            this.BodyText(this.panel.content)
            if (this.panel.kind === 'update' && this.panel.link.length === 0) {
              this.BodyText($r('app.string.update_no_link'))
            }
          } else if (this.manualMode === 'announcements') {
            if (this.announcements.length === 0) { this.BodyText($r('app.string.xxauth_empty')) }
            ForEach(this.announcements, (item: XXAuthAnnouncement): void => {
              this.ContentCard(XXAuthPopupPolicy.text(item.title), XXAuthPopupPolicy.text(item.content))
            }, (item: XXAuthAnnouncement): string => item.id)
          } else if (this.manualMode === 'articles') {
            if (this.articles.length === 0) { this.BodyText($r('app.string.xxauth_empty')) }
            ForEach(this.articles, (item: XXAuthArticle): void => {
              this.ContentCard(XXAuthPopupPolicy.text(item.title), XXAuthPopupPolicy.text(item.content))
            }, (item: XXAuthArticle): string => item.id)
          } else if (this.manualMode === 'versions') {
            if (this.latest.length > 0) { this.BodyText(this.latest) }
            if (this.versions.length === 0) { this.BodyText($r('app.string.update_no_release')) }
            ForEach(this.versions, (item: XXAuthVersion): void => {
              this.ContentCard(item.version, XXAuthPopupPolicy.text(item.change_log))
              if (item.published_at) { this.BodyText(item.published_at) }
            }, (item: XXAuthVersion): string => item.version + (item.published_at ?? ''))
          } else if (this.manualMode === 'update') { this.BodyText(this.checkMessage) }
          if (this.linkFailed) { this.BodyText($r('app.string.about_link_failed')) }
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top)
      Row({ space: 12 }) {
        if (this.panel.link.length > 0) {
          Button($r('app.string.xnative_open_download'))
            .height(46).fontSize(15).borderRadius(23)
            .layoutWeight(1).enabled(!this.opening).backgroundColor(this.accentColor)
            .visualEffect(new hdsEffect.HdsEffectBuilder().pointLight({ sourceType: this.experienceLight,
              illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER,
              options: { color: Color.White, intensity: this.experienceLight === hdsEffect.PointLightSourceType.NONE ? 0 : 10, height: 150 }
            }).buildEffect())
            .overlay(this.HdrButtonLight(this.experienceLight !== hdsEffect.PointLightSourceType.NONE))
            .onTouch((event: TouchEvent): void => { this.experienceLight = event.type === TouchType.Down ?
              hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.NONE; })
            .fontColor($r('app.color.text_on_accent')).onClick((): void => { this.openLink(); })
        }
      }.width('100%')
    }.width('100%').height('100%').padding(24).backgroundColor(Color.Transparent)
      .id('xxauth-popup-content')
  }

  build(): void {
    Column().width(0).height(0)
      .bindSheet($$this.visible, this.Content(), this.options())
  }
}
