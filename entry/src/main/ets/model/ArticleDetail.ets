/**
 * 文章详情模型
 *
 * 对应知乎 API `GET /api/v4/articles/{articleId}` 响应（专栏文章）。
 * 知乎 API 字段使用 snake_case，本类对外暴露 camelCase。
 *
 * 解析规则：
 * - 必填字段缺失返回 null：id, title, content, author
 * - 可选字段缺失用默认值：excerpt='', voteupCount=0, commentCount=0, ipInfo='', created=0, updated=0
 * - author 调用 Author.fromObject，失败返回 null
 * - topics 遍历数组调用 Topic.fromObject，过滤 null
 *
 * 注意：ArkTS 严格模式下 object 类型不允许直接属性访问，
 * fromObject 中使用 as 断言到 RawArticleDetail（所有字段可选）仅用于编译期属性访问，
 * 运行时类型安全由逐字段 typeof 校验保证。
 */

import { Author } from './Author';
import { Topic } from './Topic';

/** 知乎 API 原始文章详情响应形状（snake_case，内部使用） */
interface RawArticleDetail {
  id?: number;
  title?: string;
  content?: string;
  excerpt?: string;
  voteup_count?: number;
  comment_count?: number;
  author?: object;
  topics?: object[];
  ip_info?: string;
  created?: number;
  updated?: number;
}

/** 文章详情 */
export class ArticleDetail {
  /** 文章 ID */
  id: string;
  /** 文章标题 */
  title: string;
  /** 文章正文（HTML） */
  content: string;
  /** 摘要 */
  excerpt: string;
  /** 点赞数 */
  voteupCount: number;
  /** 评论数 */
  commentCount: number;
  /** 作者 */
  author: Author;
  /** 关联话题列表 */
  topics: Topic[];
  /** IP 属地 */
  ipInfo: string;
  /** 创建时间（Unix 时间戳，秒） */
  created: number;
  /** 更新时间（Unix 时间戳，秒） */
  updated: number;

  constructor(
    id: string,
    title: string,
    content: string,
    excerpt: string,
    voteupCount: number,
    commentCount: number,
    author: Author,
    topics: Topic[],
    ipInfo: string,
    created: number,
    updated: number
  ) {
    this.id = id;
    this.title = title;
    this.content = content;
    this.excerpt = excerpt;
    this.voteupCount = voteupCount;
    this.commentCount = commentCount;
    this.author = author;
    this.topics = topics;
    this.ipInfo = ipInfo;
    this.created = created;
    this.updated = updated;
  }

  /**
   * 从知乎响应对象解析文章详情。
   *
   * 字段映射：
   * - id ← raw.id（number 或 string，统一转为 string）
   * - title ← raw.title（string，必填）
   * - content ← raw.content（string，必填）
   * - excerpt ← raw.excerpt（string，可选，默认 ''）
   * - voteupCount ← raw.voteup_count（number，默认 0）
   * - commentCount ← raw.comment_count（number，默认 0）
   * - author ← Author.fromObject(raw.author)，失败返回 null
   * - topics ← 遍历 raw.topics 调用 Topic.fromObject，过滤 null
   * - ipInfo ← raw.ip_info（string，可选，默认 ''）
   * - created ← raw.created（number，默认 0）
   * - updated ← raw.updated（number，默认 0）
   *
   * @param raw - 知乎 API 响应中的文章详情对象
   * @returns 解析后的 ArticleDetail 实例；必填字段缺失或类型不匹配时返回 null
   */
  static fromObject(raw: object): ArticleDetail | null {
    if (raw === null || raw === undefined) {
      return null;
    }
    const data: RawArticleDetail = raw as RawArticleDetail;

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

    // author：必填
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

    // ipInfo：可选，默认 ''
    let ipInfo: string = '';
    if (typeof data.ip_info === 'string') {
      ipInfo = data.ip_info;
    }

    // 时间字段：可选，默认 0
    const created: number = typeof data.created === 'number' ? data.created : 0;
    const updated: number = typeof data.updated === 'number' ? data.updated : 0;

    return new ArticleDetail(
      id,
      title,
      content,
      excerpt,
      voteupCount,
      commentCount,
      author,
      topics,
      ipInfo,
      created,
      updated
    );
  }
}
