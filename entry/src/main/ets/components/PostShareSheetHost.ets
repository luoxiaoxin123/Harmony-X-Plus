import { bundleManager, common } from '@kit.AbilityKit';
import { LengthMetrics } from '@kit.ArkUI';
import type { DirectMessage } from '../models/Tweet';
import type { DmConversationRouteParam } from '../pages/DmConversation';
import type { PostShareRoute } from '../pages/PostShare';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_ACCOUNTS_CHANGED } from '../services/AccountStore';
import { PostShareRequest, STORAGE_KEY_POST_SHARE_REQUEST, takePostShareRequest } from '../services/PostShareRequest';
import { DEFAULT_SHEET_MATERIAL_ENABLED, DEFAULT_SHEET_MATERIAL_LEVEL, STORAGE_KEY_SHEET_MATERIAL_ENABLED,
  STORAGE_KEY_SHEET_MATERIAL_LEVEL } from '../services/SheetMaterialSettingsStore';
import { ChatPerson, xChatActions } from '../services/XChatActions';
import { xChatService } from '../services/XChatService';
import { xPrivateClient } from '../services/XPrivateClient';
import { InputModalScope } from '../utils/InputModalScope';
import { copyPostLink } from '../utils/PostLinkCopy';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { postShareUrl, sharePost } from '../utils/SharePost';
import { sheetMaterialOptions } from '../utils/SheetMaterial';
import { fieldSurfaceColor, pageSurfaceColor } from '../utils/ThemeColors';
import { ProxyAvatar } from './ProxyAvatar';
import { ChatPinPad } from './ChatPinPad';

@Component
export struct PostShareSheetHost {
  @Prop @Watch('inboxChanged') inbox: DirectMessage[] = [];
  @StorageProp(STORAGE_KEY_POST_SHARE_REQUEST) @Watch('openRequest') private requestRevision: number = 0;
  @StorageProp(STORAGE_KEY_ACCOUNTS_CHANGED) @Watch('accountChanged') private accountRevision: number = 0;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.accent_color') private accent: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.breakpoint') private breakpoint: string = 'sm';
  @StorageProp('harmonyx.window_width') private windowWidth: number = 0;
  @StorageProp('harmonyx.window_height') private windowHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private bottomInset: number = 0;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_ENABLED) private materialEnabled: boolean = DEFAULT_SHEET_MATERIAL_ENABLED;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_LEVEL) private materialLevel: number = DEFAULT_SHEET_MATERIAL_LEVEL;
  @State private open: boolean = false;
  @State private signedIn: boolean = false;
  @State private query: string = '';
  @State private note: string = '';
  @State private selected: DmConversationRouteParam | null = null;
  @State private recipients: DmConversationRouteParam[] = [];
  @State private loading: boolean = false;
  @State private failed: boolean = false;
  @State private telegramAvailable: boolean = false;
  @State private emailAvailable: boolean = false;
  @State private sending: boolean = false;
  @State private askingPin: boolean = false;
  @State private sendError: string = '';
  private current: PostShareRequest | undefined;
  private afterClose: (() => void) | undefined;
  private readonly modalScope: InputModalScope = new InputModalScope();
  private generation: number = 0;
  private timer: number = -1;
  private account: string = '';

  aboutToAppear(): void { this.openRequest(); }
  aboutToDisappear(): void {
    this.afterClose = undefined;
    this.sheetClosed();
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private openRequest(): void {
    const request: PostShareRequest | undefined = takePostShareRequest();
    if (request === undefined || this.current !== undefined) { return; }
    this.current = request;
    this.query = '';
    this.note = '';
    this.selected = null;
    this.recipients = [];
    this.loading = false;
    this.failed = false;
    this.sending = false;
    this.askingPin = false;
    this.sendError = '';
    xPrivateClient.load(this.context());
    this.account = xPrivateClient.sessionIdentity();
    this.signedIn = xPrivateClient.isSignedIn() && xPrivateClient.viewerId().length > 0;
    this.telegramAvailable = this.canOpenLink('tg://msg_url');
    this.emailAvailable = this.canOpenLink('mailto:');
    this.modalScope.setActive(true);
    this.open = true;
    if (this.signedIn) { void this.search(); }
  }

  private cancelSearch(): void {
    this.generation++;
    if (this.timer >= 0) { clearTimeout(this.timer); }
    this.timer = -1;
  }

  private accountChanged(): void {
    if (this.current === undefined) { return; }
    this.afterClose = undefined;
    this.cancelSearch();
    this.recipients = [];
    this.selected = null;
    this.open = false;
  }

  private sheetClosed(): void {
    this.open = false;
    this.cancelSearch();
    this.current = undefined;
    this.modalScope.setActive(false);
    const action: (() => void) | undefined = this.afterClose;
    this.afterClose = undefined;
    action?.();
  }

  private closeWith(action: () => void): void {
    if (!this.open) { return; }
    this.afterClose = action;
    this.open = false;
  }

  private canOpenLink(uri: string): boolean {
    try { return bundleManager.canOpenLink(uri); } catch (error) { return false; }
  }

  private async openApp(uri: string): Promise<void> {
    try {
      await this.context().startAbility({ action: 'ohos.want.action.viewData', uri: uri });
    } catch (error) { this.showShareFailure(); }
  }

  private showShareFailure(): void {
    this.getUIContext().getPromptAction().showToast({ message: $r('app.string.share_failed') });
  }

  private recentRecipients(query: string): DmConversationRouteParam[] {
    const recipients: DmConversationRouteParam[] = [];
    const seen: Set<string> = new Set<string>();
    const needle: string = query.toLowerCase();
    for (const row of this.inbox) {
      const id: string = row.conversationId ?? '';
      const username: string = row.username ?? '';
      if (id.length === 0 || row.hidden === true || seen.has(id)) { continue; }
      if (!row.from.toLowerCase().includes(needle) && !username.toLowerCase().includes(needle)) { continue; }
      seen.add(id);
      recipients.push({ conversationId: id, title: row.from, username: username, avatarUrl: row.avatarUrl ?? '',
        verifiedType: row.verifiedType, avatarShape: row.avatarShape, group: row.group ?? false,
        participantIds: row.participantIds ?? [], latestSequenceId: row.latestSequenceId ?? '' });
    }
    return recipients;
  }

  private personRecipient(person: ChatPerson): DmConversationRouteParam {
    const ids: string[] = [xPrivateClient.viewerId(), person.id];
    ids.sort((first: string, second: string): number => first.length !== second.length ?
      first.length - second.length : (first > second ? 1 : first < second ? -1 : 0));
    return { conversationId: ids.join('-'), title: person.name, username: person.username, avatarUrl: person.avatarUrl,
      verifiedType: person.verifiedType, avatarShape: person.avatarShape, group: false, participantIds: ids,
      latestSequenceId: '' };
  }

  private inboxChanged(): void {
    if (this.open && this.signedIn && this.query.trim().length === 0) { void this.search(); }
  }

  private changeQuery(query: string): void {
    this.query = query;
    this.selected = null;
    this.sendError = '';
    this.cancelSearch();
    const normalizedQuery: string = query.trim().replace(/^@/, '');
    this.recipients = this.recentRecipients(normalizedQuery);
    this.failed = false;
    this.loading = this.recipients.length === 0;
    this.timer = setTimeout((): void => { void this.search(); }, 250);
  }

  private validSearch(generation: number): boolean {
    return this.open && generation === this.generation && this.account === xPrivateClient.sessionIdentity();
  }

  private async search(): Promise<void> {
    if (!this.open || !this.signedIn || this.account !== xPrivateClient.sessionIdentity()) { return; }
    this.cancelSearch();
    const generation: number = this.generation;
    const query: string = this.query.trim().replace(/^@/, '');
    const recent: DmConversationRouteParam[] = this.recentRecipients(query);
    this.recipients = recent;
    this.failed = false;
    this.loading = false;
    if (query.length === 0 && recent.length > 0) { return; }
    this.loading = true;
    try {
      const people: ChatPerson[] = await xChatActions.people(query, false);
      if (!this.validSearch(generation)) { return; }
      const seen: Set<string> = new Set<string>(recent.map((row: DmConversationRouteParam): string => row.conversationId));
      const results: DmConversationRouteParam[] = recent.slice();
      for (const person of people) {
        if (!person.canDm || person.id.length === 0) { continue; }
        const recipient: DmConversationRouteParam = this.personRecipient(person);
        if (!seen.has(recipient.conversationId)) {
          seen.add(recipient.conversationId);
          results.push(recipient);
        }
      }
      this.recipients = results;
    } catch (error) {
      if (this.validSearch(generation)) { this.failed = true; }
    } finally {
      if (this.validSearch(generation)) { this.loading = false; }
    }
  }

  private async sendSelected(pin?: string): Promise<void> {
    const request: PostShareRequest | undefined = this.current;
    const recipient: DmConversationRouteParam | null = this.selected;
    const account: string = this.account;
    if (this.sending || request === undefined || recipient === null || account !== xPrivateClient.sessionIdentity()) {
      return;
    }
    this.sending = true;
    this.sendError = '';
    try {
      await xChatService.prepare(this.context(), recipient.participantIds);
      if (account !== xPrivateClient.sessionIdentity() || this.current !== request || !this.open) { return; }
      if (!xChatService.isUnlocked()) {
        if (pin === undefined) { this.askingPin = true; return; }
        await xChatService.unlock(pin);
      }
      if (account !== xPrivateClient.sessionIdentity() || this.current !== request || !this.open) { return; }
      this.askingPin = false;
      await xChatService.sharePost(recipient.conversationId, request.post.id, postShareUrl(request.post), this.note.trim());
      if (this.current !== request || !this.open) { return; }
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.chat_sent') });
      this.open = false;
    } catch (error) {
      if (this.current === request && this.open) {
        const resource: Resource = this.askingPin ? $r('app.string.dm_unlock_failed') : $r('app.string.chat_action_failed');
        this.sendError = this.context().resourceManager.getStringSync(resource);
      }
    } finally {
      if (this.current === request) { this.sending = false; }
    }
  }

  private openScreenshot(): void {
    const request: PostShareRequest | undefined = this.current;
    if (request === undefined) { return; }
    const param: PostShareRoute = { post: request.post };
    this.closeWith((): void => {
      request.beforeNavigate?.();
      request.pageStack.pushPath({ name: 'PostShare', param: param });
    });
  }

  private systemShare(): void {
    const request: PostShareRequest | undefined = this.current;
    if (request === undefined) { return; }
    this.closeWith(async (): Promise<void> => {
      if (!await sharePost(this.context(), request.post)) { this.showShareFailure(); }
    });
  }

  private copyLink(): void {
    if (this.current === undefined) { return; }
    const url: string = postShareUrl(this.current.post);
    this.closeWith((): void => { void copyPostLink(this.getUIContext(), url); });
  }

  private appShare(telegram: boolean): void {
    if (this.current === undefined) { return; }
    const url: string = postShareUrl(this.current.post);
    const uri: string = telegram ? 'tg://msg_url?url=' + encodeURIComponent(url) + '&text=' + encodeURIComponent(this.note) :
      'mailto:?body=' + encodeURIComponent((this.note.trim() + '\n' + url).trim());
    this.closeWith((): void => { void this.openApp(uri); });
  }

  private centered(): boolean {
    return !ResponsiveLayout.isSmall(this.breakpoint);
  }

  private sheetOptions(): SheetOptions {
    const centered: boolean = this.centered();
    const compactWindow: boolean = ResponsiveLayout.isCompactWindow(this.windowWidth, this.windowHeight);
    const options: SheetOptions = sheetMaterialOptions({
      preferType: centered ? SheetType.CENTER : SheetType.BOTTOM,
      width: centered ? Math.min(624, Math.max(280, this.windowWidth - 48)) : '100%',
      height: this.windowHeight > 0 ? this.windowHeight * (centered ? 0.70 : 0.76) : '76%',
      dragBar: !centered,
      showClose: false,
      keyboardAvoidMode: SheetKeyboardAvoidMode.RESIZE_ONLY,
      backgroundColor: pageSurfaceColor(this.displayMode, this.darkSurface),
      maskColor: '#33000000',
      radius: centered ? LengthMetrics.vp(28) : { topLeft: 28, topRight: 28, bottomLeft: 0, bottomRight: 0 },
      onDisappear: (): void => { this.sheetClosed(); },
      onWillDismiss: (action: DismissSheetAction): void => { if (!this.sending) { action.dismiss(); } }
    }, this.materialEnabled, this.materialLevel, this.breakpoint, compactWindow);
    if (this.materialEnabled) {
      options.borderWidth = 1;
      options.borderColor = '#66FFFFFF';
    }
    return options;
  }

  @Builder
  private RecipientRow(recipient: DmConversationRouteParam): void {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        ProxyAvatar({ url: recipient.avatarUrl, avatarSize: 44, radius: 22, fallbackText: recipient.title.substring(0, 1),
          verifiedType: recipient.verifiedType ?? '', avatarShape: recipient.avatarShape ?? '' })
        Column({ space: 3 }) {
          Text(recipient.title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (recipient.username.length > 0) {
            Text('@' + recipient.username).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.text_secondary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        SymbolGlyph(this.selected?.conversationId === recipient.conversationId ?
          $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.circle')).fontSize(22)
          .fontColor([this.selected?.conversationId === recipient.conversationId ? this.accent : $r('app.color.text_secondary')])
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })
    }.width('100%').padding(0).backgroundColor(Color.Transparent).enabled(!this.sending)
      .accessibilitySelected(this.selected?.conversationId === recipient.conversationId)
      .onClick((): void => {
        this.selected = this.selected?.conversationId === recipient.conversationId ? null : recipient;
        this.sendError = '';
      })
  }

  @Builder
  private Action(icon: Resource, label: ResourceStr, action: () => void): void {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 5 }) {
        Stack() {
          SymbolGlyph(icon).fontSize(22).fontColor([$r('app.color.bg_page')])
        }.width(46).height(46).borderRadius(23).backgroundColor($r('app.color.text_primary'))
        Text(label).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
          .fontColor($r('app.color.text_secondary')).textAlign(TextAlign.Center)
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.width('100%')
    }.width(79).padding(4).backgroundColor(Color.Transparent)
      .accessibilityText(typeof label === 'string' ? label : this.context().resourceManager.getStringSync(label))
      .onClick(action)
  }

  @Builder
  private Panel(): void {
    Column({ space: 4 }) {
      Row() {
        Text($r('app.string.action_share')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).layoutWeight(1)
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.xmark')).fontSize(16).fontColor([$r('app.color.text_primary')])
        }.width(40).height(40).backgroundColor(Color.Transparent).enabled(!this.sending)
          .accessibilityText($r('app.string.compose_cancel'))
          .onClick((): void => { this.open = false; })
      }.width('100%').padding({ left: 20, right: 8 })
      Search({ value: this.query, placeholder: $r('app.string.chat_search') })
        .height(44).borderRadius(22).margin({ left: 20, right: 20, bottom: 4 })
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE).enabled(this.signedIn && !this.sending)
        .backgroundColor(this.materialEnabled ? '#24FFFFFF' : fieldSurfaceColor(this.displayMode, this.darkSurface))
        .border({ width: 1, color: this.materialEnabled ? '#66FFFFFF' : $r('app.color.divider') })
        .fontColor($r('app.color.text_primary')).placeholderColor($r('app.color.text_secondary'))
        .onChange((query: string): void => this.changeQuery(query))
      List() {
        ForEach(this.recipients, (recipient: DmConversationRouteParam): void => {
          ListItem() { this.RecipientRow(recipient) }
        }, (recipient: DmConversationRouteParam): string => recipient.conversationId)
        if (this.loading && this.recipients.length === 0) {
          ListItem() { LoadingProgress().width(24).height(24).color(this.accent).margin(16) }
        } else if (this.failed) {
          ListItem() {
            Button($r('app.string.common_retry')).fontFamily(this.appFontFamily).fontColor(this.accent)
              .backgroundColor(Color.Transparent).onClick((): void => { void this.search(); })
          }
        } else if (this.recipients.length === 0) {
          ListItem() {
            Text(this.signedIn ? $r('app.string.chat_no_results') : $r('app.string.user_list_sign_in'))
              .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.text_secondary')).padding(20)
          }
        }
      }.layoutWeight(1).width('100%').scrollBar(BarState.Auto)
      if (this.selected !== null) {
        Row({ space: 8 }) {
          TextInput({ text: this.note, placeholder: $r('app.string.post_share_message') }).fontFamily(this.appFontFamily)
            .layoutWeight(1).height(40).maxLength(1000).borderRadius(20).keyboardAppearance(KeyboardAppearance.IMMERSIVE)
            .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
            .enabled(!this.sending)
            .onChange((note: string): void => { this.note = note; })
          Button(this.sending ? $r('app.string.post_sending') : $r('app.string.dm_send'))
            .height(40).fontFamily(this.appFontFamily).enabled(!this.sending)
            .fontColor($r('app.color.text_on_accent')).backgroundColor(this.accent)
            .onClick((): void => { void this.sendSelected(); })
        }.width('100%').padding({ left: 16, right: 16, bottom: 4 })
      }
      if (this.sendError.length > 0) {
        Text(this.sendError).fontFamily(this.appFontFamily).fontColor($r('app.color.danger'))
          .width('100%').padding({ left: 16, right: 16 })
      }
      Divider().color($r('app.color.divider')).width('100%')
      Scroll() {
        Row({ space: 2 }) {
          this.Action($r('sys.symbol.share'), $r('app.string.post_share_system'), (): void => this.systemShare())
          this.Action($r('sys.symbol.link'), $r('app.string.post_link_copy'), (): void => this.copyLink())
          this.Action($r('sys.symbol.camera'), $r('app.string.post_share_screenshot'), (): void => this.openScreenshot())
          if (this.telegramAvailable) {
            this.Action($r('sys.symbol.arrow_up_right'), 'Telegram', (): void => this.appShare(true))
          }
          if (this.emailAvailable) {
            this.Action($r('sys.symbol.envelope'), $r('app.string.post_share_email'), (): void => this.appShare(false))
          }
        }.alignItems(VerticalAlign.Top).padding({ left: 9, right: 9 })
      }.width('100%').align(Alignment.Start).scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
        .enabled(!this.sending)
    }.width('100%').height('100%').padding({ top: 5, bottom: this.centered() ? 8 : Math.max(8, this.bottomInset) })
  }

  @Builder
  private ShareContent(): void {
    if (this.askingPin) {
      Column() {
        ChatPinPad({ busy: this.sending, error: this.sendError,
          onSubmit: (pin: string): void => { void this.sendSelected(pin); },
          onClose: (): void => { this.askingPin = false; this.sendError = ''; } })
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    } else {
      this.Panel()
    }
  }

  build(): void {
    Column().width(0).height(0).bindSheet($$this.open, this.ShareContent(), this.sheetOptions())
  }
}
