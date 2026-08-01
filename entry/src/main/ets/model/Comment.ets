/**
 * 评论数据模型
 *
 * 对应知乎 API 评论响应中的 Comment 对象。
 * 知乎 API 字段使用 snake_case，本类对外暴露 camelCase。
 *
 * 首发只读，不支持发表评论/子评论/点赞评论。
 * 关键字段参考 docs/evidence/04-interaction-and-profile.md §6 评论数据结构。
 *
 * 注意：ArkTS 严格模式下 object 类型不允许直接属性访问，
 * fromObject 中使用 as 断言到 RawComment（所有字段可选）仅用于编译期属性访问，
 * 运行时类型安全由逐字段 typeof 校验保证。
 */

import { Author } from './Author';

/** 知乎 API 原始评论对象形状（snake_case，内部使用） */
interface RawComment {
  id?: number;
  content?: string;
  created_time?: number;
  liked?: boolean;
  like_count?: number;
  child_comment_count?: number;
  author?: object;
  reply_to_author?: object;
  comment_tag?: object;
  is_author?: boolean;
  collapsed?: boolean;
  /** 点赞者头像 URL 列表（可选，用于评论点赞动画） */
  likes?: object[];
  /** 投票状态（可选） */
  voting?: number;
  /** 是否被折叠（可选） */
  is_delete?: boolean;
  /** 是否审核中 */
  reviewing?: boolean;
}

/** 被回复的作者信息 */
export interface ReplyToAuthor {
  id: string;
  name: string;
}

/** 评论标签 */
export interface CommentTag {
  /** 标签类型 */
  type: string;
  /** 标签文本 */
  text: string;
}

/** 评论 */
export class Comment {
  /** 评论 ID */
  id: string;
  /** 评论内容（HTML 格式） */
  content: string;
  /** 创建时间（Unix 时间戳，秒） */
  createdTime: number;
  /** 当前用户是否已点赞 */
  liked: boolean;
  /** 点赞数 */
  likeCount: number;
  /** 子评论数量 */
  childCommentCount: number;
  /** 作者 */
  author: Author;
  /** 被回复的作者（可选） */
  replyToAuthor?: ReplyToAuthor;
  /** 评论标签（可选，如"作者"） */
  commentTag?: CommentTag;
  /** 是否作者本人 */
  isAuthor: boolean;
  /** 是否被折叠 */
  collapsed: boolean;

  constructor(
    id: string,
    content: string,
    createdTime: number,
    liked: boolean,
    likeCount: number,
    childCommentCount: number,
    author: Author,
    replyToAuthor: ReplyToAuthor | undefined,
    commentTag: CommentTag | undefined,
    isAuthor: boolean,
    collapsed: boolean
  ) {
    this.id = id;
    this.content = content;
    this.createdTime = createdTime;
    this.liked = liked;
    this.likeCount = likeCount;
    this.childCommentCount = childCommentCount;
    this.author = author;
    this.replyToAuthor = replyToAuthor;
    this.commentTag = commentTag;
    this.isAuthor = isAuthor;
    this.collapsed = collapsed;
  }

  /**
   * 从知乎响应对象解析评论。
   *
   * @param raw - 知乎 API 响应中的评论对象
   * @returns 解析后的 Comment 实例；必填字段缺失返回 null
   */
  static fromObject(raw: object): Comment | null {
    if (raw === null || raw === undefined) {
      return null;
    }
    const data: RawComment = raw as RawComment;

    // id：必填
    let id: string | undefined;
    if (typeof data.id === 'number') {
      id = String(data.id);
    } else if (typeof data.id === 'string') {
      id = data.id;
    }
    if (id === undefined) {
      return null;
    }

    // content：必填
    const content: string | undefined = data.content;
    if (typeof content !== 'string') {
      return null;
    }

    // author：必填
    const authorRaw: object | undefined = data.author;
    if (authorRaw === undefined) {
      return null;
    }
    const author: Author | null = Author.fromObject(authorRaw);
    if (author === null) {
      return null;
    }

    // 数值字段：可选，默认值
    const createdTime: number = typeof data.created_time === 'number' ? data.created_time : 0;
    const likeCount: number = typeof data.like_count === 'number' ? data.like_count : 0;
    const childCommentCount: number = typeof data.child_comment_count === 'number' ? data.child_comment_count : 0;

    // 布尔字段：可选，默认值
    const liked: boolean = data.liked === true;
    const isAuthor: boolean = data.is_author === true;
    const collapsed: boolean = data.collapsed === true;

    // replyToAuthor：可选
    let replyToAuthor: ReplyToAuthor | undefined = undefined;
    const replyToAuthorRaw: object | undefined = data.reply_to_author;
    if (replyToAuthorRaw !== undefined) {
      replyToAuthor = parseReplyToAuthor(replyToAuthorRaw);
    }

    // commentTag：可选
    let commentTag: CommentTag | undefined = undefined;
    const commentTagRaw: object | undefined = data.comment_tag;
    if (commentTagRaw !== undefined) {
      commentTag = parseCommentTag(commentTagRaw);
    }

    return new Comment(
      id,
      content,
      createdTime,
      liked,
      likeCount,
      childCommentCount,
      author,
      replyToAuthor,
      commentTag,
      isAuthor,
      collapsed
    );
  }

  /**
   * 获取评论的稳定唯一 key（用于 ForEach）。
   */
  stableKey(): string {
    return 'comment_' + this.id;
  }
}

/**
 * 从原始对象解析 ReplyToAuthor。
 */
function parseReplyToAuthor(raw: object): ReplyToAuthor | undefined {
  if (raw === null || raw === undefined) {
    return undefined;
  }
  const data: Record<string, object> = raw as Record<string, object>;
  const idRaw: object = data['id'];
  const nameRaw: object = data['name'];
  const id: string = typeof idRaw === 'string' ? idRaw : (typeof idRaw === 'number' ? String(idRaw) : '');
  const name: string = typeof nameRaw === 'string' ? nameRaw : '';
  if (id.length === 0 || name.length === 0) {
    return undefined;
  }
  return { id: id, name: name };
}

/**
 * 从原始对象解析 CommentTag。
 */
function parseCommentTag(raw: object): CommentTag | undefined {
  if (raw === null || raw === undefined) {
    return undefined;
  }
  const data: Record<string, object> = raw as Record<string, object>;
  const typeRaw: object = data['type'];
  const textRaw: object = data['text'];
  const type: string = typeof typeRaw === 'string' ? typeRaw : '';
  const text: string = typeof textRaw === 'string' ? textRaw : '';
  if (type.length === 0 || text.length === 0) {
    return undefined;
  }
  return { type: type, text: text };
}

/**
 * 从数组解析评论列表。
 *
 * @param rawArray - 知乎 API 响应中的 data 数组
 * @returns 解析后的 Comment 列表（过滤 null）
 */
export function commentListFromArray(rawArray: object[]): Comment[] {
  const result: Comment[] = [];
  if (rawArray === null || rawArray === undefined) {
    return result;
  }
  for (let i = 0; i < rawArray.length; i++) {
    const comment: Comment | null = Comment.fromObject(rawArray[i]);
    if (comment !== null) {
      result.push(comment);
    }
  }
  return result;
}