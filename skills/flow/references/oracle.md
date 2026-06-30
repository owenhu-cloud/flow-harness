# 机器级硬门控（独立 Oracle，已内置）

> `flow/SKILL.md` 路由器只留两句摘要；本文件是完整说明。

完成不靠 agent 自说自话：Flow 自带 `Stop` hook Oracle（`hooks/flow-oracle.sh`）。**其生效是有条件的**——仅当项目里存在 `docs/flow/verify-cmd`（由 `profile`/`verify` 写入）时，agent 每次试图收尾该 hook 才以**独立进程**跑这条命令裁决，非 0 退出即打回、阻止收尾，这是 agent 在该轮收尾内无法绕过的机器级门控（前提是 `verify-cmd` 在场）。**未写 `verify-cmd` 则 Oracle 整体放行（零侵入），此时无任何机器门，完成判定退回纪律级（红线 + verify 技能）。** 装了插件 ≠ Oracle 在守——拿不准就用 `flow-doctor` 体检实际接入态。

它防的是「压力下偷懒/reward-hacking」，提高绕过成本、留审计痕迹，**不是安全边界**：能 commit 改基线/燃料者仍可绕（信任根在仓库内，根治需带外 CI/人审基线，见 `docs/DESIGN.md` 威胁模型）。

接入方式：首次进入项目用 `profile` 探测并写 `docs/flow/verify-cmd`。需要更强的外部循环时仍可叠加 `/pua:pua-loop` 等，与本 Oracle 正交。
