#!/bin/bash
# Flow state-manager（落盘）—— 注册在 PreCompact。
# 压缩前确保 run 状态落盘，长任务跨压缩不丢 tier / 循环 / 失败计数。
set -u
DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/lib.sh"

input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')
FLOW_ROOT=$(flow_find_root "$cwd") || exit 0
export FLOW_ROOT
[ -z "$FLOW_ROOT" ] && exit 0

hash=$(flow_cwd_hash "$cwd")
RUNDIR="$FLOW_ROOT/.flow/runs/$hash"
STATE="$RUNDIR/state.json"
LOOP="$RUNDIR/loop.yml"
[ -d "$RUNDIR" ] || exit 0

# 把活跃循环的关键字段镜像进 state.json，并打 checkpoint 时间。
active="false"; iter=""; change=""
if [ -f "$LOOP" ] && [ "$(yget "$LOOP" active)" = "true" ]; then
  active="true"; iter=$(yget "$LOOP" iteration); change=$(yget "$LOOP" change_id)
fi
tmp="$STATE.tmp.$$"
if [ -f "$STATE" ]; then base=$(cat "$STATE"); else base='{}'; fi
printf '%s' "$base" | jq \
  --arg a "$active" --arg it "$iter" --arg ch "$change" --arg ts "$(flow_now_iso)" \
  '.active_loop=($a=="true") | (if $it!="" then .iteration=($it|tonumber) else . end)
   | (if $ch!="" then .change_id=$ch else . end) | .last_checkpoint=$ts' \
  > "$tmp" 2>/dev/null && mv "$tmp" "$STATE"
exit 0
