/**
 * 应用路由契约
 *
 * 集中管理路由名和页面参数类型，避免在调用方硬编码字符串。
 * 所有页面参数必须使用显式 ArkTS 类型，禁止 any/unknown。
 */

/** 路由名常量，与 main_pages.json 中的 src 顺序保持一致 */
export class RouteName {
  /** 主壳，承载 Navigation + NavPathStack 的入口页面 */
  static readonly INDEX: string = 'Index';
  /** 首页（推荐信息流） */
  static readonly HOME: string = 'HomePage';
  /** 搜索页 */
  static readonly SEARCH: string = 'SearchPage';
  /** 问题详情页 */
  static readonly QUESTION_DETAIL: string = 'QuestionDetailPage';
  /** 回答详情页 */
  static readonly ANSWER_DETAIL: string = 'AnswerDetailPage';
  /** 文章详情页 */
  static readonly ARTICLE_DETAIL: string = 'ArticleDetailPage';
  /** 登录页 */
  static readonly LOGIN: string = 'LoginPage';
  /** 个人主页 */
  static readonly PROFILE: string = 'ProfilePage';
  /** 设置页 */
  static readonly SETTINGS: string = 'SettingsPage';
}

/** 问题详情页参数 */
export interface QuestionDetailParams {
  /** 问题 ID，对应 Android 端 Question.id */
  questionId: string;
  /** 问题标题（用于详情页顶部立即展示，避免请求未返回时空白） */
  previewTitle?: string;
}

/** 回答详情页参数 */
export interface AnswerDetailParams {
  /** 回答 ID */
  answerId: string;
  /** 所属问题 ID（可选，用于返回栈和关联推荐） */
  questionId?: string;
}

/** 文章详情页参数 */
export interface ArticleDetailParams {
  /** 文章 ID */
  articleId: string;
}

/** 个人主页参数（其他用户主页时使用） */
export interface ProfileParams {
  /** 用户 url_token 或 zhihu uid */
  userToken: string;
  /** 是否为自己（用于决定显示设置入口） */
  isSelf?: boolean;
}

/** 登录页参数 */
export interface LoginParams {
  /** 登录完成后的回退目标路由名（默认回退到上一页） */
  fallbackRoute?: string;
}

/**
 * 路由参数联合类型。
 *
 * NavPathStack.pushPath 接收 BaseNavName 或具名参数对象；
 * 在 NavDestination 内部通过 parameters 字段拿到对应类型。
 *
 * 注意：不含 Record<string, string>，避免 ArkTS 严格模式下联合类型 + Record
 * 触发 "object literal type" 错误。所有具体参数类型已覆盖。
 */
export type RouteParams =
  | QuestionDetailParams
  | AnswerDetailParams
  | ArticleDetailParams
  | ProfileParams
  | LoginParams;

/** 路由栈项的统一结构，供自定义工具函数使用 */
export interface RouteStackEntry {
  name: string;
  params?: RouteParams;
}
