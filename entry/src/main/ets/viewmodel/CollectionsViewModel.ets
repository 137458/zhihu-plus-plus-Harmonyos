/**
 * 收藏状态管理 ViewModel（Slice 2）
 *
 * 单例模式，管理用户收藏夹列表和内容收藏状态。
 * @ObservedV2 + @Trace 装饰确保状态变化触发 UI 刷新。
 *
 * 功能：
 * - 加载用户收藏夹列表
 * - 加载指定内容已被哪些收藏夹收录
 * - 收藏/取消收藏操作（乐观更新 + 失败回滚）
 * - 防重复操作节流
 *
 * 参考 Android 端 ArticleViewModel.toggleFavorite + CollectionsViewModel 实现：
 * - 收藏：PUT /collections/contents/{contentType}/{id}，body add_collections={id}
 * - 取消收藏：PUT /collections/contents/{contentType}/{id}，body remove_collections={id}
 * - 不走 zse 签名，仅依赖 Cookie
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { Collection } from '../model/Collection';
import { CollectionsResult } from '../api/ZhihuApi';
import { ZhihuApi } from '../api/ZhihuApi';
import { ToastUtil } from '../utils/ToastUtil';
import { mapApiError } from '../utils/ErrorMessageUtil';

const DOMAIN: number = 0x0000;
const TAG: string = 'CollectionsViewModel';

/** 内容类型：回答或文章 */
export enum CollectionContentType {
  ANSWER = 'answer',
  ARTICLE = 'article'
}

@ObservedV2
export class CollectionsViewModel {
  /** 单例 */
  private static instance: CollectionsViewModel;

  /** 用户收藏夹列表 */
  @Trace collections: Collection[] = [];

  /** 当前内容已被哪些收藏夹收录（ID 集合） */
  @Trace contentCollectionIds: string[] = [];

  /** 是否正在加载收藏夹列表 */
  @Trace isLoading: boolean = false;

  /** 是否正在执行收藏操作 */
  @Trace isOperating: boolean = false;

  /** 是否已加载过收藏夹列表 */
  private loaded: boolean = false;

  /** API 客户端 */
  private api: ZhihuApi;

  private constructor() {
    this.api = new ZhihuApi();
  }

  /** 获取单例 */
  static getInstance(): CollectionsViewModel {
    if (CollectionsViewModel.instance === undefined) {
      CollectionsViewModel.instance = new CollectionsViewModel();
    }
    return CollectionsViewModel.instance;
  }

  // ──── 公开查询方法 ────

  /**
   * 指定内容是否已被收藏（在任意收藏夹中）。
   */
  isContentCollected(): boolean {
    return this.contentCollectionIds.length > 0;
  }

  /**
   * 指定收藏夹是否包含当前内容。
   */
  isCollectionSelected(collectionId: string): boolean {
    for (let i = 0; i < this.contentCollectionIds.length; i++) {
      if (this.contentCollectionIds[i] === collectionId) {
        return true;
      }
    }
    return false;
  }

  // ──── 公开操作方法 ────

  /**
   * 加载用户收藏夹列表。
   *
   * 已加载过不会重复加载。
   *
   * @param urlToken 用户 urlToken
   */
  async loadCollections(urlToken: string): Promise<void> {
    if (this.loaded) {
      return;
    }
    this.isLoading = true;
    try {
      const result: CollectionsResult = await this.api.fetchUserCollections(urlToken);
      this.collections = result.items;
      this.loaded = true;
      hilog.info(DOMAIN, TAG, 'loadCollections: count=%{public}d', this.collections.length);
    } catch (err) {
      const errMsg: string = mapApiError(err);
      hilog.error(DOMAIN, TAG, 'loadCollections failed: %{public}s', errMsg);
      // 失败时不覆盖已有数据，静默处理
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 加载指定内容被哪些收藏夹收录。
   *
   * @param contentType 内容类型
   * @param contentId 内容 ID
   */
  async loadContentCollections(contentType: string, contentId: string): Promise<void> {
    try {
      const collections: Collection[] = await this.api.fetchContentCollections(contentType, contentId);
      const ids: string[] = [];
      for (let i = 0; i < collections.length; i++) {
        ids.push(collections[i].id);
      }
      this.contentCollectionIds = ids;
      hilog.info(DOMAIN, TAG, 'loadContentCollections: contentId=%{public}s count=%{public}d',
        contentId, ids.length);
    } catch (err) {
      const errMsg: string = mapApiError(err);
      hilog.error(DOMAIN, TAG, 'loadContentCollections failed: %{public}s', errMsg);
      // 失败时清空列表
      this.contentCollectionIds = [];
    }
  }

  /**
   * 切换指定内容的收藏状态。
   *
   * 如果内容已在指定收藏夹中 → 取消收藏
   * 如果内容不在指定收藏夹中 → 添加收藏
   *
   * @param contentType 内容类型
   * @param contentId 内容 ID
   * @param collectionId 收藏夹 ID
   * @returns 操作成功返回 true，失败返回 false
   */
  async toggleCollection(
    contentType: string,
    contentId: string,
    collectionId: string
  ): Promise<boolean> {
    if (this.isOperating) {
      hilog.info(DOMAIN, TAG, 'toggleCollection: already operating');
      return false;
    }

    const isCurrentlyCollected: boolean = this.isCollectionSelected(collectionId);
    this.isOperating = true;

    // 保存快照（用于回滚）
    const snapshotIds: string[] = [...this.contentCollectionIds];

    // 乐观更新
    this.updateContentCollectionIds(collectionId, !isCurrentlyCollected);

    try {
      if (isCurrentlyCollected) {
        // 取消收藏
        await this.api.removeFromCollection(contentType, contentId, collectionId);
        ToastUtil.show('已取消收藏');
      } else {
        // 添加收藏
        await this.api.addToCollection(contentType, contentId, collectionId);
        ToastUtil.show('已收藏');
      }
      hilog.info(DOMAIN, TAG, 'toggleCollection success: contentId=%{public}s collectionId=%{public}s',
        contentId, collectionId);
      return true;
    } catch (err) {
      // 失败：回滚
      this.contentCollectionIds = snapshotIds;
      const errMsg: string = mapApiError(err);
      ToastUtil.show('收藏操作失败: ' + errMsg);
      hilog.error(DOMAIN, TAG, 'toggleCollection failed: %{public}s', errMsg);
      return false;
    } finally {
      this.isOperating = false;
    }
  }

  /**
   * 重置收藏夹列表加载状态（用于重新加载）。
   */
  resetLoaded(): void {
    this.loaded = false;
  }

  // ──── 内部方法 ────

  /**
   * 更新 contentCollectionIds（通过 reassign 触发 @Trace）。
   */
  private updateContentCollectionIds(collectionId: string, add: boolean): void {
    const newIds: string[] = [...this.contentCollectionIds];
    if (add) {
      // 添加
      for (let i = 0; i < newIds.length; i++) {
        if (newIds[i] === collectionId) {
          return; // 已存在
        }
      }
      newIds.push(collectionId);
    } else {
      // 移除
      for (let i = 0; i < newIds.length; i++) {
        if (newIds[i] === collectionId) {
          const removed: string[] = [];
          for (let j = 0; j < newIds.length; j++) {
            if (j !== i) {
              removed.push(newIds[j]);
            }
          }
          this.contentCollectionIds = removed;
          return;
        }
      }
      return; // 不存在
    }
    this.contentCollectionIds = newIds;
  }
}