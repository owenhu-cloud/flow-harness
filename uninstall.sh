#!/bin/bash
# Flow 卸载。移除 .flow/ 并从 settings.json 摘除 flow hooks（保留你其它配置）。
#   bash uninstall.sh [目标项目目录]     # 缺省为当前目录
set -u
TARGET="${1:-$PWD}"
TARGET=$(cd "$TARGET" 2>/dev/null && pwd) || { echo "uninstall: 目录不存在" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "uninstall: 需要 jq" >&2; exit 1; }

SET="$TARGET/.claude/settings.json"
if [ -f "$SET" ] && jq -e . "$SET" >/dev/null 2>&1; then
  tmp="$SET.tmp.$$"
  jq '
    if .hooks then .hooks |= with_entries(
      .value |= map(select(([ (.hooks // [])[].command ] | any(. != null and test("/.flow/kernel/"))) | not))
    ) else . end
    | if .hooks then .hooks |= with_entries(select(.value | length > 0)) else . end
  ' "$SET" > "$tmp" && mv "$tmp" "$SET"
  echo "✓ 已从 settings.json 摘除 flow hooks"
fi

rm -rf "$TARGET/.flow"
echo "✓ 已移除 .flow/"
echo "（.gitignore 中的 .flow/runs/ 一行如不需要可手动删除）"
