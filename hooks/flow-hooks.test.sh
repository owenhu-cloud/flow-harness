#!/bin/sh
# flow-reinject.sh / flow-bootstrap.sh 的自检：喂合成输入，断言注入内容与 JSON 合法。
# 纯 POSIX sh + python3（仅用于 JSON 合法性校验）。
set -u
DIR=$(cd "$(dirname "$0")" && pwd)
RE="$DIR/flow-reinject.sh"; BS="$DIR/flow-bootstrap.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok()  { if [ "$1" = 0 ]; then PASS=$((PASS+1)); printf 'PASS  %s\n' "$2"; else FAIL=$((FAIL+1)); printf 'FAIL  %s\n' "$2"; fi; }
has() { printf '%s' "$1" | grep -q "$2"; }
jsonok() { printf '%s' "$1" | python3 -c 'import sys,json; json.load(sys.stdin)' 2>/dev/null; }

# ---- reinject：路由抗压低 ----
out=$(printf '{"prompt":"add a small button"}' | sh "$RE")
has "$out" '\[Flow\]' && ! has "$out" '地板'; ok $? "reinject 普通任务 → 基线、无地板提示"
jsonok "$out"; ok $? "reinject 普通任务 → JSON 合法"

out=$(printf '{"prompt":"write a db migration for users"}' | sh "$RE")
has "$out" '地板'; ok $? "reinject 'migration' → 地板提示"

out=$(printf '{"prompt":"做个数据库迁移并改权限"}' | sh "$RE")
has "$out" '地板'; ok $? "reinject '迁移/权限' → 地板提示"

out=$(printf '{"prompt":"refresh the auth token please"}' | sh "$RE")
has "$out" '地板'; ok $? "reinject 'token' → 地板提示"
jsonok "$out"; ok $? "reinject 含地板 → JSON 合法"

out=$(printf '{"prompt":"deploy to production #skip-flow"}' | sh "$RE"); code=$?
{ [ -z "$out" ] && [ "$code" = 0 ]; }; ok $? "reinject #skip-flow → 静默 exit 0（先于地板判定）"

# #1 回归：句首/标题大写也要命中（折叠小写）
out=$(printf '{"prompt":"Migrate the Database and update the Schema"}' | sh "$RE")
has "$out" '地板'; ok $? "reinject 大写 'Migrate/Schema' → 地板（折叠小写修复）"
out=$(printf '{"prompt":"Deploy to Production now"}' | sh "$RE")
has "$out" '地板'; ok $? "reinject 大写 'Deploy/Production' → 地板"

# 破坏性 SQL 覆盖
out=$(printf '{"prompt":"please drop table users"}' | sh "$RE")
has "$out" '地板'; ok $? "reinject 'drop table' → 地板"

# 与 flow 地板表对齐：CI/CD、资金、回填 也须命中（修 doc/impl 漂移）
out=$(printf '{"prompt":"update the CI/CD pipeline config"}' | sh "$RE")
has "$out" '地板'; ok $? "reinject 'CI/CD pipeline' → 地板"
out=$(printf '{"prompt":"做一次资金对账的数据回填"}' | sh "$RE")
has "$out" '地板'; ok $? "reinject '资金/回填' → 地板"

# 子串噪声（已知、文档化、nudge-only 低害）
out=$(printf '{"prompt":"build a tokenizer module"}' | sh "$RE")
has "$out" '地板'; ok $? "reinject 子串噪声 'tokenizer'→地板（已知低害）"

# 注入安全：刁钻 prompt（引号/反斜杠/反引号/emoji）→ JSON 合法 且 prompt 不回显
out=$(printf '%s' '{"prompt":"x \"q\" \\ `bt` 😀 MAGICLEAK migration"}' | sh "$RE")
jsonok "$out"; ok $? "reinject 刁钻 prompt → JSON 合法（注入防护）"
{ ! has "$out" 'MAGICLEAK'; }; ok $? "reinject 不回显 prompt（无注入泄漏）"

# ---- bootstrap：过期守卫 ----
mkdir -p "$TMP/b1"; cd "$TMP/b1"
out=$(sh "$BS")
has "$out" '已启用' && ! has "$out" '过期'; ok $? "bootstrap 无 project.md → 基线、无过期提示"
jsonok "$out"; ok $? "bootstrap → JSON 合法"

mkdir -p "$TMP/b2/docs/flow"; cd "$TMP/b2"
touch -t 202001010000 docs/flow/project.md
touch -t 202401010000 package.json
out=$(sh "$BS")
has "$out" '过期'; ok $? "bootstrap 清单晚于画像 → 过期提示"
jsonok "$out"; ok $? "bootstrap 含过期 → JSON 合法"

mkdir -p "$TMP/b3/docs/flow"; cd "$TMP/b3"
touch -t 202401010000 docs/flow/project.md
touch -t 202001010000 package.json
out=$(sh "$BS")
! has "$out" '过期'; ok $? "bootstrap 画像晚于清单 → 无过期提示"

mkdir -p "$TMP/b4/docs/flow"; cd "$TMP/b4"
touch -t 202301010000 docs/flow/project.md package.json
out=$(sh "$BS")
! has "$out" '过期'; ok $? "bootstrap 同秒 mtime → 不报过期（fail-safe）"

printf '\n==== %s passed, %s failed ====\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
