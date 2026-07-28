/**
 * 首页（推荐信息流）
 *
 * 作为 TabBar 的默认页，直接渲染内容（不再包 HdsNavigation）。
 * 顶部标题栏由外层 Index.ets 的 HdsNavigation 统一提供。
 *
 * 架构：
 * - 根容器：Stack（承载列表 + 状态视图 + 加载更多指示器）
 * - Refresh + List + LazyForEach 渲染信息流卡片
 *   - 下拉触发 viewModel.pullToRefresh()
 *   - 触底 onReachEnd 触发 viewModel.loadMore()
 * - StateView 覆盖层：加载中/空态/错误态切换
 * - 底部加载更多指示器（isLoading 且 items > 0 时显示）
 *
 * 卡片点击跳转（第 3 批 Slice 2 接入）：
 * - 由 Index.ets 注入 onCardClick 回调
 * - HomePage.handleCardClick 根据 card.contentType 分发：
 *   - QUESTION 类型 → onCardClick(card) → Index.ets 推送到 QuestionDetailPage
 *   - ANSWER 类型 → onCardClick(card) → Index.ets 推送到 AnswerDetailPage
 *   - ARTICLE 类型 → onCardClick(card) → Index.ets 推送到 ArticleDetailPage
 * - 其他类型（PIN/ZVIDEO）暂未实现，预留回调
 *
 * 状态管理：
 * - @Local viewModel: HomeFeedViewModel（@ObservedV2 + @Trace 单例）
 * - build 中读取 viewModel.items 等字段建立 @Trace 依赖
 * - items 引用变化时触发 build 重新执行，同步到 FeedCardDataSource
 */

import { HomeFeedViewModel } from '../viewmodel/HomeFeedViewModel';
import { FeedCardDataSource } from '../viewmodel/FeedCardDataSource';
import { StateView, ViewState } from '../components/StateView';
import { FeedCardView } from '../components/FeedCardView';
import { FeedCard } from '../model/FeedCard';
import { ContentType } from '../model/ContentType';

@ComponentV2
export struct HomePage {
  /**
   * 卡片点击跳转回调，由 Index.ets 注入。
   *
   * 参数：
   * - card: 被点击的 FeedCard
   *
   * Index.ets 根据 card.contentType 分发到不同详情页：
   * - QUESTION → pushPathByName(RouteName.QUESTION_DETAIL, {questionId, previewTitle})
   * - ANSWER → pushPathByName(RouteName.ANSWER_DETAIL, {answerId})
   * - ARTICLE → pushPathByName(RouteName.ARTICLE_DETAIL, {articleId})
   */
  @Param onCardClick: ((card: FeedCard) => void) | undefined = undefined;

  /** ViewModel 单例（@ObservedV2 + @Trace 装饰） */
  @Local viewModel: HomeFeedViewModel = HomeFeedViewModel.getInstance();

  /** LazyForEach 数据源 */
  private dataSource: FeedCardDataSource = new FeedCardDataSource();

  aboutToAppear(): void {
    // 首次进入首页时自动加载（如果列表为空）
    this.viewModel.loadIfEmpty();
    // 初始同步一次 dataSource（@Monitor 不会在首次赋值时触发）
    this.dataSource.setItems(this.viewModel.items);
  }

  /**
   * 监听 viewModel.items 引用变化，同步到 LazyForEach 数据源。
   *
   * ArkUI V2 的 @Trace 仅观察引用变化，@Monitor 会在引用变化时回调。
   * loadMore / pullToRefresh 成功后都会重新赋值 items 触发本回调。
   */
  @Monitor('viewModel.items')
  onItemsChange(): void {
    this.dataSource.setItems(this.viewModel.items);
  }

  build() {
    Stack() {
      // 列表内容（items > 0 时渲染）
      if (this.viewModel.items.length > 0) {
        Refresh({ refreshing: this.viewModel.isPullToRefresh }) {
          List({ space: 8 }) {
            LazyForEach(this.dataSource, (item: FeedCard) => {
              ListItem() {
                FeedCardView({
                  card: item,
                  onCardClick: (card: FeedCard) => {
                    this.handleCardClick(card);
                  }
                });
              }
            }, (item: FeedCard) => item.stableKey);
          }
          .width('100%')
          .height('100%')
          .padding({
            left: $r('app.float.page_padding_horizontal'),
            right: $r('app.float.page_padding_horizontal'),
            top: $r('app.float.page_padding_vertical'),
            bottom: $r('app.float.content_bottom_padding_tabbar')
          })
          .onReachEnd(() => {
            this.viewModel.loadMore();
          });
        }
        .width('100%')
        .height('100%')
        .onRefreshing(() => {
          this.viewModel.pullToRefresh();
        });
      }

      // 状态视图覆盖层（非内容态时显示）
      // 加载中 + 列表为空：显示 LoadingView
      if (this.viewModel.isLoading && this.viewModel.items.length === 0) {
        StateView({ status: ViewState.LOADING });
      } else if (this.viewModel.errorMessage.length > 0 && this.viewModel.items.length === 0) {
        // 错误 + 列表为空：显示 ErrorView + 重试
        StateView({
          status: ViewState.ERROR,
          errorMessage: this.viewModel.errorMessage,
          onRetry: () => {
            this.viewModel.retry();
          }
        });
      } else if (this.viewModel.items.length === 0 && !this.viewModel.isLoading) {
        // 空态：列表为空且未加载
        StateView({ status: ViewState.EMPTY });
      }

      // 底部加载更多指示器（列表非空 + 正在加载更多时显示）
      // 定位在 TabBar 上方，避免被悬浮 TabBar 遮挡
      if (this.viewModel.items.length > 0 && this.viewModel.isLoading) {
        Column() {
          LoadingProgress()
            .width($r('app.float.loading_indicator_size'))
            .height($r('app.float.loading_indicator_size'))
            .color($r('app.color.app_loading'));
        }
        .width('100%')
        .height(56)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .position({ x: 0, y: '100%' })
        .markAnchor({ x: 0, y: '100%' })
        .offset({ y: -72 });
      }
    }
    .width('100%')
    .height('100%');
  }

  /**
   * 处理卡片点击，分发到对应详情页跳转回调。
   *
   * 由 Index.ets 注入的 onCardClick 回调根据 contentType 分发：
   * - QUESTION → QuestionDetailPage（本批已实现）
   * - ANSWER → AnswerDetailPage（Slice 3 实现）
   * - ARTICLE → ArticleDetailPage（Slice 4 实现）
   * - 其他 → no-op（避免误触）
   */
  private handleCardClick(card: FeedCard): void {
    const cb = this.onCardClick;
    if (cb === undefined) {
      return;
    }
    // 仅处理已实现的类型，其他类型暂不跳转
    if (card.contentType === ContentType.QUESTION
      || card.contentType === ContentType.ANSWER
      || card.contentType === ContentType.ARTICLE) {
      cb(card);
    }
  }
}
