/**
 * 统一 HTTP 客户端
 *
 * 基于 @kit.NetworkKit 的 http 模块封装，提供：
 * - 统一的 GET 请求方法
 * - 超时配置（connectTimeout + readTimeout）
 * - HTTP 状态码到 ApiError 的转换
 * - 资源释放保证（HttpRequest.destroy() 在 then/catch/finally 中调用）
 * - 响应头中 Set-Cookie 的回调通知（供 CookieJar 提取 d_c0）
 *
 * 设计约束：
 * - 不引入第三方 HTTP 库
 * - 所有请求必须设置 connectTimeout 和 readTimeout
 * - 敏感信息（Cookie）不进入日志
 * - 每个请求使用独立的 HttpRequest 实例，避免实例复用导致的连接泄漏
 *
 * ArkTS 严格模式约束：
 * - 禁止索引签名 interface（[key: string]: ...）
 * - 禁止索引访问（obj[key]）
 * - 用 Object.entries 遍历对象字段，元组索引访问允许
 */

import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ApiError, ApiErrorCode } from '../model/ApiError';

/** HTTP 响应对象 */
export interface HttpResponse {
  /** HTTP 状态码 */
  statusCode: number;
  /** 响应体字符串 */
  body: string;
}

/** GET 请求选项 */
export interface GetRequestOptions {
  /** 请求 URL */
  url: string;
  /** 请求头 */
  headers?: Record<string, string>;
  /** 连接超时（ms），默认 5000 */
  connectTimeout?: number;
  /** 读取超时（ms），默认 10000 */
  readTimeout?: number;
  /** 响应头中 Set-Cookie 的回调 */
  onSetCookie?: (cookieString: string) => void;
  /**
   * 401 重试时重建请求头的回调。
   *
   * 当 token 刷新后，CookieJar 中的 Cookie 已更新，但原始 headers 中的
   * Cookie 字段已过期。此回调在重试时被调用以获取最新 headers。
   * 不传时使用原始 headers 重试。
   */
  rebuildHeaders?: () => Record<string, string>;
}

/** POST 请求选项 */
export interface PostRequestOptions {
  /** 请求 URL */
  url: string;
  /** 请求头 */
  headers?: Record<string, string>;
  /** 请求体字符串 */
  body: string;
  /** 连接超时（ms），默认 5000 */
  connectTimeout?: number;
  /** 读取超时（ms），默认 10000 */
  readTimeout?: number;
  /** 响应头中 Set-Cookie 的回调 */
  onSetCookie?: (cookieString: string) => void;
  /**
   * 401 重试时重建请求头的回调。
   *
   * 当 token 刷新后，CookieJar 中的 Cookie 已更新，但原始 headers 中的
   * Cookie 字段已过期。此回调在重试时被调用以获取最新 headers。
   * 不传时使用原始 headers 重试。
   */
  rebuildHeaders?: () => Record<string, string>;
}

/** 默认连接超时（ms）—— 参考 Android 端 5s 配置 */
const DEFAULT_CONNECT_TIMEOUT: number = 5000;
/** 默认读取超时（ms）—— 参考 Android 端 10s 配置 */
const DEFAULT_READ_TIMEOUT: number = 10000;

/** HTTP 状态码常量 */
const HTTP_OK_MIN: number = 200;
const HTTP_OK_MAX: number = 300;
const HTTP_UNAUTHORIZED: number = 401;
const HTTP_NOT_FOUND: number = 404;
const HTTP_INTERNAL_ERROR: number = 500;

/**
 * 业务错误码（来自 HarmonyOS http 模块的 BusinessError.code）
 * - 28: 连接超时（connectTimeout 触发）
 * - 29: 读取超时（readTimeout 触发）
 */
const HTTP_ERROR_CONNECT_TIMEOUT: number = 28;
const HTTP_ERROR_READ_TIMEOUT: number = 29;

export class NetworkClient {
  /**
   * 401 未授权全局处理器。
   *
   * 由 SessionViewModel 在初始化时设置，当任意请求收到 401 时自动触发：
   * 1. 调用此处理器尝试刷新 token
   * 2. 刷新成功 → 重试原请求一次
   * 3. 刷新失败或未设置处理器 → 抛出 ApiError.unauthorized
   *
   * 注意：此设计避免 NetworkClient 与 SessionViewModel 直接耦合，
   * 处理器通过静态方法注入，不依赖 NetworkClient 构造函数。
   */
  private static unauthorizedHandler: (() => Promise<boolean>) | null = null;

  /**
   * 设置 401 全局处理器。
   *
   * @param handler 刷新 token 的异步函数，返回 true 表示刷新成功可重试
   */
  static setUnauthorizedHandler(handler: (() => Promise<boolean>) | null): void {
    NetworkClient.unauthorizedHandler = handler;
  }

  /**
   * 发起 GET 请求
   *
   * @param options 请求选项
   * @returns 响应对象
   * @throws ApiError 网络错误、超时、HTTP 错误码
   */
  async get(options: GetRequestOptions): Promise<HttpResponse> {
    const header: Record<string, string> = options.headers !== undefined ? options.headers : {};
    const connectTimeout: number = options.connectTimeout !== undefined
      ? options.connectTimeout
      : DEFAULT_CONNECT_TIMEOUT;
    const readTimeout: number = options.readTimeout !== undefined
      ? options.readTimeout
      : DEFAULT_READ_TIMEOUT;
    return this.requestInternal(
      http.RequestMethod.GET,
      options.url,
      header,
      connectTimeout,
      readTimeout,
      options.onSetCookie,
      undefined,
      options.rebuildHeaders
    );
  }

  /**
   * 发起 POST 请求
   *
   * @param options 请求选项（包含 body）
   * @returns 响应对象
   * @throws ApiError 网络错误、超时、HTTP 错误码
   */
  async post(options: PostRequestOptions): Promise<HttpResponse> {
    const header: Record<string, string> = options.headers !== undefined ? options.headers : {};
    const connectTimeout: number = options.connectTimeout !== undefined
      ? options.connectTimeout
      : DEFAULT_CONNECT_TIMEOUT;
    const readTimeout: number = options.readTimeout !== undefined
      ? options.readTimeout
      : DEFAULT_READ_TIMEOUT;
    return this.requestInternal(
      http.RequestMethod.POST,
      options.url,
      header,
      connectTimeout,
      readTimeout,
      options.onSetCookie,
      options.body,
      options.rebuildHeaders
    );
  }

  /**
   * 发起 PUT 请求
   *
   * @param options 请求选项（包含 body）
   * @returns 响应对象
   * @throws ApiError 网络错误、超时、HTTP 错误码
   */
  async put(options: PostRequestOptions): Promise<HttpResponse> {
    const header: Record<string, string> = options.headers !== undefined ? options.headers : {};
    const connectTimeout: number = options.connectTimeout !== undefined
      ? options.connectTimeout
      : DEFAULT_CONNECT_TIMEOUT;
    const readTimeout: number = options.readTimeout !== undefined
      ? options.readTimeout
      : DEFAULT_READ_TIMEOUT;
    return this.requestInternal(
      http.RequestMethod.PUT,
      options.url,
      header,
      connectTimeout,
      readTimeout,
      options.onSetCookie,
      options.body,
      options.rebuildHeaders
    );
  }

  /**
   * 请求内部实现（GET/POST/PUT 公共逻辑）。
   *
   * 统一处理：超时配置、Set-Cookie 回调、HTTP 状态码到 ApiError 转换、资源释放。
   *
   * @param method HTTP 方法（GET / POST）
   * @param url 请求 URL
   * @param header 请求头
   * @param connectTimeout 连接超时（ms）
   * @param readTimeout 读取超时（ms）
   * @param onSetCookie Set-Cookie 回调（可选）
   * @param body 请求体（仅 POST 传；GET 传 null）
   * @returns 响应对象
   * @throws ApiError 网络错误、超时、HTTP 错误码
   */
  private async requestInternal(
    method: http.RequestMethod,
    url: string,
    header: Record<string, string>,
    connectTimeout: number,
    readTimeout: number,
    onSetCookie?: (cookieString: string) => void,
    body?: string,
    rebuildHeaders?: () => Record<string, string>
  ): Promise<HttpResponse> {
    const req: http.HttpRequest = http.createHttp();
    try {
      const requestOptions: http.HttpRequestOptions = {
        method: method,
        header: header,
        connectTimeout: connectTimeout,
        readTimeout: readTimeout,
        expectDataType: http.HttpDataType.STRING
      };
      if (body !== undefined) {
        requestOptions.extraData = body;
      }

      const res: http.HttpResponse = await req.request(url, requestOptions);

      // 通知 Set-Cookie 回调（如果有）
      // res.header 在 SDK 中声明为 object，ArkTS 严格模式禁止直接索引访问
      // 通过 Object.entries 遍历查找 set-cookie 字段
      if (onSetCookie !== undefined) {
        const setCookie: string | undefined = this.extractSetCookie(res.header);
        if (setCookie !== undefined) {
          onSetCookie(setCookie);
        }
      }

      const statusCode: number = res.responseCode;
      const responseBody: string = typeof res.result === 'string' ? res.result : String(res.result);

      // HTTP 状态码到 ApiError 的转换
      if (statusCode >= HTTP_OK_MIN && statusCode < HTTP_OK_MAX) {
        return { statusCode, body: responseBody };
      }
      if (statusCode === HTTP_UNAUTHORIZED) {
        // 401 时尝试全局处理器刷新 token（节流由处理器内部控制）
        if (NetworkClient.unauthorizedHandler !== null) {
          const refreshed: boolean = await NetworkClient.unauthorizedHandler();
          if (refreshed) {
            // 刷新成功，用 rebuildHeaders 重建 headers（Cookie 已更新）
            // 不传 rebuildHeaders 时使用原始 headers（至少保证重试可进行）
            const newHeaders: Record<string, string> = rebuildHeaders !== undefined
              ? rebuildHeaders()
              : header;
            return this.requestInternal(
              method, url, newHeaders, connectTimeout, readTimeout,
              onSetCookie, body, rebuildHeaders
            );
          }
        }
        throw ApiError.unauthorized(`HTTP ${statusCode}`);
      }
      if (statusCode === HTTP_NOT_FOUND) {
        throw ApiError.notFound(`HTTP ${statusCode}`);
      }
      if (statusCode >= HTTP_INTERNAL_ERROR) {
        throw ApiError.serverError(`HTTP ${statusCode}`);
      }
      // 其他非 2xx 状态码视为未知错误
      throw new ApiError(ApiErrorCode.UNKNOWN, `HTTP ${statusCode}`);
    } catch (err) {
      // 已经是 ApiError 的直接抛出
      if (err instanceof ApiError) {
        throw err;
      }
      // HarmonyOS http 模块的 BusinessError 包含 code 和 message
      // 但运行时 err 可能不是 BusinessError，需用 typeof 校验防止类型问题
      const errTyped: BusinessError = err as BusinessError;
      const errCode: number = typeof errTyped.code === 'number' ? errTyped.code : -1;
      const errMsg: string = typeof errTyped.message === 'string' ? errTyped.message : String(err);
      if (errCode === HTTP_ERROR_CONNECT_TIMEOUT || errCode === HTTP_ERROR_READ_TIMEOUT) {
        throw ApiError.timeout(`connect or read timeout: ${errMsg}`);
      }
      // 其他业务错误视为网络错误（DNS 失败、无连接等）
      throw ApiError.network(`network error: ${errMsg}`);
    } finally {
      // 确保资源释放
      req.destroy();
    }
  }

  /**
   * 从响应头对象中提取 Set-Cookie 值。
   *
   * ArkTS 严格模式禁止索引访问（header['set-cookie']），
   * 用 Object.entries 遍历查找（不区分大小写）。
   *
   * @param header http.HttpResponse.header（object 类型）
   * @returns Set-Cookie 字符串；不存在返回 undefined
   */
  private extractSetCookie(header: object): string | undefined {
    if (header === null || header === undefined) {
      return undefined;
    }
    const entries: [string, object][] = Object.entries(header);
    for (let i = 0; i < entries.length; i++) {
      const entry: [string, object] = entries[i];
      const key: string = entry[0];
      if (key.toLowerCase() === 'set-cookie') {
        const value: object = entry[1];
        if (typeof value === 'string') {
          return value;
        }
        if (Array.isArray(value)) {
          const arr: string[] = value as string[];
          return arr.join('; ');
        }
      }
    }
    return undefined;
  }
}
