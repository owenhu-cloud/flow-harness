---
name: cross-execute
description: R3 已有一串明确、可独立验证的子任务，想把执行交给外部模型（Codex）在隔离 worktree 落地、Claude 退到编排+审查位时用——默认关闭（`docs/flow/cross-execute` 在场才启用）。 · EN: cross-model parallel executor (R3, default OFF) — dispatch well-specified, independently-verifiable subtasks to an external model (Codex) running in isolated git worktrees; Claude orchestrates and reviews every diff, never blind-trusts. Opt-in only.
---

# cross-execute — 把执行派给异模型在隔离 worktree 落地

把**明确、可独立验证**的子任务**派给外部模型（Codex）在 git worktree 里执行**，Claude 退到**编排 + 审查**位。
这是 `cross-verify` 的**镜像**：cross-verify 换的是「谁来**验**」，cross-execute 换的是「谁来**建**」——
builder = 外部模型，verifier = Claude，天然满足 builder ≠ verifier（且跨模型，盲点不重叠）。

**它是 `subagent-driven-development` 的跨模型变体**：同样是「一串任务逐条派、每条独立验证」，
区别只在执行者从「同模型 fresh 子代理」换成「异模型在隔离 worktree」。编排骨架沿用前者。

## 适用档位 + opt-in（默认关闭）

**仅 R3**，且**仅当项目根有 `docs/flow/cross-execute`**（单行写适配器键，如 `codex-cli`）才启用。
缺该文件 → 本技能不参与，走 `subagent-driven-development`（同模型子代理）或 `implement` 基线，零侵入。
适配器键、健康检查、派发底座与 `cross-verify` **共用** `../cross-verify/references/external-agent.sh`
与 `../cross-verify/references/adapters.md`——执行走其 `dispatch-write` 子命令（写沙箱变体）。
模型路由遵循 `../flow/references/model-routing.md`：**执行者默认低一档，编排/方案/评审不降档**。Codex CLI 路径中 `dispatch-write` 使用 `CROSS_EXECUTE_EFFORT`（默认 `medium`），不同于 `cross-verify` 的 `CROSS_VERIFY_EFFORT`（默认 `high`）。

## 何时别用（先读这段——多数情况答案是「别用」）

调研结论：跨进程跨模型的执行**协调成本高**，子任务一旦含糊或耦合，返工与审 diff 的开销远超收益。**默认别用**，除非全部命中：

- 任务**已拆到明确**（输入/输出/验收都写死，无需执行者做设计判断）——判断活留给 Claude/plan，别外包。
- 子任务**彼此独立**（不同文件/模块，无共享可变状态）——有耦合就串行做或同进程做。
- 每条子任务**能独立验证**（有测试或可机检的验收）——验不了就别派，你无法审。
- 子任务**数量够多**（≥3）且机械度高，并行才摊得平协调成本——一两条直接 `implement`。
- 任务能由低一档执行者完成；若需要接口/架构/数据一致性判断，先回 `plan` 或主编排者拆清楚。

任一不满足 → **不要用 cross-execute**，回 `subagent-driven-development` 或 `implement`。

## 铁律（iron-laws，违反即作废）

1. **worktree 强制隔离，一任务一 worktree。** 每个外部执行子任务必须在**独立 git worktree**（`git worktree add` 产生的 linked worktree）里跑，经 `external-agent.sh dispatch-write <adapter> <prompt-file> <out-file> <worktree-dir>` 派发。绝不让外部模型在主工作区或共享目录改文件——并发写必互相覆盖、污染主线。**这条有脚本层防线**：`dispatch-write` 校验目标确是 linked worktree，主工作区/裸目录/非 git 目录一律拒（exit 1）——但别依赖防线偷懒，编排时本就该建好 worktree。
2. **≤3 并行（甜区），超了就排队。** 同时在跑的外部执行子任务不超过 3 个。再多则协调/审查/解冲突的成本吃掉并行收益，且你来不及逐个审 diff。宁可分批。
3. **每个子任务必须可独立验证，派发 brief 含完整规格。** 子任务的输入/输出/验收写进 prompt-file 全文（外部模型是 fresh 上下文，不带它就不知道项目画像/命令/约定）。验收必须可机检（测试/命令）。验不了的任务不许派。
4. **Claude 必审每一份 diff，不盲信「我做完了」。** 外部模型回报完成 ≠ 完成。Claude 对每个 worktree 的 diff 逐份审查（正确性/越界/是否真满足规格/有无偷改无关文件），再决定合入。外部自报「测过了」不采信——要可核实的命令 + 新鲜输出。
5. **合入前每条过验证 + 整体回 `verify`。** 单条子任务：审 diff 通过 + 该任务测试新鲜绿，才 merge 回集成分支。整串收口：加载 `verify` 跑项目真实 build/test，由 `verify` + Stop hook Oracle 裁决，不由「都派完了」叙述裁决。
6. **适配器不可用必须显式降级。** 健康检查失败（`external-agent.sh healthcheck` 返回 3）→ 降级回 `subagent-driven-development`（同模型子代理）或 `implement`，并明说「未走跨模型执行，回同模型基线」。禁止假装派过。

派发 brief 模板 / 适配器 / 健康检查 / 降级语义 → 见 `../cross-verify/references/adapters.md`。

## 编排循环（每条子任务走一遍，≤3 并行）

1. **拣选**：从 `plan` 的 `tasks.md` 取下一批**互相独立、各自可验证**的子任务（最多 3 条同批）。
2. **建 worktree（每条一个新分支）**：`git worktree add -b <task-branch> ../<repo>-<task> <base>`。必须是 `git worktree add` 产生的隔离 *linked* worktree——`dispatch-write` 在脚本层就会拒绝主工作区/裸目录。
3. **写 brief + 派发**：把该任务**完整规格 + 项目画像约定（命令/风格/反模式）+ 反越界边界 + 验收命令 + 模型档位意图（预算/标准执行者，禁止做设计判断）**写进 prompt-file，**并明确要求执行者在该 worktree 内 `git commit` 自己的改动**（否则无可 merge 的提交、worktree 也会因 dirty 无法 remove）。经 `external-agent.sh dispatch-write <adapter> <prompt-file> <out-file> <worktree-dir>` 派给外部模型在该 worktree 落地。
4. **审 diff（Claude = verifier）**：执行回来后，`git -C <worktree> diff <base>..` 逐份审——是否逐条满足规格？有无越界改无关文件？正确性/边界/错误路径？复核而非采信自报（铁律 §4）。
5. **验证单条**：在 worktree 跑该任务的验收命令，新鲜绿才算过；不过 → 带具体失败回派**同一 worktree**修（改了上下文再派，不原样重试）。
6. **合入 + 清理**：审 + 验都过 →（执行者已 commit）从集成分支 `git merge <task-branch>`，再 `git worktree remove <worktree>`（已 commit 故非 dirty）+ `git branch -d <task-branch>`，勾掉 `tasks.md`。下一批。
7. **整串收口**：全部合入后加载 `verify` 跑全量真实命令，Oracle 裁决（铁律 §5）。

## 危险信号（出现即停 / 回退）

- 想让外部模型直接在主工作区/共享目录改文件「省得建 worktree」 → 停，并发互覆，铁律 §1。
- 一把派 5+ 条并行「快」 → 停，审不过来、冲突暴涨，铁律 §2。
- 派发只甩「看 tasks.md 第 N 条」不给规格全文 → 停，fresh 上下文会读漏/越界，铁律 §3。
- 外部回「done / 测过了」就直接 merge，没自己审 diff、没跑验收 → 停，盲信，铁律 §4。
- 子任务其实含设计判断（接口怎么定、架构怎么切）却外包出去 → 停，判断活不外包，「何时别用」。
- 为了省钱把 Claude 审 diff / 方案评审也降档 → 停，只有执行者降档，评审不降档。
- 子任务彼此耦合（改同一文件/共享状态）还硬并行 → 停，回串行/同进程，「何时别用」。
- 适配器没配/不可用却当派过了 → 停，显式降级，铁律 §6。

任一命中 → 停，回对应铁律/「何时别用」重做。

## 正例 / 反例

- **正例**：`docs/flow/cross-execute` 写了 `codex-cli`。tasks.md 有 4 条互相独立的机械活（各自单文件 + 完整规格 + 单元测试验收）。取前 3 条，各建一个 worktree，brief 带上 `project.md` 的构建/测试命令与反模式，经 `dispatch-write` 派给 Codex。回来后 Claude 逐份 `git diff` 审：第 2 条偷改了无关的 config，退回修；其余两条审过 + 在 worktree 跑测试新鲜绿 → merge。第 4 条同法。整串 `verify` 跑 `make test` 全绿（fresh 输出附后），Oracle 放行。
- **反例**：把 4 条任务一股脑丢给 Codex「你都在主目录做了」，回报 done 就直接信、不审 diff、不跑验收，主线程扫一眼勾完——并发覆盖 + 无独立验证 + 盲信自报，三违铁律，作废。

## checklist（声明整串完成前逐条核）

- [ ] 已确认 `docs/flow/cross-execute` 在场且适配器健康；不可用时**已显式告知降级**。
- [ ] 每条外部执行子任务都在**独立 git worktree**，全程**≤3 并行**。
- [ ] 每条任务派的 brief 含**完整规格 + 项目画像约定 + 验收命令**，非文件指针。
- [ ] 每份 diff **Claude 亲自审过**（正确性/越界/规格符合），没盲信外部自报。
- [ ] 每条单测在合入前**新鲜绿**；BLOCKED/失败都**改了上下文再派**，没原样重试。
- [ ] 每条都要求执行者在 worktree 内 commit；合入走 `git merge <task-branch>`，worktree 已 `git worktree remove`，无脏分支/残留 worktree 堆积。
- [ ] 整串收口跑了 `verify`，新鲜输出已贴、退出码 0，Oracle 放行。

## 红线（反合理化）

> 违反规则字面 = 违反规则精神。任何「我遵守了精神」的解释不成立。

| 合理化借口 | 实际规则 |
|---|---|
| 建 worktree 太麻烦，让它直接在主目录改 | 一任务一独立 worktree，强制隔离。并发写主区必互覆污染主线（铁律 §1）。 |
| 多派几条并行快很多 | ≤3 并行。再多审不过来、冲突暴涨，省的时间全赔在审 diff 与解冲突上（铁律 §2）。 |
| 让它自己去看 tasks.md 第几条 | 必须把规格**全文** + 项目画像写进 brief。外部是 fresh 上下文，不带就读漏/越界（铁律 §3）。 |
| 它是另一个模型，说做完了应该没错，直接合 | 外部自报 ≠ 完成。每份 diff 必 Claude 亲审，验收命令必新鲜跑（铁律 §4）。 |
| 这任务有点设计判断，顺手也外包了 | 判断活（接口/架构/取舍）不外包，留 Claude/plan。只派已拆死、可机检验收的机械活（何时别用）。 |
| 这几条改同一个文件，一起并行省事 | 耦合任务不并行。回串行或同进程 `implement`，否则互相覆盖（何时别用 / 铁律 §1）。 |
| 适配器没配好，先当跨模型执行过了 | 不可用即显式降级回同模型基线并告知，禁止假装派过（铁律 §6）。 |
| 都派完合上了，verify 就不用跑了 | 完成永远由 `verify` 真实命令 + Oracle 裁决，不由「都派完了」叙述（铁律 §5）。 |

外部执行抓到的问题 / Claude 审 diff 抓到真 bug → 回派同 worktree 修；撞学习信号（跨模型执行反复返工 / 协调成本超预期 / 审出外部模型系统性偏差）→ 用 Skill 工具加载 `harvest` 沉淀。整串 `verify` 收口后 → 加载 `document` 出交付物。

遵循 `flow` 技能的质量红线。
