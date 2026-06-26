---
name: plan
description: R2/R3 在 brainstorm 已确认方向后用——把选定方向落成可执行的设计 + 任务拆解，进门后不再发散。
---

# plan — 落方案（R2/R3）

把选定方向变为具体、可执行的设计。**不再发散**；进了 plan 还想换方向 → 退回 brainstorm，别在 plan 里偷偷重新选型。

## 前置

brainstorm 的 HARD GATE 已过（方向 + 权衡经用户确认）。否则先回 brainstorm。

## 产出（给 AI，密集可解析）

`docs/flow/<change>/design.md`，固定骨架：

```markdown
# <change> 设计
## Context        —— 为什么做、约束、非目标
## Decisions      —— 选定方案 + 关键技术决策（每条带一句理由）
## Risks-Tradeoffs—— 已知风险、取舍、回滚策略
## Migration      —— 兼容/数据/灰度（无则写「无」）
## Open-Questions —— 仍未定的点（门前须清零或显式接受）
```

`docs/flow/<change>/tasks.md`，编号 + checkbox（也同步进 `TodoWrite`）：

```markdown
- [ ] 1.1 <动词开头、单一职责、路径明确> — 验证方式：<怎么知道这条做完了>
- [ ] 1.2 ...
```

任务分解纪律：**小、有序、可独立验证、路径明确**；后一条不依赖前一条的未落地假设；每条都能映射到一个测试或可观测结果。关键结构配 Mermaid（加载 `diagram` 技能，落 `docs/`）。

## 守护主上下文

派子代理（`Task` 工具）草拟 design/tasks 回传 artifact，**人审产物而非审议过程**。

## 收尾 → 门 → 实现

设计完成后设一道**人类 gate**：把 design + tasks 呈给用户确认（R2/R3 可用 plan mode 让用户批准）。Open-Questions 清零后 → 用 `Skill` 工具加载 `implement`，按 tasks 逐项 builder/verifier 推进。

遵循 `flow` 技能的质量红线。
