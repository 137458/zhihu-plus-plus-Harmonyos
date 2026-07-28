/**
 * 登录页（占位实现）
 *
 * 通过 NavPathStack.pushPath({ name: RouteName.LOGIN, param: ... }) 进入。
 * 后续批次将实现登录表单、华为账号一键登录等。
 */

import { PlaceholderPage } from '../components/PlaceholderPage';

@ComponentV2
export struct LoginPage {
  @Local navPathStack: NavPathStack | undefined = undefined;

  build() {
    NavDestination() {
      PlaceholderPage({
        title: $r('app.string.page_login_title'),
        pageId: 'page_login_title',
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
