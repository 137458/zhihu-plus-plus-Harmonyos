/**
 * 搜索 ViewModel
 *
 * 单例模式，UI 通过 @ComponentV2 直接引用本类实例（getInstance()）。
 * @ObservedV2 + @Trace 装饰确保属性变化触发 UI 刷新。
 *
 * 状态字段（@Trace 装饰，UI 观察）：
 * - items: SearchResultItem[]（已加载的搜索结果列表）
 * - isLoading: 是否正在加载（submitQuery 或 loadMore）
 * - errorMessage: 错误信息（空字符串表示无错误）
 * - paging: 分页信息（null 表示未加载或首次加载未完成）
 * - query: 当前搜索词（空字符串表示未提交）
 * - hotSearchItems: 热搜榜单
 * - searchHistory: 搜索历史（最多 20 项，新的在前）
 * - hasSubmitted: 是否已提交过搜索（区分初始态和结果态）
 *
 * 行为：
 * - submitQuery(q): 提交搜索（清空 items，重新拉取首页）
 * - loadMore(): 触底加载下一页
 * - pullToRefresh(): no-op（搜索不用下拉刷新）
 * - retry(): 重试上次失败的搜索
 * - loadHotSearch(): 加载热搜（错误静默）
 * - loadHistory(): 从 preferences 加载搜索历史
 * - clearHistory(): 清空搜索历史并持久化
 *
 * 状态机：
 * - 初始: items=[], isLoading=false, paging=null, errorMessage='', query='', hasSubmitted=false
 * - 提交搜索: hasSubmitted=true, query=q, items 清空, isLoading=true
 * - 加载成功: items 更新, paging 更新, isLoading=false, errorMessage=''
 * - 加载失败: isLoading=false, errorMessage 设置为用户可读消息
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { SearchResultItem } from '../model/SearchResult';
import { HotSearchItem } from '../model/HotSearch';
import { Paging } from '../model/Paging';
import { ApiError, ApiErrorCode } from '../model/ApiError';
import { BasePaginationViewModel } from './BasePaginationViewModel';
import { ZhihuApi, SearchListResult } from '../api/ZhihuApi';
import { PreferencesUtil } from '../utils/PreferencesUtil';

const DOMAIN: number = 0x0000;
const TAG: string = 'SearchViewModel';

/** preferences 中存储搜索历史的键 */
const SEARCH_HISTORY_KEY: string = 'searchHistoryQueries';
/** 搜索历史最大条目数 */
const SEARCH_HISTORY_MAX: number = 20;

@ObservedV2
export class SearchViewModel extends BasePaginationViewModel<SearchResultItem> {
  /** 单例 */
  private static instance: SearchViewModel;

  /** 已加载的搜索结果列表 */
  @Trace items: SearchResultItem[] = [];
  /** 是否正在加载 */
  @Trace isLoading: boolean = false;
  /** 错误信息（空字符串表示无错误） */
  @Trace errorMessage: string = '';
  /** 分页信息（null 表示未加载或首次加载未完成） */
  @Trace paging: Paging | null = null;
  /** 当前搜索词（空字符串表示未提交） */
  @Trace query: string = '';
  /** 热搜榜单 */
  @Trace hotSearchItems: HotSearchItem[] = [];
  /** 搜索历史（最多 20 项，新的在前） */
  @Trace searchHistory: string[] = [];
  /** 是否已提交过搜索（区分初始态和结果态） */
  @Trace hasSubmitted: boolean = false;

  private api: ZhihuApi;

  private constructor() {
    super();
    this.api = new ZhihuApi();
  }

  /** 获取单例 */
  static getInstance(): SearchViewModel {
    if (SearchViewModel.instance === undefined) {
      SearchViewModel.instance = new SearchViewModel();
    }
    return SearchViewModel.instance;
  }

  /**
   * 提交搜索。
   *
   * 流程：
   * 1. 校验：q.trim() 为空时 no-op（避免无效请求）
   * 2. 更新 query 和 hasSubmitted=true
   * 3. 清空 items 和 paging
   * 4. 调用 api.search(query) 获取首页结果
   * 5. 添加到 searchHistory（去重，移到头部，超过 20 截断）
   * 6. 持久化 searchHistory 到 preferences
   * 7. 异常时设置 errorMessage 为用户可读消息
   *
   * @param q 用户输入的搜索词
   */
  async submitQuery(q: string): Promise<void> {
    const trimmed: string = q.trim();
    if (trimmed.length === 0) {
      // 空查询不发起请求
      return;
    }
    if (this.isLoading) {
      // 已在加载中，避免并发
      return;
    }

    this.query = trimmed;
    this.hasSubmitted = true;
    this.isLoading = true;
    this.errorMessage = '';
    this.items = [];
    this.paging = null;

    try {
      const result: SearchListResult = await this.api.search(trimmed);
      this.items = result.items;
      this.paging = result.paging;
      this.addHistory(trimmed);
    } catch (err) {
      this.errorMessage = this.mapErrorMessage(err);
      hilog.error(DOMAIN, TAG, 'submitQuery failed: %{public}s', this.errorMessage);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 触底加载更多。
   *
   * 流程：
   * 1. query 为空或 hasSubmitted=false 时 no-op
   * 2. shouldLoadMore 判断：isLoading=true 或 paging.isEnd=true 时拒绝
   * 3. 调用 api.search(query, paging.next) 获取下一页
   * 4. dedupeAppend 去重追加到 items
   * 5. 更新 paging
   * 6. 异常时设置 errorMessage
   */
  async loadMore(): Promise<void> {
    if (!this.hasSubmitted || this.query.length === 0) {
      return;
    }
    if (!this.shouldLoadMore(this.isLoading, this.paging)) {
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';

    try {
      const nextUrl: string | undefined = this.paging !== null ? this.paging.next : undefined;
      const result: SearchListResult = await this.api.search(this.query, nextUrl);
      // dedupeAppend 修改传入的数组，重新赋值触发 @Trace
      const newItems: SearchResultItem[] = [...this.items];
      this.dedupeAppend(newItems, result.items, (item: SearchResultItem) => item.type + '_' + item.id);
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
   * 下拉刷新（搜索场景下为 no-op）。
   *
   * 搜索结果通过 submitQuery 重新搜索触发刷新，不支持下拉刷新。
   */
  async pullToRefresh(): Promise<void> {
    // no-op：搜索场景不使用下拉刷新
  }

  /**
   * 重试上次失败的搜索。
   *
   * - 如果 errorMessage 非空，根据 items 状态决定调用 submitQuery 或 loadMore
   * - 如果无错误，no-op
   */
  async retry(): Promise<void> {
    if (this.errorMessage.length === 0) {
      return;
    }
    // items 为空说明首页失败，重新提交搜索
    if (this.items.length === 0) {
      await this.submitQuery(this.query);
    } else {
      await this.loadMore();
    }
  }

  /**
   * 加载热搜榜单。
   *
   * 错误静默处理（hilog.error），不显示给用户（热搜是辅助功能）。
   */
  async loadHotSearch(): Promise<void> {
    try {
      const result: HotSearchItem[] = await this.api.fetchHotSearch();
      this.hotSearchItems = result;
    } catch (err) {
      const msg: string = this.mapErrorMessage(err);
      hilog.error(DOMAIN, TAG, 'loadHotSearch failed (silent): %{public}s', msg);
      // 热搜是辅助功能，错误不显示给用户
    }
  }

  /**
   * 从 preferences 加载搜索历史。
   */
  async loadHistory(): Promise<void> {
    const history: string[] = await PreferencesUtil.getStringList(SEARCH_HISTORY_KEY);
    this.searchHistory = history;
    hilog.info(DOMAIN, TAG, 'loadHistory: count=%{public}d', history.length);
  }

  /**
   * 清空搜索历史并持久化。
   */
  async clearHistory(): Promise<void> {
    this.searchHistory = [];
    await PreferencesUtil.putStringList(SEARCH_HISTORY_KEY, []);
    hilog.info(DOMAIN, TAG, 'clearHistory: cleared');
  }

  /**
   * 将查询词添加到搜索历史（去重，移到头部，超过上限截断）。
   *
   * 同时更新内存中的 searchHistory 和持久化到 preferences。
   *
   * @param q 查询词（已 trim）
   */
  private addHistory(q: string): void {
    // 去重：移除已存在的同项
    const filtered: string[] = [];
    for (let i = 0; i < this.searchHistory.length; i++) {
      if (this.searchHistory[i] !== q) {
        filtered.push(this.searchHistory[i]);
      }
    }
    // 插入到头部
    const newHistory: string[] = [q, ...filtered];
    // 截断到上限
    if (newHistory.length > SEARCH_HISTORY_MAX) {
      newHistory.length = SEARCH_HISTORY_MAX;
    }
    this.searchHistory = newHistory;
    // 持久化（异步，不阻塞）
    PreferencesUtil.putStringList(SEARCH_HISTORY_KEY, newHistory)
      .catch((e: object) => {
        const errMsg: string = e instanceof Error ? e.message : String(e);
        hilog.error(DOMAIN, TAG, 'addHistory persist failed: %{public}s', errMsg);
      });
  }

  /**
   * 将错误对象映射为用户可读的错误消息。
   *
   * 错误码映射：
   * - NETWORK_ERROR: "网络连接失败，请检查网络"
   * - TIMEOUT: "请求超时，请稍后重试"
   * - RISK_CONTROL: "已被风控，请稍后再试"
   * - UNAUTHORIZED: "登录已失效，请重新登录"
   * - SERVER_ERROR: "服务器异常，请稍后再试"
   * - 其他: err.message
   */
  private mapErrorMessage(err: object): string {
    if (err instanceof ApiError) {
      if (err.code === ApiErrorCode.NETWORK_ERROR) {
        return '网络连接失败，请检查网络';
      }
      if (err.code === ApiErrorCode.TIMEOUT) {
        return '请求超时，请稍后重试';
      }
      if (err.code === ApiErrorCode.RISK_CONTROL) {
        return '已被风控，请稍后再试';
      }
      if (err.code === ApiErrorCode.UNAUTHORIZED) {
        return '登录已失效，请重新登录';
      }
      if (err.code === ApiErrorCode.SERVER_ERROR) {
        return '服务器异常，请稍后再试';
      }
      return err.message;
    }
    return '未知错误';
  }
}
