# 类型选择 + 复杂度触发 + 调色板

主文件给了「类型→后端」映射，这里钉死：类型决策树、**复杂度触发判据**（决定流程图走 Mermaid 还是 Graphviz）、反例集、双后端固定调色板。

> 复杂度预算、删除优先、反 AI-slop、taste-gate 等纪律借鉴 `cathrynlavery/diagram-design`（MIT, © 2025 Cathryn Lavery）；本技能按「图即代码」诉求改造，不采用其 HTML+SVG 产物路线。

## 一、类型决策树（自顶向下，命中即停）

1. **多方按时间先后发生的交互**（谁先发、谁回谁、有无并发/可选分支）？
   → `sequenceDiagram`（Mermaid）：`->>` 实线请求、`-->>` 虚线响应、`alt/opt/loop/par` 表条件与并发。
2. **单个对象/系统在自身状态间迁移**（idle→running→done、订单状态机）？
   → `stateDiagram-v2`（Mermaid）：`[*]` 起止、迁移线带触发事件标签、可嵌套 composite state。
3. **实体之间的关系与基数**（用户 1—* 订单、表结构与外键）？
   → `erDiagram`（Mermaid）：`||--o{` 表基数，列字段与类型。
4. **类型/接口的结构与继承组合**？
   → `classDiagram`（Mermaid）。
5. 以上都不是，要表达**静态依赖/分层架构/分支决策流程**？
   → **先判复杂度**（见下）：简单 → Mermaid `flowchart`；复杂 → 先拆 overview+detail，拆不动且写明原因 → Graphviz `digraph`。

## 二、复杂度触发判据（仅流程图/架构图）

下列**任一命中**即判「复杂」。判定无歧义，照下面边界取：

- 节点 **> 12**（恰好 ≤12 且无其他命中 → 不复杂，Mermaid）；
- 存在**任意回环**（哪怕 1 条，节点指回上游，如「校验不通过 → 回填表单」「未供给 → 触发供给后回到上一步」）；
- 错误/异常回退边 **≥ 3 条**（**1–2 条不算复杂**，仍 Mermaid；≥3 条 dagre 会把它们拉成长曲线，转 Graphviz）；
- 分层 subgraph/cluster **≥ 3 个**；
- 边交叉**成网**（该项为渲染后判据：先用 Mermaid/ELK 试渲染，仍糊成一团才算命中）。

**复杂 ≠ 立刻 Graphviz**：命中后先尝试拆 overview+detail（拆图永远是首选）。**拆不动才转 Graphviz，且必须在图旁写一句「为何拆不动」**（如「端到端请求链路，拆开就丢了跨层因果」）。
都不命中 → Mermaid `flowchart` 足够（GitHub 内联）。偏大但想保留内联 → Mermaid 加 ELK 渲染器：`%%{init: {"flowchart": {"defaultRenderer": "elk"}}}%%`。

> 实测依据：33 节点 DID 颁发流程，Mermaid dagre 渲成 1568×6614 超长竖条、错误边沿左缘 6000px 长曲线；同语义 Graphviz 渲成约 717×3039、更紧凑且全边保真。Graphviz 写法见 `graphviz-complex.md`。

## 三、反例集（症状 → 病根 → 正解）

- **症状**：flowchart 里箭头来回指，想表达「客户端发请求、服务端查库再回包」。
  **病根**：把时序当静态依赖，生命线和先后顺序全丢。**正解**：`sequenceDiagram`。
- **症状**：flowchart 画订单 `待支付→已支付→已发货→已完成`，还想标「超时则取消」。
  **病根**：这是状态机，flowchart 无法表达「状态」与「触发事件」。**正解**：`stateDiagram-v2`。
- **症状**：flowchart 画一堆方框代表数据库表，连线表外键。
  **病根**：缺基数（1:1/1:N/N:M）与字段，读不出关系强度。**正解**：`erDiagram`。
- **症状**：一张图既画微服务依赖又塞进一次登录时序。**病根**：一图多主题。**正解**：拆两张。
- **症状**：节点命名 `A/B/C`、分支线无标签。**病根**：占位名+无标签分支线=没传达信息。**正解**：领域词命名 + 分支/条件边写动作/条件标签（纯线性顺序边可省）。
- **症状**：30 节点请求链路硬用 Mermaid，渲成超长竖条、回退边乱窜。**病根**：超复杂度预算还用错后端。**正解**：先拆图；拆不动 → Graphviz/DOT。

## 四、全项目固定四色（复用语义，勿每图自创）

四色语义：**主路径 / 次要 / 外部依赖 / 告警异常**，跨图一致，读者一眼对齐。

### Mermaid（`classDef`）
```
classDef primary  fill:#2563eb,color:#fff,stroke:#1e40af;
classDef minor    fill:#e5e7eb,color:#111,stroke:#9ca3af;
classDef external fill:#f59e0b,color:#111,stroke:#b45309;
classDef alert    fill:#dc2626,color:#fff,stroke:#991b1b;
```

### Graphviz/DOT（节点属性，等价语义）
`<NodeId>` 换成你的真实节点名，按语义任选一行套上：
```
// 主路径 / 核心组件
<NodeId> [style="filled,rounded", fillcolor="#2563eb", fontcolor=white];
// 次要 / 辅助
<NodeId> [style="filled,rounded", fillcolor="#e5e7eb", fontcolor="#111111"];
// 外部 / 第三方边界
<NodeId> [style="filled,rounded", fillcolor="#f59e0b", fontcolor="#111111"];
// 告警 / 失败分支 / 异常态
<NodeId> [style="filled,rounded", fillcolor="#dc2626", fontcolor=white];
```

- 主（primary）：关键路径/核心组件。次（minor）：辅助节点。
- 外部（external）：第三方/外部系统边界。告警（alert）：失败分支/异常态。
- **焦点色 ≤ 2 处**（主/告警），撒在 4+ 节点即返工（见反 AI-slop）。

## 五、渲染自检

落盘前实际渲染一次，报错就修语法，不靠脑补判「应该没错」，更不删报错节点凑通过。
- Mermaid：Mermaid Live / IDE 插件 / `npx @mermaid-js/mermaid-cli -i x.mmd -o x.svg`。
- Graphviz：`dot -Tsvg x.dot -o x.svg`（单二进制，免浏览器）。
