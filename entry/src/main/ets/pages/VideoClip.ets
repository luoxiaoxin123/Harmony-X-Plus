import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { accountStore } from '../services/AccountStore';
import { ExternalShareFile, ExternalSharePayload } from '../services/ExternalShareStore';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { proxyDownloadService } from '../services/ProxyDownloadService';
import { xPrivateClient } from '../services/XPrivateClient';
import type { ReplyComposerRouteParam } from '../components/ReplyComposer';

export interface VideoClipRoute {
  url: string;
  durationMs: number;
}

@Builder
export function VideoClipBuilder(): void { VideoClipPage() }

@Component
struct VideoClipPage {
  @Consume('pageStack') private pageStack: NavPathStack;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.status_bar_height') private top: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private bottom: number = 0;
  @State private maxSeconds: number = 0;
  @State private startSeconds: number = 0;
  @State private clipSeconds: number = 15;
  @State private actualStart: number = 0;
  @State private working: boolean = false;
  @State private preview: string = '';
  @State private error: boolean = false;
  private sourcePath: string = '';
  private previewPath: string = '';
  private url: string = '';
  private accountId: string = '';
  private alive: boolean = true;
  private keepOutput: boolean = false;
  private serial: number = 0;

  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext; }

  private label(resource: Resource): string { return this.context().resourceManager.getStringSync(resource); }

  private open(route: VideoClipRoute): void {
    if (route === undefined || !/^https:\/\//i.test(route.url) || !Number.isFinite(route.durationMs)) { return; }
    this.alive = true;
    this.url = route.url;
    this.accountId = accountStore.activeId(this.context());
    this.maxSeconds = Math.max(0, Math.floor(route.durationMs / 1000));
    this.clipSeconds = Math.min(15, this.maxSeconds);
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.removeTemporaryFile(this.sourcePath);
    if (!this.keepOutput) { this.removeTemporaryFile(this.previewPath); }
  }

  private removeTemporaryFile(path: string): void {
    if (path.length === 0) { return; }
    try { fileIo.unlinkSync(path); } catch (error) {}
  }

  private available(): boolean {
    return this.alive && accountStore.activeId(this.context()) === this.accountId && this.accountId.length > 0;
  }

  private clearPreview(): void {
    this.preview = '';
    this.removeTemporaryFile(this.previewPath);
    this.previewPath = '';
  }

  private changeStart(value: number): void {
    this.startSeconds = Math.round(value);
    this.clipSeconds = Math.min(this.clipSeconds, this.maximumLength());
    this.clearPreview();
  }

  private maximumLength(): number { return Math.max(1, Math.min(60, this.maxSeconds - this.startSeconds)); }

  private async exportPreview(): Promise<void> {
    if (this.working || !this.available() || this.url.length === 0) { return; }
    const context: common.UIAbilityContext = this.context();
    this.clearPreview();
    this.working = true;
    this.error = false;
    const serial: string = Date.now().toString() + '-' + (++this.serial);
    const output: string = context.filesDir + '/harmonyx-clip-' + serial + '.mp4';
    let inputFile: fileIo.File | undefined;
    let outputFile: fileIo.File | undefined;
    try {
      if (this.sourcePath.length === 0) {
        const source: string = context.cacheDir + '/harmonyx-clip-source-' + serial + '.mp4';
        if (!await proxyDownloadService.downloadWithRetry(this.url, source, 1) || !this.available()) {
          this.removeTemporaryFile(source);
          throw new Error('Video source unavailable');
        }
        this.sourcePath = source;
      }
      const cutter = await import('libharmonyx_video_clip.so');
      if (!this.available()) { return; }
      inputFile = await fileIo.open(this.sourcePath, fileIo.OpenMode.READ_ONLY);
      outputFile = await fileIo.open(output, fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.READ_WRITE);
      this.actualStart = await cutter.exportClip(inputFile.fd, outputFile.fd, this.startSeconds * 1000, this.clipSeconds * 1000);
      if (!this.available()) { return; }
      this.previewPath = output;
      this.preview = fileUri.getUriFromPath(output);
    } catch (error) {
      if (this.alive) { this.error = true; }
    } finally {
      if (inputFile !== undefined) { try { fileIo.closeSync(inputFile.fd); } catch (error) {} }
      if (outputFile !== undefined) { try { fileIo.closeSync(outputFile.fd); } catch (error) {} }
      if (this.previewPath !== output) { this.removeTemporaryFile(output); }
      this.working = false;
    }
  }

  private useClip(): void {
    if (!this.available() || this.preview.length === 0 || !xPrivateClient.isSignedIn()) { return; }
    const payload: ExternalSharePayload = new ExternalSharePayload();
    payload.id = 'video-clip-' + Date.now().toString();
    const attachment: ExternalShareFile = new ExternalShareFile();
    attachment.uri = this.preview;
    attachment.filename = 'video-clip.mp4';
    attachment.type = 3;
    payload.files = [attachment];
    const params: ReplyComposerRouteParam = {
      replyToId: '', replyToUser: '', avatarUrl: '', avatarName: '', avatarColor: '#007DFF',
      initialText: '', imageUri: '', gifUri: '', communityId: '', communityName: '', parentTweet: null, sharedPayload: payload
    };
    this.keepOutput = true;
    this.pageStack.replacePath({ name: 'ReplyComposer', param: params });
  }

  build(): void {
    HdsNavDestination() {
      Scroll() {
        Column({ space: 14 }) {
          if (this.preview.length > 0) {
            Video({ src: this.preview }).controls(true).width('100%').height(220)
            Text(this.label($r('app.string.video_clip_actual_start')) + ' ' + (this.actualStart / 1000).toFixed(1) + ' s')
              .fontFamily(this.appFontFamily)
          }
          Text(this.label($r('app.string.video_clip_start')) + ' ' + this.startSeconds.toString() + ' s')
            .width('100%').fontFamily(this.appFontFamily)
          Slider({ value: this.startSeconds, min: 0, max: Math.max(1, this.maxSeconds - 1), step: 1 })
            .enabled(!this.working && this.maxSeconds > 1).accessibilityText($r('app.string.video_clip_start'))
            .onChange((value: number): void => this.changeStart(value))
          Text(this.label($r('app.string.video_clip_length')) + ' ' + this.clipSeconds.toString() + ' s')
            .width('100%').fontFamily(this.appFontFamily)
          Slider({ value: this.clipSeconds, min: 1, max: Math.max(2, this.maximumLength()), step: 1 })
            .enabled(!this.working && this.maximumLength() > 1).accessibilityText($r('app.string.video_clip_length'))
            .onChange((value: number): void => { this.clipSeconds = Math.round(value); this.clearPreview(); })
          if (this.working) { LoadingProgress().width(28).height(28) }
          if (this.error) {
            Text($r('app.string.video_clip_failed')).fontFamily(this.appFontFamily).fontColor($r('app.color.danger'))
          }
          Button($r('app.string.video_clip_preview')).width('100%').enabled(!this.working && this.maxSeconds > 0)
            .onClick((): void => { void this.exportPreview(); })
          Button($r('app.string.video_clip_use')).width('100%').enabled(!this.working && this.preview.length > 0)
            .onClick((): void => this.useClip())
        }.width('100%').constraintSize({ maxWidth: 600 }).padding({ top: this.top + 68, left: 20, right: 20, bottom: this.bottom + 20 })
      }.width('100%').height('100%').backgroundColor($r('app.color.bg_page'))
    }.titleMode(HdsNavDestinationTitleMode.MINI)
      .titleBar({ content: { title: { mainTitle: $r('app.string.video_clip_title') } } })
      .onReady((context: NavDestinationContext): void => this.open(context.pathInfo.param as VideoClipRoute))
  }
}
