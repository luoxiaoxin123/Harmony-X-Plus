import type { XPrivateResult } from './XPrivateClient';

interface WireError { code?: number | string; message?: string; extensions?: WireError; }
interface WireOperation {
  encoded_message_event?: string;
  conversation_key_change_sequence_id?: string;
  error_code?: number | string | null;
}
interface WireEnvelope { data?: Record<string, WireOperation>; errors?: WireError[]; }

export class XChatReceipt {
  event: string = '';
  keySequence: string = '';
  code: string = '';
  acknowledged: boolean = false;
}

export class XChatWire {
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
        receipt.code = unknownOperation ? 'PERSISTED_QUERY_NOT_FOUND' : XChatWire.safeCode(error.code ?? error.extensions?.code);
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

  static alternate(result: XPrivateResult, receipt: XChatReceipt): boolean {
    return result.status === 404 || receipt.code === 'PERSISTED_QUERY_NOT_FOUND' ||
      receipt.code === 'PERSISTEDQUERYNOTFOUND' || XChatWire.transient(result.status);
  }

  static issue(stage: string, result: XPrivateResult, receipt: XChatReceipt): string {
    if (result.status < 0) { return stage + '_network'; }
    if (result.status >= 400) { return stage + '_http_' + result.status; }
    if (receipt.code.length > 0 || !result.ok) { return stage + '_rejected_' + (receipt.code || 'UNKNOWN'); }
    return stage + '_unconfirmed';
  }

  private static safeCode(value: number | string | null | undefined): string {
    const code: string = String(value ?? '');
    return /^[A-Z0-9_-]{1,64}$/i.test(code) ? code.toUpperCase() : 'UNKNOWN';
  }
}
