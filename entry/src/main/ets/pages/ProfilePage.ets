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
 * 回答/文章 Tab 列表（Slice 3 新增）：
 * - 登录后用户信息卡片下方显示 Tabs（回答/文章）
 * - 每个 Tab 使用 List + FeedCardView 渲染
 * - 触底加载（onReachEnd）和下拉刷新（Refresh）
 * - 空状态使用 EmptyView
 *
 * 回调注入：
 * - onLoginClick: 由 Index.ets 注入，push LoginPage
 * - onSettingsClick: 由 Index.ets 注入，push SettingsPage
 * - onCardClick: 由 Index.ets 注入，用于跳转详情页（后续批次接入）
 *
 * 状态管理：
 * - @Local sessionViewModel: SessionViewModel（@ObservedV2 + @Trace 单例）
 * - @Local profileVM: ProfileViewModel（@ObservedV2 + @Trace 单例）
 * - build 中读取 isLoggedIn/profile 建立依赖，登录态变化触发 build 重新执行
 */

import { SessionViewModel } from '../viewmodel/SessionViewModel';
import { ProfileViewModel } from '../viewmodel/ProfileViewModel';
import { FeedCard } from '../model/FeedCard';
import { FeedCardView } from '../components/FeedCardView';
import { EmptyView } from '../components/EmptyView';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'ProfilePage';

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
/** 介绍/已登录提示下方间距 */
const NICKNAME_BOTTOM_MARGIN: number = 4;
/** 退出登录按钮区域上边距 */
const LOGOUT_SECTION_TOP_MARGIN: number = 16;
/** 退出登录按钮高度 */
const LOGOUT_BUTTON_HEIGHT: number = 48;
/** 退出登录按钮字体大小 */
const LOGOUT_BUTTON_FONT_SIZE: number = 15;
/** Tab 栏高度 */
const TAB_BAR_HEIGHT: number = 44;
/** Tab 内容区块上方间距 */
const TAB_CONTENT_TOP_MARGIN: number = 12;
/** 统计行高度 */
const STATS_ROW_HEIGHT: number = 36;

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
  /** 退出登录回调（由 Index.ets 注入，调用 SessionViewModel.logout + WebCookie 清理 + NavPathStack 重置） */
  @Param onLogoutClick: (() => void) | undefined = undefined;
  /** 卡片点击回调（由 Index.ets 注入，用于跳转详情页；后续批次接入） */
  @Param onCardClick: ((card: FeedCard) => void) | undefined = undefined;

  /** 会话 ViewModel（@ObservedV2 + @Trace 单例） */
  @Local sessionViewModel: SessionViewModel = SessionViewModel.getInstance();
  /** 个人页 ViewModel（@ObservedV2 + @Trace 单例） */
  @Local profileVM: ProfileViewModel = ProfileViewModel.getInstance();

  /** 功能入口配置（静态） */
  @Local entries: ProfileEntryConfig[] = buildProfileEntries();
  /** 是否显示退出登录确认对话框 */
  @Local showLogoutDialog: boolean = false;
  /** 当前选中的 Tab 索引 */
  @Local currentTabIndex: number = 0;

  aboutToAppear(): void {
    if (this.sessionViewModel.isLoggedIn && this.sessionViewModel.profile !== null) {
      const urlToken: string = this.sessionViewModel.profile.urlToken;
      this.profileVM.loadAnswers(urlToken);
      this.profileVM.loadArticles(urlToken);
    }
  }

  build() {
    Column() {
      // 用户信息卡片：登录态优先，profile=null 时仍按已登录渲染
      if (this.sessionViewModel.isLoggedIn) {
        this.buildLoggedInUserCard();
        this.buildStatsRow();
        this.buildLogoutButton();
      } else {
        this.buildLoggedOutUserCard();
      }

      // 内容 Tab 列表（已登录时显示回答/文章切换）
      if (this.sessionViewModel.isLoggedIn) {
        this.buildContentTabs();
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
    .height('100%')
    .padding({
      left: $r('app.float.page_padding_horizontal'),
      right: $r('app.float.page_padding_horizontal'),
      top: $r('app.float.page_padding_vertical'),
      bottom: $r('app.float.content_bottom_padding_tabbar')
    })
    .alignItems(HorizontalAlign.Center)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
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
   * 统计信息行 Builder。
   *
   * 在已登录状态下，用户信息卡片下方显示统计行（回答数、文章数、粉丝数、关注数）。
   * 当前 ZhihuProfile 模型暂无这些统计字段，显示占位符 "-"。
   * 使用 Row 布局，水平均匀分布。
   */
  @Builder
  buildStatsRow() {
    Row() {
      ForEach(this.buildStatsItems(), (stat: StatsItem) => {
        Column() {
          Text(stat.count)
            .fontSize($r('app.float.card_title_font_size'))
            .fontColor($r('app.color.app_title_bar_on_surface'))
            .fontWeight(FontWeight.Medium);
          Text(stat.label)
            .fontSize($r('app.float.card_meta_font_size'))
            .fontColor($r('app.color.app_on_surface_secondary'))
            .margin({ top: 2 });
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center);
      }, (item: StatsItem) => item.id);
    }
    .width('100%')
    .height(STATS_ROW_HEIGHT)
    .padding({ left: CARD_PADDING, right: CARD_PADDING })
    .margin({ top: 8 });
  }

  /**
   * 退出登录按钮 Builder。
   *
   * 仅登录态显示，位于用户信息卡片下方。
   * 点击弹出确认对话框，确认后触发 onLogoutClick 回调。
   */
  @Builder
  buildLogoutButton() {
    Column() {
      Row() {
        Text($r('app.string.profile_logout_title'))
          .fontSize(LOGOUT_BUTTON_FONT_SIZE)
          .fontColor($r('app.color.app_error'))
          .fontWeight(FontWeight.Medium);
      }
      .width('100%')
      .height(LOGOUT_BUTTON_HEIGHT)
      .padding({ left: CARD_PADDING, right: CARD_PADDING })
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.showLogoutConfirmDialog();
      });
    }
    .width('100%')
    .margin({ top: LOGOUT_SECTION_TOP_MARGIN })
    .backgroundColor($r('app.color.app_surface'))
    .borderRadius(CARD_CORNER_RADIUS);
  }

  /**
   * 内容 Tab 列表 Builder。
   *
   * 使用原生 Tabs 组件，两个 Tab：回答和文章。
   * 每个 Tab 内容是一个 List 渲染的 FeedCardView 列表。
   * 支持触底加载（onReachEnd）和下拉刷新（Refresh）。
   * 空状态时显示 EmptyView。
   */
  @Builder
  buildContentTabs() {
    Column() {
      Tabs({ index: this.currentTabIndex }) {
        TabContent() {
          if (this.profileVM.answerItems.length > 0) {
            Refresh({ refreshing: this.profileVM.isRefreshing }) {
              List({ space: 8 }) {
                ForEach(this.profileVM.answerItems, (item: FeedCard) => {
                  ListItem() {
                    FeedCardView({
                      card: item,
                      onCardClick: (card: FeedCard) => {
                        this.handleCardClick(card);
                      }
                    });
                  }
                }, (item: FeedCard) => item.stableKey);
              }
              .width('100%')
              .height('100%')
              .onReachEnd(() => {
                this.loadMoreAnswers();
              });
            }
            .width('100%')
            .height('100%')
            .onRefreshing(() => {
              this.pullToRefresh();
            });
          } else {
            EmptyView({
              title: $r('app.string.profile_no_answers'),
              subtitle: $r('app.string.state_empty_subtitle')
            });
          }
        }
        .tabBar(this.buildTabBarBuilder($r('app.string.profile_tab_answers')));

        TabContent() {
          if (this.profileVM.articleItems.length > 0) {
            Refresh({ refreshing: this.profileVM.isRefreshing }) {
              List({ space: 8 }) {
                ForEach(this.profileVM.articleItems, (item: FeedCard) => {
                  ListItem() {
                    FeedCardView({
                      card: item,
                      onCardClick: (card: FeedCard) => {
                        this.handleCardClick(card);
                      }
                    });
                  }
                }, (item: FeedCard) => item.stableKey);
              }
              .width('100%')
              .height('100%')
              .onReachEnd(() => {
                this.loadMoreArticles();
              });
            }
            .width('100%')
            .height('100%')
            .onRefreshing(() => {
              this.pullToRefresh();
            });
          } else {
            EmptyView({
              title: $r('app.string.profile_no_articles'),
              subtitle: $r('app.string.state_empty_subtitle')
            });
          }
        }
        .tabBar(this.buildTabBarBuilder($r('app.string.profile_tab_articles')));
      }
      .width('100%')
      .height('100%')
      .barMode(BarMode.Fixed)
      .animationDuration(0)
      .onChange((index: number) => {
        this.currentTabIndex = index;
        this.onTabChange(index);
      });
    }
    .width('100%')
    .height('100%')
    .margin({ top: TAB_CONTENT_TOP_MARGIN })
    .layoutWeight(1);
  }

  /**
   * 构建 TabBar 内容。
   *
   * @param text 标签文字资源
   * @returns 自定义 TabBar 组件
   */
  @Builder
  buildTabBarBuilder(text: Resource) {
    Column() {
      Text(text)
        .fontSize($r('app.float.card_title_font_size'))
        .fontColor($r('app.color.app_title_bar_on_surface'))
        .fontWeight(FontWeight.Medium);
    }
    .width('100%')
    .height(TAB_BAR_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }

  /**
   * 显示退出登录确认对话框。
   *
   * 使用 AlertDialog.show 弹出确认对话框：
   * - 确认 → 调用 onLogoutClick 回调
   * - 取消 → 关闭对话框
   */
  private showLogoutConfirmDialog(): void {
    try {
      AlertDialog.show({
        title: $r('app.string.profile_logout_confirm_title'),
        message: $r('app.string.profile_logout_confirm_message'),
        autoCancel: true,
        primaryButton: {
          value: $r('app.string.profile_logout_cancel'),
          action: () => {
            hilog.info(DOMAIN, TAG, 'logout: cancelled by user');
          }
        },
        secondaryButton: {
          value: $r('app.string.profile_logout_confirm'),
          fontColor: $r('app.color.app_error'),
          action: () => {
            hilog.info(DOMAIN, TAG, 'logout: confirmed by user');
            const cb = this.onLogoutClick;
            if (cb !== undefined) {
              cb();
            }
          }
        }
      });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'showLogoutConfirmDialog failed: %{public}s',
        e instanceof Error ? e.message : String(e));
    }
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

  /**
   * 处理卡片点击，调用 onCardClick 回调。
   *
   * @param card 被点击的 FeedCard
   */
  private handleCardClick(card: FeedCard): void {
    const cb = this.onCardClick;
    if (cb !== undefined) {
      cb(card);
    }
  }

  /**
   * Tab 切换回调。
   *
   * 切换 Tab 时，如果对应列表为空，触发加载。
   *
   * @param index 新的 Tab 索引
   */
  private onTabChange(index: number): void {
    if (!this.sessionViewModel.isLoggedIn || this.sessionViewModel.profile === null) {
      return;
    }
    const urlToken: string = this.sessionViewModel.profile.urlToken;
    if (index === 0 && this.profileVM.answerItems.length === 0) {
      this.profileVM.loadAnswers(urlToken);
    } else if (index === 1 && this.profileVM.articleItems.length === 0) {
      this.profileVM.loadArticles(urlToken);
    }
  }

  /**
   * 加载更多回答（触底加载）。
   */
  private loadMoreAnswers(): void {
    if (!this.sessionViewModel.isLoggedIn || this.sessionViewModel.profile === null) {
      return;
    }
    const urlToken: string = this.sessionViewModel.profile.urlToken;
    this.profileVM.loadAnswers(urlToken);
  }

  /**
   * 加载更多文章（触底加载）。
   */
  private loadMoreArticles(): void {
    if (!this.sessionViewModel.isLoggedIn || this.sessionViewModel.profile === null) {
      return;
    }
    const urlToken: string = this.sessionViewModel.profile.urlToken;
    this.profileVM.loadArticles(urlToken);
  }

  /**
   * 下拉刷新所有列表。
   */
  private pullToRefresh(): void {
    if (!this.sessionViewModel.isLoggedIn || this.sessionViewModel.profile === null) {
      return;
    }
    const urlToken: string = this.sessionViewModel.profile.urlToken;
    this.profileVM.refresh(urlToken);
  }

  /**
   * 构建统计行条目。
   *
   * @returns 统计条目列表
   */
  private buildStatsItems(): StatsItem[] {
    const items: StatsItem[] = [
      { id: 'stats_answers', label: $r('app.string.profile_answer_count'), count: '-' },
      { id: 'stats_articles', label: $r('app.string.profile_article_count'), count: '-' },
      { id: 'stats_followers', label: $r('app.string.profile_follower_count'), count: '-' },
      { id: 'stats_following', label: $r('app.string.profile_following_count'), count: '-' }
    ];
    return items;
  }
}

/** 统计条目 */
interface StatsItem {
  /** 唯一标识 */
  id: string;
  /** 标签文字资源 */
  label: Resource;
  /** 统计数值（占位符） */
  count: string;
}