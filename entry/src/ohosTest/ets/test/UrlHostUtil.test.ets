/**
 * UrlHostUtil 单元测试
 *
 * 重点回归：userinfo 形式的 URL（`https://www.zhihu.com:x@evil.com/`）
 * 必须解析出真实主机 `evil.com`，而非被误判为可信主机 `www.zhihu.com`，
 * 否则会绕过 ArticleWebContainer.onLoadIntercept 的可信主机白名单。
 */

import { describe, it, expect } from '@ohos/hypium';
import { extractHostFromUrl } from '../../../main/ets/utils/UrlHostUtil';

export default function urlHostUtilTest() {
  describe('UrlHostUtil', () => {
    describe('extractHostFromUrl', () => {
      it('extracts_https_host', 0, () => {
        expect(extractHostFromUrl('https://www.zhihu.com/path')).assertEqual('www.zhihu.com');
      });

      it('extracts_http_host', 0, () => {
        expect(extractHostFromUrl('http://www.zhihu.com/path')).assertEqual('www.zhihu.com');
      });

      it('extracts_host_without_path', 0, () => {
        expect(extractHostFromUrl('https://www.zhihu.com')).assertEqual('www.zhihu.com');
      });

      it('strips_port', 0, () => {
        expect(extractHostFromUrl('https://www.zhihu.com:443/path')).assertEqual('www.zhihu.com');
      });

      // ===== 关键回归：userinfo 不能绕过白名单 =====
      it('returns_real_host_for_userinfo_url_not_trusted_host', 0, () => {
        // 真实主机是 @ 之后的 evil.com，绝不能误判为可信的 www.zhihu.com
        const host: string | null = extractHostFromUrl('https://www.zhihu.com:x@evil.com/path');
        expect(host).assertEqual('evil.com');
      });

      it('returns_real_host_for_userinfo_url_without_path', 0, () => {
        const host: string | null = extractHostFromUrl('https://www.zhihu.com:x@evil.com');
        expect(host).assertEqual('evil.com');
      });

      it('extracts_trusted_host_when_userinfo_precedes_it', 0, () => {
        // 合法的 userinfo + 可信主机：仍应识别为可信主机
        expect(extractHostFromUrl('https://user:pass@www.zhihu.com/path')).assertEqual('www.zhihu.com');
      });

      it('extracts_trusted_host_with_userinfo_and_port', 0, () => {
        expect(extractHostFromUrl('https://user:pass@www.zhihu.com:443/path')).assertEqual('www.zhihu.com');
      });

      it('returns_null_for_non_http_protocol', 0, () => {
        expect(extractHostFromUrl('ftp://evil.com/path')).assertNull();
      });

      it('returns_null_for_javascript_scheme', 0, () => {
        expect(extractHostFromUrl('javascript:alert(1)')).assertNull();
      });

      it('returns_null_for_empty_url', 0, () => {
        expect(extractHostFromUrl('')).assertNull();
      });
    });
  });
}
