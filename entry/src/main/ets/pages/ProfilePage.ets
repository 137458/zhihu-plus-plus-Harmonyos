/**
 * 个人主页（占位实现）
 *
 * 作为 TabBar 的第三个 Tab，直接渲染内容（不包 NavDestination）。
 * 后续批次将根据登录状态展示个人信息、关注/收藏/历史入口等。
 */

import { PlaceholderPage } from '../components/PlaceholderPage';

@ComponentV2
export struct ProfilePage {
  build() {
    PlaceholderPage({
      title: $r('app.string.page_profile_title'),
      pageId: 'page_profile_title'
    });
  }
}
