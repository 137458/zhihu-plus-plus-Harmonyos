/**
 * 个人主页
 *
 * 作为 TabBar 的第三个 Tab，直接渲染内容（不再包 PlaceholderPage 或 HdsNavigation）。
 * 顶部标题栏由外层 Index.ets 的 HdsNavigation 统一提供。
 *
 * 登录态感知（第 4 批 Slice 3 接入）：
 * - 通过 @Local 引用 SessionViewModel 单例，读取 isLoggedIn / profile
 * - 未登录：显示占位头像 + "未登录" + 登录提示，点击用户卡片触发 onLoginClick
 * - 已登录：显示用户头像（avatarUrl）+ 昵称 + "已登录知乎账号"
 * - 功能入口（关注/收藏/历史）：未登录时点击触发 onLoginClick；已登录暂为占位
 * - 设置入口：始终触发 onSettingsClick
 *
 * 回调注入：
 * - onLoginClick: 由 Index.ets 注入，push LoginPage
 * - onSettingsClick: 由 Index.ets 注入，push SettingsPage
 *
 * 状态管理：
 * - @Local sessionViewModel: SessionViewModel（@ObservedV2 + @Trace 单例）
 * - build 中读取 isLoggedIn/profile 建立依赖，登录态变化触发 build 重新执行
 */

import { SessionViewModel } from '../viewmodel/SessionViewModel';
import { ZhihuProfile } from '../model/ZhihuProfile';

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
  /** 唯一标识（用于 ForEach key 和点击分发） */
  id: string;
}

/** 入口 ID 常量（与 buildProfileEntries 中的 id 对应） */
const ENTRY_ID_FOLLOWING: string = 'entry_following';
const ENTRY_ID_BOOKMARKS: string = 'entry_bookmarks';
const ENTRY_ID_HISTORY: string = 'entry_history';
const ENTRY_ID_SETTINGS: string = 'entry_settings';

/**
 * 个人主页功能入口列表。
 *
 * 后续批次接入跳转时，通过 entry.id 在 handleEntryClick 中分发。
 */
function buildProfileEntries(): ProfileEntryConfig[] {
  const entries: ProfileEntryConfig[] = [
    { icon: $r('sys.symbol.star'), title: '我的关注', id: ENTRY_ID_FOLLOWING },
    { icon: $r('sys.symbol.bookmark'), title: '我的收藏', id: ENTRY_ID_BOOKMARKS },
    { icon: $r('sys.symbol.clock'), title: '浏览历史', id: ENTRY_ID_HISTORY },
    { icon: $r('sys.symbol.gearshape'), title: '设置', id: ENTRY_ID_SETTINGS }
  ];
  return entries;
}

@ComponentV2
export struct ProfilePage {
  /** 登录入口点击回调（由 Index.ets 注入，push LoginPage） */
  @Param onLoginClick: (() => void) | undefined = undefined;
  /** 设置入口点击回调（由 Index.ets 注入，push SettingsPage） */
  @Param onSettingsClick: (() => void) | undefined = undefined;

  /** 会话 ViewModel（@ObservedV2 + @Trace 单例） */
  @Local sessionViewModel: SessionViewModel = SessionViewModel.getInstance();

  /** 功能入口配置（静态） */
  @Local entries: ProfileEntryConfig[] = buildProfileEntries();

  build() {
    Scroll() {
      Column() {
        // 用户信息卡片：登录态优先，profile=null 时仍按已登录渲染
        if (this.sessionViewModel.isLoggedIn) {
          this.buildLoggedInUserCard();
        } else {
          this.buildLoggedOutUserCard();
        }

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
              this.handleEntryClick(item.id);
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

  /**
   * 已登录用户信息卡片 Builder。
   *
   * 登录态优先策略：
   * - isLoggedIn=true && profile!=null：显示头像（avatarUrl）+ 昵称（name）+ 已登录提示
   * - isLoggedIn=true && profile==null：显示占位头像 + 占位昵称 + 已登录提示
   *   （验证失败但 z_c0 有效的中间态，避免与未登录态混淆）
   *
   * 卡片不可点击（已登录状态下无需跳转登录页）。
   */
  @Builder
  buildLoggedInUserCard() {
    Row() {
      // 头像：profile 存在时从网络加载，否则使用占位图
      if (this.sessionViewModel.profile !== null) {
        Image(this.sessionViewModel.profile.avatarUrl)
          .width(AVATAR_SIZE)
          .height(AVATAR_SIZE)
          .borderRadius(AVATAR_CORNER_RADIUS)
          .backgroundColor($r('app.color.app_surface_variant'))
          .alt($r('app.media.startIcon'));
      } else {
        Image($r('app.media.startIcon'))
          .width(AVATAR_SIZE)
          .height(AVATAR_SIZE)
          .borderRadius(AVATAR_CORNER_RADIUS)
          .backgroundColor($r('app.color.app_surface_variant'));
      }

      Column() {
        // 昵称：profile 存在时显示用户昵称，否则显示占位昵称
        if (this.sessionViewModel.profile !== null) {
          Text(this.sessionViewModel.profile.name)
            .fontSize(NICKNAME_FONT_SIZE)
            .fontColor($r('app.color.app_title_bar_on_surface'))
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        } else {
          Text($r('app.string.profile_logged_in_hint'))
            .fontSize(NICKNAME_FONT_SIZE)
            .fontColor($r('app.color.app_title_bar_on_surface'))
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }

        Text($r('app.string.profile_logged_in_hint'))
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
  }

  /**
   * 未登录用户信息卡片 Builder。
   *
   * 显示占位头像、"未登录"标题和登录提示。
   * 点击整个卡片触发 onLoginClick 回调，跳转到登录页。
   */
  @Builder
  buildLoggedOutUserCard() {
    Row() {
      // 头像占位（复用 startIcon 作为占位图，避免新增媒体资源）
      Image($r('app.media.startIcon'))
        .width(AVATAR_SIZE)
        .height(AVATAR_SIZE)
        .borderRadius(AVATAR_CORNER_RADIUS)
        .backgroundColor($r('app.color.app_surface_variant'));

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
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      const cb = this.onLoginClick;
      if (cb !== undefined) {
        cb();
      }
    });
  }

  /**
   * 功能入口点击分发。
   *
   * - 设置入口：始终触发 onSettingsClick（无论登录态）
   * - 其他入口（关注/收藏/历史）：未登录时触发 onLoginClick；已登录暂为占位（后续批次实现）
   *
   * @param entryId 入口唯一标识
   */
  private handleEntryClick(entryId: string): void {
    if (entryId === ENTRY_ID_SETTINGS) {
      const cb = this.onSettingsClick;
      if (cb !== undefined) {
        cb();
      }
      return;
    }
    // 其他入口：未登录时跳转登录页
    if (!this.sessionViewModel.isLoggedIn) {
      const cb = this.onLoginClick;
      if (cb !== undefined) {
        cb();
      }
      return;
    }
    // 已登录但目标页未实现，暂不处理
  }
}
