#!/bin/sh
# Flow Doctor — 项目 Flow 接入状态诊断（P0）。
# 回答用户最常问的「装了 Flow，到底什么在真生效、什么只是提示词纪律？」
# 在【项目 cwd】运行，只读探测 docs/flow/* 的 opt-in 状态 + 外部 agent 健康；不改任何文件、无副作用。
# 设计与 plugin 一致（无状态文件）：Oracle 不持久化裁决历史，故「最近结果」据 .last-green（缓存开时）
# 报告，否则诚实说明 Oracle 无状态——收尾时观察打回输出即是结果。
#
# 用法（agent 经 flow-doctor 技能调用，或人直接跑）:
#   sh "${CLAUDE_PLUGIN_ROOT}/hooks/flow-doctor.sh"        # 人读文本
#   sh hooks/flow-doctor.sh --quiet                        # 仅退出码（0=Oracle active, 1=inactive）
# 退出码：0 = Oracle 已接入（verify-cmd 在场）；1 = 未接入（完成判定退回纪律级）。无外部依赖。
set -u

SELF=$(cd "$(dirname "$0")" && pwd)
EXT="$SELF/../skills/cross-verify/references/external-agent.sh"
FLOW=docs/flow
QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

# 读单行配置（去注释/空行/首尾空白）；不存在或空 → 回空。
read1() {
  [ -f "$1" ] || return 0
  grep -v '^[[:space:]]*#' "$1" 2>/dev/null | grep -v '^[[:space:]]*$' \
    | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | head -n1
}

is_git=no
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then is_git=yes; fi

VERIFY=$(read1 "$FLOW/verify-cmd")
RCMD=$(read1 "$FLOW/robustness-cmd")
CCMD=$(read1 "$FLOW/coverage-cmd")
CMIN=$(read1 "$FLOW/coverage-min")
XV=$(read1 "$FLOW/cross-verify")
XE=$(read1 "$FLOW/cross-execute")
TC=$(read1 "$FLOW/test-count")
RC=$(read1 "$FLOW/robustness-count")
CV_EFFORT=${CROSS_VERIFY_EFFORT:-high}
CE_EFFORT=${CROSS_EXECUTE_EFFORT:-medium}

say '================ Flow Doctor ================'
say "项目: $(pwd)"
say "git 仓库: $is_git$([ "$is_git" = no ] && echo '  （A 完整性门仅 git 仓库内生效 → 当前跳过）')"
say "项目画像 (profile): $([ -f "$FLOW/project.md" ] && echo '✅ docs/flow/project.md 已固化' || echo '⚠️ 未固化 → 首个任务先跑 profile')"
say ''
say '----- 机器强制：Stop Oracle（agent 收尾时独立进程裁决，无法绕过）-----'
if [ -n "$VERIFY" ]; then
  say "  B 验证命令门   ✅ 接入   cmd: $VERIFY"
  say "  B2 测试数基线  $([ -n "$TC" ] && echo "✅ 基线=$TC" || echo '—（未建立，首次绿即 establish）')"
  say "  A 完整性门     $([ "$is_git" = yes ] && echo '✅ 生效（扫 git diff 防删测试/skip/删断言/改低基线）' || echo '⚠️ 跳过（非 git）')"
  ORACLE_ACTIVE=0
else
  say '  ⚠️ 未配置 docs/flow/verify-cmd → Oracle 整体放行（零侵入）。'
  say '     完成判定退回【纪律级】（红线 + verify 技能），非机器强制。要接入：跑 profile 或 verify 写 verify-cmd。'
  ORACLE_ACTIVE=1
fi
say "  B3 健壮性门    $([ -n "$RCMD" ] && echo "✅ 启用   cmd: $RCMD   $([ -n "$RC" ] && echo "(基线=$RC)")" || echo '⏸️ 未启用（opt-in：写 docs/flow/robustness-cmd 异常路径子集）')"
if [ -n "$CCMD" ]; then
  say "  B4 覆盖率门    ✅ 启用   cmd: $CCMD   $([ -n "$CMIN" ] && echo "地板=${CMIN}%" || echo '(无地板，仅退出码裁决)')"
else
  say '  B4 覆盖率门    ⏸️ 未启用（opt-in：写 docs/flow/coverage-cmd，首选自带 --cov-fail-under）'
fi
# 降本/缓存与最近结果
if [ -f "$FLOW/verify-cache" ]; then
  say "  verify-cache   ⚠️ 开启（自上次绿状态未变即跳过昂贵的 verify-cmd 执行；A 完整性门仍跑）"
  say "                 注：是【降本优化非安全边界】——.last-green 可被 agent 伪造以跳过 B/B2（runner 计数门）；高保真场景请关掉。"
  if [ -f "$FLOW/.last-green" ]; then
    say "    最近一次绿：.last-green 在场（指纹已记录）$(ls -l "$FLOW/.last-green" 2>/dev/null | awk '{print $6,$7,$8}')"
  else
    say '    最近一次绿：尚无 .last-green（还没跑出过绿，或刚清过）'
  fi
else
  say '  verify-cache   ⏸️ 关闭（默认；每次收尾全量验）'
fi
# 豁免文件状态
if [ -f "$FLOW/verify-allow-test-changes" ]; then
  if [ "$is_git" = yes ] && git ls-files --error-unmatch "$FLOW/verify-allow-test-changes" >/dev/null 2>&1 \
     && ! git diff HEAD -- "$FLOW/verify-allow-test-changes" 2>/dev/null | grep -q .; then
    say '  测试增删豁免   ⚠️ 已提交且生效（A 门/基线门对测试改动放行——确认这是有意的）'
  else
    say '  测试增删豁免   存在但未提交 → 不生效（堵同轮 touch 拆门）'
  fi
fi
say ''
say '----- opt-in：多模型对抗（异模型证伪，默认关）-----'
if [ -n "$XV" ]; then
  case "$XV" in
    codex-cli|grok-cli)
      say "  cross-verify   ✅ opt-in   适配器键: $XV"
      [ "$XV" = codex-cli ] && say "    └ Codex verify effort: ${CV_EFFORT}（评审/验证默认不降档；env CROSS_VERIFY_EFFORT 可覆盖）"
      if [ -f "$EXT" ]; then
        if sh "$EXT" healthcheck "$XV" >/dev/null 2>&1; then say "    └ $XV  ✅ available"
        else say "    └ $XV  ❌ 降级（binary 或 auth.json 缺）→ 会回退同模型基线"; fi
        say '    注：健康检查只验 binary+auth，不验 CLI flag 兼容；真实链路用 external-agent.smoke.sh（RUN_E2E=1）验。'
      else
        say "    ⚠️ 找不到 external-agent.sh（$EXT）"
      fi ;;
    *)
      # 校验配置的适配器键，别把无效/弃用键当成"已生效"（旧 codex-mcp 已去除——派发会 unknown adapter 失败）
      say "  cross-verify   ⚠️ opt-in 但适配器键 '$XV' 未知/已弃用"
      say "    脚本层仅认 codex-cli / grok-cli（旧 codex-mcp 别名已去除，与 codex-cli 行为相同属误导）。"
      say "    → 当前会 'unknown adapter' 失败；把 docs/flow/cross-verify 改为 codex-cli 或 grok-cli。" ;;
  esac
else
  say '  cross-verify   ⏸️ 未 opt-in（写 docs/flow/cross-verify 适配器键如 codex-cli/grok-cli 才启用）'
fi
if [ -f "$FLOW/cross-execute" ]; then
  case "$XE" in
    codex-cli)
      say '  cross-execute  ✅ opt-in   适配器键: codex-cli（异模型隔离 worktree 执行）'
      say "    └ Codex execute effort: ${CE_EFFORT}（执行默认低一档；env CROSS_EXECUTE_EFFORT 可覆盖）" ;;
    grok-cli)  say '  cross-execute  ⚠️ opt-in 但 grok-cli 未实现 dispatch-write（写沙箱）→ 派发会 unknown adapter；用 codex-cli' ;;
    '')        say '  cross-execute  ⚠️ opt-in 但文件为空/仅注释 → 未声明适配器键（应写 codex-cli）' ;;
    *)         say "  cross-execute  ⚠️ opt-in 但适配器键 '$XE' 未知（写沙箱仅支持 codex-cli）" ;;
  esac
else
  say '  cross-execute  ⏸️ 未 opt-in'
fi
say ''
say '----- 纪律级：hook 无法证明，靠 agent 自觉（不是机器强制）-----'
say '  判档 R0–R3 · brainstorm/plan 门 · builder≠verifier · TDD 红绿 · mutation 抽查 · 跨模型轮换'
say '  → 这些是 SKILL 提示词纪律；完成证据看 implement/verify 贴出的 fresh 输出，非 Oracle 裁决。'
say ''
# 总结行
if [ -n "$VERIFY" ]; then
  GATES='A,B,B2'
  [ -n "$RCMD" ] && GATES="$GATES,B3"
  [ -n "$CCMD" ] && GATES="$GATES,B4"
  say "总结: Oracle ✅ active · 机器强制门: $GATES · 其余为纪律级（非强制）。"
else
  say '总结: Oracle ⚠️ INACTIVE（无 verify-cmd）· 当前【无任何机器强制门】，完成全靠纪律级。'
fi
say '============================================='

[ "$ORACLE_ACTIVE" -eq 0 ] && exit 0 || exit 1
