// First-frame artwork, type and spacing. Keep account/network/feed imports out.
@Component
export struct StartupBrand {
  @Prop compact: boolean = false;
  @Prop subtitle: ResourceStr = '';
  build(): void {
    if (this.compact) {
      Row({ space: 10 }) {
        Image($r('app.media.ui_brand_foreground')).width(36).height(36).objectFit(ImageFit.Contain)
          .accessibilityLevel('no')
        Column({ space: 3 }) {
          Text($r('app.string.EntryAbility_label')).fontSize($r('app.float.startup_brand_size'))
            .fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary')).maxLines(1)
          Text(this.subtitle).fontSize($r('app.float.startup_brand_caption_size'))
            .fontColor($r('app.color.startup_brand_caption_color')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }.width('100%').height('100%')
    } else {
    Stack() {
      Column({ space: 20 }) {
        Image($r('app.media.ui_brand_foreground'))
          .width($r('app.float.startup_mark_size'))
          .height($r('app.float.startup_mark_size'))
          .objectFit(ImageFit.Contain)
          .accessibilityLevel('no')
        Text($r('app.string.EntryAbility_label'))
          .fontSize($r('app.float.startup_name_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .padding({ left: 24, right: 24 })
      .constraintSize({ maxWidth: 360 })
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.start_window_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
  }
}
