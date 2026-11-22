import { bundleManager } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { PROJECT_RELEASES_URL, PROJECT_REPOSITORY } from '../utils/ProjectLinks';

export const PROJECT_UPDATE_KEY: string = 'harmonyx.project_update';

export class ProjectUpdate {
  version: string = '';
  url: string = '';
}

interface GithubRelease {
  tag_name?: string;
  html_url?: string;
  prerelease?: boolean;
  draft?: boolean;
}

function versionParts(version: string): string[] {
  return /^v?(0|[1-9]\d{0,8})\.(0|[1-9]\d{0,8})\.(0|[1-9]\d{0,8})(?:-([\w.-]+))?(?:\+[\w.-]+)?$/
    .exec(version)?.slice(1, 5) ?? [];
}

function compareVersion(left: string[], right: string[]): number {
  for (let i: number = 0; i < 3; i++) {
    const diff: number = Number(left[i]) - Number(right[i]);
    if (diff !== 0) { return diff; }
  }
  if (!left[3] || !right[3]) { return Number(!left[3]) - Number(!right[3]); }
  const a: string[] = left[3].replace(/\.g[\da-f]{7,40}$/i, '').split('.');
  const b: string[] = right[3].replace(/\.g[\da-f]{7,40}$/i, '').split('.');
  for (let i: number = 0; i < Math.min(a.length, b.length); i++) {
    if (a[i] === b[i]) { continue; }
    const aNumeric: boolean = /^\d+$/.test(a[i]);
    const bNumeric: boolean = /^\d+$/.test(b[i]);
    if (aNumeric && bNumeric) { return Number(a[i]) - Number(b[i]); }
    if (aNumeric !== bNumeric) { return aNumeric ? -1 : 1; }
    return a[i] < b[i] ? -1 : 1;
  }
  return a.length - b.length;
}

export function newerProjectRelease(body: string, installed: string): ProjectUpdate {
  const current: string[] = versionParts(installed);
  const update: ProjectUpdate = new ProjectUpdate();
  if (current.length === 0) { return update; }
  const releases: GithubRelease[] = JSON.parse(body) as GithubRelease[];
  if (!Array.isArray(releases)) { return update; }
  let best: string[] = current;
  const releasePrefix: string = PROJECT_RELEASES_URL + '/tag/';
  for (const release of releases) {
    if (!release || release.draft || typeof release.tag_name !== 'string' ||
      typeof release.html_url !== 'string' || !release.html_url.startsWith(releasePrefix) ||
      (release.html_url !== releasePrefix + release.tag_name &&
        release.html_url !== releasePrefix + encodeURIComponent(release.tag_name))) { continue; }
    const candidate: string[] = versionParts(release.tag_name);
    if (candidate.length === 0 || (!current[3] && (release.prerelease || candidate[3])) ||
      compareVersion(candidate, best) <= 0) { continue; }
    best = candidate;
    update.version = release.tag_name.replace(/^v/, '');
    update.url = release.html_url;
  }
  return update;
}

class ProjectUpdates {
  private checking: boolean = false;

  async check(): Promise<void> {
    if (this.checking) { return; }
    this.checking = true;
    let request: http.HttpRequest | undefined;
    try {
      request = http.createHttp();
      const installed: string = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION).versionName;
      const result: http.HttpResponse = await request.request('https://api.github.com/repos/' +
        PROJECT_REPOSITORY + '/releases?per_page=30', {
        method: http.RequestMethod.GET, connectTimeout: 6000, readTimeout: 6000,
        header: { 'Accept': 'application/vnd.github+json', 'User-Agent': 'Harmony-X-Plus' }
      });
      if (result.responseCode === 200) {
        const body: string = typeof result.result === 'string' ? result.result : JSON.stringify(result.result);
        AppStorage.setOrCreate<ProjectUpdate>(PROJECT_UPDATE_KEY, newerProjectRelease(body, installed));
      }
    } catch (_error) {
      // The last successful check remains visible if GitHub is temporarily unavailable.
    } finally {
      request?.destroy();
      this.checking = false;
    }
  }
}

export const projectUpdates: ProjectUpdates = new ProjectUpdates();
