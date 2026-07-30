/**
 * 认证 API 封装层
 *
 * 提供会话验证和令牌刷新能力：
 * - fetchVerifiedSession(): GET /api/v4/me 验证登录态并获取用户资料
 * - refreshToken(): POST /api/account/prod/token/refresh 刷新 refresh_token
 * - signIn(refreshToken): POST /api/v3/oauth/sign_in 用 refresh_token 换取 access_token
 *
 * 安全约束：
 * - CLIENT_ID / CLIENT_SECRET 是知乎 Web 端公开常量（见证据 06-risk-register.md R019）
 * - access_token / refresh_token / z_c0 属于敏感凭据，存 Asset Store Kit
 * - 敏感信息不进入日志
 *
 * 签名构造（参考 Kotlin ZhihuCredentialRefresher）：
 *   message = grantType + clientId + source + timestamp
 *   signature = hmacSha1Hex(clientSecret, message)
 *   formData = urlEncode(各字段) 用 & 拼接
 *   encryptedBody = encryptZseV4(formData)
 */

import { NetworkClient, HttpResponse, GetRequestOptions, PostRequestOptions } from './NetworkClient';
import { CookieJar } from './CookieJar';
import { createZse96Header, hmacSha1Hex, encryptSignInPayload } from './ZseSigner';
import { ZhihuSession } from '../model/ZhihuSession';
import { ZhihuProfile } from '../model/ZhihuProfile';
import { ApiError } from '../model/ApiError';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'AuthApi';

/** 知乎 Web 端基础 URL */
const ZHIHU_WWW_BASE: string = 'https://www.zhihu.com';
/** /api/v4/me 路径 */
const ME_PATH: string = '/api/v4/me';
/** /api/account/prod/token/refresh 路径 */
const TOKEN_REFRESH_PATH: string = '/api/account/prod/token/refresh';
/** /api/v3/oauth/sign_in 路径 */
const SIGN_IN_PATH: string = '/api/v3/oauth/sign_in';

/**
 * Web UA（与 ZhihuApi.ets 保持一致；重复定义避免跨模块依赖，
 * 修改时需同步两处，后续可考虑抽取到公共常量文件）
 */
const ZHIHU_WEB_UA: string = 'Mozilla/5.0 (X11; U; Linux x86_64; en-US) AppleWebKit/540.0 (KHTML, like Gecko) Ubuntu/10.10 Chrome/9.1.0.0 Safari/540.0';

/** zse 签名版本号 */
const ZSE93_VERSION: string = '101_3_3.0';

/** OAuth 公开常量（知乎 Web 端硬编码，见证据 01-auth-and-session.md §4.3） */
const CLIENT_ID: string = 'c3cef7c66a1843f8b3a9e6a1e3160e20';
const CLIENT_SECRET: string = 'd1b964811afb40118a12068ff74a12f4';
const GRANT_TYPE: string = 'refresh_token';
const SOURCE: string = 'com.zhihu.web';

/** /api/v4/me 响应原始对象形状（内部使用） */
interface RawMeResponse {
  id?: string;
  name?: string;
  url_token?: string;
  avatar_url?: string;
  user_type?: string;
}

/** prod/token/refresh 响应原始对象形状（内部使用） */
interface RawTokenRefreshResponse {
  refresh_token?: string;
}

/** sign_in 响应原始对象形状（内部使用） */
interface RawSignInResponse {
  access_token?: string;
}

export class AuthApi {
  private client: NetworkClient;
  private cookieJar: CookieJar;

  constructor() {
    this.client = new NetworkClient();
    this.cookieJar = CookieJar.getInstance();
  }

  /**
   * 验证当前会话是否有效，并获取用户资料。
   *
   * GET https://www.zhihu.com/api/v4/me
   * - 200 → 解析 profile，构造带 profile 的 ZhihuSession 返回
   * - 401 或其他非 200 → 返回 null（不抛异常）
   *
   * @param session - 当前会话（用于提取 UA 和 Cookie）
   * @returns 带更新 profile 的 ZhihuSession；验证失败返回 null
   */
  async fetchVerifiedSession(session: ZhihuSession): Promise<ZhihuSession | null> {
    const url: string = ZHIHU_WWW_BASE + ME_PATH;
    const dc0: string | undefined = this.cookieJar.getDc0();
    const dc0Value: string = dc0 !== undefined ? dc0 : '';
    const zse96: string = createZse96Header(ZSE93_VERSION, url, dc0Value);
    const cookieHeader: string = this.cookieJar.buildCookieHeader();

    const headers: Record<string, string> = {
      'x-zse-96': zse96,
      'x-zse-93': ZSE93_VERSION,
      'Accept': 'application/json, text/plain, */*',
      'User-Agent': ZHIHU_WEB_UA,
      'x-requested-with': 'fetch'
    };
    if (cookieHeader.length > 0) {
      headers['Cookie'] = cookieHeader;
    }

    const options: GetRequestOptions = {
      url: url,
      headers: headers,
      onSetCookie: (setCookie: string) => {
        this.cookieJar.updateFromSetCookie(setCookie);
      }
    };

    try {
      const res: HttpResponse = await this.client.get(options);
      if (res.statusCode !== 200) {
        return null;
      }
      const profile: ZhihuProfile | null = this.parseMeResponse(res.body);
      if (profile === null) {
        return null;
      }
      // 构造带 profile 的会话
      const newSession: ZhihuSession = new ZhihuSession(
        true,
        session.userAgent,
        this.cookieJar.toMap(),
        session.accessToken,
        session.refreshToken,
        profile,
        Date.now()
      );
      return newSession;
    } catch (e) {
      // 401 或网络错误 → null
      if (e instanceof ApiError) {
        hilog.info(DOMAIN, TAG, 'fetchVerifiedSession failed: %{public}s', `${e.code}`);
      } else {
        hilog.error(DOMAIN, TAG, 'fetchVerifiedSession unexpected error: %{public}s',
          e instanceof Error ? e.message : String(e));
      }
      return null;
    }
  }

  /**
   * 刷新 refresh_token。
   *
   * POST https://www.zhihu.com/api/account/prod/token/refresh
   * - 无请求体，依赖 Cookie 中的 z_c0
   * - 返回新的 refresh_token
   *
   * @returns 新的 refresh_token；失败返回 null
   */
  async refreshToken(): Promise<string | null> {
    const url: string = ZHIHU_WWW_BASE + TOKEN_REFRESH_PATH;
    const cookieHeader: string = this.cookieJar.buildCookieHeader();

    const headers: Record<string, string> = {
      'Content-Type': 'application/x-www-form-urlencoded',
      'User-Agent': ZHIHU_WEB_UA,
      'x-requested-with': 'fetch'
    };
    if (cookieHeader.length > 0) {
      headers['Cookie'] = cookieHeader;
    }

    const options: PostRequestOptions = {
      url: url,
      headers: headers,
      body: '',
      onSetCookie: (setCookie: string) => {
        this.cookieJar.updateFromSetCookie(setCookie);
      }
    };

    try {
      const res: HttpResponse = await this.client.post(options);
      if (res.statusCode !== 200) {
        return null;
      }
      return this.parseRefreshTokenResponse(res.body);
    } catch (e) {
      if (e instanceof ApiError) {
        hilog.info(DOMAIN, TAG, 'refreshToken failed: %{public}s', `${e.code}`);
      } else {
        hilog.error(DOMAIN, TAG, 'refreshToken unexpected error: %{public}s',
          e instanceof Error ? e.message : String(e));
      }
      return null;
    }
  }

  /**
   * 用 refresh_token 换取 access_token。
   *
   * POST https://www.zhihu.com/api/v3/oauth/sign_in
   * - 请求体为 encryptZseV4 加密后的表单数据
   * - 签名：HMAC-SHA1(clientSecret, grantType + clientId + source + timestamp)
   * - 返回 access_token
   *
   * @param refreshToken - 上一步 refreshToken() 返回的 refresh_token
   * @returns access_token；失败返回 null
   */
  async signIn(refreshToken: string): Promise<string | null> {
    const url: string = ZHIHU_WWW_BASE + SIGN_IN_PATH;
    const timestamp: number = Date.now();

    // 构造签名
    const signMessage: string = GRANT_TYPE + CLIENT_ID + SOURCE + timestamp.toString();
    let signature: string;
    try {
      signature = hmacSha1Hex(CLIENT_SECRET, signMessage);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'hmacSha1Hex failed: %{public}s',
        e instanceof Error ? e.message : String(e));
      return null;
    }

    // 构造表单数据（URL 编码）
    const formData: string = this.buildSignInFormData(refreshToken, timestamp.toString(), signature);

    // 加密请求体
    let encryptedBody: string;
    try {
      encryptedBody = encryptSignInPayload(formData);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'encryptSignInPayload failed: %{public}s',
        e instanceof Error ? e.message : String(e));
      return null;
    }

    const cookieHeader: string = this.cookieJar.buildCookieHeader();
    const headers: Record<string, string> = {
      'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
      'Origin': ZHIHU_WWW_BASE,
      'Referer': ZHIHU_WWW_BASE + '/signin',
      'x-zse-83': '3_3.0',
      'x-requested-with': 'fetch',
      'User-Agent': ZHIHU_WEB_UA
    };
    if (cookieHeader.length > 0) {
      headers['Cookie'] = cookieHeader;
    }

    const options: PostRequestOptions = {
      url: url,
      headers: headers,
      body: encryptedBody,
      onSetCookie: (setCookie: string) => {
        this.cookieJar.updateFromSetCookie(setCookie);
      }
    };

    try {
      const res: HttpResponse = await this.client.post(options);
      if (res.statusCode !== 200) {
        return null;
      }
      return this.parseSignInResponse(res.body);
    } catch (e) {
      if (e instanceof ApiError) {
        hilog.info(DOMAIN, TAG, 'signIn failed: %{public}s', `${e.code}`);
      } else {
        hilog.error(DOMAIN, TAG, 'signIn unexpected error: %{public}s',
          e instanceof Error ? e.message : String(e));
      }
      return null;
    }
  }

  /**
   * 构造 sign_in 请求的表单数据。
   *
   * 格式：client_id=...&grant_type=refresh_token&timestamp=...&source=...&signature=...&refresh_token=...
   * 每个字段值用 encodeURIComponent 编码。
   *
   * @param refreshToken - refresh_token 值
   * @param timestamp - 毫秒时间戳字符串
   * @param signature - HMAC-SHA1 签名
   * @returns URL 编码的表单数据字符串
   */
  private buildSignInFormData(refreshToken: string, timestamp: string, signature: string): string {
    const parts: string[] = [];
    parts.push(`client_id=${encodeURIComponent(CLIENT_ID)}`);
    parts.push(`grant_type=${encodeURIComponent(GRANT_TYPE)}`);
    parts.push(`timestamp=${encodeURIComponent(timestamp)}`);
    parts.push(`source=${encodeURIComponent(SOURCE)}`);
    parts.push(`signature=${encodeURIComponent(signature)}`);
    parts.push(`refresh_token=${encodeURIComponent(refreshToken)}`);
    return parts.join('&');
  }

  /**
   * 解析 /api/v4/me 响应。
   *
   * @param body - 响应体字符串
   * @returns ZhihuProfile 实例；解析失败返回 null
   */
  private parseMeResponse(body: string): ZhihuProfile | null {
    if (body.length === 0) {
      return null;
    }
    try {
      const raw: object = JSON.parse(body);
      return ZhihuProfile.fromObject(raw);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'parseMeResponse JSON.parse failed: %{public}s',
        e instanceof Error ? e.message : String(e));
      return null;
    }
  }

  /**
   * 解析 prod/token/refresh 响应。
   *
   * @param body - 响应体字符串
   * @returns refresh_token 字符串；解析失败返回 null
   */
  private parseRefreshTokenResponse(body: string): string | null {
    if (body.length === 0) {
      return null;
    }
    try {
      const raw: object = JSON.parse(body);
      const data: RawTokenRefreshResponse = raw as RawTokenRefreshResponse;
      const token: string | undefined = data.refresh_token;
      if (typeof token === 'string' && token.length > 0) {
        return token;
      }
      return null;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'parseRefreshTokenResponse JSON.parse failed: %{public}s',
        e instanceof Error ? e.message : String(e));
      return null;
    }
  }

  /**
   * 解析 sign_in 响应。
   *
   * @param body - 响应体字符串
   * @returns access_token 字符串；解析失败返回 null
   */
  private parseSignInResponse(body: string): string | null {
    if (body.length === 0) {
      return null;
    }
    try {
      const raw: object = JSON.parse(body);
      const data: RawSignInResponse = raw as RawSignInResponse;
      const token: string | undefined = data.access_token;
      if (typeof token === 'string' && token.length > 0) {
        return token;
      }
      return null;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'parseSignInResponse JSON.parse failed: %{public}s',
        e instanceof Error ? e.message : String(e));
      return null;
    }
  }
}
