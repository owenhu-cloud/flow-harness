# multi-model 任务拆解

R3：5 个 change，各自 worktree、独立可用、依赖有序（C1→其余）。每条任务可独立验证。
验证底座：`skills/_lint/skill-lint.sh`（结构门）+ `skills/cross-verify/references/external-agent.test.sh`（派发行为门）+ 真实 codex 派发一次（新鲜证据）。

## Change 1 — 派发底座 + 适配器层 + 结构 lint（D / F / D7）｜基础，其余依赖它

- [ ] 1.1 写 `skills/cross-verify/references/external-agent.sh`：暴露 `healthcheck <adapter>` 与 `dispatch <adapter> <prompt-file> <out-file>`；codex 分支用 `codex exec --sandbox read-only --skip-git-repo-check -c model_reasoning_effort=... "$p" </dev/null`；超时包裹；codex 缺失/未登录→退出码 3（降级信号）。
      — 验证方式：`sh external-agent.test.sh` 全绿（见 1.3）
- [ ] 1.2 把 `references/adapters.md` 重构为可插拔接口：定义适配器需实现的 `dispatch`/`healthcheck` 两契约 + `codex-mcp`、`codex-cli` 两节 + 「接新模型」扩展点；删除与脚本重复的内联命令，改为指向 `external-agent.sh`。
      — 验证方式：`sh skill-lint.sh cross-verify` 通过「referenced 文件存在」检查（external-agent.sh 被 adapters.md 引用且存在）
- [ ] 1.3 写 `skills/cross-verify/references/external-agent.test.sh`：①codex 在场时 `healthcheck codex-cli`=0；②`PATH=` 抹掉 codex 后 healthcheck 返回降级码 3；③`dispatch` 喂含 bug 的代码样本，断言 out-file 非空且含级别标记（Critical/Major/严重/major）。
      — 验证方式：`sh external-agent.test.sh; echo $?` = 0
- [ ] 1.4 写 `skills/_lint/skill-lint.sh`：参数为技能名或 `--all`；校验 `name`==目录名、行为类技能含「铁律/危险信号/checklist/红线」小节、SKILL.md 内引用的 `references/*` 文件存在；任一不满足 exit 1。
      — 验证方式：`sh skill-lint.sh --all; echo $?` = 0（对全部现有技能）
- [ ] 1.5 真实端到端冒烟：用 `external-agent.sh dispatch codex-cli` 对一段并发 bug 代码派发一次。
      — 验证方式：out-file 含正确并发问题（map 无锁写），贴新鲜输出

## Change 2 — 跨模型证伪闭环 + 纪律升级（A / E）｜依赖 C1

- [ ] 2.1 重写 `skills/cross-verify/SKILL.md`：从「咨询升级」改为「多轮闭环」——build→`external-agent.sh` 派发→结构化裁决摄取→回 builder 修→再轮，直至无 Critical 或显式接受；保留铁律「异模型才算 cross」「opt-in+降级显式」「完成仍回 verify」。
      — 验证方式：`sh skill-lint.sh cross-verify` = 0，且正文含「多轮/闭环」与结构化裁决摄取段
- [ ] 2.2 在 `skills/implement/SKILL.md` verifier 段把「builder≠verifier」补强为「builder 模型 ≠ verifier 模型（异模型可用时）+ 角色轮换」，并指向 cross-verify 的闭环。
      — 验证方式：`sh skill-lint.sh implement` = 0；`grep -q '模型 ≠.*模型' implement/SKILL.md`
- [ ] 2.3 在 `skills/flow/SKILL.md` 质量红线 §2「权责分离」补一行「异模型可用时，verifier 应为不同模型；审前抹除 implementer framing」。
      — 验证方式：`grep -q '不同模型' flow/SKILL.md`；`sh skill-lint.sh flow` = 0

## Change 3 — 跨模型决策门（B）｜依赖 C1

- [ ] 3.1 在 `skills/plan/SKILL.md` 收尾段（人类 gate 前）增「跨模型对抗审计划」可选步：经 `external-agent.sh` 把 `design.md` 喂 Codex，指令「挑出设计缺陷/漏掉的风险/更优替代」，结构化回传，纳入 Decisions/Risks 复核。
      — 验证方式：`grep -q 'cross-verify\|external-agent' plan/SKILL.md`；`sh skill-lint.sh plan` = 0
- [ ] 3.2 在 `skills/brainstorm/SKILL.md` 增「可选：跨模型二意见」指针（方向分歧大时派 Codex 给独立视角），明确不替代用户拍板。
      — 验证方式：`sh skill-lint.sh brainstorm` = 0；正文含「跨模型」指针

## Change 4 — 跨模型并行执行器 cross-execute（C，R3，默认关闭）｜依赖 C1

- [x] 4.1 新建 `skills/cross-execute/SKILL.md`：opt-in（`docs/flow/cross-execute` 在场才启用）；把明确子任务经 `external-agent.sh`（workspace-write 沙箱变体）派给 Codex 在 git worktree 执行；含铁律（worktree 强制隔离、≤3 并行、每子任务可独立验证、Claude 必审 diff 不盲信）、危险信号、「何时别用」段、checklist。
      — 验证方式：`sh skill-lint.sh cross-execute` = 0 ✓
- [x] 4.2 在 `external-agent.sh` 增 `dispatch-write` 分支（`--sandbox workspace-write` + worktree cwd；脚本层隔离守护：只许 linked git worktree），并在 test.sh 加 dry-run argv/cwd/退出码断言（真实 worktree fixture，不真改文件）。
      注：实测 `codex exec` 无 `--ask-for-approval`（那是 TUI 的），exec 本就非交互 → 不传该 flag（计划文字依实际 CLI 修正）。
      — 验证方式：`sh external-agent.test.sh` 全绿（含新断言）✓ + 真实 codex 端到端冒烟（worktree 内建文件并提交、主仓未污染）✓
- [x] 4.3 在 `skills/flow/SKILL.md` 技能地图 + 按需技能段登记 `cross-execute`（R3、默认关闭）。
      — 验证方式：`grep -q 'cross-execute' flow/SKILL.md`；`sh skill-lint.sh --all` = 0 ✓

## Change 5 — 接入路由与文档（集成）｜依赖 C2/C3/C4

- [ ] 5.1 更新 `skills/flow/SKILL.md` 技能地图：cross-verify 描述改为「多模型对抗核心」，补 B/C 的入口说明。
      — 验证方式：`sh skill-lint.sh flow` = 0；技能地图含 cross-verify/cross-execute 两行
- [ ] 5.2 更新 `docs/DESIGN.md`：§6 技能数 18→20，新增「多模型」段说明 external-agent.sh 为 references 脚本（不违「无常驻 CLI」原则）、适配器层、不动 Oracle。
      — 验证方式：`grep -q 'external-agent\|多模型' DESIGN.md`；技能计数与 `ls skills/` 一致
- [ ] 5.3 更新 `README.md` 与 `docs/TEAM-OVERVIEW.md`：加「多模型对抗」能力小节，含 opt-in 用法与降级语义。
      — 验证方式：`grep -q '多模型\|cross-verify' README.md docs/TEAM-OVERVIEW.md`
- [ ] 5.4 全量回归：`sh skill-lint.sh --all`、`sh hooks/flow-oracle.test.sh`、`sh hooks/flow-hooks.test.sh`、`sh external-agent.test.sh` 全绿。
      — 验证方式：四条命令退出码全 0，贴新鲜输出
