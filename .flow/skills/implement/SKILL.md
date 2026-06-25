---
name: implement
description: Use to write code for a change's tasks. Runs inside the L1 Oracle loop. builder writes code; an independent verifier adversarially reviews. Always active once a loop is started.
version: 1
---

# implement — 开发 + 对抗（在 L1 循环内）

两个**角色独立**的子代理，禁止合并（契约 §2）。

## builder（构建）

- 按 `changes/<id>/tasks.md` 逐项实现，TDD：先写会失败的测试，再实现到通过。
- 遵 `profile.yml` 的 `conventions` 与 `glossary`。
- **不得**改测试/断言/CI/profile 来「变绿」。

## verifier（对抗，独立子代理）

- 默认怀疑，目标是**搞坏它**：边界、并发、错误路径、隐藏假设。
- 对照 `.flow/refs/antipatterns.md`（按 `profile.antipattern_packs` 加载）扫描。
- 发现真 bug → 打回 builder；并在 `runs/<id>/lesson.candidate.md` 提议候选反模式。

## 完成 = Oracle 裁决（不是你说了算）

自测通过后发 `<promise>FLOW_DONE</promise>`。Stop hook 会**独立运行冻结的 verify 命令**：
- 通过 → 循环结束。
- 不通过 → 自动喂回失败输出 + 升维动作，继续。
- 放弃用 `<flow-abort>原因</flow-abort>`；暂停用 `<flow-pause>`。

每轮先读 `runs/<hash>/loop-history.jsonl` 与 `git diff`，避免重复死路。

继承 `.flow/skills/_contract.md`。
