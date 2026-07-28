/**
 * 首页（占位实现）
 *
 * 作为 TabBar 的默认页，直接渲染内容（不包 NavDestination）。
 * NavDestination 只用于通过 NavPathStack push 进入的目标页。
 * 后续批次将实现首页推荐信息流。
 *
 * 测试入口（占位期间，仅 debug 构建可见）：
 * - titleBar 右上角齿轮按钮（componentId: home_test_push），用于触发路由跳转测试
 * - 由外层 Index.ets 通过 onPushQuestion callback 注入具体的 pushPathByName 调用
 * - 通过 SHOW_TEST_ENTRY 控制，发布前改为 false
 * - 后续批次接入真实首页功能后将移除该测试入口
 */

import { PlaceholderPage } from '../components/PlaceholderPage';

/**
 * 测试入口可见性开关。
 *
 * 占位期间设为 true 以便 UiTest 验证路由跳转。
 * 发布前改为 false 隐藏测试入口，避免泄漏到生产。
 */
const SHOW_TEST_ENTRY: boolean = true;

@ComponentV2
export struct HomePage {
  /**
   * 测试入口回调：点击右上角齿轮按钮时触发。
   * 由 Index.ets 注入 navPathStack.pushPathByName 调用。
   * undefined 时齿轮按钮不显示。
   */
  @Param onPushQuestion: (() => void) | undefined = undefined;

  build() {
    PlaceholderPage({
      title: $r('app.string.page_home_title'),
      pageId: 'page_home_title',
      menuIcon: SHOW_TEST_ENTRY ? $r('sys.symbol.chevron_right') : undefined,
      menuLabel: '测试入口',
      menuId: 'home_test_push',
      onMenuClick: this.onPushQuestion
    });
  }
}
