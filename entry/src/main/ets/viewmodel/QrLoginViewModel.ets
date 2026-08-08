/**
 * 扫码登录 ViewModel
 *
 * 管理扫码登录状态机，驱动 QrLoginApi 完成扫码登录全流程。
 * @ObservedV2 + @Trace 装饰确保状态变化触发 UI 刷新。
 *
 * 状态机：
 *   Idle → LoadingQr → WaitingScan → Scanned → Success
 *                    ↓             ↓        ↓
 *                  Error       Expired   RiskControl
 *
 * 核心流程：
 * - startLogin(): Idle → LoadingQr，预取上下文 + 获取二维码，成功转 WaitingScan
 * - pollLogin(): 轮询扫码状态，onScanned 转 Scanned，成功调用 finalizeLogin
 * - finalizeLogin(): 构造 ZhihuSession 并同步到 SessionViewModel
 * - refresh(): 重置状态并重新 startLogin
 * - cancel(): 取消轮询，状态转 Idle
 *
 * 安全约束：Cookie/Token 不进日志；会话同步通过 SessionViewModel.setSession。
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { QrLoginApi, QrCodeResult, QrPollCallbacks } from '../api/QrLoginApi';
import { AuthApi } from '../api/AuthApi';
import { CookieJar } from '../api/CookieJar';
import { ZHIHU_WEB_UA } from '../api/ZhihuConstants';
import { ZhihuSession } from '../model/ZhihuSession';
import { SessionViewModel } from './SessionViewModel';

const DOMAIN: number = 0x0000;
const TAG: string = 'QrLoginViewModel';

/** 扫码登录状态枚举 */
export enum QrLoginState {
  /** 空闲（初始状态或已取消） */
  IDLE = 'idle',
  /** 正在获取二维码 */
  LOADING_QR = 'loading_qr',
  /** 等待扫码 */
  WAITING_SCAN = 'waiting_scan',
  /** 已扫码，等待确认 */
  SCANNED = 'scanned',
  /** 触发风控 */
  RISK_CONTROL = 'risk_control',
  /** 登录成功 */
  SUCCESS = 'success',
  /** 二维码已过期 */
  EXPIRED = 'expired',
  /** 错误（网络/解析错误） */
  ERROR = 'error'
}

/**
 * 扫码登录 ViewModel
 *
 * @ObservedV2 单例模式，由 LoginPage 持有引用观察状态变化。
 */
@ObservedV2
export class QrLoginViewModel {
  /** 当前状态 */
  @Trace state: QrLoginState = QrLoginState.IDLE;
  /** 二维码内容（用于 QRCode 组件渲染） */
  @Trace qrLink: string = '';
  /** 状态提示文案 */
  @Trace statusMessage: string = '';
  /** 风控跳转 URL（仅 RISK_CONTROL 状态有值） */
  @Trace riskControlUrl: string = '';

  private qrLoginApi: QrLoginApi;
  private authApi: AuthApi;
  private sessionViewModel: SessionViewModel;
  private cookieJar: CookieJar;
  /** 轮询取消标志（true 时轮询循环退出） */
  private isCancelled: boolean = false;
  /**
   * 轮询版本号（每次启动新轮询时递增）。
   *
   * 用于替代 isPolling 守卫，解决 refresh() 时旧轮询未退出导致新轮询无法启动的竞态：
   * - 新轮询启动前 pollVersion++，旧轮询的 isCancelled 回调检测到版本不匹配后退出
   * - 旧轮询的回调/状态更新通过版本比对跳过，避免重复触发 UI 刷新
   */
  private pollVersion: number = 0;

  constructor(qrLoginApi?: QrLoginApi) {
    // 允许注入 QrLoginApi 以便设备端测试确定性复现并发竞态；生产路径不传参，行为不变
    this.qrLoginApi = qrLoginApi !== undefined ? qrLoginApi : new QrLoginApi();
    this.authApi = new AuthApi();
    this.sessionViewModel = SessionViewModel.getInstance();
    this.cookieJar = CookieJar.getInstance();
  }

  /**
   * 开始扫码登录流程。
   *
   * Idle → LoadingQr → WaitingScan/Error/RiskControl
   *
   * 流程：
   * 1. 重置取消标志
   * 2. 状态转 LoadingQr
   * 3. 预取上下文（prefetchQrLoginContext）
   * 4. 获取二维码（requestQrCode）
   * 5. 成功 → 设置 qrLink，状态转 WaitingScan，启动轮询
   * 6. 失败 → 状态转 Error
   */
  async startLogin(): Promise<void> {
    // 递增版本号并捕获本次启动的版本号：
    // - 使任何正在运行的旧轮询失效（旧轮询的 isCancelled 回调检测到版本不匹配后退出）
    // - 让本次 startLogin 在被新的 startLogin/cancel 取代后能自我退出。loading 阶段同样以
    //   版本号守卫，不能只依赖 isCancelled（会被后续 startLogin 重置为 false），否则被取消的
    //   旧 startLogin 会“复活”，与新的 startLogin 并发各启动一条轮询。
    const startVersion: number = ++this.pollVersion;
    this.isCancelled = false;
    this.riskControlUrl = '';
    this.state = QrLoginState.LOADING_QR;
    this.statusMessage = '正在获取二维码';

    try {
      // 预取上下文（失败不中断流程）
      await this.qrLoginApi.prefetchQrLoginContext();
      // 取消或被新的 startLogin 取代时直接退出，不再设置状态或启动轮询
      if (this.isCancelled || startVersion !== this.pollVersion) {
        return;
      }

      // 获取二维码
      const qrCode: QrCodeResult = await this.qrLoginApi.requestQrCode();
      if (this.isCancelled || startVersion !== this.pollVersion) {
        return;
      }

      this.qrLink = qrCode.link;
      this.state = QrLoginState.WAITING_SCAN;
      this.statusMessage = '请打开知乎 App 扫一扫';

      // 启动轮询（fire-and-forget，错误在内部处理）
      // 使用 startVersion 而非重新读取 this.pollVersion：并发 startLogin 会推进 pollVersion，
      // 若重新读取会让被取代的旧流程也拿到最新版本号，误以为自己仍是当前轮询。
      this.pollLogin(qrCode.token, qrCode.deadline, startVersion).catch((e: object) => {
        hilog.error(DOMAIN, TAG, 'pollLogin failed: %{public}s',
          e instanceof Error ? e.message : String(e));
        if (!this.isCancelled && this.pollVersion === startVersion) {
          this.state = QrLoginState.ERROR;
          this.statusMessage = '扫码登录失败，请重试';
        }
      });
    } catch (e) {
      if (this.isCancelled || startVersion !== this.pollVersion) {
        return;
      }
      hilog.error(DOMAIN, TAG, 'startLogin failed: %{public}s',
        e instanceof Error ? e.message : String(e));
      this.state = QrLoginState.ERROR;
      this.statusMessage = '二维码获取失败，请重试';
    }
  }

  /**
   * 轮询扫码状态。
   *
   * @param token 二维码 token
   * @param deadline 截止时间戳
   * @param version 启动时的轮询版本号（与 this.pollVersion 不匹配时表示已被新轮询取代）
   */
  private async pollLogin(token: string, deadline: number, version: number): Promise<void> {
    const callbacks: QrPollCallbacks = {
      // 取消信号：用户主动取消 或 版本号不匹配（新轮询已启动）
      isCancelled: (): boolean => this.isCancelled || version !== this.pollVersion,
      onScanned: () => {
        if (version !== this.pollVersion) {
          return;
        }
        if (!this.isCancelled) {
          this.state = QrLoginState.SCANNED;
          this.statusMessage = '请在知乎 App 上确认登录';
        }
      },
      onRiskControl: (message: string, redirectUrl: string) => {
        if (version !== this.pollVersion) {
          return;
        }
        if (!this.isCancelled) {
          this.state = QrLoginState.RISK_CONTROL;
          this.statusMessage = message;
          this.riskControlUrl = redirectUrl;
        }
      }
    };

    const success: boolean = await this.qrLoginApi.pollQrCodeLogin(token, deadline, callbacks);

    // 版本不匹配时跳过状态更新（旧轮询已被新轮询取代）
    if (version !== this.pollVersion) {
      return;
    }
    if (this.isCancelled) {
      return;
    }
    if (success) {
      await this.finalizeLogin();
    } else {
      // 非风控的失败视为过期
      if (this.state !== QrLoginState.RISK_CONTROL) {
        this.state = QrLoginState.EXPIRED;
        this.statusMessage = '二维码已过期，请刷新';
      }
    }
  }

  /**
   * 完成登录：构造会话并同步到 SessionViewModel。
   *
   * 流程：
   * 1. 构造 ZhihuSession（UA 用桌面 UA，Cookie 来自 CookieJar）
   * 2. 调用 AuthApi.fetchVerifiedSession 验证并获取 profile
   * 3. 验证失败但 z_c0 存在仍 setSession（与 WebView 登录路径一致）
   * 4. 状态转 Success
   */
  private async finalizeLogin(): Promise<void> {
    this.statusMessage = '正在验证登录状态';

    // 构造会话
    let session: ZhihuSession = new ZhihuSession(
      true,
      ZHIHU_WEB_UA,
      this.cookieJar.toMap(),
      null,
      null,
      null,
      Date.now()
    );

    // 验证并获取 profile（失败不阻断登录，只要 z_c0 存在即视为登录成功）
    try {
      const verified: ZhihuSession | null = await this.authApi.fetchVerifiedSession(session);
      if (verified !== null) {
        session = verified;
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'finalizeLogin verify failed: %{public}s',
        e instanceof Error ? e.message : String(e));
    }

    // 同步到 SessionViewModel（触发 isLoggedIn 变化，UI 自动刷新）
    this.sessionViewModel.setSession(session);
    this.state = QrLoginState.SUCCESS;
    this.statusMessage = '登录成功';
  }

  /**
   * 刷新二维码。
   *
   * 直接调用 startLogin，startLogin 内部会递增 pollVersion 使旧轮询失效。
   */
  async refresh(): Promise<void> {
    await this.startLogin();
  }

  /**
   * 取消扫码登录。
   *
   * 设置取消标志 + 递增版本号，确保正在运行的轮询立即退出。
   * 状态转 Idle（用于切换回网页登录模式）。
   */
  cancel(): void {
    this.isCancelled = true;
    this.pollVersion++;
    this.state = QrLoginState.IDLE;
    this.statusMessage = '';
    this.qrLink = '';
    this.riskControlUrl = '';
  }
}
