# 技能地图（完整版）

> `flow/SKILL.md` 路由器只列核心路径技能。本文件是完整地图，按需加载。
> 技能之间靠正文里的「下一步去 X 技能」显式交接。每支技能只在被加载时进主上下文，主线程保持干净。

| 技能 | 何时 | 档位 |
|---|---|---|
| `profile` | 首次进入某代码库（无 `docs/flow/project.md`），固化项目画像 | R1 R2 R3 |
| `research` | 任务新颖/不确定，需外部调研再决定（高风险升深档） | R2 R3 |
| `brainstorm` | 方向未定，先对齐再动手（**硬门**） | R2 R3 |
| `plan` | 方向已定，落成可执行设计 + 任务拆解（**门**） | R2 R3 |
| `implement` | 写代码：builder 做 + verifier 对抗，角色分离 | R1 R2 R3 |
| `verify` | 声明完成前，按档位跑真实验证命令、贴新鲜输出 | R0 R1 R2 R3 |
| `flow-doctor` | 想知道「这个项目里 Flow 什么在真生效、什么只是纪律」时体检 Oracle/B3/B4/cross 接入态与外部 agent 健康 | R0 R1 R2 R3 |
| `diagram` | 交付需要架构/流程/状态/数据图 | R2 R3 |
| `document` | 给人看的交付物（结论+取舍+图，非流水账） | R1 R2 R3 |
| `harvest` | 撞上学习信号（连败/移交/返工/真 bug）时沉淀经验 | R1 R2 R3 |
| `systematic-debugging` | 调试/修 bug 卡住，四阶段根因调试（无根因不提修复） | R1 R2 R3 |
| `code-review` | implement 后、交付前，派独立 reviewer 子代理评审并处理反馈 | R2 R3 |
| `cross-verify` | 高风险/高不可逆 change，把独立 verifier/reviewer 升级为**不同模型/外部 agent**（MCP/CLI，如 Codex）对抗证伪 | R2 R3 |
| `cross-execute` | 一串明确、可独立验证的子任务，派**异模型（Codex）在隔离 worktree** 执行、Claude 审 diff（默认关闭，`docs/flow/cross-execute` 在场才启用） | R3 |
| `subagent-driven-development` | 一串任务逐个派 fresh 子代理 + 双评审（多任务编排外壳） | R2 R3 |
| `finishing-a-development-branch` | change 收尾：合并 / PR / 丢弃决策，先过 verify+Oracle | R1 R2 R3 |
| `codebase-analysis` | 陌生/大库先理解内部结构：只读子代理 fan-out → `docs/flow/codemap.md`（架构图+模块+入口+查找表） | R2 R3 |
| `impact-analysis` | 改前算变更波及面：依赖图+时序耦合 → 受影响文件/测试范围，喂 plan/verify | R2 R3 |
| `tech-debt-audit` | 评健康度/定技术债热点：git churn×complexity，每条发现强制 `file:line` | R2 R3 |
| `writing-skills` | 要新增/修改一支 Flow 技能 | — |

**按需技能（不改判档，卡到/到点才插入）**：调试卡住 → `systematic-debugging`；交付前要独立评审 → `code-review`（与 implement 的对抗 verifier 互补）；高风险面想用异模型增强独立性 → `cross-verify`（把 verifier/reviewer 的执行者换成不同模型/外部 agent）；R2/R3 一串任务要逐个隔离派发 → `subagent-driven-development`（R3 且想把执行交给**异模型在隔离 worktree** 跑、Claude 退到审 diff 位 → `cross-execute`，默认关闭、opt-in）；change 收尾合并/PR/丢弃 → `finishing-a-development-branch`。

**分析类（理解优先于动手，多在 plan 前）**：陌生/大库先 `codebase-analysis` 画内部结构图；改前用 `impact-analysis` 算波及面定测试范围；要系统性盘技术债用 `tech-debt-audit`。三者只读、只产结构化制品，不测命令（那是 `profile`）、不查外网（那是 `research`）。

**已折叠（不另设技能，避免重叠）**：规格澄清 / spec-clarify → `brainstorm` 的苏格拉底澄清；架构 / 设计评估 → `plan` 的 Decisions/Risks-Tradeoffs + `document`；安全审查 → Claude Code 原生 `/security-review` 命令；深度调研 → `research` 的「深档」。
