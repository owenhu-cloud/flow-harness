# Flow — 轻量项目级 Agent 工作流框架

> 运行时：Claude Code（仅）· 面向 4–5 人小队 · 取向：保质前提下最大化轻量

Flow 是一个**带三层嵌套反馈回路的控制系统**，让流程能力常驻在线、主上下文干净、经验可沉淀、规范随项目自适应，并让「完成」由独立 Oracle 裁决而非 agent 自说自话。

完整技术设计见 `docs/Flow-技术设计.md`。本 README 是落地实现速查。

## 三层回路

| 回路 | 时间尺度 | 机制 | 记忆载体 |
|---|---|---|---|
| **L1 任务回路** | 秒–分 | Oracle 闭环（Stop hook 驱动、按 tier 有界） | `.flow/runs/<hash>/loop-history.jsonl` + git |
| **L2 项目回路** | 天–周 | 项目画像自举 + 漂移刷新 | `.flow/profile.yml` |
| **L3 框架回路** | 周–月 | lessons 捕获→晋升→固化 | `lessons/` |

互锁：L2 给 L1 喂 Oracle 命令；L1 失败历史喂 L3 蒸馏 lessons；L3 反向精修 L2/反模式/rubric。

## 控制平面（hooks，运行在主上下文外）

| Hook | 脚本 | 职责 |
|---|---|---|
| UserPromptSubmit | `.flow/kernel/router.sh` | 判级/沿用黏滞 tier + 召回 lessons + 注入裁决 |
| Stop | `.flow/kernel/loop-controller.sh` | **L1 Oracle 闭环引擎**（核心） |
| PreCompact | `.flow/kernel/checkpoint.sh` | 压缩前落盘 run 状态 |
| SessionStart | `.flow/kernel/restore.sh` | 新会话注入续连提示 |

`.flow/bin/flow` 是编排者显式调用的 CLI。`.flow/kernel/lib.sh` 是共享库。

## Oracle 闭环（L1）怎么工作

1. 设计通过 gate 后：`flow loop-start --change <id> --tier R2`
   —— 从 `profile.yml` 装配**冻结的** verify 命令（agent 改不了），按 tier 取迭代上限。
2. builder（TDD）→ verifier（对抗）→ agent 试图结束。
3. **Stop hook 拦截**：
   - agent 发 `<promise>FLOW_DONE</promise>` → hook **独立运行 verify**（Oracle）。通过则放行；失败则喂回输出 + 升维，继续。
   - 无信号 → 重喂任务 + 历史 + 认知升维动作。
   - 到 tier 上限 → 负责任移交人类（不无限循环）。
   - `<flow-abort>原因</flow-abort>` 放弃；`<flow-pause>` 暂停。

与 pua-loop 的区别：**默认有界、Oracle 来源受控（仅来自人审 profile）、无 Oracle 不进循环**。

## 安装（一条命令，装完即用）

```bash
# 在框架仓库里执行，把 Flow 装进你的项目：
bash install.sh /path/to/your-project
```

它自动完成全部配置：复制 `.flow/`、把 4 个 hook 幂等合并进目标的 `.claude/settings.json`（不动你原有配置）、把 `.flow/runs/` 加进 `.gitignore`、并**自动探测项目的构建/测试命令**生成 `profile.yml`（识别 npm/pnpm/yarn/bun、Cargo、Go、Python、Makefile）。

装完即用——**之后正常对话即可，无需记任何命令**：router 每轮自动判级并注入裁决；R2/R3 设计确认后，编排者按注入指引自动驱动 Oracle 闭环。

卸载：`bash uninstall.sh /path/to/your-project`（摘除 hooks 并移除 `.flow/`，保留你其它配置）。

### 可选手动操作

```bash
.flow/bin/flow profile-init           # 重新自动探测 profile（换了构建工具后）
.flow/bin/flow profile-check          # 自检每 tier 能否装配出 Oracle
.flow/bin/flow loop-status            # 查看当前循环与历史
.flow/bin/flow loop-stop              # 手动停止循环
```

> 人工覆盖：消息含 `#R0`..`#R3` 强制 tier · `#skip-flow` 跳过 · `#new` 重判 · `#no-loop` 关本 change 循环。

自检：`bash .flow/kernel/selftest.sh`

## 依赖

`bash`（3.2 兼容）、`jq`、`perl`（可移植超时）、`md5`、`git`。无需 `timeout`、无需 YAML 库。

## 复杂度路由（rubric）

四维各 0–3 求和 → tier：影响面 / 不可逆性 / 未知度 / 风险。
`0-1=R0直执 · 2-4=R1轻流程 · 5-8=R2标准 · 9-12=R3项目`。阈值见 `.flow/config.yml`。

## 目录

```
.flow/
  config.yml          通用契约配置（路由阈值/循环预算/信号）  [提交]
  profile.yml         项目自适应规范（L2，人审）             [提交]
  kernel/             控制平面 hooks + lib + selftest        [提交]
  bin/flow            CLI                                    [提交]
  refs/antipatterns.md 反模式目录                            [提交]
  skills/             各 SKILL.md + _contract.md             [提交]
  runs/<hash>/        loop.yml/state.json/history（本地）    [gitignore]
specs/ changes/ lessons/   AI 真源与共享知识                [提交]
docs/                 人类交付物 + Mermaid                   [提交]
```

## 自测

```bash
bash .flow/kernel/selftest.sh    # 覆盖所有关键路径，退出码=失败数
```
