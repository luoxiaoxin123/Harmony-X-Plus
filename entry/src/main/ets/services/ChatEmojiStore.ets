import { common } from '@kit.AbilityKit';
import util from '@ohos.util';
import { xChatActions } from './XChatActions';

export interface ChatEmoji { emoji: string; name: string; keywords: string; }
export interface ChatEmojiGroup { id: string; entries: ChatEmoji[]; }

// Default order from the official XChat bundle. The 14th slot in the quick
// panel is the more button; the full recent section also includes pleading.
export const CHAT_DEFAULT_REACTIONS: string[] = ['🎉', '🔥', '🤠', '💯', '👍', '🤔', '😭', '♥️', '😂', '👎', '😢', '😬', '🧠', '🥺'];
export const CHAT_QUICK_REACTIONS: string[] = CHAT_DEFAULT_REACTIONS.slice(0, 13);

export class ChatEmojiStore {
  private groups: ChatEmojiGroup[] = [];
  private variantGroups: Map<string, ChatEmoji[]> = new Map<string, ChatEmoji[]>();

  private variantKey(emoji: string): string {
    return emoji.replace(/[\u{1F3FB}-\u{1F3FF}\uFE0F]/gu, '').replace(/\u200D[♀♂](?=$)/u, '');
  }

  variants(context: common.Context, emoji: string): ChatEmoji[] {
    this.load(context);
    return this.variantGroups.get(this.variantKey(emoji)) ?? [];
  }

  private choices(context: common.Context): Record<string, string> {
    try {
      return JSON.parse(xChatActions.localString(context, 'preferred_emoji_variants', '{}')) as Record<string, string>;
    } catch (error) { return {}; }
  }

  preferred(context: common.Context, emoji: string): string {
    const picked: string | undefined = this.choices(context)[this.variantKey(emoji)];
    if (picked === undefined) { return emoji; }
    return this.variants(context, emoji).some((item: ChatEmoji): boolean => item.emoji === picked) ? picked : emoji;
  }

  rememberVariant(context: common.Context, base: string, emoji: string): void {
    if (!this.variants(context, base).some((item: ChatEmoji): boolean => item.emoji === emoji)) { return; }
    const choices: Record<string, string> = this.choices(context);
    choices[this.variantKey(base)] = emoji;
    xChatActions.saveLocal(context, 'preferred_emoji_variants', JSON.stringify(choices));
  }
  load(context: common.Context): ChatEmojiGroup[] {
    if (this.groups.length === 0) {
      const bytes: Uint8Array = context.resourceManager.getRawFileContentSync('chat-emoji-17.json');
      this.groups = JSON.parse(util.TextDecoder.create('utf-8').decodeToString(bytes)) as ChatEmojiGroup[];
      this.groups.forEach((group: ChatEmojiGroup): void => {
        group.entries.forEach((entry: ChatEmoji): void => {
          const key: string = this.variantKey(entry.emoji);
          const variants: ChatEmoji[] = this.variantGroups.get(key) ?? [];
          variants.push(entry);
          this.variantGroups.set(key, variants);
        });
      });
    }
    return this.groups;
  }
  recent(context: common.Context): ChatEmoji[] {
    let recent: string[] = [];
    try {
      const saved: string[] = JSON.parse(xChatActions.localString(context, 'recent_emoji', '[]')) as string[];
      if (Array.isArray(saved)) { recent = saved.filter((item: string): boolean => typeof item === 'string' && item.length > 0); }
    } catch (error) {}
    return recent.concat(CHAT_DEFAULT_REACTIONS).filter((value: string, index: number, all: string[]): boolean =>
      all.indexOf(value) === index).slice(0, 28).map((value: string): ChatEmoji => ({ emoji: value, name: value, keywords: value }));
  }
  used(context: common.Context, emoji: string): void {
    const recent: string[] = this.recent(context).map((item: ChatEmoji): string => item.emoji);
    xChatActions.saveLocal(context, 'recent_emoji', JSON.stringify([emoji].concat(recent.filter((e: string): boolean => e !== emoji)).slice(0, 28)));
  }
  search(context: common.Context, query: string): ChatEmojiGroup[] {
    const value: string = query.trim().toLowerCase();
    if (value.length === 0) {
      const recent: ChatEmojiGroup = { id: 'recent', entries: this.recent(context) };
      return [recent].concat(this.load(context));
    }
    return this.load(context).map((group: ChatEmojiGroup): ChatEmojiGroup => ({ id: group.id,
      entries: group.entries.filter((entry: ChatEmoji): boolean => entry.emoji.indexOf(value) >= 0 ||
        entry.name.toLowerCase().indexOf(value) >= 0 || entry.keywords.toLowerCase().indexOf(value) >= 0)
    })).filter((group: ChatEmojiGroup): boolean => group.entries.length > 0);
  }
}

export const chatEmojiStore: ChatEmojiStore = new ChatEmojiStore();
