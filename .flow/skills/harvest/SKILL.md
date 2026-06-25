---
name: harvest
description: Use at the end of a run that hit a learning signal (failure escalation>=3, loop handoff, rework, tier override, or a real bug found by verifier) to distill one reusable lesson.
version: 1
---

# harvest — 蒸馏经验（L3 学习闭环）

**只在有信号时**触发（见 `config.yml` 的 `harvest.*`），避免知识灌水。

## 输入

`runs/<id>/manifest.json` + `runs/<id>/loop-history.jsonl` + git diff。

## 产出候选（`runs/<id>/lesson.candidate.md`）

```yaml
symptom:        # 触发条件/症状
root_cause:     # 根因
fix:            # 修复
generalization: # 可泛化结论（下次怎么避免）
links:          # 关联路径/模块/既有 antipattern/profile 字段
last_verified:  # 日期（老化降权用）
```

## 三态生命周期

候选(本地 runs) → 去重 + 轻量人审 → 晋升入 `lessons/`（committed） → 复发者固化进
`.flow/refs/antipatterns.md` / rubric 阈值 / `profile.yml`。

召回：router 按路径/标签 top-k 注入，老化降权（非硬删）。

继承 `.flow/skills/_contract.md`。
