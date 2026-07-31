/**
 * 问题详情页 ViewModel
 *
 * 持有两部分状态：
 * 1. 问题详情（QuestionDetail）：标题、描述、统计、作者、话题
 * 2. 回答列表（FeedCard[]）：复用首页 FeedCard 模型，分页加载
 *
 * 单例模式：每个问题详情页实例通过 getInstance(questionId) 获取对应 viewModel。
 * 因 ArkUI V2 的 @ObservedV2 不支持泛型，本类不继承 BasePaginationViewModel，
 * 但复用其去重追加（dedupeAppend）和 shouldLoadMore 的逻辑思路。
 *
 * 状态机：
 * - 初始: detail=null, answers=[], isLoadingDetail=false, isLoadingAnswers=false, errorMessage=''
 * - 加载问题详情: isLoadingDetail=true
 * - 问题详情成功: detail 更新, isLoadingDetail=false
 * - 问题详情失败: isLoadingDetail=false, errorMessage 设置
 * - 加载回答列表: isLoadingAnswers=true
 * - 回答列表成功: answers 追加, paging 更新, isLoadingAnswers=false
 * - 回答列表失败: isLoadingAnswers=false, errorMessage 设置（不阻塞已加载的 detail）
 *
 * 缓存策略：
 * - 问题详情经 ContentDetailCache 缓存（TTL 10 分钟）
 * - 回答列表不缓存（每次进入页面都拉取最新）
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { QuestionDetail } from '../model/QuestionDetail';
import { FeedCard } from '../model/FeedCard';
import { Paging } from '../model/Paging';
import { ApiError } from '../model/ApiError';
import { ZhihuApi, FeedListResult } from '../api/ZhihuApi';
import { ContentDetailCache } from './ContentDetailCache';
import { mapApiError } from '../utils/ErrorMessageUtil';

const DOMAIN: number = 0x0000;
const TAG: string = 'QuestionDetailViewModel';

/** 问题详情缓存 key 前缀 */
const CACHE_KEY_PREFIX: string = 'question_';

@ObservedV2
export class QuestionDetailViewModel {
  /** 单例（按 questionId 隔离的实例映射） */
  private static instances: Map<string, QuestionDetailViewModel> = new Map<string, QuestionDetailViewModel>();

  /** 问题详情（null 表示未加载） */
  @Trace detail: QuestionDetail | null = null;
  /** 回答列表（已加载的 FeedCard 数组） */
  @Trace answers: FeedCard[] = [];
  /** 是否正在加载问题详情 */
  @Trace isLoadingDetail: boolean = false;
  /** 是否正在加载回答列表（首次或触底） */
  @Trace isLoadingAnswers: boolean = false;
  /** 当前下拉刷新状态 */
  @Trace isPullToRefresh: boolean = false;
  /** 错误信息（空字符串表示无错误） */
  @Trace errorMessage: string = '';
  /** 回答列表分页信息（null 表示未加载或首次加载未完成） */
  @Trace answersPaging: Paging | null = null;

  /** 当前问题 ID（实例绑定） */
  private questionId: string;
  /** API 客户端 */
  private api: ZhihuApi;
  /** 详情缓存 */
  private cache: ContentDetailCache;

  private constructor(questionId: string) {
    this.questionId = questionId;
    this.api = new ZhihuApi();
    this.cache = ContentDetailCache.getInstance();
  }

  /**
   * 获取指定问题的 ViewModel 实例。
   *
   * 同一 questionId 返回同一实例，便于页面重建时复用状态。
   * 不同 questionId 创建新实例。
   *
   * @param questionId 问题 ID
   */
  static getInstance(questionId: string): QuestionDetailViewModel {
    let vm: QuestionDetailViewModel | undefined = QuestionDetailViewModel.instances.get(questionId);
    if (vm === undefined) {
      vm = new QuestionDetailViewModel(questionId);
      QuestionDetailViewModel.instances.set(questionId, vm);
    }
    return vm;
  }

  /**
   * 加载问题详情。
   *
   * 流程：
   * 1. 先查 ContentDetailCache，命中且未过期直接使用
   * 2. 未命中调用 ZhihuApi.fetchQuestionDetail
   * 3. 成功后写入缓存
   * 4. 异常时设置 errorMessage
   */
  async loadDetail(): Promise<void> {
    if (this.isLoadingDetail) {
      return;
    }
    // 先查缓存
    const cacheKey: string = CACHE_KEY_PREFIX + this.questionId;
    const cached: QuestionDetail | null = this.cache.get<QuestionDetail>(cacheKey);
    if (cached !== null) {
      this.detail = cached;
      hilog.info(DOMAIN, TAG, 'loadDetail: cache hit, questionId=%{public}s', this.questionId);
      return;
    }

    this.isLoadingDetail = true;
    this.errorMessage = '';

    try {
      const detail: QuestionDetail = await this.api.fetchQuestionDetail(this.questionId);
      this.detail = detail;
      this.cache.put<QuestionDetail>(cacheKey, detail);
    } catch (err) {
      this.errorMessage = this.mapErrorMessage(err);
      hilog.error(DOMAIN, TAG, 'loadDetail failed: %{public}s', this.errorMessage);
    } finally {
      this.isLoadingDetail = false;
    }
  }

  /**
   * 加载回答列表首页。
   *
   * 用于首次进入或下拉刷新。清空当前 answers 后拉取首页。
   */
  async loadAnswersFirstPage(): Promise<void> {
    if (this.isLoadingAnswers) {
      return;
    }
    this.isLoadingAnswers = true;
    this.isPullToRefresh = true;
    this.errorMessage = '';

    try {
      const result: FeedListResult = await this.api.fetchQuestionAnswers(this.questionId);
      // 下拉刷新不保留旧数据
      this.answers = result.items;
      this.answersPaging = result.paging;
    } catch (err) {
      this.errorMessage = this.mapErrorMessage(err);
      hilog.error(DOMAIN, TAG, 'loadAnswersFirstPage failed: %{public}s', this.errorMessage);
    } finally {
      this.isLoadingAnswers = false;
      this.isPullToRefresh = false;
    }
  }

  /**
   * 触底加载更多回答。
   *
   * 流程：
   * 1. isLoadingAnswers=true 或 answersPaging.isEnd=true 时拒绝
   * 2. 调用 ZhihuApi.fetchQuestionAnswers(paging.next) 获取下一页
   * 3. dedupeAppend 去重追加到 answers
   * 4. 更新 answersPaging
   */
  async loadMoreAnswers(): Promise<void> {
    if (this.isLoadingAnswers) {
      return;
    }
    if (this.answersPaging !== null && this.answersPaging.isEnd) {
      return;
    }

    this.isLoadingAnswers = true;
    this.isPullToRefresh = false;
    this.errorMessage = '';

    try {
      const nextUrl: string | undefined = this.answersPaging !== null ? this.answersPaging.next : undefined;
      const result: FeedListResult = await this.api.fetchQuestionAnswers(this.questionId, nextUrl);
      // 去重追加，重新赋值触发 @Trace
      const newAnswers: FeedCard[] = [...this.answers];
      this.dedupeAppend(newAnswers, result.items, (item: FeedCard) => item.stableKey);
      this.answers = newAnswers;
      this.answersPaging = result.paging;
    } catch (err) {
      this.errorMessage = this.mapErrorMessage(err);
      hilog.error(DOMAIN, TAG, 'loadMoreAnswers failed: %{public}s', this.errorMessage);
    } finally {
      this.isLoadingAnswers = false;
    }
  }

  /**
   * 首次进入页面时加载（detail + answers 首页）。
   *
   * 并行加载两部分数据，互不阻塞。
   * 若 detail 已加载（缓存命中或已加载过），只加载 answers。
   */
  async loadIfEmpty(): Promise<void> {
    const loadDetailTask: Promise<void> = this.detail === null ? this.loadDetail() : Promise.resolve();
    const loadAnswersTask: Promise<void> = this.answers.length === 0 ? this.loadAnswersFirstPage() : Promise.resolve();
    await Promise.all([loadDetailTask, loadAnswersTask]);
  }

  /**
   * 重试上次失败的加载。
   *
   * - detail 为空：重试 loadDetail
   * - answers 为空：重试 loadAnswersFirstPage
   * - answers 非空：重试 loadMoreAnswers
   */
  async retry(): Promise<void> {
    if (this.errorMessage.length === 0) {
      return;
    }
    if (this.detail === null) {
      await this.loadDetail();
    }
    if (this.answers.length === 0) {
      await this.loadAnswersFirstPage();
    } else {
      await this.loadMoreAnswers();
    }
  }

  /**
   * 去重追加新条目到 answers 数组（基于 keyExtractor 去重）。
   *
   * 与 BasePaginationViewModel.dedupeAppend 保持一致的签名模式，
   * 但因 @ObservedV2 不支持泛型无法继承，故本地实现。
   *
   * @param items 当前 answers 数组（会被修改）
   * @param newItems 新条目数组
   * @param keyExtractor 从条目中提取去重 key 的函数
   */
  private dedupeAppend(items: FeedCard[], newItems: FeedCard[],
    keyExtractor: (item: FeedCard) => string): void {
    const existingKeys: Set<string> = new Set();
    for (let i = 0; i < items.length; i++) {
      existingKeys.add(keyExtractor(items[i]));
    }
    for (let i = 0; i < newItems.length; i++) {
      const key: string = keyExtractor(newItems[i]);
      if (!existingKeys.has(key)) {
        existingKeys.add(key);
        items.push(newItems[i]);
      }
    }
  }

  /**
   * 将错误对象映射为用户可读的错误消息。
   */
  private mapErrorMessage(err: object): string {
    return mapApiError(err);
  }
}
