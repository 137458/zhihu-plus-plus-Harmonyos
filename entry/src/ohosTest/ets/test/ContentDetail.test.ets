/**
 * 内容详情领域模型与缓存层单元测试
 *
 * 覆盖：
 * - Topic.fromObject：完整字段、缺 name、缺 id、无 avatarUrl
 * - AnswerDetailQuestion.fromObject：完整字段、缺 title
 * - QuestionDetail.fromObject：完整字段、风控响应（空对象）、缺 id、缺 title、缺 author、可选字段默认值
 * - AnswerDetail.fromObject：完整字段、缺 question、缺 content、空对象
 * - ArticleDetail.fromObject：完整字段、缺 title、缺 content
 * - ContentDetailCache：put 后 get 命中、未命中返回 null、TTL 过期返回 null、TTL 未过期返回数据、容量超限清空最早条目
 *
 * 测试数据用 JSON.parse 构造脱敏对象字面量，符合 ArkTS 严格模式约束。
 */

import { describe, beforeEach, it, expect } from '@ohos/hypium';
import { Topic } from '../../../main/ets/model/Topic';
import { AnswerDetailQuestion } from '../../../main/ets/model/AnswerDetailQuestion';
import { QuestionDetail } from '../../../main/ets/model/QuestionDetail';
import { AnswerDetail } from '../../../main/ets/model/AnswerDetail';
import { ArticleDetail } from '../../../main/ets/model/ArticleDetail';
import { ContentDetailCache } from '../../../main/ets/viewmodel/ContentDetailCache';

export default function contentDetailTest() {
  describe('ContentDetail', () => {
    // ============ Topic.fromObject ============
    describe('Topic.fromObject', () => {
      it('parses_full_fields', 0, () => {
        const raw: object = JSON.parse('{"id":"topic1","name":"测试话题","avatar_url":"https://pic1.zhimg.com/topic.jpg"}');
        const topic: Topic | null = Topic.fromObject(raw);
        expect(topic !== null).assertTrue();
        if (topic !== null) {
          expect(topic.id).assertEqual('topic1');
          expect(topic.name).assertEqual('测试话题');
          expect(topic.avatarUrl).assertEqual('https://pic1.zhimg.com/topic.jpg');
        }
      });

      it('returns_null_when_name_missing', 0, () => {
        const raw: object = JSON.parse('{"id":"topic1"}');
        const topic: Topic | null = Topic.fromObject(raw);
        expect(topic).assertNull();
      });

      it('returns_null_when_id_missing', 0, () => {
        const raw: object = JSON.parse('{"name":"测试话题"}');
        const topic: Topic | null = Topic.fromObject(raw);
        expect(topic).assertNull();
      });

      it('parses_without_avatar_url', 0, () => {
        const raw: object = JSON.parse('{"id":"topic1","name":"测试话题"}');
        const topic: Topic | null = Topic.fromObject(raw);
        expect(topic !== null).assertTrue();
        if (topic !== null) {
          expect(topic.id).assertEqual('topic1');
          expect(topic.name).assertEqual('测试话题');
          expect(topic.avatarUrl).assertUndefined();
        }
      });

      it('returns_null_for_null_input', 0, () => {
        const topic: Topic | null = Topic.fromObject(null as object);
        expect(topic).assertNull();
      });
    });

    // ============ AnswerDetailQuestion.fromObject ============
    describe('AnswerDetailQuestion.fromObject', () => {
      it('parses_full_fields', 0, () => {
        const raw: object = JSON.parse('{"id":12345,"title":"问题标题"}');
        const q: AnswerDetailQuestion | null = AnswerDetailQuestion.fromObject(raw);
        expect(q !== null).assertTrue();
        if (q !== null) {
          expect(q.id).assertEqual('12345');
          expect(q.title).assertEqual('问题标题');
        }
      });

      it('parses_string_id', 0, () => {
        const raw: object = JSON.parse('{"id":"abc","title":"问题标题"}');
        const q: AnswerDetailQuestion | null = AnswerDetailQuestion.fromObject(raw);
        expect(q !== null).assertTrue();
        if (q !== null) {
          expect(q.id).assertEqual('abc');
        }
      });

      it('returns_null_when_title_missing', 0, () => {
        const raw: object = JSON.parse('{"id":1}');
        const q: AnswerDetailQuestion | null = AnswerDetailQuestion.fromObject(raw);
        expect(q).assertNull();
      });

      it('returns_null_when_id_missing', 0, () => {
        const raw: object = JSON.parse('{"title":"问题"}');
        const q: AnswerDetailQuestion | null = AnswerDetailQuestion.fromObject(raw);
        expect(q).assertNull();
      });
    });

    // ============ QuestionDetail.fromObject ============
    describe('QuestionDetail.fromObject', () => {
      it('parses_full_fields', 0, () => {
        const raw: object = JSON.parse('{"id":12345,"title":"测试问题","detail":"<p>详情</p>","excerpt":"摘要","answer_count":10,"visit_count":1000,"comment_count":5,"follower_count":50,"voteup_count":100,"author":{"id":"user1","url_token":"token1","name":"作者","avatar_url":"https://pic1.zhimg.com/a.jpg"},"topics":[{"id":"t1","name":"话题1"}]}');
        const q: QuestionDetail | null = QuestionDetail.fromObject(raw);
        expect(q !== null).assertTrue();
        if (q !== null) {
          expect(q.id).assertEqual('12345');
          expect(q.title).assertEqual('测试问题');
          expect(q.detail).assertEqual('<p>详情</p>');
          expect(q.excerpt).assertEqual('摘要');
          expect(q.answerCount).assertEqual(10);
          expect(q.visitCount).assertEqual(1000);
          expect(q.commentCount).assertEqual(5);
          expect(q.followerCount).assertEqual(50);
          expect(q.voteupCount).assertEqual(100);
          expect(q.author.name).assertEqual('作者');
          expect(q.topics.length).assertEqual(1);
          if (q.topics.length > 0) {
            expect(q.topics[0].id).assertEqual('t1');
          }
        }
      });

      it('returns_null_for_empty_object_risk_control', 0, () => {
        // 风控响应（空对象）应返回 null
        const raw: object = JSON.parse('{}');
        const q: QuestionDetail | null = QuestionDetail.fromObject(raw);
        expect(q).assertNull();
      });

      it('returns_null_when_id_missing', 0, () => {
        const raw: object = JSON.parse('{"title":"测试","author":{"id":"u","url_token":"t","name":"n","avatar_url":"a"}}');
        const q: QuestionDetail | null = QuestionDetail.fromObject(raw);
        expect(q).assertNull();
      });

      it('returns_null_when_title_missing', 0, () => {
        const raw: object = JSON.parse('{"id":1,"author":{"id":"u","url_token":"t","name":"n","avatar_url":"a"}}');
        const q: QuestionDetail | null = QuestionDetail.fromObject(raw);
        expect(q).assertNull();
      });

      it('returns_null_when_author_missing', 0, () => {
        const raw: object = JSON.parse('{"id":1,"title":"测试"}');
        const q: QuestionDetail | null = QuestionDetail.fromObject(raw);
        expect(q).assertNull();
      });

      it('returns_null_when_author_invalid', 0, () => {
        // author 字段存在但内容无效
        const raw: object = JSON.parse('{"id":1,"title":"测试","author":{}}');
        const q: QuestionDetail | null = QuestionDetail.fromObject(raw);
        expect(q).assertNull();
      });

      it('uses_defaults_for_optional_fields', 0, () => {
        // 只提供必填字段，可选字段应使用默认值
        const raw: object = JSON.parse('{"id":1,"title":"测试","author":{"id":"u","url_token":"t","name":"n","avatar_url":"a"}}');
        const q: QuestionDetail | null = QuestionDetail.fromObject(raw);
        expect(q !== null).assertTrue();
        if (q !== null) {
          expect(q.detail).assertEqual('');
          expect(q.excerpt).assertEqual('');
          expect(q.answerCount).assertEqual(0);
          expect(q.visitCount).assertEqual(0);
          expect(q.commentCount).assertEqual(0);
          expect(q.followerCount).assertEqual(0);
          expect(q.voteupCount).assertEqual(0);
          expect(q.topics.length).assertEqual(0);
        }
      });

      it('filters_null_topics', 0, () => {
        // topics 数组中包含无效项，应被过滤
        const raw: object = JSON.parse('{"id":1,"title":"测试","author":{"id":"u","url_token":"t","name":"n","avatar_url":"a"},"topics":[{"id":"t1","name":"话题1"},{"name":"缺id"}]}');
        const q: QuestionDetail | null = QuestionDetail.fromObject(raw);
        expect(q !== null).assertTrue();
        if (q !== null) {
          expect(q.topics.length).assertEqual(1);
          if (q.topics.length > 0) {
            expect(q.topics[0].id).assertEqual('t1');
          }
        }
      });
    });

    // ============ AnswerDetail.fromObject ============
    describe('AnswerDetail.fromObject', () => {
      it('parses_full_fields', 0, () => {
        const raw: object = JSON.parse('{"id":67890,"content":"<p>回答正文</p>","excerpt":"回答摘要","voteup_count":50,"comment_count":3,"thanks_count":2,"author":{"id":"u","url_token":"t","name":"作者","avatar_url":"a"},"question":{"id":12345,"title":"问题"},"ip_info":"北京","created_time":1700000000,"updated_time":1700001000}');
        const a: AnswerDetail | null = AnswerDetail.fromObject(raw);
        expect(a !== null).assertTrue();
        if (a !== null) {
          expect(a.id).assertEqual('67890');
          expect(a.content).assertEqual('<p>回答正文</p>');
          expect(a.excerpt).assertEqual('回答摘要');
          expect(a.voteupCount).assertEqual(50);
          expect(a.commentCount).assertEqual(3);
          expect(a.thanksCount).assertEqual(2);
          expect(a.author.name).assertEqual('作者');
          expect(a.question.id).assertEqual('12345');
          expect(a.question.title).assertEqual('问题');
          expect(a.ipInfo).assertEqual('北京');
          expect(a.createdTime).assertEqual(1700000000);
          expect(a.updatedTime).assertEqual(1700001000);
        }
      });

      it('returns_null_when_question_missing', 0, () => {
        const raw: object = JSON.parse('{"id":1,"content":"c","author":{"id":"u","url_token":"t","name":"n","avatar_url":"a"}}');
        const a: AnswerDetail | null = AnswerDetail.fromObject(raw);
        expect(a).assertNull();
      });

      it('returns_null_when_content_missing', 0, () => {
        const raw: object = JSON.parse('{"id":1,"author":{"id":"u","url_token":"t","name":"n","avatar_url":"a"},"question":{"id":1,"title":"t"}}');
        const a: AnswerDetail | null = AnswerDetail.fromObject(raw);
        expect(a).assertNull();
      });

      it('returns_null_when_author_missing', 0, () => {
        const raw: object = JSON.parse('{"id":1,"content":"c","question":{"id":1,"title":"t"}}');
        const a: AnswerDetail | null = AnswerDetail.fromObject(raw);
        expect(a).assertNull();
      });

      it('returns_null_for_empty_object', 0, () => {
        const raw: object = JSON.parse('{}');
        const a: AnswerDetail | null = AnswerDetail.fromObject(raw);
        expect(a).assertNull();
      });

      it('uses_defaults_for_optional_fields', 0, () => {
        const raw: object = JSON.parse('{"id":1,"content":"c","author":{"id":"u","url_token":"t","name":"n","avatar_url":"a"},"question":{"id":2,"title":"t"}}');
        const a: AnswerDetail | null = AnswerDetail.fromObject(raw);
        expect(a !== null).assertTrue();
        if (a !== null) {
          expect(a.excerpt).assertEqual('');
          expect(a.voteupCount).assertEqual(0);
          expect(a.commentCount).assertEqual(0);
          expect(a.thanksCount).assertEqual(0);
          expect(a.ipInfo).assertEqual('');
          expect(a.createdTime).assertEqual(0);
          expect(a.updatedTime).assertEqual(0);
        }
      });
    });

    // ============ ArticleDetail.fromObject ============
    describe('ArticleDetail.fromObject', () => {
      it('parses_full_fields', 0, () => {
        const raw: object = JSON.parse('{"id":99999,"title":"测试文章","content":"<p>文章正文</p>","excerpt":"文章摘要","voteup_count":30,"comment_count":2,"author":{"id":"u","url_token":"t","name":"作者","avatar_url":"a"},"topics":[{"id":"t1","name":"话题"}],"ip_info":"上海","created":1700000000,"updated":1700001000}');
        const ar: ArticleDetail | null = ArticleDetail.fromObject(raw);
        expect(ar !== null).assertTrue();
        if (ar !== null) {
          expect(ar.id).assertEqual('99999');
          expect(ar.title).assertEqual('测试文章');
          expect(ar.content).assertEqual('<p>文章正文</p>');
          expect(ar.excerpt).assertEqual('文章摘要');
          expect(ar.voteupCount).assertEqual(30);
          expect(ar.commentCount).assertEqual(2);
          expect(ar.author.name).assertEqual('作者');
          expect(ar.topics.length).assertEqual(1);
          expect(ar.ipInfo).assertEqual('上海');
          expect(ar.created).assertEqual(1700000000);
          expect(ar.updated).assertEqual(1700001000);
        }
      });

      it('returns_null_when_title_missing', 0, () => {
        const raw: object = JSON.parse('{"id":1,"content":"c","author":{"id":"u","url_token":"t","name":"n","avatar_url":"a"}}');
        const ar: ArticleDetail | null = ArticleDetail.fromObject(raw);
        expect(ar).assertNull();
      });

      it('returns_null_when_content_missing', 0, () => {
        const raw: object = JSON.parse('{"id":1,"title":"t","author":{"id":"u","url_token":"t","name":"n","avatar_url":"a"}}');
        const ar: ArticleDetail | null = ArticleDetail.fromObject(raw);
        expect(ar).assertNull();
      });

      it('returns_null_when_author_missing', 0, () => {
        const raw: object = JSON.parse('{"id":1,"title":"t","content":"c"}');
        const ar: ArticleDetail | null = ArticleDetail.fromObject(raw);
        expect(ar).assertNull();
      });

      it('returns_null_for_empty_object', 0, () => {
        const raw: object = JSON.parse('{}');
        const ar: ArticleDetail | null = ArticleDetail.fromObject(raw);
        expect(ar).assertNull();
      });

      it('uses_defaults_for_optional_fields', 0, () => {
        const raw: object = JSON.parse('{"id":1,"title":"t","content":"c","author":{"id":"u","url_token":"t","name":"n","avatar_url":"a"}}');
        const ar: ArticleDetail | null = ArticleDetail.fromObject(raw);
        expect(ar !== null).assertTrue();
        if (ar !== null) {
          expect(ar.excerpt).assertEqual('');
          expect(ar.voteupCount).assertEqual(0);
          expect(ar.commentCount).assertEqual(0);
          expect(ar.topics.length).assertEqual(0);
          expect(ar.ipInfo).assertEqual('');
          expect(ar.created).assertEqual(0);
          expect(ar.updated).assertEqual(0);
        }
      });
    });

    // ============ ContentDetailCache ============
    describe('ContentDetailCache', () => {
      const cache: ContentDetailCache = ContentDetailCache.getInstance();

      beforeEach(() => {
        cache.clear();
      });

      it('put_then_get_hits', 0, () => {
        const topic: Topic = new Topic('t1', '话题', 'https://pic1.zhimg.com/topic.jpg');
        cache.put('question_123', topic);
        const got: Topic | null = cache.get<Topic>('question_123');
        expect(got !== null).assertTrue();
        if (got !== null) {
          expect(got.id).assertEqual('t1');
          expect(got.name).assertEqual('话题');
        }
      });

      it('get_misses_returns_null', 0, () => {
        const got: Topic | null = cache.get<Topic>('nonexistent_key');
        expect(got).assertNull();
      });

      it('ttl_expired_returns_null', 0, () => {
        // TTL 是 10 分钟；将 timestamp 设置为 11 分钟前，模拟过期
        const topic: Topic = new Topic('t1', '话题', 'url');
        cache.put('question_456', topic);
        const elevenMinutesAgo: number = Date.now() - 11 * 60 * 1000;
        const ok: boolean = cache.setTimestampForTest('question_456', elevenMinutesAgo);
        expect(ok).assertTrue();
        const got: Topic | null = cache.get<Topic>('question_456');
        expect(got).assertNull();
      });

      it('ttl_not_expired_returns_data', 0, () => {
        // TTL 是 10 分钟；将 timestamp 设置为 5 分钟前，未过期
        const topic: Topic = new Topic('t2', '话题2', 'url');
        cache.put('question_789', topic);
        const fiveMinutesAgo: number = Date.now() - 5 * 60 * 1000;
        cache.setTimestampForTest('question_789', fiveMinutesAgo);
        const got: Topic | null = cache.get<Topic>('question_789');
        expect(got !== null).assertTrue();
        if (got !== null) {
          expect(got.id).assertEqual('t2');
        }
      });

      it('capacity_overflow_evicts_oldest', 0, () => {
        // CACHE_MAX_SIZE = 100；put 101 个条目，第 1 个应被删除
        for (let i = 0; i < 101; i++) {
          const key: string = 'key_' + i.toString();
          const topic: Topic = new Topic('id_' + i.toString(), '话题', 'url');
          cache.put(key, topic);
        }
        // 容量应为 100
        expect(cache.size()).assertEqual(100);
        // key_0 应被删除（最早插入）
        const got0: Topic | null = cache.get<Topic>('key_0');
        expect(got0).assertNull();
        // key_100 应命中
        const got100: Topic | null = cache.get<Topic>('key_100');
        expect(got100 !== null).assertTrue();
        if (got100 !== null) {
          expect(got100.id).assertEqual('id_100');
        }
      });

      it('clear_empties_cache', 0, () => {
        const topic: Topic = new Topic('t1', '话题', 'url');
        cache.put('key_clear', topic);
        expect(cache.size()).assertEqual(1);
        cache.clear();
        expect(cache.size()).assertEqual(0);
        const got: Topic | null = cache.get<Topic>('key_clear');
        expect(got).assertNull();
      });

      it('put_overwrite_existing_key', 0, () => {
        const topic1: Topic = new Topic('t1', '话题1', 'url');
        cache.put('key_overwrite', topic1);
        const topic2: Topic = new Topic('t2', '话题2', 'url');
        cache.put('key_overwrite', topic2);
        const got: Topic | null = cache.get<Topic>('key_overwrite');
        expect(got !== null).assertTrue();
        if (got !== null) {
          expect(got.id).assertEqual('t2');
          expect(got.name).assertEqual('话题2');
        }
      });
    });
  });
}
