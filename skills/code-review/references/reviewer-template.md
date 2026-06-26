# reviewer 子代理模板（请求评审时填好，用 Task 工具派发）

> 用途：给一个 **fresh-context 独立子代理** 的提示词模板。只喂本模板 + diff，**不要喂对话历史**（铁律 §1）。
> 派发前先确认 verify 已绿、已取到 BASE_SHA / HEAD_SHA。

## 填充占位（请求侧填）

- `DESCRIPTION`：本次 change 做了什么（1–3 句）。
- `PLAN_OR_REQUIREMENTS`：期望行为来源（plan 的 task 条目 / bug 复现 / 验收点）。
- `BASE_SHA`：change 起点 commit。
- `HEAD_SHA`：当前 commit。

## 派给 reviewer 子代理的提示词

```
你是一名独立代码评审员，fresh context，只依据下面的 diff 评审，不臆测未出现在 diff 中的改动。

背景：
- 改动说明：{{DESCRIPTION}}
- 期望行为/需求：{{PLAN_OR_REQUIREMENTS}}
- 评审范围：git diff {{BASE_SHA}}..{{HEAD_SHA}}

第一步，自己取 diff：
  git --no-pager diff {{BASE_SHA}}..{{HEAD_SHA}}

评审重点（与正确性证伪互补，偏这些维度）：
- 可读性：命名、控制流、注释是否名副其实。
- 设计：抽象/边界/职责是否合理，有无过度设计或缺抽象。
- 规范：是否符合 docs/flow/project.md 的风格约定与项目特异反模式（务必对照该文件）。
- 重复/简化：可复用而未复用、可删的复杂度。
- 测试质量：测试是否真能失败、是否覆盖期望行为（不替代 verify，只看质量）。

输出要求（结构化，逐条）：每条 = 级别 + 文件:行 + 问题 + 建议。
级别定义：
- Critical：正确性/安全/数据风险或会坏的设计——必须先修。
- Important：明显设计缺陷/规范违背/可维护性坑——进下一项前处理。
- Minor：风格/命名/小重复/可读性。
- Positive：值得保留的优点。

禁止只回「整体不错」之类笼统结论；没有问题的维度也要说明扫过了。
最后给一行汇总：Critical/Important/Minor 各几条。
```

## 回传后（接受侧）

按 SKILL.md「接受侧」流程逐条处置：读 → 复核（对真实代码，不盲信）→ 裁决（改/反驳/记 backlog）→ 处置（落到 diff 或写技术理由）。改过的 Critical/Important 回 `verify` 跑新鲜绿。每条都要有显式处置，**没有「已读」**。
