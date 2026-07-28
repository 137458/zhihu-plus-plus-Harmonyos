/**
 * 首页（占位实现）
 *
 * 作为 TabBar 的默认页，不需要返回按钮。
 * 通过 NavDestination 包裹，在 onReady 中接收 navPathStack 以便后续批次
 * 实现跳转详情等交互。
 */

import { PlaceholderPage } from '../components/PlaceholderPage';
import { NavPathStack } from '@kit.ArkUI';

@ComponentV2
export struct HomePage {
  @Local navPathStack: NavPathStack | undefined = undefined;

  build() {
    NavDestination() {
      PlaceholderPage({
        title: $r('app.string.page_home_title'),
        pageId: 'page_home_title'
      });
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      this.navPathStack = ctx.pathStack;
    });
  }
}
