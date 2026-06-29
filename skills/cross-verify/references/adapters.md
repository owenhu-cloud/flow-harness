# cross-verify 适配器 —— 外部验证器接入

本文是 `cross-verify` 的深度参考：怎么把一个**外部模型 / agent** 接成对抗验证器。
SKILL.md 正文工具无关；具体工具只活在这里。

## 派发底座：`external-agent.sh`（规范实现）

具体派发**统一经本目录的 `external-agent.sh`**（一次性脚本，仿 `verify-citations.sh` 先例；遵 DESIGN「除三支 hook 外不引入常驻 CLI」）。技能不手搓 codex bash——避免重复踩 stdin 挂起 / trusted-dir / 降级的坑。两个子命令即适配器契约：

```
external-agent.sh healthcheck <adapter>            # 可用 0 / 不可用 3（降级信号）
external-agent.sh dispatch    <adapter> <prompt-file> <out-file>   # 结果写 out-file
```

## 适配器接口（任何外部验证器都要满足两点）

一个 cross-verifier 适配器需在 `external-agent.sh` 里实现两点：

1. **`dispatch`** —— 输入：change 描述 + diff/范围 + 期望行为 + 「对抗证伪，默认怀疑」指令（打进 prompt-file）；输出：结构化裁决（真问题/无发现 + 文件:行 + 复现/命令）写 out-file。
2. **`healthcheck`** —— 判断当前是否可用（决定启用还是降级；不可用返回 exit 3）。

满足这两点的任何外部 coding agent（提供非交互 CLI 或 MCP server 者）都能填进来。

## 项目 opt-in：`docs/flow/cross-verify`

单行声明本项目启用的**一个**适配器键（单行单适配器；要并用多个则在本文件追加新适配器节、由派发侧择一），例如：

```
codex-mcp
```

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

**派发**：Claude 重启加载 `.mcp.json` 后，**首选**经 `ToolSearch` 找到 `codex` / `codex-reply` 工具，喂 change 描述 + diff + 对抗指令，要求结构化回传（会话内多轮、可 `codex-reply` 续）。会话内 MCP 工具不可用时（如子代理内、未批准）→ 回退 `external-agent.sh dispatch codex-mcp`（走本地 `codex exec`）。

**健康检查**：`external-agent.sh healthcheck codex-mcp`（codex binary + 认证）；MCP 在 Claude Code 内是否已加载另由 `ToolSearch` 能否找到 `codex` 工具判定。

## 适配器 2：Codex via CLI（无 MCP 时降级）

不配 MCP（或在脚本/CI/子代理里），直接经派发底座：

```
printf '%s' "$ADVERSARIAL_PROMPT_WITH_DIFF" > /tmp/cv-prompt
external-agent.sh dispatch codex-cli /tmp/cv-prompt /tmp/cv-out   # 结构化裁决写 /tmp/cv-out
```

prompt 内容：change 描述 + 期望行为 + diff + 「对抗证伪，默认怀疑，逐条给 文件:行 + 复现」。
**健康检查**：`external-agent.sh healthcheck codex-cli`。适用于 MCP 未启用、或想一次性跨模型审查的场景。

## 接其它模型

任意提供**非交互 CLI**或**MCP server** 的外部 coding agent 同理：
- 有 MCP server → 仿适配器 1 注册进 `.mcp.json`，经工具调用。
- 只有 CLI → 在 `external-agent.sh` 的 `codex_available` / `cmd_dispatch` 两处 `case` 各加一个 adapter 分支（仿 codex-* 写法），用其非交互子命令实现 `healthcheck`/`dispatch`。
在 `docs/flow/cross-verify` 用一个新键标识它，并在本文件追加一节即可。

## 与 Oracle 的关系

cross-verify 停在**纪律级**（技能 + 红线），**不接入** Stop hook Oracle —— Oracle 是跑确定性命令、用退出码裁决的机器门，往里塞 LLM 调用会破坏其确定性。
完成判定仍由 `verify` + Oracle（`docs/flow/verify-cmd`）裁决；cross-verify 只是把"对抗证伪"这一步的大脑换成异模型。
