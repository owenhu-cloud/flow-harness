# Flow

按复杂度路由的工程工作流，以原生 Claude Code 技能实现。

Flow 在执行工程任务前先对任务复杂度评级（R0–R3），据此选择相应深度的流程：低复杂度任务直接执行，高复杂度任务依次经过方向对齐、设计、对抗实现与验证。所有能力以技能（`SKILL.md`）形式提供，由 agent 通过原生 `Skill` / `Task` / `TodoWrite` / plan mode 调度；三支 hook 提供机制兜底。

## 设计目标

Flow 针对 Claude Code 项目级开发的四类痛点各落一条机制，并补上「完成由独立 Oracle 裁决」。

| 痛点 | 机制 |
|---|---|
| 能力衰减：靠人记得触发流程 | 路由纪律由 hook 每轮重注入，不随上下文增长被挤出 |
| 上下文污染：技能与仪式常驻主上下文 | 技能正文按需加载；重活派子代理、只回传蒸馏结果 |
| 经验不沉淀：踩过的坑散落各次会话 | 学习信号蒸馏成经验，写入项目 `lessons/` / `CLAUDE.md`（`harvest`） |
| 规范一刀切：通用流程不懂「这个项目」 | 项目画像把命令、风格、反模式特化到代码库（`profile`） |
| 完成自说自话：agent 自评通过 | 完成由独立进程跑真实验证命令裁决（`Stop` hook Oracle） |

## 安装

```
/plugin marketplace add owenhu-cloud/flow-harness
/plugin install flow@flow-harness
```

安装后无需初始化或逐项目配置。会话开始时 hook 注入路由提示，agent 在工程任务上自动评级并加载对应技能。单次跳过：在消息中加入 `#skip-flow`。

## 复杂度路由

四个维度各取 0–3，求和得到档位。

| 维度 | 0 | 1 | 2 | 3 |
|---|---|---|---|---|
| 影响面 | 单文件 | 单模块 | 多模块 | 跨系统 |
| 不可逆性 | 一键回滚 | 易回滚 | 难回滚 | 不可逆 / 生产数据 |
| 未知度 | 完全已知 | 小不确定 | 需调研 | 需全新方案 |
| 风险 | 无副作用 | 内部副作用 | 外部副作用 | 安全 / 数据 / 合规 |

| 总分 | 档位 | 流程 |
|---|---|---|
| 0–1 | R0 | implement → verify（冒烟） |
| 2–4 | R1 | implement（TDD）→ verify（单测）→ 简要交付 |
| 5–8 | R2 | research → brainstorm（门）→ plan（门）→ implement（对抗）→ verify（单测+集成）→ document |
| 9–12 | R3 | 同 R2，拆分多 change、各自 worktree、双门把关 |

档位在单个任务内判定一次并沿用。覆盖标记：`#R0`–`#R3` 强制档位，`#skip-flow` 跳过，`#new` 重新评级。

## 技能

| 技能 | 触发 |
|---|---|
| `flow` | 总路由：评级、流程选择、质量红线、升维 |
| `profile` | 首次进入某代码库，探测并固化项目画像 |
| `research` | 任务新颖或不确定，需先调研 |
| `brainstorm` | R2/R3 方向未定，先对齐（硬门） |
| `plan` | 方向已定，落为可执行设计与任务拆解（门） |
| `implement` | 编码：builder 实现 + 独立 verifier 对抗，角色分离 |
| `verify` | 声明完成前，运行项目真实验证命令并附新鲜输出 |
| `diagram` | 交付物需要架构 / 流程 / 状态 / 数据图 |
| `document` | 给人阅读的交付物 |
| `harvest` | 撞上学习信号时沉淀经验 |
| `writing-skills` | 新增或修改技能 |

技能正文按需加载，相互通过显式交接串联。

## 完成判定

完成由项目真实验证命令的新鲜输出裁决，分两级保证：

1. **纪律级**——质量红线 + builder/verifier 角色分离，agent 自带证据声明完成。
2. **机器级**——`Stop` hook 独立 Oracle（`hooks/flow-oracle.sh`）。项目存在 `docs/flow/verify-cmd` 时即接入：agent 每次试图收尾，该 hook 都以独立进程跑这条命令，退出码非 0 即 `exit 2` 打回、把失败输出经 stderr 回灌——agent 无法绕过。

接入 Oracle：首次进入项目用 `profile` 探测并写入 `docs/flow/verify-cmd`（单行命令，如 `npm test`）。未写则 Oracle 放行（零侵入），完成判定退回纪律级。需要更强的外部循环（独立进程持续驱动验证）时可正交叠加。

## 质量红线

所有技能继承以下约束：

1. 不得删除或弱化测试以使其通过；不确定显式标注；完成声明须附同轮新鲜验证输出。
2. builder 与 verifier 分离；实现者不得修改测试、断言或 CI 配置。
3. 实现完成不等于通过；由独立 verifier 对抗证伪。
4. R0/R1 先执行后确认，R2/R3 在门处先确认后执行；修复一处缺陷时排查同模块同类缺陷。
5. 交付物只含结论与取舍；执行过程记录不作为交付文档。

## 目录

```
.claude-plugin/
  plugin.json        插件清单（hooks → hooks/hooks.json，skills 自动发现）
  marketplace.json   单插件市场
hooks/
  hooks.json         三支 hook 声明（SessionStart / UserPromptSubmit / Stop）
  flow-bootstrap.sh  SessionStart：注入完整路由纪律
  flow-reinject.sh   UserPromptSubmit：每轮重注入一句短纪律
  flow-oracle.sh     Stop：独立 Oracle，跑 docs/flow/verify-cmd 裁决完成
skills/
  flow/SKILL.md      总路由技能
  profile/SKILL.md   项目画像（写 docs/flow/project.md + verify-cmd）
  <name>/SKILL.md    各流程技能
  implement/references/antipatterns.md   verifier 扫描用反模式目录
docs/
  DESIGN.md          设计文档
  flow/              运行时产物（project.md 画像 / verify-cmd Oracle 燃料 / 各 change 上下文）
```

## 设计

见 [`docs/DESIGN.md`](docs/DESIGN.md)。

## License

MIT
