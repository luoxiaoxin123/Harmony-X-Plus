import { POST_URL, POST_BARE_DOMAIN, INVALID_BARE_URL_PREFIX, POST_TCO_URL, POST_EMOJI } from './XPostTextPatterns';

export const STANDARD_POST_CHARACTERS: number = 280;
const SHORT_URL_LENGTH: number = 23;

class TextRange {
  start: number;
  end: number;

  constructor(start: number, end: number) {
    this.start = start;
    this.end = end;
  }
}

function urlRanges(text: string): TextRange[] {
  if (!text.includes('.')) { return []; }
  const ranges: TextRange[] = [];
  POST_URL.lastIndex = 0;
  let match: RegExpExecArray | null = POST_URL.exec(text);
  while (match !== null) {
    const before: string = match[2] ?? '';
    const url: string = match[3];
    const protocol: string = match[4] ?? '';
    const domain: string = match[5];
    const path: string = match[7] ?? '';
    const end: number = POST_URL.lastIndex;
    const start: number = end - url.length;
    if (url.length <= 4096 && domain.length <= 253) {
      if (protocol.length > 0) {
        const tco: RegExpExecArray | null = POST_TCO_URL.exec(url);
        if (tco === null) { ranges.push(new TextRange(start, end)); }
        else if ((tco[1]?.length ?? 0) <= 40) { ranges.push(new TextRange(start, start + tco[0].length)); }
      } else if (!INVALID_BARE_URL_PREFIX.test(before)) {
        POST_BARE_DOMAIN.lastIndex = 0;
        let inner: RegExpExecArray | null = POST_BARE_DOMAIN.exec(domain);
        let last: TextRange | null = null;
        while (inner !== null) {
          last = new TextRange(start + inner.index, start + POST_BARE_DOMAIN.lastIndex);
          ranges.push(last);
          inner = POST_BARE_DOMAIN.exec(domain);
        }
        if (last !== null && path.length > 0) { last.end = end; }
      }
    }
    match = POST_URL.exec(text);
  }
  return ranges;
}

function characterWeight(point: number): number {
  return point <= 4351 || (point >= 8192 && point <= 8205) ||
    (point >= 8208 && point <= 8223) || (point >= 8242 && point <= 8247) ? 1 : 2;
}

export function weightedPostLength(value: string, replyHandle: string = ''): number {
  let text: string = value.trim().normalize('NFC');
  const mention: string = '@' + replyHandle.replace(/^@/, '');
  if (replyHandle.length > 0 && text.substring(0, mention.length).toLowerCase() === mention.toLowerCase() &&
    (text.length === mention.length || /\s/.test(text.charAt(mention.length)))) {
    text = text.substring(mention.length).trimStart();
  }
  const urls: TextRange[] = urlRanges(text);
  const emoji: Map<number, number> = new Map<number, number>();
  POST_EMOJI.lastIndex = 0;
  let match: RegExpExecArray | null = POST_EMOJI.exec(text);
  while (match !== null) {
    emoji.set(match.index, POST_EMOJI.lastIndex);
    match = POST_EMOJI.exec(text);
  }
  let urlIndex: number = 0;
  let count: number = 0;
  for (let i: number = 0; i < text.length;) {
    while (urlIndex < urls.length && urls[urlIndex].start < i) { urlIndex++; }
    const url: TextRange | undefined = urls[urlIndex];
    if (url !== undefined && url.start === i) {
      count += SHORT_URL_LENGTH;
      i = url.end;
      urlIndex++;
      continue;
    }
    const emojiEnd: number | undefined = emoji.get(i);
    if (emojiEnd !== undefined) {
      count += 2;
      i = emojiEnd;
      continue;
    }
    const point: number = text.codePointAt(i) ?? 0;
    count += characterWeight(point);
    i += point > 0xffff ? 2 : 1;
  }
  return count;
}
