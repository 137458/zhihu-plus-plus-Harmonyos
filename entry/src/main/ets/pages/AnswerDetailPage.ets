/**
 * 回答详情页（占位实现）
 *
 * 通过 NavPathStack.pushPath({ name: RouteName.ANSWER_DETAIL, param: ... }) 进入。
 */

import { PlaceholderPage } from '../components/PlaceholderPage';

@ComponentV2
export struct AnswerDetailPage {
  @Local navPathStack: NavPathStack | undefined = undefined;

  build() {
    NavDestination() {
      PlaceholderPage({
        title: $r('app.string.page_answer_detail_title'),
        pageId: 'page_answer_detail_title',
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
