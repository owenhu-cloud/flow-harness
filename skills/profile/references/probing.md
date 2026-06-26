# 探测细则 — 各源抽什么、采样启发法、多源冲突

主文件给了阶梯（CI > 清单 > 采样）。这里是每一级的执行细节。目标：**少而准**，凡要写进 `verify-cmd` 的命令一律先实跑。

## 1. CI 配置（最可靠）

- 路径：`.github/workflows/*.yml`、`.gitlab-ci.yml`、`.circleci/config.yml`、`azure-pipelines.yml`、`Jenkinsfile`。
- 抽：`run:` / `script:` 步骤里真正执行的 test / build / lint 命令；以及矩阵里的语言版本、依赖安装命令。
- 关键：CI 跑什么，「完成」就该满足什么。把 CI 的核心 test/build 串作为 `verify-cmd` 首选，本机实跑确认（CI 可能依赖云端服务，挑能本机独立跑的子集，并在 project.md 记一句「CI 全量含 X 外部依赖，本机验证用子集 Y」）。

## 2. 包 / 构建清单

| 生态 | 看 | 典型命令 |
|---|---|---|
| Node | package.json `scripts` | `npm test` / `pnpm test` / `yarn test`、`npm run build`、`npm run lint` |
| Go | go.mod、Makefile | `go test ./...`、`go build ./...`、`go vet ./...` |
| Rust | Cargo.toml | `cargo test`、`cargo build`、`cargo clippy` |
| Python | pyproject.toml / tox.ini / Makefile | `pytest`、`ruff check`、`mypy` |
| 多语言 | Makefile / Justfile | `make test` / `make check` |

- 占位陷阱：脚本可能是 `"test": "echo \"no test\" && exit 0"` 或 `exit 1`。**实跑一次**看它是否真跑测试、退出码是否反映结果——否则不写进 verify-cmd。
- 包管理器以 lockfile 判定：`pnpm-lock.yaml`→pnpm、`yarn.lock`→yarn、`package-lock.json`→npm。命令前缀别写错。

## 3. 代码采样（风格 / 反模式）

探不出命令时降级、或为填风格约定时用。**多点采样取众数，别拿单文件下结论**：

- 命名：抽 3–5 个同类文件看 函数/变量/文件 命名风格（camelCase / snake_case / PascalCase）。
- 格式化器：找 `.prettierrc`、`.editorconfig`、`rustfmt.toml`、`.golangci.yml`、`ruff.toml`——配置优先于肉眼。
- import 顺序 / 分组：看 2–3 个文件头部。
- 错误处理：看是 异常 / Result / error-return / 哨兵值；有无统一封装。
- 测试约定：测试文件位置（`__tests__`/`_test.go`/`tests/`）、命名、断言库。

每条约定**旁标样本路径**（如 `来自 internal/svc/user.go:1-20`），让 implement 能回溯核对。

## 4. 多源冲突裁决

- 命令冲突：**CI > 清单 > 采样**。以高源为准，project.md 记一句分歧（如「Makefile 用 go test，CI 额外加 -race，以 CI 为准」）。
- 风格冲突：格式化器**配置文件 > 肉眼采样**。配置存在即以配置为准。
- 始终：写进 verify-cmd 的那条，无论来源，先本机实跑。

## 5. 子代理发散探测

R2/R3 仓库大时，派 `Task` 子代理并行探：一个读 CI+清单出命令、一个采样出风格、一个扫项目特异反模式。主线程只收**回填后的画像草稿**，核对命令实跑证据后落盘，保护主上下文。子代理回报的命令，主线程仍要亲自实跑确认再写 verify-cmd——不信任子代理自报「能跑」。
