/**
 * 回答详情页
 *
 * 通过 NavPathStack.pushPathByName(RouteName.ANSWER_DETAIL, AnswerDetailParams) 进入。
 *
 * 架构（基于 HDS 官方推荐，与 PR #12 对齐）：
 * - build() 直接返回 HdsNavDestination（不再包 NavDestination > HdsNavigation 嵌套）
 *   原因：HdsNavigation navDestination builder 约束要求"HdsNavDestination 外只允许
 *   一层自定义组件，且自定义组件不允许设置属性和事件，否则仅显示空白"
 * - titleBar 配置引用 DETAIL_TITLE_BAR_STYLE / DETAIL_TITLE_BAR_PADDING 常量（4 字段模式三混合写法）
 *
 * 页面结构：
 * - 顶部作者卡：头像 + 姓名 + headline
 * - 所属问题标题（可点击，预留 Slice 6+ 实现）
 * - 中部 ArkWeb 正文：ArticleWebContainer 渲染 content HTML
 * - 底部统计栏：点赞数/评论数/感谢数
 * - 空/错/载状态切换（StateView）
 *
 * 数据来源：AnswerDetailViewModel.load()
 */

import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { DETAIL_TITLE_BAR_STYLE, DETAIL_TITLE_BAR_PADDING } from '../components/PlaceholderPage';
import { AnswerDetailParams } from '../router/AppRouter';
import { AnswerDetailViewModel } from '../viewmodel/AnswerDetailViewModel';
import { AnswerDetail } from '../model/AnswerDetail';
import { ArticleWebContainer } from '../web/ArticleWebContainer';
import { StateView, ViewState } from '../components/StateView';

/** 作者头像尺寸 */
const AVATAR_SIZE: number = 40;

@ComponentV2
export struct AnswerDetailPage {
  /** NavPathStack，由 NavDestination.onReady 注入 */
  @Local navPathStack: NavPathStack | undefined = undefined;
  /** 回答 ID */
  @Local answerId: string = '';
  /** ViewModel 实例 */
  @Local viewModel: AnswerDetailViewModel | null = null;
  /** 是否已初始化 */
  @Local initialized: boolean = false;

  aboutToAppear() {
    if (this.initialized) {
      return;
    }
    this.initialized = true;
    if (this.answerId.length > 0) {
      this.viewModel = AnswerDetailViewModel.getInstance(this.answerId);
      this.viewModel.load();
    }
  }

  build() {
    HdsNavDestination() {
      if (this.viewModel !== null) {
        if (this.viewModel.isLoading && this.viewModel.detail === null) {
          // 加载中（首次加载，detail 为空）
          StateView({ status: ViewState.LOADING });
        } else if (this.viewModel.errorMessage.length > 0 && this.viewModel.detail === null) {
          // 错误态（首次加载失败）
          StateView({
            status: ViewState.ERROR,
            errorMessage: this.viewModel.errorMessage,
            onRetry: () => {
              this.viewModel?.retry();
            }
          });
        } else if (this.viewModel.detail !== null) {
          // 内容态
          this.AnswerContent(this.viewModel.detail as AnswerDetail);
        }
      } else {
        // ViewModel 未初始化（answerId 为空）
        StateView({ status: ViewState.ERROR, errorMessage: '回答 ID 为空' });
      }
    }
    .titleBar({
      padding: DETAIL_TITLE_BAR_PADDING,
      style: DETAIL_TITLE_BAR_STYLE,
      content: {
        title: { mainTitle: $r('app.string.page_answer_detail_title') },
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
      const params = ctx.pathInfo.param as AnswerDetailParams;
      if (params !== null && params !== undefined) {
        this.answerId = params.answerId;
      }
      this.aboutToAppear();
    });
  }

  /**
   * 回答内容：作者卡 + 所属问题 + 正文 + 统计栏
   */
  @Builder
  AnswerContent(detail: AnswerDetail) {
    Column() {
      // 顶部作者卡
      Row() {
        Image(detail.author.avatarUrl)
          .width(AVATAR_SIZE)
          .height(AVATAR_SIZE)
          .borderRadius(AVATAR_SIZE / 2)
          .alt($r('app.color.app_surface_variant'));

        Column() {
          Text(detail.author.name)
            .fontSize(16)
            .fontColor($r('app.color.app_on_surface'))
            .fontWeight(FontWeight.Medium);
          if (detail.author.headline !== undefined && detail.author.headline.length > 0) {
            Text(detail.author.headline)
              .fontSize(12)
              .fontColor($r('app.color.app_on_surface_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 2 });
          }
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12 })
        .layoutWeight(1);
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 });

      // 所属问题标题
      Column() {
        Text(detail.question.title)
          .fontSize(18)
          .fontColor($r('app.color.app_on_surface'))
          .fontWeight(FontWeight.Medium)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 12 });

      // ArkWeb 正文容器
      Column() {
        ArticleWebContainer({
          htmlContent: detail.content
        });
      }
      .layoutWeight(1)
      .width('100%');

      // 底部统计栏
      Row() {
        Text(`▲ ${this.formatCount(detail.voteupCount)}`)
          .fontSize(13)
          .fontColor($r('app.color.app_on_surface_secondary'));
        Row() {
          SymbolGlyph($r('sys.symbol.bubble'))
            .fontSize(14)
            .fontColor([$r('app.color.app_on_surface_secondary')]);
          Text(this.formatCount(detail.commentCount))
            .fontSize(13)
            .fontColor($r('app.color.app_on_surface_secondary'))
            .margin({ left: 4 });
        }
        .margin({ left: 16 });
        Row() {
          SymbolGlyph($r('sys.symbol.hand_thumbs_up'))
            .fontSize(14)
            .fontColor([$r('app.color.app_on_surface_secondary')]);
          Text(this.formatCount(detail.thanksCount))
            .fontSize(13)
            .fontColor($r('app.color.app_on_surface_secondary'))
            .margin({ left: 4 });
        }
        .margin({ left: 16 });
        if (detail.ipInfo.length > 0) {
          Text(`· ${detail.ipInfo}`)
            .fontSize(12)
            .fontColor($r('app.color.app_on_surface_secondary'))
            .margin({ left: 16 });
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .justifyContent(FlexAlign.Start);

      // 错误信息（加载正文后仍可能有错误，如 WebView 加载失败）
      if (this.viewModel !== null && this.viewModel.errorMessage.length > 0) {
        Text(this.viewModel.errorMessage)
          .fontSize(13)
          .fontColor($r('app.color.app_error'))
          .padding({ left: 16, right: 16, bottom: 12 });
      }
    }
    .width('100%')
    .height('100%');
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
}
