# cross-verify 适配器 —— 外部验证器接入

本文是 `cross-verify` 的深度参考：怎么把一个**外部模型 / agent** 接成对抗验证器。
SKILL.md 正文工具无关；具体工具只活在这里。

## 适配器接口（任何外部验证器都要满足两点）

一个 cross-verifier 适配器需提供：

1. **派发一次对抗验证** —— 输入：change 描述 + diff/范围 + 期望行为 + 「对抗证伪，默认怀疑」指令；输出：结构化裁决（真问题/无发现 + 文件:行 + 复现/命令）。
2. **健康检查** —— 能判断它当前是否可用（决定启用还是降级）。

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

**派发**：Claude 重启加载 `.mcp.json` 后，经 `ToolSearch` 找到 `codex` / `codex-reply` 工具，喂 change 描述 + diff + 对抗指令，要求结构化回传。

**健康检查**：MCP `initialize` 握手能拿到 `serverInfo`（`codex-mcp-server`）即可用；或 `codex doctor` 看 auth/network。

## 适配器 2：Codex via CLI（无 MCP 时降级）

不配 MCP，直接用非交互 CLI：

```
codex exec '<对抗证伪 prompt：change 描述 + 期望行为 + 下面这段 diff，找出会出错/未覆盖/破坏现有行为处，默认怀疑。逐条给 文件:行 + 复现。>\n<diff>'
```

解析其 stdout 当结构化回传。**健康检查**：`codex --version` + `codex doctor`。
适用于 MCP 未启用、或想在脚本/CI 里跑一次性跨模型审查的场景。

## 接其它模型

任意提供**非交互 CLI**或**MCP server** 的外部 coding agent 同理：
- 有 MCP server → 仿适配器 1 注册进 `.mcp.json`，经工具调用。
- 只有 CLI → 仿适配器 2 用非交互子命令派发、解析 stdout。
在 `docs/flow/cross-verify` 用一个新键标识它即可。

## 与 Oracle 的关系

cross-verify 停在**纪律级**（技能 + 红线），**不接入** Stop hook Oracle —— Oracle 是跑确定性命令、用退出码裁决的机器门，往里塞 LLM 调用会破坏其确定性。
完成判定仍由 `verify` + Oracle（`docs/flow/verify-cmd`）裁决；cross-verify 只是把"对抗证伪"这一步的大脑换成异模型。
