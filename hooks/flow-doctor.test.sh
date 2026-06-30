#!/bin/sh
# flow-doctor.sh 自检：构造合成 docs/flow/ 状态，断言退出码与关键报告内容。
# 纯 POSIX sh，不联网、不调真 codex/grok（健康检查会因 stub 缺 auth 而降级，doctor 不应因此报错）。
set -u
DOCTOR=$(cd "$(dirname "$0")" && pwd)/flow-doctor.sh
[ -f "$DOCTOR" ] || { echo "找不到 $DOCTOR"; exit 1; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
newdir() { WORK="$TMP/$1"; mkdir -p "$WORK/docs/flow"; cd "$WORK" || exit 1; }

run_code() {  # <name> <expected-exit>
  _n=$1; _exp=$2
  sh "$DOCTOR" >"$TMP/out" 2>&1; _c=$?
  if [ "$_c" -eq "$_exp" ]; then PASS=$((PASS+1)); printf 'PASS  %s (exit %s)\n' "$_n" "$_c"
  else FAIL=$((FAIL+1)); printf 'FAIL  %s: expected exit %s got %s\n' "$_n" "$_exp" "$_c"; fi
}
has() {  # <name> <substring> : assert last run's output contains
  _n=$1; _s=$2
  if grep -qF "$_s" "$TMP/out"; then PASS=$((PASS+1)); printf 'PASS  %s\n' "$_n"
  else FAIL=$((FAIL+1)); printf 'FAIL  %s: 输出未含 "%s"\n' "$_n" "$_s"; fi
}
hasnt() {
  _n=$1; _s=$2
  if grep -qF "$_s" "$TMP/out"; then FAIL=$((FAIL+1)); printf 'FAIL  %s: 输出不应含 "%s"\n' "$_n" "$_s"
  else PASS=$((PASS+1)); printf 'PASS  %s\n' "$_n"; fi
}

# 1. 空项目（无 verify-cmd）→ Oracle inactive → exit 1，且明确说明退回纪律级
newdir d1
run_code "empty project → Oracle inactive → exit 1" 1
has "d1 报告 INACTIVE" "INACTIVE"
has "d1 提示纪律级" "纪律级"

# 2. 有 verify-cmd → Oracle active → exit 0
newdir d2; printf 'npm test\n' > docs/flow/verify-cmd
run_code "verify-cmd present → Oracle active → exit 0" 0
has "d2 显示 verify 命令" "npm test"
has "d2 B2 基线门列出" "B2 测试数基线"

# 3. B3/B4 opt-in 显示 启用 + 命令
newdir d3
printf 'npm test\n' > docs/flow/verify-cmd
printf 'npm run test:errors\n' > docs/flow/robustness-cmd
printf 'npm run cov\n' > docs/flow/coverage-cmd
printf '80\n' > docs/flow/coverage-min
run_code "B3+B4 opt-in → exit 0" 0
has "d3 B3 启用" "B3 健壮性门    ✅ 启用"
has "d3 B4 启用且显示地板" "地板=80%"

# 4. B3/B4 未配置 → 显示 未启用
newdir d4; printf 'go test ./...\n' > docs/flow/verify-cmd
run_code "no B3/B4 → exit 0" 0
has "d4 B3 未启用" "B3 健壮性门    ⏸️ 未启用"
has "d4 B4 未启用" "B4 覆盖率门    ⏸️ 未启用"

# 5. cross-verify opt-in → 显示适配器键 + 健康行（stub 环境无 auth → 降级，但 doctor 不崩、仍 exit 0）
newdir d5; printf 'pytest\n' > docs/flow/verify-cmd; printf 'codex-cli\n' > docs/flow/cross-verify
run_code "cross-verify opt-in → exit 0 (健康检查降级不致崩)" 0
has "d5 cross-verify opt-in" "cross-verify   ✅ opt-in"
has "d5 列出适配器键" "codex-cli"

# 6. 未 opt-in cross → 显示 未 opt-in
newdir d6; printf 'pytest\n' > docs/flow/verify-cmd
run_code "no cross-verify → exit 0" 0
has "d6 cross-verify 未 opt-in" "cross-verify   ⏸️ 未 opt-in"

# 6b. 配置了已弃用/未知适配器键（codex-mcp）→ 警告未知（不冒充已生效，免 dispatch 时炸）
newdir d6b; printf 'pytest\n' > docs/flow/verify-cmd; printf 'codex-mcp\n' > docs/flow/cross-verify
run_code "deprecated adapter key codex-mcp → exit 0" 0
has "d6b 警告未知/已弃用适配器键" "未知/已弃用"
hasnt "d6b 不把 codex-mcp 显示为 ✅ opt-in 已生效" "✅ opt-in   适配器键: codex-mcp"

# 6c. cross-execute 校验适配器键：合法 codex-cli → ✅；垃圾键 → 警告未知（不冒充已生效）
newdir d6c; printf 'pytest\n' > docs/flow/verify-cmd; printf 'codex-cli\n' > docs/flow/cross-execute
run_code "cross-execute codex-cli → exit 0" 0
has "d6c cross-execute 有效键 ✅" "cross-execute  ✅ opt-in   适配器键: codex-cli"
newdir d6d; printf 'pytest\n' > docs/flow/verify-cmd; printf 'whatever-garbage\n' > docs/flow/cross-execute
run_code "cross-execute garbage key → exit 0" 0
has "d6d cross-execute 垃圾键警告" "适配器键 'whatever-garbage' 未知"
hasnt "d6d 不把垃圾键显示为 ✅" "cross-execute  ✅ opt-in   适配器键: whatever-garbage"

# 7. --quiet 只给退出码、不打印（无 verify-cmd → 1）
newdir d7
sh "$DOCTOR" --quiet >"$TMP/qout" 2>&1; qc=$?
if [ "$qc" -eq 1 ] && [ ! -s "$TMP/qout" ]; then PASS=$((PASS+1)); printf 'PASS  --quiet 静默且 exit 1\n'
else FAIL=$((FAIL+1)); printf 'FAIL  --quiet: exit=%s 输出字节=%s\n' "$qc" "$(wc -c <"$TMP/qout")"; fi

# 8. 纪律级章节始终在场（诚实标注非机器强制）
newdir d8; printf 'npm test\n' > docs/flow/verify-cmd
run_code "discipline section present → exit 0" 0
has "d8 标注 builder≠verifier 为纪律级" "builder≠verifier"
has "d8 标注 hook 无法证明" "hook 无法证明"

# 9. doctor 只读：跑完不应在 docs/flow 留下新文件（无副作用 / 无状态）
newdir d9; printf 'npm test\n' > docs/flow/verify-cmd
_before=$(ls -A docs/flow | sort)
sh "$DOCTOR" >/dev/null 2>&1
_after=$(ls -A docs/flow | sort)
if [ "$_before" = "$_after" ]; then PASS=$((PASS+1)); printf 'PASS  doctor 只读（docs/flow 无新增文件）\n'
else FAIL=$((FAIL+1)); printf 'FAIL  doctor 产生了副作用: before=[%s] after=[%s]\n' "$_before" "$_after"; fi

printf '\n==== %s passed, %s failed ====\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
