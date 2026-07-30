/**
 * 会话内存模型
 *
 * 表示用户的登录会话状态，包含登录态、User-Agent、Cookie 集合、
 * Token、用户资料和刷新时间戳。
 *
 * 序列化格式（JSON）：
 * {
 *   "isLoggedIn": boolean,
 *   "userAgent": string,
 *   "cookies": { "z_c0": "...", "d_c0": "...", "_xsrf": "..." },
 *   "accessToken": string | null,
 *   "refreshToken": string | null,
 *   "profile": { "id": "...", "name": "...", ... } | null,
 *   "lastRefreshMillis": number
 * }
 *
 * 注意：ArkTS 严格模式下 Map 不能直接 JSON.stringify，故 cookies 用对象形式存储。
 *
 * 安全约束：Token/Cookie 仅存 Asset Store Kit（加密），不进日志/源码/普通 KV。
 */

import { ZhihuProfile } from './ZhihuProfile';

/** 知乎 API 原始 session 对象形状（内部使用，所有字段可选） */
interface RawZhihuSession {
  isLoggedIn?: boolean;
  userAgent?: string;
  cookies?: Record<string, string>;
  accessToken?: string;
  refreshToken?: string;
  profile?: object;
  lastRefreshMillis?: number;
}

/** toObject 返回的 JSON 兼容对象形状（用于持久化） */
interface ZhihuSessionObject {
  isLoggedIn: boolean;
  userAgent: string;
  cookies: Record<string, string>;
  accessToken: string | null;
  refreshToken: string | null;
  profile: object | null;
  lastRefreshMillis: number;
}

/** 会话状态 */
export class ZhihuSession {
  /** 是否已登录 */
  isLoggedIn: boolean;
  /** User-Agent（Web 端） */
  userAgent: string;
  /** Cookie 集合（key: cookie 名，value: cookie 值） */
  cookies: Map<string, string>;
  /** 访问令牌（可选） */
  accessToken: string | null;
  /** 刷新令牌（可选） */
  refreshToken: string | null;
  /** 用户资料（可选，未登录或未验证时为 null） */
  profile: ZhihuProfile | null;
  /** 上次刷新时间戳（毫秒，用于节流） */
  lastRefreshMillis: number;

  constructor(
    isLoggedIn: boolean,
    userAgent: string,
    cookies: Map<string, string>,
    accessToken: string | null,
    refreshToken: string | null,
    profile: ZhihuProfile | null,
    lastRefreshMillis: number
  ) {
    this.isLoggedIn = isLoggedIn;
    this.userAgent = userAgent;
    this.cookies = cookies;
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    this.profile = profile;
    this.lastRefreshMillis = lastRefreshMillis;
  }

  /**
   * 创建空会话（未登录默认状态）。
   *
   * @param userAgent 默认 User-Agent
   * @returns 空会话实例
   */
  static createEmpty(userAgent: string): ZhihuSession {
    return new ZhihuSession(
      false,
      userAgent,
      new Map<string, string>(),
      null,
      null,
      null,
      0
    );
  }

  /**
   * 从 JSON 字符串解析会话。
   *
   * @param jsonStr - JSON 格式字符串
   * @returns 解析后的 ZhihuSession 实例；解析失败返回 null
   */
  static fromJson(jsonStr: string): ZhihuSession | null {
    if (jsonStr.length === 0) {
      return null;
    }
    try {
      const raw: object = JSON.parse(jsonStr);
      return ZhihuSession.fromObject(raw);
    } catch (e) {
      return null;
    }
  }

  /**
   * 从原始对象解析会话。
   *
   * @param raw - 原始对象（来自 JSON.parse）
   * @returns 解析后的 ZhihuSession 实例；必填字段缺失返回 null
   */
  static fromObject(raw: object): ZhihuSession | null {
    if (raw === null || raw === undefined) {
      return null;
    }
    const data: RawZhihuSession = raw as RawZhihuSession;

    const isLoggedIn: boolean = typeof data.isLoggedIn === 'boolean' ? data.isLoggedIn : false;
    const userAgent: string = typeof data.userAgent === 'string' ? data.userAgent : '';
    const lastRefreshMillis: number = typeof data.lastRefreshMillis === 'number' ? data.lastRefreshMillis : 0;

    // 解析 cookies（从对象转 Map）
    // ArkTS 严格模式禁止索引访问 rawCookies[key]，用 Object.entries 遍历
    const cookies: Map<string, string> = new Map<string, string>();
    if (data.cookies !== null && data.cookies !== undefined && typeof data.cookies === 'object') {
      const rawCookies: Record<string, string> = data.cookies as Record<string, string>;
      const entries: [string, Object][] = Object.entries(rawCookies);
      for (let i: number = 0; i < entries.length; i++) {
        const entry: [string, Object] = entries[i];
        const key: string = entry[0];
        const value: Object = entry[1];
        if (typeof value === 'string' && value.length > 0) {
          cookies.set(key, value);
        }
      }
    }

    // 解析 accessToken
    const accessToken: string | null = typeof data.accessToken === 'string' && data.accessToken.length > 0
      ? data.accessToken
      : null;

    // 解析 refreshToken
    const refreshToken: string | null = typeof data.refreshToken === 'string' && data.refreshToken.length > 0
      ? data.refreshToken
      : null;

    // 解析 profile
    let profile: ZhihuProfile | null = null;
    if (data.profile !== null && data.profile !== undefined && typeof data.profile === 'object') {
      profile = ZhihuProfile.fromObject(data.profile);
    }

    return new ZhihuSession(
      isLoggedIn,
      userAgent,
      cookies,
      accessToken,
      refreshToken,
      profile,
      lastRefreshMillis
    );
  }

  /**
   * 序列化为 JSON 字符串（用于持久化到 Asset Store）。
   *
   * @returns JSON 格式字符串
   */
  toJson(): string {
    return JSON.stringify(this.toObject());
  }

  /**
   * 序列化为 JSON 兼容对象。
   *
   * cookies 从 Map 转为对象形式，便于 JSON.stringify。
   *
   * @returns 包含所有字段的对象
   */
  toObject(): ZhihuSessionObject {
    // 将 Map<string, string> 转为对象形式
    const cookiesObj: Record<string, string> = {};
    this.cookies.forEach((value: string, key: string) => {
      cookiesObj[key] = value;
    });

    return {
      isLoggedIn: this.isLoggedIn,
      userAgent: this.userAgent,
      cookies: cookiesObj,
      accessToken: this.accessToken,
      refreshToken: this.refreshToken,
      profile: this.profile !== null ? this.profile.toObject() : null,
      lastRefreshMillis: this.lastRefreshMillis
    };
  }

  /**
   * 获取指定 Cookie 值。
   *
   * @param name Cookie 名称
   * @returns Cookie 值；不存在返回 undefined
   */
  getCookie(name: string): string | undefined {
    return this.cookies.get(name);
  }

  /**
   * 设置 Cookie 值。
   *
   * @param name Cookie 名称
   * @param value Cookie 值
   */
  setCookie(name: string, value: string): void {
    this.cookies.set(name, value);
  }

  /**
   * 判断是否有登录核心凭证 z_c0。
   */
  hasZc0(): boolean {
    const zc0: string | undefined = this.cookies.get('z_c0');
    return zc0 !== undefined && zc0.length > 0;
  }

  /**
   * 构建 Cookie 请求头字符串。
   *
   * @returns Cookie 头字符串，如 "d_c0=xxx; z_c0=yyy"
   */
  buildCookieHeader(): string {
    const parts: string[] = [];
    this.cookies.forEach((value: string, key: string) => {
      parts.push(`${key}=${value}`);
    });
    return parts.join('; ');
  }
}
