---
name: flow-doctor
description: 想知道「这个项目里 Flow 到底什么在真生效、什么只是提示词纪律」时用——一条命令体检 Oracle/B3/B4/cross 的 opt-in 与外部 agent 健康，区分机器强制门 vs 靠自觉的纪律。装完插件没感觉、排查「为什么 Oracle 没拦住」、接手别人配过 Flow 的项目时尤其用。 · EN: flow-doctor — diagnose what Flow is actually enforcing in THIS project (Oracle/B3/B4/cross opt-in state + external-agent health), separating machine-enforced gates from prompt-only discipline. Use when the plugin "seems to do nothing", when debugging why the Oracle didn't block, or when inheriting a project someone else wired.
---

# flow-doctor — Flow 接入状态体检

Flow 的能力分两层，肉眼难分：**机器强制**（Stop Oracle，配了 `docs/flow/verify-cmd` 才生效）与**纪律级**（判档/门/builder≠verifier/TDD，靠 agent 自觉、hook 无法证明）。装了插件 ≠ 这些都在跑。`flow-doctor` 一条命令把真实状态摊开，杜绝「以为 Oracle 在守、其实没配 verify-cmd 而全程裸奔」。

## 何时用

- 装完 Flow「没感觉」，想确认到底接没接入。
- 排查「我删了测试 / 改低了基线，Oracle 为什么没拦」——多半是没写 `verify-cmd`（Oracle 整体放行），doctor 一眼看出。
- 接手别人配过 Flow 的项目，先体检再动手。
- 启用了 `cross-verify` 想确认异模型适配器是否真可用（codex/grok 健康）。

## 怎么用

在**项目根目录**跑诊断脚本（无副作用、只读、不联网调模型）：

```sh
sh "${CLAUDE_PLUGIN_ROOT}/hooks/flow-doctor.sh"
```

退出码：`0` = Oracle 已接入（`verify-cmd` 在场）；`1` = 未接入（完成判定退回纪律级）。`--quiet` 只给退出码、不打印，便于脚本/CI 判定。

## 读报告

- **机器强制 · Stop Oracle**：`verify-cmd` 是否配（没配 = 全程无机器门，最关键的一行）；B2 基线、A 完整性门（仅 git 仓）、B3/B4 opt-in、verify-cache 开关与 false-skip 提醒、测试豁免文件是否已提交生效。
- **opt-in · 多模型对抗**：`cross-verify`/`cross-execute` 是否启用 + 适配器键 + `codex-cli`/`grok-cli` 健康（available / 降级）。注意：健康检查只验 binary+auth，不验 CLI flag 兼容——真实端到端用 `skills/cross-verify/references/external-agent.smoke.sh`（`RUN_E2E=1`，有凭证时跑最小真调用并留证据）验。
- **纪律级**：判档/brainstorm·plan 门/builder≠verifier/TDD/mutation 抽查——doctor 明确标注**这些 hook 不强制**，完成证据看 `implement`/`verify` 贴出的 fresh 输出。

## 据结果下一步

- Oracle INACTIVE 且你要机器级守护 → 用 `profile`（首次）或 `verify` 写 `docs/flow/verify-cmd`（必要时加 `robustness-cmd`/`coverage-cmd` 开 B3/B4）。
- 适配器「降级」→ 缺 binary/`auth.json`；装好再 opt-in，否则 `cross-verify` 会回退同模型基线。
- 一切如期 → 正常按 `flow` 判档走流程。

遵循 `flow` 技能的质量红线。
