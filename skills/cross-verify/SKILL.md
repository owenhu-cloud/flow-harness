---
name: cross-verify
description: 高风险/高不可逆 change 想用「不同模型/外部 agent」来对抗证伪、增强 verifier 独立性时用（R2+）——同模型自验怕盲点、builder 与 verifier 同源信心不足、需要异模型第二意见时。 · EN: cross-model / second-model verification — escalate the independent verifier or reviewer to a DIFFERENT model / external agent (via MCP tool or external CLI, e.g. Codex) for high-stakes changes when same-model self-verification risks blind spots.
---

# cross-verify — 把独立验证升级为跨模型

把独立 verifier / reviewer 的**执行者从「同模型子代理」升级为「不同模型 / 外部 agent」**，用模型异质性消除同源盲点。
**它升级「谁来验」，不新增「验什么」** —— 不是又一类检查，而是给既有对抗验证换一个独立大脑。
**且是多轮收敛闭环**：派发 → 摄取裁决 → 回修 → 再派，直到无 Critical 或用户显式接受残留——不是「派一次、看一眼」。

## 适用档位 + 位置

**R2–R3 的高风险 / 高不可逆面**（命中 `flow` 档位地板的面尤其推荐）。挂在 `implement` 的 verifier 与 `code-review` 的 reviewer **之上**，作为**模型独立性升级档**：
- 基线仍是 Flow 同模型 `Task` verifier / reviewer；
- 本技能是 **opt-in 升级，不是替换**：项目 `docs/flow/cross-verify` 声明了可用适配器才启用。

## 与邻接技能划界（正交，不重叠）

| 技能 | 管什么 | 谁来验 |
|---|---|---|
| `implement` verifier | 证伪正确性（边界/并发/错误路径/mutation） | 同模型子代理（基线） |
| `code-review` | 可读性 / 设计 / 命名 / 规范 | 同模型子代理（基线） |
| `verify` | 跑真实 build/test 命令、贴新鲜输出 | 确定性命令 |
| **`cross-verify`** | **把上面前两者的执行者换成异模型** | **不同模型 / 外部 agent** |

cross-verify 不替 `verify` 跑命令，也不替 `implement`/`code-review` 定义检查内容——只换大脑。

## 铁律（iron-laws，不可违反）

1. **异模型才算 cross。** verifier 必须是与 builder **不同的模型 / 外部 agent**，经 MCP 工具或外部 CLI 派发（适配器见 `references/adapters.md`）。同模型换个子代理 = 普通 `implement` verifier，**不得冒称跨模型**。
2. **opt-in + 降级必须显式。** 仅当 `docs/flow/cross-verify` 声明了可用适配器才启用；适配器不可用 / 未配置 → **降级回 Flow 同模型 `Task` verifier，并明说「未走跨模型，仅同模型验证」**。禁止把没跑跨模型说成跑了。
3. **诚实摄取裁决（不当圣旨、不当噪声）。** 外部 agent 的回传是**待核实证据**：要它回传**可核实的 文件:行 / 复现步骤 / 命令+输出**，自己复核 diff 再裁决。既不盲信自报「通过」，也不因「它是外部的」就无视它报的真问题。
4. **builder ≠ verifier 仍成立且被强化。** 跨模型天然满足角色分离；但 builder 不得当外部 verifier 的「转述人」**挑好听的报**——回传须原样可审计。
5. **完成仍由 `verify` 新鲜输出裁决。** 跨模型 verifier 说「没问题」**不替代**真实 build/test 命令证据；完成判定永远回 `verify` + Stop hook Oracle。

## 派发协议：多轮对抗闭环（工具无关）

不是「派一次、看一眼」，而是一个收敛闭环——直到无 Critical 或用户显式接受残留：

1. **派发**：经 `references/external-agent.sh dispatch <adapter> <prompt-file> <out-file>` 把 **change 描述 + 真实 diff/范围 + 期望行为 + 「对抗证伪，默认怀疑而非信任」** 喂外部 verifier，要求**结构化回传**（裁决 + 每条 级别/文件:行 + 复现/命令）。健康检查失败（exit 3）→ 降级回同模型并显式告知（铁律 §2）。
2. **摄取裁决**：读 out-file，**自己复核 diff** 核实每条（铁律 §3）；不盲信自报、不挑好看的贴（铁律 §4）。
3. **回修**：有 Critical/Major → 回 `implement` 的 builder 修（builder ≠ verifier，不得自演转述）。
4. **再轮**：修完**重派同一闭环**，直到无 Critical（Major 经修复或技术性反驳清零）或用户显式接受残留。
5. **收敛后**：完成仍由 `verify` 新鲜输出 + Stop hook Oracle 裁决（铁律 §5），跨模型「没问题」不顶替命令证据。

适配器 / 健康检查 / opt-in 写法 / 派发器内部细节 → 见 `references/adapters.md`。

## 危险信号（出现即停 / 回退）

- 同模型换个子代理，却在完成声明里写「已跨模型验证」。
- 适配器不可用却**静默当跑过**，或不告知降级。
- 外部裁决**照单全收**不复核 diff，或外部「没问题」就跳过 `verify`。
- 只贴外部报告里**好看的部分**，把它报的 Critical 藏掉。
- **派一次就收**：报了 Critical/Major 却不回修、不再派下一轮，直接标完成。
- 用 `should / seems / 应该 / 大概` 描述外部验证结果。

任一命中 → 停，回对应铁律重做。

## 正反例

- **反例**：「我又派了个子代理审了一遍，跨模型验证通过，标记完成。」→ 同模型冒称跨模型（违 §1）、未跑 verify（违 §5）。失格。
- **正例**：「`docs/flow/cross-verify` 配了 codex-mcp，调外部 verifier 喂 `BASE..HEAD` diff + 对抗指令，回传：`Critical: anchor.go:88 并发下 map 无锁写`（附复现）。复核 diff 确认可复现 → 回 builder 修 → `verify` 跑 `make test-unit` 全绿（fresh 输出附后）。」

## checklist（声明跨模型验证完成前逐条核）

- [ ] verifier 确是**不同模型 / 外部 agent**，经 MCP/CLI 派发，非同模型子代理冒充。
- [ ] `docs/flow/cross-verify` 已声明适配器；不可用时已**显式告知降级**。
- [ ] 外部回传是结构化的（裁决 + 文件:行 + 复现/命令），且我**自己复核过 diff**。
- [ ] 外部报的问题逐条落地（改 / 技术性反驳），没挑好看的贴。
- [ ] 完成仍由 `verify` 新鲜输出裁决，未用外部「没问题」顶替。

## 红线（反合理化）

> 违反规则字面 = 违反规则精神。任何「我遵守了精神」的解释不成立。

| 合理化借口 | 实际规则 |
|---|---|
| 我换个子代理审审就算跨模型了 | 必须是不同模型/外部 agent（§1）；同模型换子代理是普通 verifier，不得冒称。 |
| 适配器没配好，先当跨模型过了 | 不可用即降级回同模型并显式告知（§2），禁止假装跑过。 |
| 外部 agent 说没问题，那就过 | 外部裁决是待核实证据；要复核 diff，且完成仍由 verify 命令裁决（§3/§5）。 |
| 外部是另一个模型，它说的肯定对，照单全收 | 不盲信自报；要可核实的 文件:行/复现，自己复核（§3）。 |
| 它报的这条不好看，先不贴了 | 回传须原样可审计，不许挑好听的报（§4）。 |
| 跨模型验过了，verify 命令就不用跑了 | 跨模型不替代真实 build/test 证据；完成永远回 verify + Oracle（§5）。 |

跨模型 verifier 抓到真 bug → 回 `implement` 修；撞学习信号（跨模型抓出同模型漏掉的真 bug）→ 用 Skill 工具加载 `harvest` 沉淀。完成仍回 `verify` 出证据，再 `document`。

遵循 `flow` 技能的质量红线。
