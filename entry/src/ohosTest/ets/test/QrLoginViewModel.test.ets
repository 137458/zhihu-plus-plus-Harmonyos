/**
 * QrLoginViewModel 设备端单元测试
 *
 * 验证 startLogin 的版本号守卫能阻止并发 startLogin 互相抢占导致的竞态。
 *
 * 复现的缺陷场景（修复前）：
 * 用户快速在「扫码 / 网页」登录模式间切换，导致两次 startLogin 的 loading 阶段
 * （prefetch + requestQrCode）重叠：
 *  1. Call A 调用 startLogin，进入 LOADING_QR 并阻塞在 prefetch 上；
 *  2. 用户切到网页模式 → cancel()（isCancelled=true, pollVersion++）；
 *  3. 用户切回扫码模式 → Call B 调用 startLogin，把 isCancelled 重置为 false；
 *  4. prefetch 放行后，Call A 仅检查 isCancelled（已被 B 重置为 false）→「复活」继续执行，
 *     并在末尾重新读取 this.pollVersion 拿到 B 推进后的最新版本号。
 *
 * 后果：A 与 B 各启动一条 pollQrCodeLogin，且二者持有的版本号相同（都是最新值），
 * 互不失效。展示的二维码可能与正在轮询的 token 不匹配，未扫码的那条会先报 EXPIRED
 * 覆盖状态，登录静默失败。
 *
 * 修复后：startLogin 在递增 pollVersion 时捕获 startVersion，并在每个 await 之后用
 * startVersion !== this.pollVersion 判断是否已被取代；被取代的旧 startLogin 自我退出，
 * 仅保留唯一一条轮询。
 *
 * 设计说明：
 * - 通过注入 ControllableQrLoginApi（QrLoginApi 子类）控制 prefetch / requestQrCode /
 *   pollQrCodeLogin 的时序，避免依赖真实网络，使竞态确定性复现。
 * - QrLoginViewModel 依赖 @kit.NetworkKit / @kit.AssetStoreKit，需在设备端运行（ohosTest）。
 */
import { describe, it, expect } from '@ohos/hypium';
import { QrLoginViewModel, QrLoginState } from '../../../main/ets/viewmodel/QrLoginViewModel';
import { QrLoginApi, QrCodeResult, QrPollCallbacks } from '../../../main/ets/api/QrLoginApi';

/** 可控的 prefetch 门闩 */
interface PrefetchGate {
  promise: Promise<void>;
  resolve: () => void;
}

/**
 * 可控的 QrLoginApi 子类：用于确定性测试 startLogin 的并发守卫。
 *
 * - prefetchQrLoginContext：所有调用共享同一个门闩 promise，由 releasePrefetch 放行，
 *   从而让两次 startLogin 的 loading 阶段在同一时刻同时解除阻塞。
 * - requestQrCode：按调用次数返回不同 token/link，便于区分是哪次 startLogin 发起。
 * - pollQrCodeLogin：记录入参 token，返回可控的 pending promise，不触发 finalizeLogin
 *   与状态变更，使断言只关注“启动了几条轮询”。
 */
class ControllableQrLoginApi extends QrLoginApi {
  private prefetchGate: PrefetchGate;
  /** requestQrCode 调用次数（用于生成唯一 token/link） */
  requestCallCount: number = 0;
  /** pollQrCodeLogin 被调用时传入的 token 列表 */
  pollTokens: string[] = [];
  /** 用于放行挂起的 pollQrCodeLogin，便于测试结束前清理 */
  pollResolve: ((value: boolean) => void) | null = null;

  constructor() {
    super();
    this.prefetchGate = ControllableQrLoginApi.createGate();
  }

  private static createGate(): PrefetchGate {
    let resolveFn: () => void = () => {};
    const promise: Promise<void> = new Promise<void>((resolve: () => void) => {
      resolveFn = resolve;
    });
    return { promise, resolve: resolveFn };
  }

  /** 放行所有阻塞在 prefetch 上的 startLogin */
  releasePrefetch(): void {
    this.prefetchGate.resolve();
  }

  async prefetchQrLoginContext(): Promise<void> {
    await this.prefetchGate.promise;
  }

  async requestQrCode(): Promise<QrCodeResult> {
    this.requestCallCount++;
    const token: string = `token_${this.requestCallCount}`;
    const link: string = `https://link_${this.requestCallCount}`;
    return { token, link, deadline: Date.now() + 60000 };
  }

  async pollQrCodeLogin(token: string, deadline: number, callbacks: QrPollCallbacks): Promise<boolean> {
    this.pollTokens.push(token);
    return new Promise<boolean>((resolve: (value: boolean) => void) => {
      this.pollResolve = resolve;
    });
  }
}

export default function qrLoginViewModelTest() {
  describe('QrLoginViewModel', () => {
    it('startLogin_superseded_by_new_startLogin_launches_only_one_poll', 0, async () => {
      const fake: ControllableQrLoginApi = new ControllableQrLoginApi();
      const vm: QrLoginViewModel = new QrLoginViewModel(fake);

      // Call A：进入 LOADING_QR，阻塞在 prefetch 门闩上
      const aPromise: Promise<void> = vm.startLogin();
      await Promise.resolve();

      // 模拟用户切到网页模式：cancel（isCancelled=true, pollVersion++）
      vm.cancel();

      // Call B：再次 startLogin（模拟用户切回扫码模式），isCancelled 被重置为 false
      const bPromise: Promise<void> = vm.startLogin();
      await Promise.resolve();

      // 放行 prefetch：A 与 B 同时解除阻塞
      fake.releasePrefetch();

      // 等待两条 startLogin 跑完 loading 阶段
      await aPromise;
      await bPromise;
      await Promise.resolve();
      await Promise.resolve();

      // 修复前：A 会「复活」并也启动轮询，pollTokens.length === 2（缺陷行为）。
      // 修复后：A 检测到 startVersion !== pollVersion 自我退出，仅 B 启动轮询。
      expect(fake.pollTokens.length).assertEqual(1);
      // 仅 B 调用过 requestQrCode（拿到 token_1），展示的二维码与之匹配
      expect(fake.pollTokens[0]).assertEqual('token_1');
      expect(vm.qrLink).assertEqual('https://link_1');
      expect(vm.state === QrLoginState.WAITING_SCAN).assertTrue();

      // 清理：放行挂起的轮询并取消，避免遗留 pending promise
      vm.cancel();
      if (fake.pollResolve !== null) {
        fake.pollResolve(false);
      }
      await Promise.resolve();
    });
  });
}
