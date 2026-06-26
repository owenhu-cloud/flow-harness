# 基于条件的等待（禁 sleep N 硬等）

调试竞态/时序类 bug 时最常见的假修复：加一句 `sleep 2` 让它「碰巧稳定」。这是用掩盖换绿灯——根因（竞态）还在，只是把失败概率压低，CI 上换台机器又炸，且白白拖慢每次运行。

## 铁律

- **禁止用固定时长 `sleep N` 来等待某件事就绪。** 等待必须**轮询一个明确的完成条件**，并设超时上限。
- 「先 sleep 让它过，回头再优化」= 危险信号，等同删测试变绿（SKILL 红线）。竞态根因没消，回归测试也守不住。

## 改法：轮询条件 + 超时

把「等够久」换成「等到条件成立或超时失败」：

```
deadline = now() + timeout
loop:
    if condition_met():        # 端口在听 / 文件存在 / 状态==ready / 行数达标
        break
    if now() > deadline:
        fail("条件 X 在 {timeout} 内未达成")   # 显式失败，不静默吞掉
    poll_sleep(50ms)           # 短轮询间隔，不是一次性长睡
```

- **条件要可观测且精确**：等服务起来 → 轮询健康端点返回 200，不是「睡 5 秒它应该起来了」。
- **超时要显式失败**并打印当前实际状态，方便下次定位，别静默继续。
- 优先用框架自带的 `waitFor` / `eventually` / `expect.poll` / `await condition`，少手写。

## 危险信号

- 代码里出现裸 `sleep N` / `Thread.sleep` / `time.sleep` 用于「等就绪」。
- 测试偶发挂，处理方式是「把 sleep 调大一点」—— 越调越慢且治标不治本。
- 「本地稳定 CI 偶挂」基本就是硬等的指纹。

## 正例 / 反例

- 反例：`startServer(); sleep(3); assert healthy()` —— 慢机器 3 秒不够、快机器白等。
- 正例：`startServer(); waitUntil(() => httpGet('/health')==200, timeout=10s); assert healthy()` —— 快则快过、慢则等够、真挂则超时显式报错。

回到 `SKILL.md`。涉及时序的 bug，根因要修在同步契约上，等待只用条件轮询兜。
