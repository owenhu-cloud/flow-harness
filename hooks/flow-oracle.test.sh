#!/bin/sh
# flow-oracle.sh 的自检：喂合成 Stop 输入，断言退出码与门控行为。
# 纯 POSIX sh，不调用 claude、不联网。每例构造独立临时目录（必要时建临时 git 仓库）。
# 用例分组：
#   放行/打回基础：opt-in 放行 / stop_hook_active / 命令通过 / 命令失败 / 注释-only
#   完整性-真打回：skip(.skip/xtest/.todo/t.Skipf) 注入 / 删断言 / 删测试文件 / verify-cmd 自篡改 /
#                  未提交豁免文件不生效(HACK2)
#   完整性-不误报：正常加测试 / 删 import(require) / 单行重命名 / 跨文件搬移断言 /
#                  非测试文件含 skip 字样 / 已提交豁免生效 / 非 git 优雅跳过
set -u
ORACLE=$(cd "$(dirname "$0")" && pwd)/flow-oracle.sh
[ -f "$ORACLE" ] || { echo "找不到 $ORACLE"; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
NOSTOP='{"stop_hook_active":false}'
ACTIVE='{"stop_hook_active":true}'

run() {  # run <name> <expected_code> <stdin_json>
  _name=$1; _exp=$2; _json=$3
  printf '%s' "$_json" | sh "$ORACLE" >/dev/null 2>"$TMP/err"; _code=$?
  if [ "$_code" -eq "$_exp" ]; then
    PASS=$((PASS+1)); printf 'PASS  %s (exit %s)\n' "$_name" "$_code"
  else
    FAIL=$((FAIL+1)); printf 'FAIL  %s: expected %s got %s\n' "$_name" "$_exp" "$_code"
    sed 's/^/        err> /' "$TMP/err" | head -6
  fi
}
newdir() { WORK="$TMP/$1"; mkdir -p "$WORK/docs/flow"; cd "$WORK" || exit 1; }
setcmd() { printf '%s\n' "$1" > "$WORK/docs/flow/verify-cmd"; }
gitinit() { git init -q; git config user.email t@t; git config user.name t; }

# ---- 放行/打回基础 ----
newdir c1;  run "no verify-cmd → pass" 0 "$NOSTOP"
newdir c2;  setcmd 'false'; run "stop_hook_active → pass" 0 "$ACTIVE"
newdir c3;  setcmd 'true';  run "cmd pass (non-git) → pass" 0 "$NOSTOP"
newdir c4;  setcmd 'false'; run "cmd fail → block" 2 "$NOSTOP"
newdir c5;  printf '# c\n\n' > docs/flow/verify-cmd; run "comment-only cmd → pass" 0 "$NOSTOP"

# ---- 完整性：真打回 ----
# skip 注入（.skip）
newdir c6;  setcmd 'true'; gitinit
mkdir -p tests; printf 'test("a", () => { expect(1).toBe(1) })\n' > tests/foo.test.js
git add -A; git commit -qm base
printf 'test.skip("a", () => { expect(1).toBe(1) })\n' > tests/foo.test.js
run "skip injection (.skip) → block" 2 "$NOSTOP"

# xtest 注入（verifier 发现的漏网别名）
newdir c6b; setcmd 'true'; gitinit
mkdir -p tests; printf 'test("a", () => { expect(1).toBe(1) })\n' > tests/foo.test.js
git add -A; git commit -qm base
printf 'xtest("a", () => { expect(1).toBe(1) })\n' > tests/foo.test.js
run "skip injection (xtest) → block" 2 "$NOSTOP"

# it.todo 注入（去断言 + todo）
newdir c6c; setcmd 'true'; gitinit
mkdir -p tests; printf 'it("a", () => { expect(1).toBe(1) })\n' > tests/foo.test.js
git add -A; git commit -qm base
printf 'it.todo("a")\n' > tests/foo.test.js
run "skip injection (it.todo) → block" 2 "$NOSTOP"

# Go t.Skipf 注入
newdir c6d; setcmd 'true'; gitinit
mkdir -p pkg; printf 'func TestA(t *testing.T){ if got!=1 { t.Fatal("x") } }\n' > pkg/a_test.go
git add -A; git commit -qm base
printf 'func TestA(t *testing.T){ t.Skipf("later") }\n' > pkg/a_test.go
run "skip injection (t.Skipf) → block" 2 "$NOSTOP"

# 删断言
newdir c9;  setcmd 'true'; gitinit
mkdir -p tests; printf 'test("a", () => {\n  expect(foo()).toBe(1)\n})\n' > tests/foo.test.js
git add -A; git commit -qm base
printf 'test("a", () => {\n})\n' > tests/foo.test.js
run "delete-assertion → block" 2 "$NOSTOP"

# 删测试文件
newdir c8;  setcmd 'true'; gitinit
mkdir -p tests; printf 'test("a", () => { expect(1).toBe(1) })\n' > tests/foo.test.js
git add -A; git commit -qm base; git rm -q tests/foo.test.js
run "delete-test-file → block" 2 "$NOSTOP"

# verify-cmd 自篡改（已提交后被改 → 燃料不可信）
newdir cT;  gitinit
printf 'echo ok\n' > docs/flow/verify-cmd; git add -A; git commit -qm base
printf 'true\n' > docs/flow/verify-cmd            # 改了门的燃料（仍是通过命令）
run "verify-cmd self-tamper → block" 2 "$NOSTOP"

# 未提交的豁免文件不应生效（HACK2：agent 同轮 touch 拆门）
newdir cH;  setcmd 'true'; gitinit
mkdir -p tests; printf 'test("a", () => { expect(1).toBe(1) })\n' > tests/foo.test.js
git add -A; git commit -qm base
printf 'test.skip("a", () => { expect(1).toBe(1) })\n' > tests/foo.test.js
touch docs/flow/verify-allow-test-changes         # 未提交
run "uncommitted override + skip → block" 2 "$NOSTOP"

# ---- 完整性：不误报 ----
# 已提交的豁免文件生效
newdir cO;  setcmd 'true'; gitinit
mkdir -p tests; printf 'test("a", () => { expect(1).toBe(1) })\n' > tests/foo.test.js
touch docs/flow/verify-allow-test-changes
git add -A; git commit -qm base                   # 豁免文件已提交
printf 'test.skip("a", () => { expect(1).toBe(1) })\n' > tests/foo.test.js
run "committed override + skip → pass" 0 "$NOSTOP"

# 正常新增测试（含断言）
newdir c10; setcmd 'true'; gitinit
printf 'x\n' > app.js; git add -A; git commit -qm base
mkdir -p tests; printf 'test("new", () => { expect(2).toBe(2) })\n' > tests/new.test.js
git add -A; run "benign add-test → pass" 0 "$NOSTOP"

# 删除 import（require）不应被当成删断言（A2 假阳修复）
newdir cR;  setcmd 'true'; gitinit
mkdir -p tests
printf 'const fs = require("fs")\ntest("a", () => { expect(fs).toBeTruthy() })\n' > tests/foo.test.js
git add -A; git commit -qm base
printf 'test("a", () => { expect(true).toBeTruthy() })\n' > tests/foo.test.js
run "remove require import → pass" 0 "$NOSTOP"

# 单行测试改描述（断言在删+增两侧都在 → 净持平）不误报
newdir cN;  setcmd 'true'; gitinit
mkdir -p tests; printf 'test("old", () => { expect(1).toBe(1) })\n' > tests/foo.test.js
git add -A; git commit -qm base
printf 'test("new", () => { expect(1).toBe(1) })\n' > tests/foo.test.js
run "single-line rename → pass" 0 "$NOSTOP"

# 跨文件搬移断言（A 删、B 增 → 净持平）不误报
newdir cM;  setcmd 'true'; gitinit
mkdir -p tests
printf 'test("a", () => { expect(1).toBe(1) })\n' > tests/a.test.js
printf 'test("b", () => {})\n' > tests/b.test.js
git add -A; git commit -qm base
printf 'test("a", () => {})\n' > tests/a.test.js
printf 'test("b", () => { expect(1).toBe(1) })\n' > tests/b.test.js
run "move assertion across test files → pass" 0 "$NOSTOP"

# 非测试文件含 skip/only 字样 → 不触发（限定测试文件）
newdir c11; setcmd 'true'; gitinit
printf 'a\n' > README.md; git add -A; git commit -qm base
printf 'we can skip this. .only( looks scary. expect(\n' >> README.md
run "non-test 'skip/expect' words → pass" 0 "$NOSTOP"

# #3 一行挤多个断言凑数：删含 2 断言的行、加 1 永真断言（行计数会漏，占用数计数应抓）
newdir cP;  setcmd 'true'; gitinit
mkdir -p tests
printf 'test("a", () => { expect(foo()).toBe(1); expect(bar()).toBe(2) })\n' > tests/foo.test.js
git add -A; git commit -qm base
printf 'test("a", () => { expect(true).toBe(true) })\n' > tests/foo.test.js
run "pack-multi-assert-one-line (2>1) → block" 2 "$NOSTOP"

# #2 测试文件被 assume-unchanged 标记后掏空 → git diff 失明，A0b 应抓
newdir cAU; setcmd 'true'; gitinit
mkdir -p tests; printf 'test("a", () => { expect(1).toBe(1) })\n' > tests/foo.test.js
git add -A; git commit -qm base
git update-index --assume-unchanged tests/foo.test.js
printf 'test.skip("a", () => {})\n' > tests/foo.test.js
run "assume-unchanged test file → block" 2 "$NOSTOP"

printf '\n==== %s passed, %s failed ====\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
