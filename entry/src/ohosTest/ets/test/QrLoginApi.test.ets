/**
 * QrLoginApi 纯函数单元测试
 *
 * 覆盖扫码登录 API 封装层中可独立验证的纯函数：
 * - normalizeDeadline：过期时间归一化（TTL 秒/毫秒、绝对秒/毫秒时间戳、空值）
 * - parseCookieAssignments：cookie 赋值串解析（含跳过 Cookie 属性、空值、无等号）
 *
 * 设计说明：
 * - 这两个函数参数为 string/number 原始类型，不依赖网络与系统服务，可确定性验证。
 * - isQrLoginSuccessful/isQrLoginExpired/isRiskControlResponse/syncCookiesFromScanInfo
 *   依赖模块内部未导出的 Raw* 接口类型，ArkTS 严格模式下无法在测试侧构造对象字面量，
 *   故不在此覆盖（如需覆盖需导出 Raw 接口，属生产 API 表面变更，本批不做）。
 * - pollQrCodeLogin 依赖真实网络（GET scan_info），放在设备端集成测试，此处不覆盖。
 *
 * 本批新增背景：commit 8981b0a 引入 606 行 QrLoginApi 代码，此前零测试覆盖；
 * normalizeDeadline 的分支错误会导致二维码立即过期或永不过期，属用户可感知的功能退化。
 */

import { describe, it, expect } from '@ohos/hypium';
import { normalizeDeadline, parseCookieAssignments } from '../../../main/ets/api/QrLoginApi';

/** 允许的时间误差（ms），用于容忍 Date.now() 在断言前后的微小漂移 */
const TIME_TOLERANCE_MS: number = 1000;
/** 默认二维码有效期（ms），与 QrLoginApi.ets 中 DEFAULT_QR_DEADLINE_MS 对齐 */
const DEFAULT_QR_DEADLINE_MS: number = 120000;
/** 二维码 TTL 上限（秒），与 QrLoginApi.ets 中 MAX_QR_TTL_SECONDS 对齐 */
const MAX_QR_TTL_SECONDS: number = 86400;

export default function qrLoginApiTest() {
  describe('QrLoginApi', () => {
    // ============ normalizeDeadline ============
    describe('normalizeDeadline', () => {
      it('uses_default_when_undefined', 0, () => {
        const before: number = Date.now();
        const deadline: number = normalizeDeadline(undefined);
        const after: number = Date.now();
        expect(deadline >= before + DEFAULT_QR_DEADLINE_MS - TIME_TOLERANCE_MS).assertTrue();
        expect(deadline <= after + DEFAULT_QR_DEADLINE_MS + TIME_TOLERANCE_MS).assertTrue();
      });

      it('uses_default_when_zero_or_negative', 0, () => {
        const before: number = Date.now();
        const d1: number = normalizeDeadline(0);
        const d2: number = normalizeDeadline(-100);
        const after: number = Date.now();
        expect(d1 >= before + DEFAULT_QR_DEADLINE_MS - TIME_TOLERANCE_MS).assertTrue();
        expect(d1 <= after + DEFAULT_QR_DEADLINE_MS + TIME_TOLERANCE_MS).assertTrue();
        expect(d2 >= before + DEFAULT_QR_DEADLINE_MS - TIME_TOLERANCE_MS).assertTrue();
        expect(d2 <= after + DEFAULT_QR_DEADLINE_MS + TIME_TOLERANCE_MS).assertTrue();
      });

      it('treats_small_value_as_ttl_seconds', 0, () => {
        // 60 < nowSeconds → TTL 分支；60 <= 86400 → 秒 TTL
        const before: number = Date.now();
        const deadline: number = normalizeDeadline(60);
        const after: number = Date.now();
        expect(deadline >= before + 60 * 1000 - TIME_TOLERANCE_MS).assertTrue();
        expect(deadline <= after + 60 * 1000 + TIME_TOLERANCE_MS).assertTrue();
      });

      it('treats_mid_value_as_ttl_milliseconds', 0, () => {
        // 100000 < nowSeconds；100000 > 86400 但 <= 86400000 → 毫秒 TTL
        const before: number = Date.now();
        const deadline: number = normalizeDeadline(100000);
        const after: number = Date.now();
        expect(deadline >= before + 100000 - TIME_TOLERANCE_MS).assertTrue();
        expect(deadline <= after + 100000 + TIME_TOLERANCE_MS).assertTrue();
      });

      it('treats_oversized_ttl_as_default', 0, () => {
        // 超过 MAX_QR_TTL_MS 但仍小于 nowSeconds → 默认值
        const oversized: number = MAX_QR_TTL_SECONDS * 1000 + 1;
        const before: number = Date.now();
        const deadline: number = normalizeDeadline(oversized);
        const after: number = Date.now();
        expect(deadline >= before + DEFAULT_QR_DEADLINE_MS - TIME_TOLERANCE_MS).assertTrue();
        expect(deadline <= after + DEFAULT_QR_DEADLINE_MS + TIME_TOLERANCE_MS).assertTrue();
      });

      it('treats_future_seconds_timestamp_as_absolute', 0, () => {
        // nowSeconds + 120 是未来秒级时间戳，< 10^10 → 秒级
        const nowSeconds: number = Math.floor(Date.now() / 1000);
        const futureSeconds: number = nowSeconds + 120;
        const deadline: number = normalizeDeadline(futureSeconds);
        expect(deadline).assertEqual(futureSeconds * 1000);
      });

      it('treats_large_milliseconds_timestamp_as_absolute', 0, () => {
        // now + 60000 是未来毫秒级时间戳，>= 10^10 → 毫秒级
        const now: number = Date.now();
        const futureMs: number = now + 60000;
        const deadline: number = normalizeDeadline(futureMs);
        expect(deadline).assertEqual(futureMs);
      });
    });

    // ============ parseCookieAssignments ============
    describe('parseCookieAssignments', () => {
      it('parses_multiple_cookies', 0, () => {
        const result: Map<string, string> = parseCookieAssignments('z_c0=Bearer abc; d_c0=AAA; _xsrf=BBB');
        expect(result.size).assertEqual(3);
        expect(result.get('z_c0')).assertEqual('Bearer abc');
        expect(result.get('d_c0')).assertEqual('AAA');
        expect(result.get('_xsrf')).assertEqual('BBB');
      });

      it('skips_cookie_attributes', 0, () => {
        const result: Map<string, string> = parseCookieAssignments('z_c0=abc; Path=/; Domain=zhihu.com; Secure; HttpOnly');
        expect(result.size).assertEqual(1);
        expect(result.get('z_c0')).assertEqual('abc');
      });

      it('skips_empty_value_and_no_equals_items', 0, () => {
        // "z_c0=" 值为空跳过；"HttpOnly" 无等号跳过；"=val" 等号在首位跳过
        const result: Map<string, string> = parseCookieAssignments('z_c0=; HttpOnly; =val; d_c0=ok');
        expect(result.size).assertEqual(1);
        expect(result.get('d_c0')).assertEqual('ok');
      });

      it('returns_empty_map_for_empty_string', 0, () => {
        const result: Map<string, string> = parseCookieAssignments('');
        expect(result.size).assertEqual(0);
      });

      it('preserves_value_containing_equals_sign', 0, () => {
        // z_c0 值中可能含 '='（如 "Bearer xxx=yyy"），应保留首个等号后的全部内容
        const result: Map<string, string> = parseCookieAssignments('z_c0=Bearer xxx=yyy');
        expect(result.get('z_c0')).assertEqual('Bearer xxx=yyy');
      });

      it('merges_cookie_and_cookies_style_independently', 0, () => {
        // 验证分号分隔的多段解析（scan_info 的 cookie/cookies 字段拼接后调用此函数）
        const result: Map<string, string> = parseCookieAssignments('z_c0=aaa;d_c0=bbb');
        expect(result.size).assertEqual(2);
        expect(result.get('z_c0')).assertEqual('aaa');
        expect(result.get('d_c0')).assertEqual('bbb');
      });
    });
  });
}
