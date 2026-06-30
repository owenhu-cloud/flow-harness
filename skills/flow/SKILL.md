---
name: flow
description: 在动手任何工程任务前先用——判断任务复杂度档位（R0–R3），按档位决定该走多重的流程，并加载对应的 Flow 技能。涉及写代码、改配置、重构、调试、设计、修 bug、做功能时都适用。 · EN: use before ANY engineering task — judge the complexity tier (R0–R3) and route to the right process depth; applies to writing code / changing config / refactoring / debugging / design / bugfixing / building a feature.
---

# Flow — 按复杂度路由的工程工作流（路由器）

Flow 是一组原生 Claude Code 技能。用 `Skill` 加载技能、`Task` 派子代理、`TodoWrite` 列清单、plan mode 设门。核心纪律：**先判档、按档走流程、完成必带证据**。

**本文件是极短路由器**：判档 → 选流程 → 加载技能。完整技能地图、质量红线全文、升维阶梯、Oracle 细节都在 `references/`，**按需加载，别一次性吞**。

## 第零步：意图契约（所有档位，动手改文件前）

判档之前先做一件最便宜的事——**用四行复述你对任务的理解**，把误解暴露在动手之前（这是治"指令理解"的针对性结构，不是仪式）：

```
Intent: <一句话，这次到底要达成什么>
Constraints: <硬约束：性能/兼容/接口/期限，或 none>
Non-goals: <这次明确不做什么>
Verify-signal: <可观测的完成信号：一条命令 / 测试 selector / 可见行为>
```

R0 可脑内确认 + 一句话声明；R1+ 让用户可见。**有阻塞性歧义先问一个具体问题再动手**，别替用户默默选。Stop Oracle 的「意图契约门」会在「本会话改了文件却全程无 agent 正文产出过 `Intent:` 锚」时打回（机器为**行级近似**：只认 assistant text 块里的 `Intent:`，混行 text+tool_use 且 Intent 仅在 payload 时会漏放，四行完整性靠纪律；仅 `verify-cmd` 在场的项目；`docs/flow/intent-gate-off` 可关）。

## 第一步：判档

收到工程任务，先用四维 rubric 判一次档（**每个任务判一次**，同一任务后续消息沿用，别反复横跳）：

| 维度 | 0 | 1 | 2 | 3 |
|---|---|---|---|---|
| 影响面 | 单文件 | 单模块 | 多模块 | 跨系统 |
| 不可逆性 | 一键回滚 | 易回滚 | 难回滚 | 不可逆 / 动生产数据 |
| 未知度 | 完全已知 | 小不确定 | 需调研 | 需全新方案 |
| 风险 | 无副作用 | 内部副作用 | 外部副作用 | 安全 / 数据 / 合规 |

四维各 0–3 求和 → 档位：

| 总分 | 档位 | 流程 |
|---|---|---|
| 0–1 | **R0** 直执 | implement → verify(冒烟)。先做后问。 |
| 2–4 | **R1** 轻流程 | （脑内对齐）→ implement(TDD) → verify(单测) → 一句话交付。 |
| 5–8 | **R2** 标准 | research(若新)→ brainstorm(门)→ plan(门)→ implement(builder/verifier 对抗)→ verify(单测+集成)→ document → harvest(若触发)。 |
| 9–12 | **R3** 项目 | 同 R2，但拆多个 change、各自 worktree、双门把关、顶层编排子代理。 |

判完用一句话告诉用户：「这是 R2（影响面2/不可逆1/未知2/风险2=7），走 brainstorm→plan→门→implement→verify→document」。然后**用 `Skill` 工具加载第一支流程技能**，别凭记忆复述步骤。

**覆盖标记**（用户消息里出现即生效）：`#R0`..`#R3` 强制档位 · `#skip-flow` 本次不走 Flow · `#new` 对当前任务重新判档。

### 档位地板（敏感面不得自评压低）

判档是自评，但触及高危面时**档位有地板，不得为省流程把分打低**（压低跳门 = 与删测试变绿同性质）：

| 命中面 | 地板 |
|---|---|
| 数据库迁移 / schema 变更 / 破坏性 SQL(drop/delete/truncate) / 数据回填 | ≥ **R2** |
| 认证 / 鉴权 / 权限 / 密钥 / token | ≥ **R2** |
| CI / 发布 / 部署 / 生产数据 | ≥ **R2** |
| 支付 / 计费 / 资金 | ≥ **R2** |

`flow-reinject` hook 会在消息命中这些关键词时贴出地板提示。

## 选流程后加载技能

核心路径技能（按需用 `Skill` 加载，**别一次性全读**）：`profile`(首入库画像) · `research`(新颖/不确定·高风险升深档) · `brainstorm`(方向未定·硬门) · `plan`(设计+任务拆解·门) · `implement`(builder+verifier 对抗) · `verify`(完成前·真实命令+新鲜输出) · `document`(人看的交付物) · `systematic-debugging`(调试卡住·四阶段) · `code-review`(交付前独立评审) · `cross-verify`(高风险·异模型证伪) · `harvest`(撞学习信号沉淀)。

**完整技能地图**（含分析类 `codebase-analysis`/`impact-analysis`/`tech-debt-audit`、收尾 `finishing-a-development-branch`、`diagram`、`flow-doctor`、多任务 `subagent-driven-development`/`cross-execute`、元 `writing-skills`、及「已折叠」说明）→ `references/skill-map.md`。

**判档后别只判不加载**：按档位真的用 `Skill` 工具加载对应流程技能（R1+ 写码 `implement`、收尾 `verify`；R2/R3 先 `brainstorm`/`plan`），别凭记忆走方法论——Stop Oracle 的「流程技能使用门」会在「本会话改了文件却整程没加载过任何流程技能」时打回（`docs/flow/skill-gate-off` 可关）。

技能间靠正文「下一步去 X 技能」显式交接；每支只在加载时进上下文，主线程保持干净。

## 质量红线（所有技能共享，不靠自律靠纪律 · 全文见 `references/redlines.md`）

1. **诚实/反 reward-hacking**：禁删/弱化测试或改断言「变绿」；**完成必带同轮新鲜 build/test 输出**；未验证的结论标「未验证」，禁编造。
2. **权责分离**：**builder ≠ verifier**（实现者不得改测试/断言/CI）；异模型可用时 verifier 用不同模型；动测试/CI/权限/发布停下说明。
3. **对抗**：「实现完成」≠「通过」，必被独立 verifier 证伪（专攻边界/并发/错误路径/隐藏假设）。
4. **主动穷尽**：R0/R1 先做后问、R2/R3 门处先问后做；修一处缺陷顺查同文件/同模块同类。
5. **产物纪律**：交付物只含结论+取舍+图；**执行流水账不当文档交付**。

## 卡住升维 · 机器门控

- **升维**：同一问题**连续失败才**升维（不在第一次）→ 优先 `Skill` 加载 `systematic-debugging` 四阶段根因调试；速查阶梯 → `references/escalation.md`。
- **机器门控**：完成由 `Stop` hook 独立 Oracle 裁决，但**仅当 `docs/flow/verify-cmd` 在场**才生效（非 0 退出即打回、阻止收尾）；未写则 Oracle 放行、退回纪律级。装了插件 ≠ Oracle 在守，拿不准用 `flow-doctor` 体检。完整说明（含威胁模型边界）→ `references/oracle.md`。
