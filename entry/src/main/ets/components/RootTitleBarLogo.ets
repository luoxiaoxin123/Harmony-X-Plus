import { STORAGE_KEY_SYSTEM_DARK, STORAGE_KEY_TITLE_BAR_LOGO_AUTO_CONTRAST } from '../services/AppearanceStore';

@Component
export struct RootTitleBarLogo {
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp(STORAGE_KEY_SYSTEM_DARK) private systemDark: boolean = false;
  @StorageProp(STORAGE_KEY_TITLE_BAR_LOGO_AUTO_CONTRAST) private autoContrast: boolean = true;

  private isDarkMode(): boolean {
    return this.displayMode === 'dark' || (this.displayMode !== 'light' && this.systemDark);
  }

  private logoFilter(): ColorFilter {
    if (!this.autoContrast) {
      return new ColorFilter([1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]);
    }
    const ink: number = this.isDarkMode() ? 1 : 0;
    return new ColorFilter([0, 0, 0, 0, ink, 0, 0, 0, 0, ink, 0, 0, 0, 0, ink, 0, 0, 0, 1, 0]);
  }

  build(): void {
    Image($r('app.media.ui_brand_foreground'))
      .width(30).height(30).objectFit(ImageFit.Contain)
      .colorFilter(this.logoFilter())
  }
}
