/**
 * 登录页 ViewModel
 *
 * 处理 WebView 登录流程的业务逻辑：
 * - 从 WebCookieManager 获取的 Cookie 字符串中提取 z_c0 等登录凭证
 * - 更新 CookieJar 并构造 ZhihuSession
 * - 调用 AuthApi.fetchVerifiedSession 验证会话并获取用户资料
 * - 通过 SessionViewModel.setSession 同步全局登录态
 *
 * 设计要点：
 * - 不持有 UI 引用，纯业务逻辑
 * - 所有 Cookie 操作通过 CookieJar 单例，与 AuthApi/SessionViewModel 共享
 * - 网络验证失败时仍保留登录态（Cookie 有效，仅 profile 缺失）
 *
 * 安全约束：Cookie/Token 不进入日志；setSession 由 SessionViewModel 异步持久化到 AssetStore。
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { webview } from '@kit.ArkWeb';
import { ZhihuSession } from '../model/ZhihuSession';
import { ZhihuProfile } from '../model/ZhihuProfile';
import { CookieJar } from '../api/CookieJar';
import { AuthApi } from '../api/AuthApi';
import { ZHIHU_WEB_UA } from '../api/ZhihuConstants';
import { SessionViewModel } from './SessionViewModel';

const DOMAIN: number = 0x0000;
const TAG: string = 'LoginViewModel';

/** 知乎登录页 URL（next=/ 表示登录后回到首页） */
export const ZHIHU_LOGIN_URL: string = 'https://www.zhihu.com/signin?next=%2F';

/** 知乎 Cookie 所属域名（用于 fetchCookieSync） */
export const ZHIHU_COOKIE_URL: string = 'https://www.zhihu.com';

// ZHIHU_WEB_UA 从 api/ZhihuConstants.ets 导入，避免跨模块重复定义
// 通过 re-export 保持向后兼容（LoginPage.ets 已从本模块导入 ZHIHU_WEB_UA）
export { ZHIHU_WEB_UA };

/**
 * 登录页 ViewModel。
 *
 * 使用方式：
 * 1. 在 LoginPage.aboutToAppear 中调用 setCustomUserAgent 设置桌面 UA
 * 2. Web 组件加载 ZHIHU_LOGIN_URL
 * 3. onPageEnd 时调用 detectLoginFromCookies 检测登录态
 * 4. 返回 true 表示登录成功，调用方 pop 返回上一页
 */
export class LoginViewModel {
  private sessionViewModel: SessionViewModel;
  private cookieJar: CookieJar;
  private authApi: AuthApi;

  constructor() {
    this.sessionViewModel = SessionViewModel.getInstance();
    this.cookieJar = CookieJar.getInstance();
    this.authApi = new AuthApi();
  }

  /**
   * 设置 WebView 全局 User-Agent 为桌面 UA。
   *
   * 知乎 Web 端会根据 UA 返回桌面或移动端登录页，
   * 必须使用桌面 UA 才能获取到完整功能的登录页。
   *
   * 实现说明：
   * - 使用静态方法 setAppCustomUserAgent，全局生效，无需关联具体 Web 组件
   * - setCustomUserAgent 是实例方法，要求 controller 已绑定 Web 组件，
   *   不适合在 aboutToAppear 阶段（Web 组件尚未构建完成）调用
   * - 必须在 UI 线程调用，本方法应在组件 aboutToAppear 中调用
   *
   * @param userAgent 桌面 UA 字符串
   */
  setCustomUserAgent(userAgent: string): void {
    try {
      webview.WebviewController.setAppCustomUserAgent(userAgent);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'setAppCustomUserAgent failed: %{public}s',
        e instanceof Error ? e.message : String(e));
    }
  }

  /**
   * 从 WebCookieManager 提取 Cookie 并检测登录态。
   *
   * 流程：
   * 1. 调用 fetchCookieSync 获取 https://www.zhihu.com 的所有 cookie
   * 2. 解析 cookie 字符串并更新 CookieJar
   * 3. 检查是否含有 z_c0（登录核心凭证）
   * 4. 无 z_c0 → 返回 false（未登录）
   * 5. 有 z_c0 → 构造 ZhihuSession，调用 fetchVerifiedSession 验证
   * 6. 验证成功 → setSession(verified) 同步全局状态
   * 7. 验证失败 → 仍 setSession（Cookie 有效，profile 暂缺）
   *
   * @param userAgent 当前 WebView 使用的 UA（持久化到会话）
   * @returns true 表示检测到登录凭证并已同步会话；false 表示未登录
   */
  async detectLoginFromCookies(userAgent: string): Promise<boolean> {
    // Step 1: 同步获取 Cookie 字符串
    let cookieString: string = '';
    try {
      cookieString = webview.WebCookieManager.fetchCookieSync(ZHIHU_COOKIE_URL);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'fetchCookieSync failed: %{public}s',
        e instanceof Error ? e.message : String(e));
      return false;
    }

    if (cookieString.length === 0) {
      hilog.info(DOMAIN, TAG, 'detectLogin: empty cookie, not logged in');
      return false;
    }

    // Step 2: 解析并更新 CookieJar
    this.updateCookieJarFromString(cookieString);

    // Step 3: 检查 z_c0
    if (!this.cookieJar.hasZc0()) {
      hilog.info(DOMAIN, TAG, 'detectLogin: no z_c0, not logged in');
      return false;
    }

    // Step 4: 构造 ZhihuSession
    const session: ZhihuSession = new ZhihuSession(
      true,
      userAgent,
      this.cookieJar.toMap(),
      null,
      null,
      null,
      Date.now()
    );

    // Step 5: 调用 fetchVerifiedSession 验证并获取 profile
    const verified: ZhihuSession | null = await this.authApi.fetchVerifiedSession(session);
    if (verified !== null) {
      // Step 6: 验证成功
      this.sessionViewModel.setSession(verified);
      hilog.info(DOMAIN, TAG, 'detectLogin: verified, logged in');
      return true;
    }

    // Step 7: 验证失败但 Cookie 有效，仍保留登录态（profile 暂缺）
    hilog.warn(DOMAIN, TAG, 'detectLogin: z_c0 present but verification failed, keep login state');
    this.sessionViewModel.setSession(session);
    return true;
  }

  /**
   * 解析 cookie 字符串并更新 CookieJar。
   *
   * Cookie 字符串格式形如：
   *   "d_c0=AAA; z_c0=Bearer xxx; _xsrf=yyy; other=zzz"
   * 每条 cookie 之间用 "; " 分隔。
   *
   * 仅允许的 cookie 名会被存储（CookieJar 内部过滤）。
   *
   * @param cookieString WebCookieManager.fetchCookieSync 返回的字符串
   */
  private updateCookieJarFromString(cookieString: string): void {
    const parts: string[] = cookieString.split(';');
    for (let i: number = 0; i < parts.length; i++) {
      const part: string = parts[i].trim();
      if (part.length === 0) {
        continue;
      }
      const eqIdx: number = part.indexOf('=');
      if (eqIdx <= 0) {
        continue;
      }
      const key: string = part.substring(0, eqIdx).trim();
      const value: string = part.substring(eqIdx + 1).trim();
      if (key.length > 0 && value.length > 0) {
        // CookieJar.setCookie 内部会过滤 ALLOWED_COOKIE_NAMES 并应用"空值不写入"规则
        this.cookieJar.setCookie(key, value);
      }
    }
  }

  /**
   * 清理 WebView 全局 Cookie（用于退出登录）。
   *
   * 调用 WebCookieManager.clearAllCookiesSync 清空所有 Web 组件的 cookie。
   * 注意：必须在 UI 线程调用。
   *
   * @returns true 表示清理成功；false 表示清理失败
   */
  clearWebCookies(): boolean {
    try {
      webview.WebCookieManager.clearAllCookiesSync();
      hilog.info(DOMAIN, TAG, 'clearWebCookies: cleared');
      return true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'clearAllCookiesSync failed: %{public}s',
        e instanceof Error ? e.message : String(e));
      return false;
    }
  }

  /**
   * 获取当前会话的用户资料（供 UI 显示）。
   *
   * @returns 当前 ZhihuProfile；未登录返回 null
   */
  getProfile(): ZhihuProfile | null {
    return this.sessionViewModel.profile;
  }
}
