#!/bin/sh
# research 深档的引用校验器（gate-able）。校验 sources.md：
#   ① 每条断言的独立源数 ≥ 阈值（默认 3，深档硬指标）；
#   ② 每个引用 URL/DOI 真实可达（防「我记得有篇论文说」式幻觉引用）；
#   ③ REQUIRE_SUPPORT=1（opt-in）：每源带【支撑摘录】，把校验从「可达」抬到「源支撑断言」近似。
# 任一不过 → 退出码 2 + stderr 报告，可直接当 Stop/CI 门用。全过退出码 0。
#
# 设计随 Flow 身份：纯 POSIX sh，无 Python/jq。URL 可达性检查可注入（FLOW_URL_CHECK），
# 故离线可测：默认用 curl；设了 FLOW_URL_CHECK 则调它（收 url 作 $1，0=可达）。
#
# sources.md 约定格式（由 deep-mode.md 规定）：
#   ## <断言文本>
#   - <源类型> | https://...        (每行一个源，含一个 http(s) URL 或 doi:10....)
#   - <源类型> | doi:10.1234/xxx
#   （`## ` 起新断言块；`- ` 行含 URL 即计一个源）
#
# 用法：sh verify-citations.sh [sources.md]   （缺省 docs/flow/*/sources.md 第一个）
# 阈值：MIN_SOURCES=3（可改）。

MIN=${MIN_SOURCES:-3}
SRC=$1
[ -n "$SRC" ] || SRC=$(ls docs/flow/*/sources.md 2>/dev/null | head -n1)
[ -n "$SRC" ] && [ -f "$SRC" ] || { echo "[verify-citations] 找不到 sources 文件：${SRC:-docs/flow/*/sources.md}" >&2; exit 2; }

# 可达性检查：可注入；默认 curl HEAD，2xx/3xx 即可达。doi: 转 doi.org。
url_ok() {
  _u=$1
  case "$_u" in doi:*) _u="https://doi.org/${_u#doi:}" ;; esac
  if [ -n "${FLOW_URL_CHECK:-}" ]; then
    $FLOW_URL_CHECK "$_u"
  else
    command -v curl >/dev/null 2>&1 || { echo "无 curl，无法校验可达性" >&2; return 2; }
    code=$(curl -sS -o /dev/null --max-time 15 -L -I -w '%{http_code}' "$_u" 2>/dev/null)
    case "$code" in 2??|3??) return 0 ;; *) return 1 ;; esac
  fi
}

UNDER=''   # 源数不足的断言
DEAD=''    # 不可达的 URL（断言::url）
CLAIMS=0

claim=''; count=0
flush() {
  [ -n "$claim" ] || return 0
  CLAIMS=$((CLAIMS+1))
  [ "$count" -lt "$MIN" ] && UNDER="${UNDER}- 「${claim}」只有 ${count} 个源（需 ≥ ${MIN}）\n"
}

# REQUIRE_SUPPORT=1（默认关，opt-in，高风险/深档推荐）：每个源行除 URL 外须带【支撑摘录】，
# 把校验从「URL 可达」抬到「源确实支撑该断言」的可机检近似（CoVe 式：摘录是断言被支撑的证据）。
# 行格式升为：`- <源类型> | <URL> | <摘录文本>`（≥2 个 `|`，摘录 ≥ ${MIN_EXCERPT:-12} 字符且非纯 URL）。
# 源类型/URL 字段不含 `|`；摘录取【第二个 `|` 之后的全部】，故摘录内部可含 `|`（Codex 证伪发现）。
# 机器只校验「摘录存在且够长」——「摘录是否真出现在该页」需联网取页比对，留作 verifier 人/异模型判断。
NOSUP=''   # REQUIRE_SUPPORT 下缺支撑摘录的源
# 逐行解析。IFS= 保原样；read -r 不吃反斜杠。
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    '## '*)
      flush
      claim=$(printf '%s' "$line" | sed 's/^##[[:space:]]*//')
      count=0
      ;;
    '- '*)
      url=$(printf '%s' "$line" | grep -oE '(https?://[^[:space:]]+|doi:10\.[^[:space:]]+)' | head -n1)
      if [ -n "$url" ]; then
        count=$((count+1))
        if ! url_ok "$url"; then DEAD="${DEAD}- 「${claim}」: ${url}\n"; fi
        if [ "${REQUIRE_SUPPORT:-0}" = 1 ]; then
          _np=$(printf '%s' "$line" | tr -cd '|' | wc -c | tr -d ' ')
          _ex=$(printf '%s' "$line" | sed 's/^[^|]*|[^|]*|[[:space:]]*//')   # 第二个 | 之后的全部（摘录内可含 |）
          if [ "$_np" -lt 2 ] || [ -z "$_ex" ] || [ "${#_ex}" -lt "${MIN_EXCERPT:-12}" ] \
             || printf '%s' "$_ex" | grep -qE '^(https?://|doi:)'; then
            NOSUP="${NOSUP}- 「${claim}」: ${url}（缺支撑摘录）\n"
          fi
        fi
      fi
      ;;
  esac
done < "$SRC"
flush

if [ "$CLAIMS" -eq 0 ]; then
  echo "[verify-citations] $SRC 里没有 '## 断言' 块，无可校验内容（格式见 deep-mode.md）。" >&2
  exit 2
fi

if [ -n "$UNDER" ] || [ -n "$DEAD" ] || [ -n "$NOSUP" ]; then
  {
    echo "[verify-citations] 引用校验未通过（$SRC，共 $CLAIMS 条断言，阈值 ≥${MIN} 源）："
    [ -n "$UNDER" ] && { echo "— 源数不足："; printf '%b' "$UNDER"; }
    [ -n "$DEAD" ]  && { echo "— 不可达/疑似幻觉引用："; printf '%b' "$DEAD"; }
    [ -n "$NOSUP" ] && { echo "— 缺支撑摘录（REQUIRE_SUPPORT）："; printf '%b' "$NOSUP"; }
    echo "修：补足独立源 / 剔除不可达引用 / 为每源补支撑摘录，禁编造引用充数（research 深档引用红线）。"
  } >&2
  exit 2
fi

if [ "${REQUIRE_SUPPORT:-0}" = 1 ]; then
  echo "[verify-citations] 通过：$CLAIMS 条断言均 ≥${MIN} 源、引用可达且每源带支撑摘录。"
else
  echo "[verify-citations] 通过：$CLAIMS 条断言均 ≥${MIN} 源且引用可达。"
fi
exit 0
