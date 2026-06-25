---
name: self-test
description: Use to validate an implementation at the tier's required depth. Its commands are the source the Oracle (loop verify) runs. Active for all tiers.
version: 1
---

# self-test — 自测（Oracle 来源）

按 tier 底线分级，命令取自 `profile.yml`：

| Tier | 底线 |
|---|---|
| R0 | 冒烟（build/smoke） |
| R1 | 单测 |
| R2 | 单测 + 集成 |
| R3 | + 关键路径 E2E |

## 与 Oracle 的关系

`flow loop-start` 按 `oracle.<tier>` × `commands.*` 把这些命令拼成冻结的 `verify_command`。
你在循环内跑的自测应与之一致——这样 `<promise>` 才能被 Oracle 一次通过。

## 产出

验证报告（带新鲜工具输出，契约 §1）。失败如实记录，不粉饰。

继承 `.flow/skills/_contract.md`。
