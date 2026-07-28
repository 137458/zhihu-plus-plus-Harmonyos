/**
 * 错误态组件
 *
 * 垂直居中显示错误图标、标题、副标题，以及可选的重试按钮。
 * 重试按钮样式：app_primary 背景 + app_on_primary 文字 + 圆角。
 */

@ComponentV2
export struct ErrorView {
  /** 标题，默认 state_error_title */
  @Param title: string | Resource = $r('app.string.state_error_title');
  /** 副标题，默认 state_error_subtitle_default */
  @Param subtitle: string | Resource = $r('app.string.state_error_subtitle_default');
  /** 可选重试回调，不传则不显示重试按钮 */
  @Param onRetry: (() => void) | undefined = undefined;

  build() {
    Column() {
      // 错误图标：用 Text '⚠' 代替 SymbolGlyph，避免瞎猜 glyph 名
      Text('⚠')
        .fontSize($r('app.float.error_icon_size'))
        .fontColor($r('app.color.app_error_icon'));

      Text(this.title)
        .fontSize($r('app.float.error_title_font_size'))
        .fontColor($r('app.color.app_on_surface_secondary'))
        .margin({ top: 12 });

      Text(this.subtitle)
        .fontSize($r('app.float.error_subtitle_font_size'))
        .fontColor($r('app.color.app_on_surface_disabled'))
        .margin({ top: 4 });

      if (this.onRetry !== undefined) {
        Text($r('app.string.action_retry'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.app_on_primary'))
          .backgroundColor($r('app.color.app_primary'))
          .height($r('app.float.retry_button_height'))
          .borderRadius($r('app.float.retry_button_corner_radius'))
          .padding({ left: 24, right: 24 })
          .margin({ top: 16 })
          .textAlign(TextAlign.Center)
          .onClick(() => {
            const cb = this.onRetry;
            if (cb !== undefined) {
              cb();
            }
          });
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }
}
