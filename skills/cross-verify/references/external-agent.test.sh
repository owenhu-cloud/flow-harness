#!/bin/sh
# external-agent.sh 行为测试。stub CODEX_BIN/CODEX_HOME 实现确定性，不调真 codex。
# 含 argv 断言：守护参数构造（sandbox/prompt 引用/effort 引号），堵 mutation 盲点。
# 跑法: sh external-agent.test.sh ; echo $?   （全绿 exit 0）
set -u
DIR=$(cd "$(dirname "$0")" && pwd)
SUT="$DIR/external-agent.sh"
fail=0
check() { # want got label
  if [ "$1" = "$2" ]; then printf 'PASS: %s\n' "$3"
  else printf 'FAIL: %s (want=%s got=%s)\n' "$3" "$1" "$2"; fail=1; fi
}

[ -f "$SUT" ] || { echo "FAIL: external-agent.sh 不存在 (RED)"; exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/home"; : > "$TMP/home/auth.json"          # 假认证
# 假 codex：把 argv 逐行写 $ARGLOG、cwd 写 $PWDLOG，打印 canned 裁决（不改任何文件）
cat > "$TMP/argcodex" <<'EOF'
#!/bin/sh
[ -n "${ARGLOG:-}" ] && printf '%s\n' "$@" > "$ARGLOG"
[ -n "${PWDLOG:-}" ] && pwd > "$PWDLOG"
echo "Major | line 5 | unguarded map write under concurrency"
EOF
printf '#!/bin/sh\nexit 7\n' > "$TMP/failcodex"          # 失败
printf '#!/bin/sh\n:\n'     > "$TMP/emptycodex"          # 成功但零输出
chmod +x "$TMP/argcodex" "$TMP/failcodex" "$TMP/emptycodex"
PF="$TMP/prompt"; SENT='SENT-A;B `C` $(D) "E"'           # 含特殊字符的单行哨兵
printf '%s\n' "$SENT" > "$PF"
OF="$TMP/out"; ALOG="$TMP/arglog"

H="CODEX_HOME=$TMP/home"

# --- 退出码语义 ---
env CODEX_BIN="$TMP/argcodex"  CODEX_HOME="$TMP/home" sh "$SUT" healthcheck codex-cli
check 0 $? "healthcheck available -> 0"
env CODEX_BIN="$TMP/nope"      CODEX_HOME="$TMP/home" sh "$SUT" healthcheck codex-cli
check 3 $? "healthcheck missing-binary -> 3 (降级信号)"
env CODEX_BIN="$TMP/argcodex"  CODEX_HOME="$TMP/noauth" sh "$SUT" healthcheck codex-mcp
check 3 $? "healthcheck no-auth -> 3"
env CODEX_BIN="$TMP/argcodex"  CODEX_HOME="$TMP/home" sh "$SUT" healthcheck bogus 2>/dev/null
check 1 $? "未知 adapter -> 1"

# --- dispatch 退出码 ---
env CODEX_BIN="$TMP/argcodex"  CODEX_HOME="$TMP/home" sh "$SUT" dispatch codex-cli "$PF" "$OF"
check 0 $? "dispatch ok -> 0"
grep -q "Major" "$OF"; check 0 $? "dispatch 输出含 severity 标记"
env CODEX_BIN="$TMP/failcodex" CODEX_HOME="$TMP/home" sh "$SUT" dispatch codex-cli "$PF" "$OF" 2>/dev/null
check 1 $? "dispatch codex 失败 -> 1"
env CODEX_BIN="$TMP/nope"      CODEX_HOME="$TMP/home" sh "$SUT" dispatch codex-cli "$PF" "$OF" 2>/dev/null
check 3 $? "dispatch adapter 不可用 -> 3"
env CODEX_BIN="$TMP/emptycodex" CODEX_HOME="$TMP/home" sh "$SUT" dispatch codex-cli "$PF" "$OF" 2>/dev/null
check 1 $? "dispatch 空输出 -> 1 (M3 守护)"
env CODEX_BIN="$TMP/argcodex"  CODEX_HOME="$TMP/home" sh "$SUT" dispatch codex-cli "$TMP/nofile" "$OF" 2>/dev/null
check 1 $? "dispatch prompt-file 不存在 -> 1 (M8 守护)"

# --- argv 断言（守护参数构造，堵 M5/M6/M9）---
env CODEX_BIN="$TMP/argcodex" CODEX_HOME="$TMP/home" CROSS_VERIFY_EFFORT=high ARGLOG="$ALOG" \
  sh "$SUT" dispatch codex-cli "$PF" "$OF"
grep -qx -- '--sandbox' "$ALOG"; check 0 $? "argv 含 --sandbox (M6 守护)"
grep -qx 'read-only'    "$ALOG"; check 0 $? "argv 含 read-only 沙箱值 (M6 守护：verifier 不许改码)"
grep -qxF 'model_reasoning_effort="high"' "$ALOG"; check 0 $? "argv effort 引号正确 (M9 守护)"
grep -qxF "$SENT" "$ALOG"; check 0 $? "prompt 作单一 argv 原样传入、无分词无注入 (M5 守护)"

# --- dispatch-write（cross-execute 写沙箱）退出码 + 隔离守护 + dry-run argv/cwd 断言 ---
# stub codex 不真改文件，仅记录 argv/cwd —— 校验命令拼装（写沙箱值 / 不停等审批 / cwd=worktree）。
# 写沙箱只许落在隔离的 linked git worktree → 需构造真实 git 仓 + worktree（裸目录会被拒）。
PLOG="$TMP/pwdlog"
REPO="$TMP/repo"; mkdir -p "$REPO"
( cd "$REPO" && git init -q && git config user.email t@t.t && git config user.name t \
  && git commit -q --allow-empty -m init ) >/dev/null 2>&1
WT="$TMP/wt"
git -C "$REPO" worktree add -q -b wtbranch "$WT" HEAD >/dev/null 2>&1
have_git=0; [ -d "$WT" ] && git -C "$WT" rev-parse --absolute-git-dir >/dev/null 2>&1 && have_git=1

if [ "$have_git" -eq 1 ]; then
  env CODEX_BIN="$TMP/argcodex" CODEX_HOME="$TMP/home" sh "$SUT" dispatch-write codex-cli "$PF" "$OF" "$WT"
  check 0 $? "dispatch-write ok（隔离 worktree）-> 0"
  env CODEX_BIN="$TMP/nope" CODEX_HOME="$TMP/home" sh "$SUT" dispatch-write codex-cli "$PF" "$OF" "$WT" 2>/dev/null
  check 3 $? "dispatch-write adapter 不可用 -> 3"
  env CODEX_BIN="$TMP/failcodex" CODEX_HOME="$TMP/home" sh "$SUT" dispatch-write codex-cli "$PF" "$OF" "$WT" 2>/dev/null
  check 1 $? "dispatch-write codex 失败 -> 1"
  # 隔离守护：裸目录 / 主工作区 / 不存在 一律拒（写权限 agent 不许进非隔离目录）
  env CODEX_BIN="$TMP/argcodex" CODEX_HOME="$TMP/home" sh "$SUT" dispatch-write codex-cli "$PF" "$OF" "$TMP/home" 2>/dev/null
  check 1 $? "dispatch-write 拒裸目录（非 git worktree）-> 1"
  env CODEX_BIN="$TMP/argcodex" CODEX_HOME="$TMP/home" sh "$SUT" dispatch-write codex-cli "$PF" "$OF" "$REPO" 2>/dev/null
  check 1 $? "dispatch-write 拒主工作区（非 linked worktree）-> 1"
  env CODEX_BIN="$TMP/argcodex" CODEX_HOME="$TMP/home" sh "$SUT" dispatch-write codex-cli "$PF" "$OF" "$TMP/noworktree" 2>/dev/null
  check 1 $? "dispatch-write worktree 不存在 -> 1"

  env CODEX_BIN="$TMP/argcodex" CODEX_HOME="$TMP/home" CROSS_VERIFY_EFFORT=high \
    ARGLOG="$ALOG" PWDLOG="$PLOG" sh "$SUT" dispatch-write codex-cli "$PF" "$OF" "$WT"
  grep -qx -- '--sandbox' "$ALOG"; check 0 $? "dispatch-write argv 含 --sandbox"
  grep -qx 'workspace-write' "$ALOG"; check 0 $? "dispatch-write argv 含 workspace-write 沙箱值（准改码）"
  ! grep -qx 'read-only' "$ALOG"; check 0 $? "dispatch-write argv 不含 read-only（写模式不退回只读）"
  grep -qxF 'model_reasoning_effort="high"' "$ALOG"; check 0 $? "dispatch-write argv effort 引号正确"
  grep -qxF "$SENT" "$ALOG"; check 0 $? "dispatch-write prompt 作单一 argv 原样传入"
  check "$(cd "$WT" && pwd -P)" "$(cd "$(cat "$PLOG")" && pwd -P)" "dispatch-write 在 worktree 内执行（cwd=worktree）"
else
  echo "SKIP: dispatch-write 测试（git 不可用或 worktree 创建失败）"
fi

[ $fail -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "SOME FAILED"; exit 1; }
