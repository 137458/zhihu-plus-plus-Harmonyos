/**
 * 话题模型
 *
 * 对应知乎 API 中的 topics 数组项，表示问题/文章关联的话题。
 * 知乎 API 字段使用 snake_case，本类对外暴露 camelCase。
 *
 * 注意：ArkTS 严格模式下 object 类型不允许直接属性访问，
 * fromObject 中使用 as 断言到 RawTopic（所有字段可选）仅用于编译期属性访问，
 * 运行时类型安全由逐字段 typeof 校验保证。
 */

/** 知乎 API 原始 topic 对象的形状（snake_case，内部使用） */
interface RawTopic {
  id?: string;
  name?: string;
  avatar_url?: string;
}

/** 话题信息 */
export class Topic {
  /** 话题 ID */
  id: string;
  /** 话题名称 */
  name: string;
  /** 话题头像 URL（可选） */
  avatarUrl?: string;

  constructor(id: string, name: string, avatarUrl?: string) {
    this.id = id;
    this.name = name;
    if (avatarUrl !== undefined) {
      this.avatarUrl = avatarUrl;
    }
  }

  /**
   * 从知乎响应对象解析话题信息。
   *
   * 字段映射：
   * - id ← raw.id（string）
   * - name ← raw.name（string）
   * - avatarUrl ← raw.avatar_url（string，可选）
   *
   * @param raw - 知乎 API 响应中的 topic 对象
   * @returns 解析后的 Topic 实例；必填字段缺失或类型不匹配时返回 null
   */
  static fromObject(raw: object): Topic | null {
    if (raw === null || raw === undefined) {
      return null;
    }
    const data: RawTopic = raw as RawTopic;

    const id: string | undefined = data.id;
    const name: string | undefined = data.name;

    if (typeof id !== 'string' || typeof name !== 'string') {
      return null;
    }

    let avatarUrl: string | undefined = undefined;
    if (typeof data.avatar_url === 'string') {
      avatarUrl = data.avatar_url;
    }

    return new Topic(id, name, avatarUrl);
  }
}
