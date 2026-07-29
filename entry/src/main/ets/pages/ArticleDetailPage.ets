/**
 * 文章详情页（占位实现）
 *
 * 通过 NavPathStack.pushPath({ name: RouteName.ARTICLE_DETAIL, param: ... }) 进入。
 *
 * 架构与 QuestionDetailPage 一致：build() 直接返回 HdsNavDestination，
 * titleBar 配置引用 DETAIL_TITLE_BAR_STYLE 常量。
 */

import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { EmptyView } from '../components/EmptyView';
import { DETAIL_TITLE_BAR_STYLE, DETAIL_TITLE_BAR_PADDING } from '../components/PlaceholderPage';

@ComponentV2
export struct ArticleDetailPage {
  /** 路由栈，onReady 时从 NavDestinationContext 获取 */
  @Local navPathStack: NavPathStack | undefined = undefined;

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
        title: { mainTitle: $r('app.string.page_article_detail_title') },
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
    });
  }
}
