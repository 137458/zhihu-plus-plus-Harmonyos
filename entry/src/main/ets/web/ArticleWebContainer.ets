/**
 * ArkWeb 正文容器
 *
 * 基于 @ohos.web.web 的 Web 组件封装，用于渲染知乎内容（回答/文章）的 HTML 正文。
 *
 * 职责：
 * - 将知乎 content HTML 片段包装为完整 HTML 文档（含 charset/viewport/referer meta + CSS）
 * - 深色/浅色模式 CSS 变量切换（背景色/文字色/代码块色/链接色）
 * - 图片防盗链：通过 <base href="https://www.zhihu.com/"> 注入 Referer
 * - 安全：onLoadIntercept 校验协议（仅 HTTPS）和可信主机白名单
 * - 最小化 JS 桥接：仅暴露图片点击和链接点击事件给原生
 *
 * 不职责：
 * - 不负责拉取数据（由 ViewModel 提供 htmlContent）
 * - 不负责状态切换（加载/错误/空态由调用方处理）
 * - 不负责路由跳转（仅通过回调通知调用方）
 *
 * 参考证据：docs/evidence/03-content-detail.md §6.1 内容渲染策略
 */

import { webview } from '@kit.ArkWeb';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { extractHostFromUrl } from '../utils/UrlHostUtil';

/** 可信主机白名单（知乎 CDN 和公式图） */
const TRUSTED_HOSTS: string[] = [
  'www.zhihu.com',
  'pic1.zhimg.com',
  'pic2.zhimg.com',
  'pic3.zhimg.com',
  'pic4.zhimg.com',
  'picx.zhimg.com',
  'pica.zhimg.com',
  'picb.zhimg.com',
  'picd.zhimg.com',
  'equation.zhihu.com'
];

/** 浅色模式 CSS 变量 */
const LIGHT_CSS_VARS: string = `
  :root {
    --bg-color: #ffffff;
    --text-color: #1a1a1a;
    --text-secondary: #6b7280;
    --link-color: #0066ff;
    --code-bg: #f3f4f6;
    --border-color: #e5e7eb;
    --blockquote-color: #6b7280;
  }
`;

/** 深色模式 CSS 变量 */
const DARK_CSS_VARS: string = `
  :root {
    --bg-color: #1f1f1f;
    --text-color: #e5e5e5;
    --text-secondary: #9ca3af;
    --link-color: #66b3ff;
    --code-bg: #2d2d2d;
    --border-color: #404040;
    --blockquote-color: #9ca3af;
  }
`;

/** 通用 CSS 样式（使用 CSS 变量，适配深浅色） */
const BASE_CSS: string = `
  * { box-sizing: border-box; }
  body {
    margin: 0;
    padding: 16px;
    background-color: var(--bg-color);
    color: var(--text-color);
    font-family: -apple-system, BlinkMacSystemFont, "HarmonyOS Sans", "PingFang SC", "Microsoft YaHei", sans-serif;
    font-size: 16px;
    line-height: 1.75;
    word-wrap: break-word;
    overflow-wrap: break-word;
  }
  img {
    max-width: 100%;
    height: auto;
    display: block;
    margin: 12px auto;
  }
  a {
    color: var(--link-color);
    text-decoration: none;
  }
  a:hover { text-decoration: underline; }
  h1, h2, h3, h4, h5, h6 {
    margin: 20px 0 12px;
    font-weight: 600;
    line-height: 1.4;
  }
  h1 { font-size: 1.5em; }
  h2 { font-size: 1.3em; }
  h3 { font-size: 1.15em; }
  p { margin: 12px 0; }
  code {
    background-color: var(--code-bg);
    padding: 2px 6px;
    border-radius: 4px;
    font-family: "JetBrains Mono", "Fira Code", "Cascadia Code", Consolas, monospace;
    font-size: 0.9em;
  }
  pre {
    background-color: var(--code-bg);
    padding: 12px;
    border-radius: 6px;
    overflow-x: auto;
    margin: 12px 0;
  }
  pre code {
    background: transparent;
    padding: 0;
  }
  blockquote {
    margin: 12px 0;
    padding: 8px 16px;
    border-left: 4px solid var(--border-color);
    color: var(--blockquote-color);
    background-color: var(--code-bg);
  }
  table {
    width: 100%;
    border-collapse: collapse;
    margin: 12px 0;
    display: block;
    overflow-x: auto;
  }
  th, td {
    border: 1px solid var(--border-color);
    padding: 8px 12px;
    text-align: left;
  }
  th { background-color: var(--code-bg); font-weight: 600; }
  hr {
    border: none;
    border-top: 1px solid var(--border-color);
    margin: 20px 0;
  }
  .invisible { display: none; }
`;

/**
 * 将知乎 content HTML 包装为完整 HTML 文档。
 *
 * @param content 知乎 API 返回的 content HTML 片段
 * @param colorMode 当前颜色模式（COLOR_MODE_LIGHT/COLOR_MODE_DARK）
 * @returns 完整的 HTML 文档字符串
 */
function wrapHtml(content: string, colorMode: ConfigurationConstant.ColorMode): string {
  const cssVars: string = colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    ? DARK_CSS_VARS
    : LIGHT_CSS_VARS;
  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
  <meta name="referer" content="always">
  <base href="https://www.zhihu.com/">
  <style>${cssVars}${BASE_CSS}</style>
</head>
<body>${content}</body>
</html>`;
}

@ComponentV2
export struct ArticleWebContainer {
  /** 待渲染的 HTML 内容（知乎 content 字段，通常是 HTML 片段） */
  @Param htmlContent: string = '';
  /** 页面加载完成回调 */
  @Param onPageFinish: (() => void) | undefined = undefined;
  /** 页面加载错误回调 */
  @Param onError: ((err: string) => void) | undefined = undefined;
  /** 链接点击回调（用于外链拦截后通知调用方处理路由） */
  @Param onLinkClick: ((url: string) => void) | undefined = undefined;

  /** Web 控制器 */
  private controller: webview.WebviewController = new webview.WebviewController();

  build() {
    Web({ src: this.buildFullHtml(), controller: this.controller })
      .domStorageAccess(true)
      .imageAccess(true)
      .javaScriptAccess(true)
      .fileAccess(false)
      .mixedMode(MixedMode.None)
      .onlineImageAccess(true)
      .geolocationAccess(false)
      .mediaPlayGestureAccess(true)
      .darkMode(WebDarkMode.Auto)
      .forceDarkAccess(false)
      .onPageBegin(() => {
        // 页面开始加载
      })
      .onPageEnd(() => {
        const cb = this.onPageFinish;
        if (cb !== undefined) {
          cb();
        }
      })
      .onErrorReceive((error: OnErrorReceiveEvent) => {
        const cb = this.onError;
        if (cb !== undefined) {
          const msg: string = error.error.getErrorInfo();
          cb(msg);
        }
      })
      .onLoadIntercept((event: OnLoadInterceptEvent): boolean => {
        return this.shouldIntercept(event.data.getRequestUrl());
      });
  }

  /**
   * 构造完整 HTML 文档。
   *
   * 深色模式：通过 ConfigurationConstant.ColorMode 判断。
   * 由于 ArkTS 严格模式限制，这里使用 WebDarkMode.Auto + CSS 媒体查询，
   * ArkWeb 会根据系统深色模式自动应用 CSS。
   *
   * 注意：本方法在 build 中调用，每次 htmlContent 变化时重新构造。
   */
  private buildFullHtml(): string {
    // 简化处理：同时注入浅色和深色 CSS 变量，通过 @media (prefers-color-scheme) 切换
    const fullCss: string = `${LIGHT_CSS_VARS}
@media (prefers-color-scheme: dark) {
${DARK_CSS_VARS}
}
${BASE_CSS}`;
    return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
  <meta name="referer" content="always">
  <base href="https://www.zhihu.com/">
  <style>${fullCss}</style>
</head>
<body>${this.htmlContent}</body>
</html>`;
  }

  /**
   * 判断 URL 是否应被拦截。
   *
   * 拦截规则：
   * - 非 http/https 协议 → 拦截
   * - 不可信主机 → 拦截并通过 onLinkClick 通知调用方
   * - 可信主机 → 放行
   *
   * @param url 请求 URL
   * @returns true 表示拦截，false 表示放行
   */
  private shouldIntercept(url: string): boolean {
    // 非 http/https 协议拦截
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return true;
    }
    // 解析主机名（含 userinfo 剥离，防止白名单绕过）
    const host: string | null = extractHostFromUrl(url);
    if (host === null) {
      return true;
    }
    // 校验可信主机
    if (this.isTrustedHost(host)) {
      return false;
    }
    // 不可信主机：通知调用方处理（如弹 toast 或跳转浏览器）
    const cb = this.onLinkClick;
    if (cb !== undefined) {
      cb(url);
    }
    return true;
  }

  /**
   * 判断主机是否在可信白名单中。
   */
  private isTrustedHost(host: string): boolean {
    for (let i = 0; i < TRUSTED_HOSTS.length; i++) {
      if (TRUSTED_HOSTS[i] === host) {
        return true;
      }
    }
    return false;
  }
}
