/**
 * EntryAbility - 应用主 Ability
 *
 * 生命周期与状态清理规则（第 1 批建立）：
 *
 * | 回调               | 职责                                                                 |
 * | ------------------ | ------------------------------------------------------------------- |
 * | onCreate           | 颜色模式策略；后续批次接入 Push token、网络客户端预热                 |
 * | onWindowStageCreate| 加载主壳 pages/Index；首帧提交后才允许发起网络请求                     |
 * | onWindowStageDestroy| 取消挂起的 Toast 定时器；释放窗口作用域内的资源                       |
 * | onForeground       | 恢复刷新类定时器、网络监听（后续批次）                                |
 * | onBackground       | 暂停非必要后台请求；不在此释放 UI 资源                                |
 * | onMemoryLevel      | 内存告警时清理非必要缓存（图片缓存、列表缓存），CRITICAL 时清理全部    |
 *
 * 不在此处：
 * - 不读写 Token / Cookie（由 storage/ 层在第 4 批接入）
 * - 不持久化业务状态（由 PersistenceV2 在第 6 批接入）
 * - 不直接调用 ArkUI 组件 API（窗口级操作通过 windowStage 完成）
 */

import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { ToastUtil } from '../utils/ToastUtil';

const DOMAIN: number = 0x0000;
const TAG: string = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 颜色模式策略：跟随系统，不强制浅色或深色
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, TAG, 'onCreate: ability created');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onDestroy: ability destroyed');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageCreate: loading pages/Index');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      // 首帧已提交。后续批次的网络预热、Push token 注册等在此之后触发，
      // 避免冷启动阶段的网络争抢拖慢首帧。
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
