import { common } from '@kit.AbilityKit';

export function chatFailureMessage(context: common.Context, reason: string, fallback: Resource): string {
  const resources = context.resourceManager;
  if (reason === 'recipient_key_unavailable') { return resources.getStringSync($r('app.string.post_share_no_recipient_key')); }
  if (reason === 'existing_conversation_key_unavailable') { return resources.getStringSync($r('app.string.xchat_existing_key_unavailable')); }
  if (/^(send|keys)_(unconfirmed|dependency)$/.test(reason)) {
    return resources.getStringSync($r('app.string.xchat_delivery_unconfirmed'));
  }
  if (reason === 'conversation_dependency') { return resources.getStringSync($r('app.string.dm_load_failed')); }
  const code: string = /_rejected_([A-Z0-9_-]+)$/.exec(reason)?.[1] ?? '';
  if (code.length > 0) { return resources.getStringSync($r('app.string.xchat_delivery_rejected').id, code); }
  const http: RegExpExecArray | null = /^(public_keys|conversation|keys|send)_http_([45]\d\d)$/.exec(reason);
  if (http) {
    const stage: Resource = http[1] === 'send' ? $r('app.string.dm_send') :
      http[1] === 'conversation' ? $r('app.string.dm_load_failed') : $r('app.string.xchat_key_request_failed');
    return resources.getStringSync(stage) + ' (HTTP ' + http[2] + ')';
  }
  return resources.getStringSync(fallback);
}
