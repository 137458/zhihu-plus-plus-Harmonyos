/**
 * 知乎 API 封装层
 *
 * 提供：
 * - fetchHomeRecommend(pagingNext?): 获取首页推荐信息流
 * - search(query, pagingNext?): 搜索接口（需登录，未登录返回 401）
 * - fetchHotSearch(): 热搜榜单
 * - 内部组装 zse 签名头、Cookie、include 参数
 * - 识别风控响应（非 JsonObject 或缺 $.data 抛 ApiError）
 * - 解析失败的条目跳过，不影响其他条目展示
 *
 * 注意：ArkTS 严格模式下 object 类型不允许直接属性访问，
 * parseHomeRecommendResponse / parseSearchResponse / parseHotSearchResponse
 * 中使用 as 断言到 Raw*Response（字段可选）仅用于编译期属性访问，
 * 运行时类型安全由 Array.isArray + 逐字段 typeof 保证。
 */

import { NetworkClient, HttpResponse, GetRequestOptions } from './NetworkClient';
import { CookieJar } from './CookieJar';
import { createZse96Header } from './ZseSigner';
import { FeedCard } from '../model/FeedCard';
import { SearchResultItem } from '../model/SearchResult';
import { HotSearchItem } from '../model/HotSearch';
import { Paging, parsePaging } from '../model/Paging';
import { ApiError } from '../model/ApiError';
import { QuestionDetail } from '../model/QuestionDetail';
import { AnswerDetail } from '../model/AnswerDetail';
import { ArticleDetail } from '../model/ArticleDetail';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'ZhihuApi';

/** 首页推荐列表结果 */
export interface FeedListResult {
  /** 已解析的卡片列表 */
  items: FeedCard[];
  /** 分页信息；null 表示无法解析或无分页 */
  paging: Paging | null;
}

/** 搜索列表结果 */
export interface SearchListResult {
  /** 已解析的搜索结果列表 */
  items: SearchResultItem[];
  /** 分页信息；null 表示无法解析或无分页 */
  paging: Paging | null;
}

/** 知乎 API 基础 URL（首页推荐走 api 子域） */
const ZHIHU_API_BASE: string = 'https://api.zhihu.com';
/** 首页推荐接口路径 */
const TOPSTORY_RECOMMEND_PATH: string = '/topstory/recommend';
/** 搜索/热搜接口基础 URL（www 子域） */
const ZHIHU_WWW_BASE: string = 'https://www.zhihu.com';
/** 搜索接口路径 */
const SEARCH_V3_PATH: string = '/api/v4/search_v3';
/** 热搜接口路径 */
const HOT_SEARCH_PATH: string = '/api/v4/search/hot_search';
/** zse 签名版本号 */
const ZSE93_VERSION: string = '101_3_3.0';
/** 单页拉取条数 */
const PAGE_LIMIT: number = 10;
/** 搜索结果单页条数 */
const SEARCH_PAGE_LIMIT: number = 10;
/**
 * include 参数（参考 Web 端实际请求，控制返回字段以减少流量）
 * 列出 FeedCard 解析所需的所有字段
 */
const INCLUDE_FIELDS: string = 'data[.(target.type|target.id|target.question.id|target.question.title|target.excerpt|target.author.name|target.author.headline|target.author.avatar_url|target.author.url_token|target.thumbnail|target.voteup_count|target.comment_count|target.vote_count|target.like_count|target.excerpt_title)]';

/** 问题详情接口路径 */
const QUESTION_DETAIL_PATH: string = '/api/v4/questions';
/** 回答详情接口路径 */
const ANSWER_DETAIL_PATH: string = '/api/v4/answers';
/** 文章详情接口路径 */
const ARTICLE_DETAIL_PATH: string = '/api/v4/articles';
/** 问题回答列表接口路径后缀（拼接到 QUESTION_DETAIL_PATH 之后） */
const QUESTION_FEEDS_SUFFIX: string = '/feeds';
/** 问题回答列表单页条数 */
const QUESTION_FEEDS_PAGE_LIMIT: number = 20;
/**
 * 问题详情 include 参数（逐字来自证据 03 §3，控制返回字段以减少流量）
 * 来源：docs/evidence/03-content-detail.md 问题详情行
 */
const QUESTION_DETAIL_INCLUDE: string = 'read_count,visit_count,answer_count,voteup_count,comment_count,follower_count,detail,excerpt,author,relationship.is_following,topics';
/**
 * 回答详情 include 参数（逐字来自证据 03 §3，控制返回字段以减少流量）
 * 来源：docs/evidence/03-content-detail.md 回答详情行
 */
const ANSWER_DETAIL_INCLUDE: string = '.settings,content,editable_content,paid_info,can_comment,excerpt,thanks_count,voteup_count,comment_count,visited_count,attachment,reaction,ip_info,pagination_info,endorsements,question.topics,question.author,reaction.relation.voting,author.badge_v2,settings.table_of_contents.enabled';
/**
 * 文章详情 include 参数（逐字来自证据 03 §3，控制返回字段以减少流量）
 * 来源：docs/evidence/03-content-detail.md 文章详情行
 */
const ARTICLE_DETAIL_INCLUDE: string = 'content,topics,paid_info,can_comment,excerpt,thanks_count,voteup_count,comment_count,visited_count,relationship,ip_info,relationship.vote,author.badge_v2';
/** 详情接口使用的 Web 端 User-Agent（来自 PRD 第 3 批 Slice 1） */
const ZHIHU_WEB_UA: string = 'Mozilla/5.0 (X11; U; Linux x86_64; en-US) AppleWebKit/540.0 (KHTML, like Gecko) Ubuntu/10.10 Chrome/9.1.0.0 Safari/540.0';

export class ZhihuApi {
  private client: NetworkClient;
  private cookieJar: CookieJar;

  constructor() {
    this.client = new NetworkClient();
    this.cookieJar = CookieJar.getInstance();
  }

  /**
   * 创建 rebuildHeaders 回调，用于 NetworkClient 401 重试时重建请求头。
   *
   * 401 重试时 CookieJar 可能已更新（token 刷新），但原始 headers 中的
   * x-zse-96 和 Cookie 字段已过期，需要基于当前 CookieJar 状态重建。
   *
   * @param url 请求 URL（用于重建 zse 签名）
   * @param baseHeaders 原始请求头（保留常量字段，覆盖动态字段）
   * @returns rebuildHeaders 回调
   */
  private makeRebuildHeaders(url: string, baseHeaders: Record<string, string>): () => Record<string, string> {
    return () => {
      const dc0: string | undefined = this.cookieJar.getDc0();
      const dc0Value: string = dc0 !== undefined ? dc0 : '';
      const zse96: string = createZse96Header(ZSE93_VERSION, url, dc0Value);
      const cookieHeader: string = this.cookieJar.buildCookieHeader();
      // 从 baseHeaders 复制常量字段，覆盖动态字段
      const newHeaders: Record<string, string> = {};
      const entries: [string, string][] = Object.entries(baseHeaders);
      for (let i = 0; i < entries.length; i++) {
        const entry: [string, string] = entries[i];
        newHeaders[entry[0]] = entry[1];
      }
      newHeaders['x-zse-96'] = zse96;
      newHeaders['x-zse-93'] = ZSE93_VERSION;
      if (cookieHeader.length > 0) {
        newHeaders['Cookie'] = cookieHeader;
      }
      return newHeaders;
    };
  }

  /**
   * 获取首页推荐信息流。
   *
   * @param pagingNext 下一页 URL（来自上次响应的 paging.next）；首次请求不传
   * @returns 解析后的 FeedCard 列表和分页信息
   * @throws ApiError 网络错误、超时、HTTP 错误码、风控拦截、解析失败
   */
  async fetchHomeRecommend(pagingNext?: string): Promise<FeedListResult> {
    const url: string = this.buildHomeRecommendUrl(pagingNext);
    const dc0: string | undefined = this.cookieJar.getDc0();
    const dc0Value: string = dc0 !== undefined ? dc0 : '';
    const zse96: string = createZse96Header(ZSE93_VERSION, url, dc0Value);
    const cookieHeader: string = this.cookieJar.buildCookieHeader();

    const headers: Record<string, string> = {
      'x-zse-96': zse96,
      'x-zse-93': ZSE93_VERSION,
      'Accept': 'application/json, text/plain, */*'
    };
    if (cookieHeader.length > 0) {
      headers['Cookie'] = cookieHeader;
    }

    const options: GetRequestOptions = {
      url: url,
      headers: headers,
      rebuildHeaders: this.makeRebuildHeaders(url, headers),
      onSetCookie: (setCookie: string) => {
        this.cookieJar.updateFromSetCookie(setCookie);
      }
    };

    hilog.info(DOMAIN, TAG, 'fetchHomeRecommend: url=%{public}s', url);
    const res: HttpResponse = await this.client.get(options);
    return this.parseHomeRecommendResponse(res.body);
  }

  /**
   * 构造首页推荐请求 URL。
   *
   * - 后续请求：直接使用 paging.next（已包含 query 参数）
   * - 首次请求：拼接基础 URL + path + include + limit
   *
   * @param pagingNext 下一页 URL；不传或为空则构造首次请求 URL
   */
  private buildHomeRecommendUrl(pagingNext?: string): string {
    if (pagingNext !== undefined && pagingNext.length > 0) {
      return pagingNext;
    }
    return ZHIHU_API_BASE + TOPSTORY_RECOMMEND_PATH
      + '?include=' + encodeURIComponent(INCLUDE_FIELDS)
      + '&limit=' + PAGE_LIMIT.toString();
  }

  /**
   * 解析首页推荐响应。
   *
   * 风控判定：
   * - 响应体为空 → PARSE_ERROR
   * - JSON 解析失败 → PARSE_ERROR
   * - 响应缺 $.data 字段或非数组 → RISK_CONTROL（疑似风控页/HTML 响应）
   *
   * 解析规则：
   * - 遍历 $.data 数组，每项调用 FeedCard.fromObject
   * - 解析失败的单项跳过，不影响其他条目
   * - 从 $.paging 提取分页信息
   */
  private parseHomeRecommendResponse(body: string): FeedListResult {
    if (body === null || body.length === 0) {
      throw ApiError.parseError('empty response body');
    }

    let raw: object;
    try {
      raw = JSON.parse(body);
    } catch (e) {
      throw ApiError.parseError('response is not valid JSON', e instanceof Error ? e : undefined);
    }

    const root: RawFeedResponse = raw as RawFeedResponse;
    const data: object[] | undefined = root.data;
    if (data === undefined || !Array.isArray(data)) {
      // 缺 $.data 字段或非数组，疑似风控响应（HTML 页或重定向）
      throw ApiError.riskControl('response missing $.data (likely risk control)');
    }

    const items: FeedCard[] = [];
    for (let i = 0; i < data.length; i++) {
      const card: FeedCard | null = FeedCard.fromObject(data[i]);
      if (card !== null) {
        items.push(card);
      }
      // 解析失败的单项跳过，不影响其他条目
    }

    let paging: Paging | null = null;
    const rawPaging: object | undefined = root.paging;
    if (rawPaging !== undefined) {
      paging = parsePaging(rawPaging);
    }

    hilog.info(DOMAIN, TAG, 'parseHomeRecommendResponse: items=%{public}d paging=%{public}s',
      items.length, `${paging !== null}`);
    const result: FeedListResult = {
      items: items,
      paging: paging
    };
    return result;
  }

  /**
   * 搜索接口。
   *
   * 调用 https://www.zhihu.com/api/v4/search_v3，要求登录态
   * （未登录会返回 401，由上层 NetworkClient 转 ApiError.unauthorized）。
   *
   * @param query 搜索词（必填，内部会 encodeURIComponent）
   * @param pagingNext 下一页 URL（来自上次响应的 paging.next）；首次请求不传
   * @returns 解析后的 SearchResultItem 列表和分页信息
   * @throws ApiError 网络错误、超时、HTTP 错误码（含 401）、风控拦截、解析失败
   */
  async search(query: string, pagingNext?: string): Promise<SearchListResult> {
    const url: string = this.buildSearchUrl(query, pagingNext);
    const dc0: string | undefined = this.cookieJar.getDc0();
    const dc0Value: string = dc0 !== undefined ? dc0 : '';
    const zse96: string = createZse96Header(ZSE93_VERSION, url, dc0Value);
    const cookieHeader: string = this.cookieJar.buildCookieHeader();

    const headers: Record<string, string> = {
      'x-zse-96': zse96,
      'x-zse-93': ZSE93_VERSION,
      'Accept': 'application/json, text/plain, */*'
    };
    if (cookieHeader.length > 0) {
      headers['Cookie'] = cookieHeader;
    }

    const options: GetRequestOptions = {
      url: url,
      headers: headers,
      rebuildHeaders: this.makeRebuildHeaders(url, headers),
      onSetCookie: (setCookie: string) => {
        this.cookieJar.updateFromSetCookie(setCookie);
      }
    };

    hilog.info(DOMAIN, TAG, 'search: query=%{public}s url=%{public}s', query, url);
    const res: HttpResponse = await this.client.get(options);
    return this.parseSearchResponse(res.body);
  }

  /**
   * 构造搜索请求 URL。
   *
   * - 后续请求：直接使用 paging.next（已包含 query 参数与 offset）
   * - 首次请求：拼接 www.zhihu.com/api/v4/search_v3 + t/general + q + correction + offset/limit
   *
   * @param query 搜索词
   * @param pagingNext 下一页 URL；不传或为空则构造首次请求 URL
   */
  private buildSearchUrl(query: string, pagingNext?: string): string {
    if (pagingNext !== undefined && pagingNext.length > 0) {
      return pagingNext;
    }
    return ZHIHU_WWW_BASE + SEARCH_V3_PATH
      + '?t=general'
      + '&q=' + encodeURIComponent(query)
      + '&correction=1'
      + '&offset=0'
      + '&limit=' + SEARCH_PAGE_LIMIT.toString();
  }

  /**
   * 解析搜索响应。
   *
   * 风控判定：
   * - 响应体为空 → PARSE_ERROR
   * - JSON 解析失败 → PARSE_ERROR
   * - 响应缺 $.data 字段或非数组 → RISK_CONTROL（疑似风控页/HTML 响应）
   *
   * 解析规则：
   * - 遍历 $.data 数组，每项调用 SearchResultItem.fromObject
   * - 解析失败的单项跳过，不影响其他条目
   * - 从 $.paging 提取分页信息
   */
  private parseSearchResponse(body: string): SearchListResult {
    if (body === null || body.length === 0) {
      throw ApiError.parseError('empty response body');
    }

    let raw: object;
    try {
      raw = JSON.parse(body);
    } catch (e) {
      throw ApiError.parseError('response is not valid JSON', e instanceof Error ? e : undefined);
    }

    const root: RawSearchResponse = raw as RawSearchResponse;
    const data: object[] | undefined = root.data;
    if (data === undefined || !Array.isArray(data)) {
      // 缺 $.data 字段或非数组，疑似风控响应（HTML 页或重定向）
      throw ApiError.riskControl('response missing $.data (likely risk control)');
    }

    const items: SearchResultItem[] = [];
    for (let i = 0; i < data.length; i++) {
      const item: SearchResultItem | null = SearchResultItem.fromObject(data[i]);
      if (item !== null) {
        items.push(item);
      }
      // 解析失败的单项跳过，不影响其他条目
    }

    let paging: Paging | null = null;
    const rawPaging: object | undefined = root.paging;
    if (rawPaging !== undefined) {
      paging = parsePaging(rawPaging);
    }

    hilog.info(DOMAIN, TAG, 'parseSearchResponse: items=%{public}d paging=%{public}s',
      items.length, `${paging !== null}`);
    const result: SearchListResult = {
      items: items,
      paging: paging
    };
    return result;
  }

  /**
   * 热搜榜单接口。
   *
   * 调用 https://www.zhihu.com/api/v4/search/hot_search，取 $.data.hot 数组。
   *
   * @returns 解析后的 HotSearchItem 列表（过滤 null 后）
   * @throws ApiError 网络错误、超时、HTTP 错误码、风控拦截、解析失败
   */
  async fetchHotSearch(): Promise<HotSearchItem[]> {
    const url: string = ZHIHU_WWW_BASE + HOT_SEARCH_PATH;
    const dc0: string | undefined = this.cookieJar.getDc0();
    const dc0Value: string = dc0 !== undefined ? dc0 : '';
    const zse96: string = createZse96Header(ZSE93_VERSION, url, dc0Value);
    const cookieHeader: string = this.cookieJar.buildCookieHeader();

    const headers: Record<string, string> = {
      'x-zse-96': zse96,
      'x-zse-93': ZSE93_VERSION,
      'Accept': 'application/json, text/plain, */*'
    };
    if (cookieHeader.length > 0) {
      headers['Cookie'] = cookieHeader;
    }

    const options: GetRequestOptions = {
      url: url,
      headers: headers,
      rebuildHeaders: this.makeRebuildHeaders(url, headers),
      onSetCookie: (setCookie: string) => {
        this.cookieJar.updateFromSetCookie(setCookie);
      }
    };

    hilog.info(DOMAIN, TAG, 'fetchHotSearch: url=%{public}s', url);
    const res: HttpResponse = await this.client.get(options);
    return this.parseHotSearchResponse(res.body);
  }

  /**
   * 解析热搜响应。
   *
   * 风控判定：
   * - 响应体为空 → PARSE_ERROR
   * - JSON 解析失败 → PARSE_ERROR
   * - 响应缺 $.data.hot 字段或非数组 → RISK_CONTROL
   *
   * 解析规则：
   * - 遍历 $.data.hot 数组，每项调用 HotSearchItem.fromObject
   * - 解析失败的单项跳过（过滤 null）
   */
  private parseHotSearchResponse(body: string): HotSearchItem[] {
    if (body === null || body.length === 0) {
      throw ApiError.parseError('empty response body');
    }

    let raw: object;
    try {
      raw = JSON.parse(body);
    } catch (e) {
      throw ApiError.parseError('response is not valid JSON', e instanceof Error ? e : undefined);
    }

    const root: RawHotSearchResponse = raw as RawHotSearchResponse;
    const dataField: object | undefined = root.data;
    if (dataField === undefined) {
      throw ApiError.riskControl('response missing $.data (likely risk control)');
    }
    const dataTyped: RawHotSearchData = dataField as RawHotSearchData;
    const hot: object[] | undefined = dataTyped.hot;
    if (hot === undefined || !Array.isArray(hot)) {
      throw ApiError.riskControl('response missing $.data.hot (likely risk control)');
    }

    const items: HotSearchItem[] = [];
    for (let i = 0; i < hot.length; i++) {
      const item: HotSearchItem | null = HotSearchItem.fromObject(hot[i]);
      if (item !== null) {
        items.push(item);
      }
      // 解析失败的单项跳过，不影响其他条目
    }

    hilog.info(DOMAIN, TAG, 'parseHotSearchResponse: items=%{public}d', items.length);
    return items;
  }

  /**
   * 获取问题详情。
   *
   * 调用 https://www.zhihu.com/api/v4/questions/{questionId}?include=...，
   * 需要 d_c0 Cookie（未登录可读，关注需登录）。
   *
   * @param questionId 问题 ID
   * @returns 解析后的问题详情
   * @throws ApiError 网络错误、超时、HTTP 错误码、风控拦截、解析失败
   */
  async fetchQuestionDetail(questionId: string): Promise<QuestionDetail> {
    const url: string = ZHIHU_WWW_BASE + QUESTION_DETAIL_PATH + '/' + questionId
      + '?include=' + encodeURIComponent(QUESTION_DETAIL_INCLUDE);
    const dc0: string | undefined = this.cookieJar.getDc0();
    const dc0Value: string = dc0 !== undefined ? dc0 : '';
    const zse96: string = createZse96Header(ZSE93_VERSION, url, dc0Value);
    const cookieHeader: string = this.cookieJar.buildCookieHeader();

    const headers: Record<string, string> = {
      'x-zse-96': zse96,
      'x-zse-93': ZSE93_VERSION,
      'User-Agent': ZHIHU_WEB_UA,
      'x-requested-with': 'fetch',
      'Accept': 'application/json, text/plain, */*'
    };
    if (cookieHeader.length > 0) {
      headers['Cookie'] = cookieHeader;
    }

    const options: GetRequestOptions = {
      url: url,
      headers: headers,
      rebuildHeaders: this.makeRebuildHeaders(url, headers),
      onSetCookie: (setCookie: string) => {
        this.cookieJar.updateFromSetCookie(setCookie);
      }
    };

    hilog.info(DOMAIN, TAG, 'fetchQuestionDetail: questionId=%{public}s', questionId);
    const res: HttpResponse = await this.client.get(options);
    return this.parseQuestionDetailResponse(res.body);
  }

  /**
   * 解析问题详情响应。
   *
   * 风控判定：
   * - 响应体为空 → PARSE_ERROR
   * - JSON 解析失败 → PARSE_ERROR
   * - 调用 QuestionDetail.fromObject 返回 null → RISK_CONTROL
   *   （疑似风控页/HTML 响应导致字段缺失）
   *
   * 注意：详情响应是单个对象，不像首页推荐的 data[] 数组。
   * 直接对 root 调用 fromObject。
   */
  private parseQuestionDetailResponse(body: string): QuestionDetail {
    if (body === null || body.length === 0) {
      throw ApiError.parseError('empty response body');
    }

    let raw: object;
    try {
      raw = JSON.parse(body);
    } catch (e) {
      throw ApiError.parseError('response is not valid JSON', e instanceof Error ? e : undefined);
    }

    const detail: QuestionDetail | null = QuestionDetail.fromObject(raw);
    if (detail === null) {
      // 响应解析为 null，疑似风控响应（HTML 页或字段缺失）
      throw ApiError.riskControl('question detail fromObject returned null (likely risk control)');
    }

    hilog.info(DOMAIN, TAG, 'parseQuestionDetailResponse: id=%{public}s', detail.id);
    return detail;
  }

  /**
   * 获取回答详情。
   *
   * 调用 https://www.zhihu.com/api/v4/answers/{answerId}?include=...，
   * 需要 d_c0 Cookie。
   *
   * @param answerId 回答 ID
   * @returns 解析后的回答详情
   * @throws ApiError 网络错误、超时、HTTP 错误码、风控拦截、解析失败
   */
  async fetchAnswerDetail(answerId: string): Promise<AnswerDetail> {
    const url: string = ZHIHU_WWW_BASE + ANSWER_DETAIL_PATH + '/' + answerId
      + '?include=' + encodeURIComponent(ANSWER_DETAIL_INCLUDE);
    const dc0: string | undefined = this.cookieJar.getDc0();
    const dc0Value: string = dc0 !== undefined ? dc0 : '';
    const zse96: string = createZse96Header(ZSE93_VERSION, url, dc0Value);
    const cookieHeader: string = this.cookieJar.buildCookieHeader();

    const headers: Record<string, string> = {
      'x-zse-96': zse96,
      'x-zse-93': ZSE93_VERSION,
      'User-Agent': ZHIHU_WEB_UA,
      'x-requested-with': 'fetch',
      'Accept': 'application/json, text/plain, */*'
    };
    if (cookieHeader.length > 0) {
      headers['Cookie'] = cookieHeader;
    }

    const options: GetRequestOptions = {
      url: url,
      headers: headers,
      rebuildHeaders: this.makeRebuildHeaders(url, headers),
      onSetCookie: (setCookie: string) => {
        this.cookieJar.updateFromSetCookie(setCookie);
      }
    };

    hilog.info(DOMAIN, TAG, 'fetchAnswerDetail: answerId=%{public}s', answerId);
    const res: HttpResponse = await this.client.get(options);
    return this.parseAnswerDetailResponse(res.body);
  }

  /**
   * 解析回答详情响应。
   *
   * 风控判定：
   * - 响应体为空 → PARSE_ERROR
   * - JSON 解析失败 → PARSE_ERROR
   * - 调用 AnswerDetail.fromObject 返回 null → RISK_CONTROL
   *   （疑似风控页/HTML 响应导致字段缺失）
   *
   * 注意：详情响应是单个对象，不像首页推荐的 data[] 数组。
   * 直接对 root 调用 fromObject。
   */
  private parseAnswerDetailResponse(body: string): AnswerDetail {
    if (body === null || body.length === 0) {
      throw ApiError.parseError('empty response body');
    }

    let raw: object;
    try {
      raw = JSON.parse(body);
    } catch (e) {
      throw ApiError.parseError('response is not valid JSON', e instanceof Error ? e : undefined);
    }

    const detail: AnswerDetail | null = AnswerDetail.fromObject(raw);
    if (detail === null) {
      // 响应解析为 null，疑似风控响应（HTML 页或字段缺失）
      throw ApiError.riskControl('answer detail fromObject returned null (likely risk control)');
    }

    hilog.info(DOMAIN, TAG, 'parseAnswerDetailResponse: id=%{public}s', detail.id);
    return detail;
  }

  /**
   * 获取问题下的回答列表（feeds）。
   *
   * 调用 https://www.zhihu.com/api/v4/questions/{questionId}/feeds?limit=20&order=default，
   * 返回与首页推荐相同结构的 Feed 列表（data[] + paging）。
   *
   * @param questionId 问题 ID
   * @param pagingNext 下一页 URL（来自上次响应的 paging.next）；首次请求不传
   * @param order 排序方式：'default'（默认）或 'updated'（按更新时间）
   * @returns 解析后的 FeedCard 列表和分页信息
   * @throws ApiError 网络错误、超时、HTTP 错误码、风控拦截、解析失败
   */
  async fetchQuestionAnswers(
    questionId: string,
    pagingNext?: string,
    order?: string
  ): Promise<FeedListResult> {
    const url: string = this.buildQuestionAnswersUrl(questionId, pagingNext, order);
    const dc0: string | undefined = this.cookieJar.getDc0();
    const dc0Value: string = dc0 !== undefined ? dc0 : '';
    const zse96: string = createZse96Header(ZSE93_VERSION, url, dc0Value);
    const cookieHeader: string = this.cookieJar.buildCookieHeader();

    const headers: Record<string, string> = {
      'x-zse-96': zse96,
      'x-zse-93': ZSE93_VERSION,
      'User-Agent': ZHIHU_WEB_UA,
      'x-requested-with': 'fetch',
      'Accept': 'application/json, text/plain, */*'
    };
    if (cookieHeader.length > 0) {
      headers['Cookie'] = cookieHeader;
    }

    const options: GetRequestOptions = {
      url: url,
      headers: headers,
      rebuildHeaders: this.makeRebuildHeaders(url, headers),
      onSetCookie: (setCookie: string) => {
        this.cookieJar.updateFromSetCookie(setCookie);
      }
    };

    hilog.info(DOMAIN, TAG, 'fetchQuestionAnswers: questionId=%{public}s', questionId);
    const res: HttpResponse = await this.client.get(options);
    return this.parseQuestionAnswersResponse(res.body);
  }

  /**
   * 构造问题回答列表请求 URL。
   *
   * - 后续请求：直接使用 paging.next（已包含 query 参数）
   * - 首次请求：拼接 /api/v4/questions/{id}/feeds?limit=20&order={order}
   *
   * @param questionId 问题 ID
   * @param pagingNext 下一页 URL；不传或为空则构造首次请求 URL
   * @param order 排序方式；不传默认 'default'
   */
  private buildQuestionAnswersUrl(questionId: string, pagingNext?: string, order?: string): string {
    if (pagingNext !== undefined && pagingNext.length > 0) {
      return pagingNext;
    }
    const orderValue: string = order !== undefined && order.length > 0 ? order : 'default';
    return ZHIHU_WWW_BASE + QUESTION_DETAIL_PATH + '/' + questionId + QUESTION_FEEDS_SUFFIX
      + '?limit=' + QUESTION_FEEDS_PAGE_LIMIT.toString()
      + '&order=' + orderValue;
  }

  /**
   * 解析问题回答列表响应。
   *
   * 风控判定：
   * - 响应体为空 → PARSE_ERROR
   * - JSON 解析失败 → PARSE_ERROR
   * - 响应缺 $.data 字段或非数组 → RISK_CONTROL（疑似风控页/HTML 响应）
   *
   * 解析规则：
   * - 遍历 $.data 数组，每项调用 FeedCard.fromObject
   * - 解析失败的单项跳过，不影响其他条目
   * - 从 $.paging 提取分页信息
   */
  private parseQuestionAnswersResponse(body: string): FeedListResult {
    if (body === null || body.length === 0) {
      throw ApiError.parseError('empty response body');
    }

    let raw: object;
    try {
      raw = JSON.parse(body);
    } catch (e) {
      throw ApiError.parseError('response is not valid JSON', e instanceof Error ? e : undefined);
    }

    const root: RawQuestionFeedsResponse = raw as RawQuestionFeedsResponse;
    const data: object[] | undefined = root.data;
    if (data === undefined || !Array.isArray(data)) {
      // 缺 $.data 字段或非数组，疑似风控响应（HTML 页或重定向）
      throw ApiError.riskControl('response missing $.data (likely risk control)');
    }

    const items: FeedCard[] = [];
    for (let i = 0; i < data.length; i++) {
      const card: FeedCard | null = FeedCard.fromObject(data[i]);
      if (card !== null) {
        items.push(card);
      }
      // 解析失败的单项跳过，不影响其他条目
    }

    let paging: Paging | null = null;
    const rawPaging: object | undefined = root.paging;
    if (rawPaging !== undefined) {
      paging = parsePaging(rawPaging);
    }

    hilog.info(DOMAIN, TAG, 'parseQuestionAnswersResponse: items=%{public}d paging=%{public}s',
      items.length, `${paging !== null}`);
    const result: FeedListResult = {
      items: items,
      paging: paging
    };
    return result;
  }

  /**
   * 获取文章详情。
   *
   * 调用 https://www.zhihu.com/api/v4/articles/{articleId}?include=...，
   * 需要 d_c0 Cookie。
   *
   * @param articleId 文章 ID
   * @returns 解析后的文章详情
   * @throws ApiError 网络错误、超时、HTTP 错误码、风控拦截、解析失败
   */
  async fetchArticleDetail(articleId: string): Promise<ArticleDetail> {
    const url: string = ZHIHU_WWW_BASE + ARTICLE_DETAIL_PATH + '/' + articleId
      + '?include=' + encodeURIComponent(ARTICLE_DETAIL_INCLUDE);
    const dc0: string | undefined = this.cookieJar.getDc0();
    const dc0Value: string = dc0 !== undefined ? dc0 : '';
    const zse96: string = createZse96Header(ZSE93_VERSION, url, dc0Value);
    const cookieHeader: string = this.cookieJar.buildCookieHeader();

    const headers: Record<string, string> = {
      'x-zse-96': zse96,
      'x-zse-93': ZSE93_VERSION,
      'User-Agent': ZHIHU_WEB_UA,
      'x-requested-with': 'fetch',
      'Accept': 'application/json, text/plain, */*'
    };
    if (cookieHeader.length > 0) {
      headers['Cookie'] = cookieHeader;
    }

    const options: GetRequestOptions = {
      url: url,
      headers: headers,
      rebuildHeaders: this.makeRebuildHeaders(url, headers),
      onSetCookie: (setCookie: string) => {
        this.cookieJar.updateFromSetCookie(setCookie);
      }
    };

    hilog.info(DOMAIN, TAG, 'fetchArticleDetail: articleId=%{public}s', articleId);
    const res: HttpResponse = await this.client.get(options);
    return this.parseArticleDetailResponse(res.body);
  }

  /**
   * 解析文章详情响应。
   *
   * 风控判定：
   * - 响应体为空 → PARSE_ERROR
   * - JSON 解析失败 → PARSE_ERROR
   * - 调用 ArticleDetail.fromObject 返回 null → RISK_CONTROL
   *   （疑似风控页/HTML 响应导致字段缺失）
   *
   * 注意：详情响应是单个对象，不像首页推荐的 data[] 数组。
   * 直接对 root 调用 fromObject。
   */
  private parseArticleDetailResponse(body: string): ArticleDetail {
    if (body === null || body.length === 0) {
      throw ApiError.parseError('empty response body');
    }

    let raw: object;
    try {
      raw = JSON.parse(body);
    } catch (e) {
      throw ApiError.parseError('response is not valid JSON', e instanceof Error ? e : undefined);
    }

    const detail: ArticleDetail | null = ArticleDetail.fromObject(raw);
    if (detail === null) {
      // 响应解析为 null，疑似风控响应（HTML 页或字段缺失）
      throw ApiError.riskControl('article detail fromObject returned null (likely risk control)');
    }

    hilog.info(DOMAIN, TAG, 'parseArticleDetailResponse: id=%{public}s', detail.id);
    return detail;
  }
}

/** 知乎首页推荐 API 原始响应形状（snake_case，内部使用） */
interface RawFeedResponse {
  data?: object[];
  paging?: object;
}

/** 知乎搜索 API 原始响应形状（snake_case，内部使用） */
interface RawSearchResponse {
  data?: object[];
  paging?: object;
}

/** 知乎问题回答列表 API 原始响应形状（snake_case，内部使用） */
interface RawQuestionFeedsResponse {
  data?: object[];
  paging?: object;
}

/** 知乎热搜 API 原始响应顶层形状（snake_case，内部使用） */
interface RawHotSearchResponse {
  data?: object;
}

/** 知乎热搜 API 的 $.data 对象形状（snake_case，内部使用） */
interface RawHotSearchData {
  hot?: object[];
}
