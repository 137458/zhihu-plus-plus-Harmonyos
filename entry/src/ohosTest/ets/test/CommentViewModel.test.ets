/**
 * CommentViewModel 单元测试
 *
 * 覆盖：
 * - loadComments：首次加载首页、设置 loaded、设置 isEnd
 * - loadMore：去重追加 + 重新赋值数组（触发 @Trace）
 *
 * 关键回归用例：
 * - loadMore_reassigns_comments_array_to_trigger_trace
 *   验证 loadMore 后 comments 是新数组引用（reassign）而非原地 push。
 *   @Trace 只观察引用变化，原地 push 不会触发 UI 刷新，会导致分页加载的新评论不显示。
 *
 * 设计说明：
 * - 通过注入 MockZhihuApi（ZhihuApi 子类，重写 fetchRootComments）避免真实网络依赖
 * - 测试数据用 JSON.parse 构造脱敏对象，符合 ArkTS 严格模式约束
 */
import { describe, it, expect } from '@ohos/hypium';
import { CommentViewModel } from '../../../main/ets/viewmodel/CommentViewModel';
import { ZhihuApi, RootCommentsResult } from '../../../main/ets/api/ZhihuApi';
import { Comment, commentListFromArray } from '../../../main/ets/model/Comment';
import { Paging } from '../../../main/ets/model/Paging';
import { ApiError } from '../../../main/ets/model/ApiError';

/**
 * 评论 API mock：按调用顺序返回预置的 RootCommentsResult。
 *
 * 继承 ZhihuApi 仅用于类型兼容（CommentViewModel 接受 ZhihuApi），
 * fetchRootComments 被重写为返回内存数据，不发起真实网络请求。
 */
class MockZhihuApi extends ZhihuApi {
  private responses: RootCommentsResult[] = [];
  private callCount: number = 0;

  setResponses(responses: RootCommentsResult[]): void {
    this.responses = responses;
    this.callCount = 0;
  }

  async fetchRootComments(
    contentType: string,
    contentId: string,
    offset?: number,
    pagingNext?: string
  ): Promise<RootCommentsResult> {
    const idx: number = this.callCount;
    this.callCount++;
    if (idx >= this.responses.length) {
      throw ApiError.network('no more mock responses');
    }
    return this.responses[idx];
  }
}

/**
 * 从 JSON 数组字符串构造 Comment 列表（复用 commentListFromArray）。
 */
function commentsFromJson(jsonStr: string): Comment[] {
  const rawArr: object[] = JSON.parse(jsonStr) as object[];
  return commentListFromArray(rawArr);
}

const FIRST_PAGE_JSON: string = '[' +
  '{"id":1001,"content":"评论1","created_time":1700000000,"like_count":3,"child_comment_count":0,"author":{"id":"u1","url_token":"u1token","name":"用户一","avatar_url":"https://pic1.zhimg.com/a.jpg"},"is_author":false,"collapsed":false},' +
  '{"id":1002,"content":"评论2","created_time":1700000100,"like_count":0,"child_comment_count":1,"author":{"id":"u2","url_token":"u2token","name":"用户二","avatar_url":"https://pic1.zhimg.com/b.jpg"},"is_author":false,"collapsed":false}' +
  ']';

const SECOND_PAGE_JSON: string = '[' +
  '{"id":1003,"content":"评论3","created_time":1700000200,"like_count":1,"child_comment_count":0,"author":{"id":"u3","url_token":"u3token","name":"用户三","avatar_url":"https://pic1.zhimg.com/c.jpg"},"is_author":false,"collapsed":false},' +
  '{"id":1001,"content":"评论1重复id应去重","created_time":1700000000,"like_count":3,"child_comment_count":0,"author":{"id":"u1","url_token":"u1token","name":"用户一","avatar_url":"https://pic1.zhimg.com/a.jpg"},"is_author":false,"collapsed":false}' +
  ']';

export default function commentViewModelTest() {
  describe('CommentViewModel', () => {
    // ============ loadComments ============
    describe('loadComments', () => {
      it('loads_first_page_and_sets_loaded', 0, async () => {
        const mockApi: MockZhihuApi = new MockZhihuApi();
        const paging: Paging = { next: 'https://api.test/next2', isEnd: false };
        mockApi.setResponses([{ items: commentsFromJson(FIRST_PAGE_JSON), paging: paging }]);

        const vm: CommentViewModel = new CommentViewModel('answers', '123', mockApi);
        await vm.loadComments();

        expect(vm.loaded).assertTrue();
        expect(vm.isLoading).assertFalse();
        expect(vm.comments.length).assertEqual(2);
        expect(vm.comments[0].id).assertEqual('1001');
        expect(vm.isEnd).assertFalse();
      });

      it('skips_when_already_loaded', 0, async () => {
        const mockApi: MockZhihuApi = new MockZhihuApi();
        const paging: Paging = { next: 'https://api.test/next2', isEnd: false };
        mockApi.setResponses([{ items: commentsFromJson(FIRST_PAGE_JSON), paging: paging }]);

        const vm: CommentViewModel = new CommentViewModel('answers', '123', mockApi);
        await vm.loadComments();
        // 第二次调用应被跳过，不消耗 mock 响应
        await vm.loadComments();

        expect(vm.comments.length).assertEqual(2);
      });
    });

    // ============ loadMore（关键回归：reassign 触发 @Trace） ============
    describe('loadMore', () => {
      it('reassigns_comments_array_to_trigger_trace', 0, async () => {
        // 回归用例：loadMore 必须重新赋值 comments（新引用）以触发 @Trace。
        // 旧实现使用 this.comments.push() 原地修改，引用不变，@Trace 不触发，
        // 导致 ForEach 不刷新、新加载的评论不显示。
        const mockApi: MockZhihuApi = new MockZhihuApi();
        const firstPaging: Paging = { next: 'https://api.test/next2', isEnd: false };
        const secondPaging: Paging = { next: 'https://api.test/next3', isEnd: true };
        mockApi.setResponses([
          { items: commentsFromJson(FIRST_PAGE_JSON), paging: firstPaging },
          { items: commentsFromJson(SECOND_PAGE_JSON), paging: secondPaging }
        ]);

        const vm: CommentViewModel = new CommentViewModel('answers', '123', mockApi);
        await vm.loadComments();
        const refAfterFirstLoad: Comment[] = vm.comments;

        await vm.loadMore();

        // 关键断言：loadMore 后 comments 必须是新引用（reassign），而非原地修改
        expect(vm.comments !== refAfterFirstLoad).assertTrue();
        // 第二页 2 条，其中 1 条 id=1001 与首页重复被去重 → 共 3 条
        expect(vm.comments.length).assertEqual(3);
        expect(vm.isEnd).assertTrue();
      });

      it('dedup_skips_existing_ids', 0, async () => {
        const mockApi: MockZhihuApi = new MockZhihuApi();
        const firstPaging: Paging = { next: 'https://api.test/next2', isEnd: false };
        const secondPaging: Paging = { next: 'https://api.test/next3', isEnd: true };
        mockApi.setResponses([
          { items: commentsFromJson(FIRST_PAGE_JSON), paging: firstPaging },
          { items: commentsFromJson(SECOND_PAGE_JSON), paging: secondPaging }
        ]);

        const vm: CommentViewModel = new CommentViewModel('answers', '123', mockApi);
        await vm.loadComments();
        await vm.loadMore();

        // 收集所有 id，验证无重复
        const ids: string[] = [];
        for (let i = 0; i < vm.comments.length; i++) {
          ids.push(vm.comments[i].id);
        }
        const idSet: Set<string> = new Set(ids);
        expect(idSet.size).assertEqual(ids.length);
        // 首页的 1001 内容未被第二页的重复项覆盖
        expect(vm.comments[0].content).assertEqual('评论1');
      });

      it('skips_when_isEnd', 0, async () => {
        const mockApi: MockZhihuApi = new MockZhihuApi();
        const firstPaging: Paging = { next: 'https://api.test/next2', isEnd: true };
        mockApi.setResponses([{ items: commentsFromJson(FIRST_PAGE_JSON), paging: firstPaging }]);

        const vm: CommentViewModel = new CommentViewModel('answers', '123', mockApi);
        await vm.loadComments();
        // isEnd=true，loadMore 应直接返回
        await vm.loadMore();

        expect(vm.comments.length).assertEqual(2);
      });
    });
  });
}
