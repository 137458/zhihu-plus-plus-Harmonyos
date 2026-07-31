/**
 * 问题详情页
 *
 * 通过 NavPathStack.pushPathByName(RouteName.QUESTION_DETAIL, QuestionDetailParams) 进入。
 *
 * 架构（基于 HDS 官方推荐，与 PR #12 对齐）：
 * - build() 直接返回 HdsNavDestination（不再包 NavDestination > HdsNavigation 嵌套）
 *   原因：HdsNavigation navDestination builder 约束要求"HdsNavDestination 外只允许
 *   一层自定义组件，且自定义组件不允许设置属性和事件，否则仅显示空白"
 * - titleBar 配置引用 DETAIL_TITLE_BAR_STYLE / DETAIL_TITLE_BAR_PADDING 常量（4 字段模式三混合写法）
 *
 * 页面结构：
 * - 顶部问题信息区：标题 + 统计（N 个回答 · N 浏览 · N 关注）+ 描述（可折叠，简化为首屏全部展示）
 * - 中部回答列表：LazyForEach + FeedCardView，触底加载更多
 * - 错误/加载/空态：StateView
 *
 * 数据来源：
 * - QuestionDetailViewModel.loadIfEmpty() 并行加载 detail + answers 首页
 * - 回答列表点击跳转 AnswerDetailPage（Slice 3 实现，本批预留 onAnswerClick 回调）
 *
 * HDS 规范参考：
 * - 模式三混合写法 4 字段：scrollEffectOpts + systemMaterialEffect + originalStyle + scrollEffectStyle
 * - 参考项目：tieba-lite/HDS_Spec.md 1.4 节
 */

import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DETAIL_TITLE_BAR_STYLE, DETAIL_TITLE_BAR_PADDING } from '../components/PlaceholderPage';
import { QuestionDetailParams } from '../router/AppRouter';
import { QuestionDetailViewModel } from '../viewmodel/QuestionDetailViewModel';
import { QuestionDetail } from '../model/QuestionDetail';
import { FeedCard } from '../model/FeedCard';
import { FeedCardView } from '../components/FeedCardView';
import { FeedCardDataSource } from '../viewmodel/FeedCardDataSource';

/** 日志常量 */
const DOMAIN: number = 0x0000;
const TAG: string = 'QuestionDetailPage';

@ComponentV2
export struct QuestionDetailPage {
  /** NavPathStack，由 NavDestination.onReady 注入 */
  @Local navPathStack: NavPathStack | undefined = undefined;
  /** 问题 ID，由路由参数注入 */
  @Local questionId: string = '';
  /** 预览标题（路由参数，detail 加载前显示） */
  @Local previewTitle: string = '';
  /** ViewModel 实例（aboutToAppear 时根据 questionId 获取） */
  @Local viewModel: QuestionDetailViewModel | null = null;
  /** LazyForEach 数据源 */
  @Local dataSource: FeedCardDataSource = new FeedCardDataSource();
  /** 是否已初始化（避免重复 aboutToAppear） */
  @Local initialized: boolean = false;

  aboutToAppear() {
    if (this.initialized) {
      return;
    }
    // NavDestination 的路由参数仅在 onReady 中可用，而 aboutToAppear 由 ArkUI
    // 生命周期在 onReady 之前自动调用（此时 questionId 仍为初始空串）。
    // 仅当 ID 真正可用时才标记 initialized，使 onReady 设置 ID 后再次调用
    // aboutToAppear 时能继续创建 ViewModel 并加载数据，避免页面永久停留在空态。
    if (this.questionId.length > 0) {
      this.initialized = true;
      this.viewModel = QuestionDetailViewModel.getInstance(this.questionId);
      // 同步当前已有数据（如从缓存恢复）
      this.refreshDataSource();
      // 触发首次加载
      this.viewModel.loadIfEmpty().then(() => {
        this.refreshDataSource();
      });
    }
  }

  /**
   * 同步 ViewModel 的 answers 到 DataSource。
   *
   * ViewModel.answers 是 @Trace 数组，引用变化时触发本组件 build，
   * build 中调用本方法同步到 DataSource，DataSource 通知 LazyForEach 重新渲染。
   */
  private refreshDataSource(): void {
    if (this.viewModel !== null) {
      this.dataSource.setItems(this.viewModel.answers);
    }
  }

  build() {
    HdsNavDestination() {
      // 内容区：List 承载问题信息头 + 回答列表
      List({ space: 8 }) {
        // 顶部问题信息区
        if (this.viewModel !== null && this.viewModel.detail !== null) {
          ListItem() {
            this.QuestionHeader(this.viewModel.detail as QuestionDetail);
          }
        } else if (this.viewModel !== null && this.viewModel.isLoadingDetail) {
          // 问题详情加载中
          ListItem() {
            Column() {
              Text(this.previewTitle.length > 0 ? this.previewTitle : $r('app.string.page_question_detail_title'))
                .fontSize(20)
                .fontColor($r('app.color.app_on_surface'))
                .fontWeight(FontWeight.Medium)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis });
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 });
          }
        }

        // 回答列表区
        if (this.viewModel !== null && this.viewModel.answers.length > 0) {
          ListItem() {
            Text($r('app.string.question_answers_section_title'))
              .fontSize(14)
              .fontColor($r('app.color.app_on_surface_secondary'))
              .padding({ left: 16, right: 16, top: 8, bottom: 8 });
          }

          LazyForEach(this.dataSource, (card: FeedCard) => {
            ListItem() {
              FeedCardView({
                card: card,
                onCardClick: (clickedCard: FeedCard) => {
                  this.onAnswerClick(clickedCard);
                }
              });
            }
          }, (card: FeedCard) => card.stableKey);
        } else if (this.viewModel !== null && this.viewModel.isLoadingAnswers && this.viewModel.answers.length === 0) {
          // 回答列表加载中
          ListItem() {
            Column() {
              LoadingProgress()
                .width(32)
                .height(32);
            }
            .width('100%')
            .padding({ top: 32, bottom: 32 })
            .justifyContent(FlexAlign.Center);
          }
        }
      }
      .width('100%')
      .height('100%')
      .layoutWeight(1)
      .onReachEnd(() => {
        if (this.viewModel !== null) {
          this.viewModel.loadMoreAnswers().then(() => {
            this.refreshDataSource();
          });
        }
      });
    }
    .titleBar({
      padding: DETAIL_TITLE_BAR_PADDING,
      style: DETAIL_TITLE_BAR_STYLE,
      content: {
        title: { mainTitle: this.getPageTitle() },
        backIcon: {
          label: 'back',
          icon: $r('sys.symbol.chevron_left'),
          isEnabled: true,
          componentId: 'back',
          action: () => {
            const stack = this.navPathStack;
            if (stack !== undefined) {
              stack.pop();
            }
          }
        }
      }
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onReady((ctx: NavDestinationContext) => {
      this.navPathStack = ctx.pathStack;
      const params = ctx.pathInfo.param as QuestionDetailParams;
      if (params !== null && params !== undefined) {
        this.questionId = params.questionId;
        const preview: string | undefined = params.previewTitle;
        if (preview !== undefined) {
          this.previewTitle = preview;
        }
      }
      this.aboutToAppear();
    });
  }

  /**
   * 获取页面标题。
   *
   * 优先级：detail.title > previewTitle > 默认标题。
   */
  private getPageTitle(): string | Resource {
    if (this.viewModel !== null && this.viewModel.detail !== null) {
      return (this.viewModel.detail as QuestionDetail).title;
    }
    if (this.previewTitle.length > 0) {
      return this.previewTitle;
    }
    return $r('app.string.page_question_detail_title');
  }

  /**
   * 问题信息头：标题 + 统计 + 描述。
   */
  @Builder
  QuestionHeader(detail: QuestionDetail) {
    Column() {
      // 问题标题
      Text(detail.title)
        .fontSize(20)
        .fontColor($r('app.color.app_on_surface'))
        .fontWeight(FontWeight.Medium)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%');

      // 统计信息
      Row() {
        Text(`${this.formatCount(detail.answerCount)} 个回答`)
          .fontSize(12)
          .fontColor($r('app.color.app_on_surface_secondary'));
        Text(` · ${this.formatCount(detail.visitCount)} 浏览`)
          .fontSize(12)
          .fontColor($r('app.color.app_on_surface_secondary'));
        Text(` · ${this.formatCount(detail.followerCount)} 关注`)
          .fontSize(12)
          .fontColor($r('app.color.app_on_surface_secondary'));
      }
      .width('100%')
      .margin({ top: 8 });

      // 问题详情（HTML，简化为纯文本展示）
      if (detail.detail.length > 0) {
        Text(this.stripHtml(detail.detail))
          .fontSize(14)
          .fontColor($r('app.color.app_on_surface_secondary'))
          .maxLines(5)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 12 });
      }

      // 错误信息（如果有）
      if (this.viewModel !== null && this.viewModel.errorMessage.length > 0) {
        Text(this.viewModel.errorMessage)
          .fontSize(13)
          .fontColor($r('app.color.app_error'))
          .width('100%')
          .margin({ top: 8 });
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 });
  }

  /**
   * 回答卡片点击回调。
   *
   * Slice 3 实现跳转到 AnswerDetailPage。
   * 本批预留，仅打印日志。
   */
  private onAnswerClick(card: FeedCard): void {
    hilog.info(DOMAIN, TAG, 'onAnswerClick: cardId=%{public}s (Slice 3 will implement push)', card.rawId);
  }

  /**
   * 格式化数字：超过 10000 显示为 "x.x万"，否则原样显示。
   */
  private formatCount(count: number): string {
    if (count >= 10000) {
      const wan: number = count / 10000;
      return wan.toFixed(1) + '万';
    }
    return count.toString();
  }

  /**
   * 简易 HTML 标签去除（仅用于问题详情描述的纯文本预览）。
   *
   * 注意：本方法只做最简去除，不做完整 HTML 解析。
   * 完整的 HTML 渲染在 Slice 3/4 的 ArkWeb 容器中实现。
   */
  private stripHtml(html: string): string {
    return html.replace(/<[^>]+>/g, '');
  }
}
