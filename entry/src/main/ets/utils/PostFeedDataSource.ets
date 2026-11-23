import type { Tweet } from '../models/Tweet';

// Feed pages replace their post arrays when a new page arrives. Keep the
// derived order available to lazy rows until the input or view options change.
export class PostFeedProjection {
  private source: Tweet[] | undefined;
  private variant: string | number = '';
  private rows: Tweet[] = [];

  get(source: Tweet[], variant: string | number, project: (posts: Tweet[]) => Tweet[]): Tweet[] {
    if (this.source !== source || this.variant !== variant) {
      this.rows = project(source);
      this.source = source;
      this.variant = variant;
    }
    return this.rows;
  }
}

export class PostFeedItem {
  key: string;
  index: number;

  constructor(key: string, index: number) {
    this.key = key;
    this.index = index;
  }
}

// Include the full-width header/footer in the same lazy source as the cards.
export class PostFeedDataSource implements IDataSource {
  private items: PostFeedItem[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number { return this.items.length; }
  getData(index: number): PostFeedItem { return this.items[index]; }
  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) { this.listeners.push(listener); }
  }
  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener);
    if (index >= 0) { this.listeners.splice(index, 1); }
  }
  replace(keys: string[]): void {
    const next: PostFeedItem[] = [new PostFeedItem('header', -1)];
    for (let index: number = 0; index < keys.length; index++) {
      // The builder receives an index into the parent's filtered array. Include
      // it so a retained row cannot keep a stale index after search/deletion.
      next.push(new PostFeedItem('post:' + index.toString() + ':' + keys[index], index));
    }
    next.push(new PostFeedItem('footer', -2));
    const previous: PostFeedItem[] = this.items;
    const footerIndex: number = previous.length - 1;
    const appended: boolean = footerIndex >= 1 && next.length > previous.length &&
      previous.every((item: PostFeedItem, index: number): boolean => index === footerIndex || item.key === next[index].key);
    const changes: DataOperation[] = [];
    if (appended) {
      // Move the existing footer past the entire page in one dataset update.
      changes.push({ type: DataOperationType.ADD, index: footerIndex, count: next.length - previous.length });
    } else if (previous.length !== next.length) {
      changes.push({ type: DataOperationType.RELOAD });
    } else {
      for (let index: number = 0; index < next.length; index++) {
        if (previous[index].key !== next[index].key) {
          changes.push({ type: DataOperationType.CHANGE, index: index });
        }
      }
    }
    this.items = next;
    if (changes.length === 0) { return; }
    for (const listener of this.listeners) {
      listener.onDatasetChange(changes);
    }
  }
}
