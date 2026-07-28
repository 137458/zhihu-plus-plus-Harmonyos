/**
 * 主壳 UI 测试 - HDS 版
 *
 * 验证：
 * 1. 冷启动后首页根容器可见（page_home_title）
 * 2. 点击 tabBar '我的' 后 page_profile_title 容器可见
 * 3. 点击 HomePage 测试入口（home_test_push）→ 进入 QuestionDetailPage（page_question_detail_title）→ 点击返回（back）→ 回到首页
 * 4. 点击 tabBar '搜索' 后 page_search_title 容器可见
 * 5. 搜索页显示输入框（通过 placeholder 文字"搜索知乎内容"匹配）
 *
 * 注意：
 * - UiTest 只能在真机或模拟器上运行，Previewer 不支持
 * - HDS HdsTabs 的 tabBar 简单对象形式（{icon, text}）不支持 id 字段，
 *   tabBar 项通过 ON.text 匹配文字定位（HDS 默认 tabBar 文字始终可见）
 * - titleBar 菜单/返回按钮通过 HdsNavigationIconOptions.componentId 暴露给 UiTest
 *   - 菜单按钮 componentId: 'home_test_push'
 *   - 返回按钮 componentId: 'back'
 * - 每个 it 内部创建新的 Driver（避免状态污染）
 * - 操作后通过 setTimeout 等待 UI 渲染
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
     * 冷启动后应显示首页根容器（HdsNavigation id=page_home_title）
     */
    it('coldStartShowsHomePage', 0, async () => {
      try {
        const driver: Driver = Driver.create();
        const home = await driver.findComponent(ON.id('page_home_title'));
        hilog.info(DOMAIN, TAG, 'coldStartShowsHomePage: home=%{public}s', `${home !== null}`);
        expect(home !== null).assertTrue();
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'coldStartShowsHomePage failed: %{public}s', String(e));
        expect(false).assertTrue();
      }
    });

    /**
     * 点击 tabBar 的 '我的' 文字后应切换到个人页（HDS tabBar 不支持 id，
     * 通过 ON.text 匹配文字；冷启动时在 HomePage，ProfilePage 未渲染，
     * 所以 '我的' 文字仅在 tabBar 上出现一次，可精确匹配）
     */
    it('navigateToProfileTab', 0, async () => {
      try {
        const driver: Driver = Driver.create();

        // 点击 tabBar 的"我的"
        const profileTab = await driver.findComponent(ON.text('我的'));
        hilog.info(DOMAIN, TAG, 'navigateToProfileTab: profileTab=%{public}s',
          `${profileTab !== null}`);
        expect(profileTab !== null).assertTrue();
        if (profileTab === null) {
          hilog.error(DOMAIN, TAG, 'navigateToProfileTab: tabBar "我的" not found, abort');
          return;
        }
        await profileTab.click();

        // 等待 Tab 切换与 ProfilePage 渲染
        await new Promise<void>((resolve: () => void) => setTimeout(resolve, 800));

        // 验证个人页根容器可见
        const profileTitle = await driver.findComponent(ON.id('page_profile_title'));
        hilog.info(DOMAIN, TAG, 'navigateToProfileTab: profileTitle=%{public}s',
          `${profileTitle !== null}`);
        expect(profileTitle !== null).assertTrue();
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'navigateToProfileTab failed: %{public}s', String(e));
        expect(false).assertTrue();
      }
    });

    /**
     * 验证 HomePage titleBar 测试入口按钮可见（componentId=home_test_push）
     * 仅当 currentTab === 0（HomePage 渲染）时该按钮存在
     */
    it('homePageShowsTestEntryButton', 0, async () => {
      try {
        const driver: Driver = Driver.create();

        // 确保当前在首页（点击 tabBar '首页'，若已是首页则为 no-op）
        const homeTab = await driver.findComponent(ON.text('首页'));
        expect(homeTab !== null).assertTrue();
        if (homeTab === null) {
          hilog.error(DOMAIN, TAG, 'homePageShowsTestEntryButton: tabBar "首页" not found, abort');
          return;
        }
        await homeTab.click();
        await new Promise<void>((resolve: () => void) => setTimeout(resolve, 500));

        const testBtn = await driver.findComponent(ON.id('home_test_push'));
        hilog.info(DOMAIN, TAG, 'homePageShowsTestEntryButton: testBtn=%{public}s',
          `${testBtn !== null}`);
        expect(testBtn !== null).assertTrue();
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'homePageShowsTestEntryButton failed: %{public}s', String(e));
        expect(false).assertTrue();
      }
    });

    /**
     * 完整路由测试：HomePage → 点击测试入口按钮 push 到 QuestionDetailPage →
     * 点击返回按钮 → 回到 HomePage
     *
     * 验证项：
     * 1. 点击 home_test_push 后 page_question_detail_title 可见
     * 2. 点击返回按钮（componentId=back）后回到 page_home_title
     */
    it('pushQuestionDetailAndBack', 0, async () => {
      try {
        const driver: Driver = Driver.create();

        // 前置：确保当前在 HomePage
        const homeTab = await driver.findComponent(ON.text('首页'));
        expect(homeTab !== null).assertTrue();
        if (homeTab === null) {
          hilog.error(DOMAIN, TAG, 'pushQuestionDetailAndBack: tabBar "首页" not found, abort');
          return;
        }
        await homeTab.click();
        await new Promise<void>((resolve: () => void) => setTimeout(resolve, 500));

        // 1. 点击测试入口按钮触发 pushPathByName(QUESTION_DETAIL)
        const testBtn = await driver.findComponent(ON.id('home_test_push'));
        expect(testBtn !== null).assertTrue();
        if (testBtn === null) {
          hilog.error(DOMAIN, TAG, 'pushQuestionDetailAndBack: test button not found, abort');
          return;
        }
        await testBtn.click();
        // 等待 NavDestination push 动画与 QuestionDetailPage 渲染
        await new Promise<void>((resolve: () => void) => setTimeout(resolve, 1000));

        // 2. 验证 QuestionDetailPage 根容器可见
        const questionPage = await driver.findComponent(ON.id('page_question_detail_title'));
        hilog.info(DOMAIN, TAG, 'pushQuestionDetailAndBack: questionPage=%{public}s',
          `${questionPage !== null}`);
        expect(questionPage !== null).assertTrue();

        // 3. 点击返回按钮（PlaceholderPage backIcon 的 componentId='back'）
        const backBtn = await driver.findComponent(ON.id('back'));
        hilog.info(DOMAIN, TAG, 'pushQuestionDetailAndBack: backBtn=%{public}s',
          `${backBtn !== null}`);
        expect(backBtn !== null).assertTrue();
        if (backBtn === null) {
          hilog.error(DOMAIN, TAG, 'pushQuestionDetailAndBack: back button not found, abort');
          return;
        }
        await backBtn.click();
        // 等待 pop 动画完成
        await new Promise<void>((resolve: () => void) => setTimeout(resolve, 800));

        // 4. 验证回到 HomePage（page_home_title 重新可见）
        const homeAgain = await driver.findComponent(ON.id('page_home_title'));
        hilog.info(DOMAIN, TAG, 'pushQuestionDetailAndBack: homeAgain=%{public}s',
          `${homeAgain !== null}`);
        expect(homeAgain !== null).assertTrue();
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'pushQuestionDetailAndBack failed: %{public}s', String(e));
        expect(false).assertTrue();
      }
    });

    /**
     * 点击 tabBar 的 '搜索' 文字后应切换到搜索页（HdsNavigation id=page_search_title）
     *
     * 验证项：
     * - tabBar '搜索' 文字可点击
     * - 切换后 page_search_title 根容器可见
     */
    it('navigateToSearchTab', 0, async () => {
      try {
        const driver: Driver = Driver.create();

        // 点击 tabBar 的"搜索"
        const searchTab = await driver.findComponent(ON.text('搜索'));
        hilog.info(DOMAIN, TAG, 'navigateToSearchTab: searchTab=%{public}s',
          `${searchTab !== null}`);
        expect(searchTab !== null).assertTrue();
        if (searchTab === null) {
          hilog.error(DOMAIN, TAG, 'navigateToSearchTab: tabBar "搜索" not found, abort');
          return;
        }
        await searchTab.click();

        // 等待 Tab 切换与 SearchPage 渲染
        await new Promise<void>((resolve: () => void) => setTimeout(resolve, 800));

        // 验证搜索页根容器可见
        const searchPage = await driver.findComponent(ON.id('page_search_title'));
        hilog.info(DOMAIN, TAG, 'navigateToSearchTab: searchPage=%{public}s',
          `${searchPage !== null}`);
        expect(searchPage !== null).assertTrue();
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'navigateToSearchTab failed: %{public}s', String(e));
        expect(false).assertTrue();
      }
    });

    /**
     * 搜索页应显示输入框（通过 placeholder 文字"搜索知乎内容"匹配）
     *
     * 前置：先切换到搜索 Tab
     */
    it('searchPageShowsInput', 0, async () => {
      try {
        const driver: Driver = Driver.create();

        // 确保在搜索页
        const searchTab = await driver.findComponent(ON.text('搜索'));
        expect(searchTab !== null).assertTrue();
        if (searchTab === null) {
          hilog.error(DOMAIN, TAG, 'searchPageShowsInput: tabBar "搜索" not found, abort');
          return;
        }
        await searchTab.click();
        await new Promise<void>((resolve: () => void) => setTimeout(resolve, 800));

        // 通过 placeholder 文字定位 TextInput
        const input = await driver.findComponent(ON.text('搜索知乎内容'));
        hilog.info(DOMAIN, TAG, 'searchPageShowsInput: input=%{public}s',
          `${input !== null}`);
        expect(input !== null).assertTrue();
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'searchPageShowsInput failed: %{public}s', String(e));
        expect(false).assertTrue();
      }
    });
  });
}
