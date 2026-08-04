/**
 * QrLoginViewModel 设备端单元测试
 *
 * 重点验证扫码登录状态机的并发安全：
 * - 被取消的旧 startLogin 不会因共享 isCancelled 被新流程重置为 false 而"复活"
 * - 旧流程不会与新流程并发轮询不同 token，避免覆盖 UI 状态（如虚假的"已过期"）
 *
 * 通过注入 FakeQrLoginApi 控制 prefetch 的时序，复现"快速切换登录模式（QR→WEB→QR）"
 * 在 prefetch 窗口内触发竞态的场景。
 */
import { describe, beforeEach, it, expect } from '@ohos/hypium';
import { QrLoginViewModel, QrLoginState } from '../../../main/ets/viewmodel/QrLoginViewModel';
import { QrLoginApi, QrCodeResult, QrPollCallbacks } from '../../../main/ets/api/QrLoginApi';
import { CookieJar } from '../../../main/ets/api/CookieJar';

/**
 * 可控时序的 QrLoginApi 替身：
 * - prefetchQrLoginContext：返回挂起 Promise，由测试显式 resolve，
 *   用于在 await 期间插入 cancel() 与二次 startLogin()。
 * - requestQrCode：立即返回（第 1 次 tokenA/linkA，第 2 次 tokenB/linkB），
 *   用于区分两次流程获取的二维码。
 * - pollQrCodeLogin：记录被轮询的 token，返回永不 resolve 的 Promise，
 *   避免在断言前触发 pollLogin 的后续状态更新逻辑。
 */
class FakeQrLoginApi extends QrLoginApi {
  private prefetchResolvers: Array<() => void> = [];
  private requestCallIndex: number = 0;
  pollTokens: Array<string> = [];

  constructor() {
    super();
  }

  async prefetchQrLoginContext(): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      this.prefetchResolvers.push(resolve);
    });
  }

  async requestQrCode(): Promise<QrCodeResult> {
    const idx: number = this.requestCallIndex;
    this.requestCallIndex++;
    const token: string = idx === 0 ? 'tokenA' : 'tokenB';
    const link: string = idx === 0 ? 'linkA' : 'linkB';
    return { token, link, deadline: Date.now() + 60000 };
  }

  async pollQrCodeLogin(token: string, deadline: number, callbacks: QrPollCallbacks): Promise<boolean> {
    this.pollTokens.push(token);
    // 永不 resolve：断言前不让 pollLogin 进入后续状态更新逻辑
    return new Promise<boolean>(() => {});
  }

  /** 释放所有挂起的 prefetch，使对应的 startLogin 续体继续执行 */
  resolveAllPrefetch(): void {
    for (let i: number = 0; i < this.prefetchResolvers.length; i++) {
      this.prefetchResolvers[i]();
    }
    this.prefetchResolvers = [];
  }
}

/** 刷新微任务队列，使 async 续体运行到下一个挂起点 */
function flushMicrotasks(): Promise<void> {
  return new Promise<void>((resolve: () => void) => setTimeout(resolve, 0));
}

export default function qrLoginViewModelTest() {
  describe('QrLoginViewModel', () => {
    beforeEach(() => {
      CookieJar.getInstance().clear();
    });

    describe('startLogin 竞态', () => {
      it('superseded_startLogin_does_not_launch_poll', 0, async () => {
        const fake: FakeQrLoginApi = new FakeQrLoginApi();
        const vm: QrLoginViewModel = new QrLoginViewModel(fake);

        // A：startLogin 挂起在 prefetch（pollVersion 已递增、isCancelled=false）
        const aP: Promise<void> = vm.startLogin();
        // 模拟用户快速切回网页模式：cancel() 递增 pollVersion 并置 isCancelled=true
        vm.cancel();
        // B：再次 startLogin（会把共享 isCancelled 重置为 false——"复活" A 的风险点）
        const bP: Promise<void> = vm.startLogin();

        // 释放两路 prefetch，让 A、B 续体运行
        fake.resolveAllPrefetch();
        await flushMicrotasks();

        // 期望：被取消的 A 不再继续（不获取二维码、不启动轮询），只有 B 启动轮询。
        // 修复前 A 会"复活"，导致 pollTokens 同时包含 tokenA 与 tokenB，
        // 且 A 的轮询最终会把 B 的有效状态覆盖为虚假的"已过期"。
        expect(fake.pollTokens.length).assertEqual(1);
        expect(fake.pollTokens[0]).assertEqual('tokenB');
        expect(vm.state).assertEqual(QrLoginState.WAITING_SCAN);
        expect(vm.qrLink).assertEqual('linkB');

        // 清理：取消避免遗留轮询引用；aP/bP 均已 resolve（pollLogin 为 fire-and-forget）
        vm.cancel();
        await aP.catch(() => {});
        await bP.catch(() => {});
      });
    });
  });
}
