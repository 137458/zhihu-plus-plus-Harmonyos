/**
 * 收藏夹数据模型
 *
 * 对应证据文档 §5 收藏机制的 Collection 数据结构：
 * - id, title, isPublic, isFavorited, itemCount, isDefault, description
 * - followerCount, likeCount, viewCount, commentCount, createdTime, updatedTime
 * - creator（Author 类型）
 *
 * 使用 interface 而非 class，因为 Collection 数据只读，不需要方法。
 * fromObject 静态方法用于从 JSON 解析。
 */
export interface Collection {
  /** 收藏夹 ID */
  id: string;
  /** 收藏夹标题 */
  title: string;
  /** 是否公开 */
  isPublic: boolean;
  /** 是否默认收藏夹 */
  isDefault: boolean;
  /** 条目数量 */
  itemCount: number;
  /** 描述 */
  description: string;
  /** 关注者数 */
  followerCount: number;
  /** 创建时间戳 */
  createdTime: number;
  /** 更新时间戳 */
  updatedTime: number;
  /**
   * 当前内容是否在此收藏夹中。
   *
   * 注意：此字段仅在与内容关联的收藏夹列表响应中有意义，
   * 在用户收藏夹列表响应中不存在。
   */
  isFavorited: boolean;
}

/**
 * 从 JSON 对象解析 Collection。
 *
 * @param obj 原始 JSON 对象（snake_case 字段）
 * @returns 解析后的 Collection，失败返回 null
 */
export function collectionFromObject(obj: object): Collection | null {
  if (obj === null || obj === undefined) {
    return null;
  }
  const raw: Record<string, object> = obj as Record<string, object>;
  const idRaw: object = raw['id'];
  const id: string = typeof idRaw === 'string' ? idRaw : '';
  const titleRaw: object = raw['title'];
  const title: string = typeof titleRaw === 'string' ? titleRaw : '';
  if (id.length === 0) {
    return null;
  }
  if (title.length === 0) {
    return null;
  }
  const isFavoritedVal: object = raw['is_favorited'];
  const isFavorited: boolean = typeof isFavoritedVal === 'boolean' ? isFavoritedVal : false;
  const isDefaultVal: object = raw['is_default'];
  const isDefault: boolean = typeof isDefaultVal === 'boolean' ? isDefaultVal : false;
  const isPublicVal: object = raw['is_public'];
  const isPublic: boolean = typeof isPublicVal === 'boolean' ? isPublicVal : true;
  const itemCountVal: object = raw['item_count'];
  const itemCount: number = typeof itemCountVal === 'number' ? itemCountVal : 0;
  const description: string = typeof raw['description'] === 'string' ? (raw['description'] as string) : '';
  const followerCountVal: object = raw['follower_count'];
  const followerCount: number = typeof followerCountVal === 'number' ? followerCountVal : 0;
  const createdTimeVal: object = raw['created_time'];
  const createdTime: number = typeof createdTimeVal === 'number' ? createdTimeVal : 0;
  const updatedTimeVal: object = raw['updated_time'];
  const updatedTime: number = typeof updatedTimeVal === 'number' ? updatedTimeVal : 0;

  return {
    id: id,
    title: title,
    isPublic: isPublic,
    isDefault: isDefault,
    itemCount: itemCount,
    description: description,
    followerCount: followerCount,
    createdTime: createdTime,
    updatedTime: updatedTime,
    isFavorited: isFavorited
  };
}

/**
 * 从 JSON 数组解析 Collection 列表。
 * 解析失败的项会被跳过（返回 null 过滤）。
 */
export function collectionListFromArray(arr: object[]): Collection[] {
  const result: Collection[] = [];
  for (let i = 0; i < arr.length; i++) {
    const item: Collection | null = collectionFromObject(arr[i]);
    if (item !== null) {
      result.push(item);
    }
  }
  return result;
}