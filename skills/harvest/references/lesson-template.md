# lesson 模板与字段规范

每条经验追加到项目 `lessons/<slug>.md`（`<slug>` 取根因关键词，连字符）。一文件可累积多条同主题 lesson。

## 模板

```markdown
# <一句话标题：可检索的症状 + 结论>
- signal:         触发它的学习信号（连败升维 / 移交 / 返工 / 判档被推翻 / verifier 抓 bug，五选一）
- symptom:        外部可观察的症状 / 报错原文 / 现象（写得能被关键词搜到）
- root_cause:     根因，穿透到机制层；定位不到写「未定位」并说明卡在哪
- fix:            这次怎么修的（一两行，不展开流水）
- generalization: 「下次遇到 <关键词/症状> 时，应 <可执行动作>」
- links:          关联路径 / 模块 / 反模式条目 / 相关 lesson
- last_verified:  YYYY-MM-DD
```

## 字段写法：正例 vs 反例

| 字段 | 正例 | 反例（删掉重写） |
|---|---|---|
| 标题 | `flaky async 测试：未 await 的 promise 致断言早跑` | `修了一个 bug` |
| signal | `verifier 抓 bug` | 空着 / 「感觉值得记」 |
| symptom | `CI 偶发红，本地重跑又绿；报错 expected X got undefined` | `测试有问题` |
| root_cause | `async fn 返回 promise 未 await，断言在副作用完成前执行` | `代码写错了` |
| generalization | `见 flaky async 测试，先 grep 未 await 的 async 调用` | `以后要更细心` |
| links | `src/sync/queue.ts; implement/references/antipatterns.md#ts` | 空 |

## 去重规则

写前 `grep -ri "<根因关键词>" lessons/`：
- 命中同根因 → 更新旧条目（补 symptom 变体、刷新 `last_verified`），不开新条。
- 命中相关但不同根因 → 新条，并在双方 `links` 互指。
- 未命中 → 新建。

## 何时从 lessons/ 升级到固化

同一根因**第二次**踩到（复发）即升级，不等第三次：
- 实现期反模式 → 追加到 `implement/references/antipatterns.md` 对应语言分区，让 verifier 每次对照扫描。
- 跨任务的项目级约束 → 写进项目 `CLAUDE.md`，让每次会话必看。
- 一次性、低复发的教训 → 留在 `lessons/` 即可，不固化，避免强制路径膨胀。
