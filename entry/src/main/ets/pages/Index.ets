/**
 * 应用主壳 - HDS 版
 *
 * 架构说明（基于 HDS 官方"沉浸光感"文档示例）：
 * - HdsNavigation 作为应用一级导航容器，navPathStack 承载详情页路由
 * - content slot 内放 HdsTabs 作为底部 TabBar 容器
 * - 每个 TabContent 直接承载 Tab 页面内容（HomePage/SearchPage/ProfilePage）
 * - Tab 页面不再各自用 HdsNavigation 作为根容器（避免嵌套导致 content slot 塌缩）
 * - 外层 HdsNavigation 统一提供 titleBar（4 字段模式三混合写法），
 *   title/menu 内容根据 currentTab 动态切换
 * - 详情页通过 .navDestination(PageMap) 注入，使用 HdsNavDestination（不是 HdsNavigation）
 * - AppToast 作为 Stack 顶层覆盖，仅占底部小区域，不拦截下层点击
 *
 * 卡片点击跳转（第 3 批 Slice 2 接入）：
 * - HomePage 通过 @Param onCardClick 回调把卡片点击事件交给 Index.ets
 * - Index.ets 的 handleCardClick 根据 card.contentType 分发到对应详情页：
 *   - QUESTION → QuestionDetailPage
 *   - ANSWER → AnswerDetailPage
 *   - ARTICLE → ArticleDetailPage
 *
 * HdsTabs 渐变模糊三要素（缺一不可，运行时不报错但效果不生效）：
 *   1. barOverlap(true)            - TabBar 叠加在内容之上
 *   2. barPosition(BarPosition.End) - 必须位于底部
 *   3. vertical(false)             - 必须水平排列
 *
 * HdsTabs 渐变模糊通过 barFloatingStyle 配置（不是 barBackgroundStyle，后者不是有效 API）：
 *   - gradientMask: 渐变蒙版颜色和高度
 *   - systemMaterialEffect: 沉浸光感材质（IMMERSIVE + ADAPTIVE）
 *
 * 注意：
 * - ArkTS V2 严格语法，@ComponentV2 + @Local
 * - 资源全部通过 $r() 引用
 * - TabBar 图标使用 sys.symbol 已确认 glyph 名（house / magnifyingglass / person）
 */

import {
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsNavigationMenuItemOptions,
  HdsNavigationMenuContentOptions,
  HdsTabs,
  HdsTabsController,
  ScrollEffectType,
  hdsMaterial
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  RouteName,
  QuestionDetailParams,
  AnswerDetailParams,
  ArticleDetailParams
} from '../router/AppRouter';
import { AppToast } from '../components/AppToast';
import { HomePage } from './HomePage';
import { SearchPage } from './SearchPage';
import { ProfilePage } from './ProfilePage';
import { QuestionDetailPage } from './QuestionDetailPage';
import { AnswerDetailPage } from './AnswerDetailPage';
import { ArticleDetailPage } from './ArticleDetailPage';
import { LoginPage } from './LoginPage';
import { SettingsPage } from './SettingsPage';
import { FeedCard } from '../model/FeedCard';
import { ContentType } from '../model/ContentType';
import { SessionViewModel } from '../viewmodel/SessionViewModel';

const DOMAIN: number = 0x0000;
const TAG: string = 'Index';

/**
 * 测试入口可见性开关。
 *
 * 占位期间设为 true 以便 UiTest 验证路由跳转。
 * 发布前改为 false 隐藏测试入口，避免泄漏到生产。
 * 第 3 批接入详情页跳转后，生产环境应设为 false（仅保留 onCardClick 真实跳转路径）。
 */
const SHOW_TEST_ENTRY: boolean = false;

/**
 * 路由分发 Builder
 *
 * HdsNavigation 内部通过此 @Builder 函数根据 name 返回 HdsNavDestination 目标页。
 * pushPath({ name: RouteName.XXX }) 触发时被调用。
 *
 * 约束（来自 HdsNavigation API 文档）：
 * - builder 下只能有一个根节点
 * - builder 中允许在 HdsNavDestination 组件外包含一层自定义组件，
 *   但自定义组件不允许设置属性和事件，否则仅显示空白
 * 因此这里直接调用 XxxPage()，不加任何属性。
 *
 * 未知路由 fallback：若 name 不匹配任何已知路由，渲染错误占位页，避免黑屏。
 */
@Builder
function PageMap(name: string) {
  if (name === RouteName.QUESTION_DETAIL) {
    QuestionDetailPage();
  } else if (name === RouteName.ANSWER_DETAIL) {
    AnswerDetailPage();
  } else if (name === RouteName.ARTICLE_DETAIL) {
    ArticleDetailPage();
  } else if (name === RouteName.LOGIN) {
    LoginPage();
  } else if (name === RouteName.SETTINGS) {
    SettingsPage();
  } else {
    // 未知路由：显示错误占位页，避免黑屏
    Column() {
      Text($r('app.string.error_unknown_route'))
        .fontSize(16)
        .fontColor($r('app.color.app_error'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }
}

@Entry
@ComponentV2
struct Index {
  /** 全局导航栈，承载 push 进入的详情页 */
  @Local navPathStack: NavPathStack = new NavPathStack();
  /** 当前选中的 Tab：0=首页, 1=搜索, 2=我的 */
  @Local currentTab: number = 0;
  /** HdsTabs 控制器，用于编程式切换 Tab */
  private tabsController: HdsTabsController = new HdsTabsController();
  /**
   * 会话 ViewModel（@ObservedV2 + @Trace 单例）。
   *
   * 通过 @Local 持有引用，使 @Monitor 能监听其 @Trace 属性变化。
   * SessionViewModel.isRestored 由 EntryAbility.restoreSession() 完成。
   */
  @Local sessionViewModel: SessionViewModel = SessionViewModel.getInstance();
  /**
   * 是否已触发过初始登录跳转（防止重复 push）。
   *
   * 路由守卫仅在冷启动后第一次 isRestored=true 时触发一次：
   * - 未登录 → push LoginPage
   * - 已登录 → 不跳转
   * 用户从 LoginPage pop 回来后（无论是否登录成功）不再自动跳转，
   * 避免与用户主动操作冲突。
   */
  private hasTriggeredLoginGuard: boolean = false;

  aboutToAppear(): void {
    // 设置退出登录 UI 回调（清理 WebView Cookie + 重置导航栈）
    this.sessionViewModel.setLogoutCallback(() => {
      // 清理 WebView Cookie（必须在 UI 线程调用）
      try {
        webview.WebCookieManager.clearAllCookiesSync();
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'clearAllCookiesSync failed: %{public}s',
          e instanceof Error ? e.message : String(e));
      }
      // 重置导航栈到首页（NavPathStack 无 popToRoot，用循环 pop）
      while (this.navPathStack.size() > 0) {
        this.navPathStack.pop();
      }
    });
    // 启动时立即检查一次（防止 isRestored 在组件创建前已为 true）
    this.maybePushLoginPage();
  }

  /**
   * 监听会话恢复完成。
   *
   * SessionViewModel.isRestored 在 restoreSession() 的 finally 块中设为 true，
   * 此回调触发后检查登录态决定是否跳转登录页。
   */
  @Monitor('sessionViewModel.isRestored')
  onSessionRestored(): void {
    this.maybePushLoginPage();
  }

  /**
   * 路由守卫：会话恢复完成且未登录时，push LoginPage。
   *
   * 触发条件（全部满足）：
   * 1. 未触发过登录跳转（hasTriggeredLoginGuard=false）
   * 2. 会话恢复已完成（isRestored=true）
   * 3. 未登录（isLoggedIn=false）
   *
   * 触发后置位 hasTriggeredLoginGuard=true，防止重复 push。
   * 用户从 LoginPage pop 返回后不会再次自动跳转，避免与用户主动操作冲突。
   */
  private maybePushLoginPage(): void {
    if (this.hasTriggeredLoginGuard) {
      return;
    }
    if (!this.sessionViewModel.isRestored) {
      return;
    }
    this.hasTriggeredLoginGuard = true;
    if (this.sessionViewModel.isLoggedIn) {
      return;
    }
    this.navPathStack.pushPathByName(RouteName.LOGIN, null);
  }

  build() {
    Stack() {
      HdsNavigation(this.navPathStack) {
        HdsTabs({ controller: this.tabsController }) {
          TabContent() {
            HomePage({
              onCardClick: (card: FeedCard) => {
                this.handleCardClick(card);
              }
            });
          }
          .tabBar({ icon: $r('sys.symbol.house'), text: $r('app.string.tab_home') });

          TabContent() {
            SearchPage();
          }
          .tabBar({ icon: $r('sys.symbol.magnifyingglass'), text: $r('app.string.tab_search') });

          TabContent() {
            ProfilePage({
              onLoginClick: () => {
                this.navPathStack.pushPathByName(RouteName.LOGIN, null);
              },
              onSettingsClick: () => {
                this.navPathStack.pushPathByName(RouteName.SETTINGS, null);
              },
              onLogoutClick: () => {
                // 退出登录：异步调用 SessionViewModel.logout，内部自动触发 logoutCallback
                this.sessionViewModel.logout().then(() => {
                  hilog.info(DOMAIN, TAG, 'logout: completed');
                }).catch((e: object) => {
                  hilog.error(DOMAIN, TAG, 'logout failed: %{public}s',
                    e instanceof Error ? e.message : String(e));
                });
              }
            });
          }
          .tabBar({ icon: $r('sys.symbol.person'), text: $r('app.string.tab_profile') });
        }
        .barOverlap(true)
        .barPosition(BarPosition.End)
        .vertical(false)
        .barFloatingStyle({
          // 渐变蒙版：底部向上的颜色渐变，营造 TabBar 悬浮感
          gradientMask: {
            maskColor: $r('app.color.app_tab_bar_background'),
            maskHeight: 80
          },
          // 沉浸光感材质：系统自适应，性能与效果平衡
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
          }
        })
        .onChange((index: number) => {
          if (index === this.currentTab) {
            return;
          }
          // 切换 Tab 前清空当前 Tab 的所有 push 页面，避免残留在新 Tab 上
          while (this.navPathStack.size() > 0) {
            this.navPathStack.pop();
          }
          this.currentTab = index;
        });
      }
      .navDestination(PageMap)
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
          title: { mainTitle: this.currentTabTitle() },
          menu: this.buildMenuOptions()
        }
      });

      // Toast 覆盖层：仅占底部小区域，不拦截下层点击
      AppToast();
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'));
  }

  /**
   * 根据当前 Tab 返回对应的标题资源。
   *
   * 外层 HdsNavigation 的 titleBar 由所有 Tab 共用，
   * 切换 Tab 时 mainTitle 跟随切换，保持原生体验。
   */
  private currentTabTitle(): Resource {
    if (this.currentTab === 0) {
      return $r('app.string.page_home_title');
    } else if (this.currentTab === 1) {
      return $r('app.string.page_search_title');
    } else {
      return $r('app.string.page_profile_title');
    }
  }

  /**
   * 构造 HdsNavigationMenuContentOptions 包装对象。
   *
   * 仅在首页 Tab（currentTab === 0）且 SHOW_TEST_ENTRY=true 时，
   * 返回单项菜单配置；否则返回 undefined，避免 HdsNavigation 渲染空菜单容器。
   *
   * 测试入口用于 UiTest 验证路由跳转链路（home_test_push componentId）。
   * 真实卡片点击跳转由 HomePage.onCardClick → handleCardClick 处理，与本入口并存。
   */
  private buildMenuOptions(): HdsNavigationMenuContentOptions | undefined {
    if (!SHOW_TEST_ENTRY) {
      return undefined;
    }
    if (this.currentTab !== 0) {
      return undefined;
    }
    const item: HdsNavigationMenuItemOptions = {
      content: {
        icon: $r('sys.symbol.chevron_right'),
        label: '测试入口',
        isEnabled: true,
        componentId: 'home_test_push',
        action: () => {
          // 测试入口：直接 push 占位参数到 QuestionDetailPage
          // 真实跳转由 HomePage卡片点击 → handleCardClick 触发
          const params: QuestionDetailParams = {
            questionId: 'placeholder',
            previewTitle: '占位问题'
          };
          this.navPathStack.pushPathByName(RouteName.QUESTION_DETAIL, params);
        }
      }
    };
    const items: HdsNavigationMenuItemOptions[] = [item];
    const options: HdsNavigationMenuContentOptions = {
      value: items
    };
    return options;
  }

  /**
   * 处理首页卡片点击，根据 contentType 分发到对应详情页。
   *
   * - QUESTION → QuestionDetailPage（本批 Slice 2 已实现）
   * - ANSWER → AnswerDetailPage（Slice 3 实现）
   * - ARTICLE → ArticleDetailPage（Slice 4 实现）
   * - 其他 → no-op
   */
  private handleCardClick(card: FeedCard): void {
    if (card.contentType === ContentType.QUESTION) {
      const params: QuestionDetailParams = {
        questionId: card.rawId,
        previewTitle: card.title
      };
      this.navPathStack.pushPathByName(RouteName.QUESTION_DETAIL, params);
    } else if (card.contentType === ContentType.ANSWER) {
      const params: AnswerDetailParams = {
        answerId: card.rawId
      };
      this.navPathStack.pushPathByName(RouteName.ANSWER_DETAIL, params);
    } else if (card.contentType === ContentType.ARTICLE) {
      const params: ArticleDetailParams = {
        articleId: card.rawId
      };
      this.navPathStack.pushPathByName(RouteName.ARTICLE_DETAIL, params);
    }
    // 其他类型（PIN/ZVIDEO）暂不处理
  }
}
