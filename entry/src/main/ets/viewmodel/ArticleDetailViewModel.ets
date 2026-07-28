/**
 * 文章详情 ViewModel
 *
 * 持有文章详情状态：detail (ArticleDetail | null) + isLoading + errorMessage。
 *
 * 单例模式：按 articleId 隔离的实例映射。
 *
 * 缓存策略：
 * - 文章详情经 ContentDetailCache 缓存（TTL 10 分钟）
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { ArticleDetail } from '../model/ArticleDetail';
import { ApiError, ApiErrorCode } from '../model/ApiError';
import { ZhihuApi } from '../api/ZhihuApi';
import { ContentDetailCache } from './ContentDetailCache';

const DOMAIN: number = 0x0000;
const TAG: string = 'ArticleDetailViewModel';

/** 文章详情缓存 key 前缀 */
const CACHE_KEY_PREFIX: string = 'article_';

@ObservedV2
export class ArticleDetailViewModel {
  /** 单例（按 articleId 隔离） */
  private static instances: Map<string, ArticleDetailViewModel> = new Map<string, ArticleDetailViewModel>();

  /** 文章详情（null 表示未加载） */
  @Trace detail: ArticleDetail | null = null;
  /** 是否正在加载 */
  @Trace isLoading: boolean = false;
  /** 错误信息（空字符串表示无错误） */
  @Trace errorMessage: string = '';

  /** 当前文章 ID */
  private articleId: string;
  /** API 客户端 */
  private api: ZhihuApi;
  /** 详情缓存 */
  private cache: ContentDetailCache;

  private constructor(articleId: string) {
    this.articleId = articleId;
    this.api = new ZhihuApi();
    this.cache = ContentDetailCache.getInstance();
  }

  /**
   * 获取指定文章的 ViewModel 实例。
   */
  static getInstance(articleId: string): ArticleDetailViewModel {
    let vm: ArticleDetailViewModel | undefined = ArticleDetailViewModel.instances.get(articleId);
    if (vm === undefined) {
      vm = new ArticleDetailViewModel(articleId);
      ArticleDetailViewModel.instances.set(articleId, vm);
    }
    return vm;
  }

  /**
   * 加载文章详情。
   */
  async load(): Promise<void> {
    if (this.isLoading) {
      return;
    }
    // 先查缓存
    const cacheKey: string = CACHE_KEY_PREFIX + this.articleId;
    const cached: ArticleDetail | null = this.cache.get<ArticleDetail>(cacheKey);
    if (cached !== null) {
      this.detail = cached;
      hilog.info(DOMAIN, TAG, 'load: cache hit, articleId=%{public}s', this.articleId);
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';

    try {
      const detail: ArticleDetail = await this.api.fetchArticleDetail(this.articleId);
      this.detail = detail;
      this.cache.put<ArticleDetail>(cacheKey, detail);
    } catch (err) {
      this.errorMessage = this.mapErrorMessage(err);
      hilog.error(DOMAIN, TAG, 'load failed: %{public}s', this.errorMessage);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 重试上次失败的加载。
   */
  async retry(): Promise<void> {
    if (this.errorMessage.length === 0) {
      return;
    }
    await this.load();
  }

  /**
   * 将错误对象映射为用户可读的错误消息。
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
        return '服务器异常，请稍后重试';
      }
      return err.message;
    }
    return '未知错误';
  }
}
