/**
 * 文章详情页
 *
 * 通过 NavPathStack.pushPathByName(RouteName.ARTICLE_DETAIL, ArticleDetailParams) 进入。
 *
 * 架构（基于 HDS 官方推荐，与 PR #12 对齐）：
 * - build() 直接返回 HdsNavDestination（不再包 NavDestination > HdsNavigation 嵌套）
 *   原因：HdsNavigation navDestination builder 约束要求"HdsNavDestination 外只允许
 *   一层自定义组件，且自定义组件不允许设置属性和事件，否则仅显示空白"
 * - titleBar 配置引用 DETAIL_TITLE_BAR_STYLE / DETAIL_TITLE_BAR_PADDING 常量（4 字段模式三混合写法）
 *
 * 页面结构：
 * - 顶部：文章标题 + 作者卡（头像/姓名/简介）+ 发布/更新时间
 * - 中间：ArticleWebContainer 渲染 content HTML（复用 Slice 3 组件）
 * - 底部：统计栏（点赞数/评论数）
 * - 空/错/载状态切换（StateView）
 *
 * 数据来源：ArticleDetailViewModel.load()
 */

import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { DETAIL_TITLE_BAR_STYLE, DETAIL_TITLE_BAR_PADDING } from '../components/PlaceholderPage';
import { ArticleDetailParams } from '../router/AppRouter';
import { ArticleDetailViewModel } from '../viewmodel/ArticleDetailViewModel';
import { ArticleDetail } from '../model/ArticleDetail';
import { ArticleWebContainer } from '../web/ArticleWebContainer';
import { StateView, ViewState } from '../components/StateView';

/** 作者头像尺寸 */
const AVATAR_SIZE: number = 40;

@ComponentV2
export struct ArticleDetailPage {
  /** NavPathStack，由 NavDestination.onReady 注入 */
  @Local navPathStack: NavPathStack | undefined = undefined;
  /** 文章 ID */
  @Local articleId: string = '';
  /** ViewModel 实例 */
  @Local viewModel: ArticleDetailViewModel | null = null;
  /** 是否已初始化 */
  @Local initialized: boolean = false;

  aboutToAppear() {
    if (this.initialized) {
      return;
    }
    // NavDestination 的路由参数仅在 onReady 中可用，而 aboutToAppear 由 ArkUI
    // 生命周期在 onReady 之前自动调用（此时 articleId 仍为初始空串）。
    // 仅当 ID 真正可用时才标记 initialized，使 onReady 设置 ID 后再次调用
    // aboutToAppear 时能继续创建 ViewModel 并加载数据，避免页面永久停留在空态。
    if (this.articleId.length > 0) {
      this.initialized = true;
      this.viewModel = ArticleDetailViewModel.getInstance(this.articleId);
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
          this.ArticleContent(this.viewModel.detail as ArticleDetail);
        }
      } else {
        // ViewModel 未初始化（articleId 为空）
        StateView({ status: ViewState.ERROR, errorMessage: '文章 ID 为空' });
      }
    }
    .titleBar({
      padding: DETAIL_TITLE_BAR_PADDING,
      style: DETAIL_TITLE_BAR_STYLE,
      content: {
        title: { mainTitle: $r('app.string.page_article_detail_title') },
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
      const params = ctx.pathInfo.param as ArticleDetailParams;
      if (params !== null && params !== undefined) {
        this.articleId = params.articleId;
      }
      this.aboutToAppear();
    });
  }

  /**
   * 文章内容：标题 + 作者卡 + 时间 + 正文 + 统计栏
   */
  @Builder
  ArticleContent(detail: ArticleDetail) {
    Column() {
      // 文章标题
      Text(detail.title)
        .fontSize(20)
        .fontColor($r('app.color.app_on_surface'))
        .fontWeight(FontWeight.Medium)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 8 });

      // 作者卡
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
      .padding({ left: 16, right: 16, top: 4, bottom: 8 });

      // 发布/更新时间
      Row() {
        Text(`发布于 ${this.formatTime(detail.created)}`)
          .fontSize(12)
          .fontColor($r('app.color.app_on_surface_secondary'));
        if (detail.updated > detail.created) {
          Text(`· 更新于 ${this.formatTime(detail.updated)}`)
            .fontSize(12)
            .fontColor($r('app.color.app_on_surface_secondary'))
            .margin({ left: 8 });
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 });

      // ArkWeb 正文容器（复用 Slice 3 组件）
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
        Text(`💬 ${this.formatCount(detail.commentCount)}`)
          .fontSize(13)
          .fontColor($r('app.color.app_on_surface_secondary'))
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

      // 错误信息
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

  /**
   * 格式化时间戳为 "YYYY-MM-DD" 格式。
   */
  private formatTime(timestamp: number): string {
    if (timestamp <= 0) {
      return '未知';
    }
    const date: Date = new Date(timestamp * 1000);
    const year: number = date.getFullYear();
    const month: number = date.getMonth() + 1;
    const day: number = date.getDate();
    const monthStr: string = month < 10 ? '0' + month : month.toString();
    const dayStr: string = day < 10 ? '0' + day : day.toString();
    return `${year}-${monthStr}-${dayStr}`;
  }
}
