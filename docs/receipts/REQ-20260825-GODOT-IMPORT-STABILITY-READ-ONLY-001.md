# REQ-20260825-GODOT-IMPORT-STABILITY 只读诊断回执

- 时间：2026-08-25 11:15 +08:00
- 项目：`D:/AI/zhanchengdashi`
- 分支：`codex/animal-art-integration-20260811`
- 基线：`bbbf0d3e1838844e990820fb9fe7b38dda66fe6b`
- RAG：`READY`，任务回执 `temp/rag/receipts/tasks/REQ-20260825-GODOT-IMPORT-STABILITY.json`
- 控制面：`READY / L1 direct_execute`；最终写集任务指纹 `4CF714896619261F8AAFC8D97AFC5C7CB5C0D6A12AF1D2F241460E6B8DBEAAF2`
- 负责人：`codex-primary`
- 当前共享写锁：无；`docs/active_scope.yaml` 中现有共享锁均为 `RELEASED`

## 已验证现象

- Godot 4.6.3 编辑器正在打开本项目；诊断期间不关闭或终止该进程，避免影响未保存的用户工作。
- 项目根目录 `temp/` 没有 `.gdignore`，其中有 15,420 个文件、约 8.46 GB 数据和 7 个指向 Codex Node 运行时依赖目录的 NTFS junction。
- Godot 已沿这些 junction 扫描并修改外部 `node_modules`：本次发现 194 个由 Godot 在 11:07-11:09 生成的 `.import` 旁文件，`source_file` 均指向 `res://temp/.../node_modules/...`。
- 当前 `.godot/imported/` 有 4,592 个文件、约 252 MiB；其中仅 Firefox/PDF.js/Playwright 命名即可确认的无关导入有 1,476 个、约 179 MiB。
- 同一 Firefox SVG 出现多组不同 hash 的导入产物，证明多个临时路径会对同一外部依赖重复导入。
- `temp/` 每次产生 RAG、QA、表格或发布临时文件时都会触发 Godot 文件系统扫描；由于临时目录和 junction 不属于游戏资源，这就是持续重新导入和编辑器卡顿的直接原因。

## 根因与边界

Godot 只应扫描 `assets/`、`runtime/`、`scenes/`、`scripts/` 及项目根部的必要引擎文件。现有工程已经用 `.gdignore` 隔离大多数非运行时目录，但后来新增的 `temp/`、`outputs/`、`PM/`、`production/`、`deploy/`、`QA/` 未纳入扫描边界，导致临时工具链、文档、部署与 QA 工件被错误视为游戏资源。

## 授权写集

- `.gitignore`
- `docs/DEVELOPMENT_WORKFLOW.md`
- `temp/.gdignore`
- `outputs/.gdignore`
- `PM/.gdignore`
- `production/.gdignore`
- `deploy/.gdignore`
- `QA/.gdignore`
- `tools/check_godot_scan_boundaries.ps1`
- 本任务只读/关闭回执

不修改 `project.godot`、游戏脚本、场景、运行时配置或现有用户工件。任务开始前的脏文件全部保留，不纳入本任务提交。

## 验收口径

1. 所有非运行时根目录都有明确 `.gdignore`，且 `temp/.gdignore` 能被 Git 跟踪。
2. 在已打开的真实编辑器旁向 `temp/` 写入一个可导入探针，Godot 不生成对应导入产物。
3. 在项目外的隔离副本执行一次干净导入和第二次导入；两次均不得扫描 `temp/node_modules`，不得生成 Firefox/PDF.js/Playwright 导入或外部 `.import` 旁文件，第二次不得再次改写导入缓存。
4. 隔离副本能够启动主场景，Godot 输出无 parser error、资源缺失和导入错误。
5. 扫描边界检查脚本能够阻止新的未隔离非运行时根目录和运行时目录 junction 回归。
6. 清理本次错误扫描生成的、可明确归因于 `res://temp/.../node_modules` 的缓存污染；不碰任何源资产或用户修改。
7. `git diff --check` 通过，聚焦提交并推送当前分支。
