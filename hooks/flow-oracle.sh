#!/bin/sh
# Flow 治"自说自话"：独立 Oracle。agent 试图结束（Stop）时，由本 hook —— 一个
# 与 agent 无关的进程 —— 裁决"完成"。完成不再由 agent 自说自话，而由机制裁决。
#
# 四道独立门，任一不过即 exit 2 打回：
#   A. 完整性门：扫 git diff，禁止靠删测试 / 注入 skip / 删断言来"变绿"（语法层守卫）。
#   B. 验证命令门：跑 docs/flow/verify-cmd，退出码即裁决。
#   B2. 测试数基线门：解析 runner 输出的"通过数"，低于 docs/flow/test-count 即打回
#       （语义层守卫——抓 grep 抓不到的"测试数下降"，如删测试/skip 的等价变体）。
#   B3. 健壮性门（opt-in：docs/flow/robustness-cmd 存在时）：单独跑错误路径/异常场景测试子集，
#       非 0 或通过数低于 docs/flow/robustness-count 即打回（治"只测 happy-path 即判完成"——
#       异常路径覆盖从 implement verifier 的提示词自述，升级为机器可裁决的硬门）。
#       B2/B3 的通过数比较共用 check_count_baseline()，并在此修复 bignum 基线致比较出错被静默放行的缺陷。
# 降本（严格 opt-in）：存在 docs/flow/verify-cache 时，状态指纹与上次绿相同即跳过全部门。
#   默认关闭 → 行为不变；仅 git、指纹保守、非 git/失败即回退到"跑"。已知 false-skip 边界：
#     ① 指纹用 --exclude-standard：.gitignore 的测试依赖（.env/fixtures/本地 DB）改动不触发
#        失效——测试依赖被忽略文件时勿开 verify-cache（纳入全部 ignored 文件会拖垮指纹）。
#     ② .last-green 掺入机器/仓库路径身份，**勿提交共享**；跨机/CI 各自重建。
#     ③ 开 verify-cache = 把门可靠性下放给指纹完备性：指纹任一盲点会同时穿透 A/B/B2 三门。
#     ④ 含换行的未跟踪文件名（病态）可能漏入指纹——极罕见，已知边界。
#
# 威胁模型与边界（诚实声明，勿夸大）：
#   本门防的是"压力下的 reward-hacking"，提高绕过成本、留审计痕迹，不是沙箱级隔离。
#   仍未关闭的绕过（需覆盖率/变异测试 + 带外门控才能根治）：
#     ① 同数语义掏空：测试仍在、仍通过，只把内部真断言换成等量永真断言
#        （删 expect(x).toBe(y) 同时加 expect(true).toBe(true)）——测试数不变，B2 抓不到；
#        断言占用数也持平，A2 抓不到。需覆盖率/变异测试。
#     ② verify-cmd 间接层：verify-cmd=`sh run.sh` 时，A0 只查 verify-cmd 本身，
#        改未提交的 run.sh 可绕过。建议验证命令自包含，或其脚本一并提交。
#     ③ 有 commit 权限可提交弱化后绕过（只查未并入 HEAD 的工作树改动）；
#        本轮新建、未提交的测试文件不进 git diff，掏空后对完整性门不可见。
#     ④ agent 直接覆写 hooks/flow-oracle.sh / verify-cmd / test-count 自身——
#        脚本无法防自身字节被改；基线文件可被改低（故建议纳入版本控制、人审其变更）。
#   B2 基线门特有的语义层边界（同样需覆盖率/变异 + 人审才能根治）：
#     ⑤ 解析的是 runner 输出文本，agent 可影响：测试内 print("999 passed") 可向上伪造计数；
#        reporter 不匹配任一正则时 B2 降级放行（unparseable=放行），改 reporter/吞摘要即绕过。
#     ⑥ 首次建立的基线是 TOFU（trust-on-first-use，未经核验）：先弱化再首绿会把地板锁低位，
#        "0 passed" 锁 0 即永久失效。故 docs/flow/test-count 应提交并人审，且依赖完整性门 A
#        拦截已跟踪测试的掏空（B2 与 A 互补，非替代）。
#   B3 健壮性门特有边界（与 B2 同源，不夸大）：
#     ⑦ B3 是 verify-cmd opt-in 之上的叠加门：未写 verify-cmd 时整体在"未 opt-in 早退"处即放行，
#        单放 robustness-cmd 不会触发 B3。verify 技能要求两文件一并写入（测试存在后才落）。
#     ⑧ robustness-count 同样是 TOFU + 可被改低（threat ④/⑥同理）；科学计数法等被篡改成小数的
#        基线（grep 取首个数字段 → 1e+30 读成 1）等价于"基线改低"，靠提交+人审 robustness-count 兜底。
#     ⑨ 开 verify-cache 后，指纹排除 docs/flow/ → 仅改低 robustness-count 不变指纹会被 false-skip
#        （与 B2/test-count 完全同源的已知边界）；故 verify-cache 严格 opt-in、默认关。
#     注：bignum 基线（>18 位）现由 _plausible_count 拦下——纯数字超界打回、解析侧截断为不可解析，
#        不再出现"比较出错被静默吞成 false → 测试数暴跌反放行"（见 B2/B3 回归测试 cBN1/cBN2）。
#   为让门生效，建议把 docs/flow/{verify-cmd,robustness-cmd,test-count,robustness-count,verify-allow-test-changes} 纳入版本控制并人审其变更。
#
# 严格 opt-in：仅当 docs/flow/verify-cmd 存在且非空时整体生效（由 profile / verify 写入）；
# 不存在则立即放行（零侵入）。命中 stop_hook_active 则放行，避免死循环。
# 无强依赖：仅 POSIX sh / grep / sed / git；不需 jq。grep 模式不依赖 \b（兼容 BSD grep）。

INPUT=$(cat)

case "$INPUT" in
  *'"stop_hook_active":true'*|*'"stop_hook_active": true'*) exit 0 ;;
esac

CMD_FILE="docs/flow/verify-cmd"
ALLOW_FILE="docs/flow/verify-allow-test-changes"
COUNT_FILE="docs/flow/test-count"
RCMD_FILE="docs/flow/robustness-cmd"     # B3 健壮性门的燃料（错误路径/异常场景测试子集命令）
RCOUNT_FILE="docs/flow/robustness-count" # B3 的通过数基线（守异常路径测试不被悄悄删/掏空）
[ -f "$CMD_FILE" ] || exit 0          # 未 opt-in：放行
CMD=$(grep -v '^[[:space:]]*#' "$CMD_FILE" | grep -v '^[[:space:]]*$' \
      | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | head -n1)
[ -n "$CMD" ] || exit 0               # 空命令：放行（视为该项目无法自动验证）

# 测试文件路径模式（限定扫描范围）；刻意排除 docs/flow/（Oracle 自身产物含 "test" 字样会误捕）。
TS1='*test*'; TS2='*spec*'; TS3='*Test*'; TS4='*Spec*'; EXCL=':(exclude)docs/flow/*'

# 豁免是否生效：git 下仅"已提交且本轮未改动"才算（堵同轮 touch 自助拆门）；
# 非 git 无从验证跟踪状态，按"存在即生效"（已声明边界）。完整性门与基线门共用。
override_active() {
  [ -f "$ALLOW_FILE" ] || return 1
  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git ls-files --error-unmatch "$ALLOW_FILE" >/dev/null 2>&1 \
      && ! git diff HEAD -- "$ALLOW_FILE" 2>/dev/null | grep -q . && return 0
    return 1
  fi
  return 0
}

# 从 runner 输出解析"通过测试数"。命中即回，未识别回空（→ 降级放行，不误门控）。
# 多 suite/多 package 输出按同格式**求和**（非 tail）：顺序无关、消除并行交错抖动。
# 只要解析确定性，绝对精度不重要：建立与比较用同一解析，地板自洽。
extract_count() {
  _o=$1; _n=''
  _n=$(printf '%s\n' "$_o" | grep -oiE '[0-9]+ (passed|passing)' | grep -oE '[0-9]+' | awk '{s+=$1} END{if(NR)print s}')
  [ -z "$_n" ] && _n=$(printf '%s\n' "$_o" | grep -oiE '[0-9]+ examples?'  | grep -oE '[0-9]+' | awk '{s+=$1} END{if(NR)print s}')
  [ -z "$_n" ] && _n=$(printf '%s\n' "$_o" | grep -oiE 'ran [0-9]+ tests?' | grep -oE '[0-9]+' | awk '{s+=$1} END{if(NR)print s}')
  if [ -z "$_n" ]; then
    _c=$(printf '%s\n' "$_o" | grep -cE '^[[:space:]]*--- PASS:')   # go test -v
    [ "$_c" -gt 0 ] && _n=$_c
  fi
  # 防 bignum 投毒：runner 输出里的 "99999999999999999999 passed" 会被求和成超 int64 的数，
  # 一旦写进基线，后续 `[ -lt ]` 比较出错被静默吞成 false → 测试数暴跌反被放行。
  # 源头截断：>18 位（必超真实测试规模、且超 int64 安全域）一律视为无法解析（→ 降级放行，不污染基线）。
  _plausible_count "$_n" || _n=''
  printf '%s' "$_n"
}

# 合法通过数判定：非空、纯数字、且 ≤18 位（保证落在 int64 安全比较域，杜绝 bignum 比较出错）。
_plausible_count() {
  case "$1" in ''|*[!0-9]*) return 1 ;; esac
  [ "${#1}" -le 18 ]
}

# 统一的"通过数基线门"：解析输出通过数，与基线比较。B2/B3 共用——bignum 修复只在此一处。
# 返回 0=放行（含首次建立 / 正当下降刷新），2=打回（信息走 stderr）。
# 基线值超出可信整数域（>18 位）→ 几乎必为篡改/损坏，打回而非静默放行（堵 bignum 误裁决）。
check_count_baseline() {
  _out=$1; _cf=$2; _label=$3
  _cur=$(extract_count "$_out")
  [ -n "$_cur" ] || return 0                       # 解析不出 → 降级放行（不误门控）
  if [ -f "$_cf" ]; then
    _base=$(grep -oE '[0-9]+' "$_cf" | head -n1)
    [ -n "$_base" ] || return 0                     # 基线无数字（垃圾文件）→ 跳过比较（保守）
    if ! _plausible_count "$_base"; then
      printf '[Flow Oracle] %s未通过：基线值 %s 超出可信整数域（>18 位），疑被篡改/损坏。\n' "$_label" "$_base" >&2
      printf '请人工核对并修正 %s（应为正常的通过测试数），再收尾。\n' "$_cf" >&2
      return 2
    fi
    if [ "$_cur" -lt "$_base" ]; then
      if override_active; then
        printf '%s\n' "$_cur" > "$_cf"               # 正当下降（已提交豁免）→ 刷新基线
      else
        printf '[Flow Oracle] %s未通过：通过数从基线 %s 跌到 %s，疑掏空/删/skip 测试。\n' "$_label" "$_base" "$_cur" >&2
        printf '挂了就是没过，恢复测试或修实现；若为正当删减，提交 %s 后再收尾（留审计痕迹）。\n' "$ALLOW_FILE" >&2
        return 2
      fi
    fi
  else
    printf '%s\n' "$_cur" > "$_cf"                    # 首次绿：建立基线
  fi
  return 0
}

# 可移植哈希（变更检测用）：优先 shasum/sha1sum，回退 cksum。
_hash() {
  if command -v shasum >/dev/null 2>&1; then shasum | awk '{print $1}'
  elif command -v sha1sum >/dev/null 2>&1; then sha1sum | awk '{print $1}'
  else cksum | awk '{print $1"-"$2}'; fi
}

# 验证相关状态的保守指纹：HEAD + 已跟踪改动 + 未跟踪文件内容 + verify-cmd 本身。
# 刻意排除 docs/flow/（Oracle 自身产物，含 .last-green/test-count，否则写产物会自扰动指纹）。
# 非 git 回空 → 调用方据此永不跳过（fail-safe-to-run）。
verify_fingerprint() {
  command -v git >/dev/null 2>&1 || return 0
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  {
    git rev-parse HEAD 2>/dev/null
    git diff HEAD -- . "$EXCL" 2>/dev/null
    git ls-files --others --exclude-standard -- . "$EXCL" 2>/dev/null \
      | while IFS= read -r _f; do printf '== %s\n' "$_f"; cat "$_f" 2>/dev/null; done
    cat "$CMD_FILE" 2>/dev/null
    cat "$RCMD_FILE" 2>/dev/null                  # B3 燃料变更须使缓存失效（否则改 robustness-cmd 后 false-skip）
    git rev-parse --show-toplevel 2>/dev/null    # 仓库绝对路径 + 机器身份：
    uname -srm 2>/dev/null                        # 令被提交/共享的 .last-green 在异机/异路径不误匹配
  } | _hash
}

# ---------- 降本：跳过"自上次绿以来状态未变"（严格 opt-in：docs/flow/verify-cache 存在时）----------
# 默认关闭 → 门行为不变、依旧每次全验。开启后：指纹与上次绿相同即放行不重跑（含 A/B/B2）；
# 指纹相同意味着源码与 verify-cmd 均未变，上次绿的结论仍成立，跳过安全。
CACHE_FLAG="docs/flow/verify-cache"
LASTGREEN="docs/flow/.last-green"
FP=''
if [ -f "$CACHE_FLAG" ]; then
  FP=$(verify_fingerprint)
  if [ -n "$FP" ] && [ -f "$LASTGREEN" ] && [ "$FP" = "$(cat "$LASTGREEN" 2>/dev/null)" ]; then
    exit 0
  fi
fi

# ---------- A. 完整性门（git 仓库内）：禁止靠弱化测试"变绿" ----------
SKIP_RE='(\.(skip|only|todo)\(|(xit|xdescribe|fit|fdescribe|xtest)\(|(it|test|describe)\.(skip|todo)|@pytest\.mark\.(skip|xfail)|@unittest\.skip|pytest\.skip\(|t\.Skip(Now|f)?\(|b\.Skip(Now|f)?\(|#\[ignore\])'
ASSERT_RE='(assert|expect\(|t\.(error|fatal)|\.should|should\.)'   # 不含 require：多为 import，会误伤

if command -v git >/dev/null 2>&1 \
   && git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
   && git rev-parse --verify HEAD >/dev/null 2>&1; then

  # A0. 门的"燃料"（verify-cmd / robustness-cmd）在未提交改动中被改 → 不可信，打回（仅 tracked 可查）。
  if git diff HEAD -- "$CMD_FILE" "$RCMD_FILE" 2>/dev/null | grep -q .; then
    {
      printf '[Flow Oracle] 完整性门未通过：docs/flow/verify-cmd 或 robustness-cmd（门的燃料）在未提交改动中被修改，不可信。\n'
      printf '若为正当更新验证命令，请先提交该文件再收尾（留审计痕迹）；否则恢复原命令。\n'
    } >&2
    exit 2
  fi

  # A0b. 测试文件被 assume-unchanged / skip-worktree → git diff 失明，整门被静默架空。
  if git ls-files -v -- "$TS1" "$TS2" "$TS3" "$TS4" "$EXCL" 2>/dev/null | grep -Eq '^([a-z]|S) '; then
    {
      printf '[Flow Oracle] 完整性门未通过：有测试文件被标记 assume-unchanged/skip-worktree，git diff 看不见其改动。\n'
      printf '撤销后再收尾：git update-index --no-assume-unchanged / --no-skip-worktree <file>。\n'
    } >&2
    exit 2
  fi

  if ! override_active; then
    TDIFF=$(git diff HEAD -- "$TS1" "$TS2" "$TS3" "$TS4" "$EXCL" 2>/dev/null)
    VIOL=''

    # 占用数计数（grep -oE 数命中次数，非命中行数）——堵"一行挤多个删除/凑数"。
    # A1. 净新增跳过/忽略标记。
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
    if git diff HEAD --diff-filter=D --name-only -- "$TS1" "$TS2" "$TS3" "$TS4" "$EXCL" 2>/dev/null \
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
if [ "$CODE" -ne 0 ]; then
  # 失败：exit-2 契约阻止收尾——reason 走 stderr，无需手搓 JSON 转义。Claude Code 回灌给 agent。
  {
    printf '[Flow Oracle] 独立验证命令未通过（退出码 %s），不得声明完成。\n' "$CODE"
    printf '命令：%s\n' "$CMD"
    printf -- '--- 输出末 40 行 ---\n'
    printf '%s\n' "$OUT" | tail -n 40
    printf '修实现直到此命令绿，禁止改测试/断言/CI 使其变绿（红线 §1/§2）。\n'
  } >&2
  exit 2
fi

# ---------- B2. 测试数基线门（命令已绿）----------
# 解析通过数；与基线比。缺失则建立（establish-if-missing），低于基线即打回。
# 不向上 ratchet（避免 env 波动把地板锁到高水位后误门控）；正当下降经已提交豁免接受并刷新。
check_count_baseline "$OUT" "$COUNT_FILE" "测试数基线门" || exit 2

# ---------- B3. 健壮性门（命令已绿；严格 opt-in：docs/flow/robustness-cmd 存在且非空时生效）----------
# 治"只测 happy-path 就判完成"：单独跑错误路径/异常场景测试子集，强制其存在且全绿、通过数不下降。
# 与 verify-cmd 正交——B2 数全量、happy-path 增测可掩盖异常测试被删；B3 单独守异常路径子集。
# 不存在 robustness-cmd → 跳过（零侵入，行为同旧）。门由 plan 的 Robustness-Cases 契约 + verify 写入燃料。
if [ -f "$RCMD_FILE" ]; then
  RCMD=$(grep -v '^[[:space:]]*#' "$RCMD_FILE" | grep -v '^[[:space:]]*$' \
        | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | head -n1)
  if [ -n "$RCMD" ]; then
    ROUT=$(sh -c "$RCMD" 2>&1)
    RCODE=$?
    if [ "$RCODE" -ne 0 ]; then
      {
        printf '[Flow Oracle] 健壮性门未通过（robustness-cmd 退出码 %s），异常/错误路径测试未全绿，不得声明完成。\n' "$RCODE"
        printf '命令：%s\n' "$RCMD"
        printf -- '--- 输出末 40 行 ---\n'
        printf '%s\n' "$ROUT" | tail -n 40
        printf 'happy-path 全绿不等于完成：修实现直到异常路径测试也绿（红线 §1/§3）。\n'
      } >&2
      exit 2
    fi
    check_count_baseline "$ROUT" "$RCOUNT_FILE" "健壮性数基线门" || exit 2
  fi
fi

# 全部门通过 → 若开启缓存，记录本次绿的状态指纹，供下次 skip-if-unchanged。
[ -f "$CACHE_FLAG" ] && [ -n "$FP" ] && printf '%s\n' "$FP" > "$LASTGREEN"

exit 0
