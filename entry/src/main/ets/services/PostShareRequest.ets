import type { Tweet } from '../models/Tweet';

export const STORAGE_KEY_POST_SHARE_REQUEST: string = 'harmonyx.post_share_request';

export interface PostShareRequest {
  post: Tweet;
  pageStack: NavPathStack;
  beforeNavigate?: () => void;
}

let pending: PostShareRequest | undefined;

export function openPostShare(post: Tweet, pageStack: NavPathStack, beforeNavigate?: () => void): void {
  pending = { post: post, pageStack: pageStack, beforeNavigate: beforeNavigate };
  const revision: number = AppStorage.get<number>(STORAGE_KEY_POST_SHARE_REQUEST) ?? 0;
  AppStorage.setOrCreate<number>(STORAGE_KEY_POST_SHARE_REQUEST, revision + 1);
}

export function takePostShareRequest(): PostShareRequest | undefined {
  const request: PostShareRequest | undefined = pending;
  pending = undefined;
  return request;
}
