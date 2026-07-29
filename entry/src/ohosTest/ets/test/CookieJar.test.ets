/**
 * CookieJar 设备端单元测试
 *
 * 验证：
 * - extractCookie：正常提取、不存在、空值
 * - CookieJar 单例
 * - setCookie：正常设置、空值不写入、非允许名称不写入
 * - updateFromSetCookie：解析多个 cookie
 * - buildCookieHeader：拼接正确
 * - z_c0 空值不写入（关键测试，防止登录态被清空）
 * - fromMap/toMap 往返
 * - clear 清空
 *
 * 注意：CookieJar 是纯内存操作，不依赖系统服务，
 * 理论上可在本地单元测试运行，但为保持与项目惯例一致，放在 ohosTest 目录。
 */

import { describe, beforeEach, it, expect } from '@ohos/hypium';
import { CookieJar, extractCookie } from '../../../main/ets/api/CookieJar';

export default function cookieJarTest() {
  describe('CookieJar', () => {
    // 每个测试前清空单例状态
    beforeEach(() => {
      CookieJar.getInstance().clear();
    });

    // ============ extractCookie ============
    describe('extractCookie', () => {
      it('extracts_existing_cookie', 0, () => {
        const header: string = 'd_c0=AAB1234; Path=/; HttpOnly; Secure';
        const value: string | undefined = extractCookie(header, 'd_c0');
        expect(value).assertEqual('AAB1234');
      });

      it('returns_undefined_for_nonexistent_cookie', 0, () => {
        const header: string = 'd_c0=AAB1234; Path=/; HttpOnly';
        const value: string | undefined = extractCookie(header, 'z_c0');
        expect(value).assertUndefined();
      });

      it('returns_undefined_for_empty_value', 0, () => {
        const header: string = 'd_c0=; Path=/; HttpOnly';
        const value: string | undefined = extractCookie(header, 'd_c0');
        expect(value).assertUndefined();
      });
    });

    // ============ 单例 ============
    describe('getInstance', () => {
      it('returns_same_instance', 0, () => {
        const a: CookieJar = CookieJar.getInstance();
        const b: CookieJar = CookieJar.getInstance();
        expect(a === b).assertTrue();
      });
    });

    // ============ setCookie ============
    describe('setCookie', () => {
      it('sets_allowed_cookie', 0, () => {
        const jar: CookieJar = CookieJar.getInstance();
        jar.setCookie('d_c0', 'AAB1234');
        expect(jar.getDc0()).assertEqual('AAB1234');
      });

      it('does_not_set_empty_value', 0, () => {
        const jar: CookieJar = CookieJar.getInstance();
        jar.setCookie('z_c0', '');
        expect(jar.hasZc0()).assertFalse();
      });

      it('does_not_set_disallowed_name', 0, () => {
        const jar: CookieJar = CookieJar.getInstance();
        jar.setCookie('unknown_cookie', 'value');
        expect(jar.getCookie('unknown_cookie')).assertUndefined();
      });
    });

    // ============ z_c0 空值不写入（关键测试） ============
    describe('zc0_empty_value_protection', () => {
      it('does_not_overwrite_zc0_with_empty', 0, () => {
        const jar: CookieJar = CookieJar.getInstance();
        // 先设置有效 z_c0
        jar.updateZc0('Bearer valid_token');
        expect(jar.getZc0()).assertEqual('Bearer valid_token');
        // 尝试用空值覆盖（知乎返回空值不应清空登录态）
        jar.updateZc0('');
        expect(jar.getZc0()).assertEqual('Bearer valid_token');
      });

      it('updates_zc0_with_valid_value', 0, () => {
        const jar: CookieJar = CookieJar.getInstance();
        jar.updateZc0('Bearer new_token');
        expect(jar.getZc0()).assertEqual('Bearer new_token');
        expect(jar.hasZc0()).assertTrue();
      });
    });

    // ============ updateFromSetCookie ============
    describe('updateFromSetCookie', () => {
      it('extracts_multiple_cookies', 0, () => {
        const jar: CookieJar = CookieJar.getInstance();
        const header: string = 'd_c0=AAB1234; Path=/; HttpOnly; z_c0=Bearer xxx; Path=/; HttpOnly';
        jar.updateFromSetCookie(header);
        expect(jar.getDc0()).assertEqual('AAB1234');
        expect(jar.getZc0()).assertEqual('Bearer xxx');
      });

      it('ignores_unsupported_cookies', 0, () => {
        const jar: CookieJar = CookieJar.getInstance();
        const header: string = 'd_c0=AAB1234; unknown_cookie=value; Path=/';
        jar.updateFromSetCookie(header);
        expect(jar.getDc0()).assertEqual('AAB1234');
        expect(jar.getCookie('unknown_cookie')).assertUndefined();
      });
    });

    // ============ buildCookieHeader ============
    describe('buildCookieHeader', () => {
      it('returns_empty_when_no_cookies', 0, () => {
        const jar: CookieJar = CookieJar.getInstance();
        expect(jar.buildCookieHeader()).assertEqual('');
      });

      it('builds_single_cookie_header', 0, () => {
        const jar: CookieJar = CookieJar.getInstance();
        jar.setDc0('AAB1234');
        const header: string = jar.buildCookieHeader();
        expect(header).assertEqual('d_c0=AAB1234');
      });

      it('builds_multiple_cookies_header', 0, () => {
        const jar: CookieJar = CookieJar.getInstance();
        jar.setDc0('AAB1234');
        jar.updateZc0('Bearer xxx');
        const header: string = jar.buildCookieHeader();
        // Map 的遍历顺序与插入顺序一致
        expect(header).assertEqual('d_c0=AAB1234; z_c0=Bearer xxx');
      });
    });

    // ============ fromMap/toMap ============
    describe('fromMap_toMap', () => {
      it('roundtrip_preserves_cookies', 0, () => {
        const jar: CookieJar = CookieJar.getInstance();
        const original: Map<string, string> = new Map<string, string>();
        original.set('d_c0', 'AAB1234');
        original.set('z_c0', 'Bearer xxx');

        jar.fromMap(original);
        const exported: Map<string, string> = jar.toMap();

        expect(exported.size).assertEqual(2);
        expect(exported.get('d_c0')).assertEqual('AAB1234');
        expect(exported.get('z_c0')).assertEqual('Bearer xxx');
      });

      it('fromMap_filters_disallowed_names', 0, () => {
        const jar: CookieJar = CookieJar.getInstance();
        const input: Map<string, string> = new Map<string, string>();
        input.set('d_c0', 'AAB1234');
        input.set('unknown', 'value');

        jar.fromMap(input);
        expect(jar.getDc0()).assertEqual('AAB1234');
        expect(jar.getCookie('unknown')).assertUndefined();
      });
    });

    // ============ clear ============
    describe('clear', () => {
      it('clears_all_cookies', 0, () => {
        const jar: CookieJar = CookieJar.getInstance();
        jar.setDc0('AAB1234');
        jar.updateZc0('Bearer xxx');
        expect(jar.hasAnyCookie()).assertTrue();

        jar.clear();
        expect(jar.hasAnyCookie()).assertFalse();
        expect(jar.hasDc0()).assertFalse();
        expect(jar.hasZc0()).assertFalse();
      });
    });

    // ============ xsrf/qc0 ============
    describe('xsrf_qc0', () => {
      it('sets_and_gets_xsrf', 0, () => {
        const jar: CookieJar = CookieJar.getInstance();
        jar.setCookie('_xsrf', 'abc123');
        expect(jar.getXsrf()).assertEqual('abc123');
        expect(jar.hasXsrf()).assertTrue();
      });

      it('sets_and_gets_qc0', 0, () => {
        const jar: CookieJar = CookieJar.getInstance();
        jar.setCookie('q_c0', 'sub_account_token');
        expect(jar.getQc0()).assertEqual('sub_account_token');
      });
    });
  });
}
