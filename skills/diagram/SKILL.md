---
name: diagram
description: R2+ 交付物需要图时用——架构/流程/时序/状态/数据模型。默认 Mermaid；复杂流程/架构图用 Graphviz。先判类型再判复杂度选后端，产可渲染的图代码（Graphviz 另附渲染出的 SVG 供内嵌）。 · EN: diagram — architecture / flow / sequence / state / ER diagram for a deliverable (R2+). Mermaid by default; Graphviz for complex flow/architecture. Pick type, then complexity, then backend; emit renderable diagram-as-code (Graphviz also emits a derived SVG for embedding).
---

# diagram — 图即代码（Mermaid 默认 · 复杂流程 Graphviz）

**适用档位 R2+。** 在 brainstorm→plan→implement→verify→document 中，本技能被 `plan`（落架构/流程图）或 `document`（嵌关键图）按需调用，不独立成阶段。**源产物是图代码**（Mermaid 或 Graphviz/DOT 文本）；Graphviz 另附由 `.dot` 渲染出的 `.svg` 派生资产。落 `docs/`，供人看。

> 部分质量纪律（复杂度预算、删除优先、反 AI-slop、taste-gate）借鉴 `cathrynlavery/diagram-design`（MIT），见 `references/type-selection.md` 归属。

## 三段式：判类型 → 判复杂度 → 选后端

1. **判类型**：要表达什么？查下方「类型→后端」表对症（选错类型是最大丑因）。
2. **判复杂度**（仅流程图/架构图需要）：命中复杂触发判据 → **先拆 overview+detail**；拆不动且写明原因，才升级后端（判据见 `references/type-selection.md`）。
3. **选后端 → 加载该后端写法 → 产代码 → 渲染自检**：复杂流程/架构图先 `Skill` 读 `references/graphviz-complex.md` 再写 DOT。

## 铁律（iron-laws，违反即作废）

1. **源产物是可渲染的图代码**（Mermaid / Graphviz DOT）——禁截图、手工绘图、ASCII art、draw.io、外链图。复杂图用 Graphviz 时**额外**提交由 `.dot` 渲染出的 `.svg` 派生资产供 Markdown 内嵌（GitHub 不内联 DOT）——这不是「图片」，是源代码的渲染产物。**类型与后端按下表绑定**：时序/状态/ER/类图**必须 Mermaid**；流程/架构图按复杂度在 Mermaid 与 Graphviz 间选。不在表内的格式（D2/PlantUML 等）本技能不用。
2. **类型由「要表达什么」决定，不由「我更熟哪个」决定**（映射见下表）。
3. **每张图必须语法可渲染**——未实际渲染验证 = 未完成（见反 reward-hacking）。
4. **≤12 节点优先拆图**——节点≤9/≤12 的上限是 **Mermaid 图**的拆图阈值；超了先拆 overview+detail。唯一豁免：**拆不动的完整链路**（如端到端请求流）转 Graphviz，此时不受 12 上限约束，但必须在图旁写一句「为何拆不动」。Graphviz 不是画大图的借口。

## 类型 → 后端映射（先对症，再选后端）

| 要表达的东西 | 类型 | 后端 |
|---|---|---|
| 跨组件按时间顺序的交互、请求-响应、调用次序 | `sequenceDiagram` | **Mermaid**（GitHub 内联） |
| 对象状态生命周期、有限状态机 | `stateDiagram-v2` | **Mermaid** |
| 数据模型、实体关系、表结构 | `erDiagram` | **Mermaid** |
| 类/接口结构与继承 | `classDiagram` | **Mermaid** |
| **简单**模块依赖/分层架构/分支决策流程（≤12 节点、无回环、≤2 错误回退边） | `flowchart` | **Mermaid**（可选 ELK 渲染器，见下） |
| **复杂**流程/架构（>12 节点 / 任意回环 / ≥3 错误回退 / ≥3 分层 / 边交叉成网，任一命中且拆不动） | DOT `digraph` | **Graphviz**（更紧凑、全边保真；预渲染 SVG 落盘） |

判定口诀：**有「时间先后/生命线」就 sequence；有「状态迁移」就 state；有「实体+关系基数」就 ER；其余结构/依赖/决策才 flowchart——而 flowchart 一旦复杂（判据见 references）先拆图，拆不动才转 Graphviz。** 决策树、复杂度触发判据、全项目固定四色调色板（Mermaid + DOT 两套）见 `references/type-selection.md`；Graphviz/DOT 写法、骨架与渲染见 `references/graphviz-complex.md`。

**Mermaid 偏大但想保留 GitHub 内联**：给 flowchart 加一行切 ELK 布局——
`%%{init: {"flowchart": {"defaultRenderer": "elk"}}}%%`（边更正交）。但真复杂仍优先拆图或转 Graphviz。

## 复杂度预算（Mermaid 图的拆图阈值，超则拆 overview+detail；拆不动才转 Graphviz）

| 上限 | 值 |
|---|---|
| 节点 | ≤ 9（拆图首选） / 硬上限 12 |
| 连线 / 迁移 | ≤ 12 |
| 焦点（告警/主路径高亮）色 | ≤ 2 处 |
| sequence 生命线 | ≤ 5 |
| swimlane 泳道 | ≤ 5 |
| ER 实体 | ≤ 8 |

**目标密度 4/10**：技术上完整即可，密到需要导读就该拆。「removing it wouldn't hurt → remove it」——两个永远同进同出的节点合成一个；布局已暗示的关系就删掉那条线。拆不动的大流程（如完整请求链路）才上 Graphviz。

## 可读约束

- 统一方向（一图内只用一个 `TD`/`LR` 或 DOT 的 `rankdir`）。
- **分支/条件连线必带标签**（判定的每个出边、回退边、并发分支）——无标签的分支线 = 语义缺失；纯线性顺序边（A→B→C，先后已显然）可省标签。
- 关键路径/告警用固定四色高亮；颜色复用全项目四色语义（主/次/外部/告警），不每张图自创。两套等价写法（Mermaid `classDef` / DOT 属性）见 `references/type-selection.md`。
- 命名用领域词，不用 `A/B/C` 占位。

## 反 AI-slop 反模式（出现即返工）

| 反模式 | 为何失败 |
|---|---|
| 每个节点同形同色 | 抹杀层级，读者分不出主次 |
| 图例浮在图内、压住节点 | 与节点碰撞；图例应在图外（底部/侧栏） |
| 焦点色（红/蓝高亮）撒在 4+ 节点 | 焦点是 1–2 处编辑性强调，不是信号系统；撒多了等于没强调 |
| 分支线无标签 / `A-->B` 占位命名 | 占位名+无标签的分支线=没传达信息（纯线性顺序边可不标） |
| 一张图既画架构又画时序 | 一图多主题，拆成两张各选对类型 |
| 节点超 12 还硬塞一张图 | 违复杂度预算；拆图或转 Graphviz |

## 危险信号（出现即停 / 回退）

- 一张图里既想画架构又想画时序 → 拆成两张，各选对类型。
- 节点超预算或连线交叉成网 → 先拆图；拆不动的大流程 → 转 Graphviz。
- 想插入截图/ASCII/外链图 → 回到图代码，铁律 §1。
- 复杂流程图还在硬用 Mermaid dagre 渲成超长竖条 → 转 Graphviz（铁律 §1 表）。

## 反 reward-hacking（完成判定）

- 「脑补语法应该没错」「大概能渲染」**不算完成**——必须实际渲染：Mermaid 贴 Mermaid Live 或 `npx @mermaid-js/mermaid-cli -i x.mmd -o x.svg`；DOT 跑 `dot -Tsvg x.dot -o x.svg`。
- 不把「类型差不多、能看懂」当达标：类型/后端映射不匹配即返工，不用近似类型或错后端蒙混。
- 渲染报错就如实修，不偷偷删报错节点凑「渲染成功」。

## checklist（产图前逐条过 · taste-gate）

- [ ] 类型按「要表达什么」选对（对照映射表/决策树）
- [ ] 复杂度判定走过：简单→Mermaid / 复杂→已先拆图 / 拆不动→Graphviz（并写明为何拆不动）
- [ ] 能删节点吗？能合并两个节点吗？能删某条连线吗？（删除优先）
- [ ] Mermaid 图在复杂度预算内（节点≤9 优先 / 硬上限12）；Graphviz 例外图已写明「为何拆不动」。焦点色 ≤2
- [ ] 每条分支/条件连线有标签（线性边可省），命名用领域词
- [ ] 关键路径/告警用固定四色（语义复用，非每图自创）
- [ ] 已实际渲染通过（非脑补语法）；Graphviz 的 `.dot`+`.svg` 落引用它的 doc 同目录 `assets/`
- [ ] 落 `docs/`；源为图代码，Graphviz 另附渲染出的 SVG；禁截图/手工图/外链图/ASCII

## 交接

产图完成后**回到调用本技能的阶段**：来自 `plan` 则继续 plan 的 design+tasks；交付物嵌图则**下一步用 `Skill` 工具加载 `document`** 写人类交付物。复杂图用 Graphviz 时，Markdown 内嵌渲染出的 SVG（GitHub 不内联 DOT），`.dot` 源一并提交。

遵循 `flow` 技能的质量红线。
