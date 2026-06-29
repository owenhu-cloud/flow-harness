#!/bin/sh
# Flow 技能结构 lint（机器门）。校验技能目录满足契约 §7 的可机检不变量，
# 让 SKILL.md 改动也有可运行验证（契合 harness「不靠自律靠机器门」哲学），非纯人审。
#
# 用法: skill-lint.sh <skill-name> | --all
# 硬错(exit 1): SKILL.md 缺失 / frontmatter name != 目录名 / 正文引用的 references 文件不存在。
# 软警告(不影响退出码): 行为类技能（含「铁律」者）疑似缺『红线』段或 checklist。
# 跳过 skills/_* 内部目录（如 _lint 自身）。
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)   # = skills/
err=0

lint_one() {
  d=${1%/}; name=$(basename "$d"); f="$d/SKILL.md"
  [ -f "$f" ] || { echo "ERROR[$name]: SKILL.md 缺失"; err=1; return; }
  fn=$(sed -n 's/^name:[[:space:]]*//p' "$f" | head -n1 | tr -d '[:space:]')
  [ "$fn" = "$name" ] || { echo "ERROR[$name]: frontmatter name='$fn' != 目录名'$name'"; err=1; }
  # 正文引用的 references/* 必须存在。鲁棒提取（机器门不可误杀）：
  #   - 跳过 ``` 代码块（内联示例路径不算引用）
  #   - 左边界锚定（杀粘连词如 somemyreferences/）、最多一段技能前缀
  #   - 跨技能 <seg>/references/X 仅当 <seg> 是真实技能目录才校验（杀 URL / 深层路径）
  for r in $(awk '
      /^```/ { fence=!fence; next } fence { next }
      { s=$0
        while (match(s, "(^|[^A-Za-z0-9._/-])([A-Za-z0-9_-]+/)?references/[A-Za-z0-9._-]+")) {
          t=substr(s,RSTART,RLENGTH); sub("^[^A-Za-z0-9._/-]","",t); print t
          s=substr(s,RSTART+RLENGTH)
        } }' "$f" | sort -u); do
    case "$r" in
      references/*)   path="$d/$r" ;;
      */references/*) seg=${r%%/references/*}
                      [ -d "$ROOT/$seg" ] || continue   # 前缀非真实技能 → URL/示例，跳过
                      path="$ROOT/$r" ;;
      *) continue ;;
    esac
    [ -e "$path" ] || { echo "ERROR[$name]: 引用了不存在的 $r"; err=1; }
  done
  # 软警告：行为塑造类（含「铁律」）应配红线表与 checklist
  if grep -q '铁律' "$f"; then
    grep -q '红线' "$f" || echo "WARN[$name]: 含铁律但未见『红线』段"
    grep -qi 'checklist' "$f" || echo "WARN[$name]: 含铁律但未见 checklist"
  fi
}

if [ "${1:-}" = "--all" ]; then
  for d in "$ROOT"/*/; do
    case "$(basename "$d")" in _*) continue ;; esac
    lint_one "$d"
  done
elif [ $# -eq 1 ]; then
  lint_one "$ROOT/$1"
else
  echo "usage: skill-lint.sh <name>|--all" >&2; exit 2
fi

[ $err -eq 0 ] && { echo "skill-lint: OK"; exit 0; } || { echo "skill-lint: FAILED"; exit 1; }
