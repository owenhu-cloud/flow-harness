---
name: flow
description: 在动手任何工程任务前先用——判断任务复杂度档位（R0–R3），按档位决定该走多重的流程，并加载对应的 Flow 技能。涉及写代码、改配置、重构、调试、设计、修 bug、做功能时都适用。 · EN: use before ANY engineering task — judge the complexity tier (R0–R3) and route to the right process depth; applies to writing code / changing config / refactoring / debugging / design / bugfixing / building a feature.
---

# Flow — 按复杂度路由的工程工作流

Flow 是一组原生 Claude Code 技能。用 `Skill` 工具加载技能、用 `Task` 派子代理、用 `TodoWrite` 列清单、用 plan mode 设门。核心纪律：先判档、按档走流程、完成必带证据。

## 第一步永远是判档

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

判档是自评，但触及高危面时**档位有地板，不得为省流程把分打低**：

| 命中面 | 地板 |
|---|---|
| 数据库迁移 / schema 变更 / 破坏性 SQL(drop/delete/truncate) / 数据回填 | ≥ **R2** |
| 认证 / 鉴权 / 权限 / 密钥 / token | ≥ **R2** |
| CI / 发布 / 部署 / 生产数据 | ≥ **R2** |
| 支付 / 计费 / 资金 | ≥ **R2** |

`flow-reinject` hook 会在你的消息命中这些关键词时贴出地板提示。压低档位以跳门 = 违反纪律，与删测试变绿同性质。

## 技能地图（按需用 Skill 工具加载，别一次性全读）

| 技能 | 何时 | 档位 |
|---|---|---|
| `profile` | 首次进入某代码库（无 `docs/flow/project.md`），固化项目画像 | R1 R2 R3 |
| `research` | 任务新颖/不确定，需外部调研再决定（高风险升深档） | R2 R3 |
| `brainstorm` | 方向未定，先对齐再动手（**硬门**） | R2 R3 |
| `plan` | 方向已定，落成可执行设计 + 任务拆解（**门**） | R2 R3 |
| `implement` | 写代码：builder 做 + verifier 对抗，角色分离 | R1 R2 R3 |
| `verify` | 声明完成前，按档位跑真实验证命令、贴新鲜输出 | R0 R1 R2 R3 |
| `diagram` | 交付需要架构/流程/状态/数据图 | R2 R3 |
| `document` | 给人看的交付物（结论+取舍+图，非流水账） | R1 R2 R3 |
| `harvest` | 撞上学习信号（连败/移交/返工/真 bug）时沉淀经验 | R1 R2 R3 |
| `systematic-debugging` | 调试/修 bug 卡住，四阶段根因调试（无根因不提修复） | R1 R2 R3 |
| `code-review` | implement 后、交付前，派独立 reviewer 子代理评审并处理反馈 | R2 R3 |
| `cross-verify` | 高风险/高不可逆 change，把独立 verifier/reviewer 升级为**不同模型/外部 agent**（MCP/CLI，如 Codex）对抗证伪 | R2 R3 |
| `subagent-driven-development` | 一串任务逐个派 fresh 子代理 + 双评审（多任务编排外壳） | R2 R3 |
| `finishing-a-development-branch` | change 收尾：合并 / PR / 丢弃决策，先过 verify+Oracle | R1 R2 R3 |
| `codebase-analysis` | 陌生/大库先理解内部结构：只读子代理 fan-out → `docs/flow/codemap.md`（架构图+模块+入口+查找表） | R2 R3 |
| `impact-analysis` | 改前算变更波及面：依赖图+时序耦合 → 受影响文件/测试范围，喂 plan/verify | R2 R3 |
| `tech-debt-audit` | 评健康度/定技术债热点：git churn×complexity，每条发现强制 `file:line` | R2 R3 |
| `writing-skills` | 要新增/修改一支 Flow 技能 | — |

技能之间靠正文里的「下一步去 X 技能」显式交接。每支技能只在被加载时进主上下文，主线程保持干净。

**按需技能（不改判档，卡到/到点才插入）**：调试卡住 → `systematic-debugging`；交付前要独立评审 → `code-review`（与 implement 的对抗 verifier 互补）；高风险面想用异模型增强独立性 → `cross-verify`（把 verifier/reviewer 的执行者换成不同模型/外部 agent）；R2/R3 一串任务要逐个隔离派发 → `subagent-driven-development`；change 收尾合并/PR/丢弃 → `finishing-a-development-branch`。

**分析类（理解优先于动手，多在 plan 前）**：陌生/大库先 `codebase-analysis` 画内部结构图；改前用 `impact-analysis` 算波及面定测试范围；要系统性盘技术债用 `tech-debt-audit`。三者只读、只产结构化制品，不测命令（那是 `profile`）、不查外网（那是 `research`）。

**已折叠（不另设技能，避免重叠）**：规格澄清 / spec-clarify → `brainstorm` 的苏格拉底澄清；架构 / 设计评估 → `plan` 的 Decisions/Risks-Tradeoffs + `document`；安全审查 → Claude Code 原生 `/security-review` 命令；深度调研 → `research` 的「深档」。

## 质量红线（所有技能共享，不靠自律靠纪律）

### 1. 诚实 · 反 reward-hacking
- 禁止删/弱化测试、改断言来「变绿」。挂了就是没过，改实现不改测试。
- 不确定显式标注，未验证的结论标「未验证」，禁编造。
- **完成必带证据**：任何「完成/通过」声明，须在同一轮附**新鲜的** build/test 工具输出。说「应该没问题」不算完成。

### 2. 权责分离
- **builder ≠ verifier**：实现的子代理不得改测试 / 断言 / CI 配置来让自己通过。
- 验证由独立视角给出——派一个对抗性 verifier 子代理，默认怀疑。
- **异模型可用时，verifier 应为不同模型**（盲点不重叠）：项目配了 `cross-verify` 适配器即做到 builder 模型 ≠ verifier 模型，并在喂裁决前抹除 implementer framing；多 change 间轮换谁建谁验。
- 涉及测试 / CI / 权限 / 发布的变更 → 停下说明，不静默执行。

### 3. 对抗
- 「实现完成」≠「通过」。任何实现都要被独立 verifier 证伪。
- verifier 专攻边界、并发、错误路径、隐藏假设；对照 `implement/references/antipatterns.md` 扫反模式。

### 4. 主动与穷尽
- R0/R1 先做后问；R2/R3 在门处先问后做。
- 修一个 bug → 顺手查同文件/同模块的同类 bug，别只补眼前这一处。

### 5. 产物纪律
- 给人的交付物（`docs/`、PR、CHANGELOG）只含结论、取舍、图。
- **禁止把执行流水账当文档交付**——「我先…然后…接着…」是过程，不是产物。

## 卡住时升维（同一问题连续失败才触发，不在第一次）

> 调试卡住优先**用 `Skill` 工具加载 `systematic-debugging`** 做四阶段根因调试（无根因不提修复）；下表是其压缩版升维阶梯，供主线程快速参照。

| 连败次数 | 动作 |
|---|---|
| 1 | 仔细重读上一次的错误输出。 |
| 2 | 换眼：换一个**根本不同**的分析视角，别在同一思路上调参。 |
| 3 | 升维：搜完整错误 + 读相关源码，列 **3 个根本不同的假设**逐一验证。 |
| 4 | 归零：抛弃已有假设，构造**最小复现**，重列 3 个新假设。 |
| 5+ | 移交：做隔离 PoC / 换技术栈；仍卡 → 质疑需求本身，结构化移交人类。 |

同一批文件被连续多轮修改却不收敛 → 强制回到根因，提一个 180° 反向假设。

## 机器级硬门控（独立 Oracle，已内置）

完成不靠 agent 自说自话：Flow 自带 `Stop` hook Oracle（`hooks/flow-oracle.sh`）。一旦项目里存在 `docs/flow/verify-cmd`（由 `profile`/`verify` 写入），agent 每次试图收尾时，该 hook 都会以**独立进程**跑这条命令裁决，非 0 退出即打回失败输出、阻止收尾——这是 agent 无法绕过的机器级门控。

接入方式：首次进入项目用 `profile` 探测并写 `docs/flow/verify-cmd`。未写则 Oracle 放行（零侵入），完成判定退回纪律级（红线 + verify 技能）。需要更强的外部循环时仍可叠加 `/pua:pua-loop` 等，与本 Oracle 正交。
