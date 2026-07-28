/**
 * FeedCard 的 LazyForEach 数据源
 *
 * 实现 ArkUI 的 IDataSource 接口，配合 LazyForEach 组件使用。
 *
 * 工作机制：
 * - HomePage 在 build 中读取 viewModel.items（建立 @Trace 依赖）
 * - viewModel.items 引用变化时触发 HomePage 重新 build
 * - HomePage build 中调用 setItems 同步到本 DataSource
 * - DataSource 通过 DataChangeListener 通知 LazyForEach 重新渲染
 *
 * 性能优化：
 * - setItems 做引用检查，同一引用跳过（避免无谓 reload）
 * - 内部数组直接持有外部引用，不拷贝（外部保证不修改）
 */

import { FeedCard } from '../model/FeedCard';

export class FeedCardDataSource implements IDataSource {
  /** 监听器列表（LazyForEach 内部注册） */
  private listeners: DataChangeListener[] = [];
  /** 当前数据（直接持有外部数组引用，不拷贝） */
  private items: FeedCard[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(idx: number): FeedCard {
    return this.items[idx];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    const idx: number = this.listeners.indexOf(listener);
    if (idx < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const idx: number = this.listeners.indexOf(listener);
    if (idx >= 0) {
      this.listeners.splice(idx, 1);
    }
  }

  /**
   * 设置数据并通知 LazyForEach 重新渲染。
   *
   * 引用检查：如果新数组与当前数组是同一引用，跳过（避免无谓 reload）。
   * 调用方应保证每次 items 变化时创建新引用（如 `[...oldItems, ...newItems]`）。
   */
  setItems(items: FeedCard[]): void {
    if (this.items === items) {
      return;
    }
    this.items = items;
    this.notifyDataReload();
  }

  /** 通知所有监听器数据已全部重新加载 */
  private notifyDataReload(): void {
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataReloaded();
    }
  }
}
