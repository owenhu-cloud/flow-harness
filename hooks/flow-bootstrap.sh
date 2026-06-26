#!/bin/sh
# Flow 的唯一常驻部分：会话开始（含 /clear、压缩后）注入一句路由纪律，
# 保证 agent 在动手前先用 `flow` 技能判档。正文按需用 Skill 工具懒加载。
# 无外部依赖（不需 jq）：注入内容为单行静态字符串，无需转义。

CTX='[Flow] 已启用。动手任何工程任务前，先用 Skill 工具加载 `flow` 技能判复杂度档位并路由。四维(影响面/不可逆性/未知度/风险)各0-3求和：0-1=R0直执 · 2-4=R1轻流程 · 5-8=R2标准(brainstorm→plan→门→implement→verify→document) · 9-12=R3项目。覆盖标记：#R0..#R3 强制 · #skip-flow 跳过 · #new 重判。红线：完成声明必带同轮新鲜测试输出；builder≠verifier；执行流水账不当文档交付。'

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$CTX"
