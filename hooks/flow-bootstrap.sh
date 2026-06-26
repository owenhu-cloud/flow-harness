#!/bin/sh
# Flow 的唯一常驻部分：会话开始（含 /clear、压缩后）注入一句路由纪律，
# 保证 agent 在动手前先用 `flow` 技能判档。正文按需用 Skill 工具懒加载。
# 无外部依赖（不需 jq）：注入内容为静态字符串拼接，无引号/反斜杠，无需转义。

# 过期守卫：项目画像已固化时，若依赖/构建清单晚于画像 → 提示画像可能过期，先 profile 增量更新。
# -nt 在 dash/bash/zsh/ash 均支持；不支持时 test 失败 → EXTRA 空，无副作用（fail-safe）。
# -nt 为严格大于：清单与画像同秒修改时不报过期（方向 fail-safe：少报、nudge-only）。
EXTRA=''
if [ -f docs/flow/project.md ]; then
  for m in package.json package-lock.json go.mod go.sum Cargo.toml pyproject.toml requirements.txt \
           pom.xml build.gradle build.gradle.kts Gemfile composer.json; do
    if [ -f "$m" ] && [ "$m" -nt docs/flow/project.md ]; then
      EXTRA=' 注意：依赖/构建清单晚于项目画像(docs/flow/project.md)，画像可能过期——先用 `profile` 增量更新对应字段再继续。'
      break
    fi
  done
fi

# 静态文案用单引号保留字面反引号；变量拼接不会二次求值其值内的反引号，故安全。
BASE='[Flow] 已启用。动手任何工程任务前，先用 Skill 工具加载 `flow` 技能判复杂度档位并路由。四维(影响面/不可逆性/未知度/风险)各0-3求和：0-1=R0直执 · 2-4=R1轻流程 · 5-8=R2标准(brainstorm→plan→门→implement→verify→document) · 9-12=R3项目。覆盖标记：#R0..#R3 强制 · #skip-flow 跳过 · #new 重判。红线：完成声明必带同轮新鲜测试输出；builder≠verifier；执行流水账不当文档交付。'
CTX="$BASE"
[ -n "$EXTRA" ] && CTX="$BASE$EXTRA"
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$CTX"
