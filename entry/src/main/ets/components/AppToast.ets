/**
 * Toast 渲染组件
 *
 * 仅负责根据 visible 与 message 渲染 Toast 外观；显示/隐藏的时序由
 * ToastUtil 维护的 toastState 单例驱动，AppToast 不持有自身状态。
 *
 * 容器：半透明黑底 + 圆角；位置：Stack 底部对齐，距底部 96vp。
 * 通过 Stack 覆盖在主内容之上，不拦截下层点击事件。
 */

@ComponentV2
export struct AppToast {
  /** Toast 文本 */
  @Param message: string | Resource = '';
  /** 是否显示 */
  @Param visible: boolean = false;

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.visible) {
        Text(this.message)
          .fontSize($r('app.float.toast_font_size'))
          .fontColor('#FFFFFF')
          .backgroundColor('rgba(0,0,0,0.8)')
          .borderRadius($r('app.float.toast_corner_radius'))
          .padding({
            left: $r('app.float.toast_padding_horizontal'),
            right: $r('app.float.toast_padding_horizontal'),
            top: $r('app.float.toast_padding_vertical'),
            bottom: $r('app.float.toast_padding_vertical')
          })
          .constraintSize({ maxWidth: $r('app.float.toast_max_width') })
          .textAlign(TextAlign.Center)
          .margin({ bottom: 96 });
      }
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent);
  }
}
