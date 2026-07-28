/**
 * 首页卡片统一模型
 *
 * 从知乎 Feed API 的多态响应（Feed.Target）解析为扁平 UI 模型。
 * 知乎 API 的字段使用 snake_case，本类对外暴露 camelCase。
 *
 * 解析规则：
 * - type="answer"：title=target.question.title，author=target.author，voteupCount=target.voteup_count
 * - type="article"：title=target.title，author=target.author，voteupCount=target.voteup_count
 * - type="pin"：title="想法" 或 excerptTitle，author=target.author，voteupCount=target.like_count
 * - type="zvideo"：title=target.title，author=target.author，voteupCount=target.vote_count
 * - type="question"：title=target.title|name，author=target.author，voteupCount=0
 * - 其他/未知类型：返回 null
 *
 * 注意：ArkTS 严格模式下 object 类型不允许直接属性访问，
 * fromObject 中使用 as 断言到 RawFeedTarget（所有字段可选）仅用于编译期属性访问，
 * 运行时类型安全由逐字段 typeof 校验保证。
 */

import { Author } from './Author';
import { ContentType, ContentTypeUtil } from './ContentType';

/** 首页卡片模型 */
export class FeedCard {
  /** 稳定唯一 key（contentType + "_" + rawId），用于 LazyForEach 去重 */
  stableKey: string;
  /** 内容类型 */
  contentType: ContentType;
  /** 标题 */
  title: string;
  /** 摘要 */
  excerpt: string;
  /** 作者 */
  author: Author;
  /** 缩略图 URL（可选） */
  thumbnail?: string;
  /** 点赞数 */
  voteupCount: number;
  /** 评论数 */
  commentCount: number;
  /** 内容原始 ID（用于跳转详情页） */
  rawId: string;

  constructor(
    stableKey: string,
    contentType: ContentType,
    title: string,
    excerpt: string,
    author: Author,
    voteupCount: number,
    commentCount: number,
    rawId: string,
    thumbnail?: string
  ) {
    this.stableKey = stableKey;
    this.contentType = contentType;
    this.title = title;
    this.excerpt = excerpt;
    this.author = author;
    this.voteupCount = voteupCount;
    this.commentCount = commentCount;
    this.rawId = rawId;
    if (thumbnail !== undefined) {
      this.thumbnail = thumbnail;
    }
  }

  /**
   * 从知乎 Feed API 的 raw 响应对象解析 FeedCard。
   *
   * @param raw - Feed API 响应中的单个 feed 对象，形如 { type: "feed", target: { type: "answer", ... } }
   * @returns 解析后的 FeedCard 实例；类型未知或必填字段缺失返回 null
   */
  static fromObject(raw: object): FeedCard | null {
    if (raw === null || raw === undefined) {
      return null;
    }
    const feed: RawFeed = raw as RawFeed;
    const target: object | undefined = feed.target;
    if (target === undefined) {
      return null;
    }

    const targetTyped: RawFeedTarget = target as RawFeedTarget;
    const typeStr: string | undefined = targetTyped.type;
    if (typeof typeStr !== 'string') {
      return null;
    }

    const contentType: ContentType = ContentTypeUtil.fromString(typeStr);
    if (contentType === ContentType.UNKNOWN) {
      return null;
    }

    // 根据 contentType 提取字段
    let rawId: string | undefined;
    let title: string | undefined;
    let excerpt: string | undefined;
    let authorRaw: object | undefined;
    let thumbnail: string | undefined;
    let voteupCount: number = 0;
    let commentCount: number = 0;

    if (contentType === ContentType.ANSWER) {
      rawId = typeof targetTyped.id === 'number' ? String(targetTyped.id) : undefined;
      // answer 的 title 来自 question.title
      const question: object | undefined = targetTyped.question;
      if (question !== undefined) {
        const questionTyped: RawQuestion = question as RawQuestion;
        title = typeof questionTyped.title === 'string' ? questionTyped.title : undefined;
      }
      excerpt = typeof targetTyped.excerpt === 'string' ? targetTyped.excerpt : undefined;
      authorRaw = targetTyped.author;
      voteupCount = typeof targetTyped.voteup_count === 'number' ? targetTyped.voteup_count : 0;
      commentCount = typeof targetTyped.comment_count === 'number' ? targetTyped.comment_count : 0;
      if (typeof targetTyped.thumbnail === 'string') {
        thumbnail = targetTyped.thumbnail;
      }
    } else if (contentType === ContentType.ARTICLE) {
      rawId = typeof targetTyped.id === 'number' ? String(targetTyped.id) : undefined;
      title = typeof targetTyped.title === 'string' ? targetTyped.title : undefined;
      excerpt = typeof targetTyped.excerpt === 'string' ? targetTyped.excerpt : undefined;
      authorRaw = targetTyped.author;
      voteupCount = typeof targetTyped.voteup_count === 'number' ? targetTyped.voteup_count : 0;
      commentCount = typeof targetTyped.comment_count === 'number' ? targetTyped.comment_count : 0;
    } else if (contentType === ContentType.PIN) {
      rawId = typeof targetTyped.id === 'number' ? String(targetTyped.id) : undefined;
      // pin 的 title 固定为 "想法" 或用 excerptTitle
      const excerptTitle: string | undefined = targetTyped.excerpt_title;
      title = typeof excerptTitle === 'string' && excerptTitle.length > 0 ? excerptTitle : '想法';
      excerpt = typeof targetTyped.excerpt === 'string' ? targetTyped.excerpt : '';
      authorRaw = targetTyped.author;
      voteupCount = typeof targetTyped.like_count === 'number' ? targetTyped.like_count : 0;
      commentCount = typeof targetTyped.comment_count === 'number' ? targetTyped.comment_count : 0;
    } else if (contentType === ContentType.ZVIDEO) {
      rawId = typeof targetTyped.id === 'number' ? String(targetTyped.id) : undefined;
      title = typeof targetTyped.title === 'string' ? targetTyped.title : undefined;
      excerpt = typeof targetTyped.excerpt === 'string' ? targetTyped.excerpt : undefined;
      authorRaw = targetTyped.author;
      voteupCount = typeof targetTyped.vote_count === 'number' ? targetTyped.vote_count : 0;
      commentCount = typeof targetTyped.comment_count === 'number' ? targetTyped.comment_count : 0;
    } else if (contentType === ContentType.QUESTION) {
      rawId = typeof targetTyped.id === 'number' ? String(targetTyped.id) : undefined;
      title = typeof targetTyped.title === 'string'
        ? targetTyped.title
        : (typeof targetTyped.name === 'string' ? targetTyped.name : undefined);
      excerpt = typeof targetTyped.excerpt === 'string' ? targetTyped.excerpt : undefined;
      authorRaw = targetTyped.author;
      // question 没有 voteupCount，默认 0
      voteupCount = 0;
      commentCount = typeof targetTyped.comment_count === 'number' ? targetTyped.comment_count : 0;
    } else {
      return null;
    }

    // 必填字段校验
    if (rawId === undefined || title === undefined) {
      return null;
    }
    if (excerpt === undefined) {
      excerpt = '';
    }

    // 解析 author（author 可能为 null，但简化为必填，解析失败返回 null）
    let author: Author | null = null;
    if (authorRaw !== undefined) {
      author = Author.fromObject(authorRaw);
    }
    if (author === null) {
      return null;
    }

    const stableKey: string = contentType + '_' + rawId;
    return new FeedCard(
      stableKey,
      contentType,
      title,
      excerpt,
      author,
      voteupCount,
      commentCount,
      rawId,
      thumbnail
    );
  }
}

/** 知乎 API 原始 Feed 对象形状（snake_case，内部使用） */
interface RawFeed {
  type?: string;
  target?: object;
}

/** 知乎 API 原始 Feed.Target 对象形状（snake_case，内部使用） */
interface RawFeedTarget {
  type?: string;
  id?: number;
  title?: string;
  name?: string;
  excerpt?: string;
  author?: object;
  thumbnail?: string;
  voteup_count?: number;
  comment_count?: number;
  like_count?: number;
  vote_count?: number;
  excerpt_title?: string;
  question?: object;
}

/** 知乎 API 原始 Question 对象形状 */
interface RawQuestion {
  title?: string;
  name?: string;
}
