/**
 * 加载态组件
 *
 * 垂直居中显示 LoadingProgress 与可选提示文字，填满父容器。
 */

@ComponentV2
export struct LoadingView {
  /** 提示文字，默认使用资源中的 state_loading */
  @Param tip: string | Resource = $r('app.string.state_loading');

  build() {
    Column() {
      LoadingProgress()
        .width($r('app.float.loading_indicator_size'))
        .height($r('app.float.loading_indicator_size'))
        .color($r('app.color.app_loading'));

      Text(this.tip)
        .fontSize($r('app.float.body_secondary_font_size'))
        .fontColor($r('app.color.app_on_surface_secondary'))
        .margin({ top: 12 });
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }
}
