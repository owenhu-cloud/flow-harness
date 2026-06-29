# diagram 技能改造 任务

- [x] 1.1 重写 `skills/diagram/SKILL.md` — 三段式路由 + 后端策略表 + 复杂度预算 + 反 AI-slop 表 + taste-gate + 渲染自检 + frontmatter description + 交接段。
- [x] 1.2 扩展 `skills/diagram/references/type-selection.md` — 类型决策树 + 复杂度触发判据（无歧义边界）+ 双后端固定四色调色板（Mermaid classDef + DOT）+ MIT 归属。
- [x] 1.3 新增 `skills/diagram/references/graphviz-complex.md` — DOT 骨架 + 四色写法 + 布局调参 + LLM 常见坑 + `dot -Tsvg` 渲染命令 + assets 落盘约定。
- [x] 1.4 更新跨引用 — plan/SKILL.md（22/45/91 + 10/55/92）、document/SKILL.md（17/66）、document/references/typography.md（33）的"产 Mermaid"措辞。grep 确认无残留矛盾。
- [x] 1.5 渲染验证 — skeleton.dot + cluster-example.dot 经 `dot -Tsvg` 渲染 exit=0、无警告、4 条分支标签确认在 SVG 中（同轮新鲜输出）。修正了臆造的 `splines=ortho`（与强制标签冲突，回退到 bench 验证过的默认配置）。
- [x] 1.6 跨模型对抗证伪 — Codex(MCP) 三轮对抗：首轮 1 Critical + 4 Important + 3 Minor 全修；二轮抓出 1 新引入矛盾（入口措辞"复杂=直接Graphviz"）+ 残留项全修；三轮裁决 PASS（最后 1 Minor 按其原话修复）。builder=Claude ≠ verifier=Codex。

## 同步
- 已 surgical 同步到激活目录 `.claude/skills/`（diagram 全套 + plan/document 跨引用），源与激活副本 diff 一致。
