/**
 * 断点工具
 *
 * 用于判断当前窗口宽度对应的设备尺寸档位。
 * 断点值参考 HarmonyOS 设计规范：
 *   sm: 0–600vp（手机竖屏）
 *   md: 600–840vp（手机横屏 / 小平板）
 *   lg: 840vp+（平板 / 双栏）
 *
 * 资源中的断点阈值定义在 float.json：
 *   - breakpoint_sm_max = 600vp
 *   - breakpoint_md_max = 840vp
 *
 * 当前实现只暴露枚举和工具函数，具体响应式布局由页面按档位决定。
 */

/** 设备尺寸档位 */
export enum Breakpoint {
  /** 小屏（手机竖屏） */
  SM = 'sm',
  /** 中屏（手机横屏 / 小平板） */
  MD = 'md',
  /** 大屏（平板 / 双栏） */
  LG = 'lg'
}

/** 当前窗口宽度对应的档位 */
export class BreakpointUtil {
  /**
   * 根据窗口宽度（vp）返回断点档位。
   *
   * @param widthVp - 窗口宽度（vp）。调用方通常通过 window.getWindowProperties().windowProperties.cpWidth
   *                  或组件 onAreaChange 获取。
   * @returns 断点档位
   */
  static resolve(widthVp: number): Breakpoint {
    if (widthVp < 600) {
      return Breakpoint.SM;
    }
    if (widthVp < 840) {
      return Breakpoint.MD;
    }
    return Breakpoint.LG;
  }

  /** 是否需要双栏布局（仅 lg 档位启用） */
  static shouldUseTwoPane(widthVp: number): boolean {
    return this.resolve(widthVp) === Breakpoint.LG;
  }

  /** 是否为大屏设备（含 md 和 lg） */
  static isLargeScreen(widthVp: number): boolean {
    const bp = this.resolve(widthVp);
    return bp === Breakpoint.MD || bp === Breakpoint.LG;
  }
}
