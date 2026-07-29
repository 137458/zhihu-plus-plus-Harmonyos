/**
 * 搜索页
 *
 * 作为 TabBar 的第二个 Tab，直接渲染内容（不再包 HdsNavigation）。
 * 顶部标题栏由外层 Index.ets 的 HdsNavigation 统一提供。
 *
 * 架构：
 * - 根容器：Column（搜索输入框 + 内容区）
 * - 顶部 TextInput 搜索输入框（onSubmit 提交）
 * - 内容区状态切换：
 *   - 初始态（!hasSubmitted）：热搜榜单 + 搜索历史
 *   - 结果态（hasSubmitted）：搜索结果列表 / 加载中 / 错误 / 无结果
 *
 * 状态管理：
 * - @Local viewModel: SearchViewModel（@ObservedV2 + @Trace 单例）
 * - @Local inputQuery: 当前输入框文本（与 viewModel.query 解耦，便于清空）
 * - build 中读取 viewModel 状态字段建立 @Trace 依赖
 *
 * 交互：
 * - 输入框 onSubmit → viewModel.submitQuery(inputQuery)
 * - 热搜条目 onSelect → 设置 inputQuery + viewModel.submitQuery(item.query)
 * - 历史条目 onSelect → 设置 inputQuery + viewModel.submitQuery(q)
 * - 历史条目 onRemove → viewModel 移除单条（待扩展，本批仅清空全部）
 * - 清空历史按钮 → viewModel.clearHistory()
 * - 结果列表 onReachEnd → viewModel.loadMore()
 *
 * 第 3 批接入详情页跳转后，点击搜索结果会路由到对应内容详情（本批预留空回调）。
 */

import { SearchViewModel } from '../viewmodel/SearchViewModel';
import { StateView, ViewState } from '../components/StateView';
import { SearchResultView } from '../components/SearchResultView';
import { HotSearchItemView } from '../components/HotSearchItemView';
import { SearchHistoryItemView } from '../components/SearchHistoryItemView';
import { SearchResultItem } from '../model/SearchResult';
import { HotSearchItem } from '../model/HotSearch';

/** 搜索输入框高度 */
const SEARCH_INPUT_HEIGHT: number = 48;
/** 搜索输入框圆角 */
const SEARCH_INPUT_CORNER_RADIUS: number = 24;
/** 区块标题字号 */
const SECTION_TITLE_FONT_SIZE: number = 16;
/** 区块标题上下间距 */
const SECTION_TITLE_MARGIN_VERTICAL: number = 12;
/** 清空历史按钮字号 */
const CLEAR_HISTORY_FONT_SIZE: number = 13;
/** 列表项间距 */
const LIST_ITEM_SPACE: number = 8;

@ComponentV2
export struct SearchPage {
  /** ViewModel 单例（@ObservedV2 + @Trace 装饰） */
  @Local viewModel: SearchViewModel = SearchViewModel.getInstance();
  /** 输入框当前文本（与 viewModel.query 解耦，便于清空和编辑） */
  @Local inputQuery: string = '';

  aboutToAppear(): void {
    // 进入搜索页时加载热搜和历史（幂等，已加载不会重复请求）
    this.viewModel.loadHotSearch();
    this.viewModel.loadHistory();
  }

  build() {
    Column() {
      // 搜索输入框
      Row() {
        TextInput({ text: this.inputQuery, placeholder: $r('app.string.search_hint') })
          .width('100%')
          .height(SEARCH_INPUT_HEIGHT)
          .fontSize($r('app.float.card_title_font_size'))
          .fontColor($r('app.color.app_title_bar_on_surface'))
          .placeholderFont({ size: $r('app.float.card_title_font_size') })
          .placeholderColor($r('app.color.app_on_surface_secondary'))
          .backgroundColor($r('app.color.app_surface_variant'))
          .borderRadius(SEARCH_INPUT_CORNER_RADIUS)
          .padding({ left: 16, right: 16 })
          .onChange((value: string) => {
            this.inputQuery = value;
          })
          .onSubmit(() => {
            this.viewModel.submitQuery(this.inputQuery);
          });
      }
      .width('100%')
      .padding({
        left: $r('app.float.page_padding_horizontal'),
        right: $r('app.float.page_padding_horizontal'),
        top: $r('app.float.page_padding_vertical'),
        bottom: $r('app.float.page_padding_vertical')
      });

      // 内容区：根据状态切换
      if (this.viewModel.hasSubmitted) {
        // 已提交搜索：显示结果态
        this.buildResultArea();
      } else {
        // 未提交：显示初始态（热搜 + 历史）
        this.buildInitialArea();
      }
    }
    .width('100%')
    .height('100%');
  }

  /**
   * 初始态：热搜榜单 + 搜索历史。
   *
   * 两块都存在时垂直排列；任一为空时只渲染另一块。
   */
  @Builder
  buildInitialArea() {
    Scroll() {
      Column() {
        // 搜索历史（有历史时显示）
        if (this.viewModel.searchHistory.length > 0) {
          Row() {
            Text($r('app.string.search_history_title'))
              .fontSize(SECTION_TITLE_FONT_SIZE)
              .fontColor($r('app.color.app_title_bar_on_surface'))
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1);

            Text($r('app.string.search_clear_history'))
              .fontSize(CLEAR_HISTORY_FONT_SIZE)
              .fontColor($r('app.color.app_on_surface_secondary'))
              .onClick(() => {
                this.viewModel.clearHistory();
              });
          }
          .width('100%')
          .padding({
            left: $r('app.float.page_padding_horizontal'),
            right: $r('app.float.page_padding_horizontal'),
            top: SECTION_TITLE_MARGIN_VERTICAL,
            bottom: SECTION_TITLE_MARGIN_VERTICAL
          })
          .alignItems(VerticalAlign.Center);

          ForEach(this.viewModel.searchHistory, (q: string) => {
            SearchHistoryItemView({
              query: q,
              onSelect: (query: string) => {
                this.inputQuery = query;
                this.viewModel.submitQuery(query);
              },
              onRemove: (query: string) => {
                // 单条删除待扩展，本批用清空全部替代（避免接口膨胀）
                this.viewModel.clearHistory();
              }
            });
          }, (q: string) => q);
        }

        // 热搜榜单（有热搜时显示）
        if (this.viewModel.hotSearchItems.length > 0) {
          Text($r('app.string.search_hot_title'))
            .fontSize(SECTION_TITLE_FONT_SIZE)
            .fontColor($r('app.color.app_title_bar_on_surface'))
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .padding({
              left: $r('app.float.page_padding_horizontal'),
              right: $r('app.float.page_padding_horizontal'),
              top: SECTION_TITLE_MARGIN_VERTICAL,
              bottom: SECTION_TITLE_MARGIN_VERTICAL
            });

          ForEach(this.viewModel.hotSearchItems, (item: HotSearchItem, index: number) => {
            HotSearchItemView({
              item: item,
              index: index,
              onSelect: (selected: HotSearchItem) => {
                this.inputQuery = selected.query;
                this.viewModel.submitQuery(selected.query);
              }
            });
          }, (item: HotSearchItem) => item.query + '_' + item.label);
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ bottom: $r('app.float.content_bottom_padding_tabbar') });
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off);
  }

  /**
   * 结果态：搜索结果列表 / 加载中 / 错误 / 无结果。
   */
  @Builder
  buildResultArea() {
    Stack() {
      // 结果列表（有数据时显示）
      if (this.viewModel.items.length > 0) {
        List({ space: LIST_ITEM_SPACE }) {
          ForEach(this.viewModel.items, (item: SearchResultItem) => {
            ListItem() {
              SearchResultView({
                item: item,
                onSelect: (selected: SearchResultItem) => {
                  // 第 3 批接入详情页跳转；本批预留空回调
                }
              });
            }
          }, (item: SearchResultItem) => item.type + '_' + item.id);
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

      // 加载中 + 无数据：显示 LoadingView
      if (this.viewModel.isLoading && this.viewModel.items.length === 0) {
        StateView({ status: ViewState.LOADING });
      } else if (this.viewModel.errorMessage.length > 0 && this.viewModel.items.length === 0) {
        // 错误 + 无数据：显示 ErrorView + 重试
        StateView({
          status: ViewState.ERROR,
          errorMessage: this.viewModel.errorMessage,
          onRetry: () => {
            this.viewModel.retry();
          }
        });
      } else if (this.viewModel.items.length === 0 && !this.viewModel.isLoading) {
        // 无结果：显示空态（使用 EmptyView 但自定义文案）
        StateView({ status: ViewState.EMPTY });
      }

      // 底部加载更多指示器（有数据 + 正在加载更多时显示）
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
    .layoutWeight(1);
  }
}
