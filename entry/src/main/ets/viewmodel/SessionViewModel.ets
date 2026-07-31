/**
 * 会话 ViewModel
 *
 * 单例模式，管理用户登录态的全局状态。
 * @ObservedV2 + @Trace 装饰确保 isLoggedIn / profile 变化触发 UI 刷新。
 *
 * 状态字段（@Trace 装饰，UI 观察）：
 * - isLoggedIn: 是否已登录
 * - profile: 用户资料（未登录时为 null）
 *
 * 核心流程：
 * - restoreSession(): 冷启动恢复（AssetStore 加载 → 验证 → 刷新或清除）
 * - setSession(session): 设置会话（来自 WebView 登录）
 * - logout(): 退出登录（清除 AssetStore + CookieJar + 状态）
 * - getVerifiedProfile(): 获取并更新用户资料
 *
 * 安全约束：Token/Cookie 不进日志；持久化由 AssetStore 负责。
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { ZhihuSession } from '../model/ZhihuSession';
import { ZhihuProfile } from '../model/ZhihuProfile';
import { AssetStore } from '../api/AssetStore';
import { AuthApi } from '../api/AuthApi';
import { CookieJar } from '../api/CookieJar';
import { NetworkClient } from '../api/NetworkClient';
import { ZHIHU_WEB_UA } from '../api/ZhihuConstants';

const DOMAIN: number = 0x0000;
const TAG: string = 'SessionViewModel';

/** 401 节流时间（ms）：10 秒内不重复刷新 */
const REFRESH_THROTTLE_MS: number = 10000;

@ObservedV2
export class SessionViewModel {
  /** 单例 */
  private static instance: SessionViewModel;

  /** 是否已登录 */
  @Trace isLoggedIn: boolean = false;
  /** 用户资料（未登录时为 null） */
  @Trace profile: ZhihuProfile | null = null;
  /**
   * 冷启动会话恢复是否已完成。
   *
   * EntryAbility 触发 restoreSession() 时设为 false，完成后设为 true。
   * Index.ets 路由守卫通过 @Monitor 监听此字段：
   * - 完成且未登录 → push LoginPage
   * - 完成且已登录 → 不跳转
   */
  @Trace isRestored: boolean = false;

  /** 当前会话（内存模型） */
  private session: ZhihuSession | null;
  private authApi: AuthApi;
  private assetStore: AssetStore;
  private cookieJar: CookieJar;
  /** 会话恢复进行中标志（防止重入） */
  private isRestoring: boolean = false;
  /** 上一次 401 刷新尝试的时间戳（用于节流） */
  private lastRefreshAttempt: number = 0;
  /**
   * 退出登录 UI 回调。
   *
   * 由 Index.ets 在约到 Appear 时设置，在 logout() 内部清理完成后调用，
   * 用于清理 WebView Cookie 和重置 NavPathStack。
   */
  private logoutCallback: (() => void) | null = null;

  private constructor() {
    this.authApi = new AuthApi();
    this.assetStore = AssetStore.getInstance();
    this.cookieJar = CookieJar.getInstance();
    this.session = null;
    // 注册 401 全局处理器：NetworkClient 遇到 401 时自动调用 refreshAndRetry
    NetworkClient.setUnauthorizedHandler(() => this.refreshAndRetry());
  }

  /** 获取单例 */
  static getInstance(): SessionViewModel {
    if (SessionViewModel.instance === undefined) {
      SessionViewModel.instance = new SessionViewModel();
    }
    return SessionViewModel.instance;
  }

  /**
   * 冷启动会话恢复。
   *
   * 流程：
   * 1. 从 AssetStore 加载持久化会话
   * 2. 若无会话 → 未登录态，返回
   * 3. 有会话 → 恢复 CookieJar，调用 fetchVerifiedSession 验证
   * 4. 验证成功 → 更新 profile，保存会话
   * 5. 验证失败 → 尝试 refreshToken + signIn 刷新
   * 6. 刷新成功 → 更新 token，保存会话
   * 7. 刷新失败 → 清除会话，进入未登录态
   */
  async restoreSession(): Promise<void> {
    // 防止重入：EntryAbility 与 HomePage 可能同时触发
    if (this.isRestoring) {
      hilog.info(DOMAIN, TAG, 'restoreSession: already in progress, skip');
      return;
    }
    this.isRestoring = true;
    try {
      // 1. 从 AssetStore 加载
      const stored: ZhihuSession | null = await this.assetStore.loadSession();
      if (stored === null) {
        hilog.info(DOMAIN, TAG, 'restoreSession: no stored session');
        return;
      }

      // 2. 恢复 CookieJar
      this.session = stored;
      this.cookieJar.fromMap(stored.cookies);

      // 3. 验证会话
      const verified: ZhihuSession | null = await this.authApi.fetchVerifiedSession(stored);
      if (verified !== null) {
        // 4. 验证成功
        this.session = verified;
        this.isLoggedIn = true;
        this.profile = verified.profile;
        await this.assetStore.saveSession(verified);
        hilog.info(DOMAIN, TAG, 'restoreSession: verified, logged in');
        return;
      }

      // 5. 验证失败，尝试刷新
      hilog.info(DOMAIN, TAG, 'restoreSession: verification failed, trying refresh');
      const refreshed: boolean = await this.tryRefreshTokens();
      if (refreshed) {
        // 6. 刷新成功
        this.isLoggedIn = true;
        hilog.info(DOMAIN, TAG, 'restoreSession: refresh succeeded, logged in');
        return;
      }

      // 7. 刷新失败，清除会话
      hilog.info(DOMAIN, TAG, 'restoreSession: refresh failed, clearing session');
      await this.clearSessionInternal();
    } finally {
      this.isRestoring = false;
      // 通知路由守卫：会话恢复已完成，可基于登录态决定是否跳转登录页
      this.isRestored = true;
    }
  }

  /**
   * 尝试刷新令牌（refreshToken + signIn）。
   *
   * @returns 刷新成功返回 true；失败返回 false
   */
  private async tryRefreshTokens(): Promise<boolean> {
    // 需要 z_c0 才能刷新
    if (!this.cookieJar.hasZc0()) {
      return false;
    }

    // Step 1: 刷新 refresh_token
    const newRefreshToken: string | null = await this.authApi.refreshToken();
    if (newRefreshToken === null) {
      hilog.info(DOMAIN, TAG, 'tryRefreshTokens: refreshToken failed');
      return false;
    }

    // Step 2: 用 refresh_token 换取 access_token
    const accessToken: string | null = await this.authApi.signIn(newRefreshToken);
    if (accessToken === null) {
      hilog.info(DOMAIN, TAG, 'tryRefreshTokens: signIn failed');
      return false;
    }

    // 更新会话
    if (this.session === null) {
      this.session = ZhihuSession.createEmpty(ZHIHU_WEB_UA);
    }
    this.session.accessToken = accessToken;
    this.session.refreshToken = newRefreshToken;
    this.session.isLoggedIn = true;
    this.session.lastRefreshMillis = Date.now();

    // 重新验证获取 profile
    const reverified: ZhihuSession | null = await this.authApi.fetchVerifiedSession(this.session);
    if (reverified !== null) {
      this.session = reverified;
      this.profile = reverified.profile;
    } else {
      // token 已刷新但 profile 获取失败，保留登录态但 profile 暂缺
      hilog.warn(DOMAIN, TAG, 'tryRefreshTokens: token refreshed but profile fetch failed');
    }

    // 保存更新后的会话
    await this.assetStore.saveSession(this.session);
    return true;
  }

  /**
   * 获取并更新用户资料。
   *
   * @returns 更新后的 ZhihuProfile；失败返回 null
   */
  async getVerifiedProfile(): Promise<ZhihuProfile | null> {
    if (this.session === null) {
      return null;
    }
    const verified: ZhihuSession | null = await this.authApi.fetchVerifiedSession(this.session);
    if (verified !== null && verified.profile !== null) {
      this.session = verified;
      this.profile = verified.profile;
      await this.assetStore.saveSession(verified);
      return verified.profile;
    }
    return null;
  }

  /**
   * 设置会话（来自 WebView 登录成功）。
   *
   * 同步更新内存状态和 CookieJar，并异步持久化到 AssetStore。
   * 持久化失败不影响登录流程（内存态已正确），仅打日志。
   *
   * @param session - 登录成功后的会话
   */
  setSession(session: ZhihuSession): void {
    this.session = session;
    this.isLoggedIn = session.isLoggedIn;
    this.profile = session.profile;
    // 同步 CookieJar
    this.cookieJar.fromMap(session.cookies);
    // 异步持久化，不阻塞调用方
    this.assetStore.saveSession(session).catch((e: object) => {
      hilog.error(DOMAIN, TAG, 'setSession save failed: %{public}s',
        e instanceof Error ? e.message : String(e));
    });
  }

  /**
   * 获取当前会话（内存模型）。
   *
   * @returns 当前 ZhihuSession；未初始化返回 null
   */
  getSession(): ZhihuSession | null {
    return this.session;
  }

  /**
   * 设置退出登录 UI 回调。
   *
   * 由 Index.ets 在约到 Appear 时设置，用于清理 WebView Cookie 和重置 NavPathStack。
   *
   * @param callback 退出后 UI 清理回调
   */
  setLogoutCallback(callback: (() => void) | null): void {
    this.logoutCallback = callback;
  }

  /**
   * 401 刷新令牌（含节流）。
   *
   * 由 NetworkClient 全局 unauthorizedHandler 在收到 401 时自动调用。
   * 节流规则：10 秒内已刷新过直接返回 false（避免连续 401 风暴）。
   *
   * 调用 tryRefreshTokens 内部流程：
   * 1. refreshToken() → 获取新 refresh_token
   * 2. signIn(refreshToken) → 换取 access_token
   * 3. fetchVerifiedSession() → 重新验证并获取 profile
   *
   * @returns 刷新成功返回 true；失败或节流返回 false
   */
  async refreshAndRetry(): Promise<boolean> {
    const now: number = Date.now();
    if (now - this.lastRefreshAttempt < REFRESH_THROTTLE_MS) {
      hilog.info(DOMAIN, TAG, 'refreshAndRetry: throttled');
      return false;
    }
    this.lastRefreshAttempt = now;

    // 需要 z_c0 才能刷新
    if (!this.cookieJar.hasZc0()) {
      return false;
    }

    return this.tryRefreshTokens();
  }

  /**
   * 退出登录。
   *
   * 清除 AssetStore、CookieJar 和内存会话状态。
   * 清理完成后调用 logoutCallback（由 Index.ets 设置，用于清理 WebView Cookie 和重置 NavPathStack）。
   */
  async logout(): Promise<void> {
    await this.clearSessionInternal();
    // 调用 UI 清理回调（WebView Cookie + 导航栈重置）
    const cb = this.logoutCallback;
    if (cb !== null) {
      cb();
    }
    hilog.info(DOMAIN, TAG, 'logout: session cleared');
  }

  /**
   * 内部清除会话方法。
   */
  private async clearSessionInternal(): Promise<void> {
    await this.assetStore.clearSession();
    this.cookieJar.clear();
    this.session = null;
    this.isLoggedIn = false;
    this.profile = null;
  }
}
