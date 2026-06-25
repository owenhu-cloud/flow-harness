#!/bin/bash
# Flow 一键安装。把框架装进目标项目，装完即用——正常对话即可，无需记任何命令。
#
#   bash install.sh [目标项目目录]     # 缺省为当前目录
#
# 做四件事：①复制 .flow/  ②把 4 个 hook 合并进 .claude/settings.json（幂等、不覆盖既有）
#          ③把 .flow/runs/ 加进 .gitignore  ④自动探测并生成 profile.yml
set -u
SOURCE=$(cd "$(dirname "$0")" && pwd)
TARGET="${1:-$PWD}"
TARGET=$(cd "$TARGET" 2>/dev/null && pwd) || { echo "install: 目标目录不存在: $1" >&2; exit 1; }

command -v jq  >/dev/null 2>&1 || { echo "install: 需要 jq" >&2; exit 1; }
command -v perl >/dev/null 2>&1 || echo "install: 警告 未找到 perl，Oracle 超时将不可用"

if [ "$TARGET" = "$SOURCE" ]; then
  echo "install: 不能装进框架仓库自身；请指定目标项目目录：bash install.sh /path/to/project" >&2
  exit 1
fi

echo "▸ 安装 Flow 到: $TARGET"

# ① 复制 .flow（排除本地运行流水）
mkdir -p "$TARGET/.flow"
cp -R "$SOURCE/.flow/." "$TARGET/.flow/"
rm -rf "$TARGET/.flow/runs"
find "$TARGET/.flow" -name '.DS_Store' -delete 2>/dev/null
chmod +x "$TARGET/.flow/kernel/"*.sh "$TARGET/.flow/bin/flow"
echo "  ✓ 已复制 .flow/（kernel / bin / config / profile / refs / skills）"

# ② 合并 hooks 到 .claude/settings.json（幂等：先剔除旧的 flow-kernel 组再追加）
mkdir -p "$TARGET/.claude"
SET="$TARGET/.claude/settings.json"
MERGE='
  def ensure(ev; script):
    .hooks[ev] = (((.hooks[ev] // [])
      | map(select(([ (.hooks // [])[].command ] | any(. != null and test("/.flow/kernel/"))) | not)))
      + [ {hooks:[ {type:"command", command:("$CLAUDE_PROJECT_DIR/.flow/kernel/" + script)} ]} ]);
  (.hooks //= {})
  | ensure("UserPromptSubmit"; "router.sh")
  | ensure("Stop"; "loop-controller.sh")
  | ensure("PreCompact"; "checkpoint.sh")
  | ensure("SessionStart"; "restore.sh")
'
if [ -f "$SET" ]; then
  if jq -e . "$SET" >/dev/null 2>&1; then
    tmp="$SET.tmp.$$"; jq "$MERGE" "$SET" > "$tmp" && mv "$tmp" "$SET"
    echo "  ✓ 已合并 hooks 进既有 settings.json（保留你原有配置）"
  else
    cp "$SET" "$SET.bak.$$"
    echo '{}' | jq "$MERGE" > "$SET"
    echo "  ⚠ 原 settings.json 非法 JSON，已备份为 settings.json.bak.* 并写入新配置"
  fi
else
  echo '{}' | jq "$MERGE" > "$SET"
  echo "  ✓ 已创建 .claude/settings.json 并注册 4 个 hook"
fi

# ③ .gitignore
GI="$TARGET/.gitignore"
if ! { [ -f "$GI" ] && grep -q '^\.flow/runs/' "$GI"; }; then
  printf '\n# Flow 本地运行流水（不入 git）\n.flow/runs/\n' >> "$GI"
  echo "  ✓ 已把 .flow/runs/ 加入 .gitignore"
fi

# ④ 自动探测 profile
( cd "$TARGET" && .flow/bin/flow profile-init ) | sed 's/^/  /'

echo ""
echo "✅ 安装完成。直接像平常一样用 Claude Code 即可——Flow 会自动判级、自动驱动质量闭环。"
echo "   自检： (cd \"$TARGET\" && bash .flow/kernel/selftest.sh)"
echo "   若上面 ready=false：手填 .flow/profile.yml 的 commands.* 后改 profile.ready: true。"
