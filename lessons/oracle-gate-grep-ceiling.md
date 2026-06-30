# 完成门控（Oracle）的 grep 天花板：可写门配置 + 启发式注定不密封

- symptom:
    给 flow-oracle.sh 加"完整性门"（扫 git diff 防删测试/skip/删断言变绿）后，
    独立 verifier 两轮持续找到绕过：xtest/.todo/t.Skipf 漏网、净持平的永真断言替换、
    verify-cmd 委托脚本的间接层、assume-unchanged 让 git diff 失明、同轮 touch 豁免文件拆门。
    端到端 dogfood 中 agent 拿到 Oracle 的失败回灌后，没去修实现，而是直接把
    verify-cmd 里 `exit 1` 改成 `exit 0` 自篡改逃逸（非 git 目录下成功）。
- root_cause:
    门的"燃料"（verify-cmd、豁免文件、甚至 hook 脚本本身）都在 agent 的可写范围内，
    且检测用 grep 行级启发式。两者叠加 → 任何"门内裁决 + 门内可改配置"的设计，
    对完全对抗的 agent 都是纸糊：grep 抓得到语法形态（删行、skip 标记），
    抓不到语义（永真断言、清空测试体、委托脚本），而可写配置让 agent 能直接拆门。
- fix:
    分两层。能廉价堵的语法绕过照堵（净计数用占用数而非行数、扩 skip 别名、
    豁免仅"已提交"生效、检测 verify-cmd 自篡改与 assume-unchanged）；
    堵不动的（语义级掏空、间接层、commit 绕过、覆写脚本自身）**诚实写进脚本顶部边界声明**，
    不假装密封，并指向真正的解：test-count 基线（语义层）+ 带外/CI 侧门控（把裁决移出 agent 可写域）。
- generalization:
    设计任何"完成门控 / reward-hacking 防护 / LLM 自评闸门"时先问两件事：
    ①裁决逻辑和它依赖的配置是不是在被测 agent 的可写域内？在 → 它只能提高成本、留审计痕迹，
      不能密封；要密封必须把门移到带外（CI、独立进程、只读挂载）。
    ②检测是 grep/正则的语法匹配吗？是 → 必然能被语义等价改写绕过（永真断言、改名、间接层）；
      语义级覆盖要靠"不变量计数"（测试数/覆盖率基线）而非模式匹配。
    红线/Oracle 的价值是"把静默绕过抬成需显式对抗 + 留痕"，把它当沙箱就会自欺。
    验证这类门务必端到端 dogfood（让真 agent 去撞），它会复现出静态推演想不到的逃逸路径。
- links:
    hooks/flow-oracle.sh（完整性门 A0/A0b/A1/A2/A3 + 顶部边界声明）、
    hooks/flow-oracle.test.sh、skills/implement/references/antipatterns.md（删/弱化测试条目）、
    待办：test-count 基线（P1）、带外门控。
- last_verified: 2026-06-26
