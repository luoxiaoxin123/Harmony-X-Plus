export const COMPOSER_MAX_MEDIA_ITEMS: number = 20;
export const COMPOSER_MAX_ALT_CHARACTERS: number = 1000;
export const COMPOSER_MEDIA_IMAGE: number = 1;
export const COMPOSER_MEDIA_GIF: number = 2;
export const COMPOSER_MEDIA_VIDEO: number = 3;

export class ComposerMedia {
  uri: string;
  type: number;
  alt: string;

  constructor(uri: string, type: number, alt: string = '') {
    this.uri = uri;
    this.type = type;
    this.alt = alt;
  }
}

export function addComposerMedia(current: ComposerMedia[], candidate: ComposerMedia): ComposerMedia[] {
  if (current.length >= COMPOSER_MAX_MEDIA_ITEMS || typeof candidate.uri !== 'string' ||
    candidate.uri.length === 0 || !Number.isInteger(candidate.type) ||
    candidate.type < COMPOSER_MEDIA_IMAGE || candidate.type > COMPOSER_MEDIA_VIDEO ||
    current.some((item: ComposerMedia): boolean =>
      item.uri === candidate.uri || item.type === COMPOSER_MEDIA_GIF && candidate.type === COMPOSER_MEDIA_GIF)) {
    return current;
  }
  return [...current, new ComposerMedia(candidate.uri, candidate.type,
    candidate.type !== COMPOSER_MEDIA_VIDEO && typeof candidate.alt === 'string' ?
      candidate.alt.slice(0, COMPOSER_MAX_ALT_CHARACTERS) : '')];
}

export function legacyComposerMedia(images: string[], gif: string, video: string): ComposerMedia[] {
  if (video.length > 0) { return [new ComposerMedia(video, COMPOSER_MEDIA_VIDEO)]; }
  const items: ComposerMedia[] = images.map((uri: string): ComposerMedia => new ComposerMedia(uri, COMPOSER_MEDIA_IMAGE));
  if (gif.length > 0) { items.push(new ComposerMedia(gif, COMPOSER_MEDIA_GIF)); }
  return items;
}
