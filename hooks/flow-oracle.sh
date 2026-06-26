#!/bin/sh
# Flow 治"自说自话"：独立 Oracle。agent 试图结束（Stop）时，由本 hook —— 一个
# 与 agent 无关的进程 —— 裁决"完成"。完成不再由 agent 自说自话，而由机制裁决。
#
# 两道独立门，任一不过即 exit 2 打回：
#   A. 完整性门：扫 git diff，禁止靠删测试 / 注入 skip / 删断言来"变绿"——堵住
#      "绿色退出码 + 被掏空的测试"这一 reward-hacking 盲区（红线 §1/§2 的机器级守卫）。
#   B. 验证命令门：跑 docs/flow/verify-cmd，退出码即裁决。
#
# 威胁模型与边界（诚实声明，勿夸大）：
#   本门防的是"压力下的 reward-hacking"——agent 为变绿而删/skip 测试、删断言。
#   它是提高绕过成本、留审计痕迹的纪律门，不是沙箱级隔离。已知绕过（grep 路线的
#   架构天花板，需 test-count 基线 / 带外门控才能根治，本版未做）：
#     ① 语义级掏空：块注释断言、清空测试体、把真断言换成等量的永真断言
#        （删 expect(x).toBe(y) 同时加 expect(true).toBe(true)，净计数持平）——
#        占用数计数能抓"一行挤多个删除"，但抓不到这种 1 换 1 的语义替换。
#     ② verify-cmd 间接层：verify-cmd=`sh run.sh` 时，A0 只查 verify-cmd 本身，
#        改未提交的 run.sh 可绕过 B 门。建议验证命令自包含，或其脚本一并提交。
#     ③ 有 commit 权限可提交弱化后绕过（v1 只查未并入 HEAD 的工作树改动）；
#        本轮新建、未提交的测试文件不进 git diff，掏空后对本门不可见。
#     ④ agent 直接覆写 hooks/flow-oracle.sh / verify-cmd 自身——脚本无法防自身字节被改。
#   为让门生效，建议把 docs/flow/verify-cmd 与豁免文件纳入版本控制。
#
# 严格 opt-in：仅当 docs/flow/verify-cmd 存在且非空时整体生效（由 profile / verify 写入）；
# 不存在则立即放行（零侵入）。命中 stop_hook_active 则放行，避免死循环。
# 无强依赖：仅 POSIX sh / grep / sed / git；不需 jq。grep 模式不依赖 \b（兼容 BSD grep）。

INPUT=$(cat)

case "$INPUT" in
  *'"stop_hook_active":true'*|*'"stop_hook_active": true'*) exit 0 ;;
esac

CMD_FILE="docs/flow/verify-cmd"
[ -f "$CMD_FILE" ] || exit 0          # 未 opt-in：放行
CMD=$(grep -v '^[[:space:]]*#' "$CMD_FILE" | grep -v '^[[:space:]]*$' \
      | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | head -n1)
[ -n "$CMD" ] || exit 0               # 空命令：放行（视为该项目无法自动验证）

# ---------- A. 完整性门：禁止靠弱化测试"变绿" ----------
ALLOW_FILE="docs/flow/verify-allow-test-changes"
# 测试文件路径模式（限定扫描范围，压低误报）。
TS1='*test*'; TS2='*spec*'; TS3='*Test*'; TS4='*Spec*'
# 新增"跳过/忽略测试"标记（多语言）。
SKIP_RE='(\.(skip|only|todo)\(|(xit|xdescribe|fit|fdescribe|xtest)\(|(it|test|describe)\.(skip|todo)|@pytest\.mark\.(skip|xfail)|@unittest\.skip|pytest\.skip\(|t\.Skip(Now|f)?\(|b\.Skip(Now|f)?\(|#\[ignore\])'
# 断言行（刻意不含 require：require( 多为 import，会误伤）。
ASSERT_RE='(assert|expect\(|t\.(error|fatal)|\.should|should\.)'

if command -v git >/dev/null 2>&1 \
   && git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
   && git rev-parse --verify HEAD >/dev/null 2>&1; then

  # A0. 自篡改：verify-cmd（门的"燃料"）在未提交改动中被改 → 燃料不可信，打回。
  #     仅在 verify-cmd 已纳入版本控制时可查（未跟踪则无从比对，见顶部边界声明）。
  if git diff HEAD -- "$CMD_FILE" 2>/dev/null | grep -q .; then
    {
      printf '[Flow Oracle] 完整性门未通过：docs/flow/verify-cmd（门的燃料）在未提交改动中被修改，不可信。\n'
      printf '若为正当更新验证命令，请先提交该文件再收尾（留审计痕迹）；否则恢复原命令。\n'
    } >&2
    exit 2
  fi

  # A0b. 测试文件被 assume-unchanged / skip-worktree 标记 → git diff 对其改动失明，
  #      整道完整性门被静默架空。检出即打回（git ls-files -v：小写状态=assume-unchanged，S=skip-worktree）。
  if git ls-files -v -- "$TS1" "$TS2" "$TS3" "$TS4" 2>/dev/null | grep -Eq '^([a-z]|S) '; then
    {
      printf '[Flow Oracle] 完整性门未通过：有测试文件被标记 assume-unchanged/skip-worktree，git diff 看不见其改动。\n'
      printf '撤销后再收尾：git update-index --no-assume-unchanged / --no-skip-worktree <file>。\n'
    } >&2
    exit 2
  fi

  # 豁免仅在"已提交且本轮未改动"时生效——堵住 agent 同轮 touch 豁免文件自助拆门。
  OVERRIDE_OK=0
  if [ -f "$ALLOW_FILE" ] \
     && git ls-files --error-unmatch "$ALLOW_FILE" >/dev/null 2>&1 \
     && ! git diff HEAD -- "$ALLOW_FILE" 2>/dev/null | grep -q .; then
    OVERRIDE_OK=1
  fi

  if [ "$OVERRIDE_OK" -ne 1 ]; then
    TDIFF=$(git diff HEAD -- "$TS1" "$TS2" "$TS3" "$TS4" 2>/dev/null)
    VIOL=''

    # 占用数计数（grep -oE 数命中次数，非命中行数）——堵"一行挤多个删除/凑数"。
    # A1. 净新增跳过/忽略标记（added > removed，避免重命名已跳过的测试误报）。
    SKIP_ADD=$(printf '%s\n' "$TDIFF" | grep -E '^\+'    | grep -oE  "$SKIP_RE"   | grep -c .)
    SKIP_DEL=$(printf '%s\n' "$TDIFF" | grep -E '^-[^-]' | grep -oE  "$SKIP_RE"   | grep -c .)
    [ "$SKIP_ADD" -gt "$SKIP_DEL" ] && \
      VIOL="${VIOL}- 净新增了跳过/忽略测试的标记（skip/only/todo/xit/xtest/@skip/t.Skip(f)/#[ignore]）\n"

    # A2. 断言"净减少"（删 > 增，避免重命名/跨文件搬移断言误报）。
    ASS_DEL=$(printf '%s\n' "$TDIFF" | grep -E '^-[^-]' | grep -oiE "$ASSERT_RE" | grep -c .)
    ASS_ADD=$(printf '%s\n' "$TDIFF" | grep -E '^\+'    | grep -oiE "$ASSERT_RE" | grep -c .)
    [ "$ASS_DEL" -gt "$ASS_ADD" ] && \
      VIOL="${VIOL}- 测试断言净减少（删 ${ASS_DEL} > 增 ${ASS_ADD}：assert/expect/should/t.Error…）\n"

    # A3. 删除整个测试文件。
    if git diff HEAD --diff-filter=D --name-only -- "$TS1" "$TS2" "$TS3" "$TS4" 2>/dev/null \
       | grep -q .; then
      VIOL="${VIOL}- 删除了测试文件\n"
    fi

    if [ -n "$VIOL" ]; then
      {
        printf '[Flow Oracle] 完整性门未通过：检测到疑似"弱化测试以变绿"的改动，不得声明完成。\n'
        printf '%b' "$VIOL"
        printf -- '--- 违反红线 §1/§2：挂了就是没过，改实现而非改测试。 ---\n'
        printf '若确为正当的测试增删（非掩盖失败），把 %s 提交进版本控制后再收尾（留审计痕迹）。\n' "$ALLOW_FILE"
      } >&2
      exit 2
    fi
  fi
fi

# ---------- B. 验证命令门 ----------
OUT=$(sh -c "$CMD" 2>&1)
CODE=$?
[ "$CODE" -eq 0 ] && exit 0           # Oracle 判定通过：放行

# 失败：用 Stop hook 的 exit-2 契约阻止收尾——reason 走 stderr，退出码 2 即 block。
# 刻意不组 JSON：stderr 可含任意字节（引号 / 换行 / ANSI），无需转义。Claude Code 会回灌给 agent。
{
  printf '[Flow Oracle] 独立验证命令未通过（退出码 %s），不得声明完成。\n' "$CODE"
  printf '命令：%s\n' "$CMD"
  printf -- '--- 输出末 40 行 ---\n'
  printf '%s\n' "$OUT" | tail -n 40
  printf '修实现直到此命令绿，禁止改测试/断言/CI 使其变绿（红线 §1/§2）。\n'
} >&2
exit 2
