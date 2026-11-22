import type { XPrivateResult } from './XPrivateClient';

interface WireError { code?: number | string; message?: string; extensions?: WireError; }
interface WireOperation {
  encoded_message_event?: string;
  conversation_key_change_sequence_id?: string;
  error_code?: number | string | null;
}
interface WireEnvelope { data?: Record<string, WireOperation>; errors?: WireError[]; }
interface RestWriteData { encoded_message_event?: string; conversation_id?: string; sequence_id?: string; }
interface RestWriteEnvelope { data?: RestWriteData; errors?: WireError[]; code?: number | string; }
interface RestEvent { id?: string; conversation_id?: string; sender_id?: string; encoded_event?: string; }
interface RestEventMeta { next_token?: string; result_count?: number; conversation_key_events?: string[]; }
interface RestEventEnvelope { data?: RestEvent[]; meta?: RestEventMeta; errors?: WireError[]; }

export class XChatHistory {
  events: string[] = [];
  senders: string[] = [];
  nextToken: string = '';
}

export class XChatReceipt {
  event: string = '';
  keySequence: string = '';
  code: string = '';
  acknowledged: boolean = false;
}

export class XChatWire {
  static conversationPath(id: string): string { return 'chat/conversations/' + encodeURIComponent(id); }

  static history(body: string, conversationId: string): XChatHistory | null {
    try {
      const envelope: RestEventEnvelope = JSON.parse(body) as RestEventEnvelope;
      if (!Array.isArray(envelope.data) && (envelope.meta?.result_count !== 0 || envelope.errors?.length)) { return null; }
      const page: XChatHistory = new XChatHistory();
      page.nextToken = typeof envelope.meta?.next_token === 'string' ? envelope.meta?.next_token : '';
      for (const keyEvent of envelope.meta?.conversation_key_events ?? []) {
        if (typeof keyEvent === 'string' && keyEvent.length > 0) { page.events.push(keyEvent); }
      }
      for (const row of envelope.data ?? []) {
        if ((row.conversation_id && row.conversation_id.replace(':', '-') !== conversationId) ||
          typeof row.encoded_event !== 'string' || row.encoded_event.length === 0) { continue; }
        page.events.push(row.encoded_event);
        if (row.sender_id && !page.senders.includes(row.sender_id)) { page.senders.push(row.sender_id); }
      }
      return page.events.length === 0 && (envelope.data?.length ?? 0) > 0 ? null : page;
    } catch (_error) { return null; }
  }

  static restReceipt(result: XPrivateResult, conversationId: string, keys: boolean): XChatReceipt {
    const receipt: XChatReceipt = new XChatReceipt();
    try {
      const envelope: RestWriteEnvelope = JSON.parse(result.body) as RestWriteEnvelope;
      const data: RestWriteData | undefined = envelope.data;
      if (envelope.errors?.length || envelope.code !== undefined) {
        receipt.code = XChatWire.safeCode(envelope.errors?.[0]?.code ?? envelope.code);
      } else if (result.ok && keys && data?.conversation_id?.replace(':', '-') === conversationId &&
        /^\d+$/.test(data?.sequence_id ?? '')) {
        receipt.keySequence = data?.sequence_id ?? '';
        receipt.acknowledged = true;
      } else if (result.ok && !keys && typeof data?.encoded_message_event === 'string') {
        receipt.event = data.encoded_message_event;
        receipt.acknowledged = receipt.event.length > 0;
      }
    } catch (_error) { }
    return receipt;
  }

  static receipt(result: XPrivateResult, field: string): XChatReceipt {
    const receipt: XChatReceipt = new XChatReceipt();
    try {
      const envelope: WireEnvelope = JSON.parse(result.body) as WireEnvelope;
      const operation: WireOperation | undefined = envelope.data?.[field];
      const code: number | string | null | undefined = operation?.error_code;
      const error: WireError | undefined = envelope.errors?.[0];
      if (code !== undefined && code !== null && code !== 0 && code !== '0') {
        receipt.code = XChatWire.safeCode(code);
      } else if (result.ok && operation?.encoded_message_event) {
        receipt.event = operation.encoded_message_event;
        receipt.acknowledged = true;
      } else if (error) {
        const message: string = error.message ?? '';
        const unknownOperation: boolean = /persisted\s*query\s*(not\s*found|not\s*supported)|unknown operation/i.test(message);
        const dependency: boolean = /^Dependency\s*:/i.test(message);
        receipt.code = unknownOperation ? 'PERSISTED_QUERY_NOT_FOUND' :
          dependency ? 'DEPENDENCY' : XChatWire.safeCode(error.code ?? error.extensions?.code);
      } else if (result.ok && operation) {
        receipt.keySequence = operation.conversation_key_change_sequence_id ?? '';
        receipt.acknowledged = field === 'xchat_add_encrypted_conversation_key' &&
          (code === null || code === 0 || code === '0' || /^\d+$/.test(receipt.keySequence));
      }
    } catch (_error) { }
    return receipt;
  }

  static transient(status: number): boolean {
    return status === -1 || status === 502 || status === 503 || status === 504;
  }

  static uncertain(result: XPrivateResult, receipt: XChatReceipt): boolean {
    return XChatWire.transient(result.status) || receipt.code === 'DEPENDENCY';
  }

  static alternate(result: XPrivateResult, receipt: XChatReceipt): boolean {
    return result.status === 404 || receipt.code === 'PERSISTED_QUERY_NOT_FOUND' ||
      receipt.code === 'PERSISTEDQUERYNOTFOUND' || XChatWire.uncertain(result, receipt);
  }

  static issue(stage: string, result: XPrivateResult, receipt: XChatReceipt): string {
    if (result.status < 0) { return stage + '_network'; }
    if (result.status >= 400) { return stage + '_http_' + result.status; }
    if (receipt.code === 'DEPENDENCY') { return stage + '_dependency'; }
    if (receipt.code.length > 0 || !result.ok) { return stage + '_rejected_' + (receipt.code || 'UNKNOWN'); }
    return stage + '_unconfirmed';
  }

  private static safeCode(value: number | string | null | undefined): string {
    const code: string = String(value ?? '');
    return /^[A-Z0-9_-]{1,64}$/i.test(code) ? code.toUpperCase() : 'UNKNOWN';
  }
}
