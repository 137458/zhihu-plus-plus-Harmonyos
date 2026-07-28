/**
 * NetworkClient 设备端单元测试
 *
 * 验证 NetworkClient 的错误处理和超时机制：
 * - 无效 URL 应抛出 network error
 * - 不可达 IP 应触发超时
 *
 * 迁移原因：NetworkClient 依赖 @kit.NetworkKit 的 http 模块，
 * 该 Kit 仅在设备端可用，本地单元测试环境（entry/src/test/）不支持，
 * 故迁移到 ohosTest 设备端测试目录。
 */

import { describe, it, expect } from '@ohos/hypium';
import { NetworkClient, GetRequestOptions } from '../../../main/ets/api/NetworkClient';
import { ApiError, ApiErrorCode } from '../../../main/ets/model/ApiError';

export default function networkClientTest() {
  describe('NetworkClient', () => {
    it('get_throws_network_error_for_invalid_url', 0, async () => {
      // 测试无效 URL 应抛出 network error
      const client: NetworkClient = new NetworkClient();
      const options: GetRequestOptions = {
        url: 'https://this-domain-does-not-exist-12345.invalid/api/v4/test',
        connectTimeout: 1000,
        readTimeout: 1000
      };
      try {
        await client.get(options);
        expect(false).assertTrue(); // 不应到达这里
      } catch (err) {
        if (err instanceof ApiError) {
          expect(err.code === ApiErrorCode.NETWORK_ERROR ||
                 err.code === ApiErrorCode.TIMEOUT).assertTrue();
        } else {
          expect(false).assertTrue();
        }
      }
    });

    it('get_throws_timeout_for_slow_url', 0, async () => {
      // 测试超时配置生效
      const client: NetworkClient = new NetworkClient();
      const options: GetRequestOptions = {
        url: 'https://10.255.255.1/timeout-test', // 不可达 IP，触发超时
        connectTimeout: 500,
        readTimeout: 500
      };
      try {
        await client.get(options);
        expect(false).assertTrue();
      } catch (err) {
        if (err instanceof ApiError) {
          // 可能是 timeout 或 network error
          expect(err.code === ApiErrorCode.TIMEOUT ||
                 err.code === ApiErrorCode.NETWORK_ERROR).assertTrue();
        } else {
          expect(false).assertTrue();
        }
      }
    });
  });
}
