# Flow 使用手册

面向使用者：怎么装、它如何自动工作、每项能力给你什么、如何接入机器级门控、常见问题。架构原理见 [`DESIGN.md`](DESIGN.md)。

## 1. 这是什么 / 给谁用

Flow 是一个 Claude Code 插件，让 agent 在动手前先判断任务复杂度，再按复杂度选择「该走多重的流程」——小任务直接做，大任务才上方向对齐、设计、对抗实现、验证与交付。它解决的是「agent 对什么任务都一个力度、要么过度仪式、要么草草了事、还会删测试假装通过」。

适合：用 Claude Code 做项目级开发、希望复杂改动有纪律、希望「完成」有机器把关的个人与团队。

## 2. 安装

```
/plugin marketplace add owenhu-cloud/flow-harness
/plugin install flow@flow-harness
```

装完即生效，无需逐项目配置。确认是否加载成功：

```
claude plugin list      # flow@flow-harness 应为 ✔ enabled
```

## 3. 它如何自动工作

你照常提需求即可。每个工程任务，agent 会：

1. **判档**：用四维（影响面 / 不可逆性 / 未知度 / 风险，各 0–3）求和，得 R0–R3，并用一句话告诉你：「这是 R2（…=7），走 brainstorm→plan→门→implement→verify→document」。
2. **按档走流程**：见下表。
3. **完成必带证据**：任何「完成 / 通过」声明都附同轮新鲜的 build/test 输出；口头「应该没问题」不算。

| 档位 | 你会经历什么 |
|---|---|
| **R0** 直执 | agent 直接改 + 冒烟验证。先做后问。 |
| **R1** 轻流程 | TDD 实现 → 单测 → 一句话交付。 |
| **R2** 标准 | （新颖则先调研）→ **brainstorm 与你对齐方向**（硬门，需你点头）→ **plan 出设计+任务**（门）→ implement（builder + 独立 verifier 对抗）→ verify（单测+集成）→ document。 |
| **R3** 项目 | 同 R2，但拆成多个 change、各自隔离、双门把关。 |

R2/R3 会在两处**停下等你确认**（brainstorm 方向门、plan 设计门）——这是设计使然，避免大改动一路狂奔到错方向。

### 覆盖与控制

在你的消息里加这些标记即时生效：

- `#R0` … `#R3` —— 强制档位。
- `#skip-flow` —— 本次不走 Flow。
- `#new` —— 对当前任务重新判档。

**档位地板**：当任务触及数据库迁移 / 认证授权 / 密钥 / CI 发布 / 支付 / 生产数据等敏感面时，档位不会低于 R2（即便你或 agent 想压低）。这是刻意的安全垫。

## 4. 接入机器级门控（推荐）

默认 agent 自带证据声明完成（纪律级）。要让「完成」由**独立进程**裁决、agent 绕不过，接入 Oracle：

1. 首个任务让 agent 跑 `profile`——它探测并写下 `docs/flow/project.md`（你项目真实的 test/build/lint 命令、风格、反模式）与 `docs/flow/verify-cmd`（单行验证命令，如 `npm test`）。
2. 此后 agent 每次试图收尾，`Stop` hook 都会以独立进程跑三道门：
   - **A 完整性门**：扫 git diff，发现删测试 / 注入 `.skip` / 删断言就打回——堵「删测试变绿」。
   - **B 验证命令门**：跑 verify-cmd，非 0 即打回，把失败输出回灌给 agent 继续修。
   - **B2 测试数基线门**：通过测试数掉到基线以下就打回——堵「测试数悄悄变少」。
3. 任一不过，agent 无法声明完成。未写 verify-cmd 则 Oracle 放行（零侵入）。

**让门更可信**：把 `docs/flow/verify-cmd`、`docs/flow/test-count` 提交进版本控制并在 review 时关注其变更（防被改低）。

**正当地删/改测试**：确属合理的测试增删（非掩盖失败）时，提交一个 `docs/flow/verify-allow-test-changes` 空文件作显式豁免（须已提交才生效，留审计痕迹）。

**大测试集降本**：若每次收尾全量跑测试太慢，创建 `docs/flow/verify-cache`（空文件）开启「自上次绿以来代码未变就跳过」。默认关闭；注意：测试依赖 `.gitignore` 文件（.env/fixtures）时不要开（指纹看不到它们的改动）。

## 5. 能力详解

技能按需自动加载，你一般无需手动调；了解它们能让你知道 agent 在每一步给你什么、产物落在哪。

### 理解项目（只读，先看懂再动手）

| 技能 | 何时 | 给你什么 |
|---|---|---|
| `profile` | 首次进某代码库 | `docs/flow/project.md`：真实命令 + 风格约定 + 项目特异反模式；并接入 Oracle |
| `codebase-analysis` | 陌生 / 大型库要先懂结构 | `docs/flow/codemap.md`：技术栈表 + 架构图 + 模块职责 + 入口 + 一条主流程生命周期 + 「去哪找 X」查找表 |
| `tech-debt-audit` | 盘健康度 / 排重构优先级 | 根目录可复跑 `TECH_DEBT_AUDIT.md`：按 churn×complexity 的风险表，每条带 `file:line`，含「看着差其实合理」防误报节 |
| `impact-analysis` | 改某处之前算波及面 | `docs/flow/<change>/impact.md`：受影响文件 + 应跑测试范围（= verify 下限）+ 高风险点 |

四者职责互斥：profile 答「怎么跑/什么风格」、codebase-analysis 答「结构长什么样」、tech-debt-audit 答「哪里烂」、impact-analysis 答「这次会动到谁」。

### 调研与对齐

| 技能 | 何时 | 给你什么 |
|---|---|---|
| `research` | 任务新颖 / 不确定，需外部信息 | 派子代理 fan-out，只回传带引用的结论。**浅档**默认；**深档**（高风险/不可逆决策）加对抗证伪回环 + 引用完整性校验 + 源可信度分级 + 落盘，并以 `verify-citations.sh` 做收尾硬门（每断言 ≥3 独立源、URL 可达，不过不算完成） |
| `brainstorm` | R2/R3 方向未定 | 苏格拉底澄清 + 2–4 个本质不同候选 + 取舍，收敛到一个方向（需你明确点头才进 plan）。Flow 的「规格澄清」即在此 |
| `plan` | 方向已定 | `design.md`（Context/Decisions/Risks/Migration/Open-Questions）+ `tasks.md`（编号、每条带可运行的验证方式）。进门不再发散 |

### 实现与验证

| 技能 | 何时 | 给你什么 |
|---|---|---|
| `implement` | 写代码（R1+） | builder 按 TDD 实现，独立的 verifier 子代理对抗证伪；两角色不得合并。完成声明附 verifier 的独立结论 |
| `systematic-debugging` | 改了又坏 / 不知根因 | 四阶段「复现→根因→最小修复→防回归」，铁律「无根因不提修复」；定位根因+写失败测试后把修复交回 implement |
| `verify` | 声明完成前 | 找到并跑项目真实验证命令，按档位跑足深度，贴新鲜输出作证据 |
| `code-review` | 交付 / 合并前要第三方视角 | 派独立 reviewer 子代理用模板 + diff 评审，按 Critical/Important/Minor 分级；忽略评审须写技术理由。与 implement 的对抗 verifier 互补（review 偏可读性/设计，verifier 偏证伪正确性） |
| `subagent-driven-development` | R2/R3 一串任务要逐个隔离落地 | 每个任务派 fresh 子代理（防上下文串味）+ spec/质量双评审 + 按难度分模型 |

### 交付与收尾

| 技能 | 何时 | 给你什么 |
|---|---|---|
| `diagram` | 交付需要图 | 只产可渲染的 Mermaid（架构/流程/状态/数据），落 `docs/` |
| `document` | 给人看的交付物（R1+） | 只含结论、设计取舍、关键图——**不含执行流水账**。在 verify 之后，只描述已验证为真的状态 |
| `finishing-a-development-branch` | change 干完要收尾 | 合并 / 开 PR / 丢弃的决策树；收尾前必过 verify+Oracle，脏分支不堆积 |
| `harvest` | 撞上学习信号 | 把一次真实的痛（连败/返工/判档被推翻/verifier 抓真 bug）沉淀成可被关键词搜到的经验，写入 `lessons/`。无信号不写 |

### 元

`writing-skills` —— 要给 Flow 加 / 改一支技能时用：先写「没有此技能时 agent 会怎么做错」的失败场景，再写最小规则；定义原生技能的最小格式与红线表写法。

## 6. 常见问题

**Oracle 好像没生效？** 先 `claude plugin list` 确认 `✔ enabled`；再确认项目里有非空的 `docs/flow/verify-cmd`（没有则 Oracle 按设计放行）。

**它老在 brainstorm/plan 处停下问我？** 这是 R2/R3 的硬门，刻意为之——大改动先对齐方向、再确认设计，避免一路跑偏。想跳过用 `#skip-flow` 或降档 `#R1`。

**我确实要删个过时测试，却被打回？** 提交一个 `docs/flow/verify-allow-test-changes` 空文件作显式豁免（须已提交）。

**每次收尾跑测试太慢？** 开 `docs/flow/verify-cache`（见 §4 降本），但测试依赖被 git 忽略的文件时不要开。

**它判档判低了 / 判高了？** 用 `#R0`–`#R3` 强制，或 `#new` 重判。判低漏流程、判高空转，都欢迎纠正——纠正本身会被 `harvest` 当作信号沉淀。

**完成判定能不能完全防住对抗？** 不能，也不假装能（见 DESIGN §5 边界）。门控提高绕过成本、留审计痕迹；把验证命令与基线纳入版本控制 + 人审其变更，是让门可信的关键。
