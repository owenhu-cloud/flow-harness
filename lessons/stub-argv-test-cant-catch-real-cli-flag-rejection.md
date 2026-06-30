# stub argv 断言测不出真 CLI 拒 flag：外部 CLI 调用必配真实端到端冒烟

- symptom:
    给 external-agent.sh 加 dispatch-write（codex 写沙箱执行）时，test.sh 用 stub codex
    记录 argv 做 dry-run 断言——`--sandbox workspace-write --ask-for-approval never` 全绿。
    跨模型 verifier（Codex 审自己要跑的命令）没看出 flag 问题，但**真实 codex 端到端冒烟**
    立刻 rc=2 usage error：`codex exec` 根本没有 `--ask-for-approval`（那是交互 TUI 的 flag，
    exec 子命令非交互、无审批通道）。计划文档（tasks.md 4.2）照抄了这个不存在的 flag。
- root_cause:
    stub 按"接受任何 argv 并打印 canned 输出"实现 → 它只能验证**我方命令拼装的形状**
    （引用/quoting/顺序/沙箱值），无法验证**对端 CLI 是否接受这些 flag**。flag 合法性是
    外部契约，stub 不持有该契约 → 任何"照规格/记忆写 flag"的错误都对 stub 透明，假绿。
    叠加：规格本身（计划）就把 flag 写错了，无真实对端校验时错误一路绿到底。
- fix:
    任何对**外部 CLI** 的封装，dry-run argv 断言（必要，快、确定性、测拼装）**必须**配一条
    **真实对端的端到端冒烟**（慢、真调、测契约）。dispatch-write 改为依实测 `codex exec --help`：
    删 `--ask-for-approval`（exec 无此 flag），保留 `--sandbox workspace-write`；
    真冒烟在隔离 worktree 让真 codex 建文件并提交、断言主仓未污染。两层各司其职、缺一假绿。
- generalization:
    ①stub/mock 测的是"我方怎么调"，测不了"对端认不认"——凡 flag/子命令/退出码语义来自外部
      二进制，就有一条 stub 永远盲的契约缝；用一次真实调用钉死它（CI 里可 gate 在"对端在场"）。
    ②规格里出现的具体外部 flag/子命令是**待核实事实**（AGENTS.md 不臆造）：下笔即 `--help`
      核一遍，别从计划/记忆/同类工具迁移假定（codex≠claude≠git 的 flag 表）。
    ③这正是跨模型对抗的边界：异模型 verifier 能抓语义/逻辑 bug，但**不跑真命令**时同样测不出
      flag 拒绝——所以 Flow 红线"完成必带同轮真实输出"压在 cross-verify 之上，不被它替代。
- links:
    skills/cross-verify/references/external-agent.sh（cmd_dispatch_write）、
    skills/cross-verify/references/external-agent.test.sh（dispatch-write 真 worktree fixture 段）、
    skills/cross-execute/SKILL.md、CLAUDE.md（跨模型对抗：Codex 证伪 + 真实输出裁决）。
- last_verified: 2026-06-29
