#!/bin/sh
# Flow 治衰减：每轮用户提交（UserPromptSubmit）时重注入一句短路由纪律，
# 对抗会话内上下文增长把 SessionStart 注入的提示越埋越深。
# 刻意保持极短：重注入本身不能反过来造成上下文污染。
# 读 stdin（UserPromptSubmit 的 JSON），命中 #skip-flow 即静默放行。
# 无外部依赖（不需 jq）：注入内容为静态字符串拼接，无引号/反斜杠，无需转义。

INPUT=$(cat)
case "$INPUT" in
  *'#skip-flow'*) exit 0 ;;
esac

# 路由抗压低：命中高危/敏感面关键词（中英）→ 提示档位地板≥R2，别自评压低跳流程。
# 先折叠小写再匹配（句首/标题大写极常见，区分大小写会大面积假阴）；中文不受 tr 影响。
# 敏感词作子串匹配：容忍少量假阳（tokenizer→token、released→release 等），nudge-only、低害。
INPUT_LC=$(printf '%s' "$INPUT" | tr 'A-Z' 'a-z')
FLOOR=''
case "$INPUT_LC" in
  *migration*|*migrate*|*schema*|*rollback*|*'drop table'*|*'delete from'*|*truncate*|*backfill*|*authn*|*authz*|*oauth*|*rbac*|*privilege*|*revoke*|*credential*|*password*|*secret*|*token*|*deploy*|*release*|*'ci/cd'*|*cicd*|*pipeline*|*payment*|*billing*|*production*|*迁移*|*回填*|*鉴权*|*认证*|*权限*|*密钥*|*发布*|*部署*|*支付*|*计费*|*资金*|*生产*)
    FLOOR='命中敏感面（迁移/schema/破坏性SQL/认证/权限/密钥/CI 发布/支付/生产数据），档位地板≥R2，不得自评压低以跳流程。' ;;
esac

# 静态文案用单引号保留字面反引号；变量拼接不会二次求值其值内的反引号，故安全。
BASE='[Flow] 动手工程任务前先用 `flow` 技能判档(R0–R3)并按档走流程；首次进入某代码库先用 `profile` 固化项目画像。判档后按档位用 `Skill` 工具加载对应流程技能（R1+ 写码前 `implement`、收尾前 `verify`；R2/R3 先 `brainstorm`/`plan`），别只判档就凭记忆走。动手改文件前先产出意图契约四行 Intent/Constraints/Non-goals/Verify-signal(可观测)，确认理解再动手。完成声明必带同轮新鲜验证输出，且完成由 Stop hook 的独立 Oracle 复核。'
CTX="$BASE"
[ -n "$FLOOR" ] && CTX="$BASE $FLOOR"
printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$CTX"
