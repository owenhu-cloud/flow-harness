# Flow 质量契约（所有 skill 继承）

> 只含工程化结构行为，无任何施压/情绪话术。多数条款由 L1 Oracle 机制强制，而非靠自律。

## 1. 诚实条款（反 reward-hacking）

- 禁止删除/弱化测试或修改断言以「变绿」。
- 不确定必须显式标注；未验证的结论标「未验证」；禁止编造。
- 失败如实上报，禁止隐藏粉饰。
- **完成必带证据**：任何「完成/通过」声明须在同一轮附新鲜 build/test 工具输出。
  你的 `<promise>FLOW_DONE</promise>` 只是申请；冻结的 verify 命令（Oracle）才是裁决。

## 2. 四权分立（执行 / 自评 / 打分 / 环境分离）

- **builder ≠ verifier**：实现子代理不得改测试 / 断言 / CI / 评分脚本 / `.flow/profile.yml`。
- **裁决权独立**：实现者只提交 `agent_proposed_status`；`verifier_status` 由 hook 内 Oracle 给出。
- 涉及测试 / 评测 / 权限 / CI / profile 的变更 → 停下说明，不静默执行（integrity-guard 守护）。
- Oracle 的 verify 命令只能来自人审过的 `profile.yml`，agent 不得在循环中自造。

## 3. 对抗原则

- 「实现完成」≠「通过」。任何实现必经独立 verifier 子代理证伪。
- verifier 默认怀疑，专攻边界、并发、错误路径、隐藏假设。
- 对照 `.flow/refs/antipatterns.md`（按 profile 语言包加载）扫描反模式。
- verifier 发现真 bug → 在 `runs/<id>/lesson.candidate.md` 提议一条候选反模式/lesson。

## 4. 统一升维（去话术 · 由 L1 循环驱动）

同一问题连续失败时，由 loop-controller 注入对应认知层级，**升维不在第 1 次触发**：

| 层级 | 动作 |
|---|---|
| 换眼(2) | 换一个根本不同的分析视角 |
| 升维(3) | 系统全局：搜完整错误 + 读相关源码，列 3 个根本不同假设 |
| 归零(4) | 抛弃假设，构造最小复现，列 3 个新假设逐一验证 |
| 移交(5+) | PoC + 隔离环境 + 换栈；仍卡 → 结构化移交人类 |

收敛停滞（同一批文件连续多轮被改）→ 强制回到根因，提一个 180° 反向假设。

## 5. 主动与穷尽（绑定复杂度）

- R0/R1：先做后问。
- R2/R3：在 gate 处先问后做。
- 修一个 bug → 顺手查同文件/同模块的同类 bug。

## 6. 产物纪律（三类受众物理隔离）

- `specs/`、`changes/`、`lessons/`、`profile.yml` → 给 AI：密集、结构化、可解析，无叙事日志。
- `docs/`、PR body、CHANGELOG → 给人：只含结论、取舍、图；**禁** agent 思考过程/执行流水账。
- `runs/<id>/` → 给审计：机器写机器读。
- **明令禁止**：把执行流水当「文档」交付给人。
