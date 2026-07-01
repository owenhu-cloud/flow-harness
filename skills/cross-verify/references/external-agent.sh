#!/bin/sh
# Flow 多模型对抗派发底座。把「对抗证伪 / 审查」一步的执行者派给外部模型 agent（首个：Codex）。
#
# 设计定位（遵 DESIGN「除三支 hook 外不引入常驻进程或命令行工具」）：
#   本脚本是一次性 references 脚本（仿 verify-citations.sh 先例），由 cross-verify / plan /
#   brainstorm 等技能按需调用——非常驻进程、非 hook、无注册。POSIX sh、无 jq。
#   codex 可执行名经 CODEX_BIN 注入（默认 codex），便于测试 stub 与不可用降级。
#
# 用法:
#   external-agent.sh healthcheck <adapter>
#       adapter 可用 → exit 0；不可用 → exit 3（降级信号：调用方据此回退同模型并显式告知用户）。
#   external-agent.sh dispatch <adapter> <prompt-file> <out-file>
#       只读对抗验证：prompt-file 派给外部 agent，结构化结果写 out-file。
#       成功 exit 0；adapter 不可用 exit 3；派发出错 exit 1。
#   external-agent.sh dispatch-write <adapter> <prompt-file> <out-file> <worktree-dir>
#       写沙箱执行（cross-execute 用）：在 <worktree-dir> 内以 --sandbox workspace-write
#       派给外部 agent 落地一个明确子任务（codex exec 非交互、无审批提示），过程输出写 out-file。
#       退出码同 dispatch（0/3/1）。worktree-dir 必须是 `git worktree add` 产生的隔离 linked
#       worktree——脚本会校验、拒主工作区/裸目录；审 diff/并行上限由 cross-execute 技能层强制。
#
# 适配器键: codex-cli 经本地 `codex exec` 派发（纯 CLI 路径）。本脚本【只有 CLI 路径】——
#   不要把它叫 codex-mcp：真正的 MCP（会话内 Codex MCP 工具）由 agent 在 *skill 层* 直接调用，
#   不经过本脚本。本脚本是「子代理内无 MCP、或想脚本化/CI 一次性派发」时的通用 CLI 回退。
#   （历史上脚本接受 codex-mcp 别名但与 codex-cli 行为完全相同 → 误导，已去除，统一用 codex-cli。）
#   grok-cli 经 `grok -p --permission-mode plan`（headless 只读）派发；Grok 无 MCP server 模式
#   （`grok mcp` 是反向：让 grok 连别的 MCP），故只走 CLI。仅 cross-verify(dispatch)；
#   未实现 dispatch-write（cross-execute），grok 写沙箱待 worktree 写模式验证后再加。
# 接新模型: 在 *_available / cmd_dispatch 的 case 增一个 adapter 分支即可（见 adapters.md 扩展点）。
#
# 环境覆盖: CODEX_BIN(默认 codex) · CODEX_HOME(默认 ~/.codex) · GROK_BIN(默认 grok) ·
#   GROK_HOME(默认 ~/.grok) · CROSS_VERIFY_EFFORT(默认 high，仅 codex 只读验证) ·
#   CROSS_EXECUTE_EFFORT(默认 medium，仅 codex 写沙箱执行)。
# 注: codex 子命令/flag 随版本漂移，健康检查失败即降级；细节以 `codex exec --help` 为准。

set -eu
CODEX_BIN="${CODEX_BIN:-codex}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
GROK_BIN="${GROK_BIN:-grok}"
GROK_HOME="${GROK_HOME:-$HOME/.grok}"
VERIFY_EFFORT="${CROSS_VERIFY_EFFORT:-high}"
EXECUTE_EFFORT="${CROSS_EXECUTE_EFFORT:-medium}"
TIMEOUT="${CROSS_VERIFY_TIMEOUT:-300}"

die() { printf 'external-agent: %s\n' "$*" >&2; exit 1; }

# 可移植临时文件：mktemp 在场用它；不在场（极少数精简环境）回退到 TMPDIR 下 pid+计数器名，
# 避免空文件名导致重定向报错（一致用于 _in 与各 _err，Codex 指出原 _err 缺此回退）。
_tmpn=0
_mktemp() { mktemp 2>/dev/null && return 0; _tmpn=$((_tmpn+1)); printf '%s\n' "${TMPDIR:-/tmp}/ea.$$.$_tmpn"; }

# 可移植超时（macOS 默认无 timeout）：优先 timeout/gtimeout，否则 shell watchdog。
# 超时杀进程并返回 124（与 GNU timeout 一致），让卡死的 codex 不会让 dispatch 永久挂起。
run_timeout() {
  _secs=$1; shift
  if command -v timeout  >/dev/null 2>&1; then timeout  "$_secs" "$@"; return $?; fi
  if command -v gtimeout >/dev/null 2>&1; then gtimeout "$_secs" "$@"; return $?; fi
  # 看门狗回退（macOS 默认无 timeout）。async 任务 `cmd &` 的 stdin 默认被接到 /dev/null（POSIX），
  # 会丢掉经 stdin 传入的 prompt（I-2）。`<&0 &` 在 bash 可用，但 dash/ash 对其不可靠（Codex 证伪指出）。
  # 可移植做法：先在【前台】把本函数 stdin 抽到临时文件，再让后台任务从该【文件路径】读——路径重定向
  # 对后台任务在 dash/ash/bash 一致生效。callers 传 </dev/null 则抽出空文件＝等价 /dev/null（不挂起）。
  _in=$(_mktemp)
  cat > "$_in"
  "$@" < "$_in" & _p=$!
  ( sleep "$_secs"; kill -TERM "$_p" 2>/dev/null; sleep 2; kill -KILL "$_p" 2>/dev/null ) & _w=$!
  _rc=0; wait "$_p" 2>/dev/null || _rc=$?
  # 主进程已结束 → 停掉看门狗并安静回收（避免 job 'Terminated' 噪音）
  kill "$_w" 2>/dev/null
  wait "$_w" 2>/dev/null || true
  rm -f "$_in" 2>/dev/null
  # watchdog 触发时 wait 返回 143(SIGTERM)/137(SIGKILL)，归一成 124（超时）
  case "$_rc" in 143|137) _rc=124 ;; esac
  return $_rc
}

# codex 是否可用：binary 在 PATH/绝对路径存在 + 认证文件在场（best-effort，非交互、快）。
codex_available() {
  command -v "$CODEX_BIN" >/dev/null 2>&1 || return 1
  [ -f "$CODEX_HOME/auth.json" ] || return 1
  return 0
}

# grok 是否可用：binary + 认证文件在场（同 codex_available 形态）。
grok_available() {
  command -v "$GROK_BIN" >/dev/null 2>&1 || return 1
  [ -f "$GROK_HOME/auth.json" ] || return 1
  return 0
}

cmd_healthcheck() {
  case "$1" in
    codex-cli) codex_available && exit 0 || exit 3 ;;
    grok-cli) grok_available && exit 0 || exit 3 ;;
    *) die "unknown adapter: $1 (本脚本仅 codex-cli / grok-cli；真 MCP 由 skill 层调用)" ;;
  esac
}

cmd_dispatch() {
  adapter=$1; pf=$2; of=$3
  [ -f "$pf" ] || die "prompt-file not found: $pf"
  case "$adapter" in
    codex-cli)
      codex_available || exit 3
      _err=$(_mktemp)
      # prompt 经 stdin 传入（codex exec 省略 positional 时从 stdin 读 instructions），
      # 避免把长 diff/prompt 当 argv 撞 ARG_MAX（I-2）；read-only 沙箱（verifier 不许改码）；
      # skip-git 容忍非 git 目录；effort 作 TOML 字符串覆盖；超时防卡死；stderr 留作排障。
      _rc=0
      run_timeout "$TIMEOUT" "$CODEX_BIN" exec --sandbox read-only --skip-git-repo-check \
        -c model_reasoning_effort="\"$VERIFY_EFFORT\"" <"$pf" >"$of" 2>"$_err" || _rc=$?
      if [ "$_rc" -eq 124 ]; then
        rm -f "$_err"; die "codex dispatch timed out after ${TIMEOUT}s (adapter=$adapter)"
      elif [ "$_rc" -ne 0 ]; then
        _msg=$(tail -n 5 "$_err" 2>/dev/null | tr '\n' ' '); rm -f "$_err"
        die "codex dispatch failed (adapter=$adapter, rc=$_rc): $_msg"
      fi
      rm -f "$_err"
      [ -s "$of" ] || die "empty dispatch output"
      exit 0 ;;
    grok-cli)
      grok_available || exit 3
      _err=$(_mktemp)
      # prompt 经 --prompt-file 传入（避免把长 prompt 当 argv 撞 ARG_MAX，I-2）；</dev/null 仍防
      # grok 读 stdin 挂起；--permission-mode plan = 只读规划模式（verifier 不许改码，对应 codex 的
      # --sandbox read-only）；默认模型不支持 reasoningEffort，故不传 effort；--output-format plain
      # 取纯文本裁决；超时防卡死；stderr 留作排障。
      _rc=0
      run_timeout "$TIMEOUT" "$GROK_BIN" --prompt-file "$pf" \
        --permission-mode plan --output-format plain </dev/null >"$of" 2>"$_err" || _rc=$?
      if [ "$_rc" -eq 124 ]; then
        rm -f "$_err"; die "grok dispatch timed out after ${TIMEOUT}s (adapter=$adapter)"
      elif [ "$_rc" -ne 0 ]; then
        _msg=$(tail -n 5 "$_err" 2>/dev/null | tr '\n' ' '); rm -f "$_err"
        die "grok dispatch failed (adapter=$adapter, rc=$_rc): $_msg"
      fi
      rm -f "$_err"
      [ -s "$of" ] || die "empty dispatch output"
      exit 0 ;;
    *) die "unknown adapter: $adapter" ;;
  esac
}

# 写沙箱派发：在指定 worktree 内执行 agent 落地子任务（cross-execute 专用）。
# 与 cmd_dispatch 唯一差别：--sandbox workspace-write --ask-for-approval never（允许改文件、
# 不交互停等）+ 在 <worktree-dir> 作 cwd。其余（防 stdin 挂起、effort、超时、错误归一）同。
cmd_dispatch_write() {
  adapter=$1; pf=$2; of=$3; wt=$4
  [ -f "$pf" ] || die "prompt-file not found: $pf"
  [ -d "$wt" ] || die "worktree dir not found: $wt"
  # 隔离红线的【脚本层】防线（不只靠 cross-execute 文档）：写沙箱只许落在隔离的 *linked*
  # git worktree（`git worktree add` 产生，git-dir 形如 .../.git/worktrees/<n>）。主工作区 /
  # 裸目录 / 非 git 目录一律拒——挡住「让写权限 agent 在主 checkout 改文件」这个核心危险。
  command -v git >/dev/null 2>&1 || die "dispatch-write requires git"
  _gd=$(git -C "$wt" rev-parse --absolute-git-dir 2>/dev/null) \
    || die "dispatch-write target is not a git worktree: $wt"
  case "$_gd" in
    */worktrees/*) : ;;   # linked worktree → 隔离，放行
    *) die "dispatch-write refuses non-isolated dir (use 'git worktree add'): $wt" ;;
  esac
  case "$adapter" in
    codex-cli)
      codex_available || exit 3
      _err=$(_mktemp)
      _effort_arg="model_reasoning_effort=\"$EXECUTE_EFFORT\""
      _rc=0
      # 经 sh -c 切到 worktree 再 exec codex：$1=bin $2=cwd $3=effort-arg。
      # prompt 经 stdin 传入（exec 省略 positional 时从 stdin 读 instructions），避免 ARG_MAX（I-2）；
      # workspace-write 沙箱准其在 cwd 改文件。codex exec 本就非交互、无审批提示（--ask-for-approval
      # 是 TUI 的，exec 没有），故不传该 flag。已校验是 git worktree，不带 --skip-git-repo-check。
      run_timeout "$TIMEOUT" sh -c '
        cd "$2" || { echo "external-agent: cannot cd to worktree: $2" >&2; exit 1; }
        exec "$1" exec --sandbox workspace-write -c "$3"
      ' external-agent "$CODEX_BIN" "$wt" "$_effort_arg" \
        <"$pf" >"$of" 2>"$_err" || _rc=$?
      if [ "$_rc" -eq 124 ]; then
        rm -f "$_err"; die "codex dispatch-write timed out after ${TIMEOUT}s (adapter=$adapter)"
      elif [ "$_rc" -ne 0 ]; then
        _msg=$(tail -n 5 "$_err" 2>/dev/null | tr '\n' ' '); rm -f "$_err"
        die "codex dispatch-write failed (adapter=$adapter, rc=$_rc): $_msg"
      fi
      rm -f "$_err"
      [ -s "$of" ] || die "empty dispatch-write output"
      exit 0 ;;
    *) die "unknown adapter: $adapter" ;;
  esac
}

[ $# -ge 1 ] || die "usage: external-agent.sh <healthcheck|dispatch|dispatch-write> ..."
sub=$1; shift
case "$sub" in
  healthcheck) [ $# -eq 1 ] || die "healthcheck <adapter>"; cmd_healthcheck "$1" ;;
  dispatch)    [ $# -eq 3 ] || die "dispatch <adapter> <prompt-file> <out-file>"; cmd_dispatch "$1" "$2" "$3" ;;
  dispatch-write) [ $# -eq 4 ] || die "dispatch-write <adapter> <prompt-file> <out-file> <worktree-dir>"; cmd_dispatch_write "$1" "$2" "$3" "$4" ;;
  *) die "unknown subcommand: $sub" ;;
esac
