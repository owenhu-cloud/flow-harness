# 原生技能最小格式 · CSO · 渐进披露

本文是 `writing-skills` 的深度参考。SKILL.md 已给铁律，这里给"怎么落字"的细则。

## 1. 一支技能 = 一个目录

```
skills/<name>/
  SKILL.md            # 必有，薄而密
  references/*.md     # 可选，深主题/超 120 行才拆
```

- 无 CLI、无注册表、无 manifest。建好 `SKILL.md` 即被 Claude Code 自动发现。
- `<name>` 用 kebab-case，**一字不差等于目录名**；不一致则技能不会被正确加载。
- 不要在 `flow` 技能的「技能地图」里发明与现有路由冲突的条目；新增技能只在地图补一行指针，不改既有语义。

## 2. frontmatter 只有两个键

```yaml
---
name: <kebab，==目录名>
description: <中文触发条件> · EN: <英文 CSO 关键词>
---
```

- **只有** `name` 和 `description`。不加 version/author/tags 等——多余键是噪声。
- `description` 回答唯一问题：**"什么时候该加载我？"** 不回答"加载后做什么"。
- 结构：`<谁/何时触发，附可检索症状> · EN: <english keywords>`。中文为主（项目主语言），英文尾巴是给跨语言检索兜底。

## 3. CSO（Claude Search Optimization）——把 description 写成能被命中

description 是检索入口。命中靠的是"用户/agent 当时会怎么描述这个麻烦"，所以要前置：

- **症状与报错关键词**：`flaky`、`hang`、`timeout`、`段错误`、`卡住`、具体报错串。
- **同义词**：超时/卡死/无响应；回退/还原/revert。
- **工具/命令名**：`pytest`、`go test`、`docker compose`。
- **触发时机短语**：「声明完成前」「改配置前」「第一次在某库动手时」。

**禁**：把正文步骤写进 description。实测——description 含工作流摘要时，agent 读完就自以为懂，跳过正文规则，纪律失效。description 越像"目录条目"、越不像"教程"，越好。

## 4. 正文骨架（按需取用，不是全填）

推荐顺序，缺省项删掉而非留空标题：

1. 一句话定义（这技能到底纠正什么错）。
2. 适用档位 + 流程位置（R0–R3 / brainstorm→plan→implement→verify→document 的哪一段）。
3. 铁律 / 核心规则。
4. 红线表（行为/纪律类必有）。
5. 危险信号（出现即停/回退）。
6. 1–2 个具体正反例。
7. 可执行 checklist。
8. 显式交接：「下一步用 Skill 工具加载 X」。
9. 末行：`遵循 `flow` 技能的质量红线。`（一字不差）。

正文是"给压力下的 agent 的硬约束"，不是科普。每句话要么是规则、要么是能照抄/照避的例子；删掉所有背景叙事。

## 5. 渐进披露——主文件薄，深内容下沉

| 情况 | 处理 |
|---|---|
| 正文 ≤ ~120 行且单主题 | 全留 SKILL.md。 |
| 出现某个能独立成篇的深主题 | 拆 `references/<topic>.md`，正文留一句指针。 |
| 正文 > ~120 行 | 强制拆分；SKILL.md 只保留触发命中后"立刻要用"的规则。 |
| 大段模板/清单/表格 | 下沉到 references，正文给链接。 |

目的：命中技能时只加载最小必要 token；深内容在 agent 真正动手那一刻才读。SKILL.md 是"索引 + 硬规则"，references 是"展开"。

## 6. 反 reward-hacking 的措辞纪律（写任何验证/完成类技能时套用）

- 不写 "should / seems / 大概没问题 / 应该可以"——换成可检验的硬约束。
- 不允许"同义改写原任务"冒充完成；完成判定一律交 verify + Stop hook Oracle（见 `docs/flow/verify-cmd`）。
- 不允许"信任子代理自报通过"——要求贴新鲜命令输出作为证据。
- 项目特有规范从 `docs/flow/project.md`（项目画像）取，不一刀切套通用规范。

这三类借口是行为类技能最常见的逃逸口；新技能但凡碰到"判定是否完成"，红线表里必须各钉一条。
