/**
 * 应用主壳
 *
 * 承载 Navigation + NavPathStack + 自定义 TabBar + 全局 Toast 容器。
 *
 * 架构说明：
 * - Navigation 的 children 是 TabBar 的根内容区，根据 currentTab 切换 HomePage / SearchPage / ProfilePage
 * - .navDestination 接收 top-level @Builder function PageMap，根据 name 返回 push 进入的目标页
 * - 自定义 TabBar 在 Navigation 下方，三个 Tab：首页 / 搜索 / 我的
 * - AppToast 作为 Stack 覆盖层，绑定全局 toastState 单例
 *
 * 注意：
 * - ArkTS V2 严格语法，@ComponentV2 + @Local
 * - 资源全部通过 $r() 引用
 * - TabBar 图标用 Text 字符代替 SymbolGlyph，避免瞎猜 glyph 名
 */

import { NavPathStack } from '@kit.ArkUI';
import { RouteName } from '../router/AppRouter';
import { toastState } from '../utils/ToastUtil';
import { AppToast } from '../components/AppToast';
import { HomePage } from './HomePage';
import { SearchPage } from './SearchPage';
import { QuestionDetailPage } from './QuestionDetailPage';
import { AnswerDetailPage } from './AnswerDetailPage';
import { ArticleDetailPage } from './ArticleDetailPage';
import { LoginPage } from './LoginPage';
import { ProfilePage } from './ProfilePage';
import { SettingsPage } from './SettingsPage';

/**
 * 路由分发 Builder
 *
 * Navigation 的 .navDestination 必须接收一个 @Builder 函数引用（不能是 inline lambda）。
 * 根据 name 返回对应的 NavDestination 页面。pushPath({ name: RouteName.XXX }) 触发时被调用。
 */
@Builder
function PageMap(name: string) {
  if (name === RouteName.HOME) {
    HomePage();
  } else if (name === RouteName.SEARCH) {
    SearchPage();
  } else if (name === RouteName.QUESTION_DETAIL) {
    QuestionDetailPage();
  } else if (name === RouteName.ANSWER_DETAIL) {
    AnswerDetailPage();
  } else if (name === RouteName.ARTICLE_DETAIL) {
    ArticleDetailPage();
  } else if (name === RouteName.LOGIN) {
    LoginPage();
  } else if (name === RouteName.PROFILE) {
    ProfilePage();
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

  /**
   * 单个 Tab 项
   *
   * @param index - Tab 索引
   * @param label - Tab 文本资源
   * @param icon - Tab 图标字符（用 Text 代替 SymbolGlyph）
   * @param itemId - 组件 id，供 UiTest 查找
   */
  @Builder
  tabItem(index: number, label: Resource, icon: string, itemId: string) {
    Column() {
      Text(icon)
        .fontSize($r('app.float.tab_bar_icon_size'))
        .fontColor(this.currentTab === index
          ? $r('app.color.app_tab_bar_indicator')
          : $r('app.color.app_tab_bar_on_surface'));

      Text(label)
        .fontSize($r('app.float.tab_bar_label_font_size'))
        .fontColor(this.currentTab === index
          ? $r('app.color.app_tab_bar_indicator')
          : $r('app.color.app_tab_bar_on_surface'))
        .margin({ top: 4 });
    }
    .id(itemId)
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.currentTab = index;
    });
  }

  /**
   * 自定义 TabBar：三个 Tab 横向排列，顶部 0.5vp 分隔线
   */
  @Builder
  tabBar() {
    Row() {
      this.tabItem(0, $r('app.string.tab_home'), '⌂', 'tab_home');
      this.tabItem(1, $r('app.string.tab_search'), '🔍', 'tab_search');
      this.tabItem(2, $r('app.string.tab_profile'), '👤', 'tab_profile');
    }
    .width('100%')
    .height($r('app.float.tab_bar_height'))
    .backgroundColor($r('app.color.app_tab_bar_background'))
    .border({ width: { top: 0.5 }, color: $r('app.color.app_divider') });
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        Navigation(this.navPathStack) {
          // TabBar 内容区：根据 currentTab 切换根内容
          // HomePage / SearchPage / ProfilePage 是 TabBar 的根页面
          if (this.currentTab === 0) {
            HomePage();
          } else if (this.currentTab === 1) {
            SearchPage();
          } else {
            ProfilePage();
          }
        }
        .navDestination(PageMap)
        .mode(NavigationMode.Stack)
        .hideTitleBar(true)
        .hideToolBar(true)
        .layoutWeight(1);

        this.tabBar();
      }
      .width('100%')
      .height('100%');

      // Toast 覆盖层：绑定全局 toastState，不拦截下层事件
      AppToast({
        message: toastState.message,
        visible: toastState.visible
      });
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'));
  }
}
