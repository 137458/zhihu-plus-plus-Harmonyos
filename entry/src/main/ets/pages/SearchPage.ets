/**
 * 搜索页（占位实现）
 *
 * 作为 TabBar 的第二个 Tab。后续批次将实现搜索输入、热搜、历史等。
 */

import { PlaceholderPage } from '../components/PlaceholderPage';
import { NavPathStack } from '@kit.ArkUI';

@ComponentV2
export struct SearchPage {
  @Local navPathStack: NavPathStack | undefined = undefined;

  build() {
    NavDestination() {
      PlaceholderPage({
        title: $r('app.string.page_search_title'),
        pageId: 'page_search_title'
      });
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      this.navPathStack = ctx.pathStack;
    });
  }
}
