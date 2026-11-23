import { bundleManager } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';

// Clear the launcher selection left by versions that shipped alternate icons.
export async function restoreDefaultAppIcon(): Promise<void> {
  if (!deviceInfo.apiAvailable('26.0.0')) { return; }
  try {
    await bundleManager.setAlternateIcon('');
  } catch (_error) {
    // Clones and some system themes can reject launcher icon changes.
  }
}
