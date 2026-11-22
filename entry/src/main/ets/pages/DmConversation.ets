import { submitInputKey, backInputKey } from '../utils/InputSupport';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { verificationBadgeColor, userVerifiedType, userAvatarShape } from '../utils/UserIdentity';
import { DEFAULT_SHEET_MATERIAL_ENABLED, DEFAULT_SHEET_MATERIAL_LEVEL, STORAGE_KEY_SHEET_MATERIAL_ENABLED, STORAGE_KEY_SHEET_MATERIAL_LEVEL } from '../services/SheetMaterialSettingsStore';
import { sheetMaterialOptions } from '../utils/SheetMaterial';
// The native conversation UI delegates cryptography to the official Chat XDK.
import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import hilog from '@ohos.hilog';
import { deviceInfo } from '@kit.BasicServicesKit';
import { KeyboardAvoidMode, LengthMetrics, window } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType, BottomBuilderShowType } from '@kit.UIDesignKit';
import type { DmMessage, UserProfile, TweetAuthor } from '../models/Tweet';
import { formatCount } from '../models/Tweet';
import { ChatContact, ChatContactService, chatContactService } from '../services/ChatContactService';
import { chatFailureMessage } from '../services/XChatFailureMessage';
import type { UserDetailRouteParam } from './UserDetail';
import { XChatGroupDisplay, XChatPage, XChatService, XChatWebHistorySnapshot, xChatService } from '../services/XChatService';
import { WebChatMessage, WebChatReply, readXChatWebHistory, reactInXChatWeb } from '../services/XChatWebDraft';
import { XNotificationParser } from '../services/XNotificationParser';
import { ProxyAvatar } from '../components/ProxyAvatar';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { pageSurfaceColor, secondaryButtonSurfaceColor } from '../utils/ThemeColors';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { BaseItemInfo, PhotoSource, RecentPhotoComponent, RecentPhotoOptions, photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo, picker, fileUri } from '@kit.CoreFileKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { abilityAccessCtrl, PermissionRequestResult } from '@kit.AbilityKit';
import { media } from '@kit.MediaKit';
import { inputMethod } from '@kit.IMEKit';
import { ChatPinPad } from '../components/ChatPinPad';
import { ChatMediaCard } from '../components/ChatMediaCard';
import { ChatMediaAlbum } from '../components/ChatMediaAlbum';
import { ChatPendingMediaAlbum } from '../components/ChatPendingMediaAlbum';
import { ChatMediaSend, ChatMediaOutbox, chatMediaOutbox } from '../services/ChatMediaOutbox';
import { chatMessageRenderKey } from '../utils/ChatMessageRenderKey';
import { ChatVideoViewerRouteParam } from './ChatVideoViewer';
import type { PhotoViewerRouteParam } from './PhotoViewer';
import { pendingMediaViewerSource } from '../utils/MediaViewerMotion';
import { setChatWindowPrivacy } from '../utils/ChatWindowPrivacy';
import { ChatMovingPhotoCard } from '../components/ChatMovingPhotoCard';
import { ChatMediaItem, ChatMovingPhotoProtocol } from '../utils/ChatMovingPhotoProtocol';
import { ChatVoicePlayer } from '../components/ChatVoicePlayer';
import { ChatWaveform } from '../components/ChatWaveform';
import { ChatMessageActions } from '../components/ChatMessageActions';
import { ChatEmojiPanel } from '../components/ChatEmojiPanel';
import { ChatEmojiText } from '../components/ChatEmojiText';
import { ChatLinkText } from '../components/ChatLinkText';
import { ChatPostCard } from '../components/ChatPostCard';
import { ChatPostLink, chatPostLink, chatPostLinks, chatTextWithoutLinks } from '../utils/ChatPostLinks';
import { openPostCardUrl } from '../utils/PostCardAction';
import { chatPostPreview } from '../services/ChatPostPreview';
import type { Tweet } from '../models/Tweet';
import type { PostDetailRouteParam } from './PostDetail';
import { ChatForwardPanel } from '../components/ChatForwardPanel';
import { chatEmojiStore } from '../services/ChatEmojiStore';
import { chatEmojiImages } from '../services/ChatEmojiImages';
import { xPrivateClient } from '../services/XPrivateClient';
import { XChatReplyTarget } from '../services/XChatService';
import { ChatPerson } from '../services/XChatActions';
import { pasteboard } from '@kit.BasicServicesKit';
import { ChatVoice } from '../utils/ChatVoice';
import { DmAttachment, MediaAttachment } from '../models/Tweet';
import { ChatPickedFile, XChatMedia, xChatMedia } from '../services/XChatMedia';
import { ExternalSharePayload, ExternalShareFile } from '../services/ExternalShareStore';
import { xPrivateStore } from '../services/XPrivateStore';
import { xChatActions } from '../services/XChatActions';
import { gifSearchSelectionStore } from '../services/GifSearchSelectionStore';
import { DmInfoRouteParam } from './DmInfo';
import { ChatBackgroundLayer } from '../components/ChatBackgroundLayer';
import { ChatBackgroundState, chatBackgroundStore } from '../services/ChatBackgroundStore';
import { CHAT_DECORATION_REVISION_KEY, ChatDecorationSelection,
  chatDecorationService } from '../services/ChatDecorationService';
import { DmWebRouteParam } from './DmWeb';
import { STORAGE_KEY_REDUCE_MOTION } from '../services/MotionSettingsStore';
import { ChatTypingIndicator } from '../components/ChatTypingIndicator';
import { chatMessageTime } from '../utils/ChatTime';
import { effectiveAppLocale, STORAGE_KEY_APP_LOCALE } from '../utils/AppLocale';
import { chatInputMaterial, chatPageMaterial, chatTintedControlMaterial } from '../utils/ChatMaterial';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { materialModifier } from '../utils/SystemMaterial';
import { MaterialSurfaceHost } from '../components/MaterialSurfaceHost';
import { STORAGE_KEY_REPLY_CAPSULE_MATERIAL_LEVEL, DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL,
  STORAGE_KEY_TITLE_BAR_GLASS_MATERIAL_LEVEL, DEFAULT_TITLE_BAR_GLASS_MATERIAL_LEVEL } from '../services/AppearanceStore';

export interface DmConversationRouteParam {
  conversationId: string;
  title: string;
  username: string;
  avatarUrl: string;
  verifiedType?: string;
  avatarShape?: string;
  group: boolean;
  participantIds: string[];
  latestSequenceId: string;
  contactProfile?: UserProfile;
  sharedPayload?: ExternalSharePayload;
}

const RECENT_PHOTO_MAX_AGE: number = 86400000;
const RECENT_PHOTO_DISMISS_DELAY: number = 6000;

@Builder
export function DmConversationBuilder(): void {
  DmConversationPage();
}

@Component
export struct DmConversationPage {
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_APP_LOCALE) private appLocale: string = effectiveAppLocale();
  @StorageProp('harmonyx.breakpoint') private sheetWindowBreakpoint: string = 'sm';
  private sharedImportId: string = '';
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_ENABLED) private sheetMaterialEnabled: boolean = DEFAULT_SHEET_MATERIAL_ENABLED;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_LEVEL) private sheetMaterialLevel: number = DEFAULT_SHEET_MATERIAL_LEVEL;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageProp(STORAGE_KEY_REPLY_CAPSULE_MATERIAL_LEVEL) capsuleMaterialLevel: number = DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL;
  @StorageProp(STORAGE_KEY_TITLE_BAR_GLASS_MATERIAL_LEVEL) inputMaterialLevel: number = DEFAULT_TITLE_BAR_GLASS_MATERIAL_LEVEL;
  @State @Watch('updateVisibleMessages') private messages: DmMessage[] = [];
  @State @Watch('updateVisibleMessages') private mediaSends: ChatMediaSend[] = [];
  @State private visibleTimeline: DmMessage[] = [];
  @State private chatBackground: ChatBackgroundState = new ChatBackgroundState();
  @State private chatDecoration: ChatDecorationSelection = new ChatDecorationSelection();
  @State private status: string = '';
  @State private loading: boolean = true;
  @State private sending: boolean = false;
  @State private picking: boolean = false;
  @State private draft: string = '';
  @State private needsUnlock: boolean = false;
  @State private historyUnavailable: boolean = false;
  @State private keysUnavailable: boolean = false;
  @State private sendUnavailable: boolean = false;
  @State private unlocking: boolean = false;
  @State private pin: string = '';
  @State private unlockError: string = '';
  @State private hasMore: boolean = false;
  @State private loadingHistory: boolean = false;
  @State private backupAvailable: boolean = true;
  @State private pinAttemptsRemaining: number = -1;
  @State private pinSheet: boolean = false;
  @State private webHistoryActive: boolean = false;
  @State private webPinWaiting: boolean = false;
  private webOldest: string = '';
  private webHistoryGeneration: number = 0;
  private promptedForPin: boolean = false;
  private reloadAfterUnlock: boolean = false;
  @State private attachments: ChatPickedFile[] = [];
  @State private recentPhotoShown: boolean = false;
  @State private recentPhotoQueryEpoch: number = 0;
  @State private attachmentPanelShown: boolean = false;
  @State private recording: boolean = false;
  @State private recordingPending: boolean = false;
  @State private recordingElapsed: number = 0;
  @State private recordingSamples: number[] = [];
  @State private voiceVisible: boolean = true;
  @State private searchVisible: boolean = false;
  @State @Watch('updateVisibleMessages') private searchQuery: string = '';
  @State private composerHeight: number = 80;
  @State private keyboardVisible: boolean = false;
  @StorageProp('harmonyx.window_height') private chatWindowHeight: number =
    AppStorage.get<number>('harmonyx.window_height') ?? 0;
  @StorageProp('harmonyx.compact_window') private compactWindow: boolean = false;
  @State private replyTarget: DmMessage | null = null;
  @State private reactionTarget: DmMessage | null = null;
  @State private emojiSheet: boolean = false;
  @State private reacting: boolean = false;
  @State private forwardTarget: DmMessage | null = null;
  @State private forwardSheet: boolean = false;
  @State private forwarding: boolean = false;
  @State private contact: ChatContact = new ChatContact();
  @State private contactLoading: boolean = false;
  @State private contactFailed: boolean = false;
  @State private conversationTransport: string = 'unknown';
  @State private numberSheet: boolean = false;
  @State private contactNumber: string = '';
  @State private numberError: string = '';
  @State private checkingNumber: boolean = false;
  @State private numberGranted: boolean = false;
  private pendingDelete: DmMessage | null = null;
  private pendingWebReaction: DmMessage | null = null;
  private pendingWebEmoji: string = '';
  private pendingDeleteAccount: string = '';
  private deleteAfterUnlock: boolean = false;
  private deletingMessages: Set<string> = new Set<string>();
  @State private pinnedMessageId: string = '';
  @StorageProp('harmonyx.accounts_changed') @Watch('accountChanged')
  private accountRevision: number = 0;
  @StorageProp(CHAT_DECORATION_REVISION_KEY) @Watch('decorationChanged')
  private decorationRevision: number = 0;
  private conversationId: string = '';
  @State private title: string = '';
  private originalTitle: string = '';
  private username: string = '';
  @State private avatarUrl: string = '';
  private group: boolean = false;
  private participantIds: string[] = [];
  private latestSequenceId: string = '';
  private maxEntryId: string = '';
  private historyToken: string = '';
  private minKeyVersion: string = '';
  private active: boolean = true;
  private requestGeneration: number = 0;
  private pickerGeneration: number = 0;
  private recentPhotoOptions: RecentPhotoOptions = new RecentPhotoOptions();
  private recentPhotoRequestPending: boolean = false;
  private recentPhotoTimer: number = -1;
  private disposed: boolean = false;
  private gifSelectionAccount: string = '';
  private pollTimer: number = -1;
  private typingTimer: number = -1;
  private typingUntil: number = 0;
  private submittingMedia: boolean = false;
  @State private peerTyping: boolean = false;
  @State private animatedSendIds: string[] = [];
  @StorageProp(STORAGE_KEY_REDUCE_MOTION) private reduceMotion: boolean = false;
  private fetching: boolean = false;
  private scroller: Scroller = new Scroller();
  private recorder: media.AVRecorder | null = null;
  private recordingFile: fileIo.File | null = null;
  private recordingPath: string = '';
  private recordingStarted: number = 0;
  private recordingTimer: number = -1;
  private recordingMeterTimer: number = -1;
  private recordingGeneration: number = 0;
  private samplingAmplitude: boolean = false;
  private readAttempt: string = '';
  private savingImages: boolean = false;
  private mediaActionGeneration: number = 0;
  private keyboardWindow: window.Window | null = null;
  private outboxListener: () => void = (): void => {
    if (this.active && !this.disposed && !this.submittingMedia) { this.syncOutbox(); }
  };
  private replyFocusTimer: number = -1;
  private replyKeyboardRequested: boolean = false;
  private keyboardHeightListener: (height: number) => void = (height: number): void => {
    if (!this.disposed) { this.keyboardVisible = height > 0; }
  };

  private observeKeyboard(): void {
    window.getLastWindow(getContext(this) as common.UIAbilityContext).then((win: window.Window): void => {
      if (this.disposed) { return; }
      this.keyboardWindow = win;
      win.on('keyboardHeightChange', this.keyboardHeightListener);
      this.keyboardVisible = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_KEYBOARD).bottomRect.height > 0;
    }).catch((): void => {});
  }

  private cancelReplyFocus(): void {
    if (this.replyFocusTimer >= 0) { clearTimeout(this.replyFocusTimer); this.replyFocusTimer = -1; }
    this.replyKeyboardRequested = false;
  }

  private showReplyKeyboard(): void {
    if (!this.active || this.disposed || !this.replyKeyboardRequested || this.replyTarget === null) { return; }
    try {
      inputMethod.getController().showTextInput().then((): void => {
        this.replyKeyboardRequested = false;
      }).catch((): void => {});
    } catch (error) {}
  }

  private requestReplyKeyboard(): void {
    this.cancelReplyFocus();
    this.replyKeyboardRequested = true;
    // The native context menu has released focus before this is called. Allow
    // the quoted capsule's TitleBar to commit before focusing its text client.
    this.replyFocusTimer = setTimeout((): void => {
      this.replyFocusTimer = -1;
      if (!this.active || this.disposed || this.replyTarget === null || this.recording) { return; }
      try {
        this.getUIContext().getFocusController().requestFocus(this.attachments.length > 0 ? 'chat-media-input' : 'chat-message-input');
      } catch (error) { this.cancelReplyFocus(); return; }
      this.replyFocusTimer = setTimeout((): void => {
        this.replyFocusTimer = -1;
        this.showReplyKeyboard();
      }, 80);
    }, 80);
  }

  private privacy(enabled: boolean): void {
    setChatWindowPrivacy(getContext(this) as common.UIAbilityContext, enabled);
  }

  aboutToAppear(): void {
    this.disposed = false;
    this.recentPhotoOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    this.recentPhotoOptions.photoSource = PhotoSource.ALL;
    // Let the system recommend the latest asset created within the last day.
    // Each attachment-button tap recreates the query, so period stays valid.
    this.recentPhotoOptions.period = RECENT_PHOTO_MAX_AGE / 1000;
    this.recentPhotoOptions.isAutoRefreshSupported = false;
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    this.observeKeyboard();
    this.readRoute();
    this.restoreWebHistory();
    chatMediaOutbox.subscribe(this.outboxListener);
    this.syncOutbox();
    this.loadContact();
    this.chatBackground = chatBackgroundStore.load(getContext(this) as common.UIAbilityContext, this.conversationId);
    this.chatDecoration = chatDecorationService.selection(getContext(this) as common.UIAbilityContext);
    this.load(true);
  }

  private decorationChanged(): void {
    if (!this.disposed) {
      this.chatDecoration = chatDecorationService.selection(getContext(this) as common.UIAbilityContext);
    }
  }

  aboutToDisappear(): void {
    this.closeAttachmentPanel();
    this.disposed = true;
    chatMediaOutbox.unsubscribe(this.outboxListener);
    this.mediaActionGeneration++;
    this.cancelReplyFocus();
    if (this.keyboardWindow !== null) {
      this.keyboardWindow.off('keyboardHeightChange', this.keyboardHeightListener);
      this.keyboardWindow = null;
    }
    this.pickerGeneration++;
    this.picking = false;
    this.gifSelectionAccount = '';
    this.active = false;
    this.requestGeneration++;
    this.pin = '';
    this.pinSheet = false;
    this.pendingWebReaction = null; this.pendingWebEmoji = '';
    this.contactNumber = '';
    this.pendingDelete = null; this.deleteAfterUnlock = false;
    this.numberSheet = false;
    this.draft = '';
    this.replyTarget = null;
    this.reactionTarget = null;
    this.forwardTarget = null;
    this.stopPolling();
    this.cancelRecording();
    this.discardAttachment();
    this.privacy(false);
  }

  private accountChanged(): void {
    this.closeAttachmentPanel();
    this.recentPhotoQueryEpoch++;
    this.mediaActionGeneration++;
    this.cancelReplyFocus();
    this.pickerGeneration++;
    this.picking = false;
    this.gifSelectionAccount = '';
    this.messages = [];
    this.mediaSends = [];
    this.conversationTransport = 'unknown';
    this.webHistoryActive = false;
    this.webPinWaiting = false;
    this.webOldest = '';
    this.pendingWebReaction = null; this.pendingWebEmoji = '';
    this.pendingDelete = null; this.deleteAfterUnlock = false;
    this.contact = new ChatContact();
    this.contactNumber = '';
    this.numberGranted = false;
    this.numberSheet = false;
    this.pin = '';
    this.pinSheet = false;
    this.promptedForPin = false;
    this.historyToken = '';
    this.draft = '';
    this.replyTarget = null;
    this.emojiSheet = false;
    this.forwardSheet = false;
    this.requestGeneration++;
    this.stopPolling();
    this.cancelRecording();
    this.discardAttachment();
    this.pageStack.pop();
  }

  private stopPolling(): void {
    if (this.pollTimer >= 0) { clearInterval(this.pollTimer); this.pollTimer = -1; }
    this.clearTyping();
  }

  private startPolling(): void {
    if (this.pollTimer >= 0) { clearInterval(this.pollTimer); }
    this.pollTimer = setInterval((): void => {
      if (this.active && !this.fetching && !this.sending && !this.reacting && !this.unlocking && !this.pinSheet && !this.loadingHistory) {
        this.load(false);
      }
    }, 6000);
  }

  private clearTyping(): void {
    if (this.typingTimer >= 0) { clearTimeout(this.typingTimer); this.typingTimer = -1; }
    this.typingUntil = 0;
    this.peerTyping = false;
  }

  private updatePeerTyping(deadline: number): void {
    if (!Number.isFinite(deadline) || deadline <= this.typingUntil || deadline <= Date.now()) { return; }
    if (this.typingTimer >= 0) { clearTimeout(this.typingTimer); }
    this.typingUntil = deadline;
    this.peerTyping = true;
    this.typingTimer = setTimeout((): void => this.clearTyping(), Math.max(0, deadline - Date.now()));
  }

  private animateSentMessage(update: () => void): void {
    if (this.reduceMotion) { update(); }
    else { this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseOut }, update); }
  }

  private readRoute(): void {
    const params: DmConversationRouteParam[] =
      this.pageStack.getParamByName('DmConversation') as DmConversationRouteParam[];
    if (params === undefined || params === null || params.length === 0) {
      return;
    }
    const param: DmConversationRouteParam = params[params.length - 1];
    this.conversationId = param.conversationId;
    this.title = param.title;
    this.originalTitle = param.title;
    this.username = param.username;
    this.avatarUrl = param.avatarUrl;
    this.group = param.group;
    this.participantIds = param.participantIds;
    this.latestSequenceId = param.latestSequenceId;
    if (param.contactProfile !== undefined) { this.contact = ChatContactService.fromProfile(param.contactProfile); }
    else if (!this.group) {
      const initial: ChatContact = new ChatContact();
      initial.id = this.contactId(); initial.name = param.title; initial.username = param.username; initial.avatarUrl = param.avatarUrl;
      initial.verifiedType = param.verifiedType ?? ''; initial.avatarShape = param.avatarShape ?? '';
      initial.verified = initial.verifiedType.length > 0;
      this.contact = initial;
    }
    this.pinnedMessageId = xChatActions.localString(getContext(this) as common.UIAbilityContext, 'pinned_message:' + this.conversationId, '');
    if (param.sharedPayload !== undefined && this.sharedImportId !== param.sharedPayload.id) {
      const payload: ExternalSharePayload = param.sharedPayload;
      this.sharedImportId = payload.id;
      this.draft = payload.text;
      const files: ChatPickedFile[] = payload.files.map((file: ExternalShareFile): ChatPickedFile =>
        xChatMedia.selectedFile(file.uri, file.type));
      this.addAttachments(files);
    }
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private contactId(): string {
    const participant: string = this.participantIds.find((id: string): boolean => id !== xPrivateClient.viewerId()) ?? '';
    if (participant.length > 0) { return participant; }
    if (this.contact.id.length > 0) { return this.contact.id; }
    const pair: string[] = this.conversationId.split('-');
    if (!this.group && pair.length === 2 && /^\d+$/.test(pair[0]) && /^\d+$/.test(pair[1])) {
      return pair[0] === xPrivateClient.viewerId() ? pair[1] : pair[0];
    }
    return '';
  }

  private async loadContact(): Promise<void> {
    const id: string = this.contactId();
    if (this.group || id.length === 0 || this.contactLoading) { return; }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const account: string = xPrivateStore.load(context).cacheIdentity();
    this.contactLoading = true; this.contactFailed = false;
    try {
      const contact: ChatContact = await chatContactService.load(context, id);
      if (this.disposed || account !== xPrivateStore.load(context).cacheIdentity()) { return; }
      this.contact = contact;
      if (contact.name.length > 0) { this.originalTitle = contact.name; this.title = contact.name; }
      if (contact.avatarUrl.length > 0) { this.avatarUrl = contact.avatarUrl; }
      this.username = contact.username;
    } catch (error) {
      if (!this.disposed && account === xPrivateStore.load(context).cacheIdentity()) { this.contactFailed = true; }
    } finally { if (!this.disposed) { this.contactLoading = false; } }
  }

  private plainConversation(): boolean {
    return !this.group && this.contact.cannotMessageReason !== 'RECIPIENT_REQUIRES_ENCRYPTION' &&
      (this.conversationTransport === 'plaintext' || (this.conversationTransport === 'empty' &&
        this.contact.permissionKnown && !this.contact.hasPublicKey));
  }

  private canContact(): boolean {
    return this.group || (!this.contact.permissionKnown && xPrivateClient.hasChatOAuth()) ||
      (this.contact.permissionKnown && (this.contact.canSend ||
      (this.numberGranted && this.contact.cannotMessageReason === 'INBOX_CLOSED')));
  }

  private offerHistoryUnlock(): void {
    if (this.promptedForPin || this.pinSheet || this.pinAttemptsRemaining === 0 || xChatService.isUnlocked() ||
      !this.backupAvailable || this.plainConversation()) { return; }
    this.promptedForPin = true;
    this.pinSheet = true;
  }

  private openContactProfile(): void {
    const author: TweetAuthor = { id: this.contactId(), name: this.title, username: this.username,
      avatarUrl: this.avatarUrl, avatarColor: this.accentColor, verified: this.contact.verified, verifiedType: this.contact.verifiedType, avatarShape: this.contact.avatarShape };
    if (author.id.length > 0) {
      const param: UserDetailRouteParam = { author: author, posts: [] };
      this.pageStack.pushPath({ name: 'UserDetail', param: param });
    }
  }

  private async verifyContactNumber(): Promise<void> {
    if (this.checkingNumber) { return; }
    const number: string = this.contactNumber;
    if (!/^\d{8}$/.test(number.replace(/[\s-]/g, ''))) {
      this.numberError = this.text($r('app.string.chat_contact_number_invalid')); return;
    }
    this.checkingNumber = true; this.numberError = '';
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const account: string = xPrivateStore.load(context).cacheIdentity();
    try {
      await chatContactService.verifyNumber(context, this.contactId(), number);
      if (!this.active || this.disposed || !this.numberSheet || account !== xPrivateStore.load(context).cacheIdentity()) { return; }
      this.numberGranted = true; this.contactNumber = ''; this.numberSheet = false;
    } catch (error) {
      if (this.active && this.numberSheet && account === xPrivateStore.load(context).cacheIdentity()) {
        this.numberError = this.text($r('app.string.chat_contact_number_rejected'));
      }
    } finally { this.checkingNumber = false; }
  }

  private async load(reset: boolean, history: boolean = false): Promise<void> {
    if (!this.active || this.fetching) { return; }
    const generation: number = ++this.requestGeneration;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (this.conversationId.length === 0) {
      this.status = this.text($r('app.string.dm_conversation_missing'));
      this.loading = false;
      return;
    }
    if (history) { this.loadingHistory = true; }
    else if (reset) { this.loading = this.messages.length === 0; }
    this.fetching = true;
    try {
      if (xPrivateClient.isSignedIn() && !xPrivateClient.hasChatOAuth() && (!history || this.webHistoryActive) &&
        await this.loadWebHistory(context, generation, reset, history)) { return; }
      if (!this.active || generation !== this.requestGeneration) { return; }
      try {
        await xChatService.prepare(context, this.participantIds);
        if (generation === this.requestGeneration) { this.keysUnavailable = false; }
      } catch (error) {
        if (generation === this.requestGeneration) { this.keysUnavailable = true; }
        hilog.warn(0xFF00, 'HarmonyX-Chat', 'public keys unavailable: %{public}s', (error as Error).message);
      }
      if (!this.active || generation !== this.requestGeneration) { return; }
      const backupAvailable: boolean = xChatService.hasBackup();
      if (this.backupAvailable !== backupAvailable) { this.backupAvailable = backupAvailable; }
      if (reset && this.messages.length === 0) {
        const cached: XChatPage = new XChatPage();
        cached.messages = xChatService.cachedMessages(this.conversationId);
        if (cached.messages.length > 0) { this.mergeMessages(cached); }
      }
      const page: XChatPage = await xChatService.conversation(this.conversationId,
        history ? this.maxEntryId : '', history ? this.minKeyVersion : '', history ? this.historyToken : '');
      if (!this.active || generation !== this.requestGeneration) { return; }
      const historyRecovered: boolean = this.historyUnavailable && !page.partialHistory;
      if (!history) { this.historyUnavailable = page.partialHistory; }
      if (this.conversationTransport !== page.transport) { this.conversationTransport = page.transport; }
      if (!history) { this.updatePeerTyping(page.typingUntil); }
      this.mergeMessages(page);
      this.syncOutbox(false);
      if (this.group && !page.needsUnlock) {
        const display: XChatGroupDisplay = await xChatService.groupDisplay(this.conversationId, context);
        const nickname: string = await xChatService.nickname(context, this.conversationId);
        if (!this.active || generation !== this.requestGeneration) { return; }
        if (display.name.length > 0) {
          this.originalTitle = display.name;
          const title: string = nickname.length > 0 ? nickname : display.name;
          if (this.title !== title) { this.title = title; }
        }
        if (display.avatarUrl.length > 0 && this.avatarUrl !== display.avatarUrl) { this.avatarUrl = display.avatarUrl; }
      }
      if (this.needsUnlock !== page.needsUnlock) { this.needsUnlock = page.needsUnlock; }
      if (!page.partialHistory && (history || reset || historyRecovered)) {
        this.maxEntryId = page.minSequenceId;
        this.minKeyVersion = page.minKeyVersion;
        this.historyToken = page.nextToken;
        this.hasMore = page.hasMore && (page.nextToken.length > 0 || page.minSequenceId.length > 0);
      }
      if (page.needsUnlock || page.transport === 'encrypted') { this.offerHistoryUnlock(); }
      if (reset || history || page.partialHistory || page.error.length === 0 && this.status.length > 0) {
        this.status = page.error.length > 0 ? this.text($r('app.string.dm_some_unavailable')) : '';
      }
      if (reset) {
        setTimeout((): void => { if (this.active) { this.scroller.scrollEdge(Edge.Bottom); } }, 60);
      }
      const latest: DmMessage | undefined = this.messages.length > 0 ? this.messages[this.messages.length - 1] : undefined;
      if (latest !== undefined && xChatService.isUnlocked() && !page.needsUnlock && latest.sequenceId !== undefined && this.readAttempt !== latest.sequenceId) {
        this.readAttempt = latest.sequenceId;
        xChatService.markRead(this.conversationId, latest.sequenceId, context).catch((error: Error): void => {
          hilog.warn(0xFF00, 'HarmonyX-Chat', 'read failed: %{public}s', error.message); this.readAttempt = '';
        });
      }
    } catch (error) {
      hilog.warn(0xFF00, 'HarmonyX-Chat', 'load failed: %{public}s', (error as Error).message);
      if (this.active && generation === this.requestGeneration && (reset || history || this.messages.length === 0)) {
        if (!history) { this.historyUnavailable = (error as Error).message !== 'conversation_http_404'; }
        this.status = !this.group && this.messages.length === 0 && (error as Error).message === 'conversation_unavailable' ?
          '' : this.text($r('app.string.dm_load_failed'));
        if (reset) { this.offerHistoryUnlock(); }
      }
    } finally {
      this.fetching = false;
      if (generation === this.requestGeneration) {
        this.loading = false;
        this.loadingHistory = false;
        if (this.active && this.reloadAfterUnlock) {
          this.reloadAfterUnlock = false;
          void this.load(true);
        }
      }
    }
  }

  private restoreWebHistory(): void {
    if (!xPrivateClient.isSignedIn() || xPrivateClient.hasChatOAuth()) { return; }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const account: string = xPrivateStore.load(context).cacheIdentity();
    const cached: XChatWebHistorySnapshot | undefined = xChatService.cachedWebHistory(account, this.conversationId);
    if (cached === undefined) { return; }
    this.messages = cached.messages.slice();
    this.webOldest = cached.oldest;
    this.hasMore = cached.hasMore;
    this.webHistoryActive = true;
    this.webHistoryGeneration = xChatService.webHistoryGeneration();
    this.loading = false;
  }

  private saveWebHistory(account: string): void {
    xChatService.cacheWebHistory(account, this.conversationId,
      { messages: this.messages.slice(), oldest: this.webOldest, hasMore: this.hasMore });
  }

  private async loadWebHistory(context: common.UIAbilityContext, generation: number, reset: boolean,
    earlier: boolean, pin: string = ''): Promise<boolean> {
    const account: string = xPrivateStore.load(context).cacheIdentity();
    const historyGeneration: number = xChatService.webHistoryGeneration();
    const current: () => boolean = (): boolean => this.active && !this.disposed &&
      generation === this.requestGeneration && account === xPrivateStore.load(context).cacheIdentity() &&
      historyGeneration === xChatService.webHistoryGeneration() &&
      (AppStorage.get<boolean>('harmonyx.app_foreground') ?? true);
    const viewer: string = xPrivateClient.viewerId();
    const read: Promise<WebChatReply> = readXChatWebHistory(context, this.getUIContext(), viewer, this.conversationId,
      earlier ? this.webOldest : '', current, pin);
    pin = '';
    const result: WebChatReply = await read;
    if (!current()) { return true; }
    if (result.status === 'pin_required' || result.status === 'pin_unconfirmed') {
      if (result.status === 'pin_unconfirmed') { this.unlockError = this.text($r('app.string.dm_unlock_failed')); }
      this.needsUnlock = true;
      this.webPinWaiting = true;
      if (!this.promptedForPin) { this.promptedForPin = true; this.pinSheet = true; }
      return true;
    }
    if (result.status === 'busy') {
      if (reset || earlier) { this.status = this.text($r('app.string.dm_load_failed')); }
      return true;
    }
    if (result.status !== 'history') {
      if (!earlier) { return false; }
      this.status = this.text($r('app.string.dm_load_failed'));
      return true;
    }
    const rows: WebChatMessage[] = result.messages ?? [];
    const messages: DmMessage[] = rows.map((message: WebChatMessage): DmMessage => {
      const incoming: boolean = message.outgoing === false && !this.group;
      const attachments: DmAttachment[] = message.postUrl ? [{ type: 'Post', mediaHash: '', mediaType: 5,
        filename: '', url: message.postUrl, width: 0, height: 0 }] : [];
      return { id: message.id, webMessageId: message.id, conversationId: this.conversationId, text: message.text,
        senderId: message.outgoing ? viewer : incoming ? this.contactId() : '', senderName: incoming ? this.title : '',
        senderUsername: incoming ? this.username : '', senderAvatarUrl: incoming ? this.avatarUrl : '',
        timestampMs: message.timestamp, time: message.timestamp > 0 ? XNotificationParser.relativeTime(message.timestamp) : '',
        outgoing: message.outgoing === true, directionUnknown: message.outgoing === undefined,
        encrypted: false, attachments: attachments };
    });
    const byId: Map<string, DmMessage> = new Map<string, DmMessage>();
    const ordered: DmMessage[] = earlier ? messages.concat(this.messages) : this.messages.concat(messages);
    for (const message of ordered) {
      const previous: DmMessage | undefined = byId.get(message.id);
      if (previous?.sequenceId !== undefined && message.sequenceId === undefined) { continue; }
      if (previous !== undefined && !previous.directionUnknown && message.directionUnknown) { continue; }
      if (previous?.reactions !== undefined && message.reactions === undefined) { message.reactions = previous.reactions; }
      byId.set(message.id, message);
    }
    this.messages = Array.from(byId.values());
    const firstLoad: boolean = this.messages.length === 0;
    if (this.webOldest.length === 0 || earlier) {
      if (rows.length > 0) { this.webOldest = rows[0].id; }
      this.hasMore = result.hasMore === true;
    }
    this.webHistoryActive = true;
    this.webHistoryGeneration = historyGeneration;
    this.webPinWaiting = false;
    this.needsUnlock = false;
    this.historyUnavailable = false;
    this.status = '';
    this.saveWebHistory(account);
    if (reset && firstLoad) { setTimeout((): void => { if (current()) { this.scroller.scrollEdge(Edge.Bottom); } }, 60); }
    return true;
  }

  private async unlock(): Promise<void> {
    if (this.unlocking || this.pin.length !== 4 || this.pinAttemptsRemaining === 0) { return; }
    this.unlocking = true;
    this.unlockError = '';
    const pin: string = this.pin;
    this.pin = '';
    try {
      if (this.webPinWaiting && this.pendingDelete === null) {
        const restored: boolean = await this.loadWebHistory(getContext(this) as common.UIAbilityContext,
          this.requestGeneration, true, false, pin);
        if (restored && !this.webPinWaiting) {
          const target: DmMessage | null = this.pendingWebReaction;
          const emoji: string = this.pendingWebEmoji;
          this.pinSheet = false;
          if (target !== null) { await this.react(target, emoji); }
        }
        else if (!restored) { this.unlockError = this.text($r('app.string.dm_unlock_failed')); }
        return;
      }
      if (!xChatService.hasBackup()) {
        await xChatService.prepare(getContext(this) as common.UIAbilityContext, []);
      }
      if (!this.active || !this.pinSheet) { return; }
      await xChatService.unlock(pin);
      if (!this.active) { return; }
      this.needsUnlock = false;
      this.deleteAfterUnlock = this.pendingDelete !== null;
      this.pinSheet = false;
      if (this.fetching) { this.reloadAfterUnlock = true; }
      else { await this.load(true); }
    } catch (error) {
      if (this.active) {
        const reason: string = (error as Error).message;
        const budget: RegExpMatchArray | null = reason.match(/guesses_remaining=(\d+)/);
        if (budget !== null) { this.pinAttemptsRemaining = parseInt(budget[1], 10); }
        if (this.pinAttemptsRemaining === 0) {
          this.unlockError = this.text($r('app.string.dm_pin_exhausted'));
        } else {
          this.unlockError = this.text(reason.indexOf('InvalidPin') >= 0 || reason.indexOf('Invalid PIN') >= 0 ?
            $r('app.string.dm_pin_incorrect') : $r('app.string.dm_unlock_failed'));
          if (budget !== null) {
            const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
            this.unlockError += ' ' + context.resourceManager.getStringSync(
              $r('app.string.dm_pin_attempts').id, this.pinAttemptsRemaining);
          }
        }
      }
    } finally { this.unlocking = false; }
  }

  private async send(): Promise<void> {
    const text: string = this.draft.trim();
    if ((text.length === 0 && this.attachments.length === 0) || this.sending || this.picking || this.recording ||
      !this.canContact() || (!this.plainConversation() && !xChatService.isUnlocked())) { return; }
    if (!this.plainConversation() && this.attachments.length > 0 &&
      this.attachments.every((file: ChatPickedFile): boolean => file.type >= 1 && file.type <= 3)) {
      this.submittingMedia = true;
      try {
        const send: ChatMediaSend = chatMediaOutbox.enqueue(getContext(this) as common.UIAbilityContext, this.conversationId,
          this.attachments, text, this.replyTarget ?? undefined);
        this.animateSentMessage((): void => {
          this.animatedSendIds = [send.id + ':pending'];
          this.syncOutbox();
        });
        // Ownership has moved to the outbox. Clearing the composer must not
        // discard an upload or remove a camera resource it is still reading.
        this.attachments = []; this.draft = ''; this.replyTarget = null; this.cancelReplyFocus();
        this.scroller.scrollEdge(Edge.Bottom);
      } catch (error) {
        promptAction.showToast({ message: this.text((error as Error).message === 'media_queue_full' ?
          $r('app.string.chat_media_queue_full') : $r('app.string.dm_send_failed')) });
      } finally { this.submittingMedia = false; }
      return;
    }
    this.sending = true;
    this.sendUnavailable = false;
    const conversation: string = this.conversationId;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const account: string = xPrivateStore.load(context).cacheIdentity();
    try {
      const reply: XChatReplyTarget | undefined = this.replyTarget === null ? undefined : {
        sequence_id: this.replyTarget.sequenceId ?? '', sender_id: this.replyTarget.senderId,
        text: this.replyTarget.text, raw_event: this.replyTarget.rawEvent ?? '', key_version: this.replyTarget.keyVersion ?? ''
      };
      let page: XChatPage;
      if (this.plainConversation()) {
        page = new XChatPage();
        page.messages = await chatContactService.sendPlaintext(context, this.contact, conversation, text);
      } else {
        page = this.attachments.length === 0 ? await xChatService.send(conversation, text, [], '', '', reply) :
          await xChatMedia.sendMany(context, conversation, this.attachments, text, reply);
      }
      if (!this.active || this.disposed || this.conversationId !== conversation ||
        account !== xPrivateStore.load(context).cacheIdentity()) { return; }
      this.conversationTransport = xChatService.conversationTransport(this.conversationId);
      this.animateSentMessage((): void => {
        this.animatedSendIds = page.messages.filter((message: DmMessage): boolean => message.outgoing)
          .map((message: DmMessage): string => message.id + ':sent');
        this.mergeMessages(page);
      });
      this.draft = '';
      this.replyTarget = null;
      this.discardAttachment();
      this.scroller.scrollEdge(Edge.Bottom);
    } catch (error) {
      const reason: string = (error as Error).message;
      hilog.warn(0xFF00, 'HarmonyX-Chat', 'send failed: %{public}s', reason);
      if (this.active && this.conversationId === conversation && account === xPrivateStore.load(context).cacheIdentity()) {
        this.sendUnavailable = reason === 'existing_conversation_key_unavailable' ||
          /^(conversation|keys|send)_(network|dependency|http_(401|402|403|429|50[234])|unconfirmed)$/.test(reason);
        promptAction.showToast({ message: chatFailureMessage(context, reason, $r('app.string.dm_send_failed')),
          duration: 2400 });
      }
    } finally { this.sending = false; }
  }

  private avatarInitial(): string {
    if (this.title.length > 0) {
      return this.title.substring(0, 1).toUpperCase();
    }
    return 'X';
  }

  private openInfo(): void {
    const param: DmInfoRouteParam = { conversationId: this.conversationId, title: this.title,
      username: this.username, avatarUrl: this.avatarUrl, verifiedType: this.contact.verifiedType, avatarShape: this.contact.avatarShape, group: this.group,
      participantIds: this.participantIds, latestSequenceId: this.latestSequenceId };
    this.pageStack.pushPath({ name: this.group ? 'DmGroup' : 'DmInfo', param: param });
  }

  private call(): void {
    this.openWebChat();
    promptAction.showToast({ message: this.text($r('app.string.chat_call_web_hint')), duration: 3500 });
  }

  private openWebChat(): void {
    const param: DmWebRouteParam = { conversationId: this.conversationId, title: this.title };
    this.pageStack.pushPath({ name: 'DmWeb', param: param });
  }

  private updateVisibleMessages(): void {
    const rows: DmMessage[] = ChatMediaOutbox.timeline(this.messages, this.mediaSends);
    const query: string = this.searchQuery.trim().toLowerCase();
    this.visibleTimeline = query.length === 0 ? rows :
      rows.filter((message: DmMessage): boolean => message.text.toLowerCase().indexOf(query) >= 0);
  }

  private mediaSend(id: string): ChatMediaSend | undefined {
    const send: ChatMediaSend | undefined = this.mediaSends.find((entry: ChatMediaSend): boolean => entry.id === id);
    // An echoed/confirmed row replaces the local card, including confirmation
    // that arrived through polling after a request timed out.
    return send !== undefined && !this.messages.some((message: DmMessage): boolean => message.id === id) ? send : undefined;
  }

  private mediaFailed(id: string): boolean { return this.mediaSend(id)?.state === 'failed'; }

  private mergeMessages(page: XChatPage): void {
    const previous: DmMessage[] = this.messages;
    const merged: DmMessage[] = xChatService.mergeConversation(previous, page, this.conversationId);
    if (merged !== previous) { this.messages = merged; }
  }

  private syncOutbox(refreshMedia: boolean = true): void {
    if (refreshMedia) {
      this.mediaSends = chatMediaOutbox.pending(getContext(this) as common.UIAbilityContext, this.conversationId);
    }
    const cached: DmMessage[] = xChatService.cachedMessages(this.conversationId);
    if (cached.length === 0) { return; }
    const shownIds: Set<string> = new Set<string>(this.messages.map((message: DmMessage): string => message.id));
    const confirmed: DmMessage[] = cached.filter((message: DmMessage): boolean => !shownIds.has(message.id));
    if (confirmed.length > 0) {
      const page: XChatPage = new XChatPage(); page.messages = confirmed;
      this.mergeMessages(page);
    }
  }

  private emoji(message: DmMessage): boolean {
    return chatEmojiImages.enlarged(getContext(this) as common.UIAbilityContext, message.text);
  }

  private showTime(index: number): boolean {
    const rows: DmMessage[] = this.visibleTimeline;
    return index === 0 || (index > 0 && index < rows.length &&
      rows[index].timestampMs - rows[index - 1].timestampMs > 300000);
  }

  private groupEnd(index: number): boolean {
    const rows: DmMessage[] = this.visibleTimeline;
    return index >= rows.length - 1 || !rows[index + 1].outgoing || this.showTime(index + 1);
  }

  private acceptsPicker(generation: number, account: string): boolean {
    // System pickers can hide this destination before returning their result.
    // Invalidate only when this page is removed, replaced, or the account changes.
    return !this.disposed && generation === this.pickerGeneration &&
      account === xPrivateStore.load(getContext(this) as common.UIAbilityContext).cacheIdentity();
  }

  private canShowRecentPhoto(): boolean {
    return this.canContact() && !this.plainConversation() && !this.needsUnlock && xChatService.isUnlocked() &&
      this.attachments.length === 0 && !this.recording && !this.recordingPending;
  }

  private hideRecentPhoto(): void {
    if (this.recentPhotoTimer >= 0) { clearTimeout(this.recentPhotoTimer); this.recentPhotoTimer = -1; }
    this.recentPhotoRequestPending = false;
    this.recentPhotoShown = false;
  }

  private closeAttachmentPanel(): void {
    this.hideRecentPhoto();
    this.attachmentPanelShown = false;
  }

  private checkRecentPhoto(exists: boolean, epoch: number): void {
    if (epoch !== this.recentPhotoQueryEpoch || !this.active || this.disposed) { return; }
    if (!exists) { this.hideRecentPhoto(); return; }
    if (!this.recentPhotoRequestPending || !this.attachmentPanelShown || !this.canShowRecentPhoto()) { return; }
    this.recentPhotoRequestPending = false;
    this.recentPhotoShown = true;
    this.recentPhotoTimer = setTimeout((): void => {
      this.recentPhotoTimer = -1;
      this.recentPhotoShown = false;
    }, RECENT_PHOTO_DISMISS_DELAY);
  }

  private toggleAttachmentPanel(): void {
    if (!this.active || this.disposed || !this.canShowRecentPhoto() || this.sending || this.picking) { return; }
    this.hideRecentPhoto();
    this.attachmentPanelShown = !this.attachmentPanelShown;
    if (this.attachmentPanelShown) {
      this.recentPhotoRequestPending = true;
      this.recentPhotoQueryEpoch++;
    }
  }

  private async insertRecentPhoto(info: BaseItemInfo): Promise<void> {
    const uri: string = info.uri ?? '';
    if (!this.active || this.disposed || !this.canShowRecentPhoto() || this.sending || this.picking || uri.length === 0) { return; }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const account: string = xPrivateStore.load(context).cacheIdentity();
    const generation: number = ++this.pickerGeneration;
    this.closeAttachmentPanel();
    this.picking = true;
    try {
      // The native component grants this URI's read permission on the tap.
      // Reuse album selection so MovingPhoto handles and media limits agree.
      const file: ChatPickedFile = await xChatMedia.selectedMedia(context, uri);
      if (!this.acceptsPicker(generation, account) || !this.canShowRecentPhoto()) { return; }
      if (info.mimeType === 'image/gif') { file.type = 2; }
      this.addAttachments([file]);
    } catch (error) {
      hilog.warn(0xFF00, 'HarmonyX-Chat', 'recent photo selection failed: %{public}s', (error as Error).message);
      if (this.acceptsPicker(generation, account)) {
        promptAction.showToast({ message: this.text($r('app.string.chat_action_failed')) });
      }
    } finally {
      if (generation === this.pickerGeneration) { this.picking = false; }
    }
  }

  private async pick(kind: string): Promise<void> {
    if (!xChatService.isUnlocked() || this.sending || this.picking || this.recording || this.recordingPending) { return; }
    hilog.info(0xFF00, 'HarmonyX-Chat', 'attachment action: %{public}s', kind);
    this.closeAttachmentPanel();
    if (kind !== 'files' && this.remainingMediaSlots() <= 0) { return; }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const account: string = xPrivateStore.load(context).cacheIdentity();
    const generation: number = ++this.pickerGeneration;
    if (kind === 'gif') {
      gifSearchSelectionStore.take();
      this.gifSelectionAccount = account;
      this.pageStack.pushPath({ name: 'GifSearchPage' });
      return;
    }
    this.picking = true;
    let cameraPath: string = '';
    try {
      if (kind === 'photos') {
        const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
        options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_VIDEO_TYPE;
        options.isMovingPhotoBadgeShown = true;
        options.maxSelectNumber = this.remainingMediaSlots();
        const result: photoAccessHelper.PhotoSelectResult = await new photoAccessHelper.PhotoViewPicker().select(options);
        if (this.acceptsPicker(generation, account) && result.photoUris.length > 0) {
          const selected: ChatPickedFile[] = [];
          for (let i: number = 0; i < result.photoUris.length; i++) {
            const file: ChatPickedFile = await xChatMedia.selectedMedia(context, result.photoUris[i]);
            if (!this.acceptsPicker(generation, account)) { return; }
            selected.push(file);
          }
          this.addAttachments(selected);
        }
      } else if (kind === 'camera') {
        const path: string = context.cacheDir + '/xchat_camera_' + Date.now() + '.jpg';
        cameraPath = path;
        const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE); fileIo.closeSync(file.fd);
        const profile: cameraPicker.PickerProfile = { cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK,
          saveUri: fileUri.getUriFromPath(path) };
        const result: cameraPicker.PickerResult = await cameraPicker.pick(context, [cameraPicker.PickerMediaType.PHOTO], profile);
        if (this.acceptsPicker(generation, account) && result.resultCode === 0) {
          this.addAttachments([{ uri: path, filename: 'photo.jpg', type: 1 }]);
          cameraPath = '';
        }
      } else {
        const dialog: picker.DocumentViewPicker = new picker.DocumentViewPicker(getContext(this) as common.UIAbilityContext);
        const options: picker.DocumentSelectOptions = { maxSelectNumber: 1 };
        const uris: string[] = await dialog.select(options);
        if (this.acceptsPicker(generation, account) && uris.length > 0) {
          this.discardAttachment(); this.attachments = [xChatMedia.selectedFile(uris[0], 5)];
        }
      }
    } catch (error) {
      const reason: string = (error as Error).message;
      hilog.warn(0xFF00, 'HarmonyX-Chat', 'attachment picker failed: %{public}s', reason);
      if (this.acceptsPicker(generation, account) && reason.toLowerCase().indexOf('cancel') < 0) {
        promptAction.showToast({ message: this.text($r('app.string.chat_action_failed')) });
      }
    } finally {
      if (cameraPath.length > 0) { this.removeOwnedFile(cameraPath); }
      if (generation === this.pickerGeneration) { this.picking = false; }
    }
  }

  private async record(): Promise<void> {
    if (this.recordingPending) { return; }
    if (this.recording) {
      this.recordingPending = true;
      const generation: number = ++this.recordingGeneration;
      const duration: number = Date.now() - this.recordingStarted;
      const samples: number[] = this.recordingSamples.slice();
      const recorder: media.AVRecorder | null = this.recorder;
      const file: fileIo.File | null = this.recordingFile;
      const path: string = this.recordingPath;
      this.recorder = null; this.recordingFile = null; this.recordingPath = '';
      this.recording = false;
      this.stopRecordingTimers();
      try {
        await recorder?.stop();
        if (!this.disposed && this.active && generation === this.recordingGeneration && duration >= 300) {
          this.discardAttachment();
          this.attachments = [{ uri: path, filename: 'voice.m4a', type: 4, duration: duration, waveform: samples }];
          hilog.info(0xFF00, 'HarmonyX-Voice', 'recording ready: duration=%{public}d samples=%{public}d', duration, samples.length);
        } else {
          this.removeOwnedFile(path);
          if (generation === this.recordingGeneration && this.active && duration < 300) {
            promptAction.showToast({ message: this.text($r('app.string.chat_voice_too_short')) });
          }
        }
      } catch (error) {
        this.removeOwnedFile(path);
        if (generation === this.recordingGeneration) { promptAction.showToast({ message: this.text($r('app.string.chat_action_failed')) }); }
      } finally {
        try { await recorder?.release(); } catch (error) {}
        if (file !== null) { try { fileIo.closeSync(file.fd); } catch (error) {} }
        this.recordingPending = false;
      }
      return;
    }
    if (!xChatService.isUnlocked() || this.sending || this.picking || this.attachments.length > 0) { return; }
    this.recordingPending = true;
    const generation: number = ++this.recordingGeneration;
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const access: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const permission: PermissionRequestResult = await access.requestPermissionsFromUser(context, ['ohos.permission.MICROPHONE']);
      if (!this.active || generation !== this.recordingGeneration || permission.authResults[0] !== 0) { return; }
      this.recordingPath = context.cacheDir + '/xchat_voice_' + Date.now() + '.m4a';
      this.recordingFile = fileIo.openSync(this.recordingPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
      const recorder: media.AVRecorder = await media.createAVRecorder();
      if (generation !== this.recordingGeneration) { await recorder.release(); return; }
      this.recorder = recorder;
      // Match the APK's mono AAC-LC in an MP4/M4A container.
      const profile: media.AVRecorderProfile = { audioBitrate: 32000, audioChannels: 1,
        audioCodec: media.CodecMimeType.AUDIO_AAC, audioSampleRate: 22050, fileFormat: media.ContainerFormatType.CFT_MPEG_4 };
      const config: media.AVRecorderConfig = { audioSourceType: media.AudioSourceType.AUDIO_SOURCE_TYPE_MIC,
        profile: profile, url: 'fd://' + this.recordingFile.fd };
      await recorder.prepare(config);
      if (!this.active || generation !== this.recordingGeneration) { return; }
      await recorder.start();
      if (!this.active || generation !== this.recordingGeneration) { return; }
      this.recordingStarted = Date.now(); this.recordingElapsed = 0; this.recordingSamples = []; this.recording = true;
      hilog.info(0xFF00, 'HarmonyX-Voice', 'recording started');
      this.recordingTimer = setTimeout((): void => { this.record(); }, 120000);
      this.recordingMeterTimer = setInterval((): void => { this.sampleRecording(generation); }, 100);
    } catch (error) {
      if (generation === this.recordingGeneration) {
        this.cancelRecording(); promptAction.showToast({ message: this.text($r('app.string.chat_action_failed')) });
      }
    }
    finally { this.recordingPending = false; }
  }

  private cancelRecording(): void {
    this.recordingGeneration++;
    this.recording = false;
    this.stopRecordingTimers();
    this.recordingElapsed = 0; this.recordingSamples = [];
    const recorder: media.AVRecorder | null = this.recorder;
    const file: fileIo.File | null = this.recordingFile;
    const path: string = this.recordingPath;
    this.recordingPath = '';
    this.recorder = null; this.recordingFile = null;
    const close: () => void = (): void => {
      if (file !== null) { try { fileIo.closeSync(file.fd); } catch (error) {} }
      this.removeOwnedFile(path);
    };
    if (recorder !== null) { recorder.release().then(close).catch(close); } else { close(); }
  }

  private stopRecordingTimers(): void {
    if (this.recordingTimer >= 0) { clearTimeout(this.recordingTimer); this.recordingTimer = -1; }
    if (this.recordingMeterTimer >= 0) { clearInterval(this.recordingMeterTimer); this.recordingMeterTimer = -1; }
  }

  private async sampleRecording(generation: number): Promise<void> {
    const recorder: media.AVRecorder | null = this.recorder;
    if (recorder === null || !this.recording || this.samplingAmplitude) { return; }
    this.recordingElapsed = Date.now() - this.recordingStarted;
    this.samplingAmplitude = true;
    try {
      const amplitude: number = await recorder.getAudioCapturerMaxAmplitude();
      if (generation === this.recordingGeneration && this.recording && Number.isFinite(amplitude)) {
        this.recordingSamples = [...this.recordingSamples, Math.max(0, amplitude)];
      }
    } catch (error) { /* A stopped recorder can complete its last sample late. */ }
    finally { this.samplingAmplitude = false; }
  }

  private removeOwnedFile(path: string): void {
    const cache: string = (getContext(this) as common.UIAbilityContext).cacheDir + '/';
    if (!path.startsWith(cache)) { return; }
    const name: string = path.substring(cache.length);
    if (!/^xchat_(voice_\d+\.m4a|camera_\d+\.jpg)$/.test(name)) { return; }
    try { fileIo.unlinkSync(path); } catch (error) {}
  }

  private discardAttachment(): void {
    const files: ChatPickedFile[] = this.attachments;
    this.attachments = [];
    xChatMedia.discardPicked(files);
    for (let i: number = 0; i < files.length; i++) { this.removeOwnedFile(files[i].uri); }
  }

  private remainingMediaSlots(): number {
    return this.attachments.some((file: ChatPickedFile): boolean => file.type >= 4) ? XChatMedia.MAX_MEDIA_ATTACHMENTS :
      Math.max(0, XChatMedia.MAX_MEDIA_ATTACHMENTS - XChatMedia.mediaSlots(this.attachments));
  }

  private addAttachments(files: ChatPickedFile[]): void {
    if (this.attachments.some((file: ChatPickedFile): boolean => file.type >= 4)) { this.discardAttachment(); }
    const next: ChatPickedFile[] = this.attachments.slice();
    let limited: boolean = false;
    for (let i: number = 0; i < files.length; i++) {
      if (next.some((file: ChatPickedFile): boolean => file.uri === files[i].uri)) { continue; }
      if (XChatMedia.mediaSlots(next) + XChatMedia.mediaSlots([files[i]]) > XChatMedia.MAX_MEDIA_ATTACHMENTS) { limited = true; continue; }
      next.push(files[i]);
    }
    this.attachments = next;
    if (limited) { promptAction.showToast({ message: this.text($r('app.string.chat_media_limit')) }); }
  }

  private removeAttachment(uri: string): void {
    xChatMedia.discardPicked(this.attachments.filter((file: ChatPickedFile): boolean => file.uri === uri));
    this.attachments = this.attachments.filter((file: ChatPickedFile): boolean => file.uri !== uri);
    this.removeOwnedFile(uri);
  }

  private async deleteMessage(message: DmMessage): Promise<void> {
    if (this.sending) { return; }
    if (!xChatService.isUnlocked()) {
      if (!this.backupAvailable) {
        promptAction.showToast({ message: this.text($r('app.string.dm_no_backup')) }); return;
      }
      this.pendingDelete = message;
      this.pendingDeleteAccount = xPrivateStore.load(getContext(this) as common.UIAbilityContext).cacheIdentity();
      this.deleteAfterUnlock = false; this.pinSheet = true; return;
    }
    const account: string = xPrivateStore.load(getContext(this) as common.UIAbilityContext).cacheIdentity();
    const deletionKey: string = account + ':' + this.conversationId + ':' + message.id;
    if (this.deletingMessages.has(deletionKey)) { return; }
    this.deletingMessages.add(deletionKey);
    try {
      const page: XChatPage = await xChatService.deleteMessages(this.conversationId, [message.sequenceId ?? '']);
      if (this.active && account === xPrivateStore.load(getContext(this) as common.UIAbilityContext).cacheIdentity()) {
        this.messages = xChatService.mergeConversation(this.messages, page, this.conversationId);
        if (this.replyTarget?.id === message.id) { this.replyTarget = null; this.cancelReplyFocus(); }
      }
    } catch (error) {
      hilog.warn(0xFF00, 'HarmonyX-Chat', 'delete failed: %{public}s', (error as Error).message);
      if (this.active && account === xPrivateStore.load(getContext(this) as common.UIAbilityContext).cacheIdentity()) {
        promptAction.showToast({ message: this.text($r('app.string.chat_action_failed')) });
      }
    } finally { this.deletingMessages.delete(deletionKey); }
  }

  private pinClosed(): void {
    this.pin = '';
    this.pendingWebReaction = null; this.pendingWebEmoji = '';
    const message: DmMessage | null = this.pendingDelete;
    const ready: boolean = this.deleteAfterUnlock && this.active && !this.disposed &&
      this.pendingDeleteAccount === xPrivateStore.load(getContext(this) as common.UIAbilityContext).cacheIdentity();
    this.pendingDelete = null; this.deleteAfterUnlock = false;
    if (ready && message !== null) { this.deleteMessage(message); }
  }

  private async shown(): Promise<void> {
    this.active = true;
    if (this.webHistoryActive && this.webHistoryGeneration !== xChatService.webHistoryGeneration()) {
      this.messages = [];
      this.webHistoryActive = false;
      this.webOldest = '';
      this.hasMore = false;
      if (this.fetching) { this.reloadAfterUnlock = true; }
      else { void this.load(true); }
    }
    this.syncOutbox();
    this.chatBackground = chatBackgroundStore.load(getContext(this) as common.UIAbilityContext, this.conversationId);
    this.chatDecoration = chatDecorationService.selection(getContext(this) as common.UIAbilityContext);
    this.voiceVisible = true;
    if (this.gifSelectionAccount.length > 0) {
      const gif: string = gifSearchSelectionStore.take();
      if (gif.length > 0 && this.gifSelectionAccount ===
        xPrivateStore.load(getContext(this) as common.UIAbilityContext).cacheIdentity()) {
        this.addAttachments([{ uri: gif, filename: 'animation.gif', type: 2 }]);
      }
      this.gifSelectionAccount = '';
    }
    if (AppStorage.get<string>('harmonyx.chat_search_conversation') === this.conversationId) {
      AppStorage.setOrCreate<string>('harmonyx.chat_search_conversation', ''); this.searchVisible = true;
    }
    try {
      const nickname: string = await xChatService.nickname(getContext(this) as common.UIAbilityContext, this.conversationId);
      if (this.active) { this.title = nickname.length > 0 ? nickname : this.originalTitle; }
    } catch (error) {}
    this.startPolling();
    this.privacy(xChatService.conversationInfo(this.conversationId).screenBlocked);
  }

  @Builder
  private DecoratedAvatar(url: string, size: number, radius: number, fallbackText: string,
    verifiedType: string, avatarShape: string): void {
    Stack({ alignContent: Alignment.Center }) {
      ProxyAvatar({ verifiedType: verifiedType, avatarShape: avatarShape, url: url,
        avatarSize: size, radius: radius, fallbackText: fallbackText })
      if (this.chatDecoration.frameUri.length > 0) {
        Image(this.chatDecoration.frameUri)
          .width(size * 1.78).height(size * 1.78).objectFit(ImageFit.Contain)
          .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      }
    }.width(size * 1.78).height(size * 1.78)
  }

  @Builder
  private ContactTitle(): void {
    Row() {
      Row() {
        Row({ space: 8 }) {
          Button({ type: ButtonType.Normal, stateEffect: false }) {
            this.DecoratedAvatar(this.avatarUrl, 28, 14, this.avatarInitial(),
              this.contact.verifiedType ?? '', this.contact.avatarShape ?? '')
          }.width(50).height(50).borderRadius(25).padding(0).backgroundColor(Color.Transparent)
            .monopolizeEvents(true)
            .onClick((): void => { if (this.group) { this.openInfo(); } else { this.openContactProfile(); } })
          Column({ space: 2 }) {
            Row({ space: 4 }) {
              Text(this.title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
              if (!this.group) { this.ContactBadges(); }
            }.width('100%')
            if (this.conversationTransport === 'plaintext' || this.conversationTransport === 'encrypted') {
              Row({ space: 4 }) {
                SymbolGlyph(this.conversationTransport === 'plaintext' ? $r('sys.symbol.lock_open') : $r('sys.symbol.lock'))
                  .fontSize(12).fontColor([$r('app.color.text_secondary')])
                Text(this.conversationTransport === 'plaintext' ? $r('app.string.chat_contact_unencrypted') : $r('app.string.chat_contact_encrypted')).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary'))
              }
            }
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.height(56).width('100%')
      }.height(56).layoutWeight(1).padding(0).backgroundColor(Color.Transparent)
        .accessibilityText(this.title).onClick((): void => this.openInfo())
    }.height(56).width('100%').padding({
      left: $r('app.float.chat_contact_title_leading'), right: $r('app.float.chat_contact_title_trailing')
    }).hitTestBehavior(HitTestMode.Transparent)
  }

  private verificationColor(): ResourceColor {
    const type: string = this.contact.verifiedType.toLowerCase();
    return type === 'business' ? $r('app.color.follow_badge_gold') : type === 'government' ?
      $r('app.color.text_secondary') : $r('app.color.chat_badge_blue');
  }

  @Builder
  private ContactBadges(): void {
    if (this.contact.verified) {
      SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(16).fontColor([this.verificationColor()])
        .accessibilityText($r('app.string.profile_verified'))
    }
    if (this.contact.affiliationUrl.length > 0) {
      ProxyAvatar({ url: this.contact.affiliationUrl, avatarSize: 18, radius: 3, fallbackText: '' })
        .accessibilityText(this.contact.affiliationLabel)
    }
  }

  @Builder
  private ContactIntro(): void {
    Column({ space: 12 }) {
      Row({ space: 6 }) {
        Text(this.title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_L')).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        this.ContactBadges();
      }.justifyContent(FlexAlign.Center)
      if (this.username.length > 0) {
        Text('@' + this.username).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_secondary'))
      }
      if (this.contact.createdAt.length > 0) {
        Text(this.text($r('app.string.profile_joined')) + ' ' +
          (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync($r('app.string.profile_year_month'),
            new Date(this.contact.createdAt).getFullYear(), new Date(this.contact.createdAt).getMonth() + 1)).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_secondary'))
      }
      if (this.contact.followersKnown) {
        Text(formatCount(this.contact.followers) + ' ' + this.text($r('app.string.profile_followers'))).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_secondary'))
      }
      Button($r('app.string.chat_contact_view_profile')).height(42).padding({ left: 24, right: 24 })
        .fontColor($r('app.color.text_primary')).backgroundColor(secondaryButtonSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
        .onClick((): void => { this.openContactProfile(); })
    }.width('100%').padding({ left: 24, right: 24, top: 28, bottom: 24 })
  }

  private messageSummary(message: DmMessage): string {
    if (message.text.length > 0) { return message.text; }
    if (ChatMovingPhotoProtocol.group(message.attachments ?? []).some((item: ChatMediaItem): boolean => item.video !== undefined)) {
      return this.text($r('app.string.chat_moving_photo'));
    }
    const attachment: DmAttachment | undefined = message.attachments?.[0];
    return attachment === undefined ? '' : attachment.mediaType === 4 ? this.text($r('app.string.chat_voice_messages')) :
      attachment.mediaType === 2 ? 'GIF' : attachment.mediaType === 1 ? this.text($r('app.string.chat_photos')) : attachment.filename;
  }

  private senderLabel(message: DmMessage): string {
    if (message.directionUnknown) { return ''; }
    return message.outgoing ? this.text($r('app.string.chat_message_you')) : !this.group ? this.title : message.senderName;
  }

  private chooseReply(message: DmMessage): void {
    this.replyTarget = message;
    this.requestReplyKeyboard();
  }

  private async copyMessage(message: DmMessage): Promise<void> {
    try { await pasteboard.getSystemPasteboard().setPasteData(pasteboard.createPlainTextData(message.text)); }
    catch (error) { promptAction.showToast({ message: this.text($r('app.string.chat_action_failed')) }); }
  }

  private async saveMessageImages(message: DmMessage): Promise<void> {
    if (this.savingImages || !this.active || !xChatService.isUnlocked()) { return; }
    const attachments: DmAttachment[] = (message.attachments ?? []).filter((attachment: DmAttachment): boolean =>
      attachment.type === 'Media' && (attachment.mediaType === 1 || attachment.mediaType === 2));
    if (attachments.length === 0) { return; }
    const generation: number = this.mediaActionGeneration;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const account: string = xPrivateStore.load(context).cacheIdentity();
    const paths: string[] = [];
    const names: string[] = [];
    this.savingImages = true;
    try {
      for (let i: number = 0; i < attachments.length; i++) {
        const attachment: DmAttachment = attachments[i];
        const path: string = await xChatMedia.receive(context, this.conversationId, attachment.mediaHash,
          message.keyVersion ?? '', attachment.mediaType, attachment.rawEvent);
        if (!this.active || this.disposed || generation !== this.mediaActionGeneration ||
          account !== xPrivateStore.load(context).cacheIdentity() || !xChatService.isUnlocked()) { return; }
        paths.push(path);
        const original: string = attachment.filename.replace(/[\\/:*?"<>|]/g, '_');
        let name: string = original.length > 0 ? original : 'photo-' + (i + 1).toString() + (attachment.mediaType === 2 ? '.gif' : '.jpg');
        if (names.indexOf(name) >= 0) { name = (i + 1).toString() + '-' + name; }
        names.push(name);
      }
      const dialog: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      const options: picker.DocumentSaveOptions = { newFileNames: names };
      const uris: string[] = await dialog.save(options);
      if (uris.length === 0 || !this.active || this.disposed || generation !== this.mediaActionGeneration ||
        account !== xPrivateStore.load(context).cacheIdentity() || !xChatService.isUnlocked()) { return; }
      if (uris.length !== paths.length) { throw new Error('save_target_count'); }
      for (let i: number = 0; i < paths.length; i++) {
        const file: fileIo.File = fileIo.openSync(uris[i], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
        try { fileIo.copyFileSync(paths[i], file.fd); } finally { fileIo.closeSync(file.fd); }
      }
    } catch (error) {
      if (this.active && !this.disposed && generation === this.mediaActionGeneration) {
        promptAction.showToast({ message: this.text($r('app.string.chat_action_failed')) });
      }
    } finally { this.savingImages = false; }
  }

  private pinMessage(message: DmMessage): void {
    this.pinnedMessageId = this.pinnedMessageId === message.id ? '' : message.id;
    xChatActions.saveLocal(getContext(this) as common.UIAbilityContext, 'pinned_message:' + this.conversationId, this.pinnedMessageId);
  }

  private messageInfo(message: DmMessage): void {
    this.getUIContext().showAlertDialog({ title: this.text($r('app.string.chat_message_info')),
      message: this.senderLabel(message) + '\n' + new Date(message.timestampMs).toLocaleString() +
        (message.outgoing ? '\n' + this.text(message.read ? $r('app.string.chat_read') : $r('app.string.chat_sent')) : '') +
        (this.pinnedMessageId === message.id ? '\n' + this.text($r('app.string.chat_message_pin_local')) : ''),
      confirm: { value: this.text($r('app.string.chat_message_ok')), action: (): void => {} } });
  }

  private confirmDelete(message: DmMessage): void {
    this.getUIContext().showAlertDialog({ title: this.text($r('app.string.chat_message_delete_mine')),
      message: this.text($r('app.string.chat_message_delete_confirm')),
      primaryButton: { value: this.text($r('app.string.chat_message_cancel')), action: (): void => {} },
      secondaryButton: { value: this.text($r('app.string.chat_delete')), action: (): void => { this.deleteMessage(message); } } });
  }

  private reportMessage(message: DmMessage): void {
    this.openWebChat();
  }

  private reactionChosen(message: DmMessage, emoji: string): boolean {
    return (message.reactions ?? []).some((entry): boolean => entry.active && entry.emoji === emoji && entry.senderId === xPrivateClient.viewerId());
  }

  private reactionEmojis(message: DmMessage): string[] {
    const result: string[] = [];
    (message.reactions ?? []).forEach((entry): void => { if (entry.active && result.indexOf(entry.emoji) < 0) { result.push(entry.emoji); } });
    return result;
  }

  private reactionCount(message: DmMessage, emoji: string): number {
    return (message.reactions ?? []).filter((entry): boolean => entry.active && entry.emoji === emoji).length;
  }

  private async react(message: DmMessage, emoji: string): Promise<void> {
    if (this.reacting) { return; }
    this.reacting = true;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const account: string = xPrivateStore.load(context).cacheIdentity();
    const conversation: string = this.conversationId;
    const historyGeneration: number = xChatService.webHistoryGeneration();
    const current: () => boolean = (): boolean => this.active && !this.disposed &&
      this.conversationId === conversation && account === xPrivateStore.load(context).cacheIdentity() &&
      historyGeneration === xChatService.webHistoryGeneration() &&
      (AppStorage.get<boolean>('harmonyx.app_foreground') ?? true);
    const remove: boolean = this.reactionChosen(message, emoji);
    try {
      if (message.webMessageId !== undefined && (message.sequenceId ?? '').length === 0) {
        const viewer: string = xPrivateClient.viewerId();
        const result: string = await reactInXChatWeb(context, this.getUIContext(), viewer, conversation, message.webMessageId,
          emoji, remove, current);
        if (!current()) { return; }
        if (result === 'pin_required') {
          this.pendingWebReaction = message;
          this.pendingWebEmoji = emoji;
          this.webPinWaiting = true;
          this.needsUnlock = true;
          this.promptedForPin = true;
          this.pinSheet = true;
          return;
        }
        if (result !== 'reacted') { throw new Error('web_reaction_' + result); }
        const row: DmMessage | undefined = this.messages.find((entry: DmMessage): boolean => entry.id === message.id);
        if (row !== undefined) {
          row.reactions = (row.reactions ?? []).filter(entry => entry.emoji !== emoji || entry.senderId !== viewer);
          if (!remove) { row.reactions.push({ emoji: emoji, senderId: viewer, sequenceId: '', active: true }); }
          this.messages = this.messages.slice();
          this.saveWebHistory(account);
        }
      } else {
        const page: XChatPage = await xChatService.react(conversation, message.sequenceId ?? '', emoji, remove);
        if (!current()) { return; }
        this.mergeMessages(page);
      }
      chatEmojiStore.used(context, emoji);
      hilog.info(0xFF00, 'HarmonyX-Chat', 'reaction confirmed');
    } catch (error) {
      hilog.warn(0xFF00, 'HarmonyX-Chat', 'reaction failed: %{public}s', (error as Error).message);
      if (this.active) { promptAction.showToast({ message: this.text($r('app.string.chat_action_failed')) }); }
    } finally { this.reacting = false; }
  }

  private jumpToMessage(sequenceId: string): void {
    const index: number = this.visibleTimeline.findIndex((message: DmMessage): boolean => message.sequenceId === sequenceId || message.id === sequenceId);
    if (index >= 0) { this.scroller.scrollToIndex(index + 1 + (this.hasMore ? 1 : 0) + (this.status.length > 0 ? 1 : 0) +
      (this.messages.some((m: DmMessage): boolean => m.id === this.pinnedMessageId) ? 1 : 0), true, ScrollAlign.CENTER); }
    else { promptAction.showToast({ message: this.text($r('app.string.chat_message_load_original')) }); }
  }

  private async forward(person: ChatPerson, note: string): Promise<void> {
    if (this.forwardTarget === null || this.forwarding) { return; }
    const source: DmMessage = this.forwardTarget;
    const generation: number = this.requestGeneration;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.forwarding = true;
    try {
      const ids: string[] = [xPrivateClient.viewerId(), person.id];
      ids.sort((a: string, b: string): number => XChatService.compareIds(a, b));
      const conversation: string = ids.join('-');
      await xChatService.prepare(context, ids);
      const files: ChatPickedFile[] = [];
      for (let i: number = 0; i < (source.attachments?.length ?? 0); i++) {
        const attachment: DmAttachment = (source.attachments ?? [])[i];
        if (attachment.type === 'Media') {
          const path: string = await xChatMedia.receive(context, this.conversationId, attachment.mediaHash,
            source.keyVersion ?? '', attachment.mediaType, attachment.rawEvent);
          files.push({ uri: path, filename: attachment.filename, type: attachment.mediaType, duration: attachment.durationMs });
        }
      }
      if (!this.active || generation !== this.requestGeneration) { return; }
      const text: string = [source.text, ...(source.attachments ?? []).filter((a: DmAttachment): boolean => a.type !== 'Media').map((a: DmAttachment): string => a.url), note.trim()].filter((t: string): boolean => t.length > 0).join('\n');
      const page: XChatPage = files.length > 0 ? await xChatMedia.sendMany(context, conversation, files, text) : await xChatService.send(conversation, text);
      if (!this.active || generation !== this.requestGeneration) { return; }
      if (conversation.replace(':', '-') === this.conversationId.replace(':', '-')) {
        this.messages = xChatService.mergeConversation(this.messages, page, this.conversationId);
      }
      this.forwardSheet = false;
      this.forwardTarget = null;
      promptAction.showToast({ message: this.text($r('app.string.chat_sent')) });
    } catch (error) { if (this.active) { promptAction.showToast({ message: this.text($r('app.string.dm_send_failed')) }); } }
    finally { this.forwarding = false; }
  }

  private hasVisualMedia(message: DmMessage): boolean {
    if (this.mediaSend(message.id) !== undefined) { return true; }
    return (message.attachments ?? []).some((attachment: DmAttachment): boolean =>
      attachment.type === 'Media' && attachment.mediaType >= 1 && attachment.mediaType <= 3);
  }

  private hasPostLinks(message: DmMessage): boolean { return chatPostLinks(message).length > 0; }

  // A shared post that is the entire message renders as the card alone, which is
  // how X shows it; a link inside a sentence stays part of that sentence.
  private showsMessageText(message: DmMessage): boolean {
    if (message.text.length === 0) { return false; }
    if (!this.hasPostLinks(message)) { return true; }
    return chatTextWithoutLinks(message.text).length > 0;
  }

  private openMessageLink(link: string, post: Tweet | null = null): void {
    if (!this.active || (this.conversationTransport !== 'plaintext' && !xChatService.isUnlocked())) { return; }
    const target: ChatPostLink | null = chatPostLink(link);
    const resolved: Tweet | null = post ?? (target === null ? null : chatPostPreview.known(target.postId));
    if (resolved !== null) {
      const param: PostDetailRouteParam = { tweet: resolved, refreshContent: true };
      this.pageStack.pushPath({ name: 'PostDetail', param: param });
    } else { openPostCardUrl(getContext(this) as common.UIAbilityContext, link); }
  }

  private openPickedGif(uri: string): void {
    if (!this.active || !xChatService.isUnlocked()) { return; }
    const param: PhotoViewerRouteParam = { urls: [uri], index: 0, alt: '', transitionPrefix: '',
      screenBlocked: xChatService.conversationInfo(this.conversationId).screenBlocked };
    this.pageStack.pushPath({ name: 'PhotoViewer', param: param });
  }

  private openChatVideo(media: MediaAttachment): void {
    if (!this.active || !xChatService.isUnlocked()) { return; }
    const param: ChatVideoViewerRouteParam = { media: media,
      source: pendingMediaViewerSource.take(media.id),
      screenBlocked: xChatService.conversationInfo(this.conversationId).screenBlocked };
    this.pageStack.pushPath({ name: 'ChatVideoViewer', param: param }, param.source === undefined);
  }

  @Builder
  private PendingMedia(send: ChatMediaSend | undefined): void {
    if (send !== undefined) {
      ChatPendingMediaAlbum({ files: send.files, sendId: send.id, conversationId: this.conversationId })
    }
  }

  @Builder
  private MediaRetry(messageId: string): void {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize($r('app.float.chat_media_retry_symbol_size'))
        .fontColor([Color.White])
    }.width($r('app.float.chat_media_retry_size')).height($r('app.float.chat_media_retry_size')).padding(0)
      .backgroundColor(SystemMaterialUtil.isApi26OrAbove() ? Color.Transparent : $r('app.color.danger'))
      .attributeModifier(materialModifier(chatTintedControlMaterial($r('app.color.chat_media_remove_tint'))))
      .accessibilityText($r('app.string.chat_retry'))
      .onClick((): void => { chatMediaOutbox.retry(messageId); })
  }

  private usesBubbleSkin(message: DmMessage): boolean {
    return message.outgoing && !this.emoji(message) && this.chatDecoration.bubbleUri.length > 0;
  }

  @Builder
  private BubbleContent(message: DmMessage, onMediaLongPress: () => void): void {
    Column({ space: 8 }) {
      if (this.showsMessageText(message)) {
        ChatLinkText({ text: message.text,
          fontSize: this.emoji(message) ? $r('app.float.chat_emoji_message_size') : $r('sys.float.Body_L'),
          fontColor: this.usesBubbleSkin(message) ? this.chatDecoration.bubbleTextColor :
            message.outgoing && !this.emoji(message) ? $r('app.color.text_on_accent') : $r('app.color.text_primary'),
          linkColor: this.usesBubbleSkin(message) ? this.chatDecoration.bubbleTextColor :
            message.outgoing ? $r('app.color.text_on_accent') : this.accentColor,
          onLink: (link: string): void => { this.openMessageLink(link); } })
          .padding(this.emoji(message) ? 0 : this.usesBubbleSkin(message) ?
            { left: 26, right: 34, top: 14, bottom: 14 } : { left: 15, right: 15, top: 10, bottom: 10 })
          .backgroundImage(this.usesBubbleSkin(message) ? this.chatDecoration.bubbleUri : '')
          .backgroundImageSize({ width: '100%', height: '100%' })
          .backgroundImageResizable({ slice: {
            left: this.chatDecoration.sliceLeft.toString() + 'px',
            right: this.chatDecoration.sliceRight.toString() + 'px',
            top: this.chatDecoration.sliceTop.toString() + 'px',
            bottom: this.chatDecoration.sliceBottom.toString() + 'px'
          } })
          .backgroundColor(this.emoji(message) || this.usesBubbleSkin(message) ? Color.Transparent :
            message.outgoing ? this.accentColor : secondaryButtonSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
          .borderRadius($r('app.float.chat_bubble_radius'))
      }
      if (this.mediaSend(message.id) !== undefined) {
        this.PendingMedia(this.mediaSend(message.id));
      } else if (this.hasVisualMedia(message)) {
        ChatMediaAlbum({ attachments: message.attachments ?? [], conversationId: this.conversationId,
          keyVersion: message.keyVersion ?? '', outgoing: message.outgoing, visible: this.voiceVisible,
          onLongPress: onMediaLongPress,
          onVideoOpen: (media: MediaAttachment): void => { this.openChatVideo(media); } })
      }
      ForEach(ChatMovingPhotoProtocol.group(message.attachments ?? []), (item: ChatMediaItem) => {
        if (item.attachment.type === 'Media' && item.attachment.mediaType > 3) {
          ChatMediaCard({ attachment: item.attachment, conversationId: this.conversationId, keyVersion: message.keyVersion ?? '', outgoing: message.outgoing, visible: this.voiceVisible })
            .padding({ left: 15, right: 15, top: 10, bottom: 10 })
            .backgroundColor(message.outgoing ? this.accentColor : secondaryButtonSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
            .borderRadius($r('app.float.chat_bubble_radius'))
        } else if (item.attachment.type !== 'Media' && item.attachment.url.length > 0 && chatPostLink(item.attachment.url) === null) {
          ChatLinkText({ text: item.attachment.url, fontSize: $r('sys.float.Body_M'),
            fontColor: message.outgoing ? $r('app.color.text_on_accent') : this.accentColor,
            linkColor: message.outgoing ? $r('app.color.text_on_accent') : this.accentColor,
            onLink: (link: string): void => { this.openMessageLink(link); } })
            .padding({ left: 15, right: 15, top: 10, bottom: 10 })
            .backgroundColor(message.outgoing ? this.accentColor : secondaryButtonSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
            .borderRadius($r('app.float.chat_bubble_radius'))
        }
      })
      ForEach(chatPostLinks(message), (link: ChatPostLink) => {
        ChatPostCard({ postId: link.postId, url: link.url, visible: this.voiceVisible,
          onOpen: (post: Tweet | null, url: string): void => { this.openMessageLink(url, post); },
          onLongPress: onMediaLongPress })
      }, (link: ChatPostLink): string => link.postId)
    }.alignItems(message.outgoing ? HorizontalAlign.End : HorizontalAlign.Start)
      .width(this.hasVisualMedia(message) || this.hasPostLinks(message) ? '100%' : undefined).constraintSize({ maxWidth: '100%' })
  }

  @Builder
  private MessageBubble(message: DmMessage, index: number): void {
    Column({ space: 4 }) {
      if (this.showTime(index)) {
        Text(chatMessageTime(message.timestampMs, message.time, this.appLocale)).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
          .width('100%').textAlign(TextAlign.Center).margin({ top: 16, bottom: 14 })
      }
      Row({ space: 8 }) {
        if (this.group && !message.outgoing && !message.directionUnknown) {
          this.DecoratedAvatar(message.senderAvatarUrl, 28, 14, message.senderName.substring(0, 1),
            message.senderVerifiedType ?? '', message.senderAvatarShape ?? '')
        }
        if (this.mediaFailed(message.id)) { this.MediaRetry(message.id); }
        Column({ space: 6 }) {
          if (this.group && !message.outgoing && !message.directionUnknown) {
            Text(message.senderName).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary'))
          }
          if (message.reply !== undefined) {
            Row({ space: 4 }) {
              SymbolGlyph($r('sys.symbol.arrowshape_turn_up_left')).fontSize(13).fontColor([$r('app.color.text_secondary')])
              Text(this.text($r('app.string.chat_message_replied_to')) + ' ' + (message.reply.senderName.length > 0 ? message.reply.senderName :
                message.reply.senderId === xPrivateClient.viewerId() ? this.text($r('app.string.chat_message_you')) : this.title)).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary')).maxLines(1)
            }
            ChatEmojiText({ text: message.reply.text.length > 0 ? message.reply.text : this.text($r('app.string.dm_attachment_message')),
              fontSize: $r('sys.float.Body_M'), fontColor: $r('app.color.text_secondary'), maxLines: 2 })
              .padding({ left: 14, right: 14, top: 10, bottom: 10 }).border({ width: 1, color: $r('app.color.divider') })
              .borderRadius(22).onClick((): void => { this.jumpToMessage(message.reply?.sequenceId ?? ''); })
          }
          if (this.mediaSend(message.id) !== undefined) {
            this.BubbleContent(message, (): void => {});
          } else {
          ChatMessageActions({ message: message, pinned: this.pinnedMessageId === message.id,
            content: (onLongPress: () => void): void => { this.BubbleContent(message, onLongPress); },
            onReply: (): void => { this.chooseReply(message); },
            onForward: (): void => { this.forwardTarget = message; this.forwardSheet = true; },
            onCopy: (): void => { this.copyMessage(message); }, onPin: (): void => { this.pinMessage(message); },
            onSave: (): void => { this.saveMessageImages(message); },
            onInfo: (): void => { this.messageInfo(message); }, onReport: (): void => { this.reportMessage(message); },
            onDelete: (): void => { this.confirmDelete(message); }, onReaction: (emoji: string): void => { this.react(message, emoji); },
            onMoreReactions: (): void => { this.reactionTarget = message; this.emojiSheet = true; } })
          }
          if (this.reactionEmojis(message).length > 0) {
            Flex({ wrap: FlexWrap.Wrap, justifyContent: message.outgoing ? FlexAlign.End : FlexAlign.Start }) {
              ForEach(this.reactionEmojis(message), (emoji: string) => {
                Button({ type: ButtonType.Normal }) {
                  Row({ space: 3 }) {
                    ChatEmojiText({ text: emoji, fontSize: $r('app.float.chat_emoji_reaction_size') })
                    if (this.reactionCount(message, emoji) > 1) {
                      Text(this.reactionCount(message, emoji).toString()).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
                        .fontColor(this.reactionChosen(message, emoji) ? Color.White : $r('app.color.text_secondary'))
                    }
                  }
                }.height(32).padding({ left: 10, right: 10 }).borderRadius(18)
                  .margin({ end: LengthMetrics.vp(4), bottom: LengthMetrics.vp(3) })
                  .backgroundColor(this.reactionChosen(message, emoji) ? this.accentColor : secondaryButtonSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
                  .enabled(!this.reacting).onClick((): void => { this.react(message, emoji); })
              }, (emoji: string): string => emoji)
            }
          }
        }.alignItems(message.outgoing ? HorizontalAlign.End : HorizontalAlign.Start)
          .width(this.hasVisualMedia(message) || this.hasPostLinks(message) ? '82%' : undefined).constraintSize({ maxWidth: '82%' })
          .layoutWeight(this.mediaFailed(message.id) ? 1 : 0)
      }.width('100%').justifyContent(message.directionUnknown ? FlexAlign.Center : message.outgoing ? FlexAlign.End : FlexAlign.Start)
      if (this.mediaSend(message.id) !== undefined) {
        Row({ space: 8 }) {
          Text(this.mediaSend(message.id)?.state === 'failed' ? $r('app.string.dm_send_failed') : $r('app.string.chat_media_sending')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary'))
          if (this.mediaSend(message.id)?.state === 'failed') {
            Button($r('app.string.chat_delete')).fontSize($r('sys.float.Body_S')).backgroundColor(Color.Transparent)
              .fontColor($r('app.color.text_secondary')).onClick((): void => { chatMediaOutbox.discard(message.id); })
          }
        }.width('100%').justifyContent(FlexAlign.End)
      } else if (message.outgoing && this.groupEnd(index)) {
        Text(message.read === true ? $r('app.string.chat_read') : $r('app.string.chat_sent')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary'))
          .width('100%').textAlign(TextAlign.End).padding({ end: LengthMetrics.vp(4) })
      }
    }.width('100%').padding({ left: 16, right: 16, top: 3, bottom: 3 })
  }

  @Builder
  private Content(): void {
    if (this.loading && this.visibleTimeline.length === 0 && (this.group || this.contact.id.length === 0)) {
      Column({ space: 12 }) {
        LoadingProgress().color(this.accentColor).width(24).height(24)
        Text($r('app.string.dm_loading')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    } else if (this.visibleTimeline.length === 0 && !this.group && this.contact.id.length > 0) {
      Scroll() {
        Column() {
          this.ContactIntro();
          if (this.status.length > 0) {
            Text(this.status).fontFamily(this.appFontFamily).fontColor($r('app.color.text_secondary')).padding(16)
            Button($r('app.string.common_retry')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
              .onClick((): void => { this.load(true); })
          }
        }.width('100%')
      }.width('100%').height('100%').padding({ top: this.statusBarHeight + 64,
        bottom: this.composerHeight + 16 }).scrollBar(BarState.Off)
    } else if (this.visibleTimeline.length === 0) {
      Column({ space: 16 }) {
        SymbolGlyph($r('sys.symbol.message')).fontSize(36).fontColor([$r('app.color.text_secondary')])
        Text(this.status.length > 0 ? this.status : this.text(this.needsUnlock ?
          $r('app.string.dm_locked_history') : $r('app.string.dm_no_messages'))).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_secondary')).textAlign(TextAlign.Center)
        if (this.status.length > 0) {
          Button($r('app.string.common_retry')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
            .onClick((): void => { this.load(true); })
        }
        if (this.historyUnavailable) { this.WebChatButton() }
      }.width('100%').height('100%').padding(24).justifyContent(FlexAlign.Center)
    } else {
      List({ scroller: this.scroller }) {
        ListItem() { Column().height(this.statusBarHeight + 64 + (this.searchVisible ? 52 : 0)).width('100%') }
        if (!this.group && !this.hasMore) { ListItem() { this.ContactIntro(); } }
        if (this.messages.some((m: DmMessage): boolean => m.id === this.pinnedMessageId)) {
          ListItem() {
            Row({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.pin')).fontSize(18).fontColor([this.accentColor])
              ChatEmojiText({ text: this.messageSummary(this.messages.find((m: DmMessage): boolean => m.id === this.pinnedMessageId) as DmMessage),
                fontSize: $r('sys.float.Body_M'), maxLines: 1 }).layoutWeight(1)
              Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.xmark')).fontSize(14) }
                .height(32).width(32).backgroundColor(Color.Transparent).accessibilityText($r('app.string.chat_message_unpin'))
                .onClick((): void => { this.pinnedMessageId = ''; xChatActions.saveLocal(getContext(this) as common.UIAbilityContext, 'pinned_message:' + this.conversationId, ''); })
            }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })
              .onClick((): void => { this.jumpToMessage(this.pinnedMessageId); })
          }
        }
        if (this.hasMore) {
          ListItem() {
            Button($r('app.string.dm_load_earlier')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
              .enabled(!this.loadingHistory).onClick((): void => { this.load(false, true); })
          }
        }
        if (this.status.length > 0) {
          ListItem() {
            Text(this.status).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary'))
              .width('100%').padding(12).textAlign(TextAlign.Center)
          }
        }
        if (this.historyUnavailable) { ListItem() { this.WebChatButton() } }
        ForEach(this.visibleTimeline, (message: DmMessage, index: number) => {
          ListItem() { this.MessageBubble(message, index) }
            .transition(!this.reduceMotion &&
              this.animatedSendIds.includes(message.id + (this.mediaSend(message.id) === undefined ? ':sent' : ':pending')) ?
              TransitionEffect.asymmetric(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 20 }))
                .animation({ duration: 300, curve: Curve.EaseOut }), TransitionEffect.IDENTITY) : TransitionEffect.IDENTITY)
        }, (message: DmMessage, index: number): string =>
          chatMessageRenderKey(message, this.mediaSend(message.id) !== undefined, this.pinnedMessageId, index))
        if (this.peerTyping && this.searchQuery.length === 0) {
          ListItem() {
            Row() { ChatTypingIndicator({ reduceMotion: this.reduceMotion }) }
              .width('100%').justifyContent(FlexAlign.Start).padding({ left: 16, top: 4, bottom: 4 })
          }
        }
        ListItem() { Column().height(this.composerHeight + 16).width('100%') }
      }.width('100%').height('100%')
        // Anchor the timeline at its bottom so keyboard resizing lifts the
        // messages together with the composer, including short conversations.
        .stackFromEnd(true)
        .scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }
  }

  @Builder
  private AttachmentsMenu(): void {
    Menu() {
      MenuItem({ content: $r('app.string.chat_photos'), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.picture')) }).onClick((): void => { this.pick('photos'); })
      MenuItem({ content: $r('app.string.chat_camera'), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.camera')) }).onClick((): void => { this.pick('camera'); })
      MenuItem({ content: $r('app.string.chat_documents'), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.doc')) }).onClick((): void => { this.pick('files'); })
      MenuItem({ content: 'GIF', symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.gif')) }).onClick((): void => { this.pick('gif'); })
    }
  }

  @Builder
  private PinSheet(): void {
    ChatPinPad({ busy: this.unlocking, error: this.unlockError,
      onSubmit: (pin: string): void => { this.pin = pin; this.unlock(); },
      onClose: (): void => { this.pin = ''; this.pinSheet = false; } })
  }

  @Builder
  private SearchField(): void {
    Search({ value: this.searchQuery, placeholder: $r('app.string.chat_search') })
      .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
      .height(44).margin({ left: 16, right: 16, top: 4 }).backgroundColor(Color.Transparent)
      .fontColor($r('app.color.text_primary')).borderRadius(24).clip(!SystemMaterialUtil.isApi26OrAbove())
      .attributeModifier(materialModifier(chatInputMaterial(this.capsuleMaterialLevel)))
      .onChange((value: string): void => { this.searchQuery = value; })
  }

  @Builder
  private ReplyPreview(): void {
    if (this.replyTarget !== null) {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.arrowshape_turn_up_left')).fontSize(24).fontColor([$r('app.color.text_secondary')])
        Column({ space: 3 }) {
          Text(this.text($r('app.string.chat_message_reply_to')) + ' ' + this.senderLabel(this.replyTarget)).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary')).maxLines(1)
          ChatEmojiText({ text: this.messageSummary(this.replyTarget), fontSize: $r('sys.float.Body_M'),
            fontColor: $r('app.color.text_secondary'), maxLines: 1 })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.xmark')).fontSize(16).fontColor([$r('app.color.text_secondary')]) }
          .width(30).height(30).padding(0).backgroundColor(Color.Transparent).accessibilityText($r('app.string.chat_message_cancel_reply'))
          .onClick((): void => { this.cancelReplyFocus(); this.replyTarget = null; })
      }.width('100%').height(this.replyPreviewHeight()).padding({ start: LengthMetrics.vp(14), end: LengthMetrics.vp(10) })
    }
  }

  @Builder
  private ComposerControls(): void {
    Row({ space: 8 }) {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.plus')).fontSize(25).fontColor([$r('app.color.text_primary')])
      }.width(44).height(44).backgroundColor(SystemMaterialUtil.isApi26OrAbove() ? Color.Transparent :
        secondaryButtonSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
        .attributeModifier(materialModifier(chatInputMaterial(this.capsuleMaterialLevel)))
        .enabled(!this.plainConversation() && !this.sending && !this.picking && !this.recording && !this.recordingPending)
        .accessibilityText($r('app.string.dm_attachment_message')).id('chat-attachment-button')
        .onClick((): void => { this.toggleAttachmentPanel(); })
        .bindPopup(this.recentPhotoShown, this.recentPhotoPopupOptions())
      Column() {
        this.ReplyPreview()
        Row() {
        TextInput({ text: this.draft, placeholder: this.plainConversation() ? $r('app.string.chat_contact_plain_message') : $r('app.string.chat_message') }).fontFamily(this.appFontFamily)
          .keyboardAppearance(KeyboardAppearance.IMMERSIVE).enterKeyType(EnterKeyType.Send)
          .onKeyPreIme((event: KeyEvent): boolean => submitInputKey(event, (): void => { if (this.active) { void this.send(); } }))
          .id('chat-message-input')
          .enableKeyboardOnFocus(true).onFocus((): void => { this.closeAttachmentPanel(); this.showReplyKeyboard(); })
          .layoutWeight(1).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary'))
          .backgroundColor(Color.Transparent)
          .padding({ start: LengthMetrics.vp(14), end: LengthMetrics.vp(4) }).maxLength(10000)
          .enabled(!this.sending && !this.recording).onChange((value: string): void => { this.draft = value; })
          .onSubmit((): void => { this.send(); })
        Button({ type: ButtonType.Circle }) {
          if (this.sending || this.recordingPending) { LoadingProgress().width(22).height(22).color(this.accentColor) }
          else { SymbolGlyph(this.draft.trim().length > 0 || this.attachments.length > 0 ? $r('sys.symbol.paperplane') :
            this.recording ? $r('sys.symbol.checkmark') : $r('sys.symbol.mic')).fontSize(24).fontColor([this.accentColor]) }
        }.width(42).height(42).backgroundColor(Color.Transparent).enabled(!this.sending && !this.picking && !this.recordingPending &&
          (!this.plainConversation() || this.draft.trim().length > 0))
          .accessibilityText(this.draft.trim().length > 0 || this.attachments.length > 0 ? $r('app.string.dm_send') : $r('app.string.chat_voice_messages'))
          .onClick((): void => { if (this.draft.trim().length > 0 || this.attachments.length > 0) { this.send(); } else { this.record(); } })
        }.width('100%').height(44)
      }.layoutWeight(1).height(this.composerSurfaceHeight()).borderRadius(this.replyTarget === null ? 24 : 32)
        .clip(!SystemMaterialUtil.isApi26OrAbove())
        .backgroundColor(SystemMaterialUtil.isApi26OrAbove() ? Color.Transparent :
          secondaryButtonSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
        .border({ width: SystemMaterialUtil.isApi26OrAbove() ? 0 : 1, color: $r('app.color.divider') })
        .attributeModifier(materialModifier(chatInputMaterial(this.capsuleMaterialLevel)))
    }.width('100%').height(this.composerSurfaceHeight()).alignItems(VerticalAlign.Bottom)
  }

  private recentPhotoPopupOptions(): CustomPopupOptions {
    const options: CustomPopupOptions = {
      builder: (): void => { this.RecentPhotoSuggestion(); }, placement: Placement.Top, enableArrow: true, autoCancel: true,
      // A modal mask consumes the first tap on attachment actions below.
      mask: false,
      popupColor: SystemMaterialUtil.isApi26OrAbove() ? Color.Transparent :
        secondaryButtonSurfaceColor(this.themeDisplayMode, this.themeDarkSurface),
      backgroundBlurStyle: BlurStyle.NONE,
      radius: 16, shadow: ShadowStyle.OUTER_DEFAULT_MD,
      transition: TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 8 }))
        .combine(TransitionEffect.scale({ x: 0.94, y: 0.94 })).animation({ duration: 200, curve: Curve.EaseOut }),
      onStateChange: (state: PopupStateChangeParam): void => { if (!state.isVisible) { this.hideRecentPhoto(); } }
    };
    if (deviceInfo.apiAvailable('26.0.0')) {
      options.systemMaterial = chatInputMaterial(this.capsuleMaterialLevel);
    }
    return options;
  }

  private composerSurfaceHeight(): number {
    const replyHeight: number = this.replyTarget === null ? 0 : this.replyPreviewHeight();
    if (this.recording) { return 120 + replyHeight + (replyHeight > 0 ? 8 : 0); }
    const firstFile: ChatPickedFile | undefined = this.attachments[0];
    if (firstFile === undefined) { return 44 + replyHeight; }
    if (this.compactWindow && this.keyboardVisible) {
      return this.compactDimension($r('app.float.compact_dm_media_keyboard_height')) +
        replyHeight + (replyHeight > 0 ? 4 : 0);
    }
    return (firstFile.type >= 4 ? 144 : (this.compactWindow ?
      this.compactDimension($r('app.float.compact_dm_media_composer_height')) : 184)) +
      replyHeight + (replyHeight > 0 ? 4 : 0);
  }

  private compactDimension(resource: Resource): number {
    return this.getUIContext().px2vp(getContext(this).resourceManager.getNumber(resource.id));
  }

  private replyPreviewHeight(): number {
    return this.compactWindow ? this.compactDimension($r('app.float.compact_dm_reply_height')) : 68;
  }

  private selectedMediaSize(): number {
    return this.compactWindow ? this.compactDimension($r('app.float.compact_dm_media_size')) : 96;
  }

  private sendTint(): string { return /^#[0-9A-Fa-f]{6}$/.test(this.accentColor) ? '#66' + this.accentColor.substring(1) : '#66007DFF'; }

  @Builder
  private RemoveAttachmentButton(file: ChatPickedFile): void {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.xmark')).fontSize(12).fontColor([Color.White])
    }.width(28).height(28).padding(0)
      .backgroundColor(SystemMaterialUtil.isApi26OrAbove() ? Color.Transparent : $r('app.color.danger'))
      .attributeModifier(materialModifier(chatTintedControlMaterial($r('app.color.chat_media_remove_tint'))))
      .accessibilityText($r('app.string.chat_remove_attachment')).enabled(!this.sending && !this.picking)
      .onClick((): void => { this.removeAttachment(file.uri); })
  }

  @Builder
  private SelectedMedia(firstFile: ChatPickedFile | undefined): void {
    // Dirty preview nodes can update before the composer removes this branch.
    // Keep their file snapshot valid when the selected attachment list empties.
    if (firstFile !== undefined && firstFile.type === 4) {
      Row({ space: 8 }) {
        ChatVoicePlayer({ path: firstFile.uri, durationMs: firstFile.duration ?? 0,
          samples: firstFile.waveform ?? [], visible: this.voiceVisible && !this.sending }).layoutWeight(1)
        this.RemoveAttachmentButton(firstFile)
      }.width('100%').height(64)
    } else if (firstFile !== undefined && firstFile.type === 5) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.doc')).fontSize(28).fontColor([this.accentColor])
        Text(firstFile.filename).fontFamily(this.appFontFamily).layoutWeight(1).fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_primary')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        this.RemoveAttachmentButton(firstFile)
      }.width('100%').height(64)
    } else if (firstFile !== undefined) {
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.attachments, (file: ChatPickedFile) => {
            Stack({ alignContent: Alignment.TopEnd }) {
              if (file.movingPhoto !== undefined) {
                ChatMovingPhotoCard({ selectedPhoto: file.movingPhoto, sourceUri: file.uri,
                  compact: true, tileWidth: this.compactWindow ? this.selectedMediaSize() : 0,
                  tileHeight: this.compactWindow ? this.selectedMediaSize() : 0,
                  visible: this.voiceVisible && !this.sending })
              } else if (file.type === 3) {
                Video({ src: file.uri }).width(this.selectedMediaSize()).height(this.selectedMediaSize()).controls(false).autoPlay(false).muted(true)
                  .borderRadius(12).clip(true)
              } else {
                Image(file.uri).width(this.selectedMediaSize()).height(this.selectedMediaSize()).objectFit(ImageFit.Cover).borderRadius(12).clip(true)
                  .accessibilityText(file.type === 2 ? 'GIF' : this.text($r('app.string.chat_photos')))
                  .onClick((): void => { if (file.type === 2) { this.openPickedGif(file.uri); } })
              }
              this.RemoveAttachmentButton(file)
            }.width(this.selectedMediaSize()).height(this.selectedMediaSize())
          }, (file: ChatPickedFile): string => file.uri)
          if (this.remainingMediaSlots() > 0) {
            Button({ type: ButtonType.Normal }) {
              SymbolGlyph($r('sys.symbol.plus')).fontSize(28).fontColor([$r('app.color.text_secondary')])
            }.width(this.selectedMediaSize()).height(this.selectedMediaSize()).padding(0).borderRadius(12).backgroundColor(Color.Transparent)
              .border({ width: 1.5, color: $r('app.color.divider'), style: BorderStyle.Dashed })
              .enabled(!this.sending && !this.picking).accessibilityText($r('app.string.chat_add_media'))
              .bindMenu(this.AttachmentsMenu())
          }
        }.height(this.selectedMediaSize() + 8)
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%').height(this.selectedMediaSize() + 8)
    }
  }

  @Builder
  private SelectedMediaComposer(): void {
    Column({ space: 4 }) {
      this.ReplyPreview()
      if (!this.compactWindow || !this.keyboardVisible) { this.SelectedMedia(this.attachments[0]) }
      Row({ space: 8 }) {
        TextArea({ text: this.draft, placeholder: $r('app.string.chat_message') }).fontFamily(this.appFontFamily)
          .keyboardAppearance(KeyboardAppearance.IMMERSIVE).layoutWeight(1)
          .height(this.compactWindow && this.keyboardVisible ? 44 : 56)
          .onKeyPreIme((event: KeyEvent): boolean => submitInputKey(event, (): void => { if (this.active) { void this.send(); } }))
          .id('chat-media-input')
          .enableKeyboardOnFocus(true).onFocus((): void => { this.showReplyKeyboard(); })
          .fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary')).maxLength(10000)
          .backgroundColor(SystemMaterialUtil.isApi26OrAbove() ? Color.Transparent : $r('app.color.bg_field'))
          .borderRadius(24).clip(!SystemMaterialUtil.isApi26OrAbove()).padding({ start: LengthMetrics.vp(14), end: LengthMetrics.vp(12),
            top: LengthMetrics.vp(14), bottom: LengthMetrics.vp(10) })
          .attributeModifier(materialModifier(chatInputMaterial(this.inputMaterialLevel)))
          .enabled(!this.sending).onChange((value: string): void => { this.draft = value; })
        Button({ type: ButtonType.Circle }) {
          if (this.sending) { LoadingProgress().width(22).height(22).color(Color.White) }
          else { SymbolGlyph($r('sys.symbol.arrow_up')).fontSize(24).fontColor([Color.White]) }
        }.width(44).height(44).padding(0)
          .backgroundColor(SystemMaterialUtil.isApi26OrAbove() ? Color.Transparent : this.accentColor)
          .attributeModifier(materialModifier(chatTintedControlMaterial(this.sendTint())))
          .enabled(!this.sending && !this.picking).accessibilityText($r('app.string.dm_send'))
          .onClick((): void => { this.send(); })
      }.width('100%').height(this.compactWindow && this.keyboardVisible ? 44 : 56)
    }.width('100%').height(this.composerSurfaceHeight()).padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor(SystemMaterialUtil.isApi26OrAbove() ? Color.Transparent : $r('app.color.bg_field'))
      .border({ width: SystemMaterialUtil.isApi26OrAbove() ? 0 : 1, color: $r('app.color.divider') })
      .borderRadius(32).clip(!SystemMaterialUtil.isApi26OrAbove()).attributeModifier(materialModifier(chatInputMaterial(this.capsuleMaterialLevel)))
  }

  @Builder
  private RecordingComposer(): void {
    Column({ space: 8 }) {
      this.ReplyPreview()
      ChatWaveform({ samples: this.recordingSamples, foreground: this.accentColor, dim: this.accentColor })
      Row({ space: 8 }) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.xmark')).fontSize(18).fontColor([$r('app.color.danger')])
        }.width(36).height(36).backgroundColor(Color.Transparent).accessibilityText($r('app.string.chat_voice_cancel'))
          .onClick((): void => { this.cancelRecording(); })
        Text($r('app.string.chat_recording')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(this.accentColor).layoutWeight(1)
        Text(ChatVoice.time(this.recordingElapsed)).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.checkmark')).fontSize(20).fontColor([this.accentColor])
        }.width(36).height(36).backgroundColor(Color.Transparent).enabled(!this.recordingPending)
          .accessibilityText($r('app.string.chat_voice_finish')).onClick((): void => { this.record(); })
      }.width('100%').height(40)
    }.width('100%').height(this.composerSurfaceHeight()).padding(16).borderRadius(32).clip(!SystemMaterialUtil.isApi26OrAbove())
      .backgroundColor(SystemMaterialUtil.isApi26OrAbove() ? Color.Transparent : $r('app.color.bg_field'))
      .attributeModifier(materialModifier(chatInputMaterial(this.capsuleMaterialLevel)))
  }

  @Builder
  private ComposerTitleBarContent(): void {
    Column() {
      if (this.recording) { this.RecordingComposer(); }
      else if (this.attachments.length > 0) { this.SelectedMediaComposer(); }
      else { this.ComposerControls(); }
    }.width('100%').height(this.composerSurfaceHeight())
  }

  @Builder
  private ComposerTitleBar(): void {
    MaterialSurfaceHost({ surfaceHeight: this.composerSurfaceHeight(),
      surfaceContent: (): void => { this.ComposerTitleBarContent(); } })
    .backgroundColor(Color.Transparent)
    .width('100%')
    .height(this.composerSurfaceHeight())
    .clip(false)
  }

  @Builder
  private EmojiSheet(): void {
    ChatEmojiPanel({ onSelect: (emoji: string): void => {
      const target: DmMessage | null = this.reactionTarget;
      this.emojiSheet = false;
      if (target !== null) { this.react(target, emoji); }
    } })
  }

  @Builder
  private ForwardSheet(): void {
    ChatForwardPanel({ sending: this.forwarding, preview: this.forwardTarget === null ? '' : this.messageSummary(this.forwardTarget),
      onSend: (person: ChatPerson, note: string): void => { this.forward(person, note); } })
  }

  @Builder
  private ContactNumberSheet(): void {
    Column({ space: 20 }) {
      Row() {
        Text($r('app.string.chat_contact_number_title')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_M')).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).layoutWeight(1)
        Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.xmark')).fontSize(20) }
          .width(36).height(36).backgroundColor(Color.Transparent).enabled(!this.checkingNumber)
          .accessibilityText($r('app.string.chat_message_cancel')).onClick((): void => { this.numberSheet = false; })
      }.width('100%')
      Text((getContext(this) as common.UIAbilityContext).resourceManager.getStringSync(
        $r('app.string.chat_contact_number_hint'), this.username)).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_secondary')).width('100%')
      TextInput({ text: this.contactNumber, placeholder: $r('app.string.chat_contact_number_placeholder') }).fontFamily(this.appFontFamily)
        .id('chat-contact-number-input').type(InputType.Number).maxLength(9).height(56)
        .fontSize($r('sys.float.Title_M')).fontColor($r('app.color.text_primary')).enabled(!this.checkingNumber)
        .onChange((value: string): void => { this.contactNumber = value.replace(/[^\d-]/g, ''); })
        .onSubmit((): void => { this.verifyContactNumber(); })
      if (this.numberError.length > 0) {
        Text(this.numberError).fontFamily(this.appFontFamily).fontColor($r('app.color.danger')).fontSize($r('sys.float.Body_M')).width('100%')
      }
      Button($r('app.string.chat_continue')).width('100%').height(48).backgroundColor(this.accentColor)
        .fontColor($r('app.color.text_on_accent')).enabled(!this.checkingNumber && /^\d{8}$/.test(this.contactNumber.replace(/[\s-]/g, '')))
        .onClick((): void => { this.verifyContactNumber(); })
      if (this.checkingNumber) { LoadingProgress().width(22).height(22).color(this.accentColor) }
    }.width('100%').padding(24)
  }

  @Builder
  private ContactRestriction(): void {
    Column({ space: 12 }) {
      if (this.contact.cannotMessageReason === 'INBOX_CLOSED') {
        Text((getContext(this) as common.UIAbilityContext).resourceManager.getStringSync(
          $r('app.string.chat_contact_closed'), this.username)).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_secondary')).textAlign(TextAlign.Center)
        Row({ space: 8 }) {
          Button($r('app.string.chat_contact_not_now')).layoutWeight(1).height(46)
            .fontColor($r('app.color.text_primary')).backgroundColor(secondaryButtonSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
            .onClick((): void => { ResponsiveLayout.closeContentDestination(this.pageStack); })
          Button($r('app.string.chat_contact_use_number')).layoutWeight(1).height(46)
            .fontColor($r('app.color.text_on_accent')).backgroundColor(this.accentColor)
            .onClick((): void => { this.contactNumber = ''; this.numberError = ''; this.numberSheet = true; })
        }.width('100%')
      } else {
        Text($r('app.string.chat_not_allowed')).fontFamily(this.appFontFamily).fontColor($r('app.color.text_secondary')).textAlign(TextAlign.Center).padding(12)
      }
    }.width('100%').padding({ top: 8, bottom: 4 })
  }

  @Builder
  private RecentPhotoProbe(epoch: number): void {
    // The query is invisible. Only a result for the current button tap may
    // open the recommendation, even if an older query completes late.
    RecentPhotoComponent({
      recentPhotoOptions: this.recentPhotoOptions,
      onRecentPhotoCheckResult: (exists: boolean): void => { this.checkRecentPhoto(exists, epoch); },
      onRecentPhotoClick: (_info: BaseItemInfo): boolean => false
    })
      .width($r('app.float.chat_recent_photo_size')).height($r('app.float.chat_recent_photo_size'))
      .opacity(0).hitTestBehavior(HitTestMode.BLOCK_DESCENDANTS).accessibilityLevel('no-hide-descendants')
      .align(Alignment.BottomStart)
  }

  @Builder
  private RecentPhotoSuggestion(): void {
    Column({ space: 8 }) {
      Text($r('app.string.chat_recent_photo_hint')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
        .fontColor($r('app.color.text_primary')).fontWeight(FontWeight.Medium).width('100%').maxLines(3)
      RecentPhotoComponent({
        recentPhotoOptions: this.recentPhotoOptions,
        onRecentPhotoCheckResult: (exists: boolean): void => { if (!exists) { this.hideRecentPhoto(); } },
        onRecentPhotoClick: (info: BaseItemInfo): boolean => {
          if (!this.active || this.disposed || !this.canShowRecentPhoto() || this.sending || this.picking || (info.uri ?? '').length === 0) { return false; }
          this.insertRecentPhoto(info);
          return true;
        }
      })
        .width($r('app.float.chat_recent_photo_size')).height($r('app.float.chat_recent_photo_size'))
        .borderRadius($r('app.float.chat_recent_photo_radius')).clip(true)
        .enabled(!this.sending && !this.picking)
        .accessibilityText($r('app.string.chat_insert_recent_photo'))
        .id('chat-recent-photo')
    }.width($r('app.float.chat_recent_photo_bubble_width')).padding($r('app.float.chat_recent_photo_inset'))
      .renderGroup(true).id('chat-recent-photo-suggestion')
  }

  @Builder
  private AttachmentPanelButton(symbol: Resource, label: Resource, kind: string): void {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 6 }) {
        SymbolGlyph(symbol).fontSize($r('app.float.chat_attachment_panel_symbol_size')).fontColor([this.accentColor])
        Text(label).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_M')).fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Medium).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }.width('100%')
    }.layoutWeight(1).height($r('app.float.chat_attachment_panel_height')).padding(4).borderRadius(16)
      .backgroundColor(Color.Transparent).enabled(!this.sending && !this.picking && !this.recordingPending)
      // Collect the whole button, without its decorative children or ancestor gestures.
      .hitTestBehavior(HitTestMode.Block)
      .id('chat-attachment-' + kind)
      .accessibilityText(label).onClick((): void => { this.pick(kind); })
  }

  @Builder
  private AttachmentPanelSurface(): void {
    Column().width('100%').height($r('app.float.chat_attachment_panel_surface_height'))
      .borderRadius(24).clip(!SystemMaterialUtil.isApi26OrAbove())
      .backgroundColor(SystemMaterialUtil.isApi26OrAbove() ? Color.Transparent :
        secondaryButtonSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
      .border({ width: SystemMaterialUtil.isApi26OrAbove() ? 0 : 1, color: $r('app.color.divider') })
      .attributeModifier(materialModifier(chatInputMaterial(this.capsuleMaterialLevel)))
  }

  @Builder
  private AttachmentPanel(): void {
    Stack() {
      // Retain the native material host as a passive background. The four
      // buttons are siblings above it, outside Navigation/TitleBar gestures.
      MaterialSurfaceHost({ surfaceHeight: this.getUIContext().px2vp(
        getContext(this).resourceManager.getNumber($r('app.float.chat_attachment_panel_surface_height').id)),
        surfaceContent: (): void => { this.AttachmentPanelSurface(); } })
      .backgroundColor(Color.Transparent)
      .width('100%').height($r('app.float.chat_attachment_panel_surface_height'))
      .clip(false)
      .hitTestBehavior(HitTestMode.BLOCK_DESCENDANTS)
      .accessibilityLevel('no-hide-descendants')
      Row({ space: 4 }) {
        this.AttachmentPanelButton($r('sys.symbol.picture'), $r('app.string.chat_photos'), 'photos')
        this.AttachmentPanelButton($r('sys.symbol.camera'), $r('app.string.chat_camera'), 'camera')
        this.AttachmentPanelButton($r('sys.symbol.doc'), $r('app.string.chat_documents'), 'files')
        this.AttachmentPanelButton($r('sys.symbol.gif'), $r('app.string.chat_gif'), 'gif')
      }.width('100%').height($r('app.float.chat_attachment_panel_surface_height')).padding(4)
    }.width('100%').height($r('app.float.chat_attachment_panel_surface_height'))
      .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 8 }))
        .animation({ duration: 180, curve: Curve.EaseOut }))
  }

  @Builder
  private WebChatButton(): void {
    if (xPrivateClient.isSignedIn()) {
      Button($r('app.string.dm_open_x_chat')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
        .onClick((): void => { this.openWebChat(); })
    }
  }

  @Builder
  private Composer(): void {
    Column({ space: 8 }) {
      if (this.webPinWaiting) {
        Button($r('app.string.dm_unlock_action')).fontColor($r('app.color.text_on_accent'))
          .backgroundColor(this.accentColor).width('100%').height(46)
          .onClick((): void => { this.pinSheet = true; })
      } else if (this.webHistoryActive && !this.plainConversation() && !xChatService.isUnlocked()) {
        Column().height(0)
      } else if (!this.plainConversation() && !xChatService.isUnlocked() && !this.loading) {
        Button(this.backupAvailable ? $r('app.string.dm_unlock_action') :
          this.keysUnavailable ? $r('app.string.common_retry') : $r('app.string.dm_no_backup'))
          .fontColor($r('app.color.text_on_accent')).backgroundColor(this.accentColor).width('100%').height(46)
          .enabled((this.backupAvailable || this.keysUnavailable) && this.pinAttemptsRemaining !== 0)
          .onClick((): void => {
            if (this.backupAvailable) { this.pinSheet = true; }
            else { this.load(true); }
          })
      } else if (!this.group && !this.contact.permissionKnown && !xPrivateClient.hasChatOAuth()) {
        if (this.contactFailed) {
          Button($r('app.string.chat_contact_permission_failed')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
            .onClick((): void => { this.loadContact(); })
        } else { LoadingProgress().width(24).height(24).color(this.accentColor) }
      } else if (!this.canContact()) {
        this.ContactRestriction();
      } else if (!this.plainConversation() && !xChatService.isUnlocked()) {
        LoadingProgress().width(24).height(24).color(this.accentColor)
      } else {
        this.ComposerTitleBar()
        if (this.attachmentPanelShown && this.canShowRecentPhoto()) { this.AttachmentPanel(); }
      }
      if (this.sendUnavailable && !this.historyUnavailable) { this.WebChatButton() }
    }.width('100%').padding({ left: 16, right: 16, top: 8,
      bottom: this.keyboardVisible ? 8 : this.navigationIndicatorHeight + 12 })
      .onAreaChange((_old: Area, area: Area): void => {
        const height: number = Number(area.height);
        if (height > 0 && Math.abs(height - this.composerHeight) > 0.5) { this.composerHeight = height; }
      })
  }

  build(): void {
    HdsNavDestination() {
      Column() {
        Stack({ alignContent: Alignment.TopStart }) {
          if (this.chatBackground.presetId !== 'default') {
            ChatBackgroundLayer({ wallpaper: this.chatBackground, displayMode: this.themeDisplayMode,
              darkSurface: this.themeDarkSurface, viewportHeight: this.chatWindowHeight })
              .align(Alignment.TopStart)
          }
          // The foreground follows the resized viewport; the background keeps
          // its window-sized canvas and top origin when the keyboard opens.
          Stack({ alignContent: Alignment.Bottom }) {
            // Mount the probe only while the attachment panel is open. A
            // permanent Photos UIExtension is a secure extension, and the
            // system rejects every context-menu subwindow while it exists.
            if (this.attachmentPanelShown && this.canShowRecentPhoto()) {
              ForEach([this.recentPhotoQueryEpoch], (epoch: number): void => {
                this.RecentPhotoProbe(epoch)
              }, (epoch: number): string => epoch.toString())
            }
            this.Content()
            this.Composer()
          }.width('100%').height('100%').clip(true)
        }.width('100%').layoutWeight(1).clip(true)
        .bindSheet($$this.emojiSheet, this.EmojiSheet(), sheetMaterialOptions({ height: '70%', title: { title: $r('app.string.chat_emoji_more') },
          backgroundColor: pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface),
          onDisappear: (): void => { this.reactionTarget = null; } }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.compactWindow))
        Column().height(0).width(1)
        .bindSheet($$this.forwardSheet, this.ForwardSheet(), sheetMaterialOptions({ height: '80%', title: { title: $r('app.string.chat_message_forward') },
          shouldDismiss: (dismiss: SheetDismiss): void => { if (!this.forwarding) { dismiss.dismiss(); } },
          onDisappear: (): void => { this.forwardTarget = null; } }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.compactWindow))
        Column().height(0).width(1)
          .bindSheet($$this.numberSheet, this.ContactNumberSheet(), sheetMaterialOptions({ height: SheetSize.FIT_CONTENT, showClose: false,
            dragBar: false, backgroundColor: pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface),
            shouldDismiss: (dismiss: SheetDismiss): void => { if (!this.checkingNumber) { dismiss.dismiss(); } },
            onDisappear: (): void => { this.contactNumber = ''; this.numberError = ''; } }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.compactWindow))
      }.width('100%').height('100%')
        .bindSheet($$this.pinSheet, this.PinSheet(), sheetMaterialOptions({ height: SheetSize.FIT_CONTENT, showClose: false, dragBar: false,
          onDisappear: (): void => { this.pinClosed(); } }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.compactWindow))
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode)).titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
      .bindToScrollable([this.scroller])
      .titleBar({
        avoidLayoutSafeArea: true,
        content: {
          stackBuilder: (): void => this.ContactTitle(),
          bottomBuilder: this.searchVisible ? { builder: (): void => this.SearchField(), height: 52,
            showType: BottomBuilderShowType.DIRECTLY_SHOW } : undefined,
          menu: { maxCount: 1, value: [
            { content: { icon: $r('app.media.chat_more'), label: $r('app.string.chat_more'), action: (): void => this.openInfo() } }
          ] }
        },
        style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.themeDisplayMode,
          this.themeDarkSurface, this.titleBarStyleMode)
      })
      .onShown((): void => { this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE); this.shown(); })
      .onHidden((): void => { this.closeAttachmentPanel(); this.active = false; this.cancelReplyFocus(); this.voiceVisible = false; this.stopPolling();
        this.pin = ''; this.contactNumber = ''; this.numberSheet = false; this.cancelRecording(); this.privacy(false); })
      .onKeyEvent((event: KeyEvent): boolean => backInputKey(event, (): void => {
        if (this.attachmentPanelShown) { this.closeAttachmentPanel(); return; }
        ResponsiveLayout.closeContentDestination(this.pageStack);
      }))
      .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
      .backgroundColor(pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
      .attributeModifier(materialModifier(chatPageMaterial()))
  }
}
