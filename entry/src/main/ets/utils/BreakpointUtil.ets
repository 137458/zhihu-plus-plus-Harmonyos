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
 *
 * 注意：工具类无法使用 $r() 引用资源，故断点阈值用 const 常量，
 * 与 float.json 的 breakpoint_sm_max / breakpoint_md_max 保持一致，调整时同步修改。
 */

/** 小屏断点上限（vp），与 float.json 的 breakpoint_sm_max 一致 */
const BP_SM_MAX_VP: number = 600;
/** 中屏断点上限（vp），与 float.json 的 breakpoint_md_max 一致 */
const BP_MD_MAX_VP: number = 840;

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
    if (widthVp < BP_SM_MAX_VP) {
      return Breakpoint.SM;
    }
    if (widthVp < BP_MD_MAX_VP) {
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
    const bp: Breakpoint = this.resolve(widthVp);
    return bp === Breakpoint.MD || bp === Breakpoint.LG;
  }
}
