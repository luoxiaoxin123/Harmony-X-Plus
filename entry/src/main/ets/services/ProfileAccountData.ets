import type { Tweet, MediaAttachment } from '../models/Tweet';

export class ProfileActivityPage {
  posts: Tweet[] = [];
  cursor: string = '';
  loaded: boolean = false;
  loading: boolean = false;
  status: string = '';
  webPosts: boolean = false;
  publicPosts: boolean = false;
}

export class AccountAbout {
  country: string = '';
  source: string = '';
  locationAccurate: boolean = true;
  verifiedSince: string = '';
}

export class ProfileAccountData {
  static about(body: string): AccountAbout | null {
    try {
      const root: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const data: Record<string, Object> = ProfileAccountData.obj(root, 'data');
      for (const key of ['user_result_by_screen_name', 'user_result', 'user']) {
        const result: Record<string, Object> = ProfileAccountData.obj(ProfileAccountData.obj(data, key), 'result');
        const module: Record<string, Object> = ProfileAccountData.obj(result, 'aboutModule');
        const profiles: Record<string, Object>[] = [ProfileAccountData.obj(result, 'about_profile'),
          ProfileAccountData.obj(result, 'aboutProfile'), ProfileAccountData.obj(module, 'about_profile'),
          ProfileAccountData.obj(module, 'aboutProfile')];
        for (const profile of profiles) {
          if (Object.keys(profile).length === 0) { continue; }
          const about: AccountAbout = new AccountAbout();
          about.country = ProfileAccountData.text(profile['account_based_in'] ?? profile['accountBasedIn']);
          about.source = ProfileAccountData.text(profile['source']);
          about.locationAccurate = (profile['location_accurate'] ?? profile['locationAccurate']) !== false;
          return about;
        }
      }
      return null;
    } catch (error) {
      return null;
    }
  }

  private static text(value: Object | undefined): string {
    return typeof value === 'string' ? value.trim() : '';
  }

  static video(post: Tweet): MediaAttachment | null {
    const media: MediaAttachment[] = post.attachments ?? [];
    for (let i: number = 0; i < media.length; i++) {
      if (media[i].type === 'video' || media[i].type === 'animated_gif') {
        return media[i];
      }
    }
    return null;
  }

  static duration(media: MediaAttachment | null): string {
    const seconds: number = Math.ceil((media === null ? 0 : media.durationMs ?? 0) / 1000);
    if (seconds <= 0) {
      return '';
    }
    const rest: number = seconds % 60;
    return Math.floor(seconds / 60).toString() + ':' + (rest < 10 ? '0' : '') + rest;
  }

  private static obj(source: Record<string, Object>, key: string): Record<string, Object> {
    const value: Object | undefined = source[key];
    return value !== undefined && value !== null && typeof value === 'object' &&
      !(value instanceof Array) ? value as Record<string, Object> : {};
  }
}
