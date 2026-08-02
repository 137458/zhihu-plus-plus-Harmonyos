/**
 * EntryAbility - 应用主 Ability
 *
 * 生命周期与状态清理规则（第 1 批建立）：
 *
 * | 回调               | 职责                                                                 |
 * | ------------------ | ------------------------------------------------------------------- |
 * | onCreate           | 颜色模式策略；PreferencesUtil 初始化                                |
 * | onWindowStageCreate| 加载主壳 pages/Index；首帧提交后触发会话恢复（restoreSession）        |
 * | onWindowStageDestroy| 取消挂起的 Toast 定时器；释放窗口作用域内的资源                       |
 * | onForeground       | 恢复刷新类定时器、网络监听（后续批次）                                |
 * | onBackground       | 暂停非必要后台请求；不在此释放 UI 资源                                |
 * | onMemoryLevel      | 内存告警时清理非必要缓存（图片缓存、列表缓存），CRITICAL 时清理全部    |
 *
 * 不在此处：
 * - 不直接调用 ArkUI 组件 API（窗口级操作通过 windowStage 完成）
 * - 会话恢复通过 SessionViewModel 异步触发，不阻塞首帧
 */

import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { ToastUtil } from '../utils/ToastUtil';
import { PreferencesUtil } from '../utils/PreferencesUtil';
import { SessionViewModel } from '../viewmodel/SessionViewModel';

const DOMAIN: number = 0x0000;
const TAG: string = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 颜色模式策略：跟随系统，不强制浅色或深色
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      // JSON.stringify 对 Error 对象返回 '{}'（属性不可枚举），改用 message + stack
      const errMsg = err instanceof Error
        ? `${err.message} | stack: ${err.stack ?? ''}`
        : String(err);
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode. Cause: %{public}s', errMsg);
    }

    // 注入 applicationContext 给 PreferencesUtil，供搜索历史等轻量持久化使用
    PreferencesUtil.init(this.context.getApplicationContext());

    hilog.info(DOMAIN, TAG, 'onCreate: ability created');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onDestroy: ability destroyed');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageCreate: loading pages/Index');

    // 沉浸式全屏布局：应用窗口延伸到状态栏/导航栏下方
    // 配合各页面 expandSafeArea([SafeAreaType.SYSTEM]) 实现内容穿透系统栏
    // 消除顶部/底部的"白色边框遮罩"现象
    const mainWindow = windowStage.getMainWindowSync();
    mainWindow.setWindowLayoutFullScreen(true).then(() => {
      hilog.info(DOMAIN, TAG, 'setWindowLayoutFullScreen succeeded');
    }).catch((e: object) => {
      const errMsg = e instanceof Error ? e.message : String(e);
      hilog.error(DOMAIN, TAG, 'setWindowLayoutFullScreen failed: %{public}s', errMsg);
    });

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        // Error 对象属性不可枚举，JSON.stringify 返回 '{}'，改用 message/code
        hilog.error(DOMAIN, TAG, 'Failed to load content. code=%{public}d msg=%{public}s',
          err.code, err.message ?? String(err));
        return;
      }
      // 首帧已提交。触发会话恢复（AssetStore 加载 + 网络验证），不阻塞首帧。
      // SessionViewModel.restoreSession 内部处理加载/验证/刷新/清除全流程，
      // 恢复完成后通过 @Trace isLoggedIn/profile 通知 UI 刷新。
      SessionViewModel.getInstance().restoreSession().then(() => {
        hilog.info(DOMAIN, TAG, 'Session restore completed. isLoggedIn=%{public}s',
          String(SessionViewModel.getInstance().isLoggedIn));
      }).catch((e: object) => {
        const errMsg = e instanceof Error ? e.message : String(e);
        hilog.error(DOMAIN, TAG, 'Session restore failed: %{public}s', errMsg);
      });
      hilog.info(DOMAIN, TAG, 'Succeeded in loading content. First frame committed.');
    });
  }

  onWindowStageDestroy(): void {
    // 窗口销毁前取消挂起的 Toast 定时器，避免在已销毁窗口上尝试刷新
    ToastUtil.cancelPendingTimer();
    hilog.info(DOMAIN, TAG, 'onWindowStageDestroy: toast timer canceled');
  }

  onForeground(): void {
    // 后续批次接入：网络监听恢复、刷新类定时器恢复
    hilog.info(DOMAIN, TAG, 'onForeground');
  }

  onBackground(): void {
    // 不在此释放 UI 资源；窗口销毁才释放
    hilog.info(DOMAIN, TAG, 'onBackground');
  }

  /**
   * 内存告警回调。
   *
   * - MEMORY_LEVEL_LOW：清理非必要缓存，保留当前页面数据
   * - MEMORY_LEVEL_CRITICAL：清理所有可重建的缓存，仅保留必要状态
   *
   * 后续批次接入图片缓存、列表缓存后在此统一清理。
   */
  onMemoryLevel(level: AbilityConstant.MemoryLevel): void {
    if (level === AbilityConstant.MemoryLevel.MEMORY_LEVEL_CRITICAL) {
      hilog.info(DOMAIN, TAG, 'onMemoryLevel: CRITICAL - releasing all non-essential caches');
      ToastUtil.cancelPendingTimer();
    } else if (level === AbilityConstant.MemoryLevel.MEMORY_LEVEL_LOW) {
      hilog.info(DOMAIN, TAG, 'onMemoryLevel: LOW - trimming caches');
    }
  }
}
