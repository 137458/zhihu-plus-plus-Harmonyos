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
 * 桌面 User-Agent。
 *
 * 必须使用桌面 UA，否则知乎返回移动端 H5 登录页（功能受限）。
 * 同时用于：
 * - 知乎 API 请求头（AuthApi/ZhihuApi）
 * - ArkWeb WebView 全局 UA（LoginViewModel）
 * - 会话持久化（SessionViewModel/ZhihuSession.userAgent）
 *
 * 修改此值需同步验证签名算法（zse-93）兼容性。
 */
export const ZHIHU_WEB_UA: string =
  'Mozilla/5.0 (X11; U; Linux x86_64; en-US) AppleWebKit/540.0 (KHTML, like Gecko) Ubuntu/10.10 Chrome/9.1.0.0 Safari/540.0';
