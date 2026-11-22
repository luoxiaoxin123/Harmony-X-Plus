import { ComposerMedia, addComposerMedia, legacyComposerMedia } from '../models/ComposerMedia';
// Persists one compose draft and independent reply drafts by post id.
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { ComposerOptions } from '../models/ComposerOptions';

export class ComposerDraft {
  text: string;
  media: ComposerMedia[];
  updatedAt: number;
  options: ComposerOptions = new ComposerOptions();

  constructor(text: string, media: ComposerMedia[], updatedAt: number) {
    this.text = text;
    this.media = media;
    this.updatedAt = updatedAt;
  }
}

export class ComposerDraftStore {
  private static readonly STORE_NAME: string = 'harmonyx_composer';

  load(context: common.Context, scope: string): ComposerDraft {
    try {
      const options: preferences.Options = { name: ComposerDraftStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const prefix: string = this.prefix(scope);
      const text: string = store.getSync(prefix + 'text', '') as string;
      const rawMedia: string = store.getSync(prefix + 'media', '') as string;
      let entries: ComposerMedia[];
      if (rawMedia.length > 0) {
        const decoded: ComposerMedia[] = JSON.parse(rawMedia) as ComposerMedia[];
        entries = Array.isArray(decoded) ? decoded : [];
      } else {
        const rawImages: string = store.getSync(prefix + 'images', '[]') as string;
        const images: string[] = JSON.parse(rawImages) as string[];
        entries = legacyComposerMedia(Array.isArray(images) ? images : [],
          store.getSync(prefix + 'gif', '') as string, store.getSync(prefix + 'video', '') as string);
      }
      let media: ComposerMedia[] = [];
      entries.forEach((entry: ComposerMedia): void => {
        if (entry !== null) { media = addComposerMedia(media, entry); }
      });
      const updatedAt: number = store.getSync(prefix + 'updated_at', 0) as number;
      const draft: ComposerDraft = new ComposerDraft(text, media, updatedAt);
      draft.options = ComposerOptions.restore(store.getSync(prefix + 'options', '{}') as string);
      // Older drafts can carry attachments; never restore an incompatible poll.
      if (media.length > 0) {
        draft.options.pollChoices = []; draft.options.pollImages = [];
      }
      return draft;
    } catch (error) {
      return new ComposerDraft('', [], 0);
    }
  }

  save(context: common.Context, scope: string, draft: ComposerDraft): void {
    try {
      const options: preferences.Options = { name: ComposerDraftStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const prefix: string = this.prefix(scope);
      store.putSync(prefix + 'text', draft.text);
      store.putSync(prefix + 'media', JSON.stringify(draft.media));
      store.putSync(prefix + 'updated_at', draft.updatedAt);
      store.putSync(prefix + 'options', JSON.stringify(draft.options));
      store.flushSync();
    } catch (error) {
      // A draft is a convenience; a write failure must not block composing.
    }
  }

  clear(context: common.Context, scope: string): void {
    this.save(context, scope, new ComposerDraft('', [], 0));
  }

  private prefix(scope: string): string {
    return 'draft_' + scope + '_';
  }
}

export const composerDraftStore: ComposerDraftStore = new ComposerDraftStore();
