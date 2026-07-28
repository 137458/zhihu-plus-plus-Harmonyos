/**
 * 内容详情缓存
 *
 * 内存级 LRU 缓存，按 `contentType_contentId` 缓存 QuestionDetail / AnswerDetail /
 * ArticleDetail 等详情对象，避免短时间内重复请求同一详情。
 *
 * 策略：
 * - TTL 10 分钟（CACHE_TTL_MS）：过期条目视为未命中，被访问时惰性删除
 * - 容量上限 100（CACHE_MAX_SIZE）：put 时若超限，删除最近最少使用的条目
 * - LRU 顺序维护：get 命中时重新插入更新访问顺序；put 已存在 key 时先删除再插入
 *   （Map 保持插入顺序，遍历取第一个 key 删除）
 *
 * 单例模式，全 app 共享一份缓存。
 *
 * 注意：本缓存为纯内存缓存，不持久化。App 重启后清空。
 */

/** 缓存 TTL（毫秒）—— 10 分钟 */
const CACHE_TTL_MS: number = 10 * 60 * 1000;
/** 缓存容量上限 */
const CACHE_MAX_SIZE: number = 100;

/** 缓存条目 */
interface CacheEntry {
  /** 缓存的数据（详情对象） */
  data: object;
  /** 写入时间戳（毫秒，Date.now()） */
  timestamp: number;
}

/**
 * 内容详情缓存
 *
 * 单例模式。提供 get<T>/put<T>/clear 三个方法。
 * T 必须是 object 子类型（class 实例等），原始类型不支持。
 */
export class ContentDetailCache {
  /** 单例 */
  private static instance: ContentDetailCache;
  /** 缓存存储：key = contentType_contentId */
  private cache: Map<string, CacheEntry> = new Map<string, CacheEntry>();

  private constructor() {
    // 私有构造函数，单例模式
  }

  /** 获取单例 */
  static getInstance(): ContentDetailCache {
    if (ContentDetailCache.instance === undefined) {
      ContentDetailCache.instance = new ContentDetailCache();
    }
    return ContentDetailCache.instance;
  }

  /**
   * 读取缓存。
   *
   * 命中时重新插入条目以更新访问顺序（LRU 策略）。
   *
   * @param key 缓存键（contentType_contentId）
   * @returns 命中且未过期时返回 data as T；未命中或已过期返回 null（并删除过期条目）
   */
  get<T extends object>(key: string): T | null {
    const entry: CacheEntry | undefined = this.cache.get(key);
    if (entry === undefined) {
      return null;
    }
    // 检查 TTL
    const now: number = Date.now();
    if (now - entry.timestamp > CACHE_TTL_MS) {
      // 已过期，删除并返回 null
      this.cache.delete(key);
      return null;
    }
    // LRU: 命中时重新插入，更新访问顺序
    this.cache.delete(key);
    this.cache.set(key, entry);
    return entry.data as T;
  }

  /**
   * 写入缓存。
   *
   * 已存在的 key 先删除再插入，保证位于最新访问位置（LRU 策略）。
   * 若容量超 CACHE_MAX_SIZE，删除最近最少使用的条目（Map 保持插入顺序）。
   *
   * @param key 缓存键（contentType_contentId）
   * @param value 待缓存的对象
   */
  put<T extends object>(key: string, value: T): void {
    // LRU: 已存在的 key 先删除，保证重新插入到最新位置
    if (this.cache.has(key)) {
      this.cache.delete(key);
    }
    this.cache.set(key, {
      data: value,
      timestamp: Date.now()
    });
    // 容量超限时删除最近最少使用的条目
    if (this.cache.size > CACHE_MAX_SIZE) {
      const oldestKey: string | null = this.getOldestKey();
      if (oldestKey !== null) {
        this.cache.delete(oldestKey);
      }
    }
  }

  /**
   * 清空所有缓存条目。
   */
  clear(): void {
    this.cache.clear();
  }

  /**
   * 获取缓存条目的时间戳（仅供测试和调试使用）。
   *
   * @param key 缓存键
   * @returns 时间戳（毫秒）；key 不存在返回 null
   */
  getEntryTimestamp(key: string): number | null {
    const entry: CacheEntry | undefined = this.cache.get(key);
    if (entry === undefined) {
      return null;
    }
    return entry.timestamp;
  }

  /**
   * 设置缓存条目的时间戳（仅供测试使用，用于模拟 TTL 过期场景）。
   *
   * 生产代码不应调用此方法。
   *
   * @param key 缓存键
   * @param timestamp 自定义时间戳（毫秒）
   * @returns 是否设置成功（key 不存在返回 false）
   */
  setTimestampForTest(key: string, timestamp: number): boolean {
    const entry: CacheEntry | undefined = this.cache.get(key);
    if (entry === undefined) {
      return false;
    }
    this.cache.set(key, {
      data: entry.data,
      timestamp: timestamp
    });
    return true;
  }

  /**
   * 获取当前缓存条目数量（仅供测试和调试使用）。
   */
  size(): number {
    return this.cache.size;
  }

  /**
   * 获取最近最少使用的 key（Map 保持插入顺序，第一个即 LRU 候选）。
   *
   * ArkTS 严格模式下不支持 IteratorResult 协议的便捷解构，
   * 用 forEach 遍历一次取第一个 key。
   *
   * @returns 最近最少使用的 key；缓存为空返回 null
   */
  private getOldestKey(): string | null {
    let oldestKey: string | null = null;
    this.cache.forEach((_value: CacheEntry, key: string) => {
      if (oldestKey === null) {
        oldestKey = key;
      }
    });
    return oldestKey;
  }
}
