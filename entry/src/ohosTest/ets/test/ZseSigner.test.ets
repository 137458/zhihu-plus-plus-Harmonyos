/**
 * ZseSigner 设备端单元测试
 *
 * 验证知乎 zse-v4 签名算法的正确性：
 * - encryptZseV4 的确定性、可区分性
 * - ASCII / Unicode 输入支持
 * - createZse96Header 的格式与场景覆盖
 *
 * 迁移原因：createZse96Header 依赖 @kit.CryptoArchitectureKit 的 MD5 能力，
 * 该 Kit 仅在设备端可用，本地单元测试环境（entry/src/test/）不支持，
 * 故迁移到 ohosTest 设备端测试目录。
 */

import { describe, it, expect } from '@ohos/hypium';
import { encryptZseV4, createZse96Header } from '../../../main/ets/api/ZseSigner';

export default function zseSignerTest() {
  describe('ZseSigner', () => {
    it('encryptZseV4_deterministic', 0, () => {
      // 相同输入应产生相同输出
      const a: string = encryptZseV4('hello');
      const b: string = encryptZseV4('hello');
      expect(a).assertEqual(b);
      expect(a.length > 0).assertTrue();
    });

    it('encryptZseV4_different_inputs_differ', 0, () => {
      // 不同输入应产生不同输出
      const a: string = encryptZseV4('hello');
      const b: string = encryptZseV4('world');
      expect(a !== b).assertTrue();
    });

    it('encryptZseV4_ascii_input', 0, () => {
      // 验证 ASCII 输入能正常加密
      const result: string = encryptZseV4('hello world?a=1&b=2');
      expect(result.length > 0).assertTrue();
      // 输出应只包含 ALPHABET 中的字符
      const alphabet: string = '6fpLRqJO8M/c3jnYxFkUVC4ZIG12SiH=5v0mXDazWBTsuw7QetbKdoPyAl+hN9rgE';
      for (let i = 0; i < result.length; i++) {
        const idx: number = alphabet.indexOf(result.charAt(i));
        expect(idx >= 0).assertTrue();
      }
    });

    it('encryptZseV4_unicode_input', 0, () => {
      // 验证 Unicode 输入能正常加密
      const result: string = encryptZseV4('你好，知乎++');
      expect(result.length > 0).assertTrue();
    });

    it('encryptZseV4_md5_hex_input', 0, () => {
      // 验证典型 MD5 十六进制输入（createZse96Header 内部调用场景）
      const md5Hex: string = 'd41d8cd98f00b204e9800998ecf8427e';
      const result: string = encryptZseV4(md5Hex);
      expect(result.length > 0).assertTrue();
      // 相同 MD5 应确定性输出
      const again: string = encryptZseV4(md5Hex);
      expect(result).assertEqual(again);
    });

    it('createZse96Header_format', 0, () => {
      const header: string = createZse96Header(
        '101_3_3.0',
        'https://api.zhihu.com/topstory/recommend',
        'test_dc0'
      );
      expect(header.startsWith('2.0_')).assertTrue();
      expect(header.length > 5).assertTrue();
    });

    it('createZse96Header_no_dc0', 0, () => {
      // dc0 为空时也应正常工作（匿名访问场景）
      const header: string = createZse96Header(
        '101_3_3.0',
        'https://api.zhihu.com/topstory/recommend',
        ''
      );
      expect(header.startsWith('2.0_')).assertTrue();
    });

    it('createZse96Header_with_body', 0, () => {
      const header: string = createZse96Header(
        '101_3_3.0',
        'https://www.zhihu.com/api/v4/search_v3',
        'test_dc0',
        '{"q":"test"}'
      );
      expect(header.startsWith('2.0_')).assertTrue();
    });

    it('createZse96Header_pathname_extraction', 0, () => {
      // 验证 pathname 提取：不同 pathname 应产生不同签名
      const h1: string = createZse96Header('101_3_3.0', 'https://api.zhihu.com/path_a', 'dc0');
      const h2: string = createZse96Header('101_3_3.0', 'https://api.zhihu.com/path_b', 'dc0');
      expect(h1 !== h2).assertTrue();
    });

    it('createZse96Header_deterministic', 0, () => {
      // 相同输入应产生相同签名
      const a: string = createZse96Header('101_3_3.0', 'https://api.zhihu.com/test', 'dc0');
      const b: string = createZse96Header('101_3_3.0', 'https://api.zhihu.com/test', 'dc0');
      expect(a).assertEqual(b);
    });
  });
}
