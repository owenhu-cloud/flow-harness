# 模型路由：执行降档，判断与验证不降档

Flow 的模型选择按**角色**定，不按 Codex / Claude Code 品牌定。目标是把预算花在最能降低返工的位置：判断与验证保持强模型，明确执行可以降一档。

## 角色分层

| 角色 | 做什么 | 模型档位 |
|---|---|---|
| Orchestrator / Planner | 判档、方向取舍、架构切分、风险决策 | 最强可用 |
| Executor | 落地已拆清楚、边界明确、可机检的子任务 | 默认低一档 |
| Verifier / Reviewer | 方案审、diff 审、边界/错误路径/并发证伪 | 最强可用，优先异模型 |
| Deterministic Verify | build/test/lint/coverage/Oracle | 非 LLM，按真实命令裁决 |

## 路由规则

- R0/R1：主 agent 直接做；无需跨模型执行，避免调度成本。
- R2：实现可用标准档；方案、边界、review 使用强档；高风险面走 `cross-verify`。
- R3：先用强档做 plan 与任务拆分；只有任务满足“规格完整、彼此独立、可机检验收”时，才允许 `cross-execute` 派低一档执行者。
- 不确定任务难度时上调一档；不要让弱模型承担接口设计、迁移策略、权限、安全、数据一致性判断。
- 评审不降档。评审省下的 token 通常会以漏 bug、返工和回滚成本还回去。

## 适配到 Codex / Claude Code

- Codex CLI：`external-agent.sh dispatch` 使用 `CROSS_VERIFY_EFFORT`（默认 `high`）；`dispatch-write` 使用 `CROSS_EXECUTE_EFFORT`（默认 `medium`）。
- Claude Code 子代理：执行 brief 可指定预算/标准执行者；spec 评审、质量评审、plan-review 需标注强 reviewer。若运行环境不能显式选模型，也必须在 brief 中表达该档位意图。
- 多模型时优先保持 builder 与 verifier 异源：谁建不重要，关键是“强验证者不是同一个大脑”。

遵循 `flow` 技能的质量红线。
