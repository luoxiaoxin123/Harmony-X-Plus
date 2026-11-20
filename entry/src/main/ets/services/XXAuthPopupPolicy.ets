import { XXAuthAnnouncement, XXAuthPanel, XXAuthVersion } from '../models/XXAuth';

export class XXAuthPopupPolicy {
  static text(value: string | undefined): string {
    if (typeof value !== 'string') { return ''; }
    return value.replace(/\/\/(提醒|关闭)/g, '')
      .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '')
      .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, '')
      .replace(/<\/(p|div|li|h[1-6])\s*>|<br\s*\/?\s*>/gi, '\n')
      .replace(/<[^>]*>/g, '').replace(/&nbsp;/g, ' ').replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'")
      .replace(/&amp;/g, '&').trim();
  }

  static https(value: string | undefined): string {
    if (typeof value !== 'string') { return ''; }
    const link: string = value.trim();
    return /^https:\/\/[^\s/@]+(?:\:[0-9]+)?(?:[/?#][^\s]*)?$/i.test(link) ? link : '';
  }

  static publicAnnouncements(items: XXAuthAnnouncement[]): XXAuthAnnouncement[] {
    return items.filter((item: XXAuthAnnouncement): boolean => {
      if (!item || typeof item.content !== 'string' || item.content.indexOf('//关闭') >= 0) { return false; }
      // Preserve the server's reserved priority slots so legacy control records stay hidden.
      if ((item.priority >= 10 && item.priority <= 16) ||
        (item.priority === -2 && item.title?.trim() === '链接')) { return false; }
      return XXAuthPopupPolicy.text(item.content).length > 0;
    }).sort((left: XXAuthAnnouncement, right: XXAuthAnnouncement): number =>
      (right.priority ?? 0) - (left.priority ?? 0));
  }

  static announcement(item: XXAuthAnnouncement): XXAuthPanel {
    const panel: XXAuthPanel = new XXAuthPanel();
    panel.id = item.id;
    panel.kind = 'announcement';
    panel.title = XXAuthPopupPolicy.text(item.title);
    panel.content = XXAuthPopupPolicy.text(item.content);
    panel.fingerprint = JSON.stringify([item.id, item.title, item.content]);
    panel.repeat = item.content.indexOf('//提醒') >= 0;
    return panel;
  }

  static versionParts(version: string): number[] {
    const value: string = version.trim();
    return /^v?\d+\.\d+\.\d+$/i.test(value) ?
      value.replace(/^v/i, '').split('.').map((part: string): number => Number(part)) : [];
  }

  static update(latest: XXAuthVersion, current: string): XXAuthPanel | undefined {
    if (typeof latest?.version !== 'string' || (latest.channel && latest.channel !== 'stable')) { return undefined; }
    const published: number[] = XXAuthPopupPolicy.versionParts(latest.version);
    const installed: number[] = XXAuthPopupPolicy.versionParts(current);
    if (published.length !== 3 || installed.length !== 3) { return undefined; }
    for (let i: number = 0; i < 3; i++) {
      if (published[i] < installed[i]) { return undefined; }
      if (published[i] === installed[i]) { continue; }
      const panel: XXAuthPanel = new XXAuthPanel();
      panel.id = latest.version;
      panel.kind = 'update';
      panel.version = latest.version;
      panel.content = XXAuthPopupPolicy.text(latest.change_log);
      panel.link = XXAuthPopupPolicy.https(latest.download_url);
      panel.fingerprint = JSON.stringify([panel.version, panel.content, panel.link]);
      return panel;
    }
    return undefined;
  }
}
