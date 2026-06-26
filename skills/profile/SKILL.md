---
name: profile
description: 首次在某代码库动手、或项目的验证/构建/风格规范发生变化时用——探测并固化「项目画像」到 docs/flow/project.md，让 verify/implement 懂这个项目而非一刀切套通用规范。 · EN: profile a codebase — detect & pin its real test/build/lint commands, style conventions and antipatterns into docs/flow/project.md (first task in a repo, or when conventions change).
---

# profile — 项目画像（治一刀切）

通用流程不懂「这个项目」，会用错测试命令、套错代码风格、扫错反模式。profile 把规范**一次探测、落盘持久化**，后续技能直接读、增量更新，不每次从零重探。

## 何时跑

- 某代码库里**首个**工程任务开始时（`docs/flow/project.md` 不存在即先跑）。
- 验证/构建命令、技术栈、风格约定发生变化时**增量更新**对应字段，不整篇重写。
- `flow-bootstrap` hook 在会话开始比对清单（package.json / go.mod / Cargo.toml / pyproject.toml…）与 `project.md` 的 mtime，清单更新即提示画像可能过期——命中提示就回本技能增量更新，别拿过期命令去验证。

## 探测（可靠性递降，复用 verify 的阶梯）

1. **CI 配置**（`.github/workflows/*`、`.gitlab-ci.yml`、`.circleci/` 等）——最可靠，照搬其命令。
2. **包/构建清单**（`package.json` scripts、`Makefile`、`Cargo.toml`、`pyproject.toml`、`go.mod`）。
3. **代码采样**：命名 / 格式化器 / import 顺序 / 错误处理 习惯；测试框架与目录约定。

派子代理（`Task` 工具）做发散探测，主线程只收回填后的画像，保护主上下文。

## 产出（两个文件，均落 `docs/flow/`）

`docs/flow/project.md` —— 给 agent 读的画像：

```markdown
# 项目画像 (Flow)
> profile 维护。verify/implement 优先读本文件，不每次重探测。过期即增量更新。
## 命令
- test:  <真实测试命令>   (来源: CI|清单|采样)
- build: <构建命令>
- lint:  <lint 命令>
## 技术栈
- 语言 / 框架 / 版本 / 包管理器
## 风格约定
- 命名 / 格式化器 / import 顺序 / 错误处理 习惯（均来自代码采样，标出样本路径）
## 项目特异反模式
- <本仓库踩过、通用 antipatterns.md 没有的坑；与 harvest 的 lessons 互通>
## 元
- last_profiled: <日期>
```

`docs/flow/verify-cmd` —— 给 **Stop hook Oracle**（`hooks/flow-oracle.sh`）读的、机器可执行的**单行命令**，退出码即裁决：

```
<能独立判定「完成」的命令，如 npm test，或 go test ./... && go build ./...>
```

写下这一行即把本项目**接入独立 Oracle 硬门控**：此后 agent 每次试图收尾，Stop hook 都会独立跑该命令裁决，非 0 退出即打回。探测不出可自动验证命令时，**verify-cmd 留空**并显式告知用户「该项目无法自动验证」，不留半截命令造成误判。

## 交接

- 画像就绪后 → `verify` 读 `project.md` 的命令并维护 `verify-cmd`；`implement` 读其风格约定与项目特异反模式。
- 命令/规范变化 → 回到本技能增量更新两个文件，保持 Oracle 燃料新鲜。

遵循 `flow` 技能的质量红线。
