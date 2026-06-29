# diagram 技能改造 设计

## Context

- **为什么做**：现有 `diagram` 技能是 **Mermaid 独此一家**（铁律 §1 明文禁一切非 Mermaid）。实测同一张 33 节点 DID 颁发流程，Mermaid 默认 dagre 渲成 1568×6614 超长竖条、错误回退边沿左缘走 6000px 长曲线——复杂流程图"基本不能用"。
- **调研已定论**（见 `scratchpad/diagram-bench/COMPARISON.md` + `SKILL-SURVEY.md`）：
  - 跨工具同语义渲染对比：Mermaid-dagre 最差；**Graphviz/DOT 实测最紧凑且全边保真**（归一化后高度约 Mermaid 一半）；D2 同属第一梯队。
  - 市面**无可整体直接搬、且解决复杂图布局**的现成 skill；Anthropic 官方 `anthropics/skills` 无任何制图 skill；社区多数只"包一层 Mermaid"。
  - 唯一值得借鉴：`cathrynlavery/diagram-design`（2652★, **MIT**）的"质量骨架"——但其 HTML+SVG 路线 + "≤9 节点拒画大图"哲学与"图即代码/可 diff/GitHub 内联"诉求冲突，不整搬。
- **约束**：图是给 **LLM/agent 生成**的（可写性是一等约束）；产物要可 diff、尽量 GitHub/Markdown 内联；纯文档改动。
- **非目标**：不引入 D2（同梯队但本轮选 Graphviz）；不引入 Kroki 服务；不改 HTML+SVG 路线；不动渲染产物以外的工程代码。

## Decisions

1. **后端策略**（替换铁律 §1"禁一切非 Mermaid"）：
   - **时序/状态/ER/类图 → 必须 Mermaid**（`sequenceDiagram`/`stateDiagram-v2`/`erDiagram`/`classDiagram`）。理由：GitHub 内联渲染、Mermaid 对这些类型 LLM 最可靠。
   - **流程图/架构图 → 按复杂度分流**：
     - 简单（≤12 节点 且 无回环 且 无多错误回退）→ **Mermaid flowchart**（GitHub 内联）。理由：内联可读、零额外依赖。
     - 复杂（>12 节点 / 有回环 / ≥3 错误回退 / ≥3 分层 subgraph / 边交叉成网，任一命中）→ **Graphviz/DOT**。理由：实测最紧凑、任意跨层边全保真。预渲染 SVG 落盘引用。
     - 中间档（偏大但想保留内联）可给 Mermaid 加 `%%{init:{"flowchart":{"defaultRenderer":"elk"}}}%%` 切 ELK——但真复杂仍优先拆图或转 Graphviz。
2. **progressive disclosure 结构**（借鉴 diagram-design）：主 `SKILL.md` 保持精简（路由+策略+预算+反模式+taste-gate）；后端细则懒加载到 `references/`：
   - `references/type-selection.md`（扩展）：类型决策树 + **复杂度触发判据** + 双后端固定四色调色板（Mermaid `classDef` 与 DOT 等价两套）。
   - `references/graphviz-complex.md`（新增）：何时用 Graphviz、5–8 行 DOT 骨架、四色 DOT 写法、`rankdir`/`cluster`/正交边设置、`dot -Tsvg` 渲染命令、LLM 常见坑、渲染产物落盘约定。
3. **三段式路由**（借鉴 diagram-bridge-mcp）：SKILL.md 开篇给"判类型 → 判复杂度 → 选后端并加载该后端 references → 产代码 → 渲染自检"。
4. **移植 diagram-design（MIT，注明归属）**——仅与后端无关的纪律：
   - 删除优先哲学 + 目标密度 4/10（"removing it wouldn't hurt → remove it"）。
   - **复杂度预算表**（节点≤9*、箭头≤12、焦点色≤2、lifeline≤5、实体≤8…）+ 超预算拆 overview+detail。
     - `*` 注意：与"复杂图换 Graphviz"不冲突——**拆图仍是首选**，Graphviz 是拆不动的大流程的兜底，不是画大图的借口。
   - **反 AI-slop 反模式表**（适配 diagram-as-code：剔除 HTML/SVG 专属项如 `rounded-2xl`/shadow；保留"同形框抹杀层级""图例浮图内""accent 滥用""无标签连线""A/B/C 占位命名"等）。
   - **taste-gate checklist**（适配：类型对症？能删节点/合并/删连线？焦点≤2？在预算内？已实渲染？）。
5. **跨引用同步**：放开后端后，下列硬编码"产 Mermaid"措辞改为"产图（Mermaid 默认；复杂流程/架构图 Graphviz）"：
   - `skills/plan/SKILL.md:45`、`skills/document/SKILL.md:17,66`、`skills/document/references/typography.md:33`、`skills/diagram/SKILL.md` frontmatter `description`。
6. **保留的红线**（不动）：实渲染过才算完成、报错不删节点凑通过、≤12 优先拆图、连线必带标签、固定四色语义、单图单主题。

## Risks-Tradeoffs

- **风险：Graphviz 不在 GitHub/Markdown 内联渲染** → 须预渲染 SVG 提交。缓解：仅复杂流程/架构用 Graphviz，其余全 Mermaid 内联；skill 明确渲染步骤与落盘约定（`assets/` 同目录提交 SVG）。
- **风险：放开后端诱发滥用 Graphviz 画一切** → 用"非流程图类型必须 Mermaid"硬约束 + "≤12 优先拆图" + 复杂度触发判据三道闸。
- **风险：DOT 样式啰嗦、LLM 易写错** → `graphviz-complex.md` 固定骨架 + 四色调色板照抄，降错率；渲染自检兜底。
- **风险：多后端增加渲染依赖**（`dot` / `mmdc`）→ 都是单/常见 CLI；记录 CI 注意点（mermaid-cli 需 chrome-headless-shell + puppeteer.json，dot 单二进制免浏览器）。
- **回滚**：纯文档/技能文本改动，flow-harness 自带 git，一键回退。

## Migration

- 已产出的 Mermaid 图无需改；新规则只作用于新图。无数据/schema 迁移。
- 渲染产物约定：复杂图 Graphviz 源（`.dot`）与渲染 SVG 同放引用它的 doc 的 `assets/`，二者都提交（源可 diff、SVG 可内联引用）。

## Open-Questions

1. **Graphviz 渲染 SVG 是否提交进仓？** 建议：是，连同 `.dot` 源放 `docs/.../assets/`。→ 待用户确认或采纳默认。
2. **Mermaid+ELK 中间档是否保留？** 建议：保留为"偏大但想内联"的可选项，文档里标注"真复杂优先 Graphviz/拆图"。→ 倾向保留。

（门前须清零：上述两条若无异议则采纳括号内默认。）
