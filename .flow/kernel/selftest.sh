#!/bin/bash
# Flow kernel 自测。模拟 Claude Code 的 hook I/O，覆盖所有关键路径。
# 用法：bash .flow/kernel/selftest.sh   （退出码 = 失败数）
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/.flow/kernel/lib.sh"
CWD="$ROOT"
hash=$(flow_cwd_hash "$CWD")
RUNDIR="$ROOT/.flow/runs/$hash"
T="$RUNDIR/transcript.jsonl"
LC="$ROOT/.flow/kernel/loop-controller.sh"
RT="$ROOT/.flow/kernel/router.sh"
FLOW="$ROOT/.flow/bin/flow"
PROF="$ROOT/.flow/profile.yml"
cd "$ROOT" || exit 1
# 自测须 hermetic：不依赖项目真实 profile。备份后用受控 profile，结束必还原。
PROFBAK=$(mktemp); cp "$PROF" "$PROFBAK" 2>/dev/null
trap 'cp "$PROFBAK" "$PROF" 2>/dev/null; rm -f "$PROFBAK"; rm -rf "$RUNDIR"' EXIT
pass=0; fail=0
ok(){ if eval "$2"; then echo "  ✓ $1"; pass=$((pass+1)); else echo "  ✗ $1   [cond: $2]"; fail=$((fail+1)); fi; }
mkdir -p "$RUNDIR"
mk(){ jq -cn --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}' > "$T"; }
stop(){ jq -cn --arg c "$CWD" --arg t "$T" '{hook_event_name:"Stop",session_id:"s1",transcript_path:$t,cwd:$c}' | bash "$LC"; }

rm -f "$RUNDIR/loop.yml" "$RUNDIR/loop-history.jsonl" "$RUNDIR/state.json"

echo "== 1. CLI 拒绝路径 =="
"$FLOW" loop-start --tier R0 --change c0 >/dev/null 2>&1; ok "R0 不进循环被拒" "[ $? -ne 0 ]"
printf 'profile.ready: false\n' > "$PROF"   # 受控：模拟 profile 未就绪
"$FLOW" loop-start --tier R2 --change c2 >/dev/null 2>&1; ok "R2 无Oracle被拒(no-Oracle-no-loop)" "[ $? -ne 0 ]"
cp "$PROFBAK" "$PROF" 2>/dev/null            # 还原（后续测试用 --verify，与 profile 无关）
ok "拒绝无残留" "[ ! -f '$RUNDIR/loop.yml' ]"

echo "== 2. 无循环放行 =="
mk "闲聊"; out=$(stop); ok "无循环 stdout 空(放行)" "[ -z \"\$out\" ]"

echo "== 3. 启动循环 =="
"$FLOW" loop-start --tier R2 --change demo --verify "true" >/dev/null
ok "loop.yml 建立" "[ -f '$RUNDIR/loop.yml' ]"

echo "== 4. 无信号→阻止+升维 =="
mk "改了点东西还没验证"; out=$(stop)
ok "decision=block" "[ \"\$(printf '%s' \"\$out\"|jq -r .decision)\" = block ]"
ok "含升维提示" "printf '%s' \"\$out\"|jq -r .reason|grep -q '稳步推进\\|换眼\\|升维'"
ok "iteration=2" "[ \"\$(grep '^iteration:' '$RUNDIR/loop.yml'|sed 's/.*: //')\" = 2 ]"

echo "== 5. promise+Oracle通过→放行 =="
mk "完成。<promise>FLOW_DONE</promise>"; out=$(stop)
ok "放行(空)" "[ -z \"\$out\" ]"
ok "loop.yml 删除" "[ ! -f '$RUNDIR/loop.yml' ]"
ok "history=complete" "[ \"\$(tail -1 '$RUNDIR/loop-history.jsonl'|jq -r .status)\" = complete ]"

echo "== 6. promise+Oracle失败→阻止+计数 =="
"$FLOW" loop-start --tier R2 --change d2 --verify "false" >/dev/null
mk "好了吧。<promise>FLOW_DONE</promise>"; out=$(stop)
ok "block" "[ \"\$(printf '%s' \"\$out\"|jq -r .decision)\" = block ]"
ok "含'Oracle 未通过'" "printf '%s' \"\$out\"|jq -r .reason|grep -q 'Oracle 未通过'"
ok "rejections=1" "[ \"\$(grep '^promise_rejections:' '$RUNDIR/loop.yml'|sed 's/.*: //')\" = 1 ]"

echo "== 7. 到上限→移交 =="
"$FLOW" loop-stop >/dev/null
"$FLOW" loop-start --tier R2 --change d3 --verify "false" >/dev/null
awk '{if($1=="max_iterations:")print "max_iterations: 1";else print}' "$RUNDIR/loop.yml" > "$RUNDIR/loop.yml.t" && mv "$RUNDIR/loop.yml.t" "$RUNDIR/loop.yml"
mk "还在弄"; out=$(stop)
ok "移交 block" "[ \"\$(printf '%s' \"\$out\"|jq -r .decision)\" = block ]"
ok "含'迭代上限'" "printf '%s' \"\$out\"|jq -r .reason|grep -q '迭代上限'"
ok "active=false" "[ \"\$(grep '^active:' '$RUNDIR/loop.yml'|sed 's/.*: //')\" = false ]"
out2=$(stop); ok "移交后放行" "[ -z \"\$out2\" ]"

echo "== 8. abort→放行+删除 =="
"$FLOW" loop-start --tier R2 --change d4 --verify "true" >/dev/null
mk "放弃 <flow-abort>需求不成立</flow-abort>"; out=$(stop)
ok "abort 放行" "[ -z \"\$out\" ]"; ok "abort 删除" "[ ! -f '$RUNDIR/loop.yml' ]"

echo "== 9. SubagentStop 不触发 =="
"$FLOW" loop-start --tier R2 --change d5 --verify "false" >/dev/null
mk "子代理"; out=$(jq -cn --arg c "$CWD" --arg t "$T" '{hook_event_name:"SubagentStop",session_id:"s1",transcript_path:$t,cwd:$c}'|bash "$LC")
ok "SubagentStop 放行" "[ -z \"\$out\" ]"; ok "循环仍在" "[ -f '$RUNDIR/loop.yml' ]"
"$FLOW" loop-stop >/dev/null; rm -f "$RUNDIR/loop.yml"

echo "== 10. router 注入 =="
rm -f "$RUNDIR/state.json"
r=$(jq -cn --arg c "$CWD" '{prompt:"重构登录并接验证码",cwd:$c}'|bash "$RT")
ok "产出 additionalContext" "printf '%s' \"\$r\"|jq -e .hookSpecificOutput.additionalContext >/dev/null"
ok "无state→注入rubric" "printf '%s' \"\$r\"|jq -r .hookSpecificOutput.additionalContext|grep -q 'R2标准'"
r=$(jq -cn --arg c "$CWD" '{prompt:"上线支付 #R3",cwd:$c}'|bash "$RT")
ok "#R3 识别" "printf '%s' \"\$r\"|jq -r .hookSpecificOutput.additionalContext|grep -q 'R3（人工指定）'"
ok "#R3 写state" "[ \"\$(jq -r .tier '$RUNDIR/state.json')\" = R3 ]"
r=$(jq -cn --arg c "$CWD" '{prompt:"闲聊 #skip-flow",cwd:$c}'|bash "$RT")
ok "#skip-flow 空注入" "[ -z \"\$r\" ]"
# sticky
"$FLOW" tier R1 >/dev/null
r=$(jq -cn --arg c "$CWD" '{prompt:"接着弄",cwd:$c}'|bash "$RT")
ok "sticky 沿用 R1" "printf '%s' \"\$r\"|jq -r .hookSpecificOutput.additionalContext|grep -q 'R1（沿用'"

echo ""; echo "== 结果: PASS=$pass FAIL=$fail =="
rm -rf "$RUNDIR"
exit $fail
