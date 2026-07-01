# cross-verify 适配器 —— 外部验证器接入

本文是 `cross-verify` 的深度参考：怎么把一个**外部模型 / agent** 接成对抗验证器。
SKILL.md 正文工具无关；具体工具只活在这里。

## 派发底座：`external-agent.sh`（规范实现）

具体派发**统一经本目录的 `external-agent.sh`**（一次性脚本，仿 `verify-citations.sh` 先例；遵 DESIGN「除三支 hook 外不引入常驻 CLI」）。技能不手搓 codex bash——避免重复踩 stdin 挂起 / trusted-dir / 降级的坑。两个子命令即适配器契约：

```
external-agent.sh healthcheck    <adapter>            # 可用 0 / 不可用 3（降级信号）
external-agent.sh dispatch       <adapter> <prompt-file> <out-file>   # 只读对抗验证，结果写 out-file
external-agent.sh dispatch-write <adapter> <prompt-file> <out-file> <worktree-dir>  # 写沙箱执行（cross-execute 用）
```

`dispatch-write` 是 `cross-execute`（R3、默认关闭）专用的写沙箱变体：`--sandbox workspace-write`
（`codex exec` 非交互、无审批提示），在 `<worktree-dir>`（**必须是 `git worktree add` 产生的隔离
linked worktree**，脚本会校验、拒主工作区/裸目录）内派 agent 落地子任务。退出码同 `dispatch`（0/3/1）。
`cross-verify`（只验不改）只用 `dispatch`；只有 `cross-execute`（派异模型执行）才用 `dispatch-write`。

## 适配器接口（任何外部验证器都要满足两点）

一个 cross-verifier 适配器需在 `external-agent.sh` 里实现两点：

1. **`dispatch`** —— 输入：change 描述 + diff/范围 + 期望行为 + 「对抗证伪，默认怀疑」指令（打进 prompt-file）；输出：结构化裁决（真问题/无发现 + 文件:行 + 复现/命令）写 out-file。
2. **`healthcheck`** —— 判断当前是否可用（决定启用还是降级；不可用返回 exit 3）。

满足这两点的任何外部 coding agent（提供非交互 CLI 或 MCP server 者）都能填进来。
（额外）若该适配器还想支撑 `cross-execute` 的派发执行，需在 `cmd_dispatch_write` 的 `case` 也加一支：与 `dispatch` 同构，但用该 agent 的**写沙箱 + 非交互**子命令、并在传入的 worktree cwd 内执行。只做 `cross-verify` 则无需实现它。

## 项目 opt-in：`docs/flow/cross-verify`

单行声明本项目启用的**一个**适配器键（单行单适配器；要并用多个则在本文件追加新适配器节、由派发侧择一），例如：

```
codex-cli
```

> 命名说明：脚本层适配器键统一 `codex-cli` / `grok-cli`。历史上的 `codex-mcp` 已去除——它在脚本层与 `codex-cli` 行为完全相同（都走本地 `codex exec`），属误导。「真正的 MCP」指 agent 在会话内直接调用 Codex 的 `codex`/`codex-reply` MCP 工具（见下「适配器 1」），那是 skill 层行为、不经派发脚本，与 opt-in 键无关。

- **存在且非空** → `cross-verify` 启用，用该适配器派发。
- **缺失 / 空** → 未启用，`implement`/`code-review` 走同模型 `Task` verifier 基线（零侵入）。
- 适配器不可用（健康检查失败）→ 降级回同模型，并**显式告知用户「未走跨模型」**（SKILL 铁律 §2）。

## 适配器 1：Codex via MCP（推荐）

让 Codex 作为 MCP server，Claude 经 MCP 工具直接调它做对抗验证。

**前置**：装 `codex` CLI（`brew install codex` 或 `npm i -g @openai/codex`）；`codex login` 完成认证（`codex doctor` 应显示 auth configured）。

**注册**（项目根 `.mcp.json`）：

```json
{ "mcpServers": { "codex": { "command": "codex", "args": ["mcp-server"] } } }
```

> ⚠️ 子命令是 `codex mcp-server`（「Start Codex as an MCP server (stdio)」），**不是** `codex mcp`（那是管理 Codex 自己连的外部 server）。版本差异时以 `codex mcp-server --help` 为准。

**派发**：Claude 重启加载 `.mcp.json` 后，**首选**经 `ToolSearch` 找到 `codex` / `codex-reply` 工具，喂 change 描述 + diff + 对抗指令，要求结构化回传（会话内多轮、可 `codex-reply` 续）。会话内 MCP 工具不可用时（如子代理内、未批准）→ 回退 `external-agent.sh dispatch codex-cli`（走本地 `codex exec`，prompt 经 stdin 传入避免 ARG_MAX）。

**健康检查**：`external-agent.sh healthcheck codex-cli`（codex binary + 认证）；MCP 在 Claude Code 内是否已加载另由 `ToolSearch` 能否找到 `codex` 工具判定。端到端真实派发用 `external-agent.smoke.sh`（`RUN_E2E=1`）验，不只看健康检查。

## 适配器 2：Codex via CLI（无 MCP 时降级）

不配 MCP（或在脚本/CI/子代理里），直接经派发底座：

```
printf '%s' "$ADVERSARIAL_PROMPT_WITH_DIFF" > /tmp/cv-prompt
external-agent.sh dispatch codex-cli /tmp/cv-prompt /tmp/cv-out   # 结构化裁决写 /tmp/cv-out
```

prompt 内容：change 描述 + 期望行为 + diff + 「对抗证伪，默认怀疑，逐条给 文件:行 + 复现」。
**健康检查**：`external-agent.sh healthcheck codex-cli`。适用于 MCP 未启用、或想一次性跨模型审查的场景。

**模型档位 / effort**：
- `dispatch`（只读验证 / plan-review / change-review）使用 `CROSS_VERIFY_EFFORT`，默认 `high`。
- `dispatch-write`（cross-execute 写沙箱执行）使用 `CROSS_EXECUTE_EFFORT`，默认 `medium`。
- 不要用执行档位去压低评审档位；完整规则见 `../../flow/references/model-routing.md`。

## 适配器 3：Grok via CLI（xAI Grok，只读对抗验证）

xAI 的 Grok agentic CLI（`~/.grok/bin/grok`）作只读对抗 verifier。**Grok 无 MCP server 模式**（`grok mcp` 是反向——让 grok 去连别的 MCP），故只走 CLI 派发，不进 `.mcp.json`。

**前置**：装 Grok CLI 并 `grok login`（认证落 `~/.grok/auth.json`）。

**派发**（经底座，已实装）：
```
printf '%s' "$ADVERSARIAL_PROMPT_WITH_DIFF" > /tmp/cv-prompt
external-agent.sh dispatch grok-cli /tmp/cv-prompt /tmp/cv-out
```
底层实际命令（经真实调用验证）：
```
grok -p "<prompt>" --permission-mode plan --output-format plain </dev/null
```
- **只读保证**：`--permission-mode plan`（plan 模式只规划不改文件，对应 codex 的 `--sandbox read-only`）——verifier 不许改码。
- **不传 effort**：默认模型 `grok-composer-2.5-fast` 不支持 `reasoningEffort`，传了会 400；故 `CROSS_VERIFY_EFFORT` 仅对 codex 生效。
- **健康检查**：`external-agent.sh healthcheck grok-cli`（grok binary + `~/.grok/auth.json`）。
- **环境覆盖**：`GROK_BIN`(默认 grok) · `GROK_HOME`(默认 ~/.grok)。
- **范围**：仅 `cross-verify`（`dispatch`）。**未实现 `dispatch-write`**（`cross-execute` 写沙箱）——grok 写模式（`--permission-mode acceptEdits` + worktree cwd）待验证后再加；当前对 grok-cli 调 dispatch-write 会 `unknown adapter`。

**多适配器**：`docs/flow/cross-verify` 单行单适配器（派发侧择一）。要 codex 与 grok 都用，可按 change 风险切换该键，或在编排层分别 `dispatch codex-cli` / `dispatch grok-cli` 取双模型二意见（吃双份额度）。

## 接其它模型

任意提供**非交互 CLI**或**MCP server** 的外部 coding agent 同理：
- 有 MCP server → 仿适配器 1 注册进 `.mcp.json`，经工具调用。
- 只有 CLI → 在 `external-agent.sh` 的 `codex_available` / `cmd_dispatch` 两处 `case` 各加一个 adapter 分支（仿 codex-* 写法），用其非交互子命令实现 `healthcheck`/`dispatch`。
在 `docs/flow/cross-verify` 用一个新键标识它，并在本文件追加一节即可。

## 与 Oracle 的关系

cross-verify 停在**纪律级**（技能 + 红线），**不接入** Stop hook Oracle —— Oracle 是跑确定性命令、用退出码裁决的机器门，往里塞 LLM 调用会破坏其确定性。
完成判定仍由 `verify` + Oracle（`docs/flow/verify-cmd`）裁决；cross-verify 只是把"对抗证伪"这一步的大脑换成异模型。
