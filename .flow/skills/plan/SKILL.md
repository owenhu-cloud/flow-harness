---
name: plan
description: Use after brainstorm has converged on a direction (R2/R3), to turn that direction into an executable design and task checklist. Do not re-diverge here.
version: 1
---

# plan — 落方案（R2/R3）

把选定方向变为具体、可执行的设计。**不再发散**。

## 产出（给 AI，密集可解析）

- `changes/<id>/design.md`：Context / Decisions / Risks-Tradeoffs / Migration / Open-Questions。
- `changes/<id>/tasks.md`：编号 + checkbox（`- [ ] 1.1 ...`），路径明确。
- 关键结构配 Mermaid（调 diagram skill，落 `docs/`）。

## 执行位置

子代理草拟回传 artifact，**人审产物而非审议过程**（守护主上下文）。

## 收尾 → gate → 循环

设计完成设人类 gate。gate 通过后，由编排者执行：

```
.flow/bin/flow tier R2 --change <id>
.flow/bin/flow loop-start --change <id> --tier R2
```

继承 `.flow/skills/_contract.md`。
