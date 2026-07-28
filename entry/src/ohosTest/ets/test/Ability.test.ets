/**
 * 主壳 UI 测试
 *
 * 验证：
 * 1. 冷启动后 TabBar 的 'tab_home' 可见
 * 2. 点击 'tab_profile' 后能找到 'page_profile_title' 容器
 *
 * 注意：
 * - UiTest 只能在真机或模拟器上运行，Previewer 不支持
 * - 每个 it 内部创建新的 Driver（避免状态污染）
 * - 操作后需要 setTimeout 等待 UI 渲染
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { Driver, ON } from '@ohos.UiTest';
import AbilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';

const DOMAIN: number = 0x0000;
const TAG: string = 'HarmonyShellTest';
const BUNDLE_NAME: string = 'com.isczjk.zhihuplus';
const ABILITY_NAME: string = 'EntryAbility';

export default function abilityTest() {
  describe('HarmonyShellTest', () => {
    // 冷启动前先通过 delegator 启动 EntryAbility，并等待首帧渲染
    beforeAll(async () => {
      const delegator = AbilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({
        bundleName: BUNDLE_NAME,
        abilityName: ABILITY_NAME
      });
      // 等待主壳与首页渲染完成
      await new Promise<void>((resolve: () => void) => setTimeout(resolve, 2000));
    });

    beforeEach(() => {});
    afterEach(() => {});
    afterAll(() => {});

    /**
     * 冷启动后应显示首页 Tab
     */
    it('coldStartShowsHomeTab', 0, async () => {
      const driver: Driver = Driver.create();
      const home = await driver.findComponent(ON.id('tab_home'));
      hilog.info(DOMAIN, TAG, 'coldStartShowsHomeTab: home=%{public}s', `${home !== null}`);
      expect(home !== null).assertTrue();
    });

    /**
     * 点击 'tab_profile' 后应切换到个人页，page_profile_title 容器可见
     */
    it('navigateToSettingsAndBack', 0, async () => {
      const driver: Driver = Driver.create();

      // 点击"我的" Tab
      const profileTab = await driver.findComponent(ON.id('tab_profile'));
      expect(profileTab !== null).assertTrue();
      await profileTab.click();

      // 等待 Tab 切换与目标页渲染
      await new Promise<void>((resolve: () => void) => setTimeout(resolve, 800));

      // 验证个人页根容器可见
      const profileTitle = await driver.findComponent(ON.id('page_profile_title'));
      hilog.info(DOMAIN, TAG, 'navigateToSettingsAndBack: profileTitle=%{public}s',
        `${profileTitle !== null}`);
      expect(profileTitle !== null).assertTrue();
    });
  });
}
