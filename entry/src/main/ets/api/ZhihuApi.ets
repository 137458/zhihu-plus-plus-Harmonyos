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

export class ZhihuApi {
  private client: NetworkClient;
  private cookieJar: CookieJar;

  constructor() {
    this.client = new NetworkClient();
    this.cookieJar = CookieJar.getInstance();
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
      throw ApiError.parseError('response is not valid JSON');
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
      throw ApiError.parseError('response is not valid JSON');
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
      throw ApiError.parseError('response is not valid JSON');
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

/** 知乎热搜 API 原始响应顶层形状（snake_case，内部使用） */
interface RawHotSearchResponse {
  data?: object;
}

/** 知乎热搜 API 的 $.data 对象形状（snake_case，内部使用） */
interface RawHotSearchData {
  hot?: object[];
}
