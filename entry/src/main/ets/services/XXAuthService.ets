import http from '@ohos.net.http';
import { XXAuthAnnouncement, XXAuthArticle, XXAuthResult, XXAuthVersion } from '../models/XXAuth';

// Public software identifier; developer credentials never belong in this client.
export const XXAUTH_APP_ID: string = '2778143c-260a-4e04-83ad-2889f6aaad0d';
export const XXAUTH_PLATFORM: string = 'harmonyos';
const BASE_URL: string = 'https://api.xxauth.com/open/v1';

interface XXAuthEnvelope {
  code: number;
  message?: string;
  data?: Object;
}

export class XXAuthService {
  private async request<T>(path: string): Promise<XXAuthResult<T>> {
    const result: XXAuthResult<T> = new XXAuthResult<T>();
    let request: http.HttpRequest | null = null;
    try {
      request = http.createHttp();
      const response: http.HttpResponse = await request.request(BASE_URL + path, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        header: { 'app_id': XXAUTH_APP_ID, 'Accept': 'application/json' },
        connectTimeout: 8000, readTimeout: 8000
      });
      result.status = response.responseCode;
      if (typeof response.result !== 'string') { return result; }
      const envelope: XXAuthEnvelope = JSON.parse(response.result as string) as XXAuthEnvelope;
      result.code = envelope.code;
      if (response.responseCode === 200 && envelope.code === 0 &&
        envelope.data !== undefined && envelope.data !== null) {
        result.data = envelope.data as T;
        result.ok = true;
      }
    } catch (error) {
      // No payloads, identity headers or server content in logs.
    } finally {
      if (request !== null) { request.destroy(); }
    }
    return result;
  }

  async announcements(): Promise<XXAuthResult<XXAuthAnnouncement[]>> {
    let result: XXAuthResult<XXAuthAnnouncement[]> = new XXAuthResult<XXAuthAnnouncement[]>();
    for (let attempt: number = 0; attempt < 3; attempt++) {
      result = await this.request<XXAuthAnnouncement[]>('/announcements');
      if (result.ok && !(result.data instanceof Array)) { result.ok = false; }
      if (result.ok || (result.status >= 400 && result.status < 500 && result.status !== 408) || attempt === 2) {
        return result;
      }
      await new Promise<void>((resolve): void => { setTimeout((): void => resolve(), (attempt + 1) * 1000); });
    }
    return result;
  }

  articles(): Promise<XXAuthResult<XXAuthArticle[]>> {
    return this.request<XXAuthArticle[]>('/articles');
  }

  latestVersion(): Promise<XXAuthResult<XXAuthVersion>> {
    return this.request<XXAuthVersion>('/version/latest?platform=' + XXAUTH_PLATFORM);
  }

  versions(): Promise<XXAuthResult<XXAuthVersion[]>> {
    return this.request<XXAuthVersion[]>('/version/list?platform=' + XXAUTH_PLATFORM);
  }
}

export const xxAuthService: XXAuthService = new XXAuthService();
