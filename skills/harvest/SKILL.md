---
name: harvest
description: 一次 change 撞上学习信号后用——连续失败/升维到移交/返工/档位被推翻/verifier 抓到真 bug 时，把根因沉淀成一条可复用经验。无信号不触发。
---

# harvest — 沉淀经验

**只在有信号时**触发，避免知识灌水。信号：同一问题连败到升维≥3、循环移交人类、发生返工、用户推翻了你的判档、verifier 抓到真 bug。

## 产出（追加到项目 `lessons/<slug>.md`）

```markdown
# <一句话标题>
- symptom:        触发条件 / 症状
- root_cause:     根因
- fix:            修复
- generalization: 可泛化结论（下次怎么避免）—— 写得能被关键词搜到
- links:          关联路径 / 模块 / 反模式
- last_verified:  日期
```

## 三态生命周期

候选（脑中/草稿）→ 去重 + 轻量人审 → 写入 `lessons/`（提交、团队共享）→ 复发者固化进
`implement/references/antipatterns.md` 或写进项目的 `CLAUDE.md`，让它每次都被看到。

> 召回靠原生：把高价值结论沉淀进项目 `CLAUDE.md` 或 `lessons/`，下次会话自然进上下文——不需要任何召回引擎。

遵循 `flow` 技能的质量红线。
