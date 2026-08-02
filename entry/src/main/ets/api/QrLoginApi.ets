/**
 * 知乎扫码登录 API 封装
 *
 * 复刻原 Android QrLogin.kt 的 3 个 HTTP 端点：
 * - prefetchQrLoginContext(): 预取 signin 页 + udid + captcha，建立会话上下文
 * - requestQrCode(): 获取二维码 token + link + expiresAt
 * - pollQrCodeLogin(): 轮询扫码状态，同步 Cookie，回调状态变化
 *
 * 协议要点（来自原 Android references/android/.../QrLogin.kt）：
 * - 端点：POST https://www.zhihu.com/api/v3/account/api/login/qrcode (body="{}")
 * - 轮询：GET https://www.zhihu.com/api/v3/account/api/login/qrcode/{token}/scan_info
 * - 请求头：桌面 UA + sec-ch-ua 系列 + Origin + x-requested-with + 可选 x-xsrftoken
 * - 状态判定：status==1 已扫码，z_c0 出现或 success 字段为登录成功，status==2 或 loginStatus=EXPIRED 为过期
 * - Cookie 同步：从 scan_info 的 cookie/cookies/zC0 字段解析写入 CookieJar
 * - 过期归一化：expiresAt 可能是 TTL（秒/毫秒）或绝对时间戳（秒/毫秒）
 *
 * 安全约束：Cookie/Token 不进日志；与 AuthApi 共用 NetworkClient + CookieJar。
 * ArkTS 严格模式：禁用 any/unknown，响应解析用 as 断言到显式可选 interface。
 */

import { NetworkClient, HttpResponse, GetRequestOptions, PostRequestOptions } from './NetworkClient';
import { CookieJar } from './CookieJar';
import { ZHIHU_WEB_UA } from './ZhihuConstants';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'QrLoginApi';

/** 知乎扫码登录相关 URL 常量（对齐原 Android QrLogin.kt） */
const ZHIHU_HOME_URL: string = 'https://www.zhihu.com/';
const ZHIHU_SIGNIN_URL: string = 'https://www.zhihu.com/signin?next=%2F';
const ZHIHU_SIGNIN_REFERER_URL: string = 'https://www.zhihu.com/signin';
const ZHIHU_RISK_CONTROL_URL: string = 'https://www.zhihu.com/account/risk_control/';
const UDID_URL: string = 'https://www.zhihu.com/udid';
const CAPTCHA_V2_URL: string = 'https://www.zhihu.com/api/v3/oauth/captcha/v2?type=captcha_sign_in';
const QRCODE_URL: string = 'https://www.zhihu.com/api/v3/account/api/login/qrcode';

/** 桌面 sec-ch-ua 请求头常量 */
const DESKTOP_SEC_CH_UA: string = '"Not:A-Brand";v="99", "Google Chrome";v="145", "Chromium";v="145"';
const DESKTOP_SEC_CH_UA_MOBILE: string = '?0';
const DESKTOP_SEC_CH_UA_PLATFORM: string = '"Windows"';

/** zse-93 版本号（与 AuthApi.ets 保持一致） */
const ZSE93_VERSION: string = '101_3_3.0';

/** 轮询间隔（ms） */
const POLL_INTERVAL_MS: number = 500;
/** 单次轮询请求超时（ms） */
const POLL_REQUEST_TIMEOUT_MS: number = 10000;
/** 默认二维码有效期（ms） */
const DEFAULT_QR_DEADLINE_MS: number = 120000;
/** 二维码 TTL 上限（秒） */
const MAX_QR_TTL_SECONDS: number = 86400;
/** 二维码 TTL 上限（ms） */
const MAX_QR_TTL_MS: number = MAX_QR_TTL_SECONDS * 1000;

/** 二维码响应原始对象形状（字段可选，对齐 ZhihuQrCodeResponse） */
interface RawQrCodeResponse {
  expires_at?: number;
  link?: string;
  token?: string;
  qrcode_token?: string;
}

/** 扫码状态响应中的 error 子对象 */
interface RawQrScanError {
  need_login?: boolean;
  redirect?: string;
  code?: number;
  message?: string;
}

/** 扫码状态响应原始对象形状（字段可选，对齐 ZhihuQrScanInfo） */
interface RawQrScanInfo {
  status?: number;
  cookie?: string;
  cookies?: string;
  z_c0?: string;
  zc0?: string;
  user_id?: string;
  access_token?: string;
  success?: boolean;
  logged_in?: boolean;
  login_status?: string;
  error?: RawQrScanError;
}

/** 二维码获取结果 */
export interface QrCodeResult {
  /** 二维码 token（用于轮询） */
  token: string;
  /** 二维码内容（用于 QRCode 组件渲染） */
  link: string;
  /** 过期时间戳（ms，绝对时间） */
  deadline: number;
}

/** 扫码轮询回调集合 */
export interface QrPollCallbacks {
  /**
   * 取消信号检查（每次轮询迭代前/后调用）。
   *
   * 返回 true 时轮询循环立即退出，避免 cancel() 后继续发起 HTTP 请求。
   * ViewModel 层通过版本号 + isCancelled 双重判断实现：
   * - isCancelled = true：用户主动取消（切换回网页模式）
   * - pollVersion 不匹配：新轮询已启动，旧轮询自动失效
   */
  isCancelled: () => boolean;
  /** 已扫码（status==1，仅触发一次） */
  onScanned: () => void;
  /** 触发风控（403 + error.code==40352 或 needLogin） */
  onRiskControl: (message: string, redirectUrl: string) => void;
}

/**
 * 判定扫码登录是否成功。
 *
 * 成功条件（任一满足）：
 * - user_id 存在
 * - access_token 非空
 * - success == true
 * - logged_in == true
 * - login_status 为 CONFIRMED/LOGIN_SUCCESS/SUCCESS/OK/LOGGED_IN 之一
 *
 * @param scanInfo 扫码状态响应
 * @returns true 表示登录成功
 */
export function isQrLoginSuccessful(scanInfo: RawQrScanInfo): boolean {
  if (scanInfo.user_id !== undefined || scanInfo.access_token !== undefined ||
    scanInfo.success === true || scanInfo.logged_in === true) {
    return true;
  }
  const loginStatus: string = scanInfo.login_status !== undefined ? scanInfo.login_status.toUpperCase() : '';
  return loginStatus === 'CONFIRMED' || loginStatus === 'LOGIN_SUCCESS' ||
    loginStatus === 'SUCCESS' || loginStatus === 'OK' || loginStatus === 'LOGGED_IN';
}

/**
 * 判定二维码是否已过期。
 *
 * 过期条件（任一满足）：
 * - status == 2
 * - login_status 为 EXPIRED/QR_CODE_EXPIRED/LOGIN_EXPIRED 之一
 *
 * @param scanInfo 扫码状态响应
 * @returns true 表示已过期
 */
export function isQrLoginExpired(scanInfo: RawQrScanInfo): boolean {
  const loginStatus: string = scanInfo.login_status !== undefined ? scanInfo.login_status.toUpperCase() : '';
  return scanInfo.status === 2 || loginStatus === 'EXPIRED' ||
    loginStatus === 'QR_CODE_EXPIRED' || loginStatus === 'LOGIN_EXPIRED';
}

/**
 * 判定响应是否为风控。
 *
 * 风控条件：HTTP 403 + (error.code == 40352 或 error.need_login == true)
 *
 * @param statusCode HTTP 状态码
 * @param scanInfo 扫码状态响应
 * @returns true 表示触发风控
 */
export function isRiskControlResponse(statusCode: number, scanInfo: RawQrScanInfo): boolean {
  const error: RawQrScanError | undefined = scanInfo.error;
  if (error === undefined) {
    return false;
  }
  return statusCode === 403 && (error.code === 40352 || error.need_login === true);
}

/**
 * 归一化过期时间为绝对时间戳（ms）。
 *
 * expires_at 可能的语义（原 Android normalizeDeadline 逻辑）：
 * - null/0/负数 → 默认 120s 后过期
 * - 小于当前秒数 → 当作 TTL（秒或毫秒）
 *   - <= 86400 → 秒，now + expiresAt * 1000
 *   - <= 86400000 → 毫秒，now + expiresAt
 *   - 否则 → 默认 120s
 * - 大于当前秒数但小于 10^10 → 秒级时间戳，expiresAt * 1000
 * - 大于 10^10 → 毫秒级时间戳
 *
 * @param expiresAt 二维码响应的 expires_at 字段
 * @returns 绝对时间戳（ms）
 */
export function normalizeDeadline(expiresAt: number | undefined): number {
  const now: number = Date.now();
  if (expiresAt === undefined || expiresAt <= 0) {
    return now + DEFAULT_QR_DEADLINE_MS;
  }
  const nowSeconds: number = Math.floor(now / 1000);
  if (expiresAt < nowSeconds) {
    // 当作 TTL
    if (expiresAt <= MAX_QR_TTL_SECONDS) {
      return now + expiresAt * 1000;
    } else if (expiresAt <= MAX_QR_TTL_MS) {
      return now + expiresAt;
    } else {
      return now + DEFAULT_QR_DEADLINE_MS;
    }
  } else if (expiresAt < 10000000000) {
    // 秒级时间戳
    return expiresAt * 1000;
  } else {
    // 毫秒级时间戳
    return expiresAt;
  }
}

/**
 * 从 scan_info 响应同步 Cookie 到 CookieJar。
 *
 * 解析 scan_info 的 cookie/cookies/z_c0/zc0 字段：
 * - cookie/cookies：分号分隔的 cookie 字符串（如 "z_c0=xxx; d_c0=yyy"）
 * - z_c0/zc0：直接是 z_c0 值（向后兼容）
 *
 * @param cookieJar Cookie 管理器
 * @param scanInfo 扫码状态响应
 */
export function syncCookiesFromScanInfo(cookieJar: CookieJar, scanInfo: RawQrScanInfo): void {
  // 合并 cookie 和 cookies 字段
  const parts: string[] = [];
  if (typeof scanInfo.cookie === 'string' && scanInfo.cookie.length > 0) {
    parts.push(scanInfo.cookie);
  }
  if (typeof scanInfo.cookies === 'string' && scanInfo.cookies.length > 0) {
    parts.push(scanInfo.cookies);
  }
  const rawCookie: string = parts.join(';');
  if (rawCookie.length > 0) {
    parseCookieAssignments(rawCookie).forEach((value: string, key: string) => {
      cookieJar.setCookie(key, value);
    });
  }
  // z_c0 字段直接写入（向后兼容原 Android zC0 字段）
  const zc0Value: string | undefined = scanInfo.z_c0 !== undefined ? scanInfo.z_c0 : scanInfo.zc0;
  if (typeof zc0Value === 'string' && zc0Value.length > 0) {
    cookieJar.setCookie('z_c0', zc0Value);
  }
}

/**
 * 解析 cookie 赋值字符串为 Map。
 *
 * 格式：name1=value1;name2=value2;Attr=value3（跳过 Cookie 属性）
 *
 * @param rawCookie 原始 cookie 字符串
 * @returns 解析后的 cookie 键值对
 */
export function parseCookieAssignments(rawCookie: string): Map<string, string> {
  const result: Map<string, string> = new Map<string, string>();
  const skipAttributes: Set<string> = new Set<string>([
    'Domain', 'Path', 'Expires', 'Max-Age', 'HttpOnly', 'Secure', 'SameSite'
  ]);
  const items: string[] = rawCookie.split(';');
  for (let i: number = 0; i < items.length; i++) {
    const item: string = items[i].trim();
    const eqIdx: number = item.indexOf('=');
    if (eqIdx <= 0) {
      continue;
    }
    const name: string = item.substring(0, eqIdx).trim();
    if (name.length === 0 || skipAttributes.has(name)) {
      continue;
    }
    const value: string = item.substring(eqIdx + 1).trim();
    if (value.length === 0) {
      continue;
    }
    result.set(name, value);
  }
  return result;
}

/**
 * 知乎扫码登录 API 封装类。
 */
export class QrLoginApi {
  private client: NetworkClient;
  private cookieJar: CookieJar;

  constructor() {
    this.client = new NetworkClient();
    this.cookieJar = CookieJar.getInstance();
  }

  /**
   * 预取扫码登录上下文。
   *
   * 依次请求：
   * 1. GET /signin（获取 _xsrf 等 cookie）
   * 2. POST /udid (body="{}")（获取 d_c0）
   * 3. GET /api/v3/oauth/captcha/v2?type=captcha_sign_in（触发验证码上下文）
   *
   * 任何一步失败都不抛异常（原 Android runCatching 行为），仅打日志。
   */
  async prefetchQrLoginContext(): Promise<void> {
    // Step 1: GET /signin
    try {
      const signinOptions: GetRequestOptions = {
        url: ZHIHU_SIGNIN_URL,
        headers: this.buildDesktopHeaders(ZHIHU_HOME_URL),
        onSetCookie: (setCookie: string) => {
          this.cookieJar.updateFromSetCookie(setCookie);
        }
      };
      await this.client.get(signinOptions);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'prefetch signin failed: %{public}s',
        e instanceof Error ? e.message : String(e));
    }

    // Step 2: POST /udid
    try {
      const udidOptions: PostRequestOptions = {
        url: UDID_URL,
        headers: this.buildLoginHeaders(ZHIHU_SIGNIN_REFERER_URL, false),
        body: '{}',
        onSetCookie: (setCookie: string) => {
          this.cookieJar.updateFromSetCookie(setCookie);
        }
      };
      await this.client.post(udidOptions);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'prefetch udid failed: %{public}s',
        e instanceof Error ? e.message : String(e));
    }

    // Step 3: GET captcha
    try {
      const captchaOptions: GetRequestOptions = {
        url: CAPTCHA_V2_URL,
        headers: this.buildLoginHeaders(ZHIHU_SIGNIN_REFERER_URL, false),
        onSetCookie: (setCookie: string) => {
          this.cookieJar.updateFromSetCookie(setCookie);
        }
      };
      await this.client.get(captchaOptions);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'prefetch captcha failed: %{public}s',
        e instanceof Error ? e.message : String(e));
    }
  }

  /**
   * 请求二维码。
   *
   * POST https://www.zhihu.com/api/v3/account/api/login/qrcode (body="{}")
   * 返回 { token, link, expires_at }。
   *
   * @returns 二维码结果（token + link + deadline）
   * @throws IllegalStateException token/link 为空或 HTTP >= 400
   */
  async requestQrCode(): Promise<QrCodeResult> {
    const options: PostRequestOptions = {
      url: QRCODE_URL,
      headers: this.buildLoginHeaders(ZHIHU_SIGNIN_REFERER_URL, false),
      body: '{}',
      onSetCookie: (setCookie: string) => {
        this.cookieJar.updateFromSetCookie(setCookie);
      }
    };

    const res: HttpResponse = await this.client.post(options);
    const raw: RawQrCodeResponse = this.parseQrCodeResponse(res.body);
    const token: string | undefined = raw.token !== undefined ? raw.token : raw.qrcode_token;
    const link: string | undefined = raw.link;

    if (res.statusCode >= 400 || token === undefined || token.length === 0 ||
      link === undefined || link.length === 0) {
      throw new IllegalStateException(`二维码获取失败：${res.statusCode}`);
    }

    const deadline: number = normalizeDeadline(raw.expires_at);
    return { token, link, deadline };
  }

  /**
   * 轮询扫码登录状态。
   *
   * 每 POLL_INTERVAL_MS 轮询一次，单次超时 POLL_REQUEST_TIMEOUT_MS：
   * - status==1 → 触发 onScanned（仅一次）
   * - z_c0 出现或登录成功字段 → 返回 true
   * - 过期状态或超过 deadline → 返回 false
   * - 403 风控 → 触发 onRiskControl 并返回 false
   * - 临时网络错误 → 继续轮询
   *
   * @param token 二维码 token
   * @param deadline 截止时间戳（ms）
   * @param callbacks 状态回调
   * @returns true 表示登录成功；false 表示过期或风控
   */
  async pollQrCodeLogin(
    token: string,
    deadline: number,
    callbacks: QrPollCallbacks
  ): Promise<boolean> {
    let hasPromptedConfirm: boolean = false;
    let hasPromptedRiskControl: boolean = false;

    while (Date.now() <= deadline) {
      // 取消检查：用户切换模式或启动新轮询时立即退出
      if (callbacks.isCancelled()) {
        return false;
      }
      try {
        const pollUrl: string = `${QRCODE_URL}/${token}/scan_info`;
        const options: GetRequestOptions = {
          url: pollUrl,
          headers: this.buildLoginHeaders(ZHIHU_SIGNIN_URL, true),
          connectTimeout: POLL_REQUEST_TIMEOUT_MS,
          readTimeout: POLL_REQUEST_TIMEOUT_MS,
          onSetCookie: (setCookie: string) => {
            this.cookieJar.updateFromSetCookie(setCookie);
          }
        };
        const res: HttpResponse = await this.client.get(options);
        const scanInfo: RawQrScanInfo = this.parseScanInfo(res.body);

        // 403 风控
        if (res.statusCode === 403) {
          const errMsg: string = scanInfo.error !== undefined && scanInfo.error.message !== undefined
            ? scanInfo.error.message
            : '知乎限制了当前网络环境的登录请求，请先完成网络环境验证。';
          const redirectUrl: string = scanInfo.error !== undefined && scanInfo.error.redirect !== undefined
            ? scanInfo.error.redirect
            : ZHIHU_RISK_CONTROL_URL;
          if (!hasPromptedRiskControl) {
            hasPromptedRiskControl = true;
            callbacks.onRiskControl(errMsg, redirectUrl);
          }
          return false;
        }

        // 同步 Cookie
        syncCookiesFromScanInfo(this.cookieJar, scanInfo);

        // 风控判定
        if (isRiskControlResponse(res.statusCode, scanInfo)) {
          if (!hasPromptedRiskControl) {
            hasPromptedRiskControl = true;
            const msg: string = scanInfo.error !== undefined && scanInfo.error.message !== undefined
              ? scanInfo.error.message
              : '知乎需要验证当前网络环境';
            const redirect: string = scanInfo.error !== undefined && scanInfo.error.redirect !== undefined
              ? scanInfo.error.redirect
              : ZHIHU_RISK_CONTROL_URL;
            callbacks.onRiskControl(msg, redirect);
          }
          return false;
        }

        // 已扫码
        if (scanInfo.status === 1 && !hasPromptedConfirm) {
          hasPromptedConfirm = true;
          callbacks.onScanned();
        }

        // 过期
        if (isQrLoginExpired(scanInfo)) {
          return false;
        }

        // 成功
        const loginSucceeded: boolean = isQrLoginSuccessful(scanInfo);
        if (loginSucceeded || this.cookieJar.hasZc0()) {
          return true;
        }
      } catch (e) {
        // 临时网络抖动，继续轮询
        hilog.warn(DOMAIN, TAG, 'poll transient error: %{public}s',
          e instanceof Error ? e.message : String(e));
      }

      // 等待下一次轮询
      await this.delay(POLL_INTERVAL_MS);
      // 延迟后再次检查取消信号（避免 cancel 后还要等完整延迟周期）
      if (callbacks.isCancelled()) {
        return false;
      }
    }

    return false;
  }

  /**
   * 构造桌面浏览器请求头（基础版本，不含登录专用字段）。
   *
   * @param referer Referer 头（可选）
   * @returns 请求头对象
   */
  private buildDesktopHeaders(referer: string | undefined): Record<string, string> {
    const headers: Record<string, string> = {
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'en-US,en;q=0.9',
      'User-Agent': ZHIHU_WEB_UA,
      'sec-ch-ua': DESKTOP_SEC_CH_UA,
      'sec-ch-ua-mobile': DESKTOP_SEC_CH_UA_MOBILE,
      'sec-ch-ua-platform': DESKTOP_SEC_CH_UA_PLATFORM
    };
    if (referer !== undefined && referer.length > 0) {
      headers['Referer'] = referer;
    }
    return headers;
  }

  /**
   * 构造登录专用请求头。
   *
   * 在桌面头基础上追加：
   * - Origin
   * - x-requested-with: fetch
   * - content-type: application/json;charset=UTF-8
   * - x-xsrftoken（若有 _xsrf cookie）
   * - 轮询时附加 sec-fetch-* 和 x-zse-93
   *
   * @param referer Referer 头
   * @param isPolling 是否为轮询请求
   * @returns 请求头对象
   */
  private buildLoginHeaders(referer: string, isPolling: boolean): Record<string, string> {
    const headers: Record<string, string> = this.buildDesktopHeaders(referer);
    headers['Origin'] = ZHIHU_HOME_URL.replace(/\/$/, '');
    headers['x-requested-with'] = 'fetch';
    headers['content-type'] = 'application/json;charset=UTF-8';
    if (isPolling) {
      headers['Accept'] = '*/*';
      headers['sec-fetch-dest'] = 'empty';
      headers['sec-fetch-mode'] = 'cors';
      headers['sec-fetch-site'] = 'same-origin';
      headers['x-zse-93'] = ZSE93_VERSION;
    }
    const xsrf: string | undefined = this.cookieJar.getXsrf();
    if (xsrf !== undefined) {
      headers['x-xsrftoken'] = xsrf;
    }
    // 附带 Cookie
    const cookieHeader: string = this.cookieJar.buildCookieHeader();
    if (cookieHeader.length > 0) {
      headers['Cookie'] = cookieHeader;
    }
    return headers;
  }

  /**
   * 解析二维码响应 JSON。
   *
   * @param body 响应体
   * @returns 解析后的对象（字段可选）
   */
  private parseQrCodeResponse(body: string): RawQrCodeResponse {
    if (body.length === 0) {
      return {};
    }
    try {
      const raw: object = JSON.parse(body);
      return raw as RawQrCodeResponse;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'parseQrCodeResponse failed: %{public}s',
        e instanceof Error ? e.message : String(e));
      return {};
    }
  }

  /**
   * 解析扫码状态响应 JSON。
   *
   * @param body 响应体
   * @returns 解析后的对象（字段可选）
   */
  private parseScanInfo(body: string): RawQrScanInfo {
    if (body.length === 0) {
      return {};
    }
    try {
      const raw: object = JSON.parse(body);
      return raw as RawQrScanInfo;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'parseScanInfo failed: %{public}s',
        e instanceof Error ? e.message : String(e));
      return {};
    }
  }

  /**
   * 延迟工具函数。
   *
   * @param ms 延迟毫秒数
   */
  private delay(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, ms);
    });
  }
}

/**
 * 自定义异常：非法状态（二维码获取失败时抛出）。
 * 继承 Error 以保持与原 Android IllegalStateException 语义一致。
 */
class IllegalStateException extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'IllegalStateException';
  }
}
