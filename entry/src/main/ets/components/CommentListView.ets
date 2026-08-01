/**
 * 评论列表组件
 *
 * 展示根评论列表，支持分页加载。
 * 首发只读，不支持发表评论/子评论/点赞评论。
 *
 * 使用方式：
 * ```
 * CommentListView({ viewModel: commentVM, totalCount: detail.commentCount })
 * ```
 *
 * 注意：本组件应放在内容详情页的竖向布局中，通过显示/隐藏控制。
 * 当评论列表为空时，不渲染任何内容。
 */

import { CommentViewModel } from '../viewmodel/CommentViewModel';
import { Comment } from '../model/Comment';
import { StateView, ViewState } from '../components/StateView';

/** 作者头像尺寸 */
const AVATAR_SIZE: number = 28;

@ComponentV2
export struct CommentListView {
  /** 评论 ViewModel */
  @Param viewModel: CommentViewModel | null = null;
  /** 评论总数（来自详情页） */
  @Param totalCount: number = 0;

  build() {
    Column() {
      if (this.viewModel !== null) {
        // 加载中状态（首次加载）
        if (this.viewModel.isLoading && !this.viewModel.loaded) {
          StateView({ status: ViewState.LOADING });
        } else if (this.viewModel.errorMessage.length > 0 && this.viewModel.comments.length === 0) {
          // 错误态（首次加载失败）
          StateView({
            status: ViewState.ERROR,
            errorMessage: this.viewModel.errorMessage,
            onRetry: () => {
              this.viewModel?.loadComments();
            }
          });
        } else if (this.viewModel.loaded || this.viewModel.comments.length > 0) {
          // 评论列表
          this.CommentSection();
        }
      }
    }
    .width('100%');
  }

  @Builder
  CommentSection() {
    Column() {
      // 评论标题
      Row() {
        Text('评论 ' + (this.totalCount > 0 ? this.totalCount.toString() : ''))
          .fontSize(16)
          .fontColor($r('app.color.app_on_surface'))
          .fontWeight(FontWeight.Medium);
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4, bottom: 8 });

      // 评论列表
      if (this.viewModel !== null) {
        ForEach(this.viewModel.comments, (comment: Comment) => {
          this.CommentItem(comment);
        }, (comment: Comment) => comment.stableKey());

        // 加载更多/底部状态
        if (this.viewModel.isLoading) {
          // 加载中指示器
          Row() {
            LoadingProgress()
              .width(20)
              .height(20);
            Text('加载中...')
              .fontSize(13)
              .fontColor($r('app.color.app_on_surface_secondary'))
              .margin({ left: 8 });
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 12, bottom: 24 });
        } else if (!this.viewModel.isEnd) {
          // 加载更多按钮
          Row() {
            Text('加载更多')
              .fontSize(14)
              .fontColor($r('app.color.app_primary'))
              .padding({ top: 8, bottom: 8, left: 24, right: 24 });
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 8, bottom: 16 })
          .onClick(() => {
            this.viewModel?.loadMore();
          });
        } else {
          // 没有更多了
          Row() {
            Text('没有更多评论了')
              .fontSize(13)
              .fontColor($r('app.color.app_on_surface_disabled'));
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 12, bottom: 24 });
        }
      }
    }
    .width('100%');
  }

  @Builder
  CommentItem(comment: Comment) {
    Column() {
      // 作者信息行
      Row() {
        // 头像
        Image(comment.author.avatarUrl)
          .width(AVATAR_SIZE)
          .height(AVATAR_SIZE)
          .borderRadius(AVATAR_SIZE / 2)
          .alt($r('app.color.app_surface_variant'));

        // 作者名 + 标签
        Row() {
          Text(comment.author.name)
            .fontSize(14)
            .fontColor($r('app.color.app_on_surface'))
            .fontWeight(FontWeight.Medium);
          if (comment.commentTag !== undefined) {
            Text(comment.commentTag.text)
              .fontSize(11)
              .fontColor($r('app.color.app_primary'))
              .backgroundColor($r('app.color.app_title_bar_background'))
              .borderRadius(4)
              .padding({ left: 6, right: 6, top: 1, bottom: 1 })
              .margin({ left: 6 });
          }
        }
        .margin({ left: 10 })
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center);

        // 时间
        Text(this.formatTime(comment.createdTime))
          .fontSize(12)
          .fontColor($r('app.color.app_on_surface_disabled'));
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      // 回复对象
      if (comment.replyToAuthor !== undefined) {
        Text('回复 @' + comment.replyToAuthor.name)
          .fontSize(13)
          .fontColor($r('app.color.app_on_surface_secondary'))
          .margin({ top: 4 });
      }

      // 评论内容
      Text(comment.content)
        .fontSize(15)
        .fontColor($r('app.color.app_on_surface'))
        .lineHeight(22)
        .width('100%')
        .margin({ top: 4 });

      // 底部操作行（点赞）
      Row() {
        Row() {
          SymbolGlyph($r('sys.symbol.hand_thumbsup'))
            .fontSize(14)
            .fontColor([$r('app.color.app_on_surface_secondary')]);
          if (comment.likeCount > 0) {
            Text(comment.likeCount.toString())
              .fontSize(12)
              .fontColor($r('app.color.app_on_surface_secondary'))
              .margin({ left: 4 });
          }
        }
        .padding({ top: 2, bottom: 2 });

        // 子评论数
        if (comment.childCommentCount > 0) {
          Text(comment.childCommentCount + ' 条回复')
            .fontSize(12)
            .fontColor($r('app.color.app_on_surface_secondary'))
            .margin({ left: 16 });
        }
      }
      .width('100%')
      .margin({ top: 6 });

      // 分割线
      Divider()
        .height(1)
        .color($r('app.color.app_divider'))
        .width('100%')
        .margin({ top: 12, bottom: 12 });
    }
    .width('100%')
    .padding({ left: 16, right: 16 });
  }

  /**
   * 格式化时间戳为相对时间。
   *
   * 规则：
   * - 1 小时内：X 分钟前
   * - 24 小时内：X 小时前
   * - 7 天内：X 天前
   * - 更早：MM-DD
   */
  private formatTime(timestamp: number): string {
    if (timestamp <= 0) {
      return '';
    }
    const now: number = Math.floor(Date.now() / 1000);
    const diff: number = now - timestamp;
    if (diff < 60) {
      return '刚刚';
    }
    if (diff < 3600) {
      return Math.floor(diff / 60).toString() + ' 分钟前';
    }
    if (diff < 86400) {
      return Math.floor(diff / 3600).toString() + ' 小时前';
    }
    if (diff < 604800) {
      return Math.floor(diff / 86400).toString() + ' 天前';
    }
    // 更早的显示日期
    const date: Date = new Date(timestamp * 1000);
    const month: number = date.getMonth() + 1;
    const day: number = date.getDate();
    const monthStr: string = month < 10 ? '0' + month : month.toString();
    const dayStr: string = day < 10 ? '0' + day : day.toString();
    return monthStr + '-' + dayStr;
  }
}