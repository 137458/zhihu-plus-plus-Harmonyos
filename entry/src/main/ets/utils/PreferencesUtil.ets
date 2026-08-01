/**
 * Preferences 持久化工具
 *
 * 基于 @kit.ArkData 的 preferences 模块，提供字符串数组的读写能力。
 * 用于搜索历史等轻量本地数据的持久化。
 *
 * 设计约束：
 * - 单进程内 Context 唯一，通过 init(context) 在 EntryAbility.onCreate 中注入
 * - 未调用 init 前所有读操作返回空数组，写操作静默 no-op（避免崩溃）
 * - 字符串数组以 JSON 字符串形式存储（preferences 原生不支持 string[]）
 * - 所有异常静默处理（hilog.error 记录），不向上抛
 *
 * ArkTS 严格模式约束：
 * - 不使用 any/unknown
 * - JSON.parse 返回 object，运行时用 Array.isArray + typeof 校验类型
 * - 不使用索引签名访问
 */

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'PreferencesUtil';

/** preferences 文件名（对应一个 XML 文件） */
const PREF_NAME: string = 'zhihu_plus_pref';

/** 全局 applicationContext，由 EntryAbility.onCreate 注入 */
let appContext: common.Context | undefined = undefined;

/**
 * Preferences 持久化工具
 *
 * 用法：
 *   EntryAbility.onCreate 中调用 PreferencesUtil.init(this.context.getApplicationContext())
 *   之后通过 getStringList / putStringList / remove 读写
 */
export class PreferencesUtil {
  /**
   * 注入 applicationContext。必须在 Ability onCreate 中调用一次。
   *
   * @param context applicationContext（推荐）或 abilityContext
   */
  static init(context: common.Context): void {
    appContext = context;
    hilog.info(DOMAIN, TAG, 'init: context injected');
  }

  /** 是否已初始化（Context 是否已注入） */
  static isInitialized(): boolean {
    return appContext !== undefined;
  }

  /** 获取已注入的 ApplicationContext（用于主题切换等操作） */
  static getAppContext(): common.Context | undefined {
    return appContext;
  }

  /**
   * 读取字符串数组。
   *
   * @param key 存储键
   * @returns 字符串数组；未初始化、键不存在、解析失败均返回空数组
   */
  static async getStringList(key: string): Promise<string[]> {
    if (appContext === undefined) {
      hilog.warn(DOMAIN, TAG, 'getStringList: appContext not initialized, returning empty array');
      return [];
    }
    try {
      const pref: preferences.Preferences = await preferences.getPreferences(appContext, PREF_NAME);
      const raw = await pref.get(key, '');
      if (typeof raw !== 'string') {
        return [];
      }
      if (raw.length === 0) {
        return [];
      }
      let parsed: object;
      try {
        parsed = JSON.parse(raw);
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'getStringList: JSON.parse failed for key=%{public}s', key);
        return [];
      }
      if (!Array.isArray(parsed)) {
        return [];
      }
      const arr: object[] = parsed as object[];
      const result: string[] = [];
      for (let i = 0; i < arr.length; i++) {
        const item: object = arr[i];
        if (typeof item === 'string') {
          result.push(item);
        }
      }
      return result;
    } catch (e) {
      const errMsg: string = e instanceof Error ? e.message : String(e);
      hilog.error(DOMAIN, TAG, 'getStringList failed for key=%{public}s: %{public}s', key, errMsg);
      return [];
    }
  }

  /**
   * 写入字符串数组。
   *
   * @param key 存储键
   * @param value 字符串数组（内部 JSON.stringify 后存储）
   */
  static async putStringList(key: string, value: string[]): Promise<void> {
    if (appContext === undefined) {
      hilog.warn(DOMAIN, TAG, 'putStringList: appContext not initialized, no-op');
      return;
    }
    try {
      const pref: preferences.Preferences = await preferences.getPreferences(appContext, PREF_NAME);
      await pref.put(key, JSON.stringify(value));
      await pref.flush();
    } catch (e) {
      const errMsg: string = e instanceof Error ? e.message : String(e);
      hilog.error(DOMAIN, TAG, 'putStringList failed for key=%{public}s: %{public}s', key, errMsg);
    }
  }

  /**
   * 删除指定键。
   *
   * @param key 存储键
   */
  static async remove(key: string): Promise<void> {
    if (appContext === undefined) {
      return;
    }
    try {
      const pref: preferences.Preferences = await preferences.getPreferences(appContext, PREF_NAME);
      await pref.delete(key);
      await pref.flush();
    } catch (e) {
      const errMsg: string = e instanceof Error ? e.message : String(e);
      hilog.error(DOMAIN, TAG, 'remove failed for key=%{public}s: %{public}s', key, errMsg);
    }
  }
}
