#!/bin/sh
# Flow 治"自说自话"：独立 Oracle。agent 试图结束（Stop）时，由本 hook —— 一个
# 与 agent 无关的进程 —— 跑项目真实验证命令来裁决"完成"。命令非 0 退出即阻止收尾，
# 把失败输出回灌给 agent 令其继续修。完成不再由 agent 自说自话，而由机制裁决。
#
# 严格 opt-in：仅当 docs/flow/verify-cmd 存在且非空时生效（由 profile / verify 写入）；
# 不存在则立即放行（零侵入，不影响未接入的项目）。
# 命中 stop_hook_active 则放行，避免把 agent 永久关在门里形成死循环。
# 无强依赖：仅用 POSIX sh / sed / tr / awk；不需 jq。

INPUT=$(cat)

# 已处于 Oracle 触发的阻塞循环中 → 放行，避免无限阻塞。
case "$INPUT" in
  *'"stop_hook_active":true'*|*'"stop_hook_active": true'*) exit 0 ;;
esac

CMD_FILE="docs/flow/verify-cmd"
[ -f "$CMD_FILE" ] || exit 0          # 未 opt-in：放行
CMD=$(grep -v '^[[:space:]]*#' "$CMD_FILE" | grep -v '^[[:space:]]*$' \
      | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | head -n1)
[ -n "$CMD" ] || exit 0               # 空命令：放行（视为该项目无法自动验证）

OUT=$(sh -c "$CMD" 2>&1)
CODE=$?
[ "$CODE" -eq 0 ] && exit 0           # Oracle 判定通过：放行

# 失败：用 Stop hook 的 exit-2 契约阻止收尾——reason 走 stderr，退出码 2 即 block。
# 刻意不组 JSON：stderr 可含任意字节（引号 / 换行 / ANSI），无需转义，从根上免去
# 在 POSIX sh 里手搓 JSON 字符串转义的脆弱性。Claude Code 会把这段 stderr 回灌给 agent。
{
  printf '[Flow Oracle] 独立验证命令未通过（退出码 %s），不得声明完成。\n' "$CODE"
  printf '命令：%s\n' "$CMD"
  printf -- '--- 输出末 40 行 ---\n'
  printf '%s\n' "$OUT" | tail -n 40
  printf '修实现直到此命令绿，禁止改测试/断言/CI 使其变绿（红线 §1/§2）。\n'
} >&2
exit 2
