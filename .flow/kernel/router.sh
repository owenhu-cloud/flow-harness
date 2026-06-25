#!/bin/bash
# Flow router —— 注册在 UserPromptSubmit。
# 职责：判级/沿用黏滞 tier + 召回相关 lessons + 注入裁决。不加载任何 SKILL 正文。
set -u
DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/lib.sh"

input=$(cat)
prompt=$(printf '%s' "$input" | jq -r '.prompt // ""')
cwd=$(printf '%s' "$input"    | jq -r '.cwd // ""')

FLOW_ROOT=$(flow_find_root "$cwd") || exit 0
export FLOW_ROOT
[ -z "$FLOW_ROOT" ] && exit 0

# 跳过：纯闲聊/显式跳过 → 零注入零开销。
case "$prompt" in *"#skip-flow"*) exit 0 ;; esac

hash=$(flow_cwd_hash "$cwd")
RUNDIR="$FLOW_ROOT/.flow/runs/$hash"
STATE="$RUNDIR/state.json"
mkdir -p "$RUNDIR"

# 人工覆盖检测
forced=""
case "$prompt" in
  *"#R0"*) forced=R0 ;; *"#R1"*) forced=R1 ;;
  *"#R2"*) forced=R2 ;; *"#R3"*) forced=R3 ;;
esac
is_new=0; case "$prompt" in *"#new"*) is_new=1 ;; esac

sticky=""
if [ -f "$STATE" ] && [ "$is_new" -eq 0 ] && [ -z "$forced" ]; then
  sticky=$(jq -r '.tier // ""' "$STATE" 2>/dev/null)
fi

# 持久化 forced tier（自评 tier 由 agent 经 `flow tier` 写入）
if [ -n "$forced" ]; then
  tmp="$STATE.tmp.$$"
  if [ -f "$STATE" ]; then jq --arg t "$forced" --arg ts "$(flow_now_iso)" \
      '.tier=$t | .updated_at=$ts | .override=true' "$STATE" > "$tmp" && mv "$tmp" "$STATE"
  else jq -cn --arg t "$forced" --arg ts "$(flow_now_iso)" \
      '{tier:$t, override:true, failure_count:0, updated_at:$ts}' > "$STATE"
  fi
fi

# ── 经验召回（按 prompt 关键词命中数排序取 top-k）──
recall_block=""
LDIR="$FLOW_ROOT/lessons"
if [ -d "$LDIR" ] && ls "$LDIR"/*.md >/dev/null 2>&1; then
  k=$(cfg_get lessons.recall_k); [ -z "$k" ] && k=3
  kws=$(printf '%s' "$prompt" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9_' ' ' \
        | tr ' ' '\n' | awk 'length($0)>=4' | sort -u)
  scored=""
  for f in "$LDIR"/*.md; do
    score=0
    for w in $kws; do
      c=$(grep -ic "$w" "$f" 2>/dev/null); score=$((score + c))
    done
    [ "$score" -gt 0 ] && scored="$scored$score	$f
"
  done
  if [ -n "$scored" ]; then
    recall_block="
[相关经验 · 老化降权后 top-$k]"
    while IFS='	' read -r s f; do
      [ -z "$f" ] && continue
      title=$(grep -m1 '^# ' "$f" 2>/dev/null | sed 's/^# *//')
      [ -z "$title" ] && title=$(basename "$f")
      gen=$(grep -m1 -i 'generalization' "$f" 2>/dev/null | sed 's/.*generalization[:：]*//I' | cut -c1-160)
      recall_block="$recall_block
· $title${gen:+ — $gen}"
    done <<EOF
$(printf '%s' "$scored" | sort -rn | head -n "$k")
EOF
  fi
fi

# ── 组裁决 ──
if [ -n "$forced" ]; then
  verdict="[Flow] 本任务 = ${forced}（人工指定）。按该 tier 激活流程。"
elif [ -n "$sticky" ]; then
  verdict="[Flow] 本任务 = ${sticky}（沿用本 run 判级；如需重判加 #new）。按该 tier 激活流程。"
else
  verdict="[Flow 路由] 四维各 0-3 求和 → tier：影响面/不可逆性/未知度/风险。
0-1=R0直执 · 2-4=R1轻流程 · 5-8=R2标准 · 9-12=R3项目。
请一句话判级，运行 .flow/bin/flow tier <R0|R1|R2|R3> [--change <id>] 记录，再按 tier 激活流程。
R2/R3：brainstorm→plan→gate→implement(对抗 + Oracle 循环)→self-test→document。
覆盖：#R0..#R3 强制 · #skip-flow 跳过 · #new 重判 · #no-loop 关闭本 change 循环。"
fi

flow_emit_context "UserPromptSubmit" "$verdict$recall_block"
exit 0
