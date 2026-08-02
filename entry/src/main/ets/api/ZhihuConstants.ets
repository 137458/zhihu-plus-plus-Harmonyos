/**
 * 知乎 API 公共常量
 *
 * 集中管理知乎 Web 端 API 使用的共享常量，避免跨模块重复定义导致修改遗漏。
 *
 * 历史背景：原 AuthApi.ets / ZhihuApi.ets / LoginViewModel.ets / SessionViewModel.ets
 * 各自重复定义了 ZHIHU_WEB_UA，注释明确提到"后续可考虑抽取到公共常量文件"。
 * 第 4 批 Slice 3 代码审查（P1 问题）触发本次抽取。
 */

/**
 * 桌面 User-Agent（与原 Android 项目 QrLogin.kt 的 ZHIHU_DESKTOP_USER_AGENT 对齐）。
 *
 * 用于知乎 Web API 请求头（AuthApi/ZhihuApi）和会话持久化（ZhihuSession.userAgent）。
 * 知乎 Web API 端点要求桌面 UA + zse 签名，手机 UA 会导致接口返回不一致。
 *
 * 注意：WebView 登录不使用此 UA，改用 ZHIHU_ANDROID_UA（手机 UA）。
 *
 * 修改此值需同步验证签名算法（zse-93）兼容性。
 */
export const ZHIHU_WEB_UA: string =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36';

/**
 * 知乎 Android App User-Agent（与原 Android 项目 AccountData.ANDROID_USER_AGENT 对齐）。
 *
 * 用于 ArkWeb WebView 登录流程：
 * - 加载知乎登录页（https://www.zhihu.com/signin?next=%2F）
 * - 登录成功后加载首页（https://www.zhihu.com/）获取 z_c0 等 Cookie
 *
 * 原 Android 行为（LoginActivity.kt 第 158-160 行）：
 * - 登录页使用 WebView 默认 UA（手机 Chrome）
 * - 跳转到首页时切换为 AccountData.ANDROID_USER_AGENT（手机知乎 App UA）
 * - 两者均为手机 UA，获取的 Cookie 与知乎 App 兼容
 *
 * HarmonyOS 实现统一使用此 UA（简化逻辑），效果与原 Android 一致。
 */
export const ZHIHU_ANDROID_UA: string =
  'com.zhihu.android/Futureve/10.61.0 Mozilla/5.0 (Linux; Android 12; sdk_gphone64_arm64 ' +
  'Build/SE1A.220630.001.A1; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 ' +
  'Chrome/57.0.1000.10 Mobile Safari/537.36';
