/**
 * 个人主页（占位实现）
 *
 * 作为 TabBar 的第三个 Tab，直接渲染内容（不再包 PlaceholderPage 或 HdsNavigation）。
 * 顶部标题栏由外层 Index.ets 的 HdsNavigation 统一提供。
 *
 * 本批为占位实现：
 * - 显示用户头像占位 + 昵称占位 + 简介
 * - 显示功能入口列表（关注 / 收藏 / 历史 / 设置）
 * - 登录态判断和跳转逻辑后续批次接入
 *
 * 不引入 ProfileViewModel（后续批次接入登录态后再创建），
 * 避免引入未实现的依赖。
 */

/** 头像尺寸 */
const AVATAR_SIZE: number = 72;
/** 头像圆角（圆形） */
const AVATAR_CORNER_RADIUS: number = 36;
/** 卡片内边距 */
const CARD_PADDING: number = 16;
/** 卡片圆角 */
const CARD_CORNER_RADIUS: number = 12;
/** 功能入口区块上方间距 */
const ENTRIES_SECTION_TOP_MARGIN: number = 16;
/** 功能入口高度 */
const ENTRY_ITEM_HEIGHT: number = 52;
/** 功能入口图标尺寸 */
const ENTRY_ICON_SIZE: number = 22;
/** 功能入口箭头尺寸 */
const ENTRY_ARROW_SIZE: number = 16;
/** 功能入口标题字号 */
const ENTRY_TITLE_FONT_SIZE: number = 15;
/** 昵称字号 */
const NICKNAME_FONT_SIZE: number = 17;
/** 简介字号 */
const BIO_FONT_SIZE: number = 13;
/** 昵称下方间距 */
const NICKNAME_BOTTOM_MARGIN: number = 4;

/** 单条功能入口配置 */
interface ProfileEntryConfig {
  /** 图标资源 */
  icon: Resource;
  /** 标题 */
  title: string;
  /** 唯一标识（用于 ForEach key） */
  id: string;
}

/**
 * 个人主页功能入口列表（占位）。
 *
 * 后续批次接入跳转时，每项增加 onPush 回调。
 */
function buildProfileEntries(): ProfileEntryConfig[] {
  const entries: ProfileEntryConfig[] = [
    { icon: $r('sys.symbol.star'), title: '我的关注', id: 'entry_following' },
    { icon: $r('sys.symbol.bookmark'), title: '我的收藏', id: 'entry_bookmarks' },
    { icon: $r('sys.symbol.clock'), title: '浏览历史', id: 'entry_history' },
    { icon: $r('sys.symbol.gearshape'), title: '设置', id: 'entry_settings' }
  ];
  return entries;
}

@ComponentV2
export struct ProfilePage {
  /** 功能入口配置（静态，无 ViewModel） */
  @Local entries: ProfileEntryConfig[] = buildProfileEntries();

  build() {
    Scroll() {
      Column() {
        // 用户信息卡片
        Row() {
          // 头像占位（复用 startIcon 作为占位图，避免新增媒体资源）
          Image($r('app.media.startIcon'))
            .width(AVATAR_SIZE)
            .height(AVATAR_SIZE)
            .borderRadius(AVATAR_CORNER_RADIUS)
            .backgroundColor($r('app.color.app_surface_variant'));

          // 昵称 + 简介（占位：使用已有的未登录文案）
          Column() {
            Text($r('app.string.profile_not_logged_in'))
              .fontSize(NICKNAME_FONT_SIZE)
              .fontColor($r('app.color.app_title_bar_on_surface'))
              .fontWeight(FontWeight.Medium)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });

            Text($r('app.string.profile_not_logged_in_hint'))
              .fontSize(BIO_FONT_SIZE)
              .fontColor($r('app.color.app_on_surface_secondary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: NICKNAME_BOTTOM_MARGIN });
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: 16 });
        }
        .width('100%')
        .padding(CARD_PADDING)
        .backgroundColor($r('app.color.app_surface'))
        .borderRadius(CARD_CORNER_RADIUS)
        .alignItems(VerticalAlign.Center);

        // 功能入口列表
        Column() {
          ForEach(this.entries, (item: ProfileEntryConfig) => {
            Row() {
              SymbolGlyph(item.icon)
                .fontSize(ENTRY_ICON_SIZE)
                .fontColor([$r('app.color.app_title_bar_on_surface')]);

              Text(item.title)
                .fontSize(ENTRY_TITLE_FONT_SIZE)
                .fontColor($r('app.color.app_title_bar_on_surface'))
                .margin({ left: 12 })
                .layoutWeight(1);

              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(ENTRY_ARROW_SIZE)
                .fontColor([$r('app.color.app_on_surface_secondary')]);
            }
            .width('100%')
            .height(ENTRY_ITEM_HEIGHT)
            .padding({ left: CARD_PADDING, right: CARD_PADDING })
            .alignItems(VerticalAlign.Center)
            .onClick(() => {
              // 第 3 批接入跳转；本批预留空回调
            });
          }, (item: ProfileEntryConfig) => item.id);
        }
        .width('100%')
        .margin({ top: ENTRIES_SECTION_TOP_MARGIN })
        .backgroundColor($r('app.color.app_surface'))
        .borderRadius(CARD_CORNER_RADIUS);
      }
      .width('100%')
      .padding({
        left: $r('app.float.page_padding_horizontal'),
        right: $r('app.float.page_padding_horizontal'),
        top: $r('app.float.page_padding_vertical'),
        bottom: $r('app.float.content_bottom_padding_tabbar')
      })
      .alignItems(HorizontalAlign.Center);
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off);
  }
}
