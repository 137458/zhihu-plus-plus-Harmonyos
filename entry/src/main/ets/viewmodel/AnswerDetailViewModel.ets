/**
 * 回答详情 ViewModel
 *
 * 持有回答详情状态：detail (AnswerDetail | null) + isLoading + errorMessage。
 *
 * 单例模式：按 answerId 隔离的实例映射，便于页面重建时复用状态。
 *
 * 缓存策略：
 * - 回答详情经 ContentDetailCache 缓存（TTL 10 分钟）
 * - 缓存命中时直接使用，不重复请求
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AnswerDetail } from '../model/AnswerDetail';
import { ApiError, ApiErrorCode } from '../model/ApiError';
import { ZhihuApi } from '../api/ZhihuApi';
import { ContentDetailCache } from './ContentDetailCache';

const DOMAIN: number = 0x0000;
const TAG: string = 'AnswerDetailViewModel';

/** 回答详情缓存 key 前缀 */
const CACHE_KEY_PREFIX: string = 'answer_';

@ObservedV2
export class AnswerDetailViewModel {
  /** 单例（按 answerId 隔离） */
  private static instances: Map<string, AnswerDetailViewModel> = new Map<string, AnswerDetailViewModel>();

  /** 回答详情（null 表示未加载） */
  @Trace detail: AnswerDetail | null = null;
  /** 是否正在加载 */
  @Trace isLoading: boolean = false;
  /** 错误信息（空字符串表示无错误） */
  @Trace errorMessage: string = '';

  /** 当前回答 ID */
  private answerId: string;
  /** API 客户端 */
  private api: ZhihuApi;
  /** 详情缓存 */
  private cache: ContentDetailCache;

  private constructor(answerId: string) {
    this.answerId = answerId;
    this.api = new ZhihuApi();
    this.cache = ContentDetailCache.getInstance();
  }

  /**
   * 获取指定回答的 ViewModel 实例。
   */
  static getInstance(answerId: string): AnswerDetailViewModel {
    let vm: AnswerDetailViewModel | undefined = AnswerDetailViewModel.instances.get(answerId);
    if (vm === undefined) {
      vm = new AnswerDetailViewModel(answerId);
      AnswerDetailViewModel.instances.set(answerId, vm);
    }
    return vm;
  }

  /**
   * 加载回答详情。
   *
   * 1. 先查缓存，命中且未过期直接使用
   * 2. 未命中调用 ZhihuApi.fetchAnswerDetail
   * 3. 成功后写入缓存
   */
  async load(): Promise<void> {
    if (this.isLoading) {
      return;
    }
    // 先查缓存
    const cacheKey: string = CACHE_KEY_PREFIX + this.answerId;
    const cached: AnswerDetail | null = this.cache.get<AnswerDetail>(cacheKey);
    if (cached !== null) {
      this.detail = cached;
      hilog.info(DOMAIN, TAG, 'load: cache hit, answerId=%{public}s', this.answerId);
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';

    try {
      const detail: AnswerDetail = await this.api.fetchAnswerDetail(this.answerId);
      this.detail = detail;
      this.cache.put<AnswerDetail>(cacheKey, detail);
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
