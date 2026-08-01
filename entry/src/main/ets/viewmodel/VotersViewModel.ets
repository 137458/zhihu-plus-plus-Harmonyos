/**
 * 点赞/取消点赞 ViewModel（Slice 1）
 *
 * 单例模式，管理所有内容（回答/文章）的点赞状态。
 * @ObservedV2 + @Trace 装饰确保状态变化触发 UI 刷新。
 *
 * 状态管理策略：
 * - 使用 entries 数组存储每条内容的点赞状态
 * - 状态变更时通过 reassign 触发 @Trace
 * - 乐观更新 + 失败回滚：先更新 UI，API 失败后恢复原状态
 *
 * 防重复与节流：
 * - isLoading 标志阻止 API 完成前的重复点击
 * - 内容类型区分：回答走 answer 逻辑（type up/neutral），文章走 article 逻辑（voting 1/0）
 *
 * 参考 Android 端 ArticleViewModel.toggleVoteUp 实现：
 * - 回答：POST /api/v4/answers/{id}/voters，body {"type":"up"|"neutral"}
 * - 文章：POST /api/v4/articles/{id}/voters，body {"voting":1|0}
 * - 异常时展示 Toast 错误信息
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { VoteState } from '../model/VoteState';
import { ZhihuApi } from '../api/ZhihuApi';
import { ToastUtil } from '../utils/ToastUtil';
import { mapApiError } from '../utils/ErrorMessageUtil';

const DOMAIN: number = 0x0000;
const TAG: string = 'VotersViewModel';

/** 内容类型：回答或文章 */
export enum VoteContentType {
  ANSWER = 'answer',
  ARTICLE = 'article'
}

/** 点赞状态条目 */
interface VoteStateEntry {
  /** 内容 ID（回答 ID 或文章 ID） */
  contentId: string;
  /** 当前点赞状态 */
  voteState: VoteState;
  /** 点赞数 */
  voteCount: number;
  /** 是否正在加载（用于防重复点击） */
  isLoading: boolean;
}

/** 点赞状态快照（用于失败回滚） */
interface VoteStateSnapshot {
  voteState: VoteState;
  voteCount: number;
}

@ObservedV2
export class VotersViewModel {
  /** 单例 */
  private static instance: VotersViewModel;

  /** 点赞状态条目列表 */
  @Trace entries: VoteStateEntry[] = [];

  /** API 客户端 */
  private api: ZhihuApi;

  private constructor() {
    this.api = new ZhihuApi();
  }

  /** 获取单例 */
  static getInstance(): VotersViewModel {
    if (VotersViewModel.instance === undefined) {
      VotersViewModel.instance = new VotersViewModel();
    }
    return VotersViewModel.instance;
  }

  // ──── 公开查询方法 ────

  /**
   * 获取指定内容的点赞状态。
   * 未记录时返回 NEUTRAL。
   */
  getVoteState(contentId: string): VoteState {
    const entry: VoteStateEntry | null = this.findEntry(contentId);
    if (entry !== null) {
      return entry.voteState;
    }
    return VoteState.NEUTRAL;
  }

  /**
   * 获取指定内容的点赞数。
   * 未记录时返回 0。
   */
  getVoteCount(contentId: string): number {
    const entry: VoteStateEntry | null = this.findEntry(contentId);
    if (entry !== null) {
      return entry.voteCount;
    }
    return 0;
  }

  /**
   * 指定内容是否正在加载（防重复点击）。
   */
  isLoading(contentId: string): boolean {
    const entry: VoteStateEntry | null = this.findEntry(contentId);
    if (entry !== null) {
      return entry.isLoading;
    }
    return false;
  }

  // ──── 公开操作方法 ────

  /**
   * 初始化或更新指定内容的初始状态。
   *
   * 在详情页加载完成后调用，确保 VotersViewModel 持有该内容的状态。
   * 如果该内容已被记录，不覆盖已有状态。
   *
   * @param contentId 内容 ID
   * @param initialVoteState 初始点赞状态
   * @param initialVoteCount 初始点赞数
   */
  initContent(contentId: string, initialVoteState: VoteState, initialVoteCount: number): void {
    const existing: VoteStateEntry | null = this.findEntry(contentId);
    if (existing !== null) {
      return;
    }
    const newEntries: VoteStateEntry[] = [...this.entries];
    newEntries.push({
      contentId: contentId,
      voteState: initialVoteState,
      voteCount: initialVoteCount,
      isLoading: false
    });
    this.entries = newEntries;
    hilog.info(DOMAIN, TAG, 'initContent: contentId=%{public}s state=%{public}s count=%{public}d',
      contentId, initialVoteState, initialVoteCount);
  }

  /**
   * 切换点赞状态。
   *
   * 逻辑（参考 Android 端 toggleVoteUp）：
   * 1. 当前为 NEUTRAL → 设为 UP（点赞）
   * 2. 当前为 UP → 设为 NEUTRAL（取消点赞）
   * 3. 乐观更新：先更新 UI，API 失败后回滚
   *
   * @param contentId 内容 ID
   * @param contentType 内容类型（ANSWER 或 ARTICLE）
   * @returns 操作成功返回 true，失败返回 false
   */
  async toggleVoteUp(contentId: string, contentType: VoteContentType): Promise<boolean> {
    if (this.isLoading(contentId)) {
      hilog.info(DOMAIN, TAG, 'toggleVoteUp: already loading, contentId=%{public}s', contentId);
      return false;
    }

    // 获取当前状态，计算新状态
    const currentState: VoteState = this.getVoteState(contentId);
    const newState: VoteState = currentState === VoteState.UP ? VoteState.NEUTRAL : VoteState.UP;

    // 保存快照（用于回滚）
    const snapshot: VoteStateSnapshot = {
      voteState: currentState,
      voteCount: this.getVoteCount(contentId)
    };

    // 乐观更新：更新加载状态
    this.setLoading(contentId, true);
    hilog.info(DOMAIN, TAG, 'toggleVoteUp: contentId=%{public}s %{public}s -> %{public}s',
      contentId, currentState, newState);

    try {
      // 调用 API
      let newVoteCount: number = 0;
      if (contentType === VoteContentType.ANSWER) {
        // 回答点赞：POST /api/v4/answers/{id}/voters，body {"type":"up"|"neutral"}
        const typeValue: string = newState === VoteState.UP ? 'up' : 'neutral';
        newVoteCount = await this.api.voteAnswer(contentId, typeValue);
      } else {
        // 文章点赞：POST /api/v4/articles/{id}/voters，body {"voting":1|0}
        const voting: number = newState === VoteState.UP ? 1 : 0;
        newVoteCount = await this.api.voteArticle(contentId, voting);
      }

      // 成功：更新状态和点赞数
      this.updateEntryState(contentId, newState, newVoteCount);

      // 显示 Toast
      if (newState === VoteState.UP) {
        ToastUtil.show('已赞同');
      } else {
        ToastUtil.show('已取消赞同');
      }

      return true;
    } catch (err) {
      // 失败：回滚到原状态
      this.updateEntryState(contentId, snapshot.voteState, snapshot.voteCount);
      const errMsg: string = mapApiError(err);
      ToastUtil.show('点赞失败: ' + errMsg);
      hilog.error(DOMAIN, TAG, 'toggleVoteUp failed: contentId=%{public}s err=%{public}s',
        contentId, errMsg);
      return false;
    } finally {
      this.setLoading(contentId, false);
    }
  }

  // ──── 内部方法 ────

  /**
   * 查找指定内容的条目。
   */
  private findEntry(contentId: string): VoteStateEntry | null {
    for (let i = 0; i < this.entries.length; i++) {
      if (this.entries[i].contentId === contentId) {
        return this.entries[i];
      }
    }
    return null;
  }

  /**
   * 设置 loading 状态（通过 reassign 触发 @Trace）。
   */
  private setLoading(contentId: string, isLoading: boolean): void {
    const newEntries: VoteStateEntry[] = [...this.entries];
    for (let i = 0; i < newEntries.length; i++) {
      if (newEntries[i].contentId === contentId) {
        newEntries[i] = {
          contentId: newEntries[i].contentId,
          voteState: newEntries[i].voteState,
          voteCount: newEntries[i].voteCount,
          isLoading: isLoading
        };
        this.entries = newEntries;
        return;
      }
    }
  }

  /**
   * 更新指定内容的状态和点赞数（通过 reassign 触发 @Trace）。
   */
  private updateEntryState(contentId: string, voteState: VoteState, voteCount: number): void {
    const newEntries: VoteStateEntry[] = [...this.entries];
    for (let i = 0; i < newEntries.length; i++) {
      if (newEntries[i].contentId === contentId) {
        newEntries[i] = {
          contentId: newEntries[i].contentId,
          voteState: voteState,
          voteCount: voteCount,
          isLoading: newEntries[i].isLoading
        };
        this.entries = newEntries;
        return;
      }
    }
  }
}