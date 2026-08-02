/**
 * 登录页（ArkWeb + 扫码登录实现）
 *
 * 支持两种登录模式切换（对齐原 Android LoginActivity.kt 第 271-285 行）：
 * - 网页登录（LOGIN_MODE_WEB）：Web 组件加载知乎 Web 端登录页
 * - 扫码登录（LOGIN_MODE_QR）：展示二维码，用户用知乎 App 扫码登录
 *
 * 网页登录流程：
 * - 手机 UA（ZHIHU_ANDROID_UA）加载登录页，用户在 WebView 中完成登录
 * - onPageEnd 触发 Cookie 检测，提取 z_c0 验证登录态并同步全局会话
 *
 * 扫码登录流程：
 * - QrLoginPane 组件展示二维码（ArkUI 内置 QRCode 组件）
 * - QrLoginViewModel 管理状态机，轮询扫码状态
 * - 登录成功后自动 pop 返回上一页
 *
 * 设计要点：
 * - 顶部 SegmentedControl 切换登录模式
 * - 网页登录用手机 UA，扫码登录 API 用桌面 UA（各司其职）
 * - 切换回网页模式调用 qrViewModel.cancel()，WebView 状态保留
 * - 沉浸式安全边距适配
 *
 * 安全约束：Cookie/Token 不进日志；Cookie 通过 WebCookieManager/QrLoginApi 提取后直接进入 CookieJar。
 */

import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DETAIL_TITLE_BAR_STYLE, DETAIL_TITLE_BAR_PADDING } from '../components/PlaceholderPage';
import { QrLoginPane } from '../components/QrLoginPane';
import { LoginViewModel, ZHIHU_LOGIN_URL, ZHIHU_WEB_UA, ZHIHU_ANDROID_UA } from '../viewmodel/LoginViewModel';
import { QrLoginViewModel, QrLoginState } from '../viewmodel/QrLoginViewModel';

const DOMAIN: number = 0x0000;
const TAG: string = 'LoginPage';

/** 登录模式枚举（对齐原 Android LOGIN_MODE_WEB=0 / LOGIN_MODE_QR=1） */
enum LoginMode {
  /** 网页登录 */
  WEB = 0,
  /** 扫码登录 */
  QR = 1
}

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
  /** 网页登录业务逻辑 */
  private viewModel: LoginViewModel = new LoginViewModel();
  /** 扫码登录 ViewModel（@Local 以便 @Monitor 监听状态变化） */
  @Local qrViewModel: QrLoginViewModel = new QrLoginViewModel();

  /** 路由栈，onReady 时从 NavDestinationContext 获取 */
  @Local navPathStack: NavPathStack | undefined = undefined;
  /** 当前登录模式（默认网页登录） */
  @Local loginMode: LoginMode = LoginMode.WEB;
  /** Web 页面是否正在加载（仅首次加载显示遮罩） */
  @Local isLoading: boolean = true;
  /** 是否已完成首次加载（避免登录提交跳转时闪烁遮罩） */
  @Local hasFirstLoadCompleted: boolean = false;
  /** 错误状态 */
  @Local errorState: LoginErrorState = LoginErrorState.NONE;
  /** 登录态检测中（已检测到 z_c0，正在调用 fetchVerifiedSession 验证） */
  @Local isDetecting: boolean = false;

  aboutToAppear(): void {
    // 设置手机 UA（知乎 App UA），与原 Android 项目对齐
    // 原 Android：登录页用 WebView 默认 UA（手机），首页用 AccountData.ANDROID_USER_AGENT（手机）
    // HarmonyOS：统一使用 ZHIHU_ANDROID_UA
    // 注意：setAppCustomUserAgent 是全局生效的，设置后所有 Web 组件都使用此 UA
    this.viewModel.setCustomUserAgent(ZHIHU_ANDROID_UA);
  }

  aboutToDisappear(): void {
    // 页面销毁时取消扫码登录轮询，避免泄漏
    this.qrViewModel.cancel();
  }

  /**
   * 监听扫码登录状态变化。
   *
   * 进入 SUCCESS 状态后延迟 500ms pop 返回上一页（让用户看到"登录成功"提示）。
   */
  @Monitor('qrViewModel.state')
  onQrLoginStateChanged(): void {
    if (this.qrViewModel.state === QrLoginState.SUCCESS) {
      setTimeout(() => {
        this.navPathStack?.pop();
      }, 500);
    }
  }

  build() {
    HdsNavDestination() {
      Column() {
        // 顶部模式切换 SegmentedControl（网页登录 / 扫码登录）
        Row() {
          Button($r('app.string.login_mode_web'))
            .fontSize($r('app.float.body_font_size'))
            .fontColor(this.loginMode === LoginMode.WEB
              ? $r('app.color.app_on_surface') : $r('app.color.app_on_surface_secondary'))
            .backgroundColor(this.loginMode === LoginMode.WEB
              ? $r('app.color.app_surface_variant') : $r('app.color.app_background'))
            .borderRadius(8)
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .onClick(() => {
              this.switchMode(LoginMode.WEB);
            });
          Button($r('app.string.login_mode_qr'))
            .fontSize($r('app.float.body_font_size'))
            .fontColor(this.loginMode === LoginMode.QR
              ? $r('app.color.app_on_surface') : $r('app.color.app_on_surface_secondary'))
            .backgroundColor(this.loginMode === LoginMode.QR
              ? $r('app.color.app_surface_variant') : $r('app.color.app_background'))
            .borderRadius(8)
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .margin({ left: 8 })
            .onClick(() => {
              this.switchMode(LoginMode.QR);
            });
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 8, bottom: 8 });

        // 内容区：根据模式切换显示
        Stack() {
          // Web 组件始终存在（避免重建导致登录状态丢失），通过 visibility 控制显隐
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
              const url: string = event.data.getRequestUrl();
              if (!url.startsWith('http://') && !url.startsWith('https://')) {
                hilog.warn(DOMAIN, TAG, 'Blocked non-http(s) URL: %{public}s', url);
                return true;
              }
              return false;
            })
            .width('100%')
            .height('100%')
            .visibility(this.loginMode === LoginMode.WEB ? Visibility.Visible : Visibility.Hidden);

          // 扫码登录面板（仅在扫码模式显示）
          if (this.loginMode === LoginMode.QR) {
            QrLoginPane({ viewModel: this.qrViewModel });
          }

          // 网页登录：加载中遮罩（仅首次加载）
          if (this.loginMode === LoginMode.WEB && this.isLoading) {
            this.buildLoadingOverlay($r('app.string.login_loading_page'));
          }

          // 网页登录：登录检测中遮罩
          if (this.loginMode === LoginMode.WEB && this.isDetecting) {
            this.buildLoadingOverlay($r('app.string.login_detecting'));
          }

          // 网页登录：错误态遮罩（带重试按钮）
          if (this.loginMode === LoginMode.WEB && this.errorState !== LoginErrorState.NONE) {
            this.buildErrorOverlay();
          }
        }
        .width('100%')
        .layoutWeight(1)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
      }
      .width('100%')
      .height('100%');
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
   * 切换登录模式。
   *
   * - 切换到 QR：自动触发 startLogin
   * - 切换到 WEB：取消扫码轮询，保留 WebView 状态
   *
   * @param mode 目标模式
   */
  private switchMode(mode: LoginMode): void {
    if (this.loginMode === mode) {
      return;
    }
    this.loginMode = mode;
    if (mode === LoginMode.QR) {
      // 进入扫码模式：启动扫码登录流程
      this.qrViewModel.startLogin().catch((e: object) => {
        hilog.error(DOMAIN, TAG, 'qr startLogin failed: %{public}s',
          e instanceof Error ? e.message : String(e));
      });
    } else {
      // 切回网页模式：取消轮询，WebView 状态保留
      this.qrViewModel.cancel();
    }
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
