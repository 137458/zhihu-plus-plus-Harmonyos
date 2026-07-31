/**
 * Cookie 管理器
 *
 * 单例模式，管理知乎 Web 端的 Cookie 集合：
 * - d_c0：设备标识（匿名访问时获取）
 * - z_c0：登录核心凭证（登录后获取，空值不写入防覆盖）
 * - _xsrf：CSRF token（二维码登录用，本批预留）
 * - q_c0：子账号 cookie（账号切换时获取，本批预留）
 *
 * 设计：
 * - 用 Map<string, string> 存储所有 cookie
 * - 空值 z_c0 不写入（防覆盖，参考证据 01 §5 issue #25）
 * - 域名过滤：仅接受 *.zhihu.com（由调用方解析 Set-Cookie 头后传入）
 * - 提供 Cookie 头拼接方法
 *
 * 安全约束：Cookie 不进入日志、源码、普通 preferences；
 * 持久化由 AssetStore 负责（加密存储到 Asset Store Kit）。
 */

/**
 * 从 Set-Cookie 头字符串中提取指定 Cookie 的值
 *
 * Set-Cookie 格式示例：
 *   "d_c0=AAB1234; Path=/; HttpOnly; Secure; SameSite=Lax"
 *   "z_c0=Bearer xxx; Path=/; HttpOnly"
 *
 * @param setCookieHeader Set-Cookie 头字符串
 * @param name Cookie 名称（如 'd_c0'）
 * @returns Cookie 值；不存在返回 undefined
 */
export function extractCookie(setCookieHeader: string, name: string): string | undefined {
  // 用分号 + 空格分割，第一项是 "name=value"
  const parts: string[] = setCookieHeader.split(';');
  for (let i: number = 0; i < parts.length; i++) {
    const part: string = parts[i].trim();
    const eqIdx: number = part.indexOf('=');
    if (eqIdx > 0) {
      const key: string = part.substring(0, eqIdx).trim();
      const value: string = part.substring(eqIdx + 1).trim();
      if (key === name && value.length > 0) {
        return value;
      }
    }
  }
  return undefined;
}

/** 关键 Cookie 名称常量 */
const COOKIE_NAME_DC0: string = 'd_c0';
const COOKIE_NAME_ZC0: string = 'z_c0';
const COOKIE_NAME_XSRF: string = '_xsrf';
const COOKIE_NAME_QC0: string = 'q_c0';

/** 允许的 Cookie 名称集合（仅这些会被存储） */
const ALLOWED_COOKIE_NAMES: Set<string> = new Set<string>([
  COOKIE_NAME_DC0,
  COOKIE_NAME_ZC0,
  COOKIE_NAME_XSRF,
  COOKIE_NAME_QC0
]);

/**
 * Cookie 管理器
 *
 * 单例模式，管理 Cookie 的提取、存储和拼接。
 */
export class CookieJar {
  private static instance: CookieJar;
  /** Cookie 集合（key: cookie 名，value: cookie 值） */
  private cookies: Map<string, string>;

  private constructor() {
    // 私有构造函数，单例模式
    this.cookies = new Map<string, string>();
  }

  /** 获取单例 */
  static getInstance(): CookieJar {
    if (CookieJar.instance === undefined) {
      CookieJar.instance = new CookieJar();
    }
    return CookieJar.instance;
  }

  /**
   * 从 Set-Cookie 头字符串中提取并更新所有支持的 Cookie。
   *
   * 一次解析头字符串，提取所有已知 Cookie 名，
   * 避免对每个 Cookie 名重复分割字符串。
   * 对 z_c0 应用"空值不写入"规则。
   *
   * @param setCookieHeader Set-Cookie 头字符串
   */
  updateFromSetCookie(setCookieHeader: string): void {
    const parts: string[] = setCookieHeader.split(';');
    for (let i: number = 0; i < parts.length; i++) {
      const part: string = parts[i].trim();
      const eqIdx: number = part.indexOf('=');
      if (eqIdx > 0) {
        const key: string = part.substring(0, eqIdx).trim();
        const value: string = part.substring(eqIdx + 1).trim();
        if (ALLOWED_COOKIE_NAMES.has(key) && value.length > 0) {
          this.cookies.set(key, value);
        }
      }
    }
  }

  /**
   * 设置 Cookie 值。
   *
   * 对 z_c0 应用"空值不写入"规则（防止知乎返回空值覆盖已有登录态）。
   * 仅存储 ALLOWED_COOKIE_NAMES 中的 cookie。
   *
   * @param name Cookie 名称
   * @param value Cookie 值
   */
  setCookie(name: string, value: string): void {
    if (!ALLOWED_COOKIE_NAMES.has(name)) {
      return;
    }
    if (value.length === 0) {
      // 空值不写入（z_c0 空值会清空登录态，其他 cookie 空值也跳过）
      return;
    }
    this.cookies.set(name, value);
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

  // ===== d_c0 便捷方法（向后兼容） =====

  /**
   * 从 Set-Cookie 头字符串中提取 d_c0 并更新（向后兼容）。
   *
   * @param setCookieHeader Set-Cookie 头字符串
   */
  updateDc0FromSetCookie(setCookieHeader: string): void {
    const value: string | undefined = extractCookie(setCookieHeader, COOKIE_NAME_DC0);
    if (value !== undefined) {
      this.setCookie(COOKIE_NAME_DC0, value);
    }
  }

  /** 获取 d_c0 Cookie 值 */
  getDc0(): string | undefined {
    return this.cookies.get(COOKIE_NAME_DC0);
  }

  /** 设置 d_c0 Cookie 值（用于测试或冷启动会话恢复） */
  setDc0(value: string): void {
    this.setCookie(COOKIE_NAME_DC0, value);
  }

  /** 判断是否已有 d_c0 */
  hasDc0(): boolean {
    const value: string | undefined = this.cookies.get(COOKIE_NAME_DC0);
    return value !== undefined && value.length > 0;
  }

  // ===== z_c0 便捷方法 =====

  /**
   * 设置 z_c0 Cookie 值。
   *
   * 空值不写入（防止知乎返回空值清空登录态，参考证据 01 §5 issue #25）。
   *
   * @param value z_c0 Cookie 值
   */
  updateZc0(value: string): void {
    this.setCookie(COOKIE_NAME_ZC0, value);
  }

  /** 获取 z_c0 Cookie 值 */
  getZc0(): string | undefined {
    return this.cookies.get(COOKIE_NAME_ZC0);
  }

  /** 判断是否有 z_c0（登录核心凭证） */
  hasZc0(): boolean {
    const value: string | undefined = this.cookies.get(COOKIE_NAME_ZC0);
    return value !== undefined && value.length > 0;
  }

  // ===== _xsrf 便捷方法 =====

  /** 获取 _xsrf Cookie 值 */
  getXsrf(): string | undefined {
    return this.cookies.get(COOKIE_NAME_XSRF);
  }

  /** 判断是否有 _xsrf */
  hasXsrf(): boolean {
    const value: string | undefined = this.cookies.get(COOKIE_NAME_XSRF);
    return value !== undefined && value.length > 0;
  }

  // ===== q_c0 便捷方法 =====

  /** 获取 q_c0 Cookie 值 */
  getQc0(): string | undefined {
    return this.cookies.get(COOKIE_NAME_QC0);
  }

  // ===== 批量操作 =====

  /**
   * 从 Map 批量导入 Cookie（用于从 ZhihuSession 恢复）。
   *
   * @param cookies Cookie 集合
   */
  fromMap(cookies: Map<string, string>): void {
    cookies.forEach((value: string, key: string) => {
      this.setCookie(key, value);
    });
  }

  /**
   * 导出所有 Cookie 为 Map（用于持久化到 ZhihuSession）。
   *
   * @returns Cookie 集合的副本
   */
  toMap(): Map<string, string> {
    const result: Map<string, string> = new Map<string, string>();
    this.cookies.forEach((value: string, key: string) => {
      result.set(key, value);
    });
    return result;
  }

  /**
   * 构造 Cookie 请求头值。
   *
   * @returns Cookie 头字符串，如 "d_c0=AAB1234; z_c0=Bearer xxx"；无 cookie 返回空字符串
   */
  buildCookieHeader(): string {
    const parts: string[] = [];
    this.cookies.forEach((value: string, key: string) => {
      parts.push(`${key}=${value}`);
    });
    return parts.join('; ');
  }

  /**
   * 判断是否有任何 Cookie。
   */
  hasAnyCookie(): boolean {
    return this.cookies.size > 0;
  }

  /**
   * 清空所有 Cookie（用于退出登录或测试清理）。
   */
  clear(): void {
    this.cookies.clear();
  }
}
