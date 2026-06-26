---
name: finishing-a-development-branch
description: 一个 change/分支干完了、要决定合并还是开 PR 还是丢弃时用（R1+）——收尾前必过 verify+Oracle，脏分支不堆积，丢弃前需显式确认。 · EN: a change/branch is done and you must decide merge vs PR vs discard — gate the close on verify+Oracle, don't let dirty branches pile up, require explicit confirmation before discarding (R1+).
---

# finishing-a-development-branch — 分支收尾决策（R1+）

一支 change 做完了，落地方式只有三种：**合并 / 开 PR / 丢弃**。这一支技能塞死收尾期最容易出的两类事故——**没过验证就合**、**做完不收尾让脏分支堆积**——并把「丢弃」做成需要显式确认的不可逆操作。

## 适用档位与流程位置

- 档位：R1+。R0（一次性小改、无独立分支）不走本技能。
- 位置：`brainstorm → plan → implement → verify → document` **之后**的收口动作。**先有交付物（document）再收尾**——合并/开 PR 时 PR body 与 CHANGELOG 必须已存在，不是边合边补。
- 前置硬门槛：收尾必须建立在 verify 已绿、Stop hook Oracle（`docs/flow/verify-cmd` 喂的独立复核）放行之上。verify 没过，本技能不启动。

## 铁律（iron-laws，违反即作废）

1. **未过 verify+Oracle 不许收尾。** 合并/开 PR 前必须有本轮、当前 HEAD 的新鲜验证证据（failures=0、exit 0）。Oracle 拦你 = 没完成，不许绕。
2. **先交付物，后收尾。** R1+ 的合并/PR 必须先有 `document` 产出（PR body / CHANGELOG / 设计文档）。没交付物的合并是黑箱合并。
3. **丢弃是显式不可逆操作。** 删分支/丢弃 worktree 前，向用户复述将丢失什么并取得明确确认（要求回 `discard` 或等价明示），绝不默认丢弃。
4. **只动自己这支 change 的分支。** 不顺手合别人的分支、不清理非本技能/本 change 创建的 worktree。
5. **做完即收尾，不留半成品分支过夜。** 一支 change 的终态只能是「已合并」「已挂 PR 等评审」「已显式丢弃」三选一，不存在「先放着」。

## 收尾决策树

```
change 做完
  └─ verify 全绿 且 Oracle 放行？
       ├─ 否 → 停。回 verify 取证据 / 修复，不进入收尾。
       └─ 是 → document 交付物就位？
                ├─ 否 → 先用 Skill 加载 document 产出 PR body/CHANGELOG。
                └─ 是 → 这支 change 还要不要？
                         ├─ 不要了（探索失败/方向被否） → 走「丢弃」(需显式确认)
                         ├─ 要、且需他人评审或属共享仓 → 走「开 PR」
                         └─ 要、可自行落地（本地/个人分支/明确授权直合） → 走「合并」
```

判别要点：**有人要看 = 开 PR；只有自己落地且被授权 = 合并；这段工作不保留 = 丢弃。** 拿不准默认开 PR（可逆、留痕），不要默认直合 main。

## 三条收尾路径的硬约束

- **合并**：先确认 base 分支（通常 `main`/`master`）。合并前再跑一次该档位验证命令集（rebase/merge 后代码状态变了，旧绿不算数），绿了再合。合并完清理本 change 的工作分支/worktree。
- **开 PR**：push 当前分支并建 PR；PR body 引用 verify 的新鲜输出与 document 结论，不复制全量日志。开完 PR 分支保留待评审——这是合法终态，不算「堆积」。
- **丢弃**：复述将永久丢失的内容 → 取得显式确认 → 删分支/移除 worktree。只移除本技能或本 change 创建的 worktree，外部 harness 管理的不碰。

## 危险信号（出现即停，回退）

- 想「先合了再补 PR 说明 / 回头再写 CHANGELOG」——违反铁律 2，停。
- verify 是上一轮跑的、这轮 rebase/改了又没重跑就想合——旧绿不算数，回 verify。
- 打算用「应该没冲突 / 大概能合 / 跑通了」描述收尾前状态——模糊措辞即未验证，停。
- 准备删分支但没向用户确认、或没说清丢什么——铁律 3，停。
- 一支 change 既不合也不挂 PR 也不丢弃，想「暂时放着」——不存在第四态，逼自己三选一。
- 信任子代理自报「已合并/已验证」而没自己看 diff 与命令输出——回去看证据。

## 正反例

**反例（违规）**：「实现写完了，逻辑很直接，我直接 `git merge` 到 main 然后回头补 PR 说明。」→ 未贴本轮验证证据、用「很直接」替代证据、交付物缺位、直合 main。三条铁律连违。

**正例（合规）**：「R1 单测 `pytest -q` 本轮全绿 `94 passed`（exit 0），Oracle 放行；PR body 与 CHANGELOG 已就位。这支属共享仓需评审 → 走开 PR：`git push` 后建 PR，body 引用上述输出。分支保留待评审。」→ 新鲜证据 + 交付物 + 路径判别 + 合法终态。

## checklist（收尾前逐条打钩）

- [ ] verify 跑的是**本轮、当前 HEAD** 的完整档位命令集，failures=0、exit 0。
- [ ] Stop hook Oracle 放行（`docs/flow/verify-cmd` 已是当前裁决命令）。
- [ ] document 交付物（PR body / CHANGELOG / 必要设计文档）已就位。
- [ ] 已按决策树判明 合并 / 开 PR / 丢弃，拿不准默认开 PR。
- [ ] 合并路径：base 分支确认、rebase/merge 后**重跑**验证再合。
- [ ] 丢弃路径：已向用户复述丢失内容并取得**显式**确认。
- [ ] 只动了本 change 的分支/worktree，没碰他人或外部 harness 的。
- [ ] 这支 change 落在「已合并/已挂 PR/已丢弃」之一，无遗留半成品分支。

## 红线（反合理化）

| 合理化借口 | 实际规则 |
|---|---|
| 先合了回头再补 PR 说明/CHANGELOG | 先交付物后收尾（铁律 2）。没 document 的合并是黑箱合并，不许。 |
| 上一轮 verify 过了，rebase 后没大改不用再跑 | 收尾基于本轮当前 HEAD 的新鲜证据；rebase/merge 改了状态，旧绿作废，重跑。 |
| 这改动很直接，肯定能合，跳过验证 | 把握≠证据。未过 verify+Oracle 一律不收尾（铁律 1）。 |
| 子代理报告已合并/已验证，我信它 | 不信转述；自己看 diff 与命令输出再判收尾（红线对齐 verify）。 |
| 不说「完成」，说「合上去了/应该 OK」就不算违规 | 同义改写也是收尾声明，照样要新鲜证据，否则等同伪造。 |
| 这分支没用了，直接删省事 | 丢弃不可逆：必先复述丢失内容并取得显式确认（铁律 3）。 |
| 顺手把那条相关分支也合/清了 | 只动本 change 的分支/worktree，不碰他人与外部 harness 的（铁律 4）。 |
| 还没想好怎么落地，先把分支放着 | 不存在「放着」这一态；三选一：合并/挂 PR/丢弃（铁律 5）。 |
| 默认直接合到 main 最快 | 拿不准默认开 PR（可逆留痕），不默认直合共享主干。 |

> 渐进披露：worktree/detached-HEAD 等环境分支的收尾细节见 `references/worktree-cleanup.md`，正文只留判别与硬约束。

下一步：收尾若涉及给人看的产物缺位，先用 Skill 工具加载 `document` 补齐再收；若本支 change 经历了连续失败/返工/被 verifier 抓到真 bug 等学习信号，用 Skill 工具加载 `harvest` 沉淀经验；收尾命令证据回 `verify` 取。

遵循 `flow` 技能的质量红线。
