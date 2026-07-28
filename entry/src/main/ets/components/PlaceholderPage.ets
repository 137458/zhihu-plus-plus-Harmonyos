/**
 * 占位页面组件
 *
 * 用于本批次所有占位路由的统一外观：顶部 AppTitleBar + 中间 EmptyView。
 * 通过 title、onBack、pageId 参数化，避免每个占位页面重复写样板代码。
 *
 * pageId 用于 UiTest 通过 ON.id 查找页面根容器。
 */

import { AppTitleBar } from './AppTitleBar';
import { EmptyView } from './EmptyView';

@ComponentV2
export struct PlaceholderPage {
  /** 页面标题，用于 AppTitleBar */
  @Param title: string | Resource = '';
  /** 可选返回回调，不传则不显示返回按钮 */
  @Param onBack: (() => void) | undefined = undefined;
  /** 页面根容器 id，用于 UiTest 查找；为空时不设置 id */
  @Param pageId: string = '';

  build() {
    Column() {
      AppTitleBar({
        title: this.title,
        onBack: this.onBack
      });

      EmptyView({
        title: $r('app.string.placeholder_page'),
        subtitle: $r('app.string.placeholder_page_subtitle')
      })
        .layoutWeight(1);
    }
    .id(this.pageId)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'));
  }
}
