import { STORAGE_KEY_POST_CARD_LAYOUT, STORAGE_KEY_POST_DETAIL_COMPACT, STORAGE_KEY_POST_MEDIA_SCALE } from '../services/PostDisplaySettingsStore';
import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import { DEFAULT_POST_ACTIONS_MASK, postDisplaySettingsStore, STORAGE_KEY_POST_ACTIONS_MASK, STORAGE_KEY_POST_ACTION_COUNTS } from '../services/PostDisplaySettingsStore';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { pageTextColor } from '../utils/ThemeColors';
import { STORAGE_KEY_POST_COUNT_FORMAT } from '../services/PostDisplaySettingsStore';

@Component
export struct PostDisplaySettings {
  @StorageProp(STORAGE_KEY_POST_ACTIONS_MASK) private actionsMask: number = DEFAULT_POST_ACTIONS_MASK;
  @StorageProp(STORAGE_KEY_POST_ACTION_COUNTS) private counts: boolean = true;
  @StorageLink(STORAGE_KEY_POST_CARD_LAYOUT) private cardLayout: number = 0;
  @StorageLink(STORAGE_KEY_POST_DETAIL_COMPACT) private detailLayout: number = 0;
  @StorageLink(STORAGE_KEY_POST_MEDIA_SCALE) private mediaScale: number = 100;
  @StorageProp(STORAGE_KEY_POST_COUNT_FORMAT) private countFormat: number = 0;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';

  private saved(ok: boolean): void {
    if (!ok) { promptAction.showToast({ message: $r('app.string.settings_interaction_save_failed') }); }
  }

  @Builder
  private ActionRow(bit: number, label: Resource): void {
    Row({ space: 12 }) {
      Text(label).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).layoutWeight(1)
        .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
      Toggle({ type: ToggleType.Switch, isOn: bit === 0 ? this.counts : (this.actionsMask & bit) !== 0 })
        .onChange((value: boolean): void => {
          const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
          this.saved(bit === 0 ? postDisplaySettingsStore.saveCounts(context, value) :
            postDisplaySettingsStore.saveMask(context, value ? this.actionsMask | bit : this.actionsMask & ~bit));
        }).accessibilityText(label)
    }.width('100%').constraintSize({ minHeight: 48 })
  }

  build(): void {
    Column({ space: 4 }) {
      Row({ space: 12 }) {
        Text($r('app.string.settings_post_card_layout')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_L')).layoutWeight(1)
        Select([{ value: $r('app.string.settings_post_layout_classic') },
          { value: $r('app.string.settings_post_layout_wide') },
          { value: $r('app.string.settings_post_layout_compact') }]).selected(this.cardLayout)
          .onSelect((value: number): void => {
            this.saved(postDisplaySettingsStore.saveLayoutValue(getContext(this), STORAGE_KEY_POST_CARD_LAYOUT, value));
          })
      }.width('100%').constraintSize({ minHeight: 48 })
      Row({ space: 12 }) {
        Text($r('app.string.settings_post_detail_layout')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_L')).layoutWeight(1)
        Select([{ value: $r('app.string.settings_post_layout_classic') },
          { value: $r('app.string.settings_post_layout_compact') }]).selected(this.detailLayout)
          .onSelect((value: number): void => {
            this.saved(postDisplaySettingsStore.saveLayoutValue(getContext(this), STORAGE_KEY_POST_DETAIL_COMPACT, value));
          })
      }.width('100%').constraintSize({ minHeight: 48 })
      Row({ space: 12 }) {
        Text($r('app.string.settings_post_media_scale')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
        Slider({ value: this.mediaScale, min: 50, max: 100, step: 5 }).layoutWeight(1)
          .accessibilityText($r('app.string.settings_post_media_scale'))
          .onChange((value: number, mode: SliderChangeMode): void => {
            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
              const saved: boolean = postDisplaySettingsStore.saveLayoutValue(getContext(this), STORAGE_KEY_POST_MEDIA_SCALE, value);
              this.saved(saved);
            }
          })
        Text(this.mediaScale.toString() + '%').fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
      }.width('100%').constraintSize({ minHeight: 48 })
      Text($r('app.string.settings_post_actions')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S'))
        .fontWeight(FontWeight.Bold).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).width('100%')
      Text($r('app.string.settings_post_actions_desc')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
        .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).width('100%')
      this.ActionRow(0, $r('app.string.settings_post_action_counts'))
      Row({ space: 12 }) {
        Text($r('app.string.settings_post_count_format')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_L')).layoutWeight(1)
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
        Select([{ value: $r('app.string.settings_post_count_compact') },
          { value: $r('app.string.settings_post_count_chinese') },
          { value: $r('app.string.settings_post_count_full') }])
          .selected(this.countFormat).onSelect((format: number): void => {
            this.saved(postDisplaySettingsStore.saveCountFormat(getContext(this) as common.UIAbilityContext, format));
          }).id('settings-post-count-format')
      }.width('100%').constraintSize({ minHeight: 48 })
      this.ActionRow(1, $r('app.string.action_reply'))
      this.ActionRow(2, $r('app.string.action_repost'))
      this.ActionRow(4, $r('app.string.action_like'))
      this.ActionRow(8, $r('app.string.post_detail_views'))
      this.ActionRow(16, $r('app.string.action_bookmark'))
      this.ActionRow(32, $r('app.string.action_share'))
      this.ActionRow(64, $r('app.string.post_translate'))
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
