/**
 * 设置页
 *
 * 提供主题模式切换和正文字号调节功能。
 * 通过 NavPathStack.pushPath({ name: RouteName.SETTINGS }) 进入。
 *
 * 架构与 QuestionDetailPage 一致：build() 直接返回 HdsNavDestination，
 * titleBar 配置引用 DETAIL_TITLE_BAR_STYLE 常量。
 */

import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { UIContext } from '@kit.ArkUI';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { DETAIL_TITLE_BAR_STYLE, DETAIL_TITLE_BAR_PADDING } from '../components/PlaceholderPage';
import { PreferencesUtil } from '../utils/PreferencesUtil';

/** Preferences 中主题模式存储键 */
const KEY_THEME_MODE: string = 'theme_mode';
/** Preferences 中正文字号存储键 */
const KEY_FONT_SCALE: string = 'content_font_scale';

@ComponentV2
export struct SettingsPage {
  /** 路由栈，onReady 时从 NavDestinationContext 获取 */
  @Local navPathStack: NavPathStack | undefined = undefined;
  /** 当前主题模式：'system' | 'light' | 'dark' */
  @Local currentTheme: string = 'system';
  /** 正文字号缩放比例 50~200 */
  @Local fontScale: number = 100;
  /** UIContext 实例，用于切换主题 */
  private uiContext: UIContext | undefined = undefined;

  aboutToAppear(): void {
    this.uiContext = this.getUIContext();
    this.loadSettings();
  }

  /**
   * 从 Preferences 加载已保存的设置。
   */
  private async loadSettings(): Promise<void> {
    const themeList: string[] = await PreferencesUtil.getStringList(KEY_THEME_MODE);
    if (themeList.length > 0) {
      this.currentTheme = themeList[0];
    }
    const fontList: string[] = await PreferencesUtil.getStringList(KEY_FONT_SCALE);
    if (fontList.length > 0) {
      const parsed: number = parseInt(fontList[0]);
      if (!isNaN(parsed)) {
        this.fontScale = parsed;
      }
    }
  }

  /**
   * 切换主题模式。
   */
  private onThemeChange(theme: string): void {
    this.currentTheme = theme;
    try {
      const appContext = getContext(this).getApplicationContext();
      if (theme === 'light') {
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      } else if (theme === 'dark') {
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      } else {
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    } catch (err) {
      // 静默处理
    }
    PreferencesUtil.putStringList(KEY_THEME_MODE, [theme]);
  }

  /**
   * 更新正文字号缩放比例。
   */
  private onFontScaleChange(value: number): void {
    this.fontScale = value;
    PreferencesUtil.putStringList(KEY_FONT_SCALE, [String(value)]);
  }

  @Builder
  themeButton(label: Resource, theme: string) {
    Column() {
      Text(label)
        .fontSize(14)
        .fontColor(this.currentTheme === theme
          ? $r('app.color.app_on_primary')
          : $r('app.color.app_on_surface'));
    }
    .width(100)
    .height(44)
    .justifyContent(FlexAlign.Center)
    .borderRadius(8)
    .backgroundColor(this.currentTheme === theme
      ? $r('app.color.app_primary')
      : $r('app.color.app_surface_variant'))
    .onClick(() => {
      this.onThemeChange(theme);
    })
  }

  build() {
    HdsNavDestination() {
      Column() {
        Scroll() {
          Column() {
            // ── 主题模式 ──
            Text($r('app.string.settings_theme_title'))
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .padding({ left: 16, top: 16, bottom: 8 });

            Text($r('app.string.settings_theme_description'))
              .fontSize(14)
              .fontColor($r('app.color.app_on_surface_secondary'))
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 12 });

            Row() {
              this.themeButton($r('app.string.settings_theme_system'), 'system');
              this.themeButton($r('app.string.settings_theme_light'), 'light');
              this.themeButton($r('app.string.settings_theme_dark'), 'dark');
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .justifyContent(FlexAlign.SpaceEvenly);

            // ── 分隔线 ──
            Divider()
              .strokeWidth(0.5)
              .color($r('app.color.app_divider'))
              .margin({ top: 24, bottom: 8 });

            // ── 正文字号 ──
            Text($r('app.string.settings_font_size_title'))
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .padding({ left: 16, top: 16, bottom: 8 });

            Text($r('app.string.settings_font_size_description'))
              .fontSize(14)
              .fontColor($r('app.color.app_on_surface_secondary'))
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 12 });

            Row() {
              Text($r('app.string.settings_font_size_small'))
                .fontSize(14)
                .fontColor($r('app.color.app_on_surface_secondary'));

              Slider({
                value: this.fontScale,
                min: 50,
                max: 200,
                step: 1
              })
                .onChange((value: number) => {
                  this.onFontScaleChange(value);
                })
                .layoutWeight(1)
                .margin({ left: 12, right: 12 });

              Text($r('app.string.settings_font_size_large'))
                .fontSize(14)
                .fontColor($r('app.color.app_on_surface_secondary'));
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .alignItems(VerticalAlign.Center);

            Text(this.fontScale + '%')
              .fontSize(14)
              .fontColor($r('app.color.app_primary'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 8, bottom: 16 });

            // 字号预览
            Text('这是正文字号预览效果，调整滑块可查看不同字号。')
              .fontSize(16 * this.fontScale / 100)
              .fontColor($r('app.color.app_on_surface'))
              .width('100%')
              .padding({ left: 16, right: 16, top: 8, bottom: 24 });
          }
          .width('100%')
        }
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.app_background'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
    }
    .titleBar({
      padding: DETAIL_TITLE_BAR_PADDING,
      style: DETAIL_TITLE_BAR_STYLE,
      content: {
        title: { mainTitle: $r('app.string.page_settings_title') },
        backIcon: {
          label: 'back',
          icon: $r('sys.symbol.chevron_left'),
          isEnabled: true,
          componentId: 'back',
          action: () => {
            this.navPathStack?.pop();
          }
        }
      }
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onReady((ctx: NavDestinationContext) => {
      this.navPathStack = ctx.pathStack;
    });
  }
}