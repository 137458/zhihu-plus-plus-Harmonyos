/**
 * 评论列表 ViewModel
 *
 * 管理根评论列表的加载和分页。
 * 首发只读，不支持发表评论/子评论/点赞评论。
 *
 * 设计说明：
 * - 每个内容详情页（AnswerDetailPage / ArticleDetailPage）持有自己的实例
 * - 使用 @ObservedV2 + @Trace 实现 UI 响应式更新
 * - 分页逻辑参考 BasePaginationViewModel 的 shouldLoadMore 保护
 * - 内容 ID 和类型在构造函数中确定，支持 loadComments 和 loadMore
 */

import { Comment, commentListFromArray } from '../model/Comment';
import { Paging, parsePaging } from '../model/Paging';
import { ZhihuApi, RootCommentsResult } from '../api/ZhihuApi';
import { ApiError, ApiErrorCode } from '../model/ApiError';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'CommentViewModel';

@ObservedV2
export class CommentViewModel {
  /** 评论列表 */
  @Trace comments: Comment[] = [];
  /** 是否正在加载（首次或分页） */
  @Trace isLoading: boolean = false;
  /** 是否已到末页 */
  @Trace isEnd: boolean = false;
  /** 错误信息（空字符串表示无错误） */
  @Trace errorMessage: string = '';
  /** 是否首次加载完成 */
  @Trace loaded: boolean = false;

  private api: ZhihuApi;
  /** 内容类型（answers 或 articles） */
  private contentType: string;
  /** 内容 ID */
  private contentId: string;
  /** 分页信息 */
  private paging: Paging | null = null;

  constructor(contentType: string, contentId: string, api?: ZhihuApi) {
    this.api = api !== undefined ? api : new ZhihuApi();
    this.contentType = contentType;
    this.contentId = contentId;
  }

  /**
   * 首次加载评论列表。
   *
   * 仅在 loaded=false 时执行，已加载后不重复拉取。
   * 加载完成后设置 loaded=true。
   */
  async loadComments(): Promise<void> {
    if (this.loaded || this.isLoading) {
      return;
    }
    this.isLoading = true;
    this.errorMessage = '';
    try {
      const result: RootCommentsResult = await this.api.fetchRootComments(this.contentType, this.contentId);
      this.comments = result.items;
      this.paging = result.paging;
      this.isEnd = result.paging !== null ? result.paging.isEnd : false;
      this.loaded = true;
      hilog.info(DOMAIN, TAG, 'loadComments: contentId=%{public}s count=%{public}d',
        this.contentId, this.comments.length);
    } catch (err) {
      this.errorMessage = mapApiError(err);
      hilog.error(DOMAIN, TAG, 'loadComments failed: %{public}s', this.errorMessage);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 加载更多（触底加载下一页）。
   *
   * 双重保护：isLoading=true 或 isEnd=true 时直接返回。
   */
  async loadMore(): Promise<void> {
    if (this.isLoading || this.isEnd) {
      return;
    }
    const pagingNext: string | undefined = this.paging !== null ? this.paging.next : undefined;
    if (pagingNext === undefined || pagingNext.length === 0) {
      this.isEnd = true;
      return;
    }
    this.isLoading = true;
    try {
      const result: RootCommentsResult = await this.api.fetchRootComments(this.contentType, this.contentId, undefined, pagingNext);
      // 去重追加：构建新数组并重新赋值以触发 @Trace（@Trace 只观察引用变化，
      // 参考 HomeFeedViewModel.loadMore 的 reassign 模式；原地 push 不会触发 UI 刷新）
      const newComments: Comment[] = [...this.comments];
      const existingIds: Set<string> = new Set();
      for (let i = 0; i < newComments.length; i++) {
        existingIds.add(newComments[i].id);
      }
      for (let i = 0; i < result.items.length; i++) {
        if (!existingIds.has(result.items[i].id)) {
          newComments.push(result.items[i]);
          existingIds.add(result.items[i].id);
        }
      }
      this.comments = newComments;
      this.paging = result.paging;
      this.isEnd = result.paging !== null ? result.paging.isEnd : true;
      hilog.info(DOMAIN, TAG, 'loadMore: contentId=%{public}s added=%{public}d',
        this.contentId, result.items.length);
    } catch (err) {
      this.errorMessage = '加载更多评论失败: ' + mapApiError(err);
      hilog.error(DOMAIN, TAG, 'loadMore failed: %{public}s', this.errorMessage);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 刷新评论列表（清空后重新加载）。
   */
  async refresh(): Promise<void> {
    this.comments = [];
    this.paging = null;
    this.isEnd = false;
    this.loaded = false;
    this.errorMessage = '';
    await this.loadComments();
  }
}

/**
 * 将错误对象映射为可读的错误消息。
 */
function mapApiError(err: object): string {
  if (err instanceof ApiError) {
    if (err.code === ApiErrorCode.NETWORK_ERROR) {
      return '网络错误，请检查网络连接';
    }
    if (err.code === ApiErrorCode.TIMEOUT) {
      return '请求超时，请稍后重试';
    }
    if (err.code === ApiErrorCode.UNAUTHORIZED) {
      return '请先登录';
    }
    if (err.code === ApiErrorCode.RISK_CONTROL) {
      return '请求被拦截，请稍后重试';
    }
    return err.message;
  }
  return '加载评论失败';
}