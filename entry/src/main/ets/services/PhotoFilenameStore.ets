import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import type { Tweet } from '../models/Tweet';

export const PHOTO_FILENAME_PARTS: string[] = ['date', 'author', 'index', 'code', 'post'];

export function normalizePhotoFilenameParts(parts: string[]): string[] {
  return parts.filter((part: string, index: number): boolean =>
    PHOTO_FILENAME_PARTS.includes(part) && parts.indexOf(part) === index);
}

function safePart(value: string): string {
  return value.trim().replace(/[\x00-\x1f\x7f<>:"/\\|?*]/g, '_').replace(/^[. ]+|[. ]+$/g, '').slice(0, 64);
}

function originalCode(url: string): string {
  if (!/^https?:\/\//i.test(url)) { return ''; }
  const path: string = url.split(/[?#]/, 1)[0];
  if (path.indexOf('/', path.indexOf('://') + 3) < 0) { return ''; }
  const segment: string = path.substring(path.lastIndexOf('/') + 1).replace(/\.[a-z0-9]{2,5}$/i, '');
  try { return decodeURIComponent(segment); } catch (error) { return segment; }
}

function localDate(value: string): string {
  if (/^\d{4}-\d{2}-\d{2}$/.test(value)) { return value; }
  const date: Date = new Date(value);
  if (!Number.isFinite(date.getTime())) { return ''; }
  return date.getFullYear().toString() + '-' + (date.getMonth() + 1).toString().padStart(2, '0') +
    '-' + date.getDate().toString().padStart(2, '0');
}

export function photoFilenameTitle(parts: string[], date: string, username: string, sourceIndex: number,
  url: string, postId: string): string {
  const values: Record<string, string> = {
    'date': localDate(date), 'author': username.replace(/^@/, ''),
    'index': Number.isInteger(sourceIndex) && sourceIndex >= 0 ? (sourceIndex + 1).toString() : '',
    'code': originalCode(url), 'post': postId
  };
  const title: string = normalizePhotoFilenameParts(parts).map((part: string): string => safePart(values[part]))
    .filter((part: string): boolean => part.length > 0).join('-').slice(0, 120).replace(/[. ]+$/g, '');
  return title.length > 0 ? 'HarmonyX-' + title : '';
}

class PhotoFilenameStore {
  load(context: common.Context): string[] {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_photo_filename' });
      const parts: string[] = JSON.parse(store.getSync('parts', '[]') as string) as string[];
      return Array.isArray(parts) ? normalizePhotoFilenameParts(parts) : [];
    } catch (error) { return []; }
  }

  save(context: common.Context, parts: string[]): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_photo_filename' });
      store.putSync('parts', JSON.stringify(normalizePhotoFilenameParts(parts)));
      store.flushSync();
      return true;
    } catch (error) { return false; }
  }

  title(parts: string[], tweet: Tweet | null, sourceIndex: number, url: string): string {
    return photoFilenameTitle(parts, tweet?.createdAt ?? '', tweet?.author.username ?? '', sourceIndex, url, tweet?.id ?? '');
  }
}

export const photoFilenameStore: PhotoFilenameStore = new PhotoFilenameStore();
