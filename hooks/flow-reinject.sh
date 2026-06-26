#!/bin/sh
# Flow 治衰减：每轮用户提交（UserPromptSubmit）时重注入一句短路由纪律，
# 对抗会话内上下文增长把 SessionStart 注入的提示越埋越深。
# 刻意保持极短（单句）：重注入本身不能反过来造成上下文污染。
# 读 stdin（UserPromptSubmit 的 JSON），命中 #skip-flow 即静默放行。
# 无外部依赖（不需 jq）：注入内容为单行静态字符串，无需转义。

INPUT=$(cat)
case "$INPUT" in
  *'#skip-flow'*) exit 0 ;;
esac

CTX='[Flow] 动手工程任务前先用 `flow` 技能判档(R0–R3)并按档走流程；首次进入某代码库先用 `profile` 固化项目画像；完成声明必带同轮新鲜验证输出，且完成由 Stop hook 的独立 Oracle 复核。'
printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$CTX"
