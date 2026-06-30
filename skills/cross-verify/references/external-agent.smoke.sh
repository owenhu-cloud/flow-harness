#!/bin/sh
# external-agent.sh 真实 e2e 冒烟（opt-in）：在【有凭证】时跑一次最小真 codex/grok 派发，
# 证明"健康检查通过 ⇒ 真能派发成功"这条 stub argv 测试覆盖不到的端到端链路（堵 flag 漂移盲点：
# 健康检查只验 binary+auth，真调用可能因 CLI flag 被该模型拒而 400，见 lessons/stub-argv-...）。
#
# 默认【不跑真调用】，保持离线/hermetic：
#   - 仅当 RUN_E2E=1 且对应 *_HOME/auth.json 在场时，才真调 codex/grok。
#   - 缺凭证或未设 RUN_E2E → SKIP（exit 0），不让 CI/离线环境误红。
# 证据落盘：每次真跑把 adapter/exit/输出摘要写入 EVIDENCE 文件（默认 ./.flow-e2e-evidence.txt），
#   供完成声明引用（红线 §1：完成必带同轮新鲜证据）。
#
# 用法: RUN_E2E=1 sh external-agent.smoke.sh [codex-cli|grok-cli ...]   （默认两者都试）
set -u
DIR=$(cd "$(dirname "$0")" && pwd)
SUT="$DIR/external-agent.sh"
[ -f "$SUT" ] || { echo "FAIL: external-agent.sh 不存在"; exit 1; }

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
GROK_HOME="${GROK_HOME:-$HOME/.grok}"
EVIDENCE="${EVIDENCE:-./.flow-e2e-evidence.txt}"
ADAPTERS="${*:-codex-cli grok-cli}"

if [ "${RUN_E2E:-0}" != "1" ]; then
  echo "SKIP: 未设 RUN_E2E=1 → 不跑真实外部调用（默认离线）。要跑：RUN_E2E=1 sh $0"
  exit 0
fi

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
PF="$TMP/prompt"; OF="$TMP/out"
# 最小、确定、只读的探针 prompt：要求回一个固定 token，证明端到端往返成功。
printf '%s\n' 'Reply with exactly this token and nothing else: FLOW_E2E_OK' > "$PF"

ran=0; ok=0; skipped=0
for a in $ADAPTERS; do
  case "$a" in
    codex-cli) _home="$CODEX_HOME" ;;
    grok-cli)  _home="$GROK_HOME" ;;
    *) echo "SKIP: 未知 adapter $a"; continue ;;
  esac
  if [ ! -f "$_home/auth.json" ]; then
    echo "SKIP: $a 无凭证（$_home/auth.json 不在）"; skipped=$((skipped+1)); continue
  fi
  # 先健康检查；过了再真派发——验证"健康检查通过 ⇒ 真派发不被 flag 拒"。
  if ! sh "$SUT" healthcheck "$a" >/dev/null 2>&1; then
    echo "SKIP: $a 健康检查未过（降级信号）"; skipped=$((skipped+1)); continue
  fi
  ran=$((ran+1))
  _rc=0
  CROSS_VERIFY_TIMEOUT="${CROSS_VERIFY_TIMEOUT:-120}" sh "$SUT" dispatch "$a" "$PF" "$OF" 2>"$TMP/err" || _rc=$?
  _excerpt=$(head -c 300 "$OF" 2>/dev/null | tr '\n' ' ')
  {
    printf '[%s] adapter=%s exit=%s\n' "$(cat /dev/null; echo "$(date 2>/dev/null || echo n/a)")" "$a" "$_rc"
    printf '  out: %s\n' "$_excerpt"
    [ "$_rc" -ne 0 ] && printf '  err: %s\n' "$(tail -c 300 "$TMP/err" 2>/dev/null | tr '\n' ' ')"
  } >> "$EVIDENCE"
  if [ "$_rc" -eq 0 ] && [ -s "$OF" ]; then
    printf 'PASS: %s e2e dispatch 成功（exit 0、输出非空）。证据 → %s\n' "$a" "$EVIDENCE"; ok=$((ok+1))
  else
    printf 'FAIL: %s e2e dispatch 失败（exit %s）。健康检查过但真调用挂——疑 CLI flag 漂移。证据 → %s\n' "$a" "$_rc" "$EVIDENCE"
  fi
done

echo "----"
echo "e2e: ran=$ran ok=$ok skipped=$skipped"
[ "$ran" -eq 0 ] && { echo "（无可跑 adapter：全部缺凭证/降级 → 视为 SKIP，不判失败）"; exit 0; }
[ "$ok" -eq "$ran" ]
