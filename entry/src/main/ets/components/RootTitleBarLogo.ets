import {
  APP_ICON_DEFAULT,
  APP_ICON_X_BLACK,
  APP_ICON_X_WHITE,
  STORAGE_KEY_CURRENT_APP_ICON,
  titleBarLogoForeground
} from '../services/AppIconStore';
import { STORAGE_KEY_SYSTEM_DARK, STORAGE_KEY_TITLE_BAR_LOGO_AUTO_CONTRAST } from '../services/AppearanceStore';

@Component
export struct RootTitleBarLogo {
  @StorageProp(STORAGE_KEY_CURRENT_APP_ICON) private iconName: string = '';
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp(STORAGE_KEY_SYSTEM_DARK) private systemDark: boolean = false;
  @StorageProp(STORAGE_KEY_TITLE_BAR_LOGO_AUTO_CONTRAST) private autoContrast: boolean = true;

  private isDarkMode(): boolean {
    return this.displayMode === 'dark' || (this.displayMode !== 'light' && this.systemDark);
  }

  private shouldTintX(): boolean {
    return this.autoContrast && (this.iconName === APP_ICON_DEFAULT ||
      this.iconName === APP_ICON_X_BLACK || this.iconName === APP_ICON_X_WHITE);
  }

  build(): void {
    if (this.shouldTintX()) {
      Image(titleBarLogoForeground(this.isDarkMode() ? APP_ICON_X_WHITE : APP_ICON_X_BLACK))
        .width(30).height(30).objectFit(ImageFit.Contain);
    } else {
      Image(titleBarLogoForeground(this.iconName)).width(30).height(30).objectFit(ImageFit.Contain);
    }
  }
}
