/**
 * Asset Store Kit 安全存储适配层
 *
 * 封装 @kit.AssetStoreKit，提供会话持久化能力。
 *
 * 设计：
 * - 会话序列化为 JSON 字符串，编码为 Uint8Array 存入 asset.Tag.SECRET
 * - 资产别名固定为 'zhihu_session'，存入 asset.Tag.ALIAS
 * - 访问控制：DEVICE_FIRST_UNLOCKED（设备首次解锁后可用）
 *
 * 操作映射：
 * - saveSession：先 update，若 not found（24000002）则 add
 * - loadSession：query 按别名查询，返回 SECRET 解码为字符串
 * - clearSession：remove 按别名删除
 *
 * 安全约束：
 * - SECRET 由 Asset Store Kit 加密存储，不进日志/源码/普通 KV
 * - 调用方传入的 ZhihuSession 中的 Cookie/Token 不会被打日志
 *
 * @kit.AssetStoreKit 从 API 11 开始支持，当前项目基线 API 23 满足要求。
 */

import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ZhihuSession } from '../model/ZhihuSession';

/** 资产别名（固定，用于标识会话资产） */
const SESSION_ALIAS: string = 'zhihu_session';

/** Asset Store Kit 错误码：资产未找到 */
const ERR_CODE_ASSET_NOT_FOUND: number = 24000002;

const DOMAIN: number = 0x0000;
const TAG: string = 'AssetStore';

/**
 * 会话安全存储适配层
 *
 * 单例模式，封装 Asset Store Kit 的 CRUD 操作。
 */
export class AssetStore {
  private static instance: AssetStore;
  private textEncoder: util.TextEncoder;
  private textDecoder: util.TextDecoder;

  private constructor() {
    this.textEncoder = new util.TextEncoder();
    this.textDecoder = util.TextDecoder.create('utf-8');
  }

  /** 获取单例 */
  static getInstance(): AssetStore {
    if (AssetStore.instance === undefined) {
      AssetStore.instance = new AssetStore();
    }
    return AssetStore.instance;
  }

  /**
   * 保存会话到 Asset Store。
   *
   * 若资产已存在则更新，不存在则新增。
   *
   * @param session - 待保存的会话
   * @returns 保存成功返回 true，失败返回 false
   */
  async saveSession(session: ZhihuSession): Promise<boolean> {
    const jsonStr: string = session.toJson();
    const secretBytes: Uint8Array = this.stringToBytes(jsonStr);
    const aliasBytes: Uint8Array = this.stringToBytes(SESSION_ALIAS);

    try {
      // 先尝试更新
      const query: asset.AssetMap = this.buildAliasQuery(aliasBytes);
      const updateAttrs: asset.AssetMap = new Map<asset.Tag, asset.Value>();
      updateAttrs.set(asset.Tag.SECRET, secretBytes);
      await asset.update(query, updateAttrs);
      return true;
    } catch (e) {
      // 资产不存在，需要新增
      const errCode: number = this.extractErrCode(e);
      if (errCode === ERR_CODE_ASSET_NOT_FOUND) {
        try {
          const attrs: asset.AssetMap = new Map<asset.Tag, asset.Value>();
          attrs.set(asset.Tag.ALIAS, aliasBytes);
          attrs.set(asset.Tag.SECRET, secretBytes);
          attrs.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
          await asset.add(attrs);
          return true;
        } catch (addErr) {
          hilog.error(DOMAIN, TAG, 'saveSession add failed: %{public}s',
            addErr instanceof Error ? addErr.message : String(addErr));
          return false;
        }
      }
      hilog.error(DOMAIN, TAG, 'saveSession update failed (code=%{public}d): %{public}s',
        errCode, e instanceof Error ? e.message : String(e));
      return false;
    }
  }

  /**
   * 从 Asset Store 加载会话。
   *
   * @returns 加载成功返回 ZhihuSession 实例；未找到或解析失败返回 null
   */
  async loadSession(): Promise<ZhihuSession | null> {
    const aliasBytes: Uint8Array = this.stringToBytes(SESSION_ALIAS);

    try {
      const query: asset.AssetMap = this.buildAliasQuery(aliasBytes);
      // 返回所有字段以供解析
      query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);

      const results: Array<asset.AssetMap> = await asset.query(query);
      if (results.length === 0) {
        return null;
      }

      const firstResult: asset.AssetMap = results[0];
      const secretValue: asset.Value | undefined = firstResult.get(asset.Tag.SECRET);
      if (secretValue === undefined) {
        return null;
      }

      // asset.Value 是 Uint8Array | boolean | number 联合类型，需运行时校验
      if (typeof secretValue === 'object' && secretValue instanceof Uint8Array) {
        const jsonStr: string = this.bytesToString(secretValue);
        return ZhihuSession.fromJson(jsonStr);
      }
      return null;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'loadSession failed: %{public}s',
        e instanceof Error ? e.message : String(e));
      return null;
    }
  }

  /**
   * 清除 Asset Store 中的会话。
   *
   * @returns 清除成功返回 true；资产不存在或失败返回 false
   */
  async clearSession(): Promise<boolean> {
    const aliasBytes: Uint8Array = this.stringToBytes(SESSION_ALIAS);

    try {
      const query: asset.AssetMap = this.buildAliasQuery(aliasBytes);
      await asset.remove(query);
      return true;
    } catch (e) {
      // 资产不存在视为清除成功
      const errCode: number = this.extractErrCode(e);
      if (errCode === ERR_CODE_ASSET_NOT_FOUND) {
        return true;
      }
      return false;
    }
  }

  /**
   * 构建按别名查询的 AssetMap。
   *
   * @param aliasBytes - 别名字节
   * @returns 包含 ALIAS 的查询 AssetMap
   */
  private buildAliasQuery(aliasBytes: Uint8Array): asset.AssetMap {
    const query: asset.AssetMap = new Map<asset.Tag, asset.Value>();
    query.set(asset.Tag.ALIAS, aliasBytes);
    return query;
  }

  /**
   * 字符串转 Uint8Array（UTF-8 编码）。
   *
   * @param str - 待编码字符串
   * @returns UTF-8 字节数组
   */
  private stringToBytes(str: string): Uint8Array {
    return this.textEncoder.encodeInto(str);
  }

  /**
   * Uint8Array 转字符串（UTF-8 解码）。
   *
   * @param bytes - 待解码字节数组
   * @returns UTF-8 字符串
   */
  private bytesToString(bytes: Uint8Array): string {
    return this.textDecoder.decodeWithStream(bytes);
  }

  /**
   * 从异常对象中提取 Asset Store Kit 错误码。
   *
   * ArkTS 中 BusinessError 的 code 字段为 number，
   * 但运行时可能是其他类型，需 typeof 校验。
   *
   * @param e - 异常对象
   * @returns 错误码；无法提取返回 -1
   */
  private extractErrCode(e: object): number {
    const err: Record<string, Object> = e as Record<string, Object>;
    const code: Object | undefined = err.code;
    if (typeof code === 'number') {
      return code;
    }
    return -1;
  }
}
