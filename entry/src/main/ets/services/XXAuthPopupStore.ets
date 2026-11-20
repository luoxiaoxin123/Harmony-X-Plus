import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { XXAuthPanel } from '../models/XXAuth';

export const XXAUTH_POPUP_REQUEST: string = 'harmonyx.xxauth_popup_request';
const STORE: string = 'harmonyx_update';

export function requestXXAuthPopup(kind: string): void {
  AppStorage.setOrCreate<string>(XXAUTH_POPUP_REQUEST, kind + ':' + Date.now().toString());
}

export class XXAuthPopupStore {
  private open(context: common.Context): preferences.Preferences {
    return preferences.getPreferencesSync(context, { name: STORE });
  }

  removeLegacyInstallId(context: common.Context): void {
    try {
      const store: preferences.Preferences = this.open(context);
      if (store.hasSync('device_id')) {
        store.deleteSync('device_id');
        store.flushSync();
      }
    } catch (error) { }
  }

  shouldShow(context: common.Context, panel: XXAuthPanel): boolean {
    try {
      return panel.repeat || this.open(context).getSync('seen_' + panel.kind + '_' + panel.id, '') !== panel.fingerprint;
    } catch (error) { return true; }
  }

  markRead(context: common.Context, panel: XXAuthPanel): void {
    try {
      const store: preferences.Preferences = this.open(context);
      store.putSync('seen_' + panel.kind + '_' + panel.id, panel.fingerprint);
      store.flushSync();
    } catch (error) { }
  }
}

export const xxAuthPopupStore: XXAuthPopupStore = new XXAuthPopupStore();
