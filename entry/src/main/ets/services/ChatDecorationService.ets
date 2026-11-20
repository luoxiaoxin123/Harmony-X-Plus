import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { xChatActions } from './XChatActions';

const DOWNLOAD_DIRECTORY: string = 'chat_decorations';
const SELECTION_KEY: string = 'decoration:selection';
const INSTALL_PREFIX: string = 'decoration:installed:';
export const CHAT_DECORATION_REVISION_KEY: string = 'harmonyx.chat_decoration_revision';

export class ChatDecorationInstall {
  id: string = '';
  framePath: string = '';
  frameUri: string = '';
  bubblePath: string = '';
  bubbleUri: string = '';
  bubbleTextColor: string = '#202C26';
  sliceLeft: number = 0;
  sliceRight: number = 0;
  sliceTop: number = 0;
  sliceBottom: number = 0;
}

interface LegacyDecorationInstall {
  id: string;
  version: string;
  bubbleTextColor: string;
  sliceLeft: number;
  sliceRight: number;
  sliceTop: number;
  sliceBottom: number;
}

export class ChatDecorationSelection {
  frameId: string = '';
  framePath: string = '';
  frameUri: string = '';
  bubbleId: string = '';
  bubblePath: string = '';
  bubbleUri: string = '';
  bubbleTextColor: string = '#202C26';
  sliceLeft: number = 0;
  sliceRight: number = 0;
  sliceTop: number = 0;
  sliceBottom: number = 0;
}

export class ChatDecorationService {
  private directory(context: common.Context): string {
    return context.filesDir + '/' + DOWNLOAD_DIRECTORY;
  }

  listInstalled(context: common.Context): ChatDecorationInstall[] {
    const items: ChatDecorationInstall[] = [];
    try {
      const ids: string[] = fileIo.listFileSync(this.directory(context)).sort();
      for (const id of ids) {
        if (!/^[a-z0-9-]{2,48}$/.test(id)) { continue; }
        const item: ChatDecorationInstall | null = this.installed(context, id);
        if (item !== null) { items.push(item); }
      }
    } catch (error) { }
    return items;
  }

  private installed(context: common.Context, id: string): ChatDecorationInstall | null {
    try {
      // A package directory can be shared on disk, but the saved installation is account-scoped.
      const raw: string = xChatActions.localString(context, INSTALL_PREFIX + id, '');
      if (raw.length === 0) { return null; }
      const saved: LegacyDecorationInstall = JSON.parse(raw) as LegacyDecorationInstall;
      if (saved.id !== id || typeof saved.version !== 'string' ||
        !/^[0-9A-Za-z._-]{1,32}$/.test(saved.version) || saved.version === '.' || saved.version === '..') { return null; }
      const folder: string = this.directory(context) + '/' + id + '/' + saved.version;
      const framePath: string = folder + '/frame.png';
      const bubblePath: string = folder + '/bubble.png';
      if (!fileIo.accessSync(framePath) || !fileIo.accessSync(bubblePath)) { return null; }

      const item: ChatDecorationInstall = new ChatDecorationInstall();
      item.id = id;
      item.framePath = framePath;
      item.frameUri = fileUri.getUriFromPath(framePath);
      item.bubblePath = bubblePath;
      item.bubbleUri = fileUri.getUriFromPath(bubblePath);
      item.bubbleTextColor = this.textColor(saved.bubbleTextColor);
      item.sliceLeft = this.sliceSize(saved.sliceLeft);
      item.sliceRight = this.sliceSize(saved.sliceRight);
      item.sliceTop = this.sliceSize(saved.sliceTop);
      item.sliceBottom = this.sliceSize(saved.sliceBottom);
      return item;
    } catch (error) { return null; }
  }

  private textColor(color: string | undefined): string {
    return typeof color === 'string' && /^#[0-9A-Fa-f]{6}$/.test(color) ? color : '#202C26';
  }

  private sliceSize(size: number): number {
    return Number.isFinite(size) ? Math.max(0, Math.floor(size)) : 0;
  }

  selection(context: common.Context): ChatDecorationSelection {
    const value: ChatDecorationSelection = new ChatDecorationSelection();
    try {
      const raw: string = xChatActions.localString(context, SELECTION_KEY, '');
      if (raw.length === 0) { return value; }
      const saved: ChatDecorationSelection = JSON.parse(raw) as ChatDecorationSelection;
      if (typeof saved.framePath === 'string' && saved.framePath.length > 0 && fileIo.accessSync(saved.framePath)) {
        value.frameId = typeof saved.frameId === 'string' ? saved.frameId : '';
        value.framePath = saved.framePath;
        value.frameUri = fileUri.getUriFromPath(saved.framePath);
      }
      if (typeof saved.bubblePath === 'string' && saved.bubblePath.length > 0 && fileIo.accessSync(saved.bubblePath)) {
        value.bubbleId = typeof saved.bubbleId === 'string' ? saved.bubbleId : '';
        value.bubblePath = saved.bubblePath;
        value.bubbleUri = fileUri.getUriFromPath(saved.bubblePath);
        value.bubbleTextColor = this.textColor(saved.bubbleTextColor);
        value.sliceLeft = this.sliceSize(saved.sliceLeft);
        value.sliceRight = this.sliceSize(saved.sliceRight);
        value.sliceTop = this.sliceSize(saved.sliceTop);
        value.sliceBottom = this.sliceSize(saved.sliceBottom);
      }
    } catch (error) {}
    return value;
  }

  apply(context: common.Context, installed: ChatDecorationInstall, role: string): ChatDecorationSelection {
    const value: ChatDecorationSelection = this.selection(context);
    if (role === 'frame') {
      value.frameId = installed.id;
      value.framePath = installed.framePath;
      value.frameUri = installed.frameUri;
    } else if (role === 'bubble') {
      value.bubbleId = installed.id;
      value.bubblePath = installed.bubblePath;
      value.bubbleUri = installed.bubbleUri;
      value.bubbleTextColor = installed.bubbleTextColor;
      value.sliceLeft = installed.sliceLeft;
      value.sliceRight = installed.sliceRight;
      value.sliceTop = installed.sliceTop;
      value.sliceBottom = installed.sliceBottom;
    } else {
      throw new Error('decoration_role');
    }
    xChatActions.saveLocal(context, SELECTION_KEY, JSON.stringify(value));
    this.publish();
    return value;
  }

  clear(context: common.Context, role: string): ChatDecorationSelection {
    const value: ChatDecorationSelection = this.selection(context);
    if (role === 'frame') {
      value.frameId = '';
      value.framePath = '';
      value.frameUri = '';
    } else if (role === 'bubble') {
      value.bubbleId = '';
      value.bubblePath = '';
      value.bubbleUri = '';
      value.bubbleTextColor = '#202C26';
      value.sliceLeft = 0;
      value.sliceRight = 0;
      value.sliceTop = 0;
      value.sliceBottom = 0;
    }
    xChatActions.saveLocal(context, SELECTION_KEY, JSON.stringify(value));
    this.publish();
    return value;
  }

  private publish(): void {
    AppStorage.setOrCreate<number>(CHAT_DECORATION_REVISION_KEY,
      (AppStorage.get<number>(CHAT_DECORATION_REVISION_KEY) ?? 0) + 1);
  }
}

export const chatDecorationService: ChatDecorationService = new ChatDecorationService();
