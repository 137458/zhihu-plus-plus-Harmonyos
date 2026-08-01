/**
 * 点赞状态枚举
 *
 * 对应 Android 端 VoteUpState 枚举：
 * - Up：已点赞（回答传 {"type":"up"}，文章传 {"voting":1}）
 * - Neutral：未点赞/取消点赞（回答传 {"type":"neutral"}，文章传 {"voting":0}）
 *
 * 注意：首发不支持踩（Down），仅支持赞（Up）和中立（Neutral）。
 */
export enum VoteState {
  /** 未点赞 */
  NEUTRAL = 'neutral',
  /** 已点赞 */
  UP = 'up'
}