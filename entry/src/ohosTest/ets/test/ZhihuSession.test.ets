/**
 * ZhihuSession/ZhihuProfile 设备端单元测试
 *
 * 验证：
 * - ZhihuProfile.fromObject：完整字段、缺字段返回 null、可选字段默认值
 * - ZhihuSession.createEmpty：默认值
 * - ZhihuSession.fromObject/toObject 往返
 * - ZhihuSession.fromJson/toJson 往返
 * - ZhihuSession.hasZc0 / buildCookieHeader
 * - cookies Map 与对象形式的转换
 */

import { describe, it, expect } from '@ohos/hypium';
import { ZhihuProfile } from '../../../main/ets/model/ZhihuProfile';
import { ZhihuSession } from '../../../main/ets/model/ZhihuSession';

export default function zhihuSessionTest() {
  describe('ZhihuSession', () => {
    // ============ ZhihuProfile.fromObject ============
    describe('ZhihuProfile.fromObject', () => {
      it('parses_full_fields', 0, () => {
        const raw: object = JSON.parse('{"id":"user123","name":"测试用户","url_token":"test-user","avatar_url":"https://pic1.zhimg.com/avatar.jpg","user_type":"people"}');
        const profile: ZhihuProfile | null = ZhihuProfile.fromObject(raw);
        expect(profile !== null).assertTrue();
        expect((profile as ZhihuProfile).id).assertEqual('user123');
        expect((profile as ZhihuProfile).name).assertEqual('测试用户');
        expect((profile as ZhihuProfile).urlToken).assertEqual('test-user');
        expect((profile as ZhihuProfile).avatarUrl).assertEqual('https://pic1.zhimg.com/avatar.jpg');
        expect((profile as ZhihuProfile).userType).assertEqual('people');
      });

      it('returns_null_for_missing_id', 0, () => {
        const raw: object = JSON.parse('{"name":"测试用户"}');
        const profile: ZhihuProfile | null = ZhihuProfile.fromObject(raw);
        expect(profile).assertNull();
      });

      it('returns_null_for_null_input', 0, () => {
        const profile: ZhihuProfile | null = ZhihuProfile.fromObject(null as object);
        expect(profile).assertNull();
      });

      it('defaults_user_type_to_empty', 0, () => {
        const raw: object = JSON.parse('{"id":"user123","name":"测试","url_token":"test","avatar_url":"url"}');
        const profile: ZhihuProfile | null = ZhihuProfile.fromObject(raw);
        expect(profile !== null).assertTrue();
        expect((profile as ZhihuProfile).userType).assertEqual('');
      });
    });

    // ============ ZhihuProfile.toObject ============
    describe('ZhihuProfile.toObject', () => {
      it('roundtrip_preserves_fields', 0, () => {
        const profile: ZhihuProfile = new ZhihuProfile('id1', 'name1', 'token1', 'url1', 'people');
        const obj: object = profile.toObject();
        const restored: ZhihuProfile | null = ZhihuProfile.fromObject(obj);
        expect(restored !== null).assertTrue();
        expect((restored as ZhihuProfile).id).assertEqual('id1');
        expect((restored as ZhihuProfile).name).assertEqual('name1');
        expect((restored as ZhihuProfile).urlToken).assertEqual('token1');
      });
    });

    // ============ ZhihuSession.createEmpty ============
    describe('createEmpty', () => {
      it('creates_empty_session_with_defaults', 0, () => {
        const session: ZhihuSession = ZhihuSession.createEmpty('Mozilla/5.0');
        expect(session.isLoggedIn).assertFalse();
        expect(session.userAgent).assertEqual('Mozilla/5.0');
        expect(session.cookies.size).assertEqual(0);
        expect(session.accessToken).assertNull();
        expect(session.refreshToken).assertNull();
        expect(session.profile).assertNull();
        expect(session.lastRefreshMillis).assertEqual(0);
      });
    });

    // ============ ZhihuSession.fromJson/toJson ============
    describe('fromJson_toJson', () => {
      it('roundtrip_preserves_all_fields', 0, () => {
        const cookies: Map<string, string> = new Map<string, string>();
        cookies.set('d_c0', 'AAB1234');
        cookies.set('z_c0', 'Bearer xxx');
        const profile: ZhihuProfile = new ZhihuProfile('id1', 'name1', 'token1', 'url1', 'people');
        const session: ZhihuSession = new ZhihuSession(
          true,
          'Mozilla/5.0',
          cookies,
          'access_token_value',
          'refresh_token_value',
          profile,
          1700000000000
        );

        const json: string = session.toJson();
        const restored: ZhihuSession | null = ZhihuSession.fromJson(json);
        expect(restored !== null).assertTrue();
        const r: ZhihuSession = restored as ZhihuSession;
        expect(r.isLoggedIn).assertTrue();
        expect(r.userAgent).assertEqual('Mozilla/5.0');
        expect(r.cookies.size).assertEqual(2);
        expect(r.cookies.get('d_c0')).assertEqual('AAB1234');
        expect(r.cookies.get('z_c0')).assertEqual('Bearer xxx');
        expect(r.accessToken).assertEqual('access_token_value');
        expect(r.refreshToken).assertEqual('refresh_token_value');
        expect(r.profile !== null).assertTrue();
        expect((r.profile as ZhihuProfile).id).assertEqual('id1');
        expect(r.lastRefreshMillis).assertEqual(1700000000000);
      });

      it('returns_null_for_empty_string', 0, () => {
        const session: ZhihuSession | null = ZhihuSession.fromJson('');
        expect(session).assertNull();
      });

      it('returns_null_for_invalid_json', 0, () => {
        const session: ZhihuSession | null = ZhihuSession.fromJson('{invalid json');
        expect(session).assertNull();
      });

      it('handles_null_profile_and_tokens', 0, () => {
        const cookies: Map<string, string> = new Map<string, string>();
        cookies.set('d_c0', 'AAB1234');
        const session: ZhihuSession = new ZhihuSession(
          false,
          'Mozilla/5.0',
          cookies,
          null,
          null,
          null,
          0
        );

        const json: string = session.toJson();
        const restored: ZhihuSession | null = ZhihuSession.fromJson(json);
        expect(restored !== null).assertTrue();
        const r: ZhihuSession = restored as ZhihuSession;
        expect(r.isLoggedIn).assertFalse();
        expect(r.accessToken).assertNull();
        expect(r.refreshToken).assertNull();
        expect(r.profile).assertNull();
      });
    });

    // ============ hasZc0 / buildCookieHeader ============
    describe('hasZc0_buildCookieHeader', () => {
      it('hasZc0_returns_true_when_zc0_present', 0, () => {
        const cookies: Map<string, string> = new Map<string, string>();
        cookies.set('z_c0', 'Bearer xxx');
        const session: ZhihuSession = new ZhihuSession(true, 'UA', cookies, null, null, null, 0);
        expect(session.hasZc0()).assertTrue();
      });

      it('hasZc0_returns_false_when_zc0_absent', 0, () => {
        const cookies: Map<string, string> = new Map<string, string>();
        cookies.set('d_c0', 'AAB1234');
        const session: ZhihuSession = new ZhihuSession(false, 'UA', cookies, null, null, null, 0);
        expect(session.hasZc0()).assertFalse();
      });

      it('buildCookieHeader_returns_all_cookies', 0, () => {
        const cookies: Map<string, string> = new Map<string, string>();
        cookies.set('d_c0', 'AAB1234');
        cookies.set('z_c0', 'Bearer xxx');
        const session: ZhihuSession = new ZhihuSession(true, 'UA', cookies, null, null, null, 0);
        const header: string = session.buildCookieHeader();
        expect(header).assertEqual('d_c0=AAB1234; z_c0=Bearer xxx');
      });

      it('buildCookieHeader_returns_empty_when_no_cookies', 0, () => {
        const session: ZhihuSession = ZhihuSession.createEmpty('UA');
        expect(session.buildCookieHeader()).assertEqual('');
      });
    });

    // ============ getCookie/setCookie ============
    describe('getCookie_setCookie', () => {
      it('sets_and_gets_cookie', 0, () => {
        const session: ZhihuSession = ZhihuSession.createEmpty('UA');
        session.setCookie('d_c0', 'AAB1234');
        expect(session.getCookie('d_c0')).assertEqual('AAB1234');
      });
    });

    // ============ fromObject 风控空对象 ============
    describe('fromObject_risk_control', () => {
      it('handles_empty_object', 0, () => {
        const raw: object = JSON.parse('{}');
        const session: ZhihuSession | null = ZhihuSession.fromObject(raw);
        expect(session !== null).assertTrue();
        const s: ZhihuSession = session as ZhihuSession;
        expect(s.isLoggedIn).assertFalse();
        expect(s.userAgent).assertEqual('');
        expect(s.cookies.size).assertEqual(0);
      });

      it('handles_cookies_object_form', 0, () => {
        const raw: object = JSON.parse('{"isLoggedIn":true,"cookies":{"d_c0":"AAB1234","z_c0":"Bearer xxx"}}');
        const session: ZhihuSession | null = ZhihuSession.fromObject(raw);
        expect(session !== null).assertTrue();
        const s: ZhihuSession = session as ZhihuSession;
        expect(s.isLoggedIn).assertTrue();
        expect(s.cookies.size).assertEqual(2);
        expect(s.cookies.get('d_c0')).assertEqual('AAB1234');
        expect(s.cookies.get('z_c0')).assertEqual('Bearer xxx');
      });
    });
  });
}
