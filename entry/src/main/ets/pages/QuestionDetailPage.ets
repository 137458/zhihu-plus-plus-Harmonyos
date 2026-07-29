/**
 * 问题详情页（占位实现）
 *
 * 通过 NavPathStack.pushPath({ name: RouteName.QUESTION_DETAIL, param: ... }) 进入。
 * 后续批次将解析 QuestionDetailParams 并加载问题内容、回答列表。
 *
 * 架构（基于 HDS 官方推荐）：
 * - build() 直接返回 HdsNavDestination（不再包 NavDestination > PlaceholderPage > HdsNavigation）
 * - 原因：HdsNavigation navDestination builder 约束要求"HdsNavDestination 外只允许
 *   一层自定义组件，且自定义组件不允许设置属性和事件，否则仅显示空白"
 * - titleBar 配置引用 DETAIL_TITLE_BAR_STYLE 常量（4 字段模式三混合写法）
 * - 内容区：EmptyView 占位
 *
 * 参数解析：
 * - onReady 回调获取 NavDestinationContext
 * - 从 ctx.pathInfo.param 读取 QuestionDetailParams
 * - questionId / previewTitle 暂存到 @Local，第 2 批启用真实加载
 */

import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { EmptyView } from '../components/EmptyView';
import { DETAIL_TITLE_BAR_STYLE, DETAIL_TITLE_BAR_PADDING } from '../components/PlaceholderPage';
import { QuestionDetailParams } from '../router/AppRouter';

@ComponentV2
export struct QuestionDetailPage {
  /** 路由栈，onReady 时从 NavDestinationContext 获取 */
  @Local navPathStack: NavPathStack | undefined = undefined;
  /** 从路由参数读取的问题 ID（第 2 批启用真实加载） */
  @Local questionId: string = '';
  /** 从路由参数读取的预览标题（第 2 批启用真实加载） */
  @Local previewTitle: string = '';

  build() {
    HdsNavDestination() {
      Column() {
        EmptyView({
          title: $r('app.string.placeholder_page'),
          subtitle: $r('app.string.placeholder_page_subtitle')
        })
          .layoutWeight(1);
      }
      .width('100%')
      .height('100%');
    }
    .titleBar({
      padding: DETAIL_TITLE_BAR_PADDING,
      style: DETAIL_TITLE_BAR_STYLE,
      content: {
        title: { mainTitle: $r('app.string.page_question_detail_title') },
        backIcon: {
          label: 'back',
          icon: $r('sys.symbol.chevron_left'),
          isEnabled: true,
          componentId: 'back',
          action: () => {
            this.navPathStack?.pop();
          }
        }
      }
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onReady((ctx: NavDestinationContext) => {
      this.navPathStack = ctx.pathStack;
      // 预留参数读取，第 2 批启用真实加载
      const params = ctx.pathInfo.param as QuestionDetailParams;
      if (params !== null && params !== undefined) {
        this.questionId = params.questionId;
        this.previewTitle = params.previewTitle ?? '';
      }
    });
  }
}
