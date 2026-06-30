# 扩展已有规则时，别臆造未验证的"优化"，也别只加分支不查全局自洽

- symptom:
  改造 diagram 技能（放开后端到 Graphviz、移植 diagram-design 纪律）时，Codex verifier 三轮对抗抓出：
  (1) 我在 DOT 骨架里臆造加了 `splines=ortho` 当"复杂图优化"——但它与本技能"连线必带标签"红线冲突，`dot` 直接告警 `Orthogonal edges do not currently handle edge labels`，ortho 实际不生效；而 bench 里实测最优的 `05-graphviz.dot` 根本没设 splines。
  (2) 给"≤12 节点拆图"这条已有规则新增"复杂→Graphviz"分支后，多处自相矛盾：节点硬上限 12 vs >12 触发 Graphviz；入口措辞"复杂=直接转 Graphviz" vs 正文"复杂≠立刻 Graphviz，先拆、拆不动才转"；铁律"只产图代码/无图片" vs "Graphviz 需内嵌 SVG"；plan"不创建目录" vs Graphviz 需建 `assets/`。
- root_cause:
  (1) 在已有验证基线（bench 实测的 DOT 配置）之上，凭"听起来更好"加参数，没回到证据，也没渲染验证那一行的副作用。
  (2) 给一套相互引用的规则新增一个分支时，只改了"主入口"，没扫全文所有重述该规则的位置（入口短语、checklist、反例集、危险信号、跨技能引用），导致同一规则多处口径漂移。
- fix:
  (1) 删掉 `splines=ortho`，回到 bench 验证过的默认 spline 配置；并在文档里写明"别加 ortho，它与边标签冲突"。
  (2) 钉死单一口径"命中复杂 → 先拆 overview+detail → 拆不动且写明原因才转 Graphviz"，然后 grep 出所有重述点逐一对齐；矛盾的硬约束（节点上限、无图片、不建目录）各加显式例外条款。
- generalization:
  - **改 = 在验证基线上动手**：任何"优化"参数若不在已实测通过的样本里，先单独渲染/跑一遍看副作用，再写进规范；不靠"应该更好"。
  - **给规则加分支 = 全局一致性作业**：新增一个 case 后，grep 出该规则被重述的每一处（入口/口诀/checklist/反例/危险信号/跨文件引用）逐条对齐口径；新分支若撞上已有硬约束（上限/禁令/边界），必须显式写例外，否则就是自相矛盾。
  - **跨模型 verifier 高价值**：这类"自相矛盾/臆造副作用"同模型自审极易漏，独立 verifier（Codex）逐轮对抗能稳定抓出——builder≠verifier 不是形式，是真能抓 bug。
- links:
  - skills/diagram/SKILL.md, skills/diagram/references/{type-selection,graphviz-complex}.md
  - skills/plan/SKILL.md, skills/document/SKILL.md（跨引用同步）
  - docs/flow/diagram-overhaul/（design + tasks）
- last_verified: 2026-06-29
