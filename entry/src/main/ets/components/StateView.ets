/**
 * 统一的空/错/载状态视图
 *
 * 根据 status 属性渲染对应状态：
 * - LOADING: 显示 LoadingView（加载中）
 * - EMPTY: 显示 EmptyView（暂无内容）
 * - ERROR: 显示 ErrorView（加载失败 + 重试按钮）
 * - CONTENT: 渲染空 Column（由调用方在外层 if/else 渲染实际内容）
 *
 * 用法：
 * 调用方根据 ViewModel 状态选择渲染 StateView 或实际内容：
 *   if (vm.isLoading && vm.items.length === 0) {
 *     StateView({ status: ViewState.LOADING })
 *   } else if (vm.errorMessage.length > 0 && vm.items.length === 0) {
 *     StateView({ status: ViewState.ERROR, errorMessage: vm.errorMessage, onRetry: () => vm.retry() })
 *   } else if (vm.items.length === 0) {
 *     StateView({ status: ViewState.EMPTY })
 *   } else {
 *     // 实际列表内容
 *   }
 */

import { LoadingView } from './LoadingView';
import { EmptyView } from './EmptyView';
import { ErrorView } from './ErrorView';

/** 状态枚举 */
export enum ViewState {
  /** 内容态（由调用方渲染） */
  CONTENT,
  /** 加载中 */
  LOADING,
  /** 空态 */
  EMPTY,
  /** 错误态 */
  ERROR
}

@ComponentV2
export struct StateView {
  /** 当前状态，默认 CONTENT（不显示任何状态视图） */
  @Param status: ViewState = ViewState.CONTENT;
  /** 错误态时的错误消息（仅 ERROR 状态使用） */
  @Param errorMessage: string = '';
  /** 重试回调（ERROR 状态显示重试按钮；不传则不显示按钮） */
  @Param onRetry: (() => void) | undefined = undefined;

  build() {
    Column() {
      if (this.status === ViewState.LOADING) {
        LoadingView();
      } else if (this.status === ViewState.EMPTY) {
        EmptyView();
      } else if (this.status === ViewState.ERROR) {
        ErrorView({
          subtitle: this.errorMessage,
          onRetry: this.onRetry
        });
      }
    }
    .width('100%')
    .height('100%');
  }
}
