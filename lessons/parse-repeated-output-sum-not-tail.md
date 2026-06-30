# 解析多段重复输出用「求和」而非 tail/head 取单段

- symptom:        从 runner 输出解析"通过测试数"时用 `... | tail -n1`，在多 suite / 多
                  package / monorepo（cargo workspace、go 多包）下只取**最后一个 suite** 的数，
                  基线被锁成个位数；并行交错输出顺序不稳时同一套测试两次解析得不同值 → 假门控。
- root_cause:     `tail -n1`/`head -n1` 假设"只有一段摘要"，多段重复格式下既漏计又顺序敏感
                  （并行 runner 输出顺序不确定）。
- fix:            对同格式的所有匹配**求和**：`grep -oE '[0-9]+ passed' | grep -oE '[0-9]+'
                  | awk '{s+=$1} END{if(NR)print s}'`。求和顺序无关；且只要建立与比较用同一解析，
                  系统性多/少计也自洽，不破地板。
- generalization: 解析"可能出现多次"的汇总行（多模块测试摘要、多文件计数）一律聚合(求和/累加)，
                  不要 tail/head 取单段——否则多模块项目里近乎失效且并行下偶发假阳。
- links:          hooks/flow-oracle.sh extract_count（测试数基线门 B2）；信号=verifier 真 bug（第三轮）。
- last_verified:  2026-06-26
