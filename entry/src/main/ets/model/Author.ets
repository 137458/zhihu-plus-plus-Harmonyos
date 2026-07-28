/**
 * 作者模型
 *
 * 对应知乎 API 的 author 或 Person 字段，表示内容的发布者。
 * 知乎 API 的作者字段使用 snake_case，本类对外暴露 camelCase。
 *
 * 注意：ArkTS 严格模式下 object 类型不允许直接属性访问，
 * fromObject 中使用 as 断言到 RawAuthor（所有字段可选）仅用于编译期属性访问，
 * 运行时类型安全由逐字段 typeof 校验保证。
 */

/** 知乎 API 原始 author 对象的形状（snake_case，内部使用） */
interface RawAuthor {
  id?: string;
  url_token?: string;
  name?: string;
  avatar_url?: string;
  headline?: string;
}

/** 作者信息 */
export class Author {
  /** 用户 ID */
  id: string;
  /** URL token（用于构建个人页 URL） */
  urlToken: string;
  /** 显示名称 */
  name: string;
  /** 头像 URL */
  avatarUrl: string;
  /** 一句话简介（可选） */
  headline?: string;

  constructor(id: string, urlToken: string, name: string, avatarUrl: string, headline?: string) {
    this.id = id;
    this.urlToken = urlToken;
    this.name = name;
    this.avatarUrl = avatarUrl;
    this.headline = headline;
  }

  /**
   * 从知乎响应对象解析作者信息。
   *
   * 字段映射：
   * - id ← raw.id（string）
   * - urlToken ← raw.url_token（string，snake_case）
   * - name ← raw.name（string）
   * - avatarUrl ← raw.avatar_url（string，snake_case）
   * - headline ← raw.headline（string，可选）
   *
   * @param raw - 知乎 API 响应中的 author 对象
   * @returns 解析后的 Author 实例；必填字段缺失或类型不匹配时返回 null
   */
  static fromObject(raw: object): Author | null {
    if (raw === null || raw === undefined) {
      return null;
    }
    const data: RawAuthor = raw as RawAuthor;

    const id: string | undefined = data.id;
    const urlToken: string | undefined = data.url_token;
    const name: string | undefined = data.name;
    const avatarUrl: string | undefined = data.avatar_url;

    if (typeof id !== 'string' ||
        typeof urlToken !== 'string' ||
        typeof name !== 'string' ||
        typeof avatarUrl !== 'string') {
      return null;
    }

    let headline: string | undefined = undefined;
    if (typeof data.headline === 'string') {
      headline = data.headline;
    }

    return new Author(id, urlToken, name, avatarUrl, headline);
  }
}
