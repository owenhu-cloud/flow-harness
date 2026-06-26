---
name: verify
description: 声明「完成/通过」前用（所有档位）——找出并运行项目真实的 build/test 命令，按档位跑足深度，贴出新鲜输出作为证据。手测、口头「应该没问题」不算。 · EN: before claiming done/passing (all tiers) — find & run the project's real build/test commands at the tier's depth, paste fresh output as evidence. Manual testing or "should be fine" does NOT count.
---

# verify — 完成必带证据

「完成」由**真实验证命令的新鲜输出**裁决，不由 agent 自说自话。

## 先找到项目真实的验证命令（可靠性递降）

0. **项目画像**：先看 `docs/flow/project.md`。存在即用其中已固化的 test/build/lint 命令，不重复探测（由 `profile` 维护）。不存在则按下列阶梯现场探测，并提示首个任务应先跑 `profile` 固化。若 `flow-bootstrap` 提示画像过期（清单晚于 `project.md`），先回 `profile` 更新再用其命令，别拿过期命令验证。
1. **CI 配置**（`.github/workflows/*`、`.gitlab-ci.yml`、`.circleci/` 等）——最可靠：CI 真正跑的就是验证函数，照搬它的命令。
2. **包/构建清单**（`package.json` scripts、`Makefile`、`Cargo.toml`、`pyproject.toml`、`go.mod`）。
3. **代码采样**：测试目录与命名约定、测试框架。

降级链：有 CI 用 CI；无 CI 用清单推断；无测试则退化为 `build + lint`；连构建都没有 → 明确告诉用户「该任务无法自动验证」，退回人工确认，**不静默判通过**。

## 维护 Oracle 的燃料

确定验证命令后，把能独立裁决「完成」的那条（测试 / 构建命令）写进 `docs/flow/verify-cmd`（单行）。这是 `Stop` hook Oracle（`hooks/flow-oracle.sh`）的燃料：写下它，agent 此后每次收尾都会被独立进程复核，绕不过去。命令变化时同步更新；无可自动验证命令时留空。

## 按档位跑足深度

| 档位 | 底线 |
|---|---|
| R0 | 冒烟（build / smoke） |
| R1 | 单测 |
| R2 | 单测 + 集成 |
| R3 | + 关键路径 E2E |

跑该档位对应的**完整命令集**，不取子集、不下调档位。

## 产出

验证报告：贴**新鲜的**工具输出（命令 + 退出码 + 关键日志）。失败如实记录，不粉饰。

## 红线（反合理化）

| 合理化借口 | 实际规则 |
|---|---|
| 本地手测过了就行 | 手测不是证据。完成声明须附该档位自动化命令的新鲜输出（红线 §1）。 |
| 这个档位跑单测就够了不用集成 | 底线按档位表分级：R2 含集成，R3 含 E2E，不得下调。 |
| 上一轮跑过了这轮没大改不用再跑 | 「完成/通过」声明须在同一轮附新鲜输出，不复用旧结果。 |
| 测试环境没配好先跳过这步 | 环境缺失即该档位未验证，回人工确认，不静默判通过。 |
| 跑了一部分绿了就声明通过 | 须运行档位对应的完整命令集，不取子集。 |

遵循 `flow` 技能的质量红线。
