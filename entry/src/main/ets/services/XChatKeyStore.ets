import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';

class XChatKeyStore {
  private match(userId: string): asset.AssetMap {
    const attributes: asset.AssetMap = new Map();
    attributes.set(asset.Tag.ALIAS, new util.TextEncoder().encodeInto('harmonyx_xchat_key_' + userId));
    return attributes;
  }

  load(userId: string): string {
    if (userId.length === 0) { return ''; }
    const attributes: asset.AssetMap = this.match(userId);
    attributes.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const secret: Uint8Array | undefined = asset.querySync(attributes)[0]?.get(asset.Tag.SECRET) as Uint8Array | undefined;
      return secret === undefined ? '' : util.TextDecoder.create('utf-8').decodeToString(secret);
    } catch (error) { return ''; }
  }

  save(userId: string, key: string): boolean {
    if (userId.length === 0 || key.length === 0) { return false; }
    const attributes: asset.AssetMap = this.match(userId);
    attributes.set(asset.Tag.SECRET, new util.TextEncoder().encodeInto(key));
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED);
    attributes.set(asset.Tag.SYNC_TYPE, asset.SyncType.NEVER);
    attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
    try { asset.addSync(attributes); return true; }
    catch (error) { return false; }
  }

  remove(userId: string): boolean {
    if (userId.length === 0) { return true; }
    try { asset.removeSync(this.match(userId)); return true; }
    catch (error) { return (error as BusinessError).code === asset.ErrorCode.NOT_FOUND; }
  }
}

export const xChatKeyStore: XChatKeyStore = new XChatKeyStore();
