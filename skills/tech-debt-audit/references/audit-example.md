# TECH_DEBT_AUDIT.md 完整示例（照此密度产出）

> 填满的根目录 `TECH_DEBT_AUDIT.md` 范例。同一 orders 服务（见 codemap-example.md）。
> 铁律：每条带 `file:line`，禁「整体偏乱」空话；「看着差其实合理」节强制非空。骨架见 SKILL.md。

```markdown
# 技术债审计报告
> tech-debt-audit 维护。可复跑：复跑时标 RESOLVED / NEW，逐条重核。
- 审计日期: 2026-06-26   提交: a1b2c3d   规模: 14.2k LOC
- 信号源: git churn(近 6 月) + eslint-complexity + jest --coverage

## 风险表（按 churn×complexity 降序）
| ID | 状态 | 位置 file:line | 类别 | churn | 复杂度 | 覆盖率 | 影响 | 严重度 | 建议方向 |
|----|------|----------------|------|-------|--------|--------|------|--------|----------|
| D1 | 仍存在 | src/service/order.ts:28-160 | god-fn computeTotal | 27 | 38 | 41% | 结算逻辑高频改、分支多、折扣/税/运费纠缠 | 高危 | 拆 pricing 策略 + 补分支测试 |
| D2 | 仍存在 | src/service/payment.ts:15-90 | 无错误路径测试 | 14 | 22 | 0% | 支付域零测试覆盖，改动直接资金风险 | 高危 | 先补集成测试再动 |
| D3 | NEW | src/repo/order.repo.ts:40-75 | 重复事务样板×3 | 11 | 16 | 60% | 三处近乎复制的事务包裹 | 中 | 抽 withTx 包装 |
| D4 | RESOLVED(2026-06-20) | ~~src/shared/config.ts:12~~ | 循环依赖 | - | - | - | 已解（拆 config/env） | - | - |

## 热点榜（churn × complexity top 5）
1. service/order.ts — 27×38=1026
2. service/payment.ts — 14×22=308
3. api/routes.ts — 19×9=171（churn 高但低复杂，非债，见下）
4. repo/order.repo.ts — 11×16=176
5. worker/reconcile.ts — 8×20=160

## 看着差其实合理（考虑过但不flag，含理由）  ← 强制节，不可省
- api/routes.ts:1-220 — churn=19 偏高，但都是「加端点」式追加、单端点复杂度低、有 e2e 覆盖；高 churn 来自功能增长不是腐坏，不是债。
- src/shared/errors.ts:1-300 — 行数多但是穷举错误类型表、复杂度≈1、零 churn，本质数据不是债。
- prisma/schema.prisma — 大文件但 schema 即应集中，按债处理是误报。

## 复跑摘要（第二次起填）
- RESOLVED: D4（config 循环依赖，2026-06-20 拆分）
- NEW: D3（repo 事务重复，本次新增）
- 仍存在: D1, D2（结算 god-fn / 支付无测试——两轮未还，建议升 plan 优先级）
```
