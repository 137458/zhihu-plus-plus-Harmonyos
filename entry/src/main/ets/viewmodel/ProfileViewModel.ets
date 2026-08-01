/**
 * 个人页 ViewModel（Slice 3）
 *
 * 单例模式，管理用户回答/文章列表的加载和分页。
 * @ObservedV2 + @Trace 装饰确保属性变化触发 UI 刷新。
 *
 * 状态管理：
 * - answerItems/articleItems：回答/文章列表
 * - isLoading/isRefreshing：加载状态
 * - answerPaging/articlePaging：各自的分页信息
 *
 * 分页策略：
 * - 首次加载：调用 ZhihuApi.fetchUserAnswers/fetchUserArticles 构造新 URL
 * - 翻页加载：使用 paging.next 作为 pagingNext 参数
 * - 去重追加：dedupeAppend 基于 stableKey 去重
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { FeedCard } from '../model/FeedCard';
import { Paging } from '../model/Paging';
import { BasePaginationViewModel } from './BasePaginationViewModel';
import { ZhihuApi, FeedListResult } from '../api/ZhihuApi';

const DOMAIN: number = 0x0000;
const TAG: string = 'ProfileViewModel';

@ObservedV2
export class ProfileViewModel extends BasePaginationViewModel<FeedCard> {
  /** 单例 */
  private static instance: ProfileViewModel;

  /** 回答列表 */
  @Trace answerItems: FeedCard[] = [];
  /** 文章列表 */
  @Trace articleItems: FeedCard[] = [];
  /** 是否正在加载 */
  @Trace isLoading: boolean = false;
  /** 是否正在刷新 */
  @Trace isRefreshing: boolean = false;

  /** 回答列表分页信息 */
  answerPaging: Paging | null = null;
  /** 文章列表分页信息 */
  articlePaging: Paging | null = null;

  private api: ZhihuApi;

  private constructor() {
    super();
    this.api = new ZhihuApi();
  }

  /** 获取单例 */
  static getInstance(): ProfileViewModel {
    if (ProfileViewModel.instance === undefined) {
      ProfileViewModel.instance = new ProfileViewModel();
    }
    return ProfileViewModel.instance;
  }

  /**
   * 加载回答列表（首次调用和翻页）。
   *
   * 流程：
   * 1. shouldLoadMore 判断：isLoading=true 或 answerPaging.isEnd=true 时拒绝
   * 2. 调用 ZhihuApi.fetchUserAnswers 获取数据
   * 3. dedupeAppend 去重追加到 answerItems
   * 4. 更新 answerPaging
   *
   * @param urlToken 用户 urlToken
   */
  async loadAnswers(urlToken: string): Promise<void> {
    if (!this.shouldLoadMore(this.isLoading, this.answerPaging)) {
      return;
    }

    this.isLoading = true;

    try {
      const pagingNext: string | undefined = this.answerPaging !== null ? this.answerPaging.next : undefined;
      const result: FeedListResult = await this.api.fetchUserAnswers(urlToken, pagingNext);
      const newItems: FeedCard[] = [...this.answerItems];
      this.dedupeAppend(newItems, result.items, (card: FeedCard) => card.stableKey);
      this.answerItems = newItems;
      this.answerPaging = result.paging;
      hilog.info(DOMAIN, TAG, 'loadAnswers: urlToken=%{public}s items=%{public}d',
        urlToken, result.items.length);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'loadAnswers failed: urlToken=%{public}s err=%{public}s',
        urlToken, err instanceof Error ? err.message : String(err));
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 加载文章列表（首次调用和翻页）。
   *
   * 流程：
   * 1. shouldLoadMore 判断：isLoading=true 或 articlePaging.isEnd=true 时拒绝
   * 2. 调用 ZhihuApi.fetchUserArticles 获取数据
   * 3. dedupeAppend 去重追加到 articleItems
   * 4. 更新 articlePaging
   *
   * @param urlToken 用户 urlToken
   */
  async loadArticles(urlToken: string): Promise<void> {
    if (!this.shouldLoadMore(this.isLoading, this.articlePaging)) {
      return;
    }

    this.isLoading = true;

    try {
      const pagingNext: string | undefined = this.articlePaging !== null ? this.articlePaging.next : undefined;
      const result: FeedListResult = await this.api.fetchUserArticles(urlToken, pagingNext);
      const newItems: FeedCard[] = [...this.articleItems];
      this.dedupeAppend(newItems, result.items, (card: FeedCard) => card.stableKey);
      this.articleItems = newItems;
      this.articlePaging = result.paging;
      hilog.info(DOMAIN, TAG, 'loadArticles: urlToken=%{public}s items=%{public}d',
        urlToken, result.items.length);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'loadArticles failed: urlToken=%{public}s err=%{public}s',
        urlToken, err instanceof Error ? err.message : String(err));
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 刷新所有列表。
   *
   * 清空回答和文章列表及分页信息，重新加载。
   * 使用 Promise.all 并行加载两个列表。
   *
   * @param urlToken 用户 urlToken
   */
  async refresh(urlToken: string): Promise<void> {
    if (this.isRefreshing) {
      return;
    }

    this.isRefreshing = true;
    this.isLoading = true;

    // 清空现有数据
    this.answerItems = [];
    this.articleItems = [];
    this.answerPaging = null;
    this.articlePaging = null;

    try {
      await Promise.all([
        this.loadAnswers(urlToken),
        this.loadArticles(urlToken)
      ]);
      hilog.info(DOMAIN, TAG, 'refresh completed: urlToken=%{public}s', urlToken);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'refresh failed: urlToken=%{public}s err=%{public}s',
        urlToken, err instanceof Error ? err.message : String(err));
    } finally {
      this.isRefreshing = false;
      this.isLoading = false;
    }
  }

  // ──── BasePaginationViewModel 抽象方法实现 ────

  /**
   * 触底加载更多。
   *
   * 由 BasePaginationViewModel 定义，当前仅通过 Tab 切换分发，
   * 实际调用由 loadAnswers/loadArticles 按需触发。
   */
  async loadMore(): Promise<void> {
    // 当前 Tab 的加载通过 loadAnswers/loadArticles 直接调用，
    // 此方法保留供 BasePaginationViewModel 契约使用。
    hilog.info(DOMAIN, TAG, 'loadMore: delegated to loadAnswers/loadArticles');
  }

  /**
   * 下拉刷新。
   *
   * 由 BasePaginationViewModel 定义，当前刷新通过 refresh 方法触发。
   */
  async pullToRefresh(): Promise<void> {
    // 当前刷新通过 refresh 方法触发，此方法保留供 BasePaginationViewModel 契约使用。
    hilog.info(DOMAIN, TAG, 'pullToRefresh: delegated to refresh');
  }
}