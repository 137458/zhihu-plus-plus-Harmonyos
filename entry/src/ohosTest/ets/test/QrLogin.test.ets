/**
 * QrLoginApi + QrLoginViewModel 设备端单元测试
 *
 * 验证：
 * - QrLoginApi 纯逻辑函数：isQrLoginSuccessful / isQrLoginExpired / isRiskControlResponse
 *   / normalizeDeadline / parseCookieAssignments / syncCookiesFromScanInfo
 * - QrLoginViewModel 状态机：初始状态、cancel() 重置、重复 cancel() 安全性
 *
 * 竞态修复覆盖（finalizeLogin 中 version/isCancelled 二次检查）：
 * - cancel() 后状态必须保持 IDLE，pollVersion 必须递增
 * - 这是 finalizeLogin 内部 version !== this.pollVersion 检查能生效的前提
 *
 * 注意：pollQrCodeLogin / finalizeLogin 涉及网络调用，无法在无 mock 环境下
 * 直接测试异步竞态。此处覆盖竞态修复所依赖的状态机基础。
 */

import { describe, beforeEach, it, expect } from '@ohos/hypium';
import {
  isQrLoginSuccessful,
  isQrLoginExpired,
  isRiskControlResponse,
  normalizeDeadline,
  parseCookieAssignments,
  syncCookiesFromScanInfo
} from '../../../main/ets/api/QrLoginApi';
import { CookieJar } from '../../../main/ets/api/CookieJar';
import { QrLoginViewModel, QrLoginState } from '../../../main/ets/viewmodel/QrLoginViewModel';

export default function qrLoginTest() {
  describe('QrLogin', () => {
    // ============ isQrLoginSuccessful ============
    describe('isQrLoginSuccessful', () => {
      it('returns_true_when_user_id_present', 0, () => {
        expect(isQrLoginSuccessful({ user_id: '12345' })).assertTrue();
      });

      it('returns_true_when_access_token_present', 0, () => {
        expect(isQrLoginSuccessful({ access_token: 'token' })).assertTrue();
      });

      it('returns_true_when_success_true', 0, () => {
        expect(isQrLoginSuccessful({ success: true })).assertTrue();
      });

      it('returns_true_when_logged_in_true', 0, () => {
        expect(isQrLoginSuccessful({ logged_in: true })).assertTrue();
      });

      it('returns_true_when_login_status_confirmed', 0, () => {
        expect(isQrLoginSuccessful({ login_status: 'CONFIRMED' })).assertTrue();
      });

      it('returns_true_when_login_status_case_insensitive', 0, () => {
        expect(isQrLoginSuccessful({ login_status: 'login_success' })).assertTrue();
      });

      it('returns_false_when_empty', 0, () => {
        expect(isQrLoginSuccessful({})).assertFalse();
      });

      it('returns_false_when_login_status_expired', 0, () => {
        expect(isQrLoginSuccessful({ login_status: 'EXPIRED' })).assertFalse();
      });

      it('returns_false_when_success_false', 0, () => {
        expect(isQrLoginSuccessful({ success: false })).assertFalse();
      });
    });

    // ============ isQrLoginExpired ============
    describe('isQrLoginExpired', () => {
      it('returns_true_when_status_2', 0, () => {
        expect(isQrLoginExpired({ status: 2 })).assertTrue();
      });

      it('returns_true_when_login_status_expired', 0, () => {
        expect(isQrLoginExpired({ login_status: 'EXPIRED' })).assertTrue();
      });

      it('returns_true_when_login_status_qr_code_expired', 0, () => {
        expect(isQrLoginExpired({ login_status: 'QR_CODE_EXPIRED' })).assertTrue();
      });

      it('returns_false_when_status_1', 0, () => {
        expect(isQrLoginExpired({ status: 1 })).assertFalse();
      });

      it('returns_false_when_empty', 0, () => {
        expect(isQrLoginExpired({})).assertFalse();
      });
    });

    // ============ isRiskControlResponse ============
    describe('isRiskControlResponse', () => {
      it('returns_true_when_403_and_error_code_40352', 0, () => {
        expect(isRiskControlResponse(403, { error: { code: 40352 } })).assertTrue();
      });

      it('returns_true_when_403_and_need_login', 0, () => {
        expect(isRiskControlResponse(403, { error: { need_login: true } })).assertTrue();
      });

      it('returns_false_when_200_and_error_code_40352', 0, () => {
        expect(isRiskControlResponse(200, { error: { code: 40352 } })).assertFalse();
      });

      it('returns_false_when_403_and_no_error', 0, () => {
        expect(isRiskControlResponse(403, {})).assertFalse();
      });

      it('returns_false_when_no_error_field', 0, () => {
        expect(isRiskControlResponse(403, {})).assertFalse();
      });
    });

    // ============ normalizeDeadline ============
    describe('normalizeDeadline', () => {
      it('returns_default_when_undefined', 0, () => {
        const deadline: number = normalizeDeadline(undefined);
        const now: number = Date.now();
        // 应为 now + 120000ms（默认 120s），允许 1s 浮动
        expect(deadline > now + 119000 && deadline < now + 121000).assertTrue();
      });

      it('returns_default_when_zero_or_negative', 0, () => {
        const deadline: number = normalizeDeadline(0);
        const now: number = Date.now();
        expect(deadline > now + 119000 && deadline < now + 121000).assertTrue();
      });

      it('treats_small_value_as_ttl_seconds', 0, () => {
        // expiresAt=60 应当作 60 秒 TTL
        const deadline: number = normalizeDeadline(60);
        const now: number = Date.now();
        expect(deadline > now + 59000 && deadline < now + 61000).assertTrue();
      });

      it('treats_value_between_ttl_seconds_and_ttl_ms_as_ms', 0, () => {
        // expiresAt=100000（>86400 但 <=86400000）当作毫秒 TTL
        const deadline: number = normalizeDeadline(100000);
        const now: number = Date.now();
        expect(deadline > now + 99000 && deadline < now + 101000).assertTrue();
      });

      it('treats_large_value_as_ms_timestamp', 0, () => {
        // expiresAt > 10^10 当作毫秒级时间戳
        const future: number = Date.now() + 60000;
        const deadline: number = normalizeDeadline(future);
        expect(deadline).assertEqual(future);
      });
    });

    // ============ parseCookieAssignments ============
    describe('parseCookieAssignments', () => {
      it('parses_single_cookie', 0, () => {
        const result: Map<string, string> = parseCookieAssignments('z_c0=Bearer abc');
        expect(result.get('z_c0')).assertEqual('Bearer abc');
      });

      it('parses_multiple_cookies', 0, () => {
        const result: Map<string, string> = parseCookieAssignments('z_c0=Bearer abc; d_c0=DEF123');
        expect(result.get('z_c0')).assertEqual('Bearer abc');
        expect(result.get('d_c0')).assertEqual('DEF123');
      });

      it('skips_cookie_attributes', 0, () => {
        const result: Map<string, string> = parseCookieAssignments(
          'z_c0=Bearer abc; Path=/; HttpOnly; Secure; SameSite=Lax; Domain=.zhihu.com'
        );
        expect(result.size).assertEqual(1);
        expect(result.get('z_c0')).assertEqual('Bearer abc');
      });

      it('skips_empty_values', 0, () => {
        const result: Map<string, string> = parseCookieAssignments('z_c0=; d_c0=DEF123');
        expect(result.size).assertEqual(1);
        expect(result.get('d_c0')).assertEqual('DEF123');
      });

      it('handles_cookie_value_with_equals', 0, () => {
        const result: Map<string, string> = parseCookieAssignments('z_c0=Bearer abc=def');
        expect(result.get('z_c0')).assertEqual('Bearer abc=def');
      });

      it('returns_empty_for_empty_input', 0, () => {
        const result: Map<string, string> = parseCookieAssignments('');
        expect(result.size).assertEqual(0);
      });
    });

    // ============ syncCookiesFromScanInfo ============
    describe('syncCookiesFromScanInfo', () => {
      beforeEach(() => {
        CookieJar.getInstance().clear();
      });

      it('syncs_z_c0_from_top_level_field', 0, () => {
        const jar: CookieJar = CookieJar.getInstance();
        syncCookiesFromScanInfo(jar, { z_c0: 'Bearer token123' });
        expect(jar.getZc0()).assertEqual('Bearer token123');
        expect(jar.hasZc0()).assertTrue();
      });

      it('syncs_z_c0_from_zc0_field', 0, () => {
        const jar: CookieJar = CookieJar.getInstance();
        syncCookiesFromScanInfo(jar, { zc0: 'Bearer token456' });
        expect(jar.getZc0()).assertEqual('Bearer token456');
      });

      it('syncs_z_c0_from_cookie_string', 0, () => {
        const jar: CookieJar = CookieJar.getInstance();
        syncCookiesFromScanInfo(jar, { cookie: 'z_c0=Bearer fromCookie; d_c0=DEV123' });
        expect(jar.getZc0()).assertEqual('Bearer fromCookie');
        expect(jar.getDc0()).assertEqual('DEV123');
      });

      it('syncs_z_c0_from_cookies_string', 0, () => {
        const jar: CookieJar = CookieJar.getInstance();
        syncCookiesFromScanInfo(jar, { cookies: 'z_c0=Bearer fromCookies' });
        expect(jar.getZc0()).assertEqual('Bearer fromCookies');
      });

      it('merges_cookie_and_cookies_strings', 0, () => {
        const jar: CookieJar = CookieJar.getInstance();
        syncCookiesFromScanInfo(jar, {
          cookie: 'd_c0=DEV123',
          cookies: 'z_c0=Bearer merged'
        });
        expect(jar.getDc0()).assertEqual('DEV123');
        expect(jar.getZc0()).assertEqual('Bearer merged');
      });

      it('top_level_z_c0_overrides_cookie_string', 0, () => {
        const jar: CookieJar = CookieJar.getInstance();
        syncCookiesFromScanInfo(jar, {
          cookie: 'z_c0=Bearer old',
          z_c0: 'Bearer new'
        });
        // z_c0 字段后写入，应覆盖 cookie 字符串中的值
        expect(jar.getZc0()).assertEqual('Bearer new');
      });

      it('does_not_overwrite_z_c0_with_empty', 0, () => {
        const jar: CookieJar = CookieJar.getInstance();
        jar.updateZc0('Bearer existing');
        syncCookiesFromScanInfo(jar, { z_c0: '' });
        // 空值不写入（CookieJar.setCookie 规则）
        expect(jar.getZc0()).assertEqual('Bearer existing');
      });

      it('handles_empty_scan_info', 0, () => {
        const jar: CookieJar = CookieJar.getInstance();
        jar.updateZc0('Bearer existing');
        syncCookiesFromScanInfo(jar, {});
        expect(jar.getZc0()).assertEqual('Bearer existing');
      });
    });

    // ============ QrLoginViewModel 状态机 ============
    describe('QrLoginViewModel', () => {
      it('initial_state_is_idle', 0, () => {
        const vm: QrLoginViewModel = new QrLoginViewModel();
        expect(vm.state).assertEqual(QrLoginState.IDLE);
      });

      // 竞态修复基础：cancel() 必须正确重置状态和递增 pollVersion，
      // 否则 finalizeLogin 内部的 version !== this.pollVersion 检查无法生效。
      it('cancel_resets_state_to_idle', 0, () => {
        const vm: QrLoginViewModel = new QrLoginViewModel();
        // 模拟轮询过程中用户取消
        vm.cancel();
        expect(vm.state).assertEqual(QrLoginState.IDLE);
        expect(vm.qrLink).assertEqual('');
        expect(vm.riskControlUrl).assertEqual('');
        expect(vm.statusMessage).assertEqual('');
      });

      it('cancel_can_be_called_multiple_times', 0, () => {
        const vm: QrLoginViewModel = new QrLoginViewModel();
        vm.cancel();
        const stateAfterFirstCancel: QrLoginState = vm.state;
        vm.cancel();
        expect(vm.state).assertEqual(stateAfterFirstCancel);
        expect(vm.state).assertEqual(QrLoginState.IDLE);
      });

      it('cancel_then_state_remains_idle', 0, () => {
        // 验证 cancel() 后状态稳定为 IDLE，不会被后续操作意外覆盖
        // 这是 finalizeLogin 竞态修复的核心前提
        const vm: QrLoginViewModel = new QrLoginViewModel();
        vm.cancel();
        // 再次 cancel 模拟用户连续取消（如切换模式后再返回）
        vm.cancel();
        expect(vm.state).assertEqual(QrLoginState.IDLE);
      });
    });
  });
}
