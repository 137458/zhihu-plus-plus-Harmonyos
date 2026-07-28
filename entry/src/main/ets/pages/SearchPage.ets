/**
 * 搜索页（占位实现）
 *
 * 作为 TabBar 的第二个 Tab，直接渲染内容（不包 NavDestination）。
 * 后续批次将实现搜索输入、热搜、历史等。
 */

import { PlaceholderPage } from '../components/PlaceholderPage';

@ComponentV2
export struct SearchPage {
  build() {
    PlaceholderPage({
      title: $r('app.string.page_search_title'),
      pageId: 'page_search_title'
    });
  }
}
