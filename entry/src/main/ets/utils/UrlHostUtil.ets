/**
 * URL 主机名解析工具
 *
 * 从完整 URL 中提取真实主机名，供 onLoadIntercept 等安全校验场景使用。
 *
 * 安全要点：必须正确剥离 userinfo（`user:pass@`），否则形如
 * `https://www.zhihu.com:x@evil.com/` 的 URL 会被误判为可信主机
 * `www.zhihu.com`，而其真正主机是 `@` 之后的 `evil.com`，
 * 从而绕过白名单。详见 ArticleWebContainer 的 onLoadIntercept。
 */

/**
 * 从 URL 中提取主机名（纯函数）。
 *
 * 处理顺序：剥离协议 → 剥离 path → 剥离 userinfo → 剥离 port。
 *
 * @param url 完整 URL
 * @returns 主机名；非 http/https 或无法解析返回 null
 */
export function extractHostFromUrl(url: string): string | null {
  let rest: string = url;
  if (rest.startsWith('https://')) {
    rest = rest.substring('https://'.length);
  } else if (rest.startsWith('http://')) {
    rest = rest.substring('http://'.length);
  } else {
    return null;
  }
  // 去除 path 部分
  const slashIdx: number = rest.indexOf('/');
  if (slashIdx >= 0) {
    rest = rest.substring(0, slashIdx);
  }
  // 去除 userinfo（user:pass@），取最后一个 @ 之后的部分作为真实 host
  // 防止 https://www.zhihu.com:x@evil.com/ 绕过白名单
  const atIdx: number = rest.lastIndexOf('@');
  if (atIdx >= 0) {
    rest = rest.substring(atIdx + 1);
  }
  // 去除 port
  const colonIdx: number = rest.indexOf(':');
  if (colonIdx >= 0) {
    rest = rest.substring(0, colonIdx);
  }
  return rest.length > 0 ? rest : null;
}
