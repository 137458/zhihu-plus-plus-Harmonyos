/**
 * 错误消息工具
 *
 * 将 ApiError 对象映射为用户可读的错误消息。
 * 集中管理错误码→文案映射，消除各 ViewModel 中的重复实现。
 */

import { ApiError, ApiErrorCode } from '../model/ApiError';

/**
 * 将错误对象映射为用户可读的错误消息。
 *
 * 错误码映射：
 * - NETWORK_ERROR: "网络连接失败，请检查网络"
 * - TIMEOUT: "请求超时，请稍后重试"
 * - RISK_CONTROL: "已被风控，请稍后再试"
 * - UNAUTHORIZED: "登录已失效，请重新登录"
 * - SERVER_ERROR: "服务器异常，请稍后再试"
 * - 其他: err.message
 *
 * @param err 错误对象（可能是 ApiError 或其他 Error）
 * @returns 用户可读的错误消息
 */
export function mapApiError(err: object): string {
  if (err instanceof ApiError) {
    if (err.code === ApiErrorCode.NETWORK_ERROR) {
      return '网络连接失败，请检查网络';
    }
    if (err.code === ApiErrorCode.TIMEOUT) {
      return '请求超时，请稍后重试';
    }
    if (err.code === ApiErrorCode.RISK_CONTROL) {
      return '已被风控，请稍后再试';
    }
    if (err.code === ApiErrorCode.UNAUTHORIZED) {
      return '登录已失效，请重新登录';
    }
    if (err.code === ApiErrorCode.SERVER_ERROR) {
      return '服务器异常，请稍后重试';
    }
    return err.message;
  }
  return '未知错误';
}