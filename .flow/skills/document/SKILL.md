---
name: document
description: Use after an implementation converges (R1+), to produce human-facing deliverables. Never dump agent reasoning or execution logs.
version: 1
---

# document — 人类交付物（R1+）

只产**给人看**的产物，语言取 `profile.conventions.doc_lang`（默认中文）。

## 产出

- `docs/<feature>.md`：只含结论、设计取舍、关键图。
- PR body、CHANGELOG。

## 明令禁止

- agent 思考过程 / 执行流水账 / 迭代历史——那是 `runs/` 的审计数据，不是交付物（契约 §6）。
- 流水账式「我先…然后…接着…」。

继承 `.flow/skills/_contract.md`。
