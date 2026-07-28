/**
 * 单条搜索结果 UI 组件
 *
 * 展示搜索结果条目：
 * - 顶部 Row：类型标识（如"回答"/"文章"/"问题"，从 item.type 映射到中文，
 *   未知类型不显示）+ 标题（最多 2 行）
 * - 中间：摘要（item.excerpt，最多 3 行，省略号）
 * - 底部 Row：作者头像（小圆形）+ 作者名 + 高亮文本（如果有）
 *
 * 样式参考 FeedCardView：
 * - 卡片背景：app_card_background
 * - 圆角：card_corner_radius
 * - 内边距：垂直 card_padding_vertical / 水平 page_padding_horizontal
 * - 标题字号：card_title_font_size，颜色 app_title_bar_on_surface
 * - 摘要字号：card_excerpt_font_size，颜色 app_on_surface_secondary
 * - 类型标识：小圆角背景（app_surface_variant）+ 主题色文字（app_primary），
 *   字号比标题小（card_meta_font_size）
 *
 * 点击整个卡片触发 onSelect 回调。
 *
 * 注意：@Param 装饰的对象类型必须有默认值，
 * 故定义模块级 EMPTY_ITEM 作为未传入时的占位（所有字段为空）。
 * 实际使用时调用方必须传入有效 SearchResultItem。
 */

import { SearchResultItem } from '../model/SearchResult';

/** 模块级空 SearchResultItem 实例，作为未传 item 时的默认值 */
const EMPTY_ITEM: SearchResultItem = new SearchResultItem('', '', '', '');

/** 作者头像尺寸 */
const AVATAR_SIZE: number = 24;
/** 类型标识内边距（水平） */
const TYPE_TAG_PADDING_H: number = 6;
/** 类型标识内边距（垂直） */
const TYPE_TAG_PADDING_V: number = 2;
/** 类型标识圆角 */
const TYPE_TAG_CORNER_RADIUS: number = 4;
/** 类型标识与标题间距 */
const TYPE_TAG_MARGIN_END: number = 8;
/** 作者头像与作者名间距 */
const AVATAR_NAME_MARGIN: number = 6;
/** 作者名与高亮文本间距 */
const NAME_HIGHLIGHT_MARGIN: number = 12;
/** 摘要与上方元素间距 */
const EXCERPT_TOP_MARGIN: number = 8;
/** 底部行与上方元素间距 */
const BOTTOM_ROW_TOP_MARGIN: number = 12;

@ComponentV2
export struct SearchResultView {
  /** 搜索结果数据，必须传入有效 SearchResultItem */
  @Param item: SearchResultItem = EMPTY_ITEM;
  /** 点击回调 */
  @Param onSelect: ((item: SearchResultItem) => void) | undefined = undefined;

  build() {
    Column() {
      // 顶部：类型标识 + 标题（横向布局）
      Row() {
        // 类型标识（未知类型不渲染）
        if (this.typeToString(this.item.type).length > 0) {
          Text(this.typeToString(this.item.type))
            .fontSize($r('app.float.card_meta_font_size'))
            .fontColor($r('app.color.app_primary'))
            .backgroundColor($r('app.color.app_surface_variant'))
            .padding({
              left: TYPE_TAG_PADDING_H,
              right: TYPE_TAG_PADDING_H,
              top: TYPE_TAG_PADDING_V,
              bottom: TYPE_TAG_PADDING_V
            })
            .borderRadius(TYPE_TAG_CORNER_RADIUS)
            .margin({ right: TYPE_TAG_MARGIN_END });
        }

        // 标题（最多 2 行）
        Text(this.item.title)
          .fontSize($r('app.float.card_title_font_size'))
          .fontColor($r('app.color.app_title_bar_on_surface'))
          .fontWeight(FontWeight.Medium)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1);
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      // 摘要（可选，为空时不渲染）
      if (this.item.excerpt.length > 0) {
        Text(this.item.excerpt)
          .fontSize($r('app.float.card_excerpt_font_size'))
          .fontColor($r('app.color.app_on_surface_secondary'))
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: EXCERPT_TOP_MARGIN });
      }

      // 底部：作者信息 + 高亮文本（任一存在时渲染）
      if (this.item.author !== undefined ||
          (this.item.highlight !== undefined && this.item.highlight.length > 0)) {
        Row() {
          // 作者头像 + 作者名（仅 author 存在时渲染）
          if (this.item.author !== undefined) {
            Image(this.item.author.avatarUrl)
              .width(AVATAR_SIZE)
              .height(AVATAR_SIZE)
              .borderRadius(AVATAR_SIZE / 2)
              .alt($r('app.color.app_surface_variant'));

            Text(this.item.author.name)
              .fontSize($r('app.float.card_meta_font_size'))
              .fontColor($r('app.color.app_on_surface_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ left: AVATAR_NAME_MARGIN })
              .layoutWeight(1);
          } else if (this.item.highlight !== undefined && this.item.highlight.length > 0) {
            // 无作者时，高亮文本占满整行
            Text(this.item.highlight)
              .fontSize($r('app.float.card_meta_font_size'))
              .fontColor($r('app.color.app_on_surface_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1);
          }

          // 高亮文本（右侧，仅当作者存在且高亮存在时显示）
          if (this.item.author !== undefined && this.item.highlight !== undefined &&
              this.item.highlight.length > 0) {
            Text(this.item.highlight)
              .fontSize($r('app.float.card_meta_font_size'))
              .fontColor($r('app.color.app_on_surface_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ left: NAME_HIGHLIGHT_MARGIN });
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: BOTTOM_ROW_TOP_MARGIN });
      }
    }
    .width('100%')
    .padding({
      left: $r('app.float.page_padding_horizontal'),
      right: $r('app.float.page_padding_horizontal'),
      top: $r('app.float.card_padding_vertical'),
      bottom: $r('app.float.card_padding_vertical')
    })
    .backgroundColor($r('app.color.app_card_background'))
    .borderRadius($r('app.float.card_corner_radius'))
    .onClick(() => {
      const cb = this.onSelect;
      if (cb !== undefined) {
        cb(this.item);
      }
    });
  }

  /**
   * 类型标识映射为中文显示文本。
   * - 'answer' → '回答'
   * - 'article' → '文章'
   * - 'question' → '问题'
   * - 'pin' → '想法'
   * - 'zvideo' → '视频'
   * - 其他 → ''（不显示）
   */
  private typeToString(type: string): string {
    switch (type) {
      case 'answer':
        return '回答';
      case 'article':
        return '文章';
      case 'question':
        return '问题';
      case 'pin':
        return '想法';
      case 'zvideo':
        return '视频';
      default:
        return '';
    }
  }
}
