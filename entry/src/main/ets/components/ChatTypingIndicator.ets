@Component
export struct ChatTypingIndicator {
  @Prop reduceMotion: boolean = false;
  @State raised: boolean = false;

  build(): void {
    Row({ space: 4 }) {
      ForEach([0, 1, 2], (index: number): void => {
        Circle().width(5).height(5).fill($r('app.color.text_secondary'))
          .opacity(this.raised ? 1 : 0.5)
          .translate({ y: this.raised ? -3 : 0 })
          .animation({ duration: 360, delay: 100 * index, iterations: -1, playMode: PlayMode.Alternate })
      })
    }.height(30).padding({ left: 12, right: 12 }).borderRadius(15).backgroundColor($r('app.color.bg_card'))
      .accessibilityText($r('app.string.chat_typing'))
      .onAppear((): void => { if (!this.reduceMotion) { this.raised = true; } })
  }
}
