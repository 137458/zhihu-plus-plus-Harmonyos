/**
 * 分页 ViewModel 抽象基类
 *
 * 提供通用分页逻辑：
 * - 去重追加（基于稳定 key）
 * - 是否应继续加载的判断（isLoading + isEnd 双重保护）
 *
 * 设计说明：
 * - 不使用 @ObservedV2/@Trace，因 ArkUI V2 的 @ObservedV2 装饰器不支持泛型类
 * - 子类（如 HomeFeedViewModel）用 @ObservedV2 + @Trace 自行装饰，
 *   并通过 super 调用本基类提供的工具方法操作自身状态字段
 * - 基类不持有状态字段，所有状态由子类定义
 *
 * 子类契约：
 * - 实现 loadMore(): 触底加载下一页
 * - 实现 pullToRefresh(): 下拉刷新
 * - 在 loadMore/pullToRefresh 内部调用 shouldLoadMore 判断是否继续
 * - 在追加新条目时调用 dedupeAppend 进行去重
 */

import { Paging } from '../model/Paging';

export abstract class BasePaginationViewModel<T> {
  /**
   * 将新条目去重追加到 items 数组（原地修改）。
   *
   * @param items 当前 items 数组（会被修改）
   * @param newItems 新条目数组
   * @param keyExtractor 提取稳定唯一 key 的函数（如 FeedCard.stableKey）
   * @returns 实际新增的条目数（已存在的跳过）
   */
  protected dedupeAppend(items: T[], newItems: T[], keyExtractor: (item: T) => string): number {
    const existingKeys: Set<string> = new Set();
    for (let i = 0; i < items.length; i++) {
      existingKeys.add(keyExtractor(items[i]));
    }

    let added: number = 0;
    for (let i = 0; i < newItems.length; i++) {
      const key: string = keyExtractor(newItems[i]);
      if (!existingKeys.has(key)) {
        existingKeys.add(key);
        items.push(newItems[i]);
        added++;
      }
    }
    return added;
  }

  /**
   * 判断是否应该继续加载更多。
   *
   * 双重保护：
   * - isLoading=true 时拒绝（避免重复请求）
   * - paging.isEnd=true 时拒绝（已到末页）
   *
   * @param isLoading 当前加载状态
   * @param paging 当前分页信息（null 表示首次加载，允许继续）
   */
  protected shouldLoadMore(isLoading: boolean, paging: Paging | null): boolean {
    if (isLoading) {
      return false;
    }
    if (paging !== null && paging.isEnd) {
      return false;
    }
    return true;
  }

  /**
   * 加载更多（触底加载下一页）。
   *
   * 子类实现：
   * - 调用 shouldLoadMore 判断是否继续
   * - 调用 API 获取下一页
   * - 调用 dedupeAppend 去重追加
   * - 更新 paging
   */
  abstract loadMore(): Promise<void>;

  /**
   * 下拉刷新（清空当前列表并重新拉取首页）。
   *
   * 子类实现：
   * - 清空 items 和 paging
   * - 重新拉取首页
   * - 成功后 items 替换为新数据
   */
  abstract pullToRefresh(): Promise<void>;
}
