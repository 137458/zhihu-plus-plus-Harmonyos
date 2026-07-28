/**
 * Toast 渲染组件
 *
 * 仅负责根据 toastState 单例的 visible 与 message 属性渲染 Toast 外观；
 * 显示/隐藏的时序由 ToastUtil 维护的 toastState 单例驱动，AppToast 不持有自身状态。
 *
 * 容器：半透明黑底 + 圆角；位置：Stack 底部对齐，距底部 toast_bottom_offset。
 * 通过 Stack 覆盖在主内容之上，不拦截下层点击事件。
 *
 * 实现要点：
 * - @ObservedV2 + @Trace 的属性变化通知要求组件直接持有被观察实例的引用，
 *   不能通过 @Param 传递基本类型值间接传递（@Param 是值拷贝，不观察外部实例）。
 * - 因此 AppToast 直接引用 toastState 单例，不接收 @Param。
 */

import { toastState, ToastState } from '../utils/ToastUtil';

@ComponentV2
export struct AppToast {
  /** 直接引用 @ObservedV2 单例，@Trace 属性变化会被 @ComponentV2 感知 */
  toast: ToastState = toastState;

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.toast.visible) {
        Text(this.toast.message)
          .fontSize($r('app.float.toast_font_size'))
          .fontColor($r('app.color.app_toast_text_color'))
          .backgroundColor($r('app.color.app_toast_background'))
          .borderRadius($r('app.float.toast_corner_radius'))
          .padding({
            left: $r('app.float.toast_padding_horizontal'),
            right: $r('app.float.toast_padding_horizontal'),
            top: $r('app.float.toast_padding_vertical'),
            bottom: $r('app.float.toast_padding_vertical')
          })
          .constraintSize({ maxWidth: $r('app.float.toast_max_width') })
          .textAlign(TextAlign.Center)
          .margin({ bottom: $r('app.float.toast_bottom_offset') });
      }
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent);
  }
}
