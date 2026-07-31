/**
 * 首页推荐信息流 ViewModel
 *
 * 单例模式，UI 通过 @ComponentV2 直接引用本类实例（getInstance()）。
 * @ObservedV2 + @Trace 装饰确保属性变化触发 UI 刷新。
 *
 * 状态字段（@Trace 装饰，UI 观察）：
 * - items: FeedCard[]（已加载的卡片列表）
 * - isLoading: 是否正在加载（pullToRefresh 或 loadMore）
 * - isPullToRefresh: 当前加载是否为下拉刷新（用于区分加载类型）
 * - errorMessage: 错误信息（空字符串表示无错误）
 * - paging: 分页信息（null 表示未加载或首次加载）
 *
 * 行为：
 * - loadMore(): 触底加载下一页，去重追加（基于 stableKey）
 * - pullToRefresh(): 下拉刷新，清空并重新拉取首页
 * - retry(): 重试上次失败的加载
 *
 * 状态机：
 * - 初始: items=[], isLoading=false, paging=null, errorMessage=''
 * - 加载中: isLoading=true
 * - 加载成功: items 更新，paging 更新，isLoading=false, errorMessage=''
 * - 加载失败: isLoading=false, errorMessage 设置为用户可读消息
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { FeedCard } from '../model/FeedCard';
import { Paging } from '../model/Paging';
import { BasePaginationViewModel } from './BasePaginationViewModel';
import { ZhihuApi, FeedListResult } from '../api/ZhihuApi';
import { mapApiError } from '../utils/ErrorMessageUtil';

const DOMAIN: number = 0x0000;
const TAG: string = 'HomeFeedViewModel';

@ObservedV2
export class HomeFeedViewModel extends BasePaginationViewModel<FeedCard> {
  /** 单例 */
  private static instance: HomeFeedViewModel;

  /** 已加载的卡片列表 */
  @Trace items: FeedCard[] = [];
  /** 是否正在加载 */
  @Trace isLoading: boolean = false;
  /** 当前加载是否为下拉刷新（用于区分首次加载/触底加载/下拉刷新） */
  @Trace isPullToRefresh: boolean = false;
  /** 错误信息（空字符串表示无错误） */
  @Trace errorMessage: string = '';
  /** 分页信息（null 表示未加载或首次加载未完成） */
  @Trace paging: Paging | null = null;

  private api: ZhihuApi;

  private constructor() {
    super();
    this.api = new ZhihuApi();
  }

  /** 获取单例 */
  static getInstance(): HomeFeedViewModel {
    if (HomeFeedViewModel.instance === undefined) {
      HomeFeedViewModel.instance = new HomeFeedViewModel();
    }
    return HomeFeedViewModel.instance;
  }

  /**
   * 触底加载更多。
   *
   * 流程：
   * 1. shouldLoadMore 判断：isLoading=true 或 paging.isEnd=true 时拒绝
   * 2. 调用 ZhihuApi.fetchHomeRecommend(paging.next) 获取下一页
   * 3. dedupeAppend 去重追加到 items
   * 4. 更新 paging
   * 5. 异常时设置 errorMessage 为用户可读消息
   */
  async loadMore(): Promise<void> {
    if (!this.shouldLoadMore(this.isLoading, this.paging)) {
      return;
    }

    this.isLoading = true;
    this.isPullToRefresh = false;
    this.errorMessage = '';

    try {
      const nextUrl: string | undefined = this.paging !== null ? this.paging.next : undefined;
      const result: FeedListResult = await this.api.fetchHomeRecommend(nextUrl);
      // dedupeAppend 修改传入的数组，重新赋值触发 @Trace（@Trace 只观察引用变化）
      const newItems: FeedCard[] = [...this.items];
      this.dedupeAppend(newItems, result.items, (card: FeedCard) => card.stableKey);
      this.items = newItems;
      this.paging = result.paging;
    } catch (err) {
      this.errorMessage = this.mapErrorMessage(err);
      hilog.error(DOMAIN, TAG, 'loadMore failed: %{public}s', this.errorMessage);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 下拉刷新。
   *
   * 流程：
   * 1. isLoading=true 时拒绝（避免与 loadMore 并发）
   * 2. 调用 ZhihuApi.fetchHomeRecommend() 拉取首页（不传 pagingNext）
   * 3. 清空 items，dedupeAppend 新数据
   * 4. 更新 paging
   */
  async pullToRefresh(): Promise<void> {
    if (this.isLoading) {
      return;
    }

    this.isLoading = true;
    this.isPullToRefresh = true;
    this.errorMessage = '';

    try {
      const result: FeedListResult = await this.api.fetchHomeRecommend();
      // 清空后追加新数据，重新赋值触发 @Trace（pullToRefresh 不保留旧数据）
      const newItems: FeedCard[] = [];
      this.dedupeAppend(newItems, result.items, (card: FeedCard) => card.stableKey);
      this.items = newItems;
      this.paging = result.paging;
    } catch (err) {
      this.errorMessage = this.mapErrorMessage(err);
      hilog.error(DOMAIN, TAG, 'pullToRefresh failed: %{public}s', this.errorMessage);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 首次加载（HomePage aboutToAppear 时调用）。
   *
   * 等价于 pullToRefresh，但语义更清晰。
   * 已有数据时为 no-op（避免重复加载）。
   */
  async loadIfEmpty(): Promise<void> {
    if (this.items.length > 0) {
      return;
    }
    if (this.isLoading) {
      return;
    }
    await this.pullToRefresh();
  }

  /**
   * 重试上次失败的加载。
   *
   * - 如果 errorMessage 非空，根据 isPullToRefresh/items 状态决定调用 pullToRefresh 或 loadMore
   * - 如果无错误，no-op
   */
  async retry(): Promise<void> {
    if (this.errorMessage.length === 0) {
      return;
    }
    if (this.isPullToRefresh || this.items.length === 0) {
      await this.pullToRefresh();
    } else {
      await this.loadMore();
    }
  }

  /**
   * 将错误对象映射为用户可读的错误消息。
   */
  private mapErrorMessage(err: object): string {
    return mapApiError(err);
  }
}
