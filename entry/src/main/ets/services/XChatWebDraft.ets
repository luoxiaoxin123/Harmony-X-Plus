import { common } from '@kit.AbilityKit';
import { BuilderNode, UIContext } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { proxyStore, ProxyEntry } from './ProxyStore';
import { xUserAgent } from './XUserAgent';
import { xWebCookieBridge } from './XWebCookieBridge';
import { XChatConversationId } from './XChatConversationId';

export interface WebChatMessage { id: string; text: string; outgoing?: boolean; timestamp: number; postUrl: string; }
export interface WebChatReply { status: string; previous?: string[]; messages?: WebChatMessage[]; hasMore?: boolean; }
interface WebChatReaction { id: string; emoji: string; remove: boolean; }

export function webChatDraftScript(viewer: string, conversation: string, text: string, action: string,
  previous: string[], expires: number, digit: string = '', position: number = -1,
  reaction?: WebChatReaction): string {
  return `(() => {
    const answer = (status, previous, messages) => JSON.stringify({status, previous, messages});
    if (Date.now() > ${expires} || (location.origin !== 'https://x.com' && location.origin !== 'https://chat.x.com')) {
      return answer('unavailable');
    }
    const route = /^\\/(?:i\\/chat|messages)\\/(g?\\d+(?:[-:]\\d+)?)\\/?$/.exec(location.pathname);
    const inbox = /^\\/(?:i\\/chat|messages)\\/?$/.test(location.pathname);
    const recovery = /^\\/i\\/chat\\/pin\\/recovery\\/?$/.test(location.pathname);
    if (!route && !inbox && !recovery) return answer('waiting');
    const canonical = value => {
      const id = decodeURIComponent(value).replace(':', '-');
      if (/^g\\d+$/.test(id)) return id;
      if (!/^\\d+-\\d+$/.test(id)) return '';
      return id.split('-').sort((a, b) => a.length - b.length || (a < b ? -1 : a > b ? 1 : 0)).join('-');
    };
    if (route && canonical(route[1]) !== ${JSON.stringify(conversation)}) return answer('wrong_conversation');
    const accounts = document.cookie.split(';').map(cookie => cookie.trim()).filter(cookie => cookie.startsWith('twid='));
    if (!accounts.length || accounts.some(cookie => decodeURIComponent(cookie.slice(5)).replace(/^"|"$/g, '') !== ${JSON.stringify('u=' + viewer)})) {
      return answer('wrong_account');
    }
    const roots = [document];
    for (let index = 0; index < roots.length && index < 32; index++) {
      for (const element of roots[index].querySelectorAll('*')) {
        if (element.shadowRoot) roots.push(element.shadowRoot);
      }
    }
    const find = selector => roots.map(root => root.querySelector(selector)).find(Boolean);
    const operation = ${JSON.stringify(action)};
    let pinBoxes = [1, 2, 3, 4].map(number => find('input[aria-label="Digit ' + number + '"]'));
    if (recovery && pinBoxes.some(box => !box)) {
      const controls = roots.flatMap(root => Array.from(root.querySelectorAll('input[inputmode="numeric"][maxlength="1"]')));
      if (controls.length === 4) pinBoxes = controls;
    }
    if (pinBoxes.every(box => box && !box.disabled && !box.readOnly && box.maxLength === 1)) {
      if (operation !== 'unlock') return answer('pin_required');
      const digit = ${JSON.stringify(digit)};
      const index = ${position};
      if (!/^\\d$/.test(digit) || index < 0 || index > 3 || pinBoxes.slice(0, index).some(box => box.value.length !== 1)) {
        return answer('pin_required');
      }
      const box = pinBoxes[index];
      const setValue = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
      box.focus();
      if (box.value !== '' || !document.execCommand?.('insertText', false, digit)) {
        setValue.call(box, digit);
        box.dispatchEvent(new Event('input', {bubbles: true, composed: true}));
      }
      return answer(index === 3 ? 'pin_attempted' : 'pin_digit');
    }
    if (inbox && find('[data-testid="dm-inbox-panel"]')) return answer('inbox');
    if (!route) return answer('waiting');
    const panel = find('[data-testid="dm-conversation-panel"]');
    const box = panel?.querySelector('textarea[data-testid="dm-composer-textarea"]');
    const list = panel?.querySelector('[data-testid="dm-message-list"], [data-testid="dm-message-scroller"]');
    if (!list) return answer('waiting');
    const scroller = panel.querySelector('[data-testid="dm-message-scroller"]') || list;
    const messageTag = node => node.getAttribute('data-testid') || '';
    const messageId = node => messageTag(node).replace(/^message-(?:text-)?/, '');
    const messageNodes = Array.from(list.querySelectorAll('[data-testid^="message-"]'));
    const messageRow = node => {
      const row = node.closest?.('[data-testid^="message-"]:not([data-testid^="message-text-"])');
      return row && messageId(row) === messageId(node) ? row : node;
    };
    const outgoing = (row, bubble = row) => {
      const sender = row.getAttribute('data-sender-id');
      if (/^\\d+$/.test(sender || '')) return sender === ${JSON.stringify(viewer)};
      if (row.classList?.contains('justify-end')) return true;
      if (row.classList?.contains('justify-start')) return false;
      const bounds = list.getBoundingClientRect();
      const rect = bubble.getBoundingClientRect();
      const left = rect.left - bounds.left;
      const right = bounds.right - rect.right;
      return !rect.width || Math.abs(left - right) <= 8 ? undefined : left > right;
    };
    if (operation.startsWith('reaction_')) {
      const reaction = ${JSON.stringify(reaction ?? null)};
      if (!reaction) return answer('unavailable');
      const row = messageNodes.find(node => messageTag(node) === 'message-' + reaction.id);
      if (!row) {
        if (operation === 'reaction_open' && messageNodes.length > 0) scroller.scrollTop = 0;
        return answer('waiting');
      }
      const normalizeEmoji = value => (value || '').replace(/[\uFE0E\uFE0F]/g, '').trim();
      const emoji = normalizeEmoji(reaction.emoji);
      const label = node => node.getAttribute('aria-label') || node.getAttribute('title') || '';
      const matchesEmoji = node => normalizeEmoji(node.getAttribute('data-emoji')) === emoji ||
        normalizeEmoji(node.textContent) === emoji || normalizeEmoji(label(node)).includes(emoji) ||
        normalizeEmoji(node.querySelector('img[alt]')?.alt) === emoji;
      const visible = node => !node.disabled && node.getAttribute('aria-disabled') !== 'true' &&
        !!node.getClientRects().length;
      const picker = '[role="menu"], [data-testid*="reaction-picker"], [data-testid*="emoji-picker"]';
      const chips = Array.from(row.querySelectorAll('button, [role="button"]'))
        .filter(node => visible(node) && !node.closest(picker) && matchesEmoji(node));
      const selected = chips.some(node => node.getAttribute('aria-pressed') === 'true' ||
        node.getAttribute('data-state') === 'on' || /^(remove reaction|移除回应|取消回应)/i.test(label(node)));
      const state = JSON.stringify(chips.map(node => [label(node), node.textContent, node.getAttribute('aria-pressed'),
        node.getAttribute('data-state')]));
      const before = ${JSON.stringify(previous)};
      if (operation === 'reaction_confirm') return answer(state !== before[0] ? 'reacted' : 'waiting');
      if (operation === 'reaction_open') {
        row.scrollIntoView?.({ block: 'nearest' });
        if (!reaction.remove && selected || reaction.remove && chips.length === 0) return answer('reacted');
        if (reaction.remove && selected && chips.length === 1) {
          chips[0].click();
          return answer('reaction_submitted', [state]);
        }
        const trigger = Array.from(row.querySelectorAll('button, [role="button"]')).find(node => visible(node) &&
          (/(^|[-_])(?:message-(?:more|menu|actions)|add-reaction)([-_]|$)/i.test(messageTag(node)) ||
            /^(more message actions|message actions|add reaction|消息操作|添加回应)$/i.test(label(node))));
        if (trigger) trigger.click();
        else {
          const rect = row.getBoundingClientRect();
          const bubble = row.querySelector('[data-testid^="message-text-"]') || row;
          bubble.dispatchEvent(new MouseEvent('contextmenu', { bubbles: true, composed: true, cancelable: true,
            button: 2, clientX: Math.round((rect.left + rect.right) / 2), clientY: Math.round((rect.top + rect.bottom) / 2) }));
        }
        return answer('reaction_opened', [state]);
      }
      const controls = Array.from(new Set(roots.flatMap(root => Array.from(root.querySelectorAll(
        '[role="menu"] button, [role="menuitem"], [data-testid*="reaction-picker"] button, ' +
        '[data-testid*="emoji-picker"] button, button[data-testid*="reaction-emoji"]')))));
      const choices = controls.filter(node => visible(node) && !chips.includes(node) && matchesEmoji(node));
      if (choices.length !== 1) {
        const more = controls.find(node => visible(node) && !chips.includes(node) &&
          (/^(more reactions|more emojis|choose emoji|更多表情|更多回应)$/i.test(label(node)) ||
            /(?:more-emoji|more-reaction|open-emoji-picker)/i.test(messageTag(node))));
        if (more && operation === 'reaction_choose') { more.click(); return answer('reaction_picker'); }
        return answer('waiting');
      }
      choices[0].click();
      return answer('reaction_submitted', before);
    }
    const linkedPost = node => Array.from(node.querySelectorAll?.('a[href]') || []).map(anchor => {
      try { return new URL(anchor.href, location.origin); } catch (_) { return null; }
    }).find(link => link && /^(?:www\\.)?(?:x\\.com|twitter\\.com)$/.test(link.hostname) && /\\/status\\/\\d+(?:\\/|$)/.test(link.pathname));
    if (operation === 'history' || operation === 'earlier') {
      if (operation === 'earlier') { scroller.scrollTop = 0; return answer('scrolled'); }
      const rows = new Map();
      for (const node of messageNodes) {
        const tag = messageTag(node);
        const textNode = tag.startsWith('message-text-');
        const id = messageId(node);
        if (!id || rows.has(id)) continue;
        const row = messageRow(node);
        const message = textNode ? node : node.querySelector('[data-testid^="message-text-"]');
        const text = (message?.innerText || message?.textContent || '').trim();
        const link = linkedPost(row);
        if (!text && !link) continue;
        const time = row.querySelector('time');
        rows.set(id, { id, text, outgoing: outgoing(row, message || row),
          timestamp: Date.parse(time?.dateTime || '') || 0, postUrl: link?.href || '' });
      }
      if (rows.size === 0 && !panel.querySelector('[data-testid="dm-composer-textarea"]')) return answer('waiting');
      return answer('history', undefined, Array.from(rows.values()).slice(-120));
    }
    if (!box || box.disabled || box.readOnly) return answer('waiting');
    const requested = ${JSON.stringify(text)};
    if (operation === 'prepare') {
      if (box.value === requested) return answer('ready');
      if (box.value.length > 0) return answer('occupied');
      Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value').set.call(box, requested);
      box.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
      return answer('staged');
    }
    if (operation === 'submit') {
      const send = panel.querySelector('[data-testid="dm-composer-send-button"]');
      if (box.value !== requested || !send || send.disabled || send.getAttribute('aria-disabled') === 'true') {
        return answer('waiting');
      }
      const before = messageNodes.map(node => node.getAttribute('data-testid'));
      send.click();
      return answer('submitted', before);
    }
    if (box.value.length > 0) return answer('waiting');
    const before = ${JSON.stringify(previous)};
    const normalize = value => value.replace(/\\s+/g, ' ').trim();
    const lines = requested.split('\\n');
    const post = /^https:\\/\\/x\\.com\\/(?:i|[^/]+)\\/status\\/(\\d+)$/.exec(lines[lines.length - 1]);
    const note = normalize(lines.slice(0, -1).join('\\n'));
    const matchesPostCard = node => {
      if (!post) return false;
      if (note && normalize(node.querySelector('[data-testid^="message-text-"]')?.innerText || '') !== note) return false;
      return Array.from(node.querySelectorAll('a[href]')).some(anchor => {
        const link = new URL(anchor.href, location.origin);
        return /^(?:www\\.)?(?:x\\.com|twitter\\.com)$/.test(link.hostname) &&
          new RegExp('/status/' + post[1] + '(?:/|$)').test(link.pathname);
      });
    };
    const confirmed = messageNodes.some(node => {
      if (before.includes(node.getAttribute('data-testid'))) return false;
      const text = node.innerText || node.textContent || '';
      const row = messageRow(node);
      return outgoing(row, node) === true &&
        (normalize(text) === normalize(requested) || matchesPostCard(node));
    });
    return answer(confirmed ? 'confirmed' : 'waiting');
  })()`;
}

class ChatWebNode {
  readonly controller: webview.WebviewController = new webview.WebviewController();
  readonly url: string;
  failed: boolean = false;

  constructor(url: string) { this.url = url; }
}

@Builder
function BuildChatWebNode(node: ChatWebNode): void {
  Web({ src: node.url, controller: node.controller })
    .width(720)
    .height(900)
    .javaScriptAccess(true)
    .domStorageAccess(true)
    .databaseAccess(true)
    .fileAccess(false)
    .userAgent(xUserAgent.value())
    .onPageBegin((): void => { node.controller.onActive(); })
    .onLoadIntercept((event): boolean => {
      if (event === undefined || !event.data.isMainFrame()) { return false; }
      const url: string = event.data.getRequestUrl();
      return !/^https:\/\/(?:x\.com|chat\.x\.com)(?:\/|$)/.test(url);
    })
    .onErrorReceive((event): void => {
      if (event?.request.isMainFrame()) { node.failed = true; }
    })
    .onRenderExited((): void => { node.failed = true; })
    .onHttpAuthRequest((event): boolean => {
      if (event === undefined) { return false; }
      const proxy: ProxyEntry | null = proxyStore.webProxyEntry();
      if (proxy === null || proxy.username.length === 0 || proxy.password.length === 0) {
        event.handler.cancel();
        return false;
      }
      return event.handler.confirm(proxy.username, proxy.password);
    })
}

async function evaluate(node: ChatWebNode, viewer: string, id: string, text: string, action: string,
  expires: number, previous: string[] = [], digit: string = '', position: number = -1,
  reaction?: WebChatReaction): Promise<WebChatReply> {
  let timer: number = -1;
  try {
    const result: string = await Promise.race([
      node.controller.runJavaScript(webChatDraftScript(viewer, id, text, action, previous, expires, digit, position, reaction)),
      new Promise<string>((resolve: (value: string) => void): void => {
        timer = setTimeout((): void => { resolve(''); }, Math.max(0, Math.min(1500, expires - Date.now())));
      })
    ]);
    const decoded: Object | string = JSON.parse(result) as Object | string;
    return typeof decoded === 'string' ? JSON.parse(decoded) as WebChatReply : decoded as WebChatReply;
  } catch (_error) { return { status: 'no_result' }; }
  finally { if (timer >= 0) { clearTimeout(timer); } }
}

class ChatWebSession {
  viewer: string;
  id: string;
  node: ChatWebNode;
  builder: BuilderNode<[ChatWebNode]>;

  constructor(ui: UIContext, viewer: string, id: string) {
    this.viewer = viewer;
    this.id = id;
    this.node = new ChatWebNode(ChatWebSession.url(id));
    this.builder = new BuilderNode<[ChatWebNode]>(ui);
    this.builder.build(wrapBuilder(BuildChatWebNode), this.node);
  }

  static url(id: string): string { return 'https://x.com/i/chat/' + encodeURIComponent(id); }

  open(id: string): void {
    this.id = id;
    this.node.controller.loadUrl(ChatWebSession.url(id));
  }
}

let session: ChatWebSession | undefined;
let busy: boolean = false;

async function nextFrame(): Promise<void> {
  await new Promise<void>((resolve: () => void): void => { setTimeout(resolve, 250); });
}

async function runChatWeb(context: common.Context, ui: UIContext, viewer: string, conversationId: string, text: string,
  oldest: string, isCurrent: () => boolean, pin: string, reading: boolean, reaction?: WebChatReaction): Promise<WebChatReply> {
  const id: string = XChatConversationId.canonical(conversationId).replace(':', '-');
  if (!id || !/^\d+$/.test(viewer)) { return { status: 'unavailable' }; }
  if (reaction !== undefined) {
    const waitUntil: number = Date.now() + 5000;
    while (busy && isCurrent() && Date.now() < waitUntil) { await nextFrame(); }
  }
  if (busy) { return { status: 'busy' }; }
  busy = true;
  let submitted: boolean = false;
  let resetPendingPin: boolean = false;
  try {
    await proxyStore.applyToWebStack();
    if (!isCurrent() || !xWebCookieBridge.syncActive(context)) { return { status: 'unavailable' }; }
    if (session === undefined || session.viewer !== viewer || session.node.failed) {
      session?.builder.dispose();
      session = new ChatWebSession(ui, viewer, id);
    } else {
      session.node.controller.onActive();
      if (session.id !== id) { session.open(id); }
    }
    const active: ChatWebSession = session;
    const node: ChatWebNode = active.node;
    let deadline: number = Date.now() + (pin.length > 0 ? 25000 : 15000);
    let pinAttempted: boolean = false;
    let redirected: boolean = false;
    let readySince: number = 0;
    let scrollRequested: boolean = false;
    let scrollExpires: number = 0;
    let beforeScroll: Set<string> = new Set<string>();
    let reactionAction: string = 'reaction_open';
    let reactionBefore: string[] = [];
    while (Date.now() < deadline && !node.failed && isCurrent()) {
      const action: string = reaction !== undefined ? reactionAction : reading ? 'history' : 'prepare';
      const reply: WebChatReply = await evaluate(node, viewer, id, text, action, deadline, reactionBefore, '', -1, reaction);
      if (!isCurrent()) { break; }
      if (reply.status === 'wrong_account' || reply.status === 'occupied') { return reply; }
      if (reply.status === 'wrong_conversation' && reaction !== undefined) { return reply; }
      if (reply.status === 'pin_required' && !pinAttempted) {
        if (!/^\d{4}$/.test(pin)) { return reply; }
        pinAttempted = true;
        resetPendingPin = true;
        for (let index: number = 0; index < 4 && isCurrent() && !node.failed; index++) {
          const unlock: WebChatReply = await evaluate(node, viewer, id, '', 'unlock', Date.now() + 1500, [], pin[index], index);
          if (unlock.status !== 'pin_digit') { break; }
          await nextFrame();
        }
        pin = '';
        deadline = Date.now() + 20000;
      } else if (reply.status === 'inbox' && !redirected) {
        resetPendingPin = false;
        redirected = true;
        active.open(id);
      } else if (reaction !== undefined) {
        if (reply.status === 'reacted') { return reply; }
        if (reply.status === 'reaction_opened' || reply.status === 'reaction_submitted') {
          reactionBefore = reply.previous ?? [];
          submitted = reply.status === 'reaction_submitted';
          reactionAction = submitted ? 'reaction_confirm' : 'reaction_choose';
        } else if (reply.status === 'reaction_picker') {
          reactionAction = 'reaction_pick';
        } else if (reply.status === 'no_result' && reactionAction !== 'reaction_confirm') {
          return { status: 'unconfirmed' };
        }
      } else if (reading && reply.status === 'history') {
        resetPendingPin = false;
        const messages: WebChatMessage[] = reply.messages ?? [];
        if (!oldest) { return { status: 'history', messages: messages, hasMore: messages.length > 0 }; }
        if (!scrollRequested) {
          beforeScroll = new Set(messages.map((message: WebChatMessage): string => message.id));
          await evaluate(node, viewer, id, '', 'earlier', deadline);
          scrollRequested = true;
          scrollExpires = Date.now() + 5500;
        } else {
          const boundary: number = messages.findIndex((message: WebChatMessage): boolean => message.id === oldest);
          if (boundary > 0) { return { status: 'history', messages: messages.slice(0, boundary), hasMore: true }; }
          if (boundary < 0 && messages.length > 0 && beforeScroll.size > 0 &&
            messages.every((message: WebChatMessage): boolean => !beforeScroll.has(message.id))) {
            return { status: 'history', messages: messages, hasMore: true };
          }
          if (Date.now() >= scrollExpires) { return { status: 'history', messages: [], hasMore: false }; }
        }
      } else if (!reading && reply.status === 'ready') {
        resetPendingPin = false;
        if (readySince === 0) { readySince = Date.now(); }
        else if (Date.now() - readySince >= 350) {
          submitted = true;
          const sent: WebChatReply = await evaluate(node, viewer, id, text, 'submit', Date.now() + 1500);
          if (sent.status === 'no_result') { return { status: 'unconfirmed' }; }
          if (sent.status !== 'submitted') { return { status: 'unavailable' }; }
          const previous: string[] | undefined = sent.previous;
          if (!Array.isArray(previous)) { return { status: 'unconfirmed' }; }
          const confirmUntil: number = Date.now() + 10000;
          while (Date.now() < confirmUntil && !node.failed && isCurrent()) {
            const confirmed: WebChatReply = await evaluate(node, viewer, id, text, 'confirm', confirmUntil, previous);
            if (confirmed.status === 'confirmed') { return confirmed; }
            if (confirmed.status === 'wrong_account' || confirmed.status === 'wrong_conversation') { break; }
            await nextFrame();
          }
          return { status: 'unconfirmed' };
        }
      } else {
        readySince = 0;
      }
      await nextFrame();
    }
    return { status: resetPendingPin ? 'pin_unconfirmed' : submitted ? 'unconfirmed' : 'unavailable' };
  } catch (_error) {
    return { status: submitted ? 'unconfirmed' : 'unavailable' };
  } finally {
    pin = '';
    busy = false;
    try {
      if (resetPendingPin) {
        session?.builder.dispose();
        session = undefined;
      } else {
        session?.node.controller.onInactive();
      }
    } catch (_error) { }
  }
}

export async function sendXChatWebDraft(context: common.Context, ui: UIContext, viewer: string, conversationId: string,
  text: string, isCurrent: () => boolean, pin: string = ''): Promise<string> {
  if (!text.trim()) { return 'unavailable'; }
  return (await runChatWeb(context, ui, viewer, conversationId, text, '', isCurrent, pin, false)).status;
}

export function readXChatWebHistory(context: common.Context, ui: UIContext, viewer: string, conversationId: string,
  oldest: string, isCurrent: () => boolean, pin: string = ''): Promise<WebChatReply> {
  return runChatWeb(context, ui, viewer, conversationId, '', oldest, isCurrent, pin, true);
}

export async function reactInXChatWeb(context: common.Context, ui: UIContext, viewer: string, conversationId: string,
  messageId: string, emoji: string, remove: boolean, isCurrent: () => boolean): Promise<string> {
  if (!messageId || !emoji.trim()) { return 'unavailable'; }
  const reply: WebChatReply = await runChatWeb(context, ui, viewer, conversationId, '', '', isCurrent, '', false,
    { id: messageId, emoji: emoji, remove: remove });
  return reply.status;
}
