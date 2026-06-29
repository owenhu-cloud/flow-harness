---
name: plan
description: R2/R3 在 brainstorm 已确认方向后用——把选定方向落成可执行的设计 + 任务拆解，进门后不再发散。 · EN: turn the agreed direction into an executable design + task breakdown; no diverging past the gate (R2/R3, after brainstorm).
---

# plan — 落方案（R2/R3）

把 brainstorm 选定的方向变成具体、可执行的设计与任务拆解。**进了 plan 不再发散**。

适用档位 **R2 / R3**。在 Flow 流程中的位置：`brainstorm（门）→ 【plan（门）】→ implement → verify → document`。plan 的唯一产物是文档（design + tasks + 必要的图），**不写实现代码、不建代码脚手架、不跑实现**——那是 implement 的事；但可在 `docs/flow/<change>/` 下落图资产（如复杂图的 `assets/`）。

## 前置：brainstorm 硬门必须已过

方向 + 关键权衡已经用户**明确确认**，才进 plan。否则先用 `Skill` 加载 `brainstorm`。在 plan 里偷偷重新选型 = 把发散偷渡进规划阶段。

## 铁律（iron-laws，违反即作废）

1. **不在 plan 内换方向**。想换 → 退回 brainstorm 重新过门，不在计划里偷换选型。
2. **Open-Questions 门前清零**（或被用户显式接受），不带未决问题进 implement。
3. **每条 task 必须可独立验证**：单一职责、路径明确，且「验证方式」是**可运行的真实检查**（命令 / 可观测断言），不是「手测一下 / 应该没问题」。
4. **零占位**：design 与 tasks 里不出现 TBD / TODO / 「待定」/「加适当的错误处理」。要么写出具体行为，要么拆成独立任务。
5. **plan 不碰实现文件树**：不写实现代码、不建代码脚手架。产物仅 `design.md` + `tasks.md`（+ 图：Mermaid 默认 / 复杂流程·架构 Graphviz）；可在 `docs/flow/<change>/` 下创建图资产（如复杂图的 `assets/*.dot`+`.svg`），但不碰实现代码目录。
6. **收尾设人类 gate**：design + tasks 呈用户确认后，才加载 implement。

## 产出（给 AI，密集可解析）

`docs/flow/<change>/design.md`，固定骨架：

```markdown
# <change> 设计
## Context        —— 为什么做、约束、非目标
## Decisions      —— 选定方案 + 关键技术决策（每条带一句理由）
## Risks-Tradeoffs—— 已知风险、取舍、回滚策略
## Migration      —— 兼容 / 数据 / 灰度（无则写「无」）
## Open-Questions —— 仍未定的点（门前须清零或显式接受）
```

`docs/flow/<change>/tasks.md`，编号 + checkbox（同步进 `TodoWrite`）：

```markdown
- [ ] 1.1 <动词开头、单一职责、路径明确> — 验证方式：<可运行命令 / 可观测断言>
- [ ] 1.2 ...
```

拆解纪律细则、更多正反例见 `references/task-decomposition.md`（写任务前先读）。关键结构配图：用 `Skill` 加载 `diagram`（Mermaid 默认；复杂流程·架构图用 Graphviz），图落 `docs/`。

## 合理化借口 → 实际规则（压力下逐条钉死）

| 你会对自己说的话 | 实际规则 |
|---|---|
| 「想到个更好的方向，边写计划边换了」 | 换方向 = 退回 brainstorm 重新过门，**不在 plan 偷换** |
| 「这条任务很大，先写上，实现时再拆」 | 拆分是 plan 的职责；**写不出验证方式 = 还没想清，继续拆** |
| 「验证方式先写『手动测试』『看下效果』」 | 必须映射到可运行命令或可观测断言；写不出 = 任务定义不完整 |
| 「Open-Questions 留着，实现时顺便定」 | 门前清零或用户显式接受；带未决进 implement = 偷渡发散 |
| 「先把目录 / 脚手架建好再规划」 | plan **不碰实现代码树**（图资产目录除外）；脚手架是 implement |
| 「计划里写『加适当的错误处理』『TODO 补测试』就行」 | 占位语 = 计划缺陷，写出具体行为或拆成独立任务 |
| 「任务太细了，合并成一大条省事」 | 不可独立验证的合并条 = 黑盒；保持小而有序 |
| 「子代理草拟的 design 看着对，直接进门」 | 审**内容**（决策理由 / 风险 / 每条可验证性），不因「子代理说没问题」放行 |

## 危险信号（出现即停 / 回退）

- 某条 task 写不出「怎么知道它做完了」→ 没拆到位，**停，继续拆**。
- 任务间出现「先做完 A 才知道 B 怎么写」的隐藏依赖 → 假设未落地，回 Context 补清。
- 写计划时频繁回头改方向 / 选型 → 方向没真定，**回 brainstorm**。
- design 出现 TBD / TODO / 「待定」/「适当处理」→ 占位，补实或拆任务。
- 同一实体在不同任务里叫不同名字 → 命名漂移，统一后再进门。

## 一个正反例

```
坏:  - [ ] 2.1 实现用户登录 — 验证方式：测一下
     # 太大、动词模糊、验证不可执行 → 黑盒任务

好:  - [ ] 2.1 在 auth/login.go 加 ValidateCredentials(email,pw) → (User,error)；
        空密码 / 不存在用户返回 ErrInvalidCred
        — 验证方式：go test ./auth -run TestValidateCredentials，三条路径全绿
```

## 守护主上下文

派子代理（`Task` 工具）草拟 design / tasks 回传 artifact，**主线程审产物而非审议过程**。审的是内容：决策有没有理由、风险有没有回滚、每条任务能不能独立验证——不是看子代理「报了通过」就放行。

## 进门前 checklist（逐条勾，缺一条不进门）

- [ ] brainstorm 硬门已过（方向 + 权衡经用户确认）
- [ ] design.md 五节齐，Open-Questions 已清零或用户显式接受
- [ ] 每条 task 动词开头、单一职责、路径明确
- [ ] 每条 task 的「验证方式」可执行（命令 / 可观测断言），非「手测 / 应该没问题」
- [ ] 任务有序，后条不依赖前条未落地的假设
- [ ] 无 TBD / TODO / 占位语；实体命名跨任务一致
- [ ] 关键结构有图（Mermaid / 复杂流程·架构 Graphviz）
- [ ] 没碰实现代码 / 实现目录树（图资产目录除外）；产物只有 design + tasks（+ 图）

## 收尾 → 门 → 实现

**可选（高风险面）：跨模型对抗审计划**。人类 gate 前，若项目 `docs/flow/cross-verify` 声明了适配器，把 `design.md` 经 `cross-verify`（其派发器 `external-agent.sh`，对象从 diff 换成方案文本）喂异模型，指令「挑出设计缺陷 / 漏掉的风险 / 更优替代」，结构化回传后纳入 Decisions / Risks-Tradeoffs 复核——审的是**设计层盲点**，不替代用户拍板。不可用则跳过并说明。→ 详见 `cross-verify` 技能。

checklist 全过后，设一道**人类 gate**：把 design + tasks 呈给用户确认（R2/R3 可用 plan mode 让用户批准）。确认后 → 用 `Skill` 工具加载 `implement`，按 tasks 逐项 builder / verifier 对抗推进。完成判定由 verify + Stop hook Oracle（`docs/flow/verify-cmd`）裁决，不由 agent 自报。

遵循 `flow` 技能的质量红线。
