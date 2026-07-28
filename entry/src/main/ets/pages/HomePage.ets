/**
 * 首页（推荐信息流）
 *
 * 作为 TabBar 的默认页，直接渲染内容（不包 NavDestination）。
 *
 * 架构：
 * - HdsNavigation 作为页面级根容器（模式三混合写法 4 字段组合）
 *   - 传入空 NavPathStack，仅作为 UI 容器不参与路由
 *   - titleMode = MINI
 *   - 顶部渐变模糊 + 沉浸光感材质
 * - Refresh + List + LazyForEach 渲染信息流卡片
 *   - 下拉触发 viewModel.pullToRefresh()
 *   - 触底 onReachEnd 触发 viewModel.loadMore()
 * - StateView 覆盖层：加载中/空态/错误态切换
 * - 底部加载更多指示器（isLoading 且 items > 0 时显示）
 *
 * 状态管理：
 * - @Local viewModel: HomeFeedViewModel（@ObservedV2 + @Trace 单例）
 * - build 中读取 viewModel.items 等字段建立 @Trace 依赖
 * - items 引用变化时触发 build 重新执行，同步到 FeedCardDataSource
 *
 * 测试入口（占位期间，仅 SHOW_TEST_ENTRY=true 时显示）：
 * - titleBar 右上角齿轮按钮（componentId: home_test_push）
 * - 由外层 Index.ets 通过 onPushQuestion callback 注入 pushPathByName 调用
 * - 第 3 批接入详情页跳转后移除
 */

import {
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsNavigationMenuItemOptions,
  HdsNavigationMenuContentOptions,
  ScrollEffectType,
  hdsMaterial
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { HomeFeedViewModel } from '../viewmodel/HomeFeedViewModel';
import { FeedCardDataSource } from '../viewmodel/FeedCardDataSource';
import { StateView, ViewState } from '../components/StateView';
import { FeedCardView } from '../components/FeedCardView';
import { FeedCard } from '../model/FeedCard';

/**
 * 测试入口可见性开关。
 *
 * 占位期间设为 true 以便 UiTest 验证路由跳转。
 * 发布前改为 false 隐藏测试入口，避免泄漏到生产。
 * 第 3 批接入详情页跳转后移除该开关。
 */
const SHOW_TEST_ENTRY: boolean = true;

/**
 * 共享的空 NavPathStack。
 *
 * HdsNavigation 作为 UI 容器（仅用 titleBar + 渐变模糊）时传入此栈，
 * 不参与实际路由。所有 HomePage 实例共用同一个空栈，避免每个实例
 * 都创建独立的 NavPathStack 造成内存浪费。
 */
const EMPTY_NAV_STACK: NavPathStack = new NavPathStack();

@ComponentV2
export struct HomePage {
  /**
   * 测试入口回调：点击右上角齿轮按钮时触发。
   * 由 Index.ets 注入 navPathStack.pushPathByName 调用。
   * undefined 时齿轮按钮不显示。
   */
  @Param onPushQuestion: (() => void) | undefined = undefined;

  /** ViewModel 单例（@ObservedV2 + @Trace 装饰） */
  @Local viewModel: HomeFeedViewModel = HomeFeedViewModel.getInstance();

  /** LazyForEach 数据源 */
  private dataSource: FeedCardDataSource = new FeedCardDataSource();

  aboutToAppear(): void {
    // 首次进入首页时自动加载（如果列表为空）
    this.viewModel.loadIfEmpty();
    // 初始同步一次 dataSource（@Monitor 不会在首次赋值时触发）
    this.dataSource.setItems(this.viewModel.items);
  }

  /**
   * 监听 viewModel.items 引用变化，同步到 LazyForEach 数据源。
   *
   * ArkUI V2 的 @Trace 仅观察引用变化，@Monitor 会在引用变化时回调。
   * loadMore / pullToRefresh 成功后都会重新赋值 items 触发本回调。
   */
  @Monitor('viewModel.items')
  onItemsChange(): void {
    this.dataSource.setItems(this.viewModel.items);
  }

  build() {
    HdsNavigation(EMPTY_NAV_STACK) {
      Stack() {
        // 列表内容（items > 0 时渲染）
        if (this.viewModel.items.length > 0) {
          Refresh({ refreshing: this.viewModel.isPullToRefresh }) {
            List({ space: 8 }) {
              LazyForEach(this.dataSource, (item: FeedCard) => {
                ListItem() {
                  FeedCardView({
                    card: item,
                    onCardClick: (card: FeedCard) => {
                      // 第 3 批接入详情页跳转；本批预留空回调
                      // 点击卡片暂无效果，避免误触
                    }
                  });
                }
              }, (item: FeedCard) => item.stableKey);
            }
            .width('100%')
            .height('100%')
            .padding({
              left: $r('app.float.page_padding_horizontal'),
              right: $r('app.float.page_padding_horizontal'),
              top: $r('app.float.page_padding_vertical'),
              bottom: $r('app.float.page_padding_vertical')
            })
            .onReachEnd(() => {
              this.viewModel.loadMore();
            });
          }
          .width('100%')
          .height('100%')
          .onRefreshing(() => {
            this.viewModel.pullToRefresh();
          });
        }

        // 状态视图覆盖层（非内容态时显示）
        // 加载中 + 列表为空：显示 LoadingView
        if (this.viewModel.isLoading && this.viewModel.items.length === 0) {
          StateView({ status: ViewState.LOADING });
        } else if (this.viewModel.errorMessage.length > 0 && this.viewModel.items.length === 0) {
          // 错误 + 列表为空：显示 ErrorView + 重试
          StateView({
            status: ViewState.ERROR,
            errorMessage: this.viewModel.errorMessage,
            onRetry: () => {
              this.viewModel.retry();
            }
          });
        } else if (this.viewModel.items.length === 0 && !this.viewModel.isLoading) {
          // 空态：列表为空且未加载
          StateView({ status: ViewState.EMPTY });
        }

        // 底部加载更多指示器（列表非空 + 正在加载更多时显示）
        if (this.viewModel.items.length > 0 && this.viewModel.isLoading) {
          Column() {
            LoadingProgress()
              .width($r('app.float.loading_indicator_size'))
              .height($r('app.float.loading_indicator_size'))
              .color($r('app.color.app_loading'));
          }
          .width('100%')
          .height(56)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .position({ x: 0, y: '100%' })
          .markAnchor({ x: 0, y: '100%' });
        }
      }
      .width('100%')
      .height('100%');
    }
    .id('page_home_title')
    .width('100%')
    .height('100%')
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    .titleBar({
      padding: {
        start: LengthMetrics.vp(2),
        end: LengthMetrics.vp(2)
      },
      style: {
        // 模式三混合写法 4 字段组合
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(0)
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
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
            }
          }
        }
      },
      content: {
        title: { mainTitle: $r('app.string.page_home_title') },
        menu: this.buildMenuOptions()
      }
    });
  }

  /**
   * 构造 HdsNavigationMenuContentOptions 包装对象。
   * 仅在 SHOW_TEST_ENTRY=true 且 onPushQuestion 不为 undefined 时返回单项菜单配置，
   * 否则返回 undefined，避免 HdsNavigation 渲染空菜单容器。
   */
  private buildMenuOptions(): HdsNavigationMenuContentOptions | undefined {
    if (!SHOW_TEST_ENTRY) {
      return undefined;
    }
    const cb: (() => void) | undefined = this.onPushQuestion;
    if (cb === undefined) {
      return undefined;
    }
    const item: HdsNavigationMenuItemOptions = {
      content: {
        icon: $r('sys.symbol.chevron_right'),
        label: '测试入口',
        isEnabled: true,
        componentId: 'home_test_push',
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
