# Flow

按复杂度路由的工程工作流，以原生 Claude Code 技能实现。

Flow 在执行任何工程任务前先对其复杂度评级（R0–R3），据此选择相应深度的流程：低复杂度任务直接执行，高复杂度任务依次经过方向对齐、设计、对抗实现、验证与交付。所有能力以技能（`SKILL.md`）形式提供，由 agent 通过原生 `Skill` / `Task` / `TodoWrite` / plan mode 调度；三支 hook 提供机制兜底，其中独立 Oracle 在「完成」声明处做机器级裁决。

- **详细架构与技术方案** → [`docs/DESIGN.md`](docs/DESIGN.md)
- **面向用户的使用手册** → [`docs/MANUAL.md`](docs/MANUAL.md)

## 设计目标

Flow 针对 Claude Code 项目级开发的常见失效，各落一条机制，并补上多数框架忽视的「完成由独立 Oracle 裁决」。

| 失效 | 机制 |
|---|---|
| 流程靠人记得触发，注意力一漂质量就掉 | 路由纪律由 hook 每轮重注入，不随上下文增长被埋没 |
| 大量技能与仪式常驻主上下文 | 技能正文按需加载；重活派子代理、只回传蒸馏结论 |
| 完成自说自话、删测试「变绿」 | 完成由独立进程跑真实命令裁决，并扫 git diff 防弱化测试 |
| happy-path 全绿即判完成、异常即崩 | 异常路径覆盖升为机器门（opt-in）：B3 健壮性门（接入后异常路径测试挂、或其通过数跌破基线即打回）+ B4 覆盖率门（覆盖率命令失败、或覆盖率跌破地板即打回） |
| 简单需求过度设计、复杂需求拆错缝 | 按复杂度+SOLID 选切口：简单直接做不套模式，复杂沿 SRP/DIP 拆（五问提取过程），反两头作弊 |
| 通用流程不懂「这个项目」 | 项目画像把命令、风格、反模式特化到代码库 |
| 踩过的坑散落各次会话 | 学习信号蒸馏成可复用经验，写入项目 `lessons/` / `CLAUDE.md` |
| 判档可被压低以跳流程 | 触及敏感面（迁移/认证/支付/生产数据…）时档位有地板 |
| 同模型自审看不见自己的盲点 | 高风险面把 verifier/方案评审升为**异模型**（Codex/Grok），plan 期对方案做跨模型审 |

## 安装

```
/plugin marketplace add owenhu-cloud/flow-harness
/plugin install flow@flow-harness
```

安装后无需初始化或逐项目配置。会话开始时 hook 注入路由提示，agent 在工程任务上自动评级并加载对应技能。单次跳过：消息中加入 `#skip-flow`。

## 复杂度路由

四个维度各取 0–3，求和得到档位。

| 维度 | 0 | 1 | 2 | 3 |
|---|---|---|---|---|
| 影响面 | 单文件 | 单模块 | 多模块 | 跨系统 |
| 不可逆性 | 一键回滚 | 易回滚 | 难回滚 | 不可逆 / 生产数据 |
| 未知度 | 完全已知 | 小不确定 | 需调研 | 需全新方案 |
| 风险 | 无副作用 | 内部副作用 | 外部副作用 | 安全 / 数据 / 合规 |

| 总分 | 档位 | 流程 |
|---|---|---|
| 0–1 | R0 | implement → verify（冒烟） |
| 2–4 | R1 | implement（TDD）→ verify（单测）→ 简要交付 |
| 5–8 | R2 | research（若新）→ brainstorm（门）→ plan（门）→ implement（对抗）→ verify（单测+集成）→ document |
| 9–12 | R3 | 同 R2，拆分多 change、各自 worktree、双门把关 |

覆盖标记：`#R0`–`#R3` 强制档位，`#skip-flow` 跳过，`#new` 重新评级。触及数据库迁移 / 认证授权 / 密钥 / CI 发布 / 支付 / 生产数据等敏感面时，档位有地板（≥ R2），不得为省流程压低。

## 能力总览

技能按需加载，相互通过正文里的显式交接串联。

**总路由** — `flow`（评级、流程选择、质量红线、升维、档位地板）。

**理解项目** — `profile`（命令/风格/反模式画像）· `codebase-analysis`（内部结构代码地图）· `impact-analysis`（变更波及面）· `tech-debt-audit`（健康度/技术债热点）。

**调研与对齐** — `research`（外部 fan-out 调研，浅档/深档）· `brainstorm`（方向对齐，硬门）· `plan`（可执行设计 + **按复杂度+SOLID 拆任务**（简单直接做、复杂沿 SRP/DIP 切，五问提取过程）+ **R3/高风险面默认跨模型审方案**，门）。

**实现与验证** — `implement`（builder + 独立 verifier 对抗）· `systematic-debugging`（四阶段根因调试）· `verify`（真实命令 + 新鲜证据）· `code-review`（独立 reviewer 子代理）· `cross-verify`（**多模型对抗核心**：把独立 verifier/reviewer 升级为异模型/外部 agent 如 Codex，多轮证伪闭环；亦供 plan/brainstorm 做跨模型决策门）· `subagent-driven-development`（串行单任务隔离派发）。

**体检** — `flow-doctor`（一条命令看清「这个项目里 Flow 什么在真生效、什么只是纪律」：Oracle/B3/B4/cross 接入态 + 外部 agent 健康，区分机器强制门 vs 靠自觉的纪律）。

**交付与收尾** — `diagram`（Mermaid 图）· `document`（人类交付物）· `finishing-a-development-branch`（合并/PR/丢弃决策）· `harvest`（沉淀经验）。

**元** — `writing-skills`（新增/修改技能，对流程文档套 TDD）。

### 多模型对抗（opt-in）

把「对抗证伪」这一步的执行者从同模型子代理升级为**异模型**（首个适配器 Codex），用模型异质性消除同源盲点——是对 `builder ≠ verifier` 的强化（builder 模型 ≠ verifier 模型）。

- **启用**：项目 `docs/flow/cross-verify` 写入适配器键（如 `codex-cli`、`grok-cli`）。`implement`/`code-review` 经 **change-review 模式**把对抗派给异模型；`plan` 经 **plan-review 模式**把 `design.md`+`tasks.md` 喂异模型挑设计盲点（R3/命中档位地板默认）。多轮闭环到无 Critical。
- **降级**：适配器不可用（健康检查失败）→ **显式降级回同模型基线并告知**，缺 Codex 不致纪律失效；不写该文件则零侵入。
- **派发底座**：`skills/cross-verify/references/external-agent.sh`（一次性脚本，遵「除三支 hook 外不引入常驻 CLI」，非 hook、非常驻）。
- **不接入 Oracle**：Stop hook 仍是确定性命令门，不塞 LLM。结构契约由 `skills/_lint/skill-lint.sh` 机器校验。

## 完成判定

完成由项目真实验证命令的新鲜输出裁决，分两级：

1. **纪律级** — 质量红线 + builder/verifier 角色分离，agent 自带证据声明完成。
2. **机器级** — `Stop` hook 独立 Oracle（`hooks/flow-oracle.sh`）。项目写入 `docs/flow/verify-cmd` 即接入；此后 agent 每次收尾，该 hook 以独立进程跑**七道门**裁决：

   - **A1 意图契约门** — 本会话用编辑工具改了文件、却无任何 agent 正文(text)产出过 `Intent:` 锚即打回（治「装了也不懂用户意图」）。会话级、行级近似、**fail-open**（任何歧义即放行，宁漏放不误杀）；opt-out：`docs/flow/intent-gate-off`。
   - **A2 流程技能使用门** — 本会话用编辑工具改了文件、却整程没 `Skill` 加载过任何流程技能（只加载 `flow` 判档 / `flow-doctor` 体检不算）即打回（治「判档后凭记忆走、不加载 implement/verify 等技能纪律」）。会话级、**fail-open**；opt-out：`docs/flow/skill-gate-off`。
   - **A 完整性门** — 扫 git diff，阻止靠删测试 / 注入 skip / 删断言 / 改低已提交基线「变绿」（语法层）。
   - **B 验证命令门** — 跑 verify-cmd，退出码即裁决。
   - **B2 测试数基线门** — 解析 runner 通过数，低于基线即打回（语义层，抓 grep 抓不到的测试数下降；已修 bignum 基线误判 + 收紧「换 reporter 吞摘要」绕过）。
   - **B3 健壮性门**（opt-in：`docs/flow/robustness-cmd`）— 单独跑错误路径/异常场景测试子集，非 0 或其通过数下降即打回。把异常覆盖从提示词自述升为机器门。
   - **B4 覆盖率门**（opt-in：`docs/flow/coverage-cmd` + 可选 `coverage-min`）— 覆盖率命令退出码非 0 即打回；若另设了合法 `coverage-min`（0..100 整数）且覆盖率% 可解析，低于地板亦打回。抓「删分支/删错误路径测试使覆盖率跌破地板」（首选让 coverage-cmd 自带 `--cov-fail-under`，退出码即承载地板，免依赖解析）。

   任一不过即 `exit 2` 打回失败输出、阻止收尾，agent 在该轮收尾内绕不过——**前提是写了 `verify-cmd`；未写则 Oracle 整体放行（零侵入），此时无任何机器门、退回纪律级**（用 `flow-doctor` 体检实际接入态）。可选 `docs/flow/verify-cache` 启用「自上次绿无改动即跳过」降本。

   **边界（诚实声明）**：本门防的是「压力下偷懒/reward-hacking」，提高绕过成本、留审计痕迹，**不是安全边界**——信任根（`verify-cmd`/基线/`flow-oracle.sh` 自身）在仓库内，能 commit 改它们者仍可绕，根治需带外 CI / 人审基线变更（见 [`docs/DESIGN.md`](docs/DESIGN.md) 威胁模型）。**变异测试刻意不入 Stop 门**（每次收尾跑变异分钟级、会逼用户关掉整个门）——留在 implement verifier 的 mutation 抽查 + profile 记录的 `mutation-cmd`（按需/CI 跑）。

## 质量红线

所有技能继承：① 不得删/弱化测试、改断言以「变绿」，完成声明须附同轮新鲜输出；② builder 与 verifier 为独立子代理，实现者不得改测试/断言/CI；③ 实现完成不等于通过，由独立 verifier 对抗证伪；④ R0/R1 先做后问、R2/R3 在门处先问后做，修一处缺陷顺查同类；⑤ 交付物只含结论与取舍，执行过程记录不作为交付文档。

## 目录

```
.claude-plugin/   plugin.json（hooks 自动加载，skills 自动发现）· marketplace.json
hooks/            hooks.json · flow-bootstrap.sh（SessionStart）· flow-reinject.sh（UserPromptSubmit）
                  · flow-oracle.sh（Stop·Oracle）· *.test.sh（hook 自检）
skills/<name>/    SKILL.md（按需加载）· references/（深主题外置，含示例与脚本）
docs/             DESIGN.md（技术方案）· MANUAL.md（使用手册）
```

## License

MIT
