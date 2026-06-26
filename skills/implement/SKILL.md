---
name: implement
description: 给一个 change 写代码时用（R1+）——builder 做实现、独立的 verifier 子代理对抗证伪，两个角色不得合并。 · EN: write code for a change (R1+) — builder implements, an independent verifier subagent adversarially falsifies; the two roles must not be merged.
---

# implement — 开发 + 对抗

两个**角色独立**的子代理，禁止合并（红线 §2）。用 `Task` 工具把 builder 与 verifier 分派给不同子代理。

动手前先读 `docs/flow/project.md`（项目画像）：用其中固化的命令、风格约定与**项目特异反模式**，别套通用规范。无画像 → 先用 `profile` 固化（治一刀切）。

## builder（构建）

- 按 `tasks.md` 逐项实现，TDD：**先写会失败的测试，再实现到通过**。
- 遵项目既有的命名/风格约定——以 `project.md` 的「风格约定」为准，再看周围代码，不自创。
- **不得**改测试/断言/CI 配置来「变绿」。

## verifier（对抗，独立子代理）

- 默认怀疑，目标是**搞坏它**：边界、并发、错误路径、隐藏假设。
- 对照 `references/antipatterns.md`（按项目语言取分区）**+ `project.md` 的项目特异反模式**双重扫描。
- 发现真 bug → 打回 builder；并把它记成一条候选经验，交给 `harvest`。

## 完成 = verify 通过 + 证据（不是你说了算）

builder 自测通过后，**加载 `verify` 技能**按档位跑真实验证命令，并在同一轮贴出**新鲜输出**。没有新鲜的通过输出，就不是完成（红线 §1）。

**完成声明须可核实角色分离**：附上独立 verifier 子代理的结论——它**扫了什么**（边界 / 并发 / 错误路径 / 对照的反模式分区）+ **裁决**（发现的真 bug，或"无发现"）。只说"verifier 看过了"不算；没有可审计的 verifier 结论，等于没做对抗（红线 §2/§3）。hook 无法内省子代理是否真跑——靠这条可审计要求兜底。

每轮动手前先 `git diff` + 看 `TodoWrite` 进度，避免重复死路。连续失败时按 `flow` 技能的「升维」表换思路，别原地调参。

## 红线（反合理化）

> 违反规则字面 = 违反规则精神。任何「我遵守了精神」的解释不成立。

| 合理化借口 | 实际规则 |
|---|---|
| 这改动很小不用写测试 | 改动大小不改变 TDD：先写会失败的测试，再实现到通过。 |
| 测试挂了先注释掉/skip 让进度往前 | 禁止注释/skip/弱化测试。挂了就是未通过，修实现而非改测试（红线 §1）。 |
| builder 顺手改下断言让它过 | builder 不得改测试/断言/CI。改断言属 verifier 域，违反权责分离（红线 §2）。 |
| verifier 没找到问题就算通过 | 通过由真实 verify 命令的新鲜输出裁决，不由「没找到」推定。 |
| 这个 bug 不在本次 task 范围内先放着 | 修一个 bug 时顺手查同文件/同模块同类 bug（红线 §4）。 |
| verifier 我 builder 顺便扮一下就行 | builder 与 verifier 必须是不同子代理；完成声明须附 verifier 的独立结论（扫了什么+裁决），不可自演（红线 §2）。 |

完成后 → R1+ 加载 `document` 出交付物；撞上学习信号则加载 `harvest`。

遵循 `flow` 技能的质量红线。
