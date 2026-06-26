---
name: profile
description: 首次在某代码库动手、或项目的验证/构建/风格规范发生变化时用——探测并固化「项目画像」到 docs/flow/project.md，让 verify/implement 懂这个项目而非一刀切套通用规范。 · EN: profile a codebase — detect & pin its real test/build/lint commands, style conventions and antipatterns into docs/flow/project.md (first task in a repo, or when conventions change).
---

# profile — 项目画像（治一刀切）

通用流程不懂「这个项目」：会用错测试命令、套错代码风格、扫错反模式。profile 把规范**一次探测、落盘持久化**，后续技能直接读、增量更新，不每次从零重探。

**适用档位 R1 / R2 / R3**（R0 直执不必固化）。流程位置：在 brainstorm→plan→implement→verify→document 的**最前面**——某代码库首个工程任务开工前先跑，给后续所有技能铺底。它喂的是 `verify` 与 Stop hook Oracle，不替代它们裁决。

## 何时跑

- 某代码库里**首个**工程任务开始时（`docs/flow/project.md` 不存在即先跑）。
- 验证/构建命令、技术栈、风格约定变化时**增量更新**对应字段，不整篇重写。
- `flow-bootstrap` hook 在会话开始比对清单（package.json / go.mod / Cargo.toml / pyproject.toml…）与 `project.md` 的 mtime，清单更新即提示画像可能过期——命中提示就回本技能更新，别拿过期命令去验证。

## 探测阶梯（可靠性递降，与 verify 同源）

1. **CI 配置**（`.github/workflows/*`、`.gitlab-ci.yml`、`.circleci/`）——最可靠：CI 真在跑的就是验证函数，照搬其命令。
2. **包/构建清单**（`package.json` scripts、`Makefile`、`Cargo.toml`、`pyproject.toml`、`go.mod`）。
3. **代码采样**：命名 / 格式化器 / import 顺序 / 错误处理；测试框架与目录约定。

高源胜低源；冲突时以 CI 为准并在画像里记一句分歧。派子代理（`Task` 工具）做发散探测，主线程只收回填后的画像。各源该抽什么、采样启发法、多源冲突细则见 **references/probing.md**。

## 铁律（不可违反）

1. **写进 `verify-cmd` 的命令必须在本机实跑过**，退出码语义确认无误——没实跑的命令不入 Oracle 燃料。看出来 ≠ 跑得通。
2. 探测可靠性 **CI > 清单 > 采样**；多源冲突以高源为准并记录，不挑顺手的。
3. 探测不出可自动验证命令 → `verify-cmd` **留空 + 显式告知用户**「该项目无法自动验证」，绝不凑半截命令。
4. **增量更新对应字段**，不整篇覆盖——保护手工修订与 harvest 沉淀的 lessons。

## 危险信号（出现即停 / 回退）

- 你正要把一条**从没在本机跑过**的命令写进 `verify-cmd` → 停，先实跑。
- 你打算把「应该能跑」的命令塞进 Oracle 燃料凑数 → 回退，留空。
- `project.md` 里的技术栈/命令与当前清单对不上 → 停，重探对应字段。
- 你把 `npm t` 与 `npm test`、同义改写当「不同命令」糊弄 → 写真实、原样可执行的命令串。

## 产出（两个文件，落 `docs/flow/`）

`docs/flow/project.md` —— 给 agent 读的画像：

```markdown
# 项目画像 (Flow)
> profile 维护。verify/implement 优先读本文件，不每次重探测。过期即增量更新。
## 命令
- test:  <真实测试命令>   (来源: CI|清单|采样，已实跑✓)
- build: <构建命令>       (来源…，已实跑✓)
- lint:  <lint 命令>
## 技术栈
- 语言 / 框架 / 版本 / 包管理器
## 风格约定
- 命名 / 格式化器 / import 顺序 / 错误处理（均来自代码采样，标出样本路径）
## 项目特异反模式
- <本仓库踩过、通用 antipatterns.md 没有的坑；与 harvest 的 lessons 互通>
## 元
- last_profiled: <日期>   sources: <CI/清单/采样>
```

`docs/flow/verify-cmd` —— 给 **Stop hook Oracle**（`hooks/flow-oracle.sh`）读的、机器可执行的**单行命令**，退出码即裁决：

```
<能独立判定「完成」的命令，如 npm test，或 go test ./... && go build ./...>
```

写下这一行即把本项目**接入独立 Oracle 硬门控**：此后每次试图收尾，Stop hook 都以独立进程跑该命令裁决，非 0 退出即打回。所以它必须先在本机实跑通过再写入（铁律 1）。

## 反 reward-hacking 红线

| 合理化借口 | 实际规则 |
|---|---|
| 一眼就是 Go 项目，`go test` 直接写进 verify-cmd 不用跑 | 看出来不等于跑得通；未实跑的命令不入 Oracle 燃料（铁律 1），会让 Oracle 误判。 |
| package.json 里有 test 脚本，照抄就行 | 脚本可能是占位（`"test": "exit 1"` / `echo no tests`）；写入前实跑确认它真跑测试。 |
| project.md 已存在，应该是最新的 | 「应该」不算；核对 last_profiled 与清单 mtime，bootstrap 报过期就更新，别拿过期命令验证。 |
| 探测不出测试命令，先把 build 写进 verify-cmd 凑个数 | 半截燃料会让 Oracle 误绿/误红；探测不出就留空 + 告知用户，退回人工确认。 |
| 整篇重写更省事 | 覆盖会抹掉手工修订与 lessons；只改变化的字段（铁律 4）。 |
| 采了一个文件看到风格就够了 | 单样本可能是异类；多点采样取众数，约定旁标样本路径。 |
| CI 和清单命令不一样，挑我顺手的写 | CI 是真在跑的验证函数，以 CI 为准并记一句分歧（铁律 2）。 |

## 正反例

- ✅ 探到 `go.mod` → 本机实跑 `go test ./... && go build ./...`，退出 0 → 才写入 `verify-cmd`，project.md 命令旁标「已实跑✓ 来源:清单」。
- ❌ 探到 `go.mod` 就把 `go test ./...` 写进 `verify-cmd` 没跑——若该仓库无测试文件，Oracle 会拿一条空跑命令永远判绿，门控形同虚设。
- ✅ bootstrap 提示「go.mod 晚于 project.md」→ 回本技能，只重探命令字段、更新 last_profiled，其余不动。
- ❌ 见提示过期就整篇重写 project.md，连 harvest 写进「项目特异反模式」的两条 lesson 一起抹了。

## 收尾 checklist

- [ ] 沿 CI→清单→采样 阶梯探完，命令来源已标注。
- [ ] 每条写入 `verify-cmd`/project.md 命令的，已在本机实跑、退出码语义确认。
- [ ] 探测不出自动验证命令时，`verify-cmd` 留空且已告知用户。
- [ ] 风格约定均标了样本路径；项目特异反模式与 harvest lessons 不冲突。
- [ ] last_profiled 与 sources 已更新；增量更新未覆盖无关字段。

## 交接

- 画像就绪后 → **下一步用 `Skill` 工具加载 `verify` 技能**读 project.md 命令并维护 verify-cmd；`implement` 读其风格约定与项目特异反模式。
- 命令/规范变化或 bootstrap 报过期 → 回本技能增量更新两个文件，保持 Oracle 燃料新鲜。

遵循 `flow` 技能的质量红线。
