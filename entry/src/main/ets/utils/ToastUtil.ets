/**
 * Toast 工具类
 *
 * 全局 Toast 控制器：维护一个 @ObservedV2 单例 toastState，主壳中的 AppToast
 * 组件直接持有该单例引用以感知变化。ToastUtil.show() 设置 message + visible=true，
 * 并在 durationMs 后将 visible 置回 false。
 *
 * 注意：
 * - ArkTS 严格语法，不使用 any/unknown
 * - @ObservedV2 与 @Trace 必须成对使用，仅 @Trace 属性参与 UI 刷新
 * - 重复调用 show() 会取消上一次的定时器，避免 Toast 闪烁
 * - setTimeout 在 OpenHarmony 全局定义返回 number，不需要 as 强转
 */

/** Toast 全局状态：由 ToastUtil 写入，由 AppToast 读取 */
@ObservedV2
export class ToastState {
  /** 是否显示 */
  @Trace visible: boolean = false;
  /** Toast 文本（string 或 Resource） */
  @Trace message: string | Resource = '';
}

/** 全局单例：主壳的 AppToast 直接绑定此实例 */
export const toastState: ToastState = new ToastState();

/** 当前挂起的定时器 id；-1 表示无定时器 */
let pendingTimerId: number = -1;

/**
 * Toast 工具方法
 *
 * 用法：ToastUtil.show('已保存'); 或 ToastUtil.show($r('app.string.xxx'));
 */
export class ToastUtil {
  /**
   * 显示一条 Toast。
   *
   * @param message - 文本或资源
   * @param durationMs - 显示时长，默认 2000ms
   */
  static show(message: string | Resource, durationMs: number = 2000): void {
    // 取消上一次挂起的定时器
    if (pendingTimerId !== -1) {
      clearTimeout(pendingTimerId);
      pendingTimerId = -1;
    }

    toastState.message = message;
    toastState.visible = true;

    pendingTimerId = setTimeout(() => {
      toastState.visible = false;
      pendingTimerId = -1;
    }, durationMs);
  }

  /**
   * 取消挂起的 Toast 定时器并隐藏 Toast。
   *
   * 用于 Ability 退出 / 窗口销毁 / 内存告警时清理资源，
   * 避免已销毁窗口上的 Toast 仍尝试刷新。
   */
  static cancelPendingTimer(): void {
    if (pendingTimerId !== -1) {
      clearTimeout(pendingTimerId);
      pendingTimerId = -1;
    }
    toastState.visible = false;
  }
}
