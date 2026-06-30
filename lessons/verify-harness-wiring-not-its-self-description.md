# 别信 harness 的"自我宣称"，去验证它到底接没接上

- symptom:
  用户质疑"Codex 交叉验证真生效了吗？我用量没变""感觉 flow-harness 很多能力没真实生效"。
  排查发现：(1) 当前会话加载的 `.claude/skills/` 是几个月前 `cp` 出的旧精简副本，缺 `cross-verify`/`cross-execute` 等技能——跑的是降级版方法论；(2) `cross-verify` opt-in 键虽配了 `codex-mcp`，但消费它的技能没在激活集里，plan/brainstorm 从未走跨模型；(3) Stop hook 的"独立 Oracle 复核"虽经插件注册并每轮触发，但 `docs/flow/verify-cmd` 不存在 → 第一行就 `exit 0`，**一直是 no-op**，从没真拦过。
- root_cause:
  把"reinject/文档宣称的能力"当成"已生效的能力"。harness 的 SessionStart/UserPromptSubmit 文本会持续宣称"完成由独立 Oracle 复核""跨模型对抗"，但这些多为 **opt-in / 需落配置文件 / 依赖某副本同步**，而注入文本不反映真实接线状态。多套技能来源（仓内源 / `.claude/skills` cp 副本 / 插件 cache）漂移时，到底加载哪套也不显式。
- fix:
  逐项验证接线，而非读宣称：① 比对实际加载的技能副本 vs 源（`diff`、看 `Skill` 工具的 base dir）；② 查 opt-in 开关文件是否存在且被可加载的技能消费（`docs/flow/cross-verify`、`docs/flow/verify-cmd`）；③ 跨模型调用查留痕证明真跑（codex `~/.codex/sessions/<threadId>.jsonl`、token 用量、auth_mode）；④ Oracle 这类门读脚本确认其 opt-in 前置条件是否满足。
- generalization:
  - **"宣称生效" ≠ "已接线生效"**：reinject 文本、README、技能描述都可能领先于真实配置。声明某能力在保护你之前，先验证它的开关/依赖/副本真的到位且被调用。
  - **完成门（Oracle）严格 opt-in**：没有 `docs/flow/verify-cmd` 就是 no-op。要它真拦，必须为（子）项目写一条会因失败而非零退出的真实验证命令，并提交版本控制。
  - **多副本漂移要先定位"真身"**：源仓 / 项目 `.claude/skills`（cp 同步）/ 插件 cache（GitHub 安装）三者可能不一致；改前先确认会话实际加载哪套，改后同步到那套。
  - **真实外部调用是抓臆造的最好手段**：grok `--effort` 被默认模型拒（400）、codex 的 read-only 沙箱、macOS 无 `timeout`——都是真跑一次才暴露，纸面推不出。[[dont-invent-unvalidated-optimizations-when-extending-rules]]
- links:
  - hooks/flow-oracle.sh（opt-in 第 51 行）、docs/flow/verify-cmd
  - skills/cross-verify/references/{external-agent.sh,adapters.md}（grok-cli 适配器）
  - .claude/skills（cp 副本）vs ~/.claude/plugins/cache/flow-harness（插件）
- last_verified: 2026-06-29
