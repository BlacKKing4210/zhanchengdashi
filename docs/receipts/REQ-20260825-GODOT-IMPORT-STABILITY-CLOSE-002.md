# REQ-20260825-GODOT-IMPORT-STABILITY 关闭回执

- 日期：2026-08-25
- 项目：`D:/AI/zhanchengdashi`
- 分支：`codex/animal-art-integration-20260811`
- 基线：`bbbf0d3e1838844e990820fb9fe7b38dda66fe6b`
- 任务：彻底排查并解决 Godot 编辑器持续重新导入资源导致的卡顿
- 结果：`PASS`

## 根因

项目后来新增的 `temp/` 没有根级 `.gdignore`。该目录有 15,420 个文件、约 8.46 GB 数据、23 个嵌套 Godot 工程副本，以及 7 个指向 Codex Node 运行时依赖的 NTFS junction。Godot 沿 junction 进入同一套外部 `node_modules`，对 Firefox、PDF.js、Playwright 的 SVG、字体等资源按多个 `res://temp/...` 路径重复导入；临时工具每次写入又会触发下一轮扫描。

修复前实测：

- `.godot/imported/`：4,592 个文件，264,341,499 字节。
- 仅按 Firefox/PDF.js/Playwright 命名即可确认的污染：1,476 个文件，187,831,494 字节。
- 外部 Node 依赖中发现 209 个 Godot `.import` 旁文件，内容明确记录 `source_file="res://temp/.../node_modules/..."`。
- 同一 Firefox SVG 有多组不同 hash 导入产物，确认重复路径导入而非正常资源更新。

## 修复内容

1. 给 `temp/`、`outputs/`、`PM/`、`production/`、`deploy/`、`QA/` 增加根级 `.gdignore`，补齐所有非运行时根目录的 Godot 扫描边界。
2. 调整 `.gitignore`：继续忽略 `temp/*`，但显式保留并允许提交 `temp/.gdignore`。项目专用规则放在通用 Unreal `Temp/` 规则之后，避免 Windows 不区分大小写导致 sentinel 再次被忽略。
3. 在 `docs/DEVELOPMENT_WORKFLOW.md` 固化运行时扫描白名单：Godot 只扫描 `assets/`、`runtime/`、`scenes/`、`scripts/` 和必要根文件；工具、文档、临时、发布、部署和 QA 根目录必须隔离。
4. 新增 `tools/check_godot_scan_boundaries.ps1`，检查所有非运行时根目录都有 `.gdignore`、四个运行时根目录不存在 junction/symlink，并验证 Git 会跟踪 `temp/.gdignore` 但忽略其他 `temp/*`。
5. 不修改 `project.godot`、运行时脚本、场景、配置表或源资产。

## 验证证据

### 已打开的真实编辑器

- 编辑器：Godot 4.6.3，原有 PID 13260；全程未关闭或终止。
- 修复后写入 `temp/import_stability_probe/codex_gdignore_probe.svg`，等待 12 秒：探针对应导入数 0，导入缓存总数和最新写入时间不变，外部 `.import` 新增/改写数 0。

### 项目外完整隔离副本

隔离副本包含当前项目、完整游戏资源、`temp/.gdignore`，并故意在 `temp/junction_probe/node_modules` 放置指向原外部 Node 依赖的 junction。

- 首次干净导入：Godot exit 0，6,753 ms，仅扫描并导入 164 个真实游戏资源。
- 第二次无改动导入：Godot exit 0，3,878 ms。
- 两次之间 `.godot/imported/` 均为 328 个文件、20,928,640 字节。
- 两次缓存 SHA-256 集合摘要均为 `EC685D6F88FD1C9F41C183D2CC75B2847BE7E5CD0CE96ABABB7BC21982559CA9`；数量、字节、内容和最新写入时间全部未变化。
- `temp/` 缓存命中 0；探针旁文件 0；Firefox/PDF.js/Playwright/toolbar 命中 0；外部 Node `.import` 新增或改写 0。
- 隔离启动主场景 exit 0；`SCRIPT ERROR`、`Parse Error`、资源缺失、加载失败、无 loader、无效调用计数均为 0。日志中有 2 条在线房间 RPC checksum 消息，来自并行连接的现有网络会话，与资源导入、解析和本任务修改无关，本回执不把网络协议状态声明为已修复。

### 现有缓存清理与稳定性

以当前 164 个真实源资源的 `.import` 映射为白名单，白名单精确对应 328 个缓存文件和隔离干净导入结果；随后仅隔离并清理其余缓存：

- 错误缓存：4,264 个，243,412,859 字节。
- 外部 Node Godot 旁文件：209 个，225,585 字节。
- 清理后真实工程缓存：328 个，20,928,640 字节，与隔离干净导入的数量、字节和摘要完全一致。
- 在仍打开的真实 Godot 编辑器旁连续观察 15 秒：缓存数量和摘要不变，编辑器仍存活，外部临时旁文件为 0。
- 该 15 秒内编辑器 CPU 累计 0.25 秒，平均进程总 CPU 约 1.67%，折算整机约 0.10%；没有持续导入写入。
- 在真实编辑器仍打开时完整重建项目 RAG（6,078 ms，大量写入 `temp/rag/`）：RAG `READY`、16/16 golden queries 通过，Godot 缓存前后仍为 328 个且摘要、数量、最新写入时间完全不变，编辑器继续存活。

### 回归检查

- `tools/check_godot_scan_boundaries.ps1` 在真实项目：PASS。
- 同一检查在含 `temp/node_modules` junction 的隔离项目：PASS。
- 本任务没有修改 `.gd`，无需进行缩进迁移；隔离编辑器已完成 GDScript 注册和主场景资源加载。

## 保留与清理

- 任务开始前的用户/前序脏文件全部保留，未纳入修复或缓存白名单删除。
- 只清理可重建的 `.godot` 错误缓存和内容明确指向 `res://temp/.../node_modules` 的外部 Godot 旁文件；没有删除源资源。
- 隔离项目、验证日志、测试 junction 和临时 quarantine 在验证后删除，不作为交付物或版本库内容。
