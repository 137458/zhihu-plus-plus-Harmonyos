/**
 * 文章详情页（占位实现）
 *
 * 通过 NavPathStack.pushPath({ name: RouteName.ARTICLE_DETAIL, param: ... }) 进入。
 */

import { PlaceholderPage } from '../components/PlaceholderPage';

@ComponentV2
export struct ArticleDetailPage {
  @Local navPathStack: NavPathStack | undefined = undefined;

  build() {
    NavDestination() {
      PlaceholderPage({
        title: $r('app.string.page_article_detail_title'),
        pageId: 'page_article_detail_title',
        onBack: () => {
          this.navPathStack?.pop();
        }
      });
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      this.navPathStack = ctx.pathStack;
    });
  }
}
