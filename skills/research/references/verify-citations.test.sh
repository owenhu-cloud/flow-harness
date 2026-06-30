#!/bin/sh
# verify-citations.sh 的自检：纯 POSIX，离线。注入 mock URL 检查器（含 "dead" 即不可达），
# 用合成 sources.md 断言：源数阈值、可达性、空块/缺文件、MIN_SOURCES 覆盖、doi 计数。
set -u
DIR=$(cd "$(dirname "$0")" && pwd)
SCRIPT="$DIR/verify-citations.sh"
[ -f "$SCRIPT" ] || { echo "找不到 $SCRIPT"; exit 1; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0

# mock：url 含 "dead" → 不可达(exit1)，否则可达(exit0)
printf '#!/bin/sh\ncase "$1" in *dead*) exit 1;; *) exit 0;; esac\n' > "$TMP/chk.sh"
chmod +x "$TMP/chk.sh"
export FLOW_URL_CHECK="sh $TMP/chk.sh"

run() {  # run <name> <expected_code> <file-or-empty> [needle]
  _n=$1; _exp=$2; _f=$3; _needle=${4:-}
  out=$(MIN_SOURCES="${MIN_SOURCES:-3}" sh "$SCRIPT" $_f 2>"$TMP/err"); code=$?
  okc=1; [ "$code" -eq "$_exp" ] && okc=0
  okn=0; [ -n "$_needle" ] && { grep -q "$_needle" "$TMP/err" "$TMP/out" 2>/dev/null || grep -q "$_needle" "$TMP/err" || okn=1; }
  if [ "$okc" -eq 0 ] && [ "$okn" -eq 0 ]; then PASS=$((PASS+1)); printf 'PASS  %s (exit %s)\n' "$_n" "$code"
  else FAIL=$((FAIL+1)); printf 'FAIL  %s: expect %s got %s; needle=%s\n' "$_n" "$_exp" "$code" "$_needle"; sed 's/^/      err> /' "$TMP/err"|head -4; fi
}

# 1. 干净：2 断言各 3 源、全可达 → 0
cat > "$TMP/clean.md" <<'EOF'
## claim one
- t1 | https://ex.com/ok1
- t2 | https://ex.com/ok2
- t3 | doi:10.1/ok3
## claim two
- a | https://ok.com/a
- b | https://ok.com/b
- c | https://ok.com/c
EOF
run "clean (2 claims, 3 src, reachable) → pass" 0 "$TMP/clean.md"

# 2. 源数不足：一断言只 2 源 → 2
cat > "$TMP/under.md" <<'EOF'
## weak claim
- a | https://ok.com/a
- b | https://ok.com/b
EOF
run "under-sourced (2<3) → block" 2 "$TMP/under.md" "源数不足"

# 3. 不可达 URL → 2
cat > "$TMP/dead.md" <<'EOF'
## claim with dead link
- a | https://ok.com/a
- b | https://ok.com/b
- c | https://host.com/dead-page
EOF
run "dead URL → block" 2 "$TMP/dead.md" "不可达"

# 4. 无断言块 → 2
printf 'just some prose, no claims\n' > "$TMP/empty.md"
run "no claim blocks → block" 2 "$TMP/empty.md" "没有"

# 5. 缺文件 → 2
run "missing file → block" 2 "$TMP/nope.md" "找不到"

# 6. MIN_SOURCES=2 覆盖：上面的 under.md（2 源）应通过
MIN_SOURCES=2 run "MIN_SOURCES=2 lets 2-source pass" 0 "$TMP/under.md"

# 7. doi 行计为一个源且被检查（dead doi → 不可达）
cat > "$TMP/doi.md" <<'EOF'
## doi claim
- a | https://ok.com/a
- b | doi:10.1/ok
- c | doi:10.9/dead
EOF
run "doi counted & checked (dead doi) → block" 2 "$TMP/doi.md" "不可达"

# 8. REQUIRE_SUPPORT：每源带支撑摘录 → pass
cat > "$TMP/sup_ok.md" <<'EOF'
## supported claim
- t1 | https://ex.com/a | the paper states X increases Y by 12%
- t2 | https://ex.com/b | benchmark shows the same effect across models
- t3 | doi:10.1/c | meta-analysis confirms the direction holds
EOF
export REQUIRE_SUPPORT=1
run "REQUIRE_SUPPORT + excerpts → pass" 0 "$TMP/sup_ok.md"

# 9. REQUIRE_SUPPORT：缺摘录（仅 URL）→ block
cat > "$TMP/sup_missing.md" <<'EOF'
## unsupported claim
- t1 | https://ex.com/a
- t2 | https://ex.com/b
- t3 | doi:10.1/c
EOF
run "REQUIRE_SUPPORT + no excerpt → block" 2 "$TMP/sup_missing.md" "缺支撑摘录"

# 10. REQUIRE_SUPPORT：摘录过短 → block
cat > "$TMP/sup_short.md" <<'EOF'
## short-excerpt claim
- t1 | https://ex.com/a | ok
- t2 | https://ex.com/b | ok
- t3 | doi:10.1/c | ok
EOF
run "REQUIRE_SUPPORT + short excerpt → block" 2 "$TMP/sup_short.md" "缺支撑摘录"
# 10b. REQUIRE_SUPPORT：摘录内部含 `|` → 取第二个 `|` 之后全部 → 合法长摘录 pass（Codex 证伪边界）
cat > "$TMP/sup_pipe.md" <<'EOF'
## pipe-in-excerpt claim
- t1 | https://ex.com/a | supporting sentence with a | pipe inside it
- t2 | https://ex.com/b | another sufficiently long supporting excerpt
- t3 | doi:10.1/c | third sufficiently long supporting excerpt
EOF
run "REQUIRE_SUPPORT + excerpt containing pipe → pass" 0 "$TMP/sup_pipe.md"
unset REQUIRE_SUPPORT

# 11. 默认模式（无 REQUIRE_SUPPORT）：缺摘录仍 pass（向后兼容，证明既有契约不破）
run "default mode ignores missing excerpt → pass" 0 "$TMP/sup_missing.md"

printf '\n==== %s passed, %s failed ====\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
