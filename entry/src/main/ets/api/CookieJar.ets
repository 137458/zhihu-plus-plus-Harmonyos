/**
 * Cookie 管理器
 *
 * 第 2 批只管理匿名 `d_c0` Cookie：
 * - 从响应 Set-Cookie 头中提取 d_c0
 * - 存内存（AppStorageV2 或单例），不持久化（第 4 批接入登录态时再持久化）
 * - 提供 Cookie 头拼接方法
 *
 * 注意：Token/Cookie 必须不进入日志。
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
  for (let i = 0; i < parts.length; i++) {
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

/**
 * Cookie 管理器
 *
 * 单例模式，管理 d_c0 Cookie 的提取、存储和拼接。
 * 第 4 批接入登录态时扩展为管理 z_c0 等。
 */
export class CookieJar {
  private static instance: CookieJar;
  /** 匿名 Cookie d_c0 */
  private dc0: string | undefined;

  private constructor() {
    // 私有构造函数，单例模式
  }

  /** 获取单例 */
  static getInstance(): CookieJar {
    if (CookieJar.instance === undefined) {
      CookieJar.instance = new CookieJar();
    }
    return CookieJar.instance;
  }

  /**
   * 从 Set-Cookie 头字符串中提取 d_c0 并更新
   *
   * @param setCookieHeader Set-Cookie 头字符串
   */
  updateFromSetCookie(setCookieHeader: string): void {
    const value: string | undefined = extractCookie(setCookieHeader, 'd_c0');
    if (value !== undefined) {
      this.dc0 = value;
    }
  }

  /**
   * 获取 d_c0 Cookie 值
   */
  getDc0(): string | undefined {
    return this.dc0;
  }

  /**
   * 设置 d_c0 Cookie 值（用于测试或第 4 批登录态恢复）
   */
  setDc0(value: string): void {
    this.dc0 = value;
  }

  /**
   * 判断是否已有 d_c0
   */
  hasDc0(): boolean {
    return this.dc0 !== undefined && this.dc0.length > 0;
  }

  /**
   * 构造 Cookie 请求头值
   *
   * @returns Cookie 头字符串，如 "d_c0=AAB1234"；无 d_c0 返回空字符串
   */
  buildCookieHeader(): string {
    if (this.dc0 !== undefined && this.dc0.length > 0) {
      return `d_c0=${this.dc0}`;
    }
    return '';
  }

  /**
   * 清空所有 Cookie（用于退出登录或测试清理）
   */
  clear(): void {
    this.dc0 = undefined;
  }
}
