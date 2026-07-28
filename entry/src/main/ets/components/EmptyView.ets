/**
 * 空态组件
 *
 * 垂直居中显示图标（可选自定义，默认用文字符号代替 SymbolGlyph 避免瞎猜 glyph 名）、
 * 标题与副标题，填满父容器。
 */

@ComponentV2
export struct EmptyView {
  /** 标题，默认 state_empty_title */
  @Param title: string | Resource = $r('app.string.state_empty_title');
  /** 副标题，默认 state_empty_subtitle */
  @Param subtitle: string | Resource = $r('app.string.state_empty_subtitle');
  /** 可选自定义图标资源；不传则渲染默认占位符号 */
  @Param icon: Resource | undefined = undefined;

  build() {
    Column() {
      if (this.icon !== undefined) {
        Image(this.icon)
          .width($r('app.float.empty_icon_size'))
          .height($r('app.float.empty_icon_size'));
      } else {
        // 默认占位：用文字符号代替，避免使用未确认的 SymbolGlyph glyph 名
        Text('○')
          .fontSize($r('app.float.empty_icon_size'))
          .fontColor($r('app.color.app_empty_icon'));
      }

      Text(this.title)
        .fontSize($r('app.float.empty_title_font_size'))
        .fontColor($r('app.color.app_on_surface_secondary'))
        .margin({ top: 12 });

      Text(this.subtitle)
        .fontSize($r('app.float.empty_subtitle_font_size'))
        .fontColor($r('app.color.app_on_surface_disabled'))
        .margin({ top: 4 });
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }
}
