# 「状态未变就跳过校验」的缓存：指纹不全 = 门被静默绕过（false-skip）

- symptom:        给完成门控加"自上次绿以来无改动即跳过"的指纹缓存后，出现 false-skip——
                  改了东西却被判"未变"放行：①被提交/共享的 last-green 在别的机器/检出上指纹相同
                  → 跳过全部门（即便此处会失败）；②测试依赖的 `.gitignore` 文件（.env/fixtures）
                  改动不进指纹 → 跳过。
- root_cause:     指纹"不完整"：缺机器/仓库路径身份（故跨机误命中）、用 `--exclude-standard`
                  排除了被忽略但测试真实依赖的文件。false-skip 的危害方向是**门被绕过**（比
                  false-run 严重得多）。
- fix:            指纹掺入 `git rev-parse --show-toplevel` + `uname` 身份令共享缓存异机不误匹配；
                  顶部诚实声明"依赖被忽略文件时勿开缓存"；默认关闭(opt-in)、非 git/失败回退到"跑"。
- generalization: 任何"无变化则跳过校验/测试"的优化，失败方向必须是"多跑"而非"漏跑"：指纹要
                  含身份(机器/路径)且覆盖全部影响结果的输入；做不到就 opt-in + 诚实声明盲区，
                  别让它成为静默绕过门的通道。验证 false-skip 必须端到端（真 agent/真改动撞）。
- links:          hooks/flow-oracle.sh verify_fingerprint（skip-if-unchanged 缓存）；信号=verifier 真 bug（第四轮）。
- last_verified:  2026-06-26
