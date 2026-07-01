#!/bin/sh
# transcript schema 金丝雀（C2）。A1 意图门 / A2 技能使用门 grep 一个【未公开的 Claude Code transcript 格式】。
# 若 CC 改了格式，这两门会【静默 fail-open → 变 no-op、零信号】（和 lessons/ 里 8 条剧本一样）。
# 本测试抓一份【真实】transcript 切片（fixtures/real-transcript-sample.jsonl，结构真、正文脱敏）：
#   (1) 断言 A1/A2 依赖的 schema 锚点仍存在于真实样本 —— 锚点被重命名 → 本测试红（loud），不再静默失效。
#   (2) 行为金丝雀：喂真实样本给 Oracle，断言真实锚点【确实驱动】门（不只是字符串在场）。
# 纳入 verify-cmd 与 CI，故 schema 漂移会在 CI 立刻变红。
set -u
DIR=$(cd "$(dirname "$0")" && pwd)
FIX="$DIR/fixtures/real-transcript-sample.jsonl"
ORACLE="$DIR/flow-oracle.sh"
PASS=0; FAIL=0
ok(){ if [ "$1" -eq 0 ]; then PASS=$((PASS+1)); printf 'PASS  %s\n' "$2"; else FAIL=$((FAIL+1)); printf 'FAIL  %s\n' "$2"; fi; }
[ -f "$FIX" ] || { echo "缺 fixture: $FIX（金丝雀需要一份真实 transcript 样本）"; exit 1; }

# (1) 结构锚点：A1(意图) 与 A2(技能) 门赖以工作的子串必须仍在真实样本里
grep -qF '"type":"assistant"' "$FIX"; ok $? 'schema 锚点存在: "type":"assistant"（A1/A2 角色标记）'
grep -qF '"type":"text"'      "$FIX"; ok $? 'schema 锚点存在: "type":"text"（A1 正文块标记）'
grep -qF '"name":"Write"'     "$FIX"; ok $? 'schema 锚点存在: "name":"Write"（A1/A2 编辑工具标记）'
grep -qF '"name":"Skill"'     "$FIX"; ok $? 'schema 锚点存在: "name":"Skill"（A2 技能加载标记）'
grep -qF '"skill":"'          "$FIX"; ok $? 'schema 锚点存在: "skill":"<名>"（A2 技能名标记）'

# (2) 行为金丝雀：真实锚点确实驱动 A2（关 A1 以隔离；A1 锚点已由上面结构断言覆盖）
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/p/docs/flow"; printf 'true\n' > "$TMP/p/docs/flow/verify-cmd"; : > "$TMP/p/docs/flow/intent-gate-off"
cp "$FIX" "$TMP/p/tx.jsonl"
IN='{"stop_hook_active":false,"transcript_path":"'"$TMP"'/p/tx.jsonl"}'
( cd "$TMP/p" && printf '%s' "$IN" | sh "$ORACLE" >/dev/null 2>&1 ); rc=$?
[ "$rc" -eq 0 ]; ok $? "真实样本(有编辑+真实 Skill:implement 标记) → A2 放行(exit 0)"
# 去掉真实 Skill 行 → A2 应打回（证明 "name":"Skill"+"skill":" 锚点确在驱动门，不是摆设）
grep -v '"name":"Skill"' "$FIX" > "$TMP/p/tx.jsonl"
( cd "$TMP/p" && printf '%s' "$IN" | sh "$ORACLE" >/dev/null 2>&1 ); rc=$?
[ "$rc" -eq 2 ]; ok $? "去掉真实 Skill 行 → A2 打回(exit 2)：锚点确在驱动门"

printf '\n==== %s passed, %s failed ====\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
