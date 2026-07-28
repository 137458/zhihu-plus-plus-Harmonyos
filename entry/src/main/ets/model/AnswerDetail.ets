/**
 * 回答详情模型
 *
 * 对应知乎 API `GET /api/v4/answers/{answerId}` 响应。
 * 知乎 API 字段使用 snake_case，本类对外暴露 camelCase。
 *
 * 解析规则：
 * - 必填字段缺失返回 null：id, content, author, question
 * - 可选字段缺失用默认值：excerpt='', ipInfo='', thanksCount=0, voteupCount=0, commentCount=0, createdTime=0, updatedTime=0
 * - author 调用 Author.fromObject，失败返回 null
 * - question 调用 AnswerDetailQuestion.fromObject，失败返回 null（question 必填）
 *
 * 注意：ArkTS 严格模式下 object 类型不允许直接属性访问，
 * fromObject 中使用 as 断言到 RawAnswerDetail（所有字段可选）仅用于编译期属性访问，
 * 运行时类型安全由逐字段 typeof 校验保证。
 */

import { Author } from './Author';
import { AnswerDetailQuestion } from './AnswerDetailQuestion';

/** 知乎 API 原始回答详情响应形状（snake_case，内部使用） */
interface RawAnswerDetail {
  id?: number;
  content?: string;
  excerpt?: string;
  voteup_count?: number;
  comment_count?: number;
  thanks_count?: number;
  author?: object;
  question?: object;
  ip_info?: string;
  created_time?: number;
  updated_time?: number;
}

/** 回答详情 */
export class AnswerDetail {
  /** 回答 ID */
  id: string;
  /** 回答正文（HTML） */
  content: string;
  /** 摘要 */
  excerpt: string;
  /** 点赞数 */
  voteupCount: number;
  /** 评论数 */
  commentCount: number;
  /** 感谢数 */
  thanksCount: number;
  /** 作者 */
  author: Author;
  /** 内嵌的问题信息（必填） */
  question: AnswerDetailQuestion;
  /** IP 属地 */
  ipInfo: string;
  /** 创建时间（Unix 时间戳，秒） */
  createdTime: number;
  /** 更新时间（Unix 时间戳，秒） */
  updatedTime: number;

  constructor(
    id: string,
    content: string,
    excerpt: string,
    voteupCount: number,
    commentCount: number,
    thanksCount: number,
    author: Author,
    question: AnswerDetailQuestion,
    ipInfo: string,
    createdTime: number,
    updatedTime: number
  ) {
    this.id = id;
    this.content = content;
    this.excerpt = excerpt;
    this.voteupCount = voteupCount;
    this.commentCount = commentCount;
    this.thanksCount = thanksCount;
    this.author = author;
    this.question = question;
    this.ipInfo = ipInfo;
    this.createdTime = createdTime;
    this.updatedTime = updatedTime;
  }

  /**
   * 从知乎响应对象解析回答详情。
   *
   * 字段映射：
   * - id ← raw.id（number 或 string，统一转为 string）
   * - content ← raw.content（string，必填）
   * - excerpt ← raw.excerpt（string，可选，默认 ''）
   * - voteupCount ← raw.voteup_count（number，默认 0）
   * - commentCount ← raw.comment_count（number，默认 0）
   * - thanksCount ← raw.thanks_count（number，默认 0）
   * - author ← Author.fromObject(raw.author)，失败返回 null
   * - question ← AnswerDetailQuestion.fromObject(raw.question)，失败返回 null（question 必填）
   * - ipInfo ← raw.ip_info（string，可选，默认 ''）
   * - createdTime ← raw.created_time（number，默认 0）
   * - updatedTime ← raw.updated_time（number，默认 0）
   *
   * @param raw - 知乎 API 响应中的回答详情对象
   * @returns 解析后的 AnswerDetail 实例；必填字段缺失或类型不匹配时返回 null
   */
  static fromObject(raw: object): AnswerDetail | null {
    if (raw === null || raw === undefined) {
      return null;
    }
    const data: RawAnswerDetail = raw as RawAnswerDetail;

    // id：number 或 string，统一转为 string
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

    // excerpt：可选，默认 ''
    let excerpt: string = '';
    if (typeof data.excerpt === 'string') {
      excerpt = data.excerpt;
    }

    // 数值字段：可选，默认 0
    const voteupCount: number = typeof data.voteup_count === 'number' ? data.voteup_count : 0;
    const commentCount: number = typeof data.comment_count === 'number' ? data.comment_count : 0;
    const thanksCount: number = typeof data.thanks_count === 'number' ? data.thanks_count : 0;

    // author：必填
    const authorRaw: object | undefined = data.author;
    if (authorRaw === undefined) {
      return null;
    }
    const author: Author | null = Author.fromObject(authorRaw);
    if (author === null) {
      return null;
    }

    // question：必填，调用 AnswerDetailQuestion.fromObject
    const questionRaw: object | undefined = data.question;
    if (questionRaw === undefined) {
      return null;
    }
    const question: AnswerDetailQuestion | null = AnswerDetailQuestion.fromObject(questionRaw);
    if (question === null) {
      return null;
    }

    // ipInfo：可选，默认 ''
    let ipInfo: string = '';
    if (typeof data.ip_info === 'string') {
      ipInfo = data.ip_info;
    }

    // 时间字段：可选，默认 0
    const createdTime: number = typeof data.created_time === 'number' ? data.created_time : 0;
    const updatedTime: number = typeof data.updated_time === 'number' ? data.updated_time : 0;

    return new AnswerDetail(
      id,
      content,
      excerpt,
      voteupCount,
      commentCount,
      thanksCount,
      author,
      question,
      ipInfo,
      createdTime,
      updatedTime
    );
  }
}
