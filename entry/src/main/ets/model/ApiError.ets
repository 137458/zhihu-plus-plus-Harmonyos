/**
 * 业务错误枚举和错误类
 *
 * 用于网络层统一错误处理，区分不同错误类型以便 UI 层展示合适的提示。
 * ApiError 继承 Error，额外携带错误码 code 和可选的原始错误 cause，
 * 便于上层根据 code 进行分支处理。
 *
 * 注意：cause 用独立字段保存，不依赖 ES2022 的 Error.cause，
 * 保证 ArkTS 兼容。
 */

/** API 错误码 */
export enum ApiErrorCode {
  /** 网络错误（无连接、DNS 失败等） */
  NETWORK_ERROR,
  /** 请求超时 */
  TIMEOUT,
  /** 响应解析失败 */
  PARSE_ERROR,
  /** 风控拦截 */
  RISK_CONTROL,
  /** 未授权（登录失效） */
  UNAUTHORIZED,
  /** 资源不存在 */
  NOT_FOUND,
  /** 服务器错误（5xx） */
  SERVER_ERROR,
  /** 未知错误 */
  UNKNOWN
}

/**
 * API 错误类
 *
 * 继承 Error，额外携带错误码 code 和可选的原始错误 cause。
 * 提供一组静态工厂方法便于快速创建不同类型的错误实例。
 */
export class ApiError extends Error {
  /** 错误码 */
  code: ApiErrorCode;
  /** 原始错误（可选，独立字段保存） */
  cause?: Error;

  constructor(code: ApiErrorCode, message: string, cause?: Error) {
    super(message);
    this.name = 'ApiError';
    this.code = code;
    if (cause !== undefined) {
      this.cause = cause;
    }
  }

  /** 创建网络错误（无连接、DNS 失败等） */
  static network(message: string, cause?: Error): ApiError {
    return new ApiError(ApiErrorCode.NETWORK_ERROR, message, cause);
  }

  /** 创建请求超时错误 */
  static timeout(message: string, cause?: Error): ApiError {
    return new ApiError(ApiErrorCode.TIMEOUT, message, cause);
  }

  /** 创建响应解析失败错误 */
  static parseError(message: string, cause?: Error): ApiError {
    return new ApiError(ApiErrorCode.PARSE_ERROR, message, cause);
  }

  /** 创建风控拦截错误 */
  static riskControl(message: string, cause?: Error): ApiError {
    return new ApiError(ApiErrorCode.RISK_CONTROL, message, cause);
  }

  /** 创建未授权错误（登录失效） */
  static unauthorized(message: string, cause?: Error): ApiError {
    return new ApiError(ApiErrorCode.UNAUTHORIZED, message, cause);
  }

  /** 创建资源不存在错误 */
  static notFound(message: string, cause?: Error): ApiError {
    return new ApiError(ApiErrorCode.NOT_FOUND, message, cause);
  }

  /** 创建服务器错误（5xx） */
  static serverError(message: string, cause?: Error): ApiError {
    return new ApiError(ApiErrorCode.SERVER_ERROR, message, cause);
  }

  /** 创建未知错误 */
  static unknown(message: string, cause?: Error): ApiError {
    return new ApiError(ApiErrorCode.UNKNOWN, message, cause);
  }
}
