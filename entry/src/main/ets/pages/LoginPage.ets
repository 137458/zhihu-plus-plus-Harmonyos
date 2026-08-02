/**
 * 登录页（ArkWeb 实现）
 *
 * 使用 Web 组件加载知乎 Web 端登录页（https://www.zhihu.com/signin?next=%2F），
 * 用户在 WebView 中完成登录后，通过 WebCookieManager 提取 z_c0 等 Cookie，
 * 调用 LoginViewModel.detectLoginFromCookies 验证登录态并同步全局会话。
 *
 * 设计要点：
 * - 桌面 UA：避免知乎返回移动端 H5 登录页（功能受限）
 * - onPageEnd 触发 Cookie 检测：每次页面加载完成后检查 z_c0
 * - 加载态遮罩：仅在首次加载时显示（避免登录提交时的页面跳转闪烁遮罩）
 * - 错误态遮罩：网络失败时显示错误信息 + 重试按钮
 * - 登录检测中遮罩：z_c0 存在时显示验证中状态
 * - 登录成功：自动 pop 返回上一页
 *
 * 安全约束：Cookie/Token 不进日志；Cookie 通过 WebCookieManager 提取后直接进入 CookieJar。
 *
 * 架构与 QuestionDetailPage 一致：build() 直接返回 HdsNavDestination，
 * titleBar 配置引用 DETAIL_TITLE_BAR_STYLE 常量。
 */

import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DETAIL_TITLE_BAR_STYLE, DETAIL_TITLE_BAR_PADDING } from '../components/PlaceholderPage';
import { LoginViewModel, ZHIHU_LOGIN_URL, ZHIHU_WEB_UA } from '../viewmodel/LoginViewModel';

const DOMAIN: number = 0x0000;
const TAG: string = 'LoginPage';

/**
 * 登录页错误状态枚举。
 *
 * 使用枚举而非 nullable Resource，避免 ArkTS 严格模式下
 * `Resource | null` 在 Text 组件中的类型不匹配问题。
 */
enum LoginErrorState {
  /** 无错误 */
  NONE,
  /** Web 页面加载失败（网络错误、DNS 解析失败等） */
  LOAD_FAILED,
  /** 登录态验证失败（z_c0 存在但 fetchVerifiedSession 抛异常） */
  VERIFY_FAILED
}

@ComponentV2
export struct LoginPage {
  /** Web 控制器 */
  private controller: webview.WebviewController = new webview.WebviewController();
  /** 登录业务逻辑 */
  private viewModel: LoginViewModel = new LoginViewModel();

  /** 路由栈，onReady 时从 NavDestinationContext 获取 */
  @Local navPathStack: NavPathStack | undefined = undefined;
  /** Web 页面是否正在加载（仅首次加载显示遮罩） */
  @Local isLoading: boolean = true;
  /** 是否已完成首次加载（避免登录提交跳转时闪烁遮罩） */
  @Local hasFirstLoadCompleted: boolean = false;
  /** 错误状态 */
  @Local errorState: LoginErrorState = LoginErrorState.NONE;
  /** 登录态检测中（已检测到 z_c0，正在调用 fetchVerifiedSession 验证） */
  @Local isDetecting: boolean = false;

  aboutToAppear(): void {
    // 设置桌面 UA，避免知乎返回移动端 H5 登录页
    // 注意：setCustomUserAgent 是全局生效的，设置后所有 Web 组件都使用此 UA
    this.viewModel.setCustomUserAgent(ZHIHU_WEB_UA);
  }

  build() {
    HdsNavDestination() {
      Stack() {
        // Web 组件始终存在（避免重建导致登录状态丢失）
        Web({ src: ZHIHU_LOGIN_URL, controller: this.controller })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .fileAccess(false)
          .imageAccess(true)
          .onlineImageAccess(true)
          .mixedMode(MixedMode.None)
          .geolocationAccess(false)
          .mediaPlayGestureAccess(true)
          .darkMode(WebDarkMode.Auto)
          .forceDarkAccess(false)
          .onPageBegin(() => {
            // 仅首次加载显示遮罩；登录提交时的页面跳转不显示遮罩（避免遮挡表单）
            if (!this.hasFirstLoadCompleted) {
              this.isLoading = true;
            }
            this.errorState = LoginErrorState.NONE;
          })
          .onPageEnd(() => {
            this.isLoading = false;
            this.hasFirstLoadCompleted = true;
            this.checkLoginStatus();
          })
          .onErrorReceive((event: OnErrorReceiveEvent) => {
            this.isLoading = false;
            this.hasFirstLoadCompleted = true;
            this.errorState = LoginErrorState.LOAD_FAILED;
            hilog.error(DOMAIN, TAG, 'Web load error: %{public}s', event.error.getErrorInfo());
          })
          .onLoadIntercept((event: OnLoadInterceptEvent): boolean => {
            // 安全拦截：仅允许 http/https 协议
            // 知乎登录页可能跳转到第三方协议（weixin://, intent:// 等），拦截防止原生调用风险
            // 所有 https 跳转均放行，确保 QQ/微信等第三方登录流程正常
            const url: string = event.data.getRequestUrl();
            if (!url.startsWith('http://') && !url.startsWith('https://')) {
              hilog.warn(DOMAIN, TAG, 'Blocked non-http(s) URL: %{public}s', url);
              return true;
            }
            return false;
          })
          .width('100%')
          .height('100%');

        // 加载中遮罩（仅首次加载）
        if (this.isLoading) {
          this.buildLoadingOverlay($r('app.string.login_loading_page'));
        }

        // 登录检测中遮罩
        if (this.isDetecting) {
          this.buildLoadingOverlay($r('app.string.login_detecting'));
        }

        // 错误态遮罩（带重试按钮）
        if (this.errorState !== LoginErrorState.NONE) {
          this.buildErrorOverlay();
        }
      }
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
    }
    .titleBar({
      padding: DETAIL_TITLE_BAR_PADDING,
      style: DETAIL_TITLE_BAR_STYLE,
      content: {
        title: { mainTitle: $r('app.string.page_login_title') },
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
    .id('page_login_title')
    .onReady((ctx: NavDestinationContext) => {
      this.navPathStack = ctx.pathStack;
    });
  }

  /**
   * 加载中遮罩 Builder。
   *
   * 用于"正在加载登录页"和"正在检测登录状态"两种场景，
   * 通过 message 参数区分提示文案。
   *
   * @param message 显示的提示文字
   */
  @Builder
  buildLoadingOverlay(message: Resource) {
    Column() {
      LoadingProgress()
        .size({ width: 48, height: 48 })
        .color($r('app.color.app_loading'));
      Text(message)
        .fontSize($r('app.float.body_secondary_font_size'))
        .fontColor($r('app.color.app_on_surface_secondary'))
        .margin({ top: 12 });
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('app.color.app_background'));
  }

  /**
   * 错误态遮罩 Builder（含重试按钮）。
   *
   * 根据 errorState 显示对应的错误文案：
   * - LOAD_FAILED：登录页加载失败
   * - VERIFY_FAILED：登录态验证失败
   */
  @Builder
  buildErrorOverlay() {
    Column() {
      Text($r('app.string.state_error_title'))
        .fontSize($r('app.float.error_title_font_size'))
        .fontColor($r('app.color.app_error'));
      if (this.errorState === LoginErrorState.LOAD_FAILED) {
        Text($r('app.string.login_load_failed'))
          .fontSize($r('app.float.error_subtitle_font_size'))
          .fontColor($r('app.color.app_on_surface_secondary'))
          .margin({ top: 4 });
      } else {
        Text($r('app.string.login_verify_failed'))
          .fontSize($r('app.float.error_subtitle_font_size'))
          .fontColor($r('app.color.app_on_surface_secondary'))
          .margin({ top: 4 });
      }
      Button($r('app.string.login_retry'))
        .margin({ top: 16 })
        .onClick(() => {
          this.errorState = LoginErrorState.NONE;
          this.isLoading = true;
          // 重新加载登录页（不是 refresh，避免缓存导致状态残留）
          this.controller.loadUrl(ZHIHU_LOGIN_URL);
        });
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('app.color.app_background'));
  }

  /**
   * 检测登录状态。
   *
   * 每次 Web 页面加载完成（onPageEnd）时触发：
   * 1. 调用 LoginViewModel.detectLoginFromCookies 提取并验证 Cookie
   * 2. 检测到 z_c0 且验证成功 → pop 返回上一页
   * 3. 未检测到 z_c0 → 不操作，让用户继续在 Web 页面操作
   * 4. 检测到 z_c0 但验证抛异常 → 显示错误提示（保留 Web 内容）
   *
   * 注意：detectLoginFromCookies 内部已实现 z_c0 快速检查（无 z_c0 立即返回 false），
   * 不会触发多余的网络请求。
   */
  private async checkLoginStatus(): Promise<void> {
    if (this.isDetecting) {
      return;
    }
    this.isDetecting = true;
    try {
      const success: boolean = await this.viewModel.detectLoginFromCookies(ZHIHU_WEB_UA);
      if (success) {
        hilog.info(DOMAIN, TAG, 'Login success, popping');
        this.navPathStack?.pop();
      }
      // 未登录时不显示错误，让用户继续在 Web 页面操作
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'checkLoginStatus error: %{public}s',
        e instanceof Error ? e.message : String(e));
      this.errorState = LoginErrorState.VERIFY_FAILED;
    } finally {
      this.isDetecting = false;
    }
  }
}
