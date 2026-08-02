/**
 * 扫码登录面板组件
 *
 * 展示知乎扫码登录二维码，根据 QrLoginViewModel 的状态显示对应 UI：
 * - LOADING_QR：加载中动画 + "正在获取二维码"
 * - WAITING_SCAN：QRCode 组件 + "请打开知乎 App 扫一扫" + 刷新按钮
 * - SCANNED：QRCode 组件 + "请在知乎 App 上确认登录"
 * - SUCCESS：登录成功文案
 * - EXPIRED：过期文案 + 刷新按钮
 * - ERROR：错误文案 + 重试按钮
 * - RISK_CONTROL：风控提示 + "完成验证后继续扫码"按钮
 *
 * 二维码使用 ArkUI 内置 QRCode(value: string) 组件渲染，
 * 无需第三方依赖，API version 9+ 支持。
 *
 * 设计要点：
 * - 所有文案用 $r() 引用，不硬编码
 * - 根容器 expandSafeArea 适配沉浸式
 * - 通过 @Param 接收 ViewModel，观察 @Trace 状态变化
 */

import { QrLoginViewModel, QrLoginState } from '../viewmodel/QrLoginViewModel';

/**
 * 扫码登录面板组件。
 *
 * 由 LoginPage 根据 loginMode 决定是否渲染，渲染时自动触发 startLogin。
 */
@ComponentV2
export struct QrLoginPane {
  /** 扫码登录 ViewModel（由父组件传入） */
  @Param viewModel: QrLoginViewModel = new QrLoginViewModel();

  build() {
    Column() {
      // 顶部留白（避开 titleBar）
      Blank().height(40);

      // 状态内容区
      if (this.viewModel.state === QrLoginState.LOADING_QR) {
        this.buildLoading();
      } else if (this.viewModel.state === QrLoginState.WAITING_SCAN ||
        this.viewModel.state === QrLoginState.SCANNED) {
        this.buildQrCode();
      } else if (this.viewModel.state === QrLoginState.SUCCESS) {
        this.buildSuccess();
      } else if (this.viewModel.state === QrLoginState.EXPIRED) {
        this.buildExpired();
      } else if (this.viewModel.state === QrLoginState.ERROR) {
        this.buildError();
      } else if (this.viewModel.state === QrLoginState.RISK_CONTROL) {
        this.buildRiskControl();
      } else {
        // IDLE 状态：空内容（等待父组件触发 startLogin）
        Blank();
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center);
  }

  /**
   * 加载中状态：LoadingProgress + 文案。
   */
  @Builder
  buildLoading() {
    Column() {
      LoadingProgress()
        .size({ width: 48, height: 48 })
        .color($r('app.color.app_loading'));
      Text($r('app.string.qr_loading'))
        .fontSize($r('app.float.body_secondary_font_size'))
        .fontColor($r('app.color.app_on_surface_secondary'))
        .margin({ top: 12 });
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }

  /**
   * 二维码状态（WAITING_SCAN / SCANNED）：QRCode 组件 + 状态文案 + 刷新按钮。
   */
  @Builder
  buildQrCode() {
    Column() {
      // 二维码
      QRCode(this.viewModel.qrLink)
        .width(260)
        .height(260)
        .color(Color.Black)
        .backgroundColor(Color.White)
        .margin({ top: 20 });

      // 状态文案
      if (this.viewModel.state === QrLoginState.WAITING_SCAN) {
        Text($r('app.string.qr_waiting_scan'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.app_on_surface'))
          .margin({ top: 20 });
      } else {
        Text($r('app.string.qr_scanned'))
          .fontSize($r('app.float.body_font_size'))
          .fontColor($r('app.color.app_on_surface'))
          .margin({ top: 20 });
      }

      // 刷新按钮（仅 WAITING_SCAN 状态显示，SCANNED 后不可刷新）
      if (this.viewModel.state === QrLoginState.WAITING_SCAN) {
        Button($r('app.string.qr_refresh'))
          .margin({ top: 24 })
          .onClick(() => {
            this.viewModel.refresh();
          });
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }

  /**
   * 登录成功状态：成功图标 + 文案。
   */
  @Builder
  buildSuccess() {
    Column() {
      Text($r('app.string.qr_success'))
        .fontSize($r('app.float.title_bar_title_font_size'))
        .fontColor($r('app.color.app_on_surface'))
        .margin({ top: 40 });
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }

  /**
   * 过期状态：过期文案 + 刷新按钮。
   */
  @Builder
  buildExpired() {
    Column() {
      Text($r('app.string.qr_expired'))
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.app_on_surface_secondary'))
        .margin({ top: 40 });
      Button($r('app.string.qr_refresh'))
        .margin({ top: 16 })
        .onClick(() => {
          this.viewModel.refresh();
        });
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }

  /**
   * 错误状态：错误文案 + 重试按钮。
   */
  @Builder
  buildError() {
    Column() {
      Text($r('app.string.qr_error'))
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.app_error'))
        .margin({ top: 40 });
      Button($r('app.string.qr_retry'))
        .margin({ top: 16 })
        .onClick(() => {
          this.viewModel.refresh();
        });
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }

  /**
   * 风控状态：风控提示 + "完成验证后继续扫码"按钮。
   */
  @Builder
  buildRiskControl() {
    Column() {
      Text($r('app.string.qr_risk_control'))
        .fontSize($r('app.float.body_font_size'))
        .fontColor($r('app.color.app_error'))
        .margin({ top: 40 });
      Text(this.viewModel.statusMessage)
        .fontSize($r('app.float.body_secondary_font_size'))
        .fontColor($r('app.color.app_on_surface_secondary'))
        .margin({ top: 8 })
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
      Button($r('app.string.qr_risk_continue'))
        .margin({ top: 16 })
        .onClick(() => {
          this.viewModel.refresh();
        });
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }
}
