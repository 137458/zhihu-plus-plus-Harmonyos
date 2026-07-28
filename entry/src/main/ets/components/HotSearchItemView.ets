/**
 * 单条热搜 UI 组件
 *
 * 展示热搜榜单中的一条热搜词：
 * - 左侧：排名序号（前 3 名用主题色高亮，其余用次要色）
 * - 中间：Column（label + 热度数值，格式化为"1234 万"或"5678"）
 * - 右侧：箭头图标（sys.symbol.chevron_right）
 *
 * 样式：
 * - 高度：48vp
 * - 内边距：水平 page_padding_horizontal
 * - 序号颜色：index < 3 用 app_primary，否则用 app_on_surface_secondary
 *
 * 整行可点击，触发 onSelect 回调。
 */

import { HotSearchItem } from '../model/HotSearch';

/** 模块级空 HotSearchItem 实例，作为未传 item 时的默认值 */
const EMPTY_ITEM: HotSearchItem = new HotSearchItem('', '', 0);

/** 列表项高度 */
const ITEM_HEIGHT: number = 48;
/** 排名序号宽度 */
const RANK_WIDTH: number = 32;
/** 排名序号字号 */
const RANK_FONT_SIZE: number = 16;
/** 标签字号 */
const LABEL_FONT_SIZE: number = 14;
/** 热度数值字号 */
const HOT_VALUE_FONT_SIZE: number = 11;
/** 箭头图标尺寸 */
const ARROW_ICON_SIZE: number = 16;
/** 序号高亮阈值（前 3 名高亮） */
const TOP_RANK_THRESHOLD: number = 3;
/** 标签与热度数值间距 */
const LABEL_HOT_MARGIN: number = 2;

@ComponentV2
export struct HotSearchItemView {
  /** 热搜数据，必须传入有效 HotSearchItem */
  @Param item: HotSearchItem = EMPTY_ITEM;
  /** 序号（0-based，用于显示排名；前 3 名高亮） */
  @Param index: number = 0;
  /** 点击回调 */
  @Param onSelect: ((item: HotSearchItem) => void) | undefined = undefined;

  build() {
    Row() {
      // 左侧：排名序号（1-based 显示）
      Text((this.index + 1).toString())
        .fontSize(RANK_FONT_SIZE)
        .fontColor(this.index < TOP_RANK_THRESHOLD ?
          $r('app.color.app_primary') : $r('app.color.app_on_surface_secondary'))
        .fontWeight(FontWeight.Medium)
        .width(RANK_WIDTH)
        .textAlign(TextAlign.Center);

      // 中间：标签 + 热度数值
      Column() {
        Text(this.item.label)
          .fontSize(LABEL_FONT_SIZE)
          .fontColor($r('app.color.app_title_bar_on_surface'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        if (this.item.hotShow > 0) {
          Text(this.formatHotShow(this.item.hotShow))
            .fontSize(HOT_VALUE_FONT_SIZE)
            .fontColor($r('app.color.app_on_surface_secondary'))
            .margin({ top: LABEL_HOT_MARGIN });
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1);

      // 右侧：箭头图标
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(ARROW_ICON_SIZE)
        .fontColor([$r('app.color.app_on_surface_secondary')]);
    }
    .width('100%')
    .height(ITEM_HEIGHT)
    .padding({
      left: $r('app.float.page_padding_horizontal'),
      right: $r('app.float.page_padding_horizontal')
    })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      const cb = this.onSelect;
      if (cb !== undefined) {
        cb(this.item);
      }
    });
  }

  /**
   * 格式化热度数值：
   * - >= 10000 显示为 "x.x 万"
   * - 否则原样显示
   */
  private formatHotShow(num: number): string {
    if (num >= 10000) {
      const wan: number = num / 10000;
      return wan.toFixed(1) + ' 万';
    }
    return num.toString();
  }
}
