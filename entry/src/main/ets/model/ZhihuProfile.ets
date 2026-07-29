/**
 * 用户资料模型
 *
 * 对应知乎 API /api/v4/me 的响应字段。
 * 知乎 API 使用 snake_case，本类对外暴露 camelCase。
 *
 * 字段映射：
 * - id ← raw.id
 * - name ← raw.name
 * - urlToken ← raw.url_token
 * - avatarUrl ← raw.avatar_url
 * - userType ← raw.user_type
 *
 * 注意：ArkTS 严格模式下 object 类型不允许直接属性访问，
 * fromObject 中使用 as 断言到 RawZhihuProfile（所有字段可选）仅用于编译期属性访问，
 * 运行时类型安全由逐字段 typeof 校验保证。
 */

/** 知乎 API 原始 /api/v4/me 对象的形状（snake_case，内部使用） */
interface RawZhihuProfile {
  id?: string;
  name?: string;
  url_token?: string;
  avatar_url?: string;
  user_type?: string;
}

/** 用户资料 */
export class ZhihuProfile {
  /** 用户 ID */
  id: string;
  /** 显示名称 */
  name: string;
  /** URL token（用于构建个人页 URL） */
  urlToken: string;
  /** 头像 URL */
  avatarUrl: string;
  /** 用户类型 */
  userType: string;

  constructor(id: string, name: string, urlToken: string, avatarUrl: string, userType: string) {
    this.id = id;
    this.name = name;
    this.urlToken = urlToken;
    this.avatarUrl = avatarUrl;
    this.userType = userType;
  }

  /**
   * 从知乎 /api/v4/me 响应对象解析用户资料。
   *
   * @param raw - 知乎 API 响应对象
   * @returns 解析后的 ZhihuProfile 实例；必填字段缺失或类型不匹配时返回 null
   */
  static fromObject(raw: object): ZhihuProfile | null {
    if (raw === null || raw === undefined) {
      return null;
    }
    const data: RawZhihuProfile = raw as RawZhihuProfile;

    const id: string | undefined = data.id;
    const name: string | undefined = data.name;
    const urlToken: string | undefined = data.url_token;
    const avatarUrl: string | undefined = data.avatar_url;
    const userType: string | undefined = data.user_type;

    if (typeof id !== 'string' ||
        typeof name !== 'string' ||
        typeof urlToken !== 'string' ||
        typeof avatarUrl !== 'string') {
      return null;
    }

    const resolvedUserType: string = typeof userType === 'string' ? userType : '';

    return new ZhihuProfile(id, name, urlToken, avatarUrl, resolvedUserType);
  }

  /**
   * 序列化为 JSON 兼容对象（用于持久化）。
   *
   * @returns 包含所有字段的对象字面量
   */
  toObject(): object {
    return {
      id: this.id,
      name: this.name,
      url_token: this.urlToken,
      avatar_url: this.avatarUrl,
      user_type: this.userType
    };
  }
}
