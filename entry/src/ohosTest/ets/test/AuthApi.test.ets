/**
 * AuthApi 设备端单元测试
 *
 * 验证认证 API 封装层的错误处理：
 * - fetchVerifiedSession：无有效 Cookie 时返回 null
 * - refreshToken：无有效 Cookie 时返回 null
 * - signIn：无效 refresh_token 时返回 null
 *
 * 设计说明：
 * - AuthApi 的 parse 方法（parseMeResponse/parseRefreshTokenResponse/parseSignInResponse）
 *   是私有方法，测试通过公共 API 触发错误路径验证
 * - 所有测试不依赖真实登录态，使用无 Cookie 的初始状态测试错误处理路径
 * - 测试覆盖网络错误、无权限、无效参数等场景，确保 ApiError 被正确捕获
 *
 * 注意：AuthApi 依赖 NetworkClient 发起 HTTP 请求，需要在设备端运行。
 * 测试前确保网络可用（否则测试也会因网络错误返回 null，与预期一致）。
 */
import { describe, beforeEach, it, expect } from '@ohos/hypium';
import { AuthApi } from '../../../main/ets/api/AuthApi';
import { CookieJar } from '../../../main/ets/api/CookieJar';
import { ZhihuSession } from '../../../main/ets/model/ZhihuSession';

export default function authApiTest() {
  describe('AuthApi', () => {
    // 每个测试前清空 CookieJar，确保无残留凭据
    beforeEach(() => {
      CookieJar.getInstance().clear();
    });

    // ============ fetchVerifiedSession ============
    describe('fetchVerifiedSession', () => {
      it('returns_null_when_no_cookies', 0, async () => {
        const api: AuthApi = new AuthApi();
        const session: ZhihuSession = ZhihuSession.createEmpty('Test UA');
        const result: ZhihuSession | null = await api.fetchVerifiedSession(session);
        // 无 Cookie 时服务器返回 401，应返回 null（不抛异常）
        expect(result).assertNull();
      });
    });

    // ============ refreshToken ============
    describe('refreshToken', () => {
      it('returns_null_when_no_cookies', 0, async () => {
        const api: AuthApi = new AuthApi();
        const result: string | null = await api.refreshToken();
        // 无 Cookie（z_c0）时服务器返回 401，应返回 null
        expect(result).assertNull();
      });
    });

    // ============ signIn ============
    describe('signIn', () => {
      it('returns_null_with_invalid_refresh_token', 0, async () => {
        const api: AuthApi = new AuthApi();
        const result: string | null = await api.signIn('invalid_refresh_token');
        // 无效 refresh_token 时服务器返回 4xx，应返回 null
        expect(result).assertNull();
      });
    });
  });
}