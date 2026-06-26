# 环境分支收尾细节（worktree / detached HEAD）

正文给的是「合并/开 PR/丢弃」三路径的判别与硬约束；本文补环境差异下的具体动作。仍受 SKILL.md 全部铁律约束（先 verify+Oracle、先交付物、丢弃需显式确认、只动本 change 的分支）。

## 先识别环境

收尾前判断当前处于哪种 git 形态，菜单不同：

1. **标准仓库 + 命名分支**：在 `main`/`master` 之外的常规分支上。可合并/开 PR/丢弃三选一。
2. **命名分支 worktree**：通过 `git worktree` 检出的独立工作目录，分支有名字。收尾后需额外 `git worktree remove`。
3. **detached HEAD**：无分支名。**不能直接合并/丢弃一个不存在的分支**——先决定是否 `git switch -c <name>` 落成命名分支再走三路径，否则只能保留或显式放弃这段游离提交（确认后）。

## base 分支识别

合并前确认目标 base：优先看仓库默认分支（`git symbolic-ref refs/remotes/origin/HEAD` 或 `gh repo view`），常见 `main`/`master`。不要凭记忆假设，仓库可能用 `develop` 或 `trunk`。

## worktree 清理的来源规则

- **只移除本技能或本 change 创建的 worktree**——通常位于 `.worktrees/` 或 `worktrees/` 等本流程约定路径。
- **外部 harness（含本 Flow harness 自身）管理的 worktree 一律不动。** 分不清来源时，不删，问用户。
- 合并/丢弃后才清理 worktree；开 PR 路径保留 worktree 与分支待评审，不清理。

## 丢弃路径的显式确认（不可逆）

删分支 / 丢弃游离提交 / 移除 worktree 前：

1. 列出将永久丢失的内容（哪个分支、多少未合并提交、是否已 push）。
2. 要求用户明示确认（回 `discard` 或等价明确指令）。
3. 已 push 的分支额外提示远端副本是否一并删除。
4. 确认后再执行 `git branch -D` / `git worktree remove --force` 等。

任何一步缺确认即停——丢弃是本技能唯一不可逆动作。

## 收尾后回到主线

清理完 worktree/分支后，确保回到一个干净的 base 工作区（`git status` 干净、HEAD 在 base 分支），避免把后续工作误建在残留状态上。
