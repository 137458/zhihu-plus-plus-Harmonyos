/**
 * 通用分页模型
 *
 * 对应知乎 API 响应中的 paging 字段，用于翻页加载更多数据。
 * 知乎 API 的分页字段使用 snake_case，本接口对外暴露 camelCase。
 *
 * 注意：ArkTS 严格模式下 object 类型不允许直接属性访问，
 * parsePaging 中使用 as 断言到 RawPaging（所有字段可选）仅用于编译期属性访问，
 * 运行时类型安全由逐字段 typeof 校验保证。
 */

/** 分页信息 */
export interface Paging {
  /** 下一页 URL（必填） */
  next: string;
  /** 是否已到最后一页（必填） */
  isEnd: boolean;
  /** 上一页 URL（可选） */
  previous?: string;
}

/** 知乎 API 原始 paging 对象的形状（snake_case，内部使用） */
interface RawPaging {
  next?: string;
  is_end?: boolean;
  previous?: string;
}

/**
 * 从知乎响应的 paging 对象解析分页信息。
 *
 * 字段映射：
 * - next ← paging.next（string，必填）
 * - isEnd ← paging.is_end（boolean，必填）
 * - previous ← paging.previous（string，可选）
 *
 * @param raw - 知乎 API 响应中的 paging 对象
 * @returns 解析后的 Paging 对象；必填字段缺失或类型不匹配时返回 null
 */
export function parsePaging(raw: object): Paging | null {
  if (raw === null || raw === undefined) {
    return null;
  }
  const data: RawPaging = raw as RawPaging;

  const next: string | undefined = data.next;
  const isEnd: boolean | undefined = data.is_end;

  if (typeof next !== 'string' || typeof isEnd !== 'boolean') {
    return null;
  }

  let previous: string | undefined = undefined;
  if (typeof data.previous === 'string') {
    previous = data.previous;
  }

  const result: Paging = {
    next: next,
    isEnd: isEnd,
    previous: previous
  };
  return result;
}
