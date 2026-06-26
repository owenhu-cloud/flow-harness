---
name: code-review
description: 一个 change 收敛后、合并/进下一项前想要第三方评审时用（R2+）——派独立 reviewer 子代理按 Critical/Important/Minor 分级查可读性·设计·规范，并接住评审结果（嘴上接受实际忽略=违规）。 · EN: after a change converges, before merge/next task, when you want third-party review (R2+) — dispatch an independent reviewer subagent that grades findings Critical/Important/Minor on readability/design/conventions, and actually receive them (acknowledging then ignoring = violation).
---

# code-review — 请求评审 + 接受评审（合一）

**适用档位：R2–R3。** 在 Flow 流程 `brainstorm → plan → implement → verify → document` 中，挂在 **verify 之后、document/合并之前**：实现已收敛、verify 已出新鲜绿证据，此时派一个 fresh-context 的 reviewer 子代理审查**可读性 / 设计 / 规范**。

与 `implement` 的对抗 verifier **互补不重叠**：verifier 偏**证伪正确性**（搞坏它、抓真 bug），review 偏**可读性·设计·命名·规范·重复**。verify 没绿之前不要 review——别拿评审掩盖未通过的测试。

本技能两件事合一：**请求评审**（怎么派、给什么上下文）+ **接受评审**（怎么接、不许嘴上接受实际忽略）。

动手前读 `docs/flow/project.md`（项目画像）：reviewer 须按其中的风格约定与**项目特异反模式**审，别套通用规范。

## 铁律（iron-laws，不可违反）

1. **reviewer 必须是独立子代理 + fresh context。** 用 `Task` 工具新派一个子代理，喂它**模板 + git diff**（见 `references/reviewer-template.md`），不喂对话历史。你自己回看自己的代码不算评审。
2. **diff 驱动，不靠转述。** 评审对象是 `BASE_SHA..HEAD_SHA` 的真实 diff，不是你对改动的口头描述。
3. **分级裁决，逐条落地。** 每条发现归 Critical / Important / Minor，且每条都要有**显式处置**：改 / 反驳（带技术理由）/ 记入 backlog。**没有「已读」这种处置。**
4. **忽略任何一条 = 必须显式写明理由。** 默默不处理 = 违规。理由只能是技术性的（见下「何时可正当忽略」），不能是「赶时间 / 觉得还好」。
5. **Critical 未清零不得合并 / 不得进下一项。** Important 未清零不得进下一项（除非显式反驳并记录）。

## 严重度分级（reviewer 必须给每条打级）

| 级别 | 含义 | 闸门 |
|---|---|---|
| **Critical** | 正确性/安全/数据风险、会坏的设计 | 立即修，**未清零禁止合并** |
| **Important** | 明显设计缺陷、规范违背、可维护性坑 | 进下一项前清零，或显式反驳+记录 |
| **Minor** | 风格、命名、小重复、可读性 | 当场修或记入 backlog（择一，不许「已读」） |
| **Positive** | 值得保留的设计/测试优点 | 记下，别在重构中弄丢 |

## 请求侧（怎么派 reviewer）

1. 确认 verify 已绿（无新鲜绿证据 → 先回 `verify`，别 review）。
2. 取 `BASE_SHA`（change 起点）、`HEAD_SHA`（当前）。
3. 用 `references/reviewer-template.md` 填四要素（DESCRIPTION / PLAN_OR_REQUIREMENTS / BASE_SHA / HEAD_SHA），`Task` 派 reviewer 子代理。
4. **要求结构化回传**：每条 = 级别 + 文件:行 + 问题 + 建议。reviewer 只回「看着还行」= 无效评审，重派并明确要它逐条对照 diff 与 `project.md` 反模式。

## 接受侧（怎么接，封堵「嘴上接受」）

流程：**读 → 复核 → 裁决 → 处置**。

- **禁止表演式接受**：不许用「你说得对！」「好建议！」「我马上改」开头。先**对着真实代码复核这条成不成立**，再行动。
- **每条都要落到 diff**：处置是代码改动（再跑 verify）或一句技术性反驳，**不是一句口头确认**。
- **不盲改**：reviewer 也可能错/缺上下文。改之前核：这条会不会破坏现有功能？是否与既定架构冲突？
- **逐条改、逐条验**：批量改完一把梭不算；每条 Critical/Important 改完要有对应验证（回 `verify`），别假设改对了。

### 何时可以正当忽略（须显式写理由）

- 建议会破坏现有功能 / 现有测试。
- reviewer 缺上下文，结论基于误解。
- 违反 YAGNI（没人调用的过度设计）。
- 与本栈/既定架构决策冲突。
- 兼容/历史原因必须保留。

→ 用技术理由说明，不带防御情绪；架构层冲突上交人类决策。**「我觉得没必要」不是理由。**

## 危险信号（出现即停 / 回退）

- reviewer 用了对话历史而非 diff，或就是你自己换个口吻自评。
- 评审回传没有分级，或只有「整体不错」一句。
- 你回「收到/有道理」之后**没有任何 diff 变化也没有书面反驳理由**——这就是嘴上接受实际忽略。
- Critical 还在却开始谈合并；或把 Critical 私自降级成 Minor 来过闸。
- 处置话术出现 `should` / `seems` / `大概没问题` / 「同义改写了一遍当作改了」。
- 反驳理由是「赶时间」「先这样」「精神上接受了」——非技术理由，不成立。

任一命中 → 停，回到对应铁律重做，不是绕过。

## 正反例

- **反例**：reviewer 报「Critical: `parseConfig` 未处理空文件会 panic（config.go:42）」。你回「好的有道理」，然后直接去写 document。→ 违反铁律 §3/§4：无 diff 变化、无书面理由 = 默默忽略。
- **正例**：同一条，你复核确认可复现 → 改 config.go 并补一条先红后绿的测试 → 回 `verify` 跑出绿 → 在评审回执里标这条「已修，见 commit」。另一条 Minor「变量名 `tmp` 含糊」你判断记入 backlog 并写明「非阻塞，下一次清理」。

## checklist（声明评审完成前逐条核）

- [ ] reviewer 是 fresh-context 独立子代理，喂的是模板 + diff，不是对话历史。
- [ ] 每条发现都有级别（Critical/Important/Minor/Positive）。
- [ ] 每条都有显式处置：改 / 反驳（技术理由）/ 记 backlog——无「已读」。
- [ ] 被忽略的每条都写了技术性理由。
- [ ] Critical 全清零；Important 清零或显式反驳并记录。
- [ ] 改过的 Critical/Important 都回 `verify` 跑过新鲜绿。

## 红线（反合理化）

> 违反规则字面 = 违反规则精神。任何「我遵守了精神」的解释不成立。

| 合理化借口 | 实际规则 |
|---|---|
| 这改动很直白，不用找人评审 | R2+ change 收敛后该评审就评审；「看着简单」正是漏设计坑的地方（铁律 §1）。 |
| 我自己再读一遍代码就当评审了 | 自评不是评审。必须 fresh-context 独立子代理 + diff（铁律 §1/§2）。 |
| 把改动口头讲给 reviewer 听就行 | 评审对象是真实 diff，不是你的转述（铁律 §2）。 |
| reviewer 说"整体不错"，那就过了 | 无分级、无逐条 = 无效评审，重派并要求逐条对照 diff 与项目反模式。 |
| 我回了"有道理"，算接受了 | 接受=代码改动或书面技术反驳，不是口头确认；只回话没 diff = 默默忽略（铁律 §3/§4）。 |
| 这条 Critical 现在没空，先合了再说 | Critical 未清零禁止合并；没空不是技术理由（铁律 §5）。 |
| 这条我觉得没必要，跳过 | 忽略必须写技术性理由（破坏功能/缺上下文/YAGNI/架构冲突/兼容），"觉得没必要"不算（铁律 §4）。 |
| 几条建议我一把改完，不用逐条验 | 逐条改逐条验，改完回 verify 跑新鲜绿，别假设改对了。 |
| reviewer 肯定对，照单全改 | 不盲改：先核会否破坏现有功能/冲突架构，reviewer 也会错。 |
| 把 Critical 降成 Minor 就能过闸 | 级别由问题性质定，不由过闸需要定；私自降级=作弊。 |
| 评审顶替 verify，绿不绿无所谓 | review 偏可读性/设计，不证伪正确性；完成仍由 verify 新鲜输出裁决，二者不互相顶替。 |

完成后 → R1+ 加载 `document` 出交付物；评审撞上学习信号（reviewer 抓到真设计缺陷/返工/同类问题重复出现）则下一步用 Skill 工具加载 `harvest` 沉淀经验。

遵循 `flow` 技能的质量红线。
