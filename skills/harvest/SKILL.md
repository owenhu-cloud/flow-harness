---
name: harvest
description: 一次 change 撞上学习信号后用——连续失败/升维到移交/返工/档位被推翻/verifier 抓到真 bug 时，把根因沉淀成一条可复用经验。无信号不触发。 · EN: capture a reusable lesson after a learning signal (repeated failure / escalation to handoff / rework / tier overturned / verifier found a real bug). No signal → don't trigger.
---

# harvest — 沉淀经验

**只在踩到学习信号时**触发，把一次真实的痛沉淀成一条能被关键词搜到、下次会自动进上下文的经验。无信号不写——避免知识灌水把高价值结论淹没。

## Flow 档位与位置

- 适用档位：R0–R3 全档，但**由信号触发，不由档位触发**。R0 也可能踩信号（如反复改一行都跑不绿）。
- 流程位置：在 `brainstorm → plan → implement → verify → document` 之后、本轮收尾时。verify/document 已出结论，此处只回收「这次为什么疼」。
- 与既有机制对齐：完成判定仍由 `verify` + Stop hook Oracle（`docs/flow/verify-cmd`）裁决；项目画像在 `docs/flow/project.md`（由 `profile` 维护）；升维表在 `flow` 技能。harvest 不发明召回引擎，靠原生上下文召回（见下）。

## 学习信号（命中任一即触发，否则不触发）

逐条钉死，不靠「感觉学到了点东西」：

1. **连续失败到升维**：同一问题反复修 ≥3 次未果，被迫升维（R↑）或换方案。
2. **升维到移交人类**：循环卡死，最终交回人类决策——说明 agent 侧缺一条规则。
3. **返工**：已声明「完成」的东西被打回重做（自己发现或被 verifier/用户打回）。
4. **判档被推翻**：用户或 verifier 推翻了你的 R 档判定（判低了漏流程，或判高了空转）。
5. **verifier 抓到真 bug**：`implement` 的对抗 verifier 找到真实缺陷（非同义改写、非措辞争议）。

> 反例（不触发）：一次就改对了；只是手生查了下文档；个人偏好之争。这些写进 lesson 是噪声。

## 铁律（iron-laws，不可违反）

1. **一信号一 lesson**：每条 lesson 必须能指回上面某个具体信号；指不回 → 别写。
2. **泛化结论必须可被搜到**：`generalization` 写成「下次遇到 <可检索症状/关键词> 时，应 <动作>」，不是「要细心」这种废话。
3. **根因穿透到机制层**：`root_cause` 要答「为什么会发生」，不是复述「发生了什么」。穿不透 → 标 `root_cause: 未定位`，宁缺毋滥。
4. **去重优先于新增**：写前先 `grep` 现有 `lessons/`，命中同根因 → 更新旧条目并刷新 `last_verified`，不开新条。

## 危险信号（出现即停 / 回退）

- 想写「下次更小心 / 多测一点 / 注意边界」——空泛，删掉重写成可执行规则，否则不写。
- 一次 change 想批量产出 >2 条 lesson——多半在灌水，回到「指回哪个信号」自检。
- lesson 内容与项目无关（纯语言通识）——不进 `lessons/`，该去查文档不是沉淀。
- 把「执行流水 / 这次怎么修的」当 lesson——那是 `document` 的活，harvest 只留可泛化结论。

## 产出

追加到项目 `lessons/<slug>.md`，字段格式见 `references/lesson-template.md`（含填写正反例）。一句话标题 + symptom/root_cause/fix/generalization/links/last_verified 六字段。

## 三态生命周期

```
候选(脑中/本轮草稿)  →  写入 lessons/(去重+轻量人审, 提交团队共享)  →  固化(复发者)
```

- **候选**：本轮信号触发，脑中或草稿。还没价值证明，不急着提交。
- **写入 `lessons/`**：去重通过 + 一眼人审过，落盘提交。靠原生召回——下次会话该文件进上下文即生效，**无需召回引擎**。
- **固化**：同一根因**复发**（再次踩同信号）→ 升级到强制路径：写进 `implement/references/antipatterns.md` 对应分区（让 verifier 每次扫描），或项目 `CLAUDE.md`（让每次会话必看）。一次性教训不固化，避免规则膨胀。

## 反 reward-hacking

- 「验证当时通过了所以根因不重要」——返工/被打回本身就是信号，根因必须定位或显式标 `未定位`。
- 「verifier 报的只是措辞 / 同义改写」——先确认是不是真 bug 再决定触发；是真 bug 不许降级成「风格问题」糊弄过去。
- 「这条以后肯定用得上先写着」——未指回信号的预防性 lesson 一律不写。

## Checklist（写入前逐项过）

- [ ] 能指回上面 5 个信号中的哪一个？指不回 → 不写。
- [ ] `grep lessons/` 去重过，未与现有条目同根因。
- [ ] `root_cause` 穿透到机制（否则标「未定位」）。
- [ ] `generalization` 含可被搜到的关键词 + 可执行动作。
- [ ] 复发的话，已评估是否该固化进 antipatterns/CLAUDE.md。

## 正反例

- **正**：verifier 抓到「漏 `await` 致浮动 promise，测试偶发绿」→ symptom「测试偶发通过/失败、CI flaky」，root_cause「async 函数返回 promise 未 await，断言早于副作用完成」，generalization「见 flaky async 测试先查未 await 的 promise」。可搜、可执行。
- **反**：「这次 bug 是因为代码写错了，下次写对就行」——无根因、无关键词、不可执行，删。

下一步：lesson 已落盘则本轮收尾；若复发需固化进强制路径，用 Skill 工具加载 `implement`（更新其 antipatterns）或回 `flow` 确认。需要把结论写成给人看的交付物时，用 Skill 工具加载 `document`。

遵循 `flow` 技能的质量红线。
