# multi-model 多模型对抗能力套件 设计

> 把 flow-harness 从「单模型工作流」升级为「原生多模型对抗工作流」。
> Codex 为首个外部模型适配器，贯穿 verify / decide / execute 三面，统一受现有红线约束。

## Context

**为什么**：flow-harness 现为单模型工作流，关于 Codex 只有一支薄 `cross-verify`（opt-in、咨询性地把 verifier 换异模型）。目标是把多模型对抗织进 harness 骨架，成为一等能力。

**用户已确认方向（brainstorm 门）**：六支柱全要（A 跨模型证伪闭环 / B 跨模型决策门 / C 并行执行器 / D 派发底座 / E 纪律升级 / F 可插拔适配器层）；重心「先 Codex、接口留可插拔扩展口」。

**约束**：
- C1 DESIGN 原则「除三支 hook 外不引入常驻进程或命令行工具」→ 派发底座必须是 `references/` 下一次性脚本（仿现有 `verify-citations.sh` 先例），**不得**做成新 hook / 常驻 CLI。
- C2 不动 Oracle 确定性（Stop hook 保持纯命令裁决，不塞 LLM）。
- C3 技能契约 §7：metadata 仅 `name`(=目录名)+`description`；正文密集，深主题入 `references/`；行为类技能含铁律 / 危险信号 / 正反例 / checklist / 「合理化借口→规则」红线表；交接显式；**完成一律回 `verify`+Oracle，技能内不自造完成机制**。
- C4 POSIX sh、无 jq、可测（`*.test.sh` 先例）。
- C5 异模型不可用必须显式降级回同模型基线并告知——缺 Codex 时纪律不失效。

**非目标**：不把 LLM 塞进 Oracle；不实现 Codex 之外模型（只留接口）；不改 R0/R1 流程；不动 `profile`/分析类技能。

## Decisions

- **D1 多模型核心归口 `cross-verify`**：把它从「薄咨询技能」升级为「多模型对抗核心」，承载适配器接口 + 派发脚本；A/B/C 三类能力都经它派发。理由：单一归口，避免每技能各搓 bash 重复踩 stdin 挂起 / trusted-dir / 降级的坑。
- **D2 派发底座 = references 脚本** `skills/cross-verify/references/external-agent.sh`：仿 `verify-citations.sh` 先例的一次性可测脚本。封装①健康检查②codex 派发（`</dev/null` 防挂起、`--sandbox read-only`、`--skip-git-repo-check`、model/effort、超时、stdout 捕获）③结构化裁决契约④降级退出码。理由：遵 C1，不加常驻件。
- **D3 适配器可插拔**：`docs/flow/cross-verify` 单行写适配器键（`codex-cli` / `grok-cli`；旧 `codex-mcp` 别名已去除——脚本层与 codex-cli 行为相同属误导，真 MCP 是 skill 层 in-session 工具）；`adapters.md` 定义接口（`dispatch` + `healthcheck` 两函数契约）+ Codex/Grok 适配器 + 「接新模型」扩展点。理由：先 Codex 后留口（C5/重心）。
- **D4 纪律升级写进红线**：`flow` + `implement` 的「builder≠verifier」升为「builder 模型 ≠ verifier 模型（异模型可用时）+ 角色轮换 + 审前抹 implementer framing」。理由：把模型独立性钉进纪律层，不只活在一支技能里。
- **D5 决策门 B 复用 cross-verify**：`plan`（主）/`brainstorm`（可选）门增「跨模型对抗审设计 / 计划」段，经 cross-verify 派发，验证对象从 diff 换成 `design.md` / 方案文本。理由：最小新增面，不为决策门另起技能。
- **D6 并行执行器 C = 新技能 `cross-execute`（R3，默认关闭）**：把明确子任务派给 Codex 在 git worktree 执行，Claude 编排 + 审查，仿 `subagent-driven-development` 外壳。理由：执行语义与「证伪」正交，单独技能更清晰；调研警示协调成本高 → 默认 opt-in、worktree 强制、≤3 并行甜区、文档写明「何时别用」。
- **D7 结构 lint 作机器门**：新增 `skills/_lint/skill-lint.sh`，校验技能结构不变量（`name`==目录名、行为类技能含必备小节、referenced 文件存在、派发脚本通过自测）。理由：让 SKILL.md 改动也有可运行验证（契合 harness「机器门」哲学），非纯人审。

## Risks-Tradeoffs

| 风险 | 缓解 |
|---|---|
| cross-verify 升级后正文变重 | 正文留指针，多轮闭环 / 派发细节入 `references/` |
| codex 版本差异（mcp-server 子命令、flag 漂移） | 派发脚本先健康检查；不符即降级；注释指明以 `codex … --help` 为准 |
| C 执行器协调成本高、可能负收益 | 默认关闭 opt-in；worktree 强制隔离；≤3 并行；文档列「何时别用」 |
| 改红线影响所有任务完成判定 | 异模型不可用即显式降级回同模型基线（C5），纪律不因缺 Codex 失效 |
| 改动面大、跨多技能 | 拆 5 个独立 change，依赖有序；每个独立可用、可单独回滚 |

**回滚**：全部为 flow-harness 内文件改动，git 逐 change 回滚；项目侧删 `docs/flow/cross-verify` 即退回纯纪律级，插件零侵入。

## Migration

- **兼容**：未写 `docs/flow/cross-verify` 的项目零变化（现状）。已有 opt-in 文件继续有效——**但若其值是旧 `codex-mcp` 别名，需迁移为 `codex-cli`**（该别名后已从脚本层去除；`flow-doctor` 会对未知/弃用键给出警告而非误报已生效）。
- **灰度**：按 change 顺序合并，每个 change 独立可用；C（执行器）最后且默认关闭。
- **数据**：无数据迁移（纯流程文档 + 脚本）。

## Open-Questions

无（B 位置=plan 门为主、brainstorm 可选；C 默认关闭；适配器先 Codex；均在 brainstorm 已定）。
