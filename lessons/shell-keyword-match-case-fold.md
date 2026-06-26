# shell 关键词子串匹配前必先折叠小写

- symptom:        基于 POSIX `case "$INPUT" in *keyword*)` 的关键词检测对句首/标题大写
                  大面积假阴：`Migrate the Database` / `Deploy to Production` 全部漏判，
                  只有全小写输入才命中。
- root_cause:     POSIX `case` 的 glob 子串匹配**区分大小写**；而用户在句首/标题/驼峰里
                  大写极常见，词表却只列了小写 → 多数真实输入漏网。
- fix:            匹配前 `INPUT_LC=$(printf '%s' "$INPUT" | tr 'A-Z' 'a-z')`，对 `$INPUT_LC`
                  做 `case`；词表只留小写（去掉 OAuth 这类大写冗余）。中文不受 tr 影响。
- generalization: 任何 shell 关键词/敏感词子串匹配，先 `tr A-Z a-z` 折叠小写再 case，
                  否则大写说法静默漏判。测试必须含「大写/标题化」用例，否则假阴看不出来。
- links:          hooks/flow-reinject.sh（档位地板检测）；信号=verifier 抓到真 bug（第五轮）。
- last_verified:  2026-06-26
