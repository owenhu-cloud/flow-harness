---
name: diagram
description: R2+ 交付物需要图时用——架构/流程/状态/数据模型，只产 Mermaid。
---

# diagram — 仅 Mermaid

## 类型映射（选错类型是最大丑因）

- 架构 → `flowchart`（分层 subgraph）
- 流程 → `sequenceDiagram`
- 状态机 → `stateDiagram`
- 数据 → `erDiagram`

## 可读约束

- 单图节点 ≤ ~12，超则拆图。
- 统一方向（TD 或 LR）。
- 关键路径用 `classDef` 高亮；连线必带标签。
- 固定一套四色 `classDef`（主/次/外部/告警），全项目复用。

产物落 `docs/`，仅供人看。遵循 `flow` 技能的质量红线。
