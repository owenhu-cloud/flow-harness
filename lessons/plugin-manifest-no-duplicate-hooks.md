# Claude Code 插件 plugin.json 别声明自动加载的 hooks/hooks.json

- symptom:        插件"装了却不生效"（hook 全不触发）；`claude plugin list` 显示
                  `✘ failed to load` + `Duplicate hooks file detected: ./hooks/hooks.json`。
- root_cause:     Claude Code 按约定**自动加载** `hooks/hooks.json`；plugin.json 再写
                  `"hooks": "./hooks/hooks.json"` → 同一文件被加载两次 → 整个插件加载失败，
                  其声明的所有 hook（含 Stop/Oracle）随之全部失效。manifest.hooks 只应指向
                  「额外的、非标准路径的」hook 文件。
- fix:            删掉 plugin.json 里的 `hooks` 键，靠自动加载。
- generalization: Claude Code 插件「装了不生效」先跑 `claude plugin list` 看 load status，
                  别假设已生效；plugin.json **不要**声明标准路径 `hooks/hooks.json`（自动加载，
                  显式声明=重复=整插件加载失败）。机制级功能上线后必须验证它真的 loaded。
- links:          .claude-plugin/plugin.json、hooks/hooks.json；信号=返工（Oracle 从未真正运行过）。
- last_verified:  2026-06-26
