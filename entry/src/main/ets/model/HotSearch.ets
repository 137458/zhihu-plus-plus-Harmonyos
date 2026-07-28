/**
 * 热搜模型
 *
 * 从知乎热搜 API 响应解析。
 * API: https://www.zhihu.com/api/v4/search/hot_search
 *
 * 注意：ArkTS 严格模式下 object 类型不允许直接属性访问，
 * fromObject 中使用 as 断言到 RawHotSearch（所有字段可选）仅用于编译期属性访问，
 * 运行时类型安全由逐字段 typeof 校验保证。
 */

/** 热搜条目 */
export class HotSearchItem {
  /** 搜索词 */
  query: string;
  /** 显示标签（可能和 query 相同，也可能带"#前缀"） */
  label: string;
  /** 热度数值 */
  hotShow: number;

  constructor(query: string, label: string, hotShow: number) {
    this.query = query;
    this.label = label;
    this.hotShow = hotShow;
  }

  /**
   * 从知乎热搜 API 的 raw 响应对象解析 HotSearchItem。
   *
   * @param raw - 热搜 API 响应中的单条数据对象
   * @returns 解析后的 HotSearchItem 实例；必填字段缺失返回 null
   */
  static fromObject(raw: object): HotSearchItem | null {
    if (raw === null || raw === undefined) {
      return null;
    }
    const data: RawHotSearch = raw as RawHotSearch;

    const query: string | undefined = typeof data.query === 'string' ? data.query
      : (typeof data.search_text === 'string' ? data.search_text : undefined);
    const label: string | undefined = typeof data.display_query === 'string' ? data.display_query
      : (typeof data.title === 'string' ? data.title : undefined);
    const hotShow: number = typeof data.hot === 'number' ? data.hot
      : (typeof data.hot_value === 'number' ? data.hot_value : 0);

    if (query === undefined || label === undefined) {
      return null;
    }

    return new HotSearchItem(query, label, hotShow);
  }
}

/** 知乎热搜 API 原始响应对象形状（snake_case，内部使用） */
interface RawHotSearch {
  query?: string;
  search_text?: string;
  display_query?: string;
  title?: string;
  hot?: number;
  hot_value?: number;
}
