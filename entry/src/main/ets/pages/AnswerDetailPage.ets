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
import { VotersViewModel, VoteContentType } from '../viewmodel/VotersViewModel';
import { VoteState } from '../model/VoteState';
import { CollectionsViewModel, CollectionContentType } from '../viewmodel/CollectionsViewModel';
import { CollectionPickerDialog } from '../components/CollectionPickerDialog';
import { CommentViewModel } from '../viewmodel/CommentViewModel';
import { CommentListView } from '../components/CommentListView';
import { SessionViewModel } from '../viewmodel/SessionViewModel';
import { ToastUtil } from '../utils/ToastUtil';

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
  /** 点赞 ViewModel */
  private votersVM: VotersViewModel = VotersViewModel.getInstance();
  /** 收藏 ViewModel */
  private collectionsVM: CollectionsViewModel = CollectionsViewModel.getInstance();
  /** 收藏夹选择器是否显示 */
  @Local showCollectionDialog: boolean = false;
  /** 会话 ViewModel */
  private sessionVM: SessionViewModel = SessionViewModel.getInstance();
  /** 评论 ViewModel */
  @Local commentVM: CommentViewModel | null = null;
  /** 是否显示评论列表 */
  @Local showComments: boolean = false;

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

  /** 监听 ViewModel 变化，在 detail 加载完成后初始化点赞状态并加载收藏状态 */
  @Monitor('viewModel')
  onViewModelChange(): void {
    if (this.viewModel !== null && this.viewModel.detail !== null) {
      this.votersVM.initContent(this.viewModel.detail.id, VoteState.NEUTRAL, this.viewModel.detail.voteupCount);
      // 加载收藏状态（仅登录用户）
      if (this.sessionVM.isLoggedIn) {
        const urlToken: string = this.sessionVM.profile?.urlToken ?? '';
        if (urlToken.length > 0) {
          this.collectionsVM.loadCollections(urlToken);
        }
        this.collectionsVM.loadContentCollections('answer', this.viewModel.detail.id);
      }
      // 初始化评论 ViewModel
      if (this.commentVM === null) {
        this.commentVM = new CommentViewModel('answers', this.viewModel.detail.id);
      }
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

      // 收藏夹选择器对话框
      if (this.showCollectionDialog) {
        CollectionPickerDialog({
          options: {
            show: this.showCollectionDialog,
            onClose: () => {
              this.showCollectionDialog = false;
            },
            onConfirm: (selectedIds: string[]) => {
              this.handleCollectionConfirm(selectedIds);
            }
          }
        });
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

      // 底部统计栏（含点赞/收藏/评论按钮）
      Row() {
        // 点赞按钮
        Row() {
          SymbolGlyph($r('sys.symbol.hand_thumbsup'))
            .fontSize(16)
            .fontColor([this.voteButtonColor(detail.id)]);
          Text(this.formatCount(this.voteDisplayCount(detail.id, detail.voteupCount)))
            .fontSize(13)
            .fontColor(this.voteButtonColor(detail.id))
            .margin({ left: 4 });
        }
        .margin({ left: 0 })
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .borderRadius(16)
        .backgroundColor(this.voteButtonBgColor(detail.id))
        .onClick(() => {
          this.handleVoteClick(detail.id);
        });
        // 收藏按钮
        Row() {
          SymbolGlyph($r('sys.symbol.bookmark'))
            .fontSize(16)
            .fontColor([this.collectionButtonColor()]);
          Text(this.collectionButtonText())
            .fontSize(13)
            .fontColor(this.collectionButtonColor())
            .margin({ left: 4 });
        }
        .margin({ left: 8 })
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .borderRadius(16)
        .backgroundColor(this.collectionButtonBgColor())
        .onClick(() => {
          this.handleCollectionClick(detail.id);
        });
        // 评论数
        Row() {
          SymbolGlyph($r('sys.symbol.doc_text'))
            .fontSize(14)
            .fontColor([$r('app.color.app_on_surface_secondary')]);
          Text(this.formatCount(detail.commentCount))
            .fontSize(13)
            .fontColor($r('app.color.app_on_surface_secondary'))
            .margin({ left: 4 });
        }
        .margin({ left: 16 })
        .onClick(() => {
          this.handleCommentClick();
        });
        // 感谢数
        Row() {
          SymbolGlyph($r('sys.symbol.hand_thumbsup_fill'))
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

      // 评论列表
      if (this.commentVM !== null && this.showComments) {
        CommentListView({
          viewModel: this.commentVM,
          totalCount: detail.commentCount
        });
      }

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

  /**
   * 获取点赞按钮颜色：已点赞为蓝色，否则为次级文字色。
   */
  private voteButtonColor(contentId: string): ResourceColor {
    if (this.votersVM.getVoteState(contentId) === VoteState.UP) {
      return $r('app.color.app_title_bar_background');
    }
    return $r('app.color.app_on_surface_secondary');
  }

  /**
   * 获取点赞按钮背景色：已点赞为蓝色，否则透明。
   */
  private voteButtonBgColor(contentId: string): ResourceColor {
    if (this.votersVM.getVoteState(contentId) === VoteState.UP) {
      return $r('app.color.app_title_bar_background');
    }
    return Color.Transparent;
  }

  /**
   * 获取显示点赞数：优先使用 VotersViewModel 中的值，否则使用详情页的初始值。
   */
  private voteDisplayCount(contentId: string, detailVoteCount: number): number {
    const vmCount: number = this.votersVM.getVoteCount(contentId);
    if (vmCount > 0) {
      return vmCount;
    }
    return detailVoteCount;
  }

  /**
   * 处理点赞按钮点击。
   *
   * 未登录时提示跳转；已登录时调用 VotersViewModel 切换点赞状态。
   */
  private handleVoteClick(contentId: string): void {
    if (!this.sessionVM.isLoggedIn) {
      ToastUtil.show('请先登录');
      return;
    }
    this.votersVM.toggleVoteUp(contentId, VoteContentType.ANSWER);
  }

  /**
   * 处理评论按钮点击。
   *
   * 切换评论列表的显示/隐藏。首次点击时自动加载评论。
   */
  private handleCommentClick(): void {
    this.showComments = !this.showComments;
    if (this.showComments && this.commentVM !== null && !this.commentVM.loaded && !this.commentVM.isLoading) {
      this.commentVM.loadComments();
    }
  }

  // ──── 收藏相关方法 ────

  /**
   * 获取收藏按钮颜色：内容已收藏为蓝色，否则为次级文字色。
   */
  private collectionButtonColor(): ResourceColor {
    if (this.collectionsVM.isContentCollected()) {
      return $r('app.color.app_title_bar_background');
    }
    return $r('app.color.app_on_surface_secondary');
  }

  /**
   * 获取收藏按钮文字。
   */
  private collectionButtonText(): string {
    return '收藏';
  }

  /**
   * 获取收藏按钮背景色：内容已收藏为蓝色，否则透明。
   */
  private collectionButtonBgColor(): ResourceColor {
    if (this.collectionsVM.isContentCollected()) {
      return $r('app.color.app_title_bar_background');
    }
    return Color.Transparent;
  }

  /**
   * 处理收藏按钮点击。
   *
   * 未登录时提示跳转；已登录时加载收藏夹列表并弹出选择器。
   */
  private handleCollectionClick(contentId: string): void {
    if (!this.sessionVM.isLoggedIn) {
      ToastUtil.show('请先登录');
      return;
    }
    // 加载收藏夹列表（如果尚未加载）
    const urlToken: string = this.sessionVM.profile?.urlToken ?? '';
    if (urlToken.length > 0) {
      this.collectionsVM.loadCollections(urlToken);
    }
    this.showCollectionDialog = true;
  }

  /**
   * 处理收藏夹选择器确认。
   *
   * 计算需要添加和移除的收藏夹，逐个执行操作。
   */
  private async handleCollectionConfirm(selectedIds: string[]): Promise<void> {
    const prevIds: string[] = this.collectionsVM.contentCollectionIds;
    // 计算需要添加的（在 selectedIds 但不在 prevIds）
    const toAdd: string[] = [];
    for (let i = 0; i < selectedIds.length; i++) {
      let found: boolean = false;
      for (let j = 0; j < prevIds.length; j++) {
        if (selectedIds[i] === prevIds[j]) {
          found = true;
          break;
        }
      }
      if (!found) {
        toAdd.push(selectedIds[i]);
      }
    }
    // 计算需要移除的（在 prevIds 但不在 selectedIds）
    const toRemove: string[] = [];
    for (let i = 0; i < prevIds.length; i++) {
      let found: boolean = false;
      for (let j = 0; j < selectedIds.length; j++) {
        if (prevIds[i] === selectedIds[j]) {
          found = true;
          break;
        }
      }
      if (!found) {
        toRemove.push(prevIds[i]);
      }
    }

    // 关闭对话框
    this.showCollectionDialog = false;

    // 逐个执行操作（toggleCollection 内部处理乐观更新和回滚）
    const contentType: string = 'answer';
    const contentId: string = this.answerId;

    // 先添加收藏，再移除收藏
    for (let i = 0; i < toAdd.length; i++) {
      await this.collectionsVM.toggleCollection(contentType, contentId, toAdd[i]);
    }
    for (let i = 0; i < toRemove.length; i++) {
      await this.collectionsVM.toggleCollection(contentType, contentId, toRemove[i]);
    }
  }
}
