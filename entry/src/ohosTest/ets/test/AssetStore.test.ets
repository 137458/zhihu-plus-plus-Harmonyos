/**
 * AssetStore 设备端单元测试
 *
 * 验证 Asset Store Kit 适配层：
 * - saveSession/loadSession 往返
 * - clearSession 清除
 * - loadSession 未找到返回 null
 * - saveSession 更新已存在的资产
 * - 空会话保存/加载
 *
 * 注意：Asset Store Kit 是系统服务，只能在设备端运行（ohosTest）。
 * 测试前确保无残留资产（先 clear 再测试）。
 */

import { describe, beforeEach, it, expect } from '@ohos/hypium';
import { AssetStore } from '../../../main/ets/api/AssetStore';
import { ZhihuSession } from '../../../main/ets/model/ZhihuSession';
import { ZhihuProfile } from '../../../main/ets/model/ZhihuProfile';

export default function assetStoreTest() {
  describe('AssetStore', () => {
    // 每个测试前清除残留资产
    beforeEach(async () => {
      await AssetStore.getInstance().clearSession();
    });

    // ============ saveSession/loadSession 往返 ============
    it('save_and_load_roundtrip', 0, async () => {
      const cookies: Map<string, string> = new Map<string, string>();
      cookies.set('d_c0', 'AAB1234');
      cookies.set('z_c0', 'Bearer test_token');
      const profile: ZhihuProfile = new ZhihuProfile('user123', '测试用户', 'test-user', 'https://pic1.zhimg.com/avatar.jpg', 'people');
      const session: ZhihuSession = new ZhihuSession(
        true,
        'Mozilla/5.0 (Test UA)',
        cookies,
        'access_token_value',
        'refresh_token_value',
        profile,
        1700000000000
      );

      const saved: boolean = await AssetStore.getInstance().saveSession(session);
      expect(saved).assertTrue();

      const loaded: ZhihuSession | null = await AssetStore.getInstance().loadSession();
      expect(loaded !== null).assertTrue();
      const s: ZhihuSession = loaded as ZhihuSession;
      expect(s.isLoggedIn).assertTrue();
      expect(s.userAgent).assertEqual('Mozilla/5.0 (Test UA)');
      expect(s.cookies.size).assertEqual(2);
      expect(s.cookies.get('d_c0')).assertEqual('AAB1234');
      expect(s.cookies.get('z_c0')).assertEqual('Bearer test_token');
      expect(s.accessToken).assertEqual('access_token_value');
      expect(s.refreshToken).assertEqual('refresh_token_value');
      expect(s.profile !== null).assertTrue();
      expect((s.profile as ZhihuProfile).id).assertEqual('user123');
      expect(s.lastRefreshMillis).assertEqual(1700000000000);
    });

    // ============ loadSession 未找到返回 null ============
    it('loadSession_returns_null_when_not_found', 0, async () => {
      const loaded: ZhihuSession | null = await AssetStore.getInstance().loadSession();
      expect(loaded).assertNull();
    });

    // ============ clearSession 清除 ============
    it('clearSession_removes_asset', 0, async () => {
      // 先保存
      const session: ZhihuSession = ZhihuSession.createEmpty('Mozilla/5.0');
      await AssetStore.getInstance().saveSession(session);
      // 确认已保存
      const loaded1: ZhihuSession | null = await AssetStore.getInstance().loadSession();
      expect(loaded1 !== null).assertTrue();
      // 清除
      const cleared: boolean = await AssetStore.getInstance().clearSession();
      expect(cleared).assertTrue();
      // 确认已清除
      const loaded2: ZhihuSession | null = await AssetStore.getInstance().loadSession();
      expect(loaded2).assertNull();
    });

    // ============ saveSession 更新已存在的资产 ============
    it('saveSession_updates_existing_asset', 0, async () => {
      // 第一次保存
      const session1: ZhihuSession = ZhihuSession.createEmpty('UA v1');
      await AssetStore.getInstance().saveSession(session1);
      const loaded1: ZhihuSession | null = await AssetStore.getInstance().loadSession();
      expect(loaded1 !== null).assertTrue();
      expect((loaded1 as ZhihuSession).userAgent).assertEqual('UA v1');

      // 第二次保存（更新）
      const cookies: Map<string, string> = new Map<string, string>();
      cookies.set('z_c0', 'Bearer updated');
      const session2: ZhihuSession = new ZhihuSession(
        true,
        'UA v2',
        cookies,
        null,
        null,
        null,
        0
      );
      await AssetStore.getInstance().saveSession(session2);
      const loaded2: ZhihuSession | null = await AssetStore.getInstance().loadSession();
      expect(loaded2 !== null).assertTrue();
      const s: ZhihuSession = loaded2 as ZhihuSession;
      expect(s.userAgent).assertEqual('UA v2');
      expect(s.isLoggedIn).assertTrue();
      expect(s.hasZc0()).assertTrue();
    });

    // ============ 空会话保存/加载 ============
    it('save_and_load_empty_session', 0, async () => {
      const session: ZhihuSession = ZhihuSession.createEmpty('Empty UA');
      await AssetStore.getInstance().saveSession(session);
      const loaded: ZhihuSession | null = await AssetStore.getInstance().loadSession();
      expect(loaded !== null).assertTrue();
      const s: ZhihuSession = loaded as ZhihuSession;
      expect(s.isLoggedIn).assertFalse();
      expect(s.userAgent).assertEqual('Empty UA');
      expect(s.cookies.size).assertEqual(0);
      expect(s.profile).assertNull();
    });

    // ============ clearSession 对不存在的资产也返回 true ============
    it('clearSession_returns_true_when_not_found', 0, async () => {
      const cleared: boolean = await AssetStore.getInstance().clearSession();
      expect(cleared).assertTrue();
    });
  });
}
