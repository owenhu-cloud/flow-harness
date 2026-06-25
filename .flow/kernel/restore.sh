#!/bin/bash
# Flow state-manager（恢复）—— 注册在 SessionStart。
# 新会话开场时，若存在 run 状态/活跃循环，注入一句续连提示，保持连续性。
set -u
DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/lib.sh"

input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')
[ -z "$cwd" ] && cwd="$PWD"
FLOW_ROOT=$(flow_find_root "$cwd") || exit 0
export FLOW_ROOT
[ -z "$FLOW_ROOT" ] && exit 0

hash=$(flow_cwd_hash "$cwd")
RUNDIR="$FLOW_ROOT/.flow/runs/$hash"
STATE="$RUNDIR/state.json"
LOOP="$RUNDIR/loop.yml"
[ -f "$STATE" ] || exit 0

tier=$(jq -r '.tier // ""' "$STATE" 2>/dev/null)
change=$(jq -r '.change_id // ""' "$STATE" 2>/dev/null)
nh=$(jq -r '.next_hypothesis // ""' "$STATE" 2>/dev/null)
loop="否"
if [ -f "$LOOP" ] && [ "$(yget "$LOOP" active)" = "true" ]; then
  loop="是（第 $(yget "$LOOP" iteration)/$(yget "$LOOP" max_iterations) 轮，change $(yget "$LOOP" change_id)）"
fi
[ -z "$tier" ] && [ "$loop" = "否" ] && exit 0

msg="[Flow 状态恢复] tier=${tier:-未定}"
[ -n "$change" ] && msg="$msg · change=$change"
msg="$msg · 活跃 Oracle 循环=$loop"
[ -n "$nh" ] && msg="$msg
未竟假设：$nh"

flow_emit_context "SessionStart" "$msg"
exit 0
