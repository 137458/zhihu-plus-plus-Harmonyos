/**
 * 知乎 Web 端 zse-v4 签名算法
 *
 * 用于生成 x-zse-96 请求头的值。算法来自 Android 参考实现（Rust 版 rs-zse-sign）。
 *
 * 注意：ArkTS 的 number 是 double，位运算时会被截断为 32 位有符号整数。
 * 所有中间结果必须用 `>>> 0` 强制转为无符号 32 位，避免符号位扩展。
 *
 * 关键 API 确认（CryptoArchitectureKit 官方示例 MessageDigestComputation）：
 *   - cryptoFramework.createMd('MD5')  创建摘要实例
 *   - md.updateSync({ data: Uint8Array })  分段更新
 *   - md.digestSync()  返回 DataBlob，其 .data 为 Uint8Array
 */

import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { buffer } from '@kit.ArkTS';

/** S-Box 常量（256 项），来自 Rust 参考 ZB */
const ZB: Uint8Array = new Uint8Array([
  20, 223, 245, 7, 248, 2, 194, 209, 87, 6, 227, 253, 240, 128, 222, 91,
  237, 9, 125, 157, 230, 93, 252, 205, 90, 79, 144, 199, 159, 197, 186, 167,
  39, 37, 156, 198, 38, 42, 43, 168, 217, 153, 15, 103, 80, 189, 71, 191,
  97, 84, 247, 95, 36, 69, 14, 35, 12, 171, 28, 114, 178, 148, 86, 182,
  32, 83, 158, 109, 22, 255, 94, 238, 151, 85, 77, 124, 254, 18, 4, 26,
  123, 176, 232, 193, 131, 172, 143, 142, 150, 30, 10, 146, 162, 62, 224, 218,
  196, 229, 1, 192, 213, 27, 110, 56, 231, 180, 138, 107, 242, 187, 54, 120,
  19, 44, 117, 228, 215, 203, 53, 239, 251, 127, 81, 11, 133, 96, 204, 132,
  41, 115, 73, 55, 249, 147, 102, 48, 122, 145, 106, 118, 74, 190, 29, 16,
  174, 5, 177, 129, 63, 113, 99, 31, 161, 76, 246, 34, 211, 13, 60, 68,
  207, 160, 65, 111, 82, 165, 67, 169, 225, 57, 112, 244, 155, 51, 236, 200,
  233, 58, 61, 47, 100, 137, 185, 64, 17, 70, 234, 163, 219, 108, 170, 166,
  59, 149, 52, 105, 24, 212, 78, 173, 45, 0, 116, 226, 119, 136, 206, 135,
  175, 195, 25, 92, 121, 208, 126, 139, 3, 75, 141, 21, 130, 98, 241, 40,
  154, 66, 184, 49, 181, 46, 243, 88, 101, 183, 8, 23, 72, 188, 104, 179,
  210, 134, 250, 201, 164, 89, 216, 202, 220, 50, 221, 152, 140, 33, 235, 214,
]);

/** 轮密钥常量（32 项），来自 Rust 参考 ZK */
const ZK: Uint32Array = new Uint32Array([
  1170614578, 1024848638, 1413669199, 3951632832, 3528873006, 2921909214, 4151847688, 3997739139,
  1933479194, 3323781115, 3888513386, 460404854, 3747539722, 2403641034, 2615871395, 2119585428,
  2265697227, 2035090028, 2773447226, 4289380121, 4217216195, 2200601443, 3051914490, 1579901135,
  1321810770, 456816404, 2903323407, 4065664991, 330002838, 3506006750, 363569021, 2347096187,
]);

/** 自定义 Base64 字母表（64 字符），来自 Rust 参考 ALPHABET */
const ALPHABET: string = '6fpLRqJO8M/c3jnYxFkUVC4ZIG12SiH=5v0mXDazWBTsuw7QetbKdoPyAl+hN9rgE';

/** 首块异或密钥：'059053f7d15e01d7' 的 ASCII 字节序列 */
const KEY16: Uint8Array = new Uint8Array([
  48, 53, 57, 48, 53, 51, 102, 55, 100, 49, 53, 101, 48, 49, 100, 55,
]);

/**
 * 大端序读取 4 字节为无符号 32 位整数
 *
 * @param b - 字节数组
 * @param off - 起始偏移
 * @returns 无符号 32 位整数
 */
function readU32Be(b: Uint8Array, off: number): number {
  return ((b[off] << 24) | (b[off + 1] << 16) | (b[off + 2] << 8) | b[off + 3]) >>> 0;
}

/**
 * 大端序写入 4 字节
 *
 * @param v - 无符号 32 位整数
 * @param out - 输出字节数组
 * @param off - 起始偏移
 */
function writeU32Be(v: number, out: Uint8Array, off: number): void {
  out[off] = (v >>> 24) & 0xFF;
  out[off + 1] = (v >>> 16) & 0xFF;
  out[off + 2] = (v >>> 8) & 0xFF;
  out[off + 3] = v & 0xFF;
}

/**
 * 32 位循环左移
 *
 * @param v - 无符号 32 位整数
 * @param n - 左移位数（1-31）
 * @returns 循环左移后的无符号 32 位整数
 */
function rotateLeft(v: number, n: number): number {
  return ((v << n) | (v >>> (32 - n))) >>> 0;
}

/**
 * G 变换：S-Box 替换 + 线性变换
 *
 * 算法：
 * 1. 将 32 位输入按大端序拆为 4 字节
 * 2. 每字节经 ZB S-Box 替换
 * 3. 重新组合为 32 位（大端序）得到 ti
 * 4. 返回 ti ^ rotateLeft(ti,2) ^ rotateLeft(ti,10) ^ rotateLeft(ti,18) ^ rotateLeft(ti,24)
 *
 * @param tt - 无符号 32 位输入
 * @returns 无符号 32 位输出
 */
function gTransform(tt: number): number {
  const te0: number = (tt >>> 24) & 0xFF;
  const te1: number = (tt >>> 16) & 0xFF;
  const te2: number = (tt >>> 8) & 0xFF;
  const te3: number = tt & 0xFF;

  const ti: number = ((ZB[te0] << 24) | (ZB[te1] << 16) | (ZB[te2] << 8) | ZB[te3]) >>> 0;

  const ti2: number = rotateLeft(ti, 2);
  const ti10: number = rotateLeft(ti, 10);
  const ti18: number = rotateLeft(ti, 18);
  const ti24: number = rotateLeft(ti, 24);

  return (ti ^ ti2 ^ ti10 ^ ti18 ^ ti24) >>> 0;
}

/**
 * R 块加密：32 轮 Feistel 迭代
 *
 * 算法：
 * 1. 输入 16 字节，按大端序读为 4 个 u32：tr[0..3]
 * 2. 32 轮迭代：tr[i+4] = tr[i] ^ gTransform(tr[i+1] ^ tr[i+2] ^ tr[i+3] ^ ZK[i])
 * 3. 输出 16 字节：按 tr[35], tr[34], tr[33], tr[32] 逆序大端写入
 *
 * @param input16 - 16 字节输入块
 * @returns 16 字节输出块
 */
function rBlock(input16: Uint8Array): Uint8Array {
  const tr: Uint32Array = new Uint32Array(36);
  tr[0] = readU32Be(input16, 0);
  tr[1] = readU32Be(input16, 4);
  tr[2] = readU32Be(input16, 8);
  tr[3] = readU32Be(input16, 12);

  for (let i = 0; i < 32; i++) {
    const x: number = (tr[i + 1] ^ tr[i + 2] ^ tr[i + 3] ^ ZK[i]) >>> 0;
    const ta: number = gTransform(x);
    tr[i + 4] = (tr[i] ^ ta) >>> 0;
  }

  const out: Uint8Array = new Uint8Array(16);
  writeU32Be(tr[35], out, 0);
  writeU32Be(tr[34], out, 4);
  writeU32Be(tr[33], out, 8);
  writeU32Be(tr[32], out, 12);
  return out;
}

/**
 * X 块加密：CBC 模式
 *
 * 算法：对每个 16 字节块：
 * 1. mixed = chunk XOR iv
 * 2. iv = rBlock(mixed)
 * 3. 输出 iv
 *
 * @param data - 待加密数据（长度为 16 的整数倍）
 * @param iv0 - 初始 IV（16 字节，即首块密文）
 * @returns 加密结果
 */
function xBlocks(data: Uint8Array, iv0: Uint8Array): Uint8Array {
  const numBlocks: number = Math.floor(data.length / 16);
  const out: Uint8Array = new Uint8Array(numBlocks * 16);
  const iv: Uint8Array = new Uint8Array(16);
  iv.set(iv0);

  for (let block = 0; block < numBlocks; block++) {
    const offset: number = block * 16;
    const mixed: Uint8Array = new Uint8Array(16);
    for (let i = 0; i < 16; i++) {
      mixed[i] = data[offset + i] ^ iv[i];
    }
    const enc: Uint8Array = rBlock(mixed);
    iv.set(enc);
    out.set(enc, offset);
  }

  return out;
}

/**
 * 自定义 Base64 编码
 *
 * 算法：
 * 1. 用 0 填充到长度为 3 的倍数
 * 2. 从后向前处理，每 3 字节输出 4 字符
 * 3. 每个字节异或 58>>(8*(i%4)) 的对应字节（i 为全局递增计数器）
 * 4. 3 字节组合为 24 位 v，按 6 位一组从低位到高位映射到 ALPHABET
 *
 * @param bytesIn - 待编码字节
 * @returns 编码后的字符串
 */
function customEncode(bytesIn: Uint8Array): string {
  // 用 0 填充到长度为 3 的倍数
  const remainder: number = bytesIn.length % 3;
  const padLen: number = remainder === 0 ? bytesIn.length : bytesIn.length + (3 - remainder);
  const bytes: Uint8Array = new Uint8Array(padLen);
  bytes.set(bytesIn);

  // 用数组 push + join 替代字符串拼接，避免 O(n²) 字符串拷贝
  const out: string[] = [];
  let i: number = 0;
  let p: number = bytes.length - 1;

  while (p >= 0) {
    let v: number = 0;

    const b0: number = bytes[p];
    const m0: number = (58 >>> (8 * (i % 4))) & 0xFF;
    i++;
    v |= (b0 ^ m0) & 0xFF;

    const b1: number = bytes[p - 1];
    const m1: number = (58 >>> (8 * (i % 4))) & 0xFF;
    i++;
    v |= ((b1 ^ m1) & 0xFF) << 8;

    const b2: number = bytes[p - 2];
    const m2: number = (58 >>> (8 * (i % 4))) & 0xFF;
    i++;
    v |= ((b2 ^ m2) & 0xFF) << 16;

    out.push(ALPHABET.charAt((v & 63) >>> 0));
    out.push(ALPHABET.charAt(((v >>> 6) & 63) >>> 0));
    out.push(ALPHABET.charAt(((v >>> 12) & 63) >>> 0));
    out.push(ALPHABET.charAt(((v >>> 18) & 63) >>> 0));

    p -= 3;
  }

  return out.join('');
}

/**
 * 将字符串编码为 UTF-8 字节序列
 *
 * @param str - 输入字符串
 * @returns UTF-8 字节序列
 */
function strToUtf8Bytes(str: string): Uint8Array {
  const buf = buffer.from(str, 'utf-8');
  // Buffer 继承自 Uint8Array，但 ArkTS 中 buf.buffer 可能不覆盖实际字节范围
  // 用 buf.length + 逐字节复制确保只取实际使用的字节
  const len: number = buf.length;
  const bytes: Uint8Array = new Uint8Array(len);
  for (let i = 0; i < len; i++) {
    bytes[i] = buf[i];
  }
  return bytes;
}

/**
 * 将字节序列转换为十六进制小写字符串
 *
 * @param bytes - 输入字节
 * @returns 十六进制字符串（小写）
 */
function bytesToHex(bytes: Uint8Array): string {
  const hexChars: string = '0123456789abcdef';
  const result: string[] = [];
  for (let i = 0; i < bytes.length; i++) {
    result.push(hexChars.charAt((bytes[i] >> 4) & 0x0F));
    result.push(hexChars.charAt(bytes[i] & 0x0F));
  }
  return result.join('');
}

/**
 * 计算字符串的 MD5 摘要，返回十六进制小写字符串
 *
 * 内部用 try-catch 包装 cryptoFramework API（这些 API 声明可能抛出 BusinessError）。
 * 失败时抛出 Error，由上层调用方（ZhihuApi.fetchHomeRecommend）的 try-catch 捕获并
 * 转换为 ApiError。
 *
 * @param input - 输入字符串
 * @returns 32 字符的 MD5 十六进制字符串
 * @throws Error 当 cryptoFramework API 调用失败
 */
function md5Hex(input: string): string {
  let md: cryptoFramework.Md;
  try {
    md = cryptoFramework.createMd('MD5');
  } catch (e) {
    throw new Error(`createMd failed: ${e instanceof Error ? e.message : String(e)}`);
  }

  const inputBytes: Uint8Array = strToUtf8Bytes(input);
  const inputBlob: cryptoFramework.DataBlob = { data: inputBytes };
  try {
    md.updateSync(inputBlob);
  } catch (e) {
    throw new Error(`updateSync failed: ${e instanceof Error ? e.message : String(e)}`);
  }

  let digestBlob: cryptoFramework.DataBlob;
  try {
    digestBlob = md.digestSync();
  } catch (e) {
    throw new Error(`digestSync failed: ${e instanceof Error ? e.message : String(e)}`);
  }
  return bytesToHex(digestBlob.data);
}

/**
 * 计算 HMAC-SHA1，返回十六进制小写字符串
 *
 * 用于知乎登录签名（sign_in 接口的 signature 字段）。
 * 使用 @kit.CryptoArchitectureKit 的 Mac API：
 *   - createSymKeyGenerator('HMAC') 创建密钥生成器
 *   - convertKeySync({ data: keyBytes }) 转换原始密钥为 SymKey
 *   - createMac('SHA1') 创建 Mac 实例
 *   - initSync(symKey) + updateSync({ data: msgBytes }) + doFinalSync()
 *
 * @param key - HMAC 密钥字符串
 * @param message - 待签名消息字符串
 * @returns 40 字符的 HMAC-SHA1 十六进制字符串
 * @throws Error 当 cryptoFramework API 调用失败
 */
export function hmacSha1Hex(key: string, message: string): string {
  const keyBytes: Uint8Array = strToUtf8Bytes(key);
  const msgBytes: Uint8Array = strToUtf8Bytes(message);

  let keyGen: cryptoFramework.SymKeyGenerator;
  try {
    keyGen = cryptoFramework.createSymKeyGenerator('HMAC');
  } catch (e) {
    throw new Error(`createSymKeyGenerator failed: ${e instanceof Error ? e.message : String(e)}`);
  }

  let symKey: cryptoFramework.SymKey;
  try {
    symKey = keyGen.convertKeySync({ data: keyBytes });
  } catch (e) {
    throw new Error(`convertKeySync failed: ${e instanceof Error ? e.message : String(e)}`);
  }

  let mac: cryptoFramework.Mac;
  try {
    mac = cryptoFramework.createMac('SHA1');
  } catch (e) {
    throw new Error(`createMac failed: ${e instanceof Error ? e.message : String(e)}`);
  }

  try {
    mac.initSync(symKey);
  } catch (e) {
    throw new Error(`mac initSync failed: ${e instanceof Error ? e.message : String(e)}`);
  }

  const msgBlob: cryptoFramework.DataBlob = { data: msgBytes };
  try {
    mac.updateSync(msgBlob);
  } catch (e) {
    throw new Error(`mac updateSync failed: ${e instanceof Error ? e.message : String(e)}`);
  }

  let resultBlob: cryptoFramework.DataBlob;
  try {
    resultBlob = mac.doFinalSync();
  } catch (e) {
    throw new Error(`mac doFinalSync failed: ${e instanceof Error ? e.message : String(e)}`);
  }

  return bytesToHex(resultBlob.data);
}

/**
 * 加密 sign_in 请求体
 *
 * 复用 encryptZseV4 对表单数据进行加密。
 *
 * @param formData - URL 编码的表单数据字符串
 * @returns 加密后的字符串
 */
export function encryptSignInPayload(formData: string): string {
  return encryptZseV4(formData);
}

/**
 * zse-v4 加密入口
 *
 * 算法步骤：
 * 1. 明文 = [seed, 0, ...encodeURIComponent(input) 的 ASCII 字节]
 *    seed = 12（来自 Rust 参考：Math.random = () => 0.1 → Math.floor(0.1 * 127) = 12）
 * 2. PKCS7 填充到 16 字节倍数
 * 3. 首块与 KEY16 异或 42
 * 4. rBlock 加密首块得到 c0
 * 5. 后续块用 CBC 模式（IV 为 c0）
 * 6. customEncode 输出
 *
 * @param input - 待加密字符串（通常是 MD5 十六进制字符串）
 * @returns 加密结果字符串
 */
export function encryptZseV4(input: string): string {
  const seed: number = 12;

  // 构造明文：[seed, 0, ...encodeURIComponent(input) 的 ASCII 字节]
  const encoded: string = encodeURIComponent(input);
  const encodedBytes: Uint8Array = new Uint8Array(encoded.length);
  for (let i = 0; i < encoded.length; i++) {
    encodedBytes[i] = encoded.charCodeAt(i);
  }

  const plainLen: number = 2 + encodedBytes.length;
  // PKCS7 填充
  const pad: number = 16 - (plainLen % 16);
  const totalLen: number = plainLen + pad;

  const plain: Uint8Array = new Uint8Array(totalLen);
  plain[0] = seed;
  plain[1] = 0;
  plain.set(encodedBytes, 2);
  for (let i = plainLen; i < totalLen; i++) {
    plain[i] = pad;
  }

  // 首块：与 KEY16 异或 42
  const first: Uint8Array = new Uint8Array(16);
  for (let i = 0; i < 16; i++) {
    first[i] = plain[i] ^ KEY16[i] ^ 42;
  }

  // 加密首块
  const c0: Uint8Array = rBlock(first);

  // 拼接密文
  const cipher: Uint8Array = new Uint8Array(totalLen);
  cipher.set(c0, 0);

  if (totalLen > 16) {
    const rest: Uint8Array = new Uint8Array(totalLen - 16);
    rest.set(plain.subarray(16), 0);
    const restCipher: Uint8Array = xBlocks(rest, c0);
    cipher.set(restCipher, 16);
  }

  return customEncode(cipher);
}

/**
 * 构造 x-zse-96 请求头
 *
 * 算法：
 * 1. 从完整 URL 提取 pathname（首个 '/' 之后的部分，含前导 '/'）
 * 2. 拼接签名源串：zse93 + "+" + pathname + "+" + dc0 [+ "+" + body]
 * 3. 计算 MD5 十六进制
 * 4. encryptZseV4 加密
 * 5. 返回 "2.0_" + 加密结果
 *
 * @param zse93 - 版本号，默认 "101_3_3.0"
 * @param url - 完整请求 URL
 * @param dc0 - d_c0 Cookie 值
 * @param body - 请求体（可选，GET 请求不传）
 * @returns x-zse-96 header 值，形如 "2.0_xxxxx"
 */
export function createZse96Header(
  zse93: string,
  url: string,
  dc0: string,
  body?: string
): string {
  // 从 URL 提取 pathname："/" + url 在 "://" 后首个 '/' 之后的部分
  let pathname: string = '/';
  const schemeEnd: number = url.indexOf('//');
  if (schemeEnd >= 0) {
    const afterScheme: string = url.substring(schemeEnd + 2);
    const pathStart: number = afterScheme.indexOf('/');
    if (pathStart >= 0) {
      pathname = afterScheme.substring(pathStart);
    }
  }

  // 拼接签名源串（对应 Kotlin listOfNotNull(...).joinToString("+")）
  const parts: string[] = [];
  parts.push(zse93);
  parts.push(pathname);
  parts.push(dc0);
  if (body !== undefined) {
    parts.push(body);
  }
  const signSource: string = parts.join('+');

  let hash: string;
  try {
    hash = md5Hex(signSource);
  } catch (e) {
    throw new Error(`md5Hex failed: ${e instanceof Error ? e.message : String(e)}`);
  }
  return '2.0_' + encryptZseV4(hash);
}
