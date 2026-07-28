/**
 * 单条搜索历史 UI 组件
 *
 * 展示搜索历史中的一条记录：
 * - 左侧：搜索图标（sys.symbol.magnifyingglass，小尺寸 16vp）
 * - 中间：历史词文本（最多 1 行省略号）
 * - 右侧：关闭图标（sys.symbol.xmark，可点击，触发 onRemove）
 *
 * 样式：
 * - 高度：40vp
 * - 内边距：水平 page_padding_horizontal
 * - 图标颜色：app_on_surface_secondary
 * - 文字颜色：app_title_bar_on_surface
 *
 * 整行可点击触发 onSelect；删除图标单独可点击触发 onRemove。
 * 当 onRemove 为 undefined 时不渲染关闭图标。
 */

/** 列表项高度 */
const ITEM_HEIGHT: number = 40;
/** 图标尺寸 */
const ICON_SIZE: number = 16;
/** 文本字号 */
const TEXT_FONT_SIZE: number = 14;
/** 图标与文本间距 */
const ICON_TEXT_MARGIN: number = 12;

@ComponentV2
export struct SearchHistoryItemView {
  /** 搜索历史词 */
  @Param query: string = '';
  /** 点击回调 */
  @Param onSelect: ((query: string) => void) | undefined = undefined;
  /** 删除单条历史回调（为 undefined 时不渲染关闭图标） */
  @Param onRemove: ((query: string) => void) | undefined = undefined;

  build() {
    Row() {
      // 左侧：搜索图标
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(ICON_SIZE)
        .fontColor([$r('app.color.app_on_surface_secondary')]);

      // 中间：历史词文本（最多 1 行省略号）
      Text(this.query)
        .fontSize(TEXT_FONT_SIZE)
        .fontColor($r('app.color.app_title_bar_on_surface'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: ICON_TEXT_MARGIN })
        .layoutWeight(1);

      // 右侧：关闭图标（仅当 onRemove 不为 undefined 时渲染）
      if (this.onRemove !== undefined) {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(ICON_SIZE)
          .fontColor([$r('app.color.app_on_surface_secondary')])
          .onClick(() => {
            const cb = this.onRemove;
            if (cb !== undefined) {
              cb(this.query);
            }
          });
      }
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
        cb(this.query);
      }
    });
  }
}
