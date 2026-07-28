/**
 * 统一标题栏组件
 *
 * 左侧可选返回按钮（提供 onBack 时显示），中间居中标题，右侧可选 action
 * （rightActionIcon 与 rightActionText 互斥，icon 优先）。
 *
 * 颜色、尺寸、字号全部通过 $r() 引用资源，避免硬编码。
 */

/**
 * AppTitleBar Props
 *
 * 注意：ArkTS V2 严格语法下，可选 @Param 用 `T | undefined = undefined`
 * 表示调用方可以不传，且能在 build() 中通过 `!== undefined` 判断。
 */
@ComponentV2
export struct AppTitleBar {
  /** 标题文字或资源 */
  @Param title: string | Resource = '';
  /** 可选返回回调，不传则不显示返回按钮 */
  @Param onBack: (() => void) | undefined = undefined;
  /** 可选右侧文字按钮内容 */
  @Param rightActionText: string | Resource = '';
  /** 可选右侧图标（与 rightActionText 互斥，优先级更高） */
  @Param rightActionIcon: Resource | undefined = undefined;
  /** 右侧 action 点击回调 */
  @Param onRightAction: (() => void) | undefined = undefined;

  build() {
    Column() {
      Row() {
        // 左侧：返回按钮或对称占位（保证标题居中）
        if (this.onBack !== undefined) {
          Text('‹')
            .fontSize($r('app.float.title_bar_title_font_size'))
            .fontColor($r('app.color.app_title_bar_on_surface'))
            .width($r('app.float.title_bar_icon_size'))
            .height($r('app.float.title_bar_icon_size'))
            .textAlign(TextAlign.Center)
            .onClick(() => {
              const cb = this.onBack;
              if (cb !== undefined) {
                cb();
              }
            });
        } else {
          Blank()
            .width($r('app.float.title_bar_icon_size'))
            .height($r('app.float.title_bar_icon_size'));
        }

        // 标题，居中显示，用 layoutWeight 撑开剩余空间
        Text(this.title)
          .fontSize($r('app.float.title_bar_title_font_size'))
          .fontColor($r('app.color.app_title_bar_on_surface'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        // 右侧 action：icon 优先，其次 text，最后对称占位
        if (this.rightActionIcon !== undefined) {
          Image(this.rightActionIcon)
            .width($r('app.float.title_bar_icon_size'))
            .height($r('app.float.title_bar_icon_size'))
            .onClick(() => {
              const cb = this.onRightAction;
              if (cb !== undefined) {
                cb();
              }
            });
        } else if (this.rightActionText !== '') {
          Text(this.rightActionText)
            .fontSize($r('app.float.title_bar_action_font_size'))
            .fontColor($r('app.color.app_primary'))
            .onClick(() => {
              const cb = this.onRightAction;
              if (cb !== undefined) {
                cb();
              }
            });
        } else {
          Blank()
            .width($r('app.float.title_bar_icon_size'))
            .height($r('app.float.title_bar_icon_size'));
        }
      }
      .width('100%')
      .height($r('app.float.title_bar_height'))
      .backgroundColor($r('app.color.app_title_bar_background'))
      .padding({ left: 12, right: 12 });

      // 底部分隔线
      Divider()
        .color($r('app.color.app_divider'))
        .strokeWidth(0.5);
    }
    .width('100%');
  }
}
