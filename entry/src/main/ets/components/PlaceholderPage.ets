/**
 * 占位页面组件 - HDS 版
 *
 * 用于本批次所有占位路由的统一外观：HDS 顶部标题栏（带滚动渐变模糊）+ 中间 EmptyView。
 *
 * 实现方式：
 * - 使用 HdsNavigation 作为页面级根容器，提供 HDS titleBar + ScrollEffectType.COMMON_BLUR
 * - 传入空 NavPathStack，HdsNavigation 仅作为 UI 容器，不参与路由
 * - 路由由外层 Index.ets 的 HdsNavigation(navPathStack) + NavDestination 管理
 * - titleMode = MINI，符合详情页标题栏规范
 * - 渐变模糊立即生效（blurEffectiveEndOffset = 0vp），即使内容不滚动也有模糊效果
 *
 * pageId 用于 UiTest 通过 ON.id 查找页面根容器。
 *
 * 菜单按钮（可选）：
 * - 当 menuIcon 不为 undefined 时，在 HdsNavigation titleBar 的 menu 区追加一个图标按钮
 * - menuId 通过 HdsNavigationIconOptions.componentId 暴露给 UiTest，用于 ON.id 定位触发
 * - 用于测试入口（如 HomePage 的 push 到 QuestionDetailPage 测试）
 */

import {
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsNavigationMenuItemOptions,
  HdsNavigationMenuContentOptions,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { EmptyView } from './EmptyView';

@ComponentV2
export struct PlaceholderPage {
  /** 页面标题，用于 HdsNavigation titleBar */
  @Param title: string | Resource = '';
  /** 可选返回回调，不传则不显示返回按钮 */
  @Param onBack: (() => void) | undefined = undefined;
  /** 页面根容器 id，用于 UiTest 查找；为空时不设置 id */
  @Param pageId: string = '';
  /** 可选菜单图标资源（SymbolGlyph）；不传则不显示菜单按钮 */
  @Param menuIcon: Resource | undefined = undefined;
  /** 菜单按钮无障碍 label */
  @Param menuLabel: string = '';
  /** 菜单按钮 componentId，用于 UiTest ON.id 定位 */
  @Param menuId: string = '';
  /** 菜单按钮点击回调 */
  @Param onMenuClick: (() => void) | undefined = undefined;

  /** 占位用的空 NavPathStack，HdsNavigation 仅作为 UI 容器不参与路由 */
  private emptyStack: NavPathStack = new NavPathStack();

  build() {
    HdsNavigation(this.emptyStack) {
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
    .id(this.pageId)
    .width('100%')
    .height('100%')
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(this.onBack === undefined)
    .titleBar({
      padding: {
        start: LengthMetrics.vp(2),
        end: LengthMetrics.vp(2)
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.COMMON_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(0)
        },
        originalStyle: {
          backgroundStyle: {
            backgroundColor: $r('app.color.app_title_bar_background')
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('app.color.app_title_bar_on_surface'),
              subTitleColor: $r('app.color.app_on_surface_secondary')
            },
            menuStyle: {
              backgroundColor: $r('app.color.app_surface_variant'),
              iconColor: $r('app.color.app_title_bar_on_surface')
            },
            backIconStyle: {
              backgroundColor: $r('app.color.app_surface_variant'),
              iconColor: $r('app.color.app_title_bar_on_surface')
            }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: $r('app.color.app_title_bar_background')
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('app.color.app_title_bar_on_surface'),
              subTitleColor: $r('app.color.app_on_surface_secondary')
            },
            menuStyle: {
              backgroundColor: $r('app.color.app_surface_variant'),
              iconColor: $r('app.color.app_title_bar_on_surface')
            },
            backIconStyle: {
              backgroundColor: $r('app.color.app_surface_variant'),
              iconColor: $r('app.color.app_title_bar_on_surface')
            }
          }
        }
      },
      content: {
        title: { mainTitle: this.title },
        menu: this.buildMenuOptions(),
        backIcon: this.onBack !== undefined ? {
          label: 'back',
          icon: $r('sys.symbol.chevron_left'),
          isEnabled: true,
          componentId: 'back',
          action: () => {
            const cb = this.onBack;
            if (cb !== undefined) {
              cb();
            }
          }
        } : undefined
      }
    });
  }

  /**
   * 构造 HdsNavigationMenuContentOptions 包装对象。
   * 仅在 menuIcon 不为 undefined 且 onMenuClick 不为 undefined 时返回单项菜单配置，
   * 否则返回 undefined，避免 HdsNavigation 渲染空菜单容器。
   */
  private buildMenuOptions(): HdsNavigationMenuContentOptions | undefined {
    const icon: Resource | undefined = this.menuIcon;
    const cb: (() => void) | undefined = this.onMenuClick;
    if (icon === undefined || cb === undefined) {
      return undefined;
    }
    const item: HdsNavigationMenuItemOptions = {
      content: {
        icon: icon,
        label: this.menuLabel,
        isEnabled: true,
        componentId: this.menuId,
        action: () => {
          cb();
        }
      }
    };
    const items: HdsNavigationMenuItemOptions[] = [item];
    const options: HdsNavigationMenuContentOptions = {
      value: items
    };
    return options;
  }
}
