#!/bin/bash
# Flow kernel 共享库。被 router/loop-controller/checkpoint/restore 与 bin/flow 复用。
# 约束：bash 3.2 兼容（无关联数组/mapfile），无 timeout，依赖 jq + perl + md5。

# 从 start 目录向上找到包含 .flow 的项目根；找不到则空。
flow_find_root() {
  local d="$1"
  [ -z "$d" ] && d="$PWD"
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    if [ -d "$d/.flow" ]; then printf '%s' "$d"; return 0; fi
    d=$(dirname "$d")
  done
  [ -d "/.flow" ] && { printf '%s' "/"; return 0; }
  return 1
}

# md5：macOS 用 md5，Linux/CI 用 md5sum（保证跨平台）。
flow_md5() {
  if command -v md5 >/dev/null 2>&1; then md5
  else md5sum | awk '{print $1}'
  fi
}

# cwd → 8 位稳定哈希，做 run 隔离键（一个工作目录一个 run）。
flow_cwd_hash() { printf '%s' "$1" | flow_md5 | cut -c1-8; }

flow_now_iso()   { date -u +%Y-%m-%dT%H:%M:%SZ; }
flow_now_epoch() { date +%s; }

# 转义点号，避免在 grep 正则里 . 误匹配。
_flow_kq() { printf '%s' "$1" | sed 's/[.]/\\./g'; }

# 从扁平点号键文件读取一个键值（去注释/首尾空白/外层引号）。
yget() { # file key
  local f="$1" k kq line
  kq=$(_flow_kq "$2")
  [ -f "$f" ] || return 0
  line=$(grep "^${kq}:" "$f" 2>/dev/null | head -1)
  [ -z "$line" ] && return 0
  printf '%s' "$line" \
    | sed "s/^${kq}:[[:space:]]*//" \
    | sed 's/[[:space:]]\{1,\}#.*$//' \
    | sed 's/[[:space:]]*$//' \
    | sed 's/^"//; s/"$//'
}

# 在扁平点号键文件里更新或追加一个键（值原样写入，不加引号）。
yset() { # file key value
  local f="$1" k="$2" v="$3" kq tmp
  kq=$(_flow_kq "$k")
  [ -f "$f" ] || : > "$f"
  if grep -q "^${kq}:" "$f" 2>/dev/null; then
    tmp="$f.tmp.$$"
    awk -v k="$k" -v v="$v" '
      { split($0, a, ":"); if (a[1]==k) print k": "v; else print $0 }
    ' "$f" > "$tmp" && mv "$tmp" "$f"
  else
    printf '%s: %s\n' "$k" "$v" >> "$f"
  fi
}

# 便捷：读 config / profile。
cfg_get()  { yget "$FLOW_ROOT/.flow/config.yml" "$1"; }
prof_get() { yget "$FLOW_ROOT/.flow/profile.yml" "$1"; }

# 带超时执行外部命令（无 timeout 时的可移植实现）。
# 用法：flow_run_timeout <秒> <程序> [参数...]
# 返回：命令退出码；超时返回 124；fork 失败返回 127。
flow_run_timeout() {
  local t="$1"; shift
  perl -e '
    my $t = shift @ARGV;
    my $pid = fork();
    if (!defined $pid) { exit 127; }
    if ($pid == 0) { exec @ARGV or exit 127; }
    my $timed = 0;
    local $SIG{ALRM} = sub { $timed = 1; kill "TERM", $pid; };
    alarm $t;
    waitpid($pid, 0);
    my $rc = $? >> 8;
    alarm 0;
    if ($timed) { sleep 1; kill "KILL", $pid; exit 124; }
    exit $rc;
  ' "$t" "$@"
}

# 取 transcript 中最后一条 assistant 文本（JSONL slurp）。
flow_last_assistant() { # transcript_path
  [ -f "$1" ] || { printf ''; return 0; }
  jq -rs '[.[] | select(.type=="assistant")
            | (.message.content // [])[]?
            | select(.type=="text") | .text] | last // ""' "$1" 2>/dev/null
}

# 输出 Stop hook 的 block 决策（阻止结束并把 reason 喂回模型）。
flow_emit_block() { # reason
  jq -cn --arg r "$1" '{decision:"block", reason:$r}'
}

# 输出 UserPromptSubmit / SessionStart 的注入上下文。
flow_emit_context() { # event_name additional_context
  jq -cn --arg e "$1" --arg c "$2" \
    '{hookSpecificOutput:{hookEventName:$e, additionalContext:$c}}'
}
