/**
 * 回答详情内嵌的问题模型
 *
 * 对应知乎回答详情响应中的 `question` 字段，仅包含 id 和 title。
 * 与 QuestionDetail 区别：回答详情接口的 include 参数仅请求
 * `question.topics,question.author`，不返回问题的完整统计信息。
 *
 * 注意：ArkTS 严格模式下 object 类型不允许直接属性访问，
 * fromObject 中使用 as 断言到 RawAnswerDetailQuestion（所有字段可选）仅用于编译期属性访问，
 * 运行时类型安全由逐字段 typeof 校验保证。
 */

/** 知乎 API 原始回答详情内嵌问题对象的形状（snake_case，内部使用） */
interface RawAnswerDetailQuestion {
  id?: number;
  title?: string;
}

/** 回答详情内嵌的问题信息 */
export class AnswerDetailQuestion {
  /** 问题 ID */
  id: string;
  /** 问题标题 */
  title: string;

  constructor(id: string, title: string) {
    this.id = id;
    this.title = title;
  }

  /**
   * 从知乎响应对象解析回答详情内嵌的问题信息。
   *
   * 字段映射：
   * - id ← raw.id（number 或 string，统一转为 string）
   * - title ← raw.title（string）
   *
   * @param raw - 知乎 API 响应中的 question 对象
   * @returns 解析后的 AnswerDetailQuestion 实例；必填字段缺失或类型不匹配时返回 null
   */
  static fromObject(raw: object): AnswerDetailQuestion | null {
    if (raw === null || raw === undefined) {
      return null;
    }
    const data: RawAnswerDetailQuestion = raw as RawAnswerDetailQuestion;

    const title: string | undefined = data.title;
    if (typeof title !== 'string') {
      return null;
    }

    // id 在知乎 API 中可能是 number 或 string，统一转为 string
    let id: string | undefined;
    if (typeof data.id === 'number') {
      id = String(data.id);
    } else if (typeof data.id === 'string') {
      id = data.id;
    } else {
      return null;
    }

    return new AnswerDetailQuestion(id, title);
  }
}
