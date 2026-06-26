# hotspot-mining — 挖热点的命令、工具与打分

主 SKILL 给机制，这里给可照搬的命令、各栈工具、打分公式与大库子代理分工。证据全部来自本仓库，不查外网。

## 1. 挖 churn（改动频率）

技术债藏在「改得最勤」的文件里。统计近 6–12 个月（项目活跃则取更短窗口）各文件被提交触及的次数：

```bash
# 各文件改动次数，降序（近 12 个月）
git log --since="12 months ago" --name-only --pretty=format: \
  | grep -v '^$' | sort | uniq -c | sort -rn | head -40

# 只看源码、排除生成物/锁文件/vendor（按项目调整 grep）
git log --since="12 months ago" --name-only --pretty=format: \
  | grep -vE '(^$|vendor/|node_modules/|dist/|\.lock$|\.snap$|_gen\.|\.pb\.go$)' \
  | sort | uniq -c | sort -rn | head -40

# 某文件的改动历史（看是不是高频、谁在改、commit 意图）
git log --since="12 months ago" --oneline -- <path>
```

排除项很关键：生成代码、锁文件、快照、vendor 的高 churn 是噪音，不是债。先把它们滤掉再排序。

**churn 也是「热」的信号**：top 文件不一定复杂，但「常改」本身意味着它是系统的活跃中心，值得优先看复杂度。

## 2. 量 complexity（难改程度）

按 profile 画像里的技术栈派对应工具（与 profile 的反模式扫描同源，但目的不同：profile 查规范违例，这里量债务热度）。优先用项目已装的工具，没有再用一次性 `npx`/`pipx`。

| 栈 | 圈复杂度 / god | 循环依赖 | 重复 | 死代码 |
|----|----------------|----------|------|--------|
| TS/JS | `npx eslint`(complexity 规则) | `npx madge --circular src` | `npx jscpd src` | `npx knip` / `npx ts-prune` |
| Python | `radon cc -s -n C .` | `pydeps --show-cycles` | `pylint --disable=all -e duplicate-code` | `vulture .` |
| Go | `gocyclo -over 15 .` | `go mod graph` / `staticcheck` | `dupl -threshold 50 ./...` | `staticcheck ./...` |
| Rust | `cargo clippy`(cognitive_complexity) | `cargo modules` | — | `cargo +nightly udeps` |
| 通用兜底 | god-file = 行数阈值(默认 >500 LOC) + 超长函数 | import 图人工抽样 | 目测重复块 | — |

god-file 的行数阈值随项目调整（profile 里若记了语言惯例就用它）。**行数只是触发深看的信号，不是判罪依据**——必须叠加 churn 才定级（见 SKILL 红线）。

## 3. 覆盖率（有则纳入三角）

若 profile 记录了测试命令且能出覆盖率，跑一次拿到各文件覆盖率；缺则跳过，报告里注明「无覆盖率数据」，不要瞎猜数字。

```bash
# 例：Go
go test ./... -coverprofile=/tmp/cov.out && go tool cover -func=/tmp/cov.out
# 例：JS（按项目实际命令）
npx jest --coverage
```

## 4. 交集打分

把信号合成一个可排序的分数，目的是排序、不是精确度量：

```
churn  = 近 N 月该文件提交触及次数
cplx   = 圈复杂度峰值 或 god 程度（行数/阈值）
cov    = 覆盖率(0–1)，无数据时取 0.5 中性值

score  = churn * cplx / max(cov, 0.1)
```

- 高 churn × 高 cplx × 低 cov → 分数飙高 → **高危**（每次改都贵、易错、无网兜）。
- 低 churn 的高 cplx → 分数被压低 → 降级（丑但不常碰，痛感低）。
- 高 churn 的低 cplx → 中低（常改但好改，先放放）。

severity 映射按相对排名分四档（高危/中/低/观察），不卡死绝对阈值——不同库基线不同，取本库分布的相对高位。

## 5. 大库（>50k LOC）子代理分工

主上下文吞不下全库源码。用 `Task` 工具按目录/模块切分，每个子代理审一块，**只回传结构化条目，不回传源码**。

派发要点：
- 先在主线程跑完 churn 排序（步骤 1，便宜），圈定 top 模块再派——别让子代理盲扫全库。
- 每个子代理领一个模块 + churn 数据，职责：量复杂度、深读热点、产条目。
- 强制子代理回传**带 file:line 的条目**，无坐标的发现退回（铁律 1 对子代理同样生效）。

子代理回传格式（主线程据此汇总打分、去重、定级）：

```
模块: <dir>
- file:line | 类别 | churn | 复杂度 | 覆盖率 | 影响(一句) | 建议方向(一句)
- ...
看着差其实合理(本模块):
- file:line | 为什么不flag
```

主线程负责：跨模块统一打分排序、合并「看着差其实合理」节、写最终 `TECH_DEBT_AUDIT.md`。子代理自报「审完了」不算数——主线程核每条都有坐标才采纳。
