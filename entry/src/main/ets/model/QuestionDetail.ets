/**
 * 问题详情模型
 *
 * 对应知乎 API `GET /api/v4/questions/{questionId}` 响应。
 * 知乎 API 字段使用 snake_case，本类对外暴露 camelCase。
 *
 * 解析规则：
 * - 必填字段缺失返回 null：id, title, author
 * - 可选字段缺失用默认值：detail='', excerpt=''
 * - author 调用 Author.fromObject，失败返回 null
 * - topics 遍历数组调用 Topic.fromObject，过滤 null
 *
 * 注意：ArkTS 严格模式下 object 类型不允许直接属性访问，
 * fromObject 中使用 as 断言到 RawQuestionDetail（所有字段可选）仅用于编译期属性访问，
 * 运行时类型安全由逐字段 typeof 校验保证。
 */

import { Author } from './Author';
import { Topic } from './Topic';

/** 知乎 API 原始问题详情响应形状（snake_case，内部使用） */
interface RawQuestionDetail {
  id?: number;
  title?: string;
  detail?: string;
  excerpt?: string;
  answer_count?: number;
  visit_count?: number;
  comment_count?: number;
  follower_count?: number;
  voteup_count?: number;
  author?: object;
  topics?: object[];
}

/** 问题详情 */
export class QuestionDetail {
  /** 问题 ID */
  id: string;
  /** 问题标题 */
  title: string;
  /** 问题描述（HTML） */
  detail: string;
  /** 摘要 */
  excerpt: string;
  /** 回答数 */
  answerCount: number;
  /** 浏览数 */
  visitCount: number;
  /** 评论数 */
  commentCount: number;
  /** 关注数 */
  followerCount: number;
  /** 点赞数 */
  voteupCount: number;
  /** 作者 */
  author: Author;
  /** 关联话题列表 */
  topics: Topic[];

  constructor(
    id: string,
    title: string,
    detail: string,
    excerpt: string,
    answerCount: number,
    visitCount: number,
    commentCount: number,
    followerCount: number,
    voteupCount: number,
    author: Author,
    topics: Topic[]
  ) {
    this.id = id;
    this.title = title;
    this.detail = detail;
    this.excerpt = excerpt;
    this.answerCount = answerCount;
    this.visitCount = visitCount;
    this.commentCount = commentCount;
    this.followerCount = followerCount;
    this.voteupCount = voteupCount;
    this.author = author;
    this.topics = topics;
  }

  /**
   * 从知乎响应对象解析问题详情。
   *
   * 字段映射：
   * - id ← raw.id（number 或 string，统一转为 string）
   * - title ← raw.title（string，必填）
   * - detail ← raw.detail（string，可选，默认 ''）
   * - excerpt ← raw.excerpt（string，可选，默认 ''）
   * - answerCount ← raw.answer_count（number，默认 0）
   * - visitCount ← raw.visit_count（number，默认 0）
   * - commentCount ← raw.comment_count（number，默认 0）
   * - followerCount ← raw.follower_count（number，默认 0）
   * - voteupCount ← raw.voteup_count（number，默认 0）
   * - author ← Author.fromObject(raw.author)，失败返回 null
   * - topics ← 遍历 raw.topics 调用 Topic.fromObject，过滤 null
   *
   * @param raw - 知乎 API 响应中的问题详情对象
   * @returns 解析后的 QuestionDetail 实例；必填字段缺失或类型不匹配时返回 null
   */
  static fromObject(raw: object): QuestionDetail | null {
    if (raw === null || raw === undefined) {
      return null;
    }
    const data: RawQuestionDetail = raw as RawQuestionDetail;

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

    // title：必填
    const title: string | undefined = data.title;
    if (typeof title !== 'string') {
      return null;
    }

    // detail：可选，默认 ''
    let detail: string = '';
    if (typeof data.detail === 'string') {
      detail = data.detail;
    }

    // excerpt：可选，默认 ''
    let excerpt: string = '';
    if (typeof data.excerpt === 'string') {
      excerpt = data.excerpt;
    }

    // 数值字段：可选，默认 0
    const answerCount: number = typeof data.answer_count === 'number' ? data.answer_count : 0;
    const visitCount: number = typeof data.visit_count === 'number' ? data.visit_count : 0;
    const commentCount: number = typeof data.comment_count === 'number' ? data.comment_count : 0;
    const followerCount: number = typeof data.follower_count === 'number' ? data.follower_count : 0;
    const voteupCount: number = typeof data.voteup_count === 'number' ? data.voteup_count : 0;

    // author：必填，调用 Author.fromObject
    const authorRaw: object | undefined = data.author;
    if (authorRaw === undefined) {
      return null;
    }
    const author: Author | null = Author.fromObject(authorRaw);
    if (author === null) {
      return null;
    }

    // topics：可选，缺省为空数组；遍历过滤 null
    const topics: Topic[] = [];
    const topicsRaw: object[] | undefined = data.topics;
    if (topicsRaw !== undefined && Array.isArray(topicsRaw)) {
      for (let i = 0; i < topicsRaw.length; i++) {
        const topic: Topic | null = Topic.fromObject(topicsRaw[i]);
        if (topic !== null) {
          topics.push(topic);
        }
      }
    }

    return new QuestionDetail(
      id,
      title,
      detail,
      excerpt,
      answerCount,
      visitCount,
      commentCount,
      followerCount,
      voteupCount,
      author,
      topics
    );
  }
}
