# impact.md 完整示例（照此密度产出）

> 填满的 `docs/flow/<change>/impact.md` 范例。场景：给 Order 加 `discountCents` 字段并改结算。
> 同一服务见 codebase-analysis 的 codemap-example.md。骨架见 SKILL.md「产出」。
> 铁律：每条波及关系挂 file:line / git 证据；时序耦合标「含/无代码依赖」；受影响测试集=verify 下限。

```markdown
# add-order-discount 波及面
> impact-analysis 产出。范围给 plan 排任务、给 verify 定测试下限。不替代验证。

## 变更入口
- prisma/schema.prisma（Order 加 discountCents Int @default(0)）
- src/service/order.ts:computeTotal()（结算需减折扣）
- src/repo/order.repo.ts:insert()（落库带新字段）

## 直接受影响（caller + dependent + 契约下游）
- src/api/routes.ts:40 — `POST /orders` zod schema 需加 discountCents（证据：routes.ts:40 引 OrderInput）
- src/service/payment.ts:charge():15 — 扣款金额来自 computeTotal，折扣改变入参（证据：payment.ts:15 调 order.computeTotal）
- src/api/dto.ts:OrderResponse — 响应体若回传 total 受影响（证据：dto.ts:22 映射 computeTotal 结果）

## 间接受影响（二跳，止于稳定边界）
- worker/reconcile.ts:对账 — 依赖落库金额；路径 repo.insert → DB → reconcile 读（证据：reconcile.ts:30 SELECT amount）。止于 DB 边界。

## 时序耦合（git 常共改，≠ 代码依赖）
- src/service/order.ts ↔ test/order.spec.ts：近 6 月共改 9 次（含代码依赖：测试直接覆盖）
- src/service/order.ts ↔ docs/pricing.md：共改 4 次（**无代码依赖**：文档，交人判断是否同步更新）

## 应跑测试集（= verify 下限，不是上限）
- test/order.spec.ts（computeTotal 折扣分支）
- test/payment.spec.ts（扣款金额=折后）
- test/api/orders.e2e.ts（端到端下单带折扣）
- 命令：`npm test -- order payment orders.e2e`（verify 据此，不得缩小）

## 高风险文件（触发强制 code-review）
- src/service/payment.ts — 触支付金额计算，错误直接资金损失。理由：支付域 + 折扣算错=多扣/少扣。
- prisma/schema.prisma — schema 变更需迁移，不可逆性高（档位地板≥R2）。

## 已排除（看似相关，确认无关）
- src/worker/ship.ts — 发货不读金额（证据：grep 无 amount/total 引用），排除。
- src/service/refund.ts — 退款读历史落库值，不经 computeTotal 新逻辑，本次不影响（证据：refund.ts:20 读 order.amount 落库快照）。
```
