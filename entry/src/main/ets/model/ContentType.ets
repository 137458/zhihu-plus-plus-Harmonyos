/**
 * 内容类型枚举
 *
 * 用于区分首页卡片和搜索结果的内容类型。
 * 对应知乎 API 中内容条目的 type 字段。
 *
 * 注意：ArkTS 枚举不支持静态方法，故将 fromString 放在 ContentTypeUtil 类上，
 * 与项目中 Breakpoint / BreakpointUtil 的模式保持一致。
 */

/** 内容类型 */
export enum ContentType {
  /** 回答 */
  ANSWER = 'answer',
  /** 文章（专栏） */
  ARTICLE = 'article',
  /** 问题 */
  QUESTION = 'question',
  /** 想法（Pin） */
  PIN = 'pin',
  /** 视频 */
  ZVIDEO = 'zvideo',
  /** 未知类型 */
  UNKNOWN = 'unknown'
}

/**
 * 内容类型工具类
 *
 * 提供 ContentType 枚举与字符串之间的转换方法。
 */
export class ContentTypeUtil {
  /**
   * 根据字符串返回对应的内容类型枚举值。
   *
   * @param value - 内容类型字符串（如 'answer'、'article' 等）
   * @returns 对应的 ContentType 枚举值；未知字符串返回 UNKNOWN
   */
  static fromString(value: string): ContentType {
    if (value === ContentType.ANSWER) {
      return ContentType.ANSWER;
    }
    if (value === ContentType.ARTICLE) {
      return ContentType.ARTICLE;
    }
    if (value === ContentType.QUESTION) {
      return ContentType.QUESTION;
    }
    if (value === ContentType.PIN) {
      return ContentType.PIN;
    }
    if (value === ContentType.ZVIDEO) {
      return ContentType.ZVIDEO;
    }
    return ContentType.UNKNOWN;
  }
}
