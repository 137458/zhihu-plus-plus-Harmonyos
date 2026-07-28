/**
 * 问题详情页（占位实现）
 *
 * 通过 NavPathStack.pushPath({ name: RouteName.QUESTION_DETAIL, param: ... }) 进入。
 * 后续批次将解析 QuestionDetailParams 并加载问题内容、回答列表。
 */

import { PlaceholderPage } from '../components/PlaceholderPage';
import { QuestionDetailParams } from '../router/AppRouter';

@ComponentV2
export struct QuestionDetailPage {
  @Local navPathStack: NavPathStack | undefined = undefined;
  /** 从路由参数读取的问题 ID（第2批启用真实加载） */
  @Local questionId: string = '';
  /** 从路由参数读取的预览标题（第2批启用真实加载） */
  @Local previewTitle: string = '';

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
      // 预留参数读取，第2批启用真实加载
      const params = ctx.pathInfo.param as QuestionDetailParams;
      if (params !== null && params !== undefined) {
        this.questionId = params.questionId ?? '';
        this.previewTitle = params.previewTitle ?? '';
      }
    });
  }
}
