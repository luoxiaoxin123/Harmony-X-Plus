export interface XXAuthAnnouncement {
  id: string;
  title: string;
  content: string;
  priority: number;
  created_at?: string;
  updated_at?: string;
  status?: number;
}

export interface XXAuthArticle {
  id: string;
  title: string;
  content: string;
  sort_order?: number;
}

export interface XXAuthVersion {
  version: string;
  download_url?: string;
  change_log?: string;
  published_at?: string;
  channel?: string;
}

export class XXAuthResult<T> {
  ok: boolean = false;
  status: number = 0;
  code: number = -1;
  data: T | undefined = undefined;
}

export class XXAuthPanel {
  id: string = '';
  kind: string = '';
  title: string = '';
  content: string = '';
  link: string = '';
  version: string = '';
  repeat: boolean = false;
  fingerprint: string = '';
}
