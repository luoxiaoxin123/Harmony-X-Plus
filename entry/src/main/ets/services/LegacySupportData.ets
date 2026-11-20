import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { asset } from '@kit.AssetStoreKit';
import { BusinessError } from '@kit.BasicServicesKit';

// Match the two alias formats used for old redemption codes. Query attributes
// only so existing sign-in credentials and other asset secrets are never read.
const LEGACY_ALIAS: RegExp = /^harmonyx_supporter_(?:v1|account_v2_\d+)$/;
const PAGE_SIZE: number = 32;

export function removeLegacyInstallId(context: common.Context): void {
  try {
    const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_update' });
    if (store.hasSync('device_id')) {
      store.deleteSync('device_id');
      store.flushSync();
    }
  } catch (error) { }
}

export async function removeLegacySupportData(): Promise<void> {
  const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
  const aliases: Uint8Array[] = [];
  const query: asset.AssetMap = new Map();
  query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ATTRIBUTES);
  query.set(asset.Tag.RETURN_LIMIT, PAGE_SIZE);
  for (let offset: number = 0; ; offset += PAGE_SIZE) {
    query.set(asset.Tag.RETURN_OFFSET, offset);
    let rows: asset.AssetMap[];
    try { rows = await asset.query(query); }
    catch (error) {
      if ((error as BusinessError).code !== asset.ErrorCode.NOT_FOUND) { return; }
      break;
    }
    for (const row of rows) {
      const alias: Uint8Array = row.get(asset.Tag.ALIAS) as Uint8Array;
      if (alias instanceof Uint8Array && LEGACY_ALIAS.test(decoder.decodeToString(alias))) {
        aliases.push(alias);
      }
    }
    if (rows.length < PAGE_SIZE) { break; }
  }
  // Delete after collecting aliases so removals cannot shift a later page.
  for (const alias of aliases) {
    const match: asset.AssetMap = new Map();
    match.set(asset.Tag.ALIAS, alias);
    try { await asset.remove(match); }
    catch (error) { }
  }
}
