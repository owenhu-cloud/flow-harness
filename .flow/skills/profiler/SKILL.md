---
name: profiler
description: Use when .flow/profile.yml is missing/stale/profile.ready!=true, or when the project's build/test setup changed (new package manifest or CI config). Bootstraps the project-adaptive norms that feed the Oracle.
version: 1
---

# profiler — 自举项目自适应规范（L2）

产出 `.flow/profile.yml`，**首次必须人审后置 `profile.ready: true`**（Oracle 正确性是 L1 承重点）。

## 取证优先级（可靠性递降）

1. **CI 配置**（`.github/workflows/*`、`.gitlab-ci.yml`、`.circleci/` 等）——最可靠：CI 真正跑的就是验证函数。
2. **包/构建清单**（package.json scripts、Makefile、Cargo.toml、pyproject.toml、go.mod）。
3. **代码采样**：目录与命名约定、测试风格、领域词汇、可观测反模式。

## 必填字段（扁平点号键，见 profile.yml 注释）

- `commands.{build,lint,smoke,unit,integ,e2e}`：本项目存在的填命令，不存在留空。
- `oracle.{R0..R3}`：每 tier 由哪些命令键拼装（空格分隔）。
- `module_boundaries`：供 rubric「影响面」粒度。
- `antipattern_packs`：选用语言/框架反模式包（见 `.flow/refs/antipatterns.md`）。
- `conventions.{naming,test_style,doc_lang}`。
- 每个推断字段写 `field_meta.<key>: <置信度>|<日期>`。

## 降级链（无 Oracle 不进循环）

有 CI → 用 CI 命令；无 CI → 用清单推断；无测试 → Oracle 退化为 build+lint；无可信 verify → 该 tier 退回人类 gate（在 oracle.* 留空即可）。

## 收尾

`.flow/bin/flow profile-check` 自检每 tier 能否装配出 Oracle。请人审后置 `profile.ready: true`。

继承 `.flow/skills/_contract.md`。
