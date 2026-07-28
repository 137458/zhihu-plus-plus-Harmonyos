/**
 * 个人主页（占位实现）
 *
 * 作为 TabBar 的第三个 Tab，不需要返回按钮。
 * 后续批次将根据登录状态展示个人信息、关注/收藏/历史入口等。
 */

import { PlaceholderPage } from '../components/PlaceholderPage';
import { NavPathStack } from '@kit.ArkUI';

@ComponentV2
export struct ProfilePage {
  @Local navPathStack: NavPathStack | undefined = undefined;

  build() {
    NavDestination() {
      PlaceholderPage({
        title: $r('app.string.page_profile_title'),
        pageId: 'page_profile_title'
      });
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      this.navPathStack = ctx.pathStack;
    });
  }
}
