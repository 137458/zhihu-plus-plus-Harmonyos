/**
 * 单卡片 UI 组件
 *
 * 展示首页信息流卡片：
 * - 顶部：标题（最多 2 行，加粗）
 * - 中部：摘要（最多 3 行，灰色小字；为空时不渲染）
 * - 缩略图（可选，右侧 80x80，加载失败显示占位灰块）
 * - 底部：作者头像（24x24 圆形）+ 作者名 + headline + 互动数（点赞 + 评论）
 *
 * 卡片样式：
 * - 圆角白色背景
 * - 卡片间距 8vp（由调用方 List space 控制）
 * - 内边距：水平 14vp，垂直 12vp
 *
 * 第 2 批仅展示，点击跳转详情页在第 3 批实现（本批预留 onCardClick 回调）。
 *
 * 注意：@Param 装饰的对象类型必须有默认值，
 * 故定义模块级 EMPTY_CARD 作为未传入时的占位（所有字段为空）。
 * 实际使用时调用方必须传入有效 FeedCard。
 */

import { FeedCard } from '../model/FeedCard';
import { Author } from '../model/Author';
import { ContentType } from '../model/ContentType';

/** 模块级空 FeedCard 实例，作为 FeedCardView 未传 card 时的默认值 */
const EMPTY_AUTHOR: Author = new Author('', '', '', '');
const EMPTY_CARD: FeedCard = new FeedCard(
  '', ContentType.UNKNOWN, '', '', EMPTY_AUTHOR, 0, 0, ''
);

/** 缩略图尺寸 */
const THUMBNAIL_SIZE: number = 80;
/** 作者头像尺寸 */
const AVATAR_SIZE: number = 24;

@ComponentV2
export struct FeedCardView {
  /** 卡片数据，必须传入有效 FeedCard */
  @Param card: FeedCard = EMPTY_CARD;
  /** 点击回调（第 3 批接入详情页跳转；本批预留） */
  @Param onCardClick: ((card: FeedCard) => void) | undefined = undefined;

  build() {
    Column() {
      // 顶部：标题 + 缩略图（横向布局）
      Row() {
        // 标题
        Text(this.card.title)
          .fontSize($r('app.float.card_title_font_size'))
          .fontColor($r('app.color.app_on_surface'))
          .fontWeight(FontWeight.Medium)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1);

        // 缩略图（可选）
        if (this.card.thumbnail !== undefined && this.card.thumbnail.length > 0) {
          Image(this.card.thumbnail)
            .width(THUMBNAIL_SIZE)
            .height(THUMBNAIL_SIZE)
            .borderRadius($r('app.float.card_corner_radius'))
            .objectFit(ImageFit.Cover)
            .margin({ left: 12 })
            .alt($r('app.color.app_surface_variant'));
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top);

      // 摘要（可选，为空时不渲染）
      if (this.card.excerpt.length > 0) {
        Text(this.card.excerpt)
          .fontSize($r('app.float.card_summary_font_size'))
          .fontColor($r('app.color.app_on_surface_secondary'))
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 8 });
      }

      // 底部：作者信息 + 互动数
      Row() {
        // 作者头像
        Image(this.card.author.avatarUrl)
          .width(AVATAR_SIZE)
          .height(AVATAR_SIZE)
          .borderRadius(AVATAR_SIZE / 2)
          .alt($r('app.color.app_surface_variant'));

        // 作者名 + headline
        Text(this.card.author.name)
          .fontSize($r('app.float.card_meta_font_size'))
          .fontColor($r('app.color.app_on_surface_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: 6 });

        // 互动数（右侧）
        Row() {
          Text(`▲ ${this.formatCount(this.card.voteupCount)}`)
            .fontSize($r('app.float.card_meta_font_size'))
            .fontColor($r('app.color.app_on_surface_secondary'));
          Row() {
            SymbolGlyph($r('sys.symbol.doc_text'))
              .fontSize(14)
              .fontColor([$r('app.color.app_on_surface_secondary')]);
            Text(this.formatCount(this.card.commentCount))
              .fontSize($r('app.float.card_meta_font_size'))
              .fontColor($r('app.color.app_on_surface_secondary'))
              .margin({ left: 4 });
          }
          .margin({ left: 12 });
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.End);
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 12 });
    }
    .width('100%')
    .padding({
      left: $r('app.float.card_padding_horizontal'),
      right: $r('app.float.card_padding_horizontal'),
      top: $r('app.float.card_padding_vertical'),
      bottom: $r('app.float.card_padding_vertical')
    })
    .backgroundColor($r('app.color.app_card_background'))
    .borderRadius($r('app.float.card_corner_radius'))
    .onClick(() => {
      const cb = this.onCardClick;
      if (cb !== undefined) {
        cb(this.card);
      }
    });
  }

  /**
   * 格式化数字：超过 10000 显示为 "x.x万"，否则原样显示。
   */
  private formatCount(count: number): string {
    if (count >= 10000) {
      const wan: number = count / 10000;
      // 保留 1 位小数
      return wan.toFixed(1) + '万';
    }
    return count.toString();
  }
}
