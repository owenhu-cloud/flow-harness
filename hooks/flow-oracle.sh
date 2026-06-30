#!/bin/sh
# Flow 治"自说自话"：独立 Oracle。agent 试图结束（Stop）时，由本 hook —— 一个
# 与 agent 无关的进程 —— 裁决"完成"。完成不再由 agent 自说自话，而由机制裁决。
#
# 六道独立门，任一不过即 exit 2 打回：
#   A1. 意图契约门：本会话用编辑工具改了文件、却无任何 agent 正文(text)消息产出过意图锚 → 打回
#       （治"装了也不懂用户意图"）。机器锚：存在一条「含 "type":"text" 块且该行有 `Intent:` 子串」的
#       assistant 行（行级近似，非块级解析；纯 tool_use payload 的 Intent 被排除，混行边界见 A1 段注释）。
#       四行完整性(Intent/Constraints/Non-goals/Verify-signal)属纪律级(router+reinject)，非机器校验。
#       会话级、保守、fail-open（任何歧义即放行）；opt-out：建 docs/flow/intent-gate-off。
#   A. 完整性门：扫 git diff，禁止靠删测试 / 注入 skip / 删断言来"变绿"（语法层守卫）。
#   B. 验证命令门：跑 docs/flow/verify-cmd，退出码即裁决。
#   B2. 测试数基线门：解析 runner 输出的"通过数"，低于 docs/flow/test-count 即打回
#       （语义层守卫——抓 grep 抓不到的"测试数下降"，如删测试/skip 的等价变体）。
#   B3. 健壮性门（opt-in：docs/flow/robustness-cmd 存在时）：单独跑错误路径/异常场景测试子集，
#       非 0 或通过数低于 docs/flow/robustness-count 即打回（治"只测 happy-path 即判完成"——
#       异常路径覆盖从 implement verifier 的提示词自述，升级为机器可裁决的硬门）。
#       B2/B3 的通过数比较共用 check_count_baseline()，并在此修复 bignum 基线致比较出错被静默放行的缺陷。
#   B4. 覆盖率门（opt-in：docs/flow/coverage-cmd 存在时）：跑带覆盖率统计的测试命令，退出码非 0 即打回；
#       若设 docs/flow/coverage-min 地板，解析覆盖率% 低于地板亦打回（解析不出则仅退出码裁决）。
#       B4 是"绝对地板"——覆盖率低于 coverage-min（或 coverage-cmd 自带阈值）即打回，非动态基线/ratchet。
#       它能抓"删分支/删错误路径测试使覆盖率跌破地板"（计数门抓不到）；但：地板设太低则跌而未破不拦（见⑬），
#       且抓不到"同路径假断言"（expect(x).toBe(y)→expect(true).toBe(true) 路径不变、覆盖率不降）——那需变异，见⑩。
#       变异测试刻意不入本门（每次收尾跑变异分钟级、会逼用户关掉整个 Oracle）；见威胁模型⑩。
# 降本（严格 opt-in）：存在 docs/flow/verify-cache 时，状态指纹与上次绿相同即跳过【昂贵的 verify-cmd
#   执行】（B/B2/B3/B4）。**A 完整性门 + A0c 基线门 always 跑、不被缓存跳过**（命中早退在 A 之后）。
#   默认关闭 → 行为不变；仅 git、指纹保守、非 git/失败即回退到"跑"。已知 false-skip 边界：
#     ① 指纹用 --exclude-standard：.gitignore 的测试依赖（.env/fixtures/本地 DB）改动不触发
#        失效——测试依赖被忽略文件时勿开 verify-cache（纳入全部 ignored 文件会拖垮指纹）。
#     ② .last-green 掺入机器/仓库路径身份，**勿提交共享**；跨机/CI 各自重建。
#     ③ 开 verify-cache = 把【B 段】可靠性下放给指纹完备性 + .last-green 可信。.last-green 是 agent 可
#        直接写的普通文件：能算出篡改态指纹者可【伪造】一份匹配的 .last-green（无需 commit）→ 跳过 B/B2。
#        缓解：A/A0c 已移到命中早退【之前】always 跑，故"删/弱化测试、改低/删/改垃圾基线文件"即便伪造
#        缓存仍被 A/A0c 拦（见测试 cCF）；但【runner 输出的通过数下降】（如 verify-cmd 委托的 run.sh
#        少跑一半，基线文件未动）属 B2 职责，B2 在命中时本就不跑（缓存即"跳过执行"，无输出可验）——这是
#        缓存的固有取舍，非可在仓库内根治（要么重跑 verify-cmd defeat 缓存，要么需不可伪造的密钥=仓库内不存在）。
#        故 verify-cache 是【降本优化、非安全边界】：仅在"接受 B 段 forge 风险"处开；高保真场景关掉它，每轮全验。
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
#     ⑤ 解析的是 runner 输出文本，agent 可影响：测试内 print("999 passed") 可向上伪造计数。
#        （已收紧）"建立过数值基线后又变不可解析"现按绕过处理→打回（check_count_baseline）；
#        仍存的窗口：基线建立之前就吞摘要/不可解析，则首次即无基线可比（需覆盖率/变异根治）。
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
#   B4 覆盖率门特有边界：
#     ⑩ 变异测试不入 Stop 门（每次收尾跑变异分钟级、会逼用户关掉整个 Oracle）。①同数语义掏空的
#        最终根治仍需变异——B4 覆盖率只是"分钟内可跑"的代理（覆盖率绿≠断言有效，仅"行/分支被跑到"）。
#        变异留在 implement verifier 的 mutation 抽查 + profile 的可选 mutation-cmd（人按需/CI 周期跑，非 Stop 门）。
#     ⑪ 覆盖率% 解析仅认 total:/TOTAL/coverage: 三类总计上下文，取整数部分；其它格式（istanbul 表格、
#        多包 go test -cover 无 total: 总计行时只能取最后一包）解析不可靠——故强烈建议 coverage-cmd 自带
#        --cov-fail-under 等阈值或用 `go tool cover -func`(有 total:)，让退出码即承载地板，不依赖本解析。
#        解析不出则降级仅退出码裁决；coverage-min 非 0..100 纯整数亦视为未设地板（降级），不误解析。
#     ⑫ coverage-min 可被改低（threat④同理）→ 建议提交并人审；A0 与缓存指纹已把 coverage-cmd 与 coverage-min
#        一并纳入（未提交改低即被 A0 拦），但已提交的改低仍依赖人审 diff。coverage-min 非整数/超界 → 地板跳过（降级仅退出码）。
#     ⑬ B4 是绝对地板、非动态基线（刻意）：覆盖率 run 间抖动（并行/flaky/env）比测试通过数大得多，
#        若像 B2/B3 那样 ratchet 到高水位，92.1%→92.0% 的正常抖动就会误门控。故 B4 不自动建基线——
#        要把 coverage-min 设到有意义的水平，靠它兜底；"跌而未破地板"（92→78 但 min=70）B4 不拦，是地板语义的固有取舍。
#   为让门生效，建议把 docs/flow/{verify-cmd,robustness-cmd,coverage-cmd,coverage-min,test-count,robustness-count,verify-allow-test-changes} 纳入版本控制并人审其变更。
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
COV_FILE="docs/flow/coverage-cmd"        # B4 覆盖率门的燃料（带覆盖率统计的测试命令）
COVMIN_FILE="docs/flow/coverage-min"     # B4 的覆盖率地板（整数百分比；缺省则只看 coverage-cmd 退出码）
[ -f "$CMD_FILE" ] || exit 0          # 未 opt-in：放行
CMD=$(grep -v '^[[:space:]]*#' "$CMD_FILE" | grep -v '^[[:space:]]*$' \
      | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | head -n1)
[ -n "$CMD" ] || exit 0               # 空命令：放行（视为该项目无法自动验证）

# ---------- A1. 意图契约门（治"指令理解"；会话级、保守、fail-open）----------
# 仅当 transcript 可读、本会话【确实用编辑工具改过文件】、却【无任何 assistant 消息产出过意图契约】时打回。
# 关键设计：意图锚要求所在 assistant 行含 "type":"text" 块（行级近似，非块级 JSON 解析）——router/reinject
#   注入的 "Intent" 模板落在 hook/工具结果行（非 assistant）；纯 tool_use 消息行无 text 块即被排除，故
#   Write/Edit 写入的【文件内容】含 "Intent:" 不会满足本门（Codex 证伪发现并已加 cIntent8 回归）。
#   已验证真实 Claude Code transcript 中 text 与 tool_use 分属不同消息行（0/17 混行），故此近似在实务中成立。
# 边界（诚实，非搪塞）：若单条 assistant 消息行同时含 text 块与 tool_use、且 Intent 仅在 tool_use payload，
#   行级 grep 仍会【漏放】(cIntent9 记录此既定行为)——属本门「宁漏放不误杀」+ Oracle「非安全边界」的取舍：
#   对抗式构造 transcript 超出威胁模型（治压力下偷懒的诚实 agent，非决心作弊者）。
# 粒度刻意取【会话级】而非单轮：精确单轮需解析版本相关的 transcript 结构，脆弱易误杀；本门宁可漏放不误杀。
# 三个判定子串（"name":"Write/Edit/MultiEdit"、"type":"assistant"、"type":"text"）是 transcript 稳定约定。
# opt-out：建 docs/flow/intent-gate-off 即关闭本门（零侵入回退）。无 transcript_path / 不可读 → 放行。
if [ ! -f "docs/flow/intent-gate-off" ]; then
  _tx=$(printf '%s' "$INPUT" | sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
  if [ -n "$_tx" ] && [ -f "$_tx" ]; then
    if grep -qE '"name":[[:space:]]*"(Write|Edit|MultiEdit)"' "$_tx" 2>/dev/null \
       && ! grep -E '"type":[[:space:]]*"assistant"' "$_tx" 2>/dev/null \
            | grep -E '"type":[[:space:]]*"text"' \
            | grep -qE 'Intent[:：]'; then
      {
        printf '[Flow Oracle] 意图契约门未通过：本会话用编辑工具改了文件，但全程无 agent 产出过意图契约。\n'
        printf '动手改文件前应先产出四行：Intent / Constraints / Non-goals / Verify-signal（可观测）。\n'
        printf '补上意图契约即可收尾；该项目确实不需要则建 docs/flow/intent-gate-off 关闭本门。\n'
      } >&2
      exit 2
    fi
  fi
fi

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

# C-1：已提交基线（test-count/robustness-count）被绕过计数门。两条绕过都堵（除非已提交豁免）：
#   (a) 工作树把值【改低】；(b) 工作树【删除】已提交基线（含 `git rm`）——否则 check_count_baseline
#       见文件不存在会按"首绿"重新 establish 一个更低基线，等于清零地板（Codex 证伪发现的 C-1 漏洞）。
# 以 HEAD 为信任锚（`git cat-file -e HEAD:$_bf`）：HEAD 无基线＝establish 场景，放行（不干扰首次建立）；
# HEAD 有基线则工作树要么删了要么改低 → 均按绕过打回。持平/调高放行。基线文件由 hook 自动写，
# 故不并入"任何改动即打回"的 fuel 门，只在此拦"删/改低"。路径相对仓库根（hook cwd=项目根，全脚本一致）。
# 注：信任根仍在仓库内——能 commit 改它者仍可绕（带外 CI/人审基线才是边界，见文件头威胁④/⑥与 DESIGN）。
check_baseline_not_lowered() {  # <baseline-file>
  _bf=$1
  git cat-file -e "HEAD:$_bf" 2>/dev/null || return 0              # HEAD 无已提交基线 → establish 场景 → 不管
  _head=$(git show "HEAD:$_bf" 2>/dev/null | grep -oE '[0-9]+' | head -n1)
  [ -n "$_head" ] || return 0
  _plausible_count "$_head" || return 0
  if [ ! -f "$_bf" ]; then                                         # (b) 已提交基线被删（rm / git rm）
    override_active && return 0
    printf '[Flow Oracle] 完整性门未通过：已提交基线 %s 被删除（HEAD=%s），疑清零地板以重建低基线绕过计数门。\n' "$_bf" "$_head" >&2
    printf '恢复该文件，或提交 %s 接受正当移除（留审计痕迹）。\n' "$ALLOW_FILE" >&2
    return 2
  fi
  _work=$(grep -oE '[0-9]+' "$_bf" 2>/dev/null | head -n1)
  if [ -z "$_work" ] || ! _plausible_count "$_work"; then         # (c) 改成无数字/非法（>18位）值 → 令计数门失效
    override_active && return 0                                    #     （HEAD 本有有效基线，B2 遇不可解析基线会放行 → 等价清零地板）
    printf '[Flow Oracle] 完整性门未通过：已提交基线 %s 被改成不可解析/非法值（HEAD=%s），疑令计数门失效以绕过。\n' "$_bf" "$_head" >&2
    printf '恢复为正常数值，或提交 %s 接受变更（留审计痕迹）。\n' "$ALLOW_FILE" >&2
    return 2
  fi
  if [ "$_work" -lt "$_head" ]; then                              # (a) 改低
    override_active && return 0
    printf '[Flow Oracle] 完整性门未通过：基线 %s 被未提交改低（HEAD=%s → 工作树=%s），疑绕过计数门。\n' "$_bf" "$_head" "$_work" >&2
    printf '恢复基线值，或提交 %s 接受正当下降（留审计痕迹）。\n' "$ALLOW_FILE" >&2
    return 2
  fi
  return 0
}

# 从 runner 输出解析"通过测试数"。命中即回，未识别回空（放行/打回由 check_count_baseline 据"有无基线"裁决）。
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
  # JUnit / Maven Surefire："Tests run: N, Failures: 0, Errors: 0"。B2 仅在 verify-cmd 已绿
  # （exit 0）时运行，正常配置下 failures/errors=0、run 数即通过数；多模块各打一行 → 求和。
  # 边界（诚实）：若 Maven 配 testFailureIgnore=true 让失败仍 exit 0，run 数会含失败数——此时基线被
  # 高估。规避：verify-cmd 别用 ignore-failures 的命令（让失败真的非 0），或用结构化报告（见下）。
  # 注：grep 解析有天花板（见文件头与 verify 技能）——结构化报告（--reporter json/JUnit XML +
  # 项目自带阈值/退出码）才是可靠路径，本解析仅作 best-effort 兜底，认不出则由 check_count_baseline
  # 据"有无基线"裁决（无基线 establish-degrade-open、有基线变不可解析则按绕过打回）。
  [ -z "$_n" ] && _n=$(printf '%s\n' "$_o" | grep -oiE 'tests? run: [0-9]+' | grep -oE '[0-9]+' | awk '{s+=$1} END{if(NR)print s}')
  # 防 bignum 投毒：runner 输出里的 "99999999999999999999 passed" 会被求和成超 int64 的数，
  # 一旦写进基线，后续 `[ -lt ]` 比较出错被静默吞成 false → 测试数暴跌反被放行。
  # 源头截断：>18 位（必超真实测试规模、且超 int64 安全域）一律视为无法解析（不污染基线；后续放行/打回同样由 check_count_baseline 据有无基线裁决）。
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
  if [ -z "$_cur" ]; then
    # 解析不出通过数。无基线 → 降级放行（establish 前无可比，不误门控）。
    # 但"已建立过数值基线却本轮解析不出"= 异常：换 reporter / 吞测试摘要以绕过计数门（威胁⑤）。
    # → 打回（已提交豁免可接受正当的 reporter/命令更换）。收紧"unparseable 一律放行"的盲点。
    if [ -f "$_cf" ] && [ -n "$(grep -oE '[0-9]+' "$_cf" 2>/dev/null | head -n1)" ]; then
      override_active && return 0
      printf '[Flow Oracle] %s未通过：已建立通过数基线，但本轮输出解析不出通过数，疑换 reporter/吞测试摘要以绕过计数门。\n' "$_label" >&2
      printf '若确为正当更换验证命令/reporter，更新或删除基线 %s 后重建，或提交 %s 接受变更（留审计痕迹）。\n' "$_cf" "$ALLOW_FILE" >&2
      return 2
    fi
    return 0
  fi
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

# 从 coverage 工具输出解析"总覆盖率百分比的整数部分"。识别不出回空（→ 仅退出码裁决，不猜，避免误解析致 fail-open）。
# 仅认可可靠的"总计"上下文（优先级递降），不对全文末个 % 瞎猜（"100% done"之类噪声会 fail-open）：
#   ① go `go tool cover -func` 的 `total:` 行  ② coverage.py/pytest-cov 的 `TOTAL` 行  ③ go test -cover 的 `coverage: NN%`
# 取整数部分（小数点/百分号之前）做地板比较：87.5→87、79.9→79（对 ">=min" 保守偏严，正确——79.9 确实 < 80）。
# 其它工具（istanbul 表格等）建议靠 coverage-cmd 自带 --cov-fail-under，退出码即承载地板，不依赖本解析。
extract_coverage() {
  _co=$1; _ctx=''; _cv=''
  _ctx=$(printf '%s\n' "$_co" | grep -iE '^[[:space:]]*total:' | tail -n1)            # go func 总计
  [ -z "$_ctx" ] && _ctx=$(printf '%s\n' "$_co" | grep -iE '^[[:space:]]*TOTAL[[:space:]]' | tail -n1)  # coverage.py TOTAL
  [ -z "$_ctx" ] && _ctx=$(printf '%s\n' "$_co" | grep -iE 'coverage:[[:space:]]*[0-9]' | tail -n1)     # go test -cover
  [ -n "$_ctx" ] || { printf ''; return 0; }
  # 从上下文取最后一个 NN(.N)?% 形态，再切出整数部分（% 与小数点之前）。
  _cv=$(printf '%s\n' "$_ctx" | grep -oE '[0-9]+(\.[0-9]+)?%' | tail -n1 | grep -oE '^[0-9]+')
  _plausible_count "$_cv" || _cv=''
  printf '%s' "$_cv"
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
    cat "$COV_FILE" 2>/dev/null                   # B4 燃料同理
    cat "$COVMIN_FILE" 2>/dev/null                # 覆盖率地板变更亦须使缓存失效
    cat "$COUNT_FILE" 2>/dev/null                 # I-1：B2 基线纳入指纹——改低 test-count 须使缓存失效，
    cat "$RCOUNT_FILE" 2>/dev/null                # 否则开 verify-cache 时改低基线不变指纹 → false-skip 穿透 A/B/B2/B3
    # （副作用：首次 establish 基线后下一轮指纹必变、会多跑一次，之后稳定——fail-safe-to-run，可接受）
    git rev-parse --show-toplevel 2>/dev/null    # 仓库绝对路径 + 机器身份：
    uname -srm 2>/dev/null                        # 令被提交/共享的 .last-green 在异机/异路径不误匹配
  } | _hash
}

# ---------- 降本：跳过"自上次绿以来状态未变"（严格 opt-in：docs/flow/verify-cache 存在时）----------
# 默认关闭 → 门行为不变、依旧每次全验。开启后只缓存掉【昂贵的 verify-cmd 执行】（B/B2/B3/B4）。
# 重要（Codex 四轮发现）：缓存命中的 exit 0 刻意放到 A 完整性门 + A0c 基线门【之后】，让这些【廉价】
# 检查即便缓存命中也 always 跑。否则 .last-green 只是个普通文件，agent 改低基线/删断言后自行伪造一份
# 匹配篡改态的 .last-green（无需 commit）即可让顶部 exit 0 穿透所有门。此处只在此【计算】指纹、不早退。
CACHE_FLAG="docs/flow/verify-cache"
LASTGREEN="docs/flow/.last-green"
FP=''
[ -f "$CACHE_FLAG" ] && FP=$(verify_fingerprint)

# ---------- A. 完整性门（git 仓库内）：禁止靠弱化测试"变绿" ----------
SKIP_RE='(\.(skip|only|todo)\(|(xit|xdescribe|fit|fdescribe|xtest)\(|(it|test|describe)\.(skip|todo)|@pytest\.mark\.(skip|xfail)|@unittest\.skip|pytest\.skip\(|t\.Skip(Now|f)?\(|b\.Skip(Now|f)?\(|#\[ignore\])'
ASSERT_RE='(assert|expect\(|t\.(error|fatal)|\.should|should\.)'   # 不含 require：多为 import，会误伤

if command -v git >/dev/null 2>&1 \
   && git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
   && git rev-parse --verify HEAD >/dev/null 2>&1; then

  # A0. 门的"燃料"（verify-cmd / robustness-cmd）在未提交改动中被改 → 不可信，打回（仅 tracked 可查）。
  if git diff HEAD -- "$CMD_FILE" "$RCMD_FILE" "$COV_FILE" "$COVMIN_FILE" 2>/dev/null | grep -q .; then
    {
      printf '[Flow Oracle] 完整性门未通过：docs/flow/verify-cmd / robustness-cmd / coverage-cmd / coverage-min（门的燃料）在未提交改动中被修改，不可信。\n'
      printf '若为正当更新验证命令，请先提交该文件再收尾（留审计痕迹）；否则恢复原命令。\n'
    } >&2
    exit 2
  fi

  # A0c. 已提交基线被未提交改低（绕过计数门）→ 打回（C-1）。fuel 文件的"任何改动即打回"由上面 A0 管；
  # 基线文件因 hook 自动写，只拦【改低】（见 check_baseline_not_lowered）。
  check_baseline_not_lowered "$COUNT_FILE"  || exit 2
  check_baseline_not_lowered "$RCOUNT_FILE" || exit 2

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
    # 排除 diff 文件头（`+++ ` / `--- `，带尾空格）而非用 '^\+[^+]'：后者会把首字符为 +/- 的【内容行】
    # （如 JS 一元 `+expect(x)`）也排掉（Codex 证伪指出的过宽）。改为只剔带尾空格的真头，保留 `+expect`。
    # 否则路径含断言关键词的文件头（+++ b/tests/assert_helpers_test.js 命中 "assert"）会被误计为
    # "新增断言/标记"，抬高 ADD 抵消真实 DEL，使净减少/净新增判定失效（C-2 假阴性）。两侧对称。
    # 已知残留（可忽略）：内容行恰以 `++ `/`-- ` 开头（diff 呈 `+++ `/`--- `）会被误当头剔除——但真实
    # 测试代码几乎不存在以 `++ `/`-- ` 起行的断言/skip 行；不为此引入 noprefix 脆弱性（见 verify 技能）。
    # A1. 净新增跳过/忽略标记。
    SKIP_ADD=$(printf '%s\n' "$TDIFF" | grep -E '^\+' | grep -vE '^\+\+\+ ' | grep -oE  "$SKIP_RE"   | grep -c .)
    SKIP_DEL=$(printf '%s\n' "$TDIFF" | grep -E '^-' | grep -vE '^--- '     | grep -oE  "$SKIP_RE"   | grep -c .)
    [ "$SKIP_ADD" -gt "$SKIP_DEL" ] && \
      VIOL="${VIOL}- 净新增了跳过/忽略测试的标记（skip/only/todo/xit/xtest/@skip/t.Skip(f)/#[ignore]）\n"

    # A2. 断言"净减少"（删 > 增，避免重命名/跨文件搬移断言误报）。
    ASS_DEL=$(printf '%s\n' "$TDIFF" | grep -E '^-' | grep -vE '^--- '     | grep -oiE "$ASSERT_RE" | grep -c .)
    ASS_ADD=$(printf '%s\n' "$TDIFF" | grep -E '^\+' | grep -vE '^\+\+\+ ' | grep -oiE "$ASSERT_RE" | grep -c .)
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

# ---------- 缓存命中早退（在 A 完整性门 + A0c 基线门【之后】）----------
# 此处 A/A0c 已跑过（above）。指纹与上次绿相同 → 源码/verify-cmd/基线均未变，上次绿结论仍成立，
# 可安全跳过【昂贵的】B/B2/B3/B4（verify-cmd 执行）。伪造 .last-green 也只能跳过 B，跳不过已跑完的 A。
if [ -f "$CACHE_FLAG" ] && [ -n "$FP" ] && [ -f "$LASTGREEN" ] && [ "$FP" = "$(cat "$LASTGREEN" 2>/dev/null)" ]; then
  exit 0
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
# C-1 二次校验（Codex 三轮发现）：A0c 在跑 verify-cmd【之前】校验过基线；但 verify-cmd 执行期间
# 被测代码/测试可能把 test-count 改低/删/改垃圾（运行时 side-effect 绕过，无需 commit）。故在 B2
# 读基线【之前】、verify-cmd 跑完【之后】再校验一次，堵"跑测时篡改基线"。非 git 时 no-op。
check_baseline_not_lowered "$COUNT_FILE" || exit 2
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
    check_baseline_not_lowered "$RCOUNT_FILE" || exit 2   # C-1 二次校验：堵 robustness-cmd 跑测期间篡改基线
    check_count_baseline "$ROUT" "$RCOUNT_FILE" "健壮性数基线门" || exit 2
  fi
fi

# ---------- B4. 覆盖率门（严格 opt-in：docs/flow/coverage-cmd 存在且非空时生效）----------
# 治"①同数语义掏空"的代理指标：掏空断言/删错误路径测试常使分支覆盖率下降——计数门(B2/B3)抓不到，
# 覆盖率门能抓到。两道子检查：① coverage-cmd 退出码（含项目自带 --cov-fail-under 等阈值）；
# ② 若设了 coverage-min，解析输出覆盖率%与之比，低于地板即打回（解析不出则仅凭退出码，诚实降级）。
# 不存在 coverage-cmd → 跳过（零侵入）。注：变异测试不入本 Stop 门——每次收尾跑变异是分钟级、
# 会逼用户关掉整个 Oracle；变异留在 implement verifier 的 mutation 抽查 + profile 的可选 mutation-cmd（按需/周期跑）。
if [ -f "$COV_FILE" ]; then
  CCMD=$(grep -v '^[[:space:]]*#' "$COV_FILE" | grep -v '^[[:space:]]*$' \
        | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | head -n1)
  if [ -n "$CCMD" ]; then
    COUT=$(sh -c "$CCMD" 2>&1)
    CCODE=$?
    if [ "$CCODE" -ne 0 ]; then
      {
        printf '[Flow Oracle] 覆盖率门未通过（coverage-cmd 退出码 %s），不得声明完成。\n' "$CCODE"
        printf '命令：%s\n' "$CCMD"
        printf -- '--- 输出末 40 行 ---\n'
        printf '%s\n' "$COUT" | tail -n 40
        printf '补测试提升覆盖（尤其错误/分支路径），禁止下调阈值或改测试使其变绿（红线 §1/§2）。\n'
      } >&2
      exit 2
    fi
    if [ -f "$COVMIN_FILE" ]; then
      # 地板必须是 0..100 的纯整数；非法（小数/科学计数/>100/带噪声）→ 视为未设地板，降级仅退出码（不误解析）。
      MIN=$(grep -v '^[[:space:]]*#' "$COVMIN_FILE" | grep -v '^[[:space:]]*$' \
            | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | head -n1)
      case "$MIN" in ''|*[!0-9]*) MIN='' ;; esac
      [ -n "$MIN" ] && { _plausible_count "$MIN" && [ "$MIN" -le 100 ] || MIN=''; }
      CUR_COV=$(extract_coverage "$COUT")
      if [ -n "$MIN" ] && [ -n "$CUR_COV" ] && [ "$CUR_COV" -lt "$MIN" ]; then
        {
          printf '[Flow Oracle] 覆盖率门未通过：覆盖率 %s%% 低于地板 %s%%，疑掏空断言/删分支测试。\n' "$CUR_COV" "$MIN"
          printf '补足覆盖再收尾；若确需下调地板，提交 %s 并人审其变更（不在收尾时静默改低）。\n' "$COVMIN_FILE"
        } >&2
        exit 2
      fi
    fi
  fi
fi

# 全部门通过 → 若开启缓存，记录本次绿的状态指纹，供下次 skip-if-unchanged。
[ -f "$CACHE_FLAG" ] && [ -n "$FP" ] && printf '%s\n' "$FP" > "$LASTGREEN"

exit 0
