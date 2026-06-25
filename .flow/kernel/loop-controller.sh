#!/bin/bash
# Flow L1 任务回路引擎 —— 注册在 Stop 事件。
# 机制（取自 pua-loop，但默认有界、Oracle 来源受控）：
#   agent 试图结束 → 本 hook 拦截 → 若有活跃循环：
#     · <promise> 出现 → 在 hook 外独立运行冻结的 verify(Oracle)
#         pass → 放行结束；fail → 拒绝、升维、重喂
#     · 无信号 → 重喂任务 + 历史 + 认知升维动作
#     · 到 tier 上限 → 负责任移交，停止循环
#   无活跃循环 → 放行（普通对话必须能正常结束）。
set -u
DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/lib.sh"

input=$(cat)
ev=$(printf '%s' "$input"     | jq -r '.hook_event_name // ""')
sid=$(printf '%s' "$input"    | jq -r '.session_id // ""')
trans=$(printf '%s' "$input"  | jq -r '.transcript_path // ""')
cwd=$(printf '%s' "$input"    | jq -r '.cwd // ""')
parent=$(printf '%s' "$input" | jq -r '.parent_session_id // ""')

# Gate 0：仅主会话生效。子代理的结束不触发循环。
[ "$ev" = "SubagentStop" ] && exit 0
[ -n "$parent" ] && [ "$parent" != "null" ] && exit 0

FLOW_ROOT=$(flow_find_root "$cwd") || exit 0
export FLOW_ROOT
[ -z "$FLOW_ROOT" ] && exit 0

hash=$(flow_cwd_hash "$cwd")
RUNDIR="$FLOW_ROOT/.flow/runs/$hash"
LOOP="$RUNDIR/loop.yml"
HIST="$RUNDIR/loop-history.jsonl"

# 无循环态 → 放行结束（关键：普通对话/非循环任务必须能停）。
[ -f "$LOOP" ] || exit 0
[ "$(yget "$LOOP" active)" = "true" ] || exit 0

# 孤儿回收：循环态过旧视为残留，删除并放行。
started=$(yget "$LOOP" started_epoch); [ -z "$started" ] && started=0
stale=$(cfg_get loop.stale_seconds);   [ -z "$stale" ] && stale=3600
now=$(flow_now_epoch)
if [ $((now - started)) -gt "$stale" ]; then
  printf '{"iteration":%s,"status":"orphan_reaped","timestamp":"%s"}\n' \
    "$(yget "$LOOP" iteration)" "$(flow_now_iso)" >> "$HIST" 2>/dev/null
  rm -f "$LOOP"
  exit 0
fi

# 会话绑定：首次绑定当前会话；非属主会话不干预。
lsid=$(yget "$LOOP" session_id)
if [ -z "$lsid" ]; then
  yset "$LOOP" session_id "$sid"; lsid="$sid"
elif [ "$lsid" != "$sid" ]; then
  exit 0
fi

iter=$(yget "$LOOP" iteration);        [ -z "$iter" ] && iter=1
max=$(yget "$LOOP" max_iterations);    [ -z "$max" ] && max=10
rej=$(yget "$LOOP" promise_rejections);[ -z "$rej" ] && rej=0
change=$(yget "$LOOP" change_id)
tier=$(yget "$LOOP" tier)
promise=$(yget "$LOOP" completion_promise); [ -z "$promise" ] && promise=FLOW_DONE
verify=$(yget "$LOOP" verify_command)

last=$(flow_last_assistant "$trans")

log_hist() { # status verify_tail
  jq -cn --argjson it "$iter" --arg s "$1" --argjson rj "$rej" \
    --arg vt "$2" --arg ts "$(flow_now_iso)" \
    '{iteration:$it,status:$s,rejections:$rj,verify_tail:$vt,timestamp:$ts}' >> "$HIST"
}

hist_tail() {
  local n; n=$(cfg_get loop.history_tail); [ -z "$n" ] && n=8
  [ -f "$HIST" ] && tail -n "$n" "$HIST" | jq -r '"  · 第\(.iteration)轮 \(.status)\(if .verify_tail!="" then ": "+.verify_tail else "" end)"' 2>/dev/null
}

# 认知升维动作（去话术，源自 NoPUA）。综合迭代数与拒绝数取更高层级。
elevation() {
  local i="$1" r="$2" lvl
  lvl="$i"
  [ "$r" -gt "$lvl" ] && lvl="$r"
  if   [ "$lvl" -le 1 ]; then echo "稳步推进：逐字读上轮错误/验证输出，再动手。"
  elif [ "$lvl" -eq 2 ]; then echo "【换眼】换一个根本不同的分析视角，别只调参数。"
  elif [ "$lvl" -eq 3 ]; then echo "【升维】拉到系统全局：搜完整错误 + 读相关源码，列 3 个根本不同的假设。"
  elif [ "$lvl" -eq 4 ]; then echo "【归零】抛弃既有假设，构造最小复现，列 3 个全新假设逐一验证。"
  else echo "【移交在即】PoC + 隔离环境 + 换技术栈；并质疑需求本身是否成立。"
  fi
}

# 停滞检测：连续多轮改动同一组文件 → 强制根因步。
stall_note() {
  local sig last_sig cnt
  command -v git >/dev/null 2>&1 || return 0
  sig=$(git -C "$cwd" diff --name-only 2>/dev/null | sort | flow_md5)
  last_sig=$(yget "$LOOP" last_sig)
  cnt=$(yget "$LOOP" stall_count); [ -z "$cnt" ] && cnt=0
  if [ -n "$sig" ] && [ "$sig" = "$last_sig" ]; then
    cnt=$((cnt + 1))
  else
    cnt=0
  fi
  yset "$LOOP" last_sig "$sig"
  yset "$LOOP" stall_count "$cnt"
  if [ "$cnt" -ge 2 ]; then
    echo "⚠ 连续 $((cnt + 1)) 轮在改同一批文件——这是绕圈信号。停止微调，回到根因：列出所有尝试的共享假设，提一个 180° 反向假设。"
  fi
}

base_reason() {
  printf '继续推进 change「%s」(tier %s)，目标是让独立 Oracle 通过。\n' "$change" "$tier"
  printf '完成所有 tasks 后，自行运行验证并在回复中发出 <promise>%s</promise>。\n' "$promise"
  printf 'verify 命令由 profile 冻结，你不得修改测试/断言/CI 来"变绿"。\n'
  local ht; ht=$(hist_tail)
  [ -n "$ht" ] && { printf '\n历史（避免重复死路，必要时先读 .flow/runs/%s/loop-history.jsonl 与 git diff）：\n' "$hash"; printf '%s\n' "$ht"; }
  local sn; sn=$(stall_note); [ -n "$sn" ] && printf '\n%s\n' "$sn"
}

handoff() { # 到上限：停循环，要求结构化移交
  yset "$LOOP" active false
  log_hist "max_reached" ""
  flow_emit_block "已达迭代上限（$max 轮），停止自动循环。请输出结构化移交报告并结束：
①已验证事实 ②已排除的可能 ③已收窄的范围 ④建议的下一步方向 ⑤交接信息。
（该 run 命中 harvest 信号，结束后将蒸馏一条候选 lesson。）"
  exit 0
}

# ── 信号优先级：abort > pause > promise ──
case "$last" in
  *"<flow-abort>"*)
    log_hist "abort" ""
    rm -f "$LOOP"
    exit 0 ;;
  *"<flow-pause>"*)
    yset "$LOOP" active false
    log_hist "pause" ""
    exit 0 ;;
esac

if printf '%s' "$last" | grep -q "<promise>$promise</promise>"; then
  # Oracle 裁决
  if [ -z "$verify" ]; then
    # 设计上不应发生（loop-start 保证 verify 非空）。降级：放行但留痕告警。
    log_hist "complete_no_oracle" "WARN: verify_command 为空，按荣誉制放行"
    rm -f "$LOOP"
    exit 0
  fi
  to=$(cfg_get oracle.verify_timeout); [ -z "$to" ] && to=600
  out=$(cd "$cwd" && flow_run_timeout "$to" /bin/sh -c "$verify" 2>&1); rc=$?
  vtail=$(printf '%s' "$out" | tail -n 6 | tr '\n' ' ' | cut -c1-500)
  if [ "$rc" -eq 0 ]; then
    log_hist "complete" "$vtail"
    rm -f "$LOOP"
    exit 0
  fi
  # Oracle 拒绝
  rej=$((rej + 1)); yset "$LOOP" promise_rejections "$rej"
  log_hist "promise_rejected" "exit=$rc | $vtail"
  if [ "$iter" -ge "$max" ]; then handoff; fi
  iter=$((iter + 1)); yset "$LOOP" iteration "$iter"
  flow_emit_block "Oracle 未通过（退出码 ${rc}）。验证输出尾部：
$out

$(elevation "$iter" "$rej")

$(base_reason)"
  exit 0
fi

# 无终止信号：常规重喂 + 升维（或到上限移交）
if [ "$iter" -ge "$max" ]; then handoff; fi
iter=$((iter + 1)); yset "$LOOP" iteration "$iter"
log_hist "continue" ""
flow_emit_block "$(elevation "$iter" "$rej")

$(base_reason)"
exit 0
