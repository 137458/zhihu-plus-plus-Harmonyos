/**
 * 设置页（占位实现）
 *
 * 通过 NavPathStack.pushPath({ name: RouteName.SETTINGS }) 进入。
 */

import { PlaceholderPage } from '../components/PlaceholderPage';

@ComponentV2
export struct SettingsPage {
  @Local navPathStack: NavPathStack | undefined = undefined;

  build() {
    NavDestination() {
      PlaceholderPage({
        title: $r('app.string.page_settings_title'),
        pageId: 'page_settings_title',
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
