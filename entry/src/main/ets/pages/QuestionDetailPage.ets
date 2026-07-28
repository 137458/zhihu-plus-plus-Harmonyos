/**
 * 问题详情页（占位实现）
 *
 * 通过 NavPathStack.pushPath({ name: RouteName.QUESTION_DETAIL, param: ... }) 进入。
 * 后续批次将解析 QuestionDetailParams 并加载问题内容、回答列表。
 */

import { PlaceholderPage } from '../components/PlaceholderPage';
import { NavPathStack } from '@kit.ArkUI';

@ComponentV2
export struct QuestionDetailPage {
  @Local navPathStack: NavPathStack | undefined = undefined;

  build() {
    NavDestination() {
      PlaceholderPage({
        title: $r('app.string.page_question_detail_title'),
        pageId: 'page_question_detail_title',
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
