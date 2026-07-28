/**
 * 搜索结果模型
 *
 * 从知乎搜索 API 响应解析。搜索 API 返回 data 数组，每项可能是不同类型的内容。
 *
 * 注意：ArkTS 严格模式下 object 类型不允许直接属性访问，
 * fromObject 中使用 as 断言到 RawSearchResult（所有字段可选）仅用于编译期属性访问，
 * 运行时类型安全由逐字段 typeof 校验保证。
 */

import { Author } from './Author';

/** 搜索结果条目 */
export class SearchResultItem {
  /** 内容类型标识（answer/article/question/zvideo/pin 等） */
  type: string;
  /** 内容 ID */
  id: string;
  /** 标题 */
  title: string;
  /** 摘要 */
  excerpt: string;
  /** 作者（可选） */
  author?: Author;
  /** 高亮文本（可选，用于搜索结果高亮显示） */
  highlight?: string;

  constructor(
    type: string,
    id: string,
    title: string,
    excerpt: string,
    author?: Author,
    highlight?: string
  ) {
    this.type = type;
    this.id = id;
    this.title = title;
    this.excerpt = excerpt;
    if (author !== undefined) {
      this.author = author;
    }
    if (highlight !== undefined) {
      this.highlight = highlight;
    }
  }

  /**
   * 从知乎搜索 API 的 raw 响应对象解析 SearchResultItem。
   *
   * @param raw - 搜索 API 响应中的单条数据对象
   * @returns 解析后的 SearchResultItem 实例；必填字段缺失返回 null
   */
  static fromObject(raw: object): SearchResultItem | null {
    if (raw === null || raw === undefined) {
      return null;
    }
    const data: RawSearchResult = raw as RawSearchResult;

    const type: string | undefined = typeof data.type === 'string' ? data.type : undefined;
    const id: string | undefined = typeof data.id === 'string' ? data.id
      : (typeof data.id === 'number' ? String(data.id) : undefined);
    const title: string | undefined = typeof data.title === 'string' ? data.title : undefined;
    const excerpt: string | undefined = typeof data.excerpt === 'string' ? data.excerpt : undefined;

    if (type === undefined || id === undefined || title === undefined) {
      return null;
    }

    let author: Author | undefined = undefined;
    if (data.author !== undefined) {
      const parsed: Author | null = Author.fromObject(data.author);
      if (parsed !== null) {
        author = parsed;
      }
    }

    let highlight: string | undefined = undefined;
    if (typeof data.highlight === 'string') {
      highlight = data.highlight;
    }

    const finalExcerpt: string = excerpt !== undefined ? excerpt : '';
    return new SearchResultItem(type, id, title, finalExcerpt, author, highlight);
  }
}

/** 知乎搜索 API 原始响应对象形状（snake_case，内部使用） */
interface RawSearchResult {
  type?: string;
  id?: string | number;
  title?: string;
  excerpt?: string;
  author?: object;
  highlight?: string;
  object?: object;  // 搜索 API 把详细内容放在 object 字段里
}
