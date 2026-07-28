/**
 * 应用主壳 - HDS 版
 *
 * 架构说明：
 * - HdsNavigation 替代 Navigation，作为路由壳与 NavDestination 分发容器
 * - HdsTabs 替代自定义 TabBar，提供底部渐变模糊（沉浸光感视效）
 * - AppToast 作为 Stack 覆盖层，直接绑定全局 toastState 单例
 *
 * HdsTabs 渐变模糊三要素（缺一不可，运行时不报错但效果不生效）：
 *   1. barOverlap(true)        - TabBar 叠加在内容之上
 *   2. barPosition(BarPosition.End) - 必须位于底部
 *   3. vertical(false)         - 必须水平排列
 *
 * HdsTabs 模糊不能与原生 Tabs 的 barBackgroundColor / barBackgroundEffect / barBackgroundBlurStyle 混用，
 * 否则 HdsTabs 默认模糊管线被替换。
 *
 * 注意：
 * - ArkTS V2 严格语法，@ComponentV2 + @Local
 * - 资源全部通过 $r() 引用
 * - TabBar 图标使用 sys.symbol 已确认 glyph 名（house / magnifyingglass / person）
 */

import {
  HdsNavigation,
  HdsTabs,
  HdsTabsController
} from '@kit.UIDesignKit';
import { RouteName, QuestionDetailParams } from '../router/AppRouter';
import { toastState } from '../utils/ToastUtil';
import { AppToast } from '../components/AppToast';
import { HomePage } from './HomePage';
import { SearchPage } from './SearchPage';
import { ProfilePage } from './ProfilePage';
import { QuestionDetailPage } from './QuestionDetailPage';
import { AnswerDetailPage } from './AnswerDetailPage';
import { ArticleDetailPage } from './ArticleDetailPage';
import { LoginPage } from './LoginPage';
import { SettingsPage } from './SettingsPage';

/**
 * 路由分发 Builder
 *
 * HdsNavigation 内部封装了 navDestination，通过此 @Builder 函数根据 name 返回目标页。
 * pushPath({ name: RouteName.XXX }) 触发时被调用。
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
  }
}

@Entry
@ComponentV2
struct Index {
  /** 全局导航栈，承载 push 进入的目标页 */
  @Local navPathStack: NavPathStack = new NavPathStack();
  /** 当前选中的 Tab：0=首页, 1=搜索, 2=我的 */
  @Local currentTab: number = 0;
  /** HdsTabs 控制器，用于编程式切换 Tab */
  private tabsController: HdsTabsController = new HdsTabsController();

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        // HdsNavigation 作为主壳导航容器，hideTitleBar(true) 把顶部空间让给子页面
        // 子页面（HomePage/SearchPage/ProfilePage 及 push 进入的目标页）自己控制顶栏
        HdsNavigation(this.navPathStack) {
          if (this.currentTab === 0) {
            // 注入测试入口回调，由 HomePage titleBar 测试入口按钮触发 push 到 QuestionDetailPage
            // 传 QuestionDetailParams 占位参数（占位期间不使用 questionId，仅满足类型与签名约束）
            HomePage({
              onPushQuestion: () => {
                const params: QuestionDetailParams = {
                  questionId: 'placeholder',
                  previewTitle: '占位问题'
                };
                this.navPathStack.pushPathByName(RouteName.QUESTION_DETAIL, params);
              }
            });
          } else if (this.currentTab === 1) {
            SearchPage();
          } else {
            ProfilePage();
          }
        }
        .navDestination(PageMap)
        .hideTitleBar(true)
        .layoutWeight(1);

        // HdsTabs 作为底部 TabBar，提供渐变模糊背景
        HdsTabs({ controller: this.tabsController }) {
          TabContent() {
            // 内容区为空，实际内容由 HdsNavigation 根据 currentTab 渲染
            // HdsTabs 仅作为 TabBar 容器，不承载页面内容
            Column().width('100%').height('100%');
          }
          .tabBar({ icon: $r('sys.symbol.house'), text: $r('app.string.tab_home') });

          TabContent() {
            Column().width('100%').height('100%');
          }
          .tabBar({ icon: $r('sys.symbol.magnifyingglass'), text: $r('app.string.tab_search') });

          TabContent() {
            Column().width('100%').height('100%');
          }
          .tabBar({ icon: $r('sys.symbol.person'), text: $r('app.string.tab_profile') });
        }
        .barOverlap(true)
        .barPosition(BarPosition.End)
        .vertical(false)
        .barBackgroundStyle({
          maskColor: $r('app.color.app_tab_bar_background'),
          maskHeight: 80
        })
        .onChange((index: number) => {
          this.currentTab = index;
        });
      }
      .width('100%')
      .height('100%');

      // Toast 覆盖层：直接绑定全局 toastState 单例
      AppToast();
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'));
  }
}
