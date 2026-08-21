# F-ZC-ADMIN-001 本地实现与验证回执

- Request ID：`REQ-20260814-ADMIN-ANALYTICS-RESOURCE-GRANTS`
- Feature ID：`F-ZC-ADMIN-001`
- 时间：`2026-08-14 11:46:45 +08:00`
- 本地实现状态：`VERIFIED`
- 阿里云部署状态：`NOT READY: Aliyun deployment profile`
- 生产账号初始化状态：`NOT EXECUTED`

## 范围与正式来源

- 正式设计：`docs/ADMIN_ANALYTICS_DASHBOARD_DESIGN.docx` / `docs/ADMIN_ANALYTICS_DASHBOARD_DESIGN.md`
- 可编辑设计：Figma 文件 `bGtSRFlZfFe8erC5GdGVP4`，页面节点 `10:33`
- RAG Gate：`READY`，54 个来源、756 个 chunks、13/13 golden queries、mean recall@k = `1.0`
- RAG index signature：`0ca2115d716f39caa9b1344943f116548efe706719cd686fd64d1c329ea98413`
- Task receipt：`temp/rag/receipts/tasks/REQ-20260814-ADMIN-ANALYTICS-RESOURCE-GRANTS.json`

## 已实现

1. Node Web 后台保留 Owner / Analyst 权限、scrypt 凭据、登录限流、会话过期、HttpOnly/SameSite Cookie、CSRF/Origin 校验和安全响应头。
2. 动物统计新增排名样本、平均名次、不同参赛规模的标准化名次得分、平均参赛数、Wilson 置信区间和人工平衡复核信号；低样本不会给出确定调整结论，后台不会直接修改平衡配置。
3. Godot 权威服按最多 5000 条保留比赛回填旧数据，并持续生成只读、脱敏的 `dashboard_snapshot.json`。
4. Godot 权威账号存储生成全账号 `admin_accounts_snapshot.json`，包含完整 UserID、保存阵容、卡牌等级、段位镜像和允许展示的资源摘要，不含账号明文、密码哈希、salt、session、refresh token 或 installation 标识。
5. Owner 可向一个明确 UserID 或提交时冻结的全部账号目标发送资源命令。当前允许资源仅为 `gacha_tickets` 和指定 `card_id` 的 `card_copies`。
6. 发放使用 Owner 二次认证、全服固定确认文本、UUID 幂等键、原子无覆盖入队、持久化处理账本、processed/failed 回执和 profile revision/CAS，避免网络重试重复到账及旧客户端覆盖后台发放。
7. Web UI 已覆盖总览、动物平衡、阵容库、Owner 资源发放、任务与审计、Owner 权限六页，并包含 ARIA tab、焦点管理、状态播报和 390px 窄屏布局。
8. 已提供非 root systemd、独立状态目录、TLS、版本化 release/current、共享目录最小权限、游戏服 drop-in、备份/回滚及只读预检模板；未修改现有 `junglelaw-server.service`。

## 验证证据

- Node：`node --test tests/admin_dashboard/dashboard.test.mjs`，13/13 通过；覆盖同幂等键不同金额、不同目标及并发入队冲突返回 `409 idempotency_conflict`。
- GDScript：Tab 缩进检查通过；Godot 4.6.2 新综合场景输出 `ADMIN_BACKEND_FEATURES_TEST_PASS`。
- 既有回归：`test_match_analytics_store`、`test_player_account_store`、`test_online_room_analytics`、`test_online_main_adapter` 全部通过。
- 浏览器：本机 Chrome headless 以短时 `127.0.0.1` 测试实例完成 Owner 登录、动物平均名次、全量阵容、指定账号发放及 390px 窄屏验收；恰好生成 1 条 pending 指令，page errors = 0，unexpected HTTP responses = 0；测试服务器和 Chrome 已关闭，临时凭据/状态/命令已清理。
- 浏览器截图：
  - `temp/codex-admin-20260814/browser-runs/run-sJ7iot/animals-desktop.png`，SHA-256 `92CDE206CF7A17009B48199155FAC51B9544D2D4DD98AB163A83EE090ED165AA`
  - `temp/codex-admin-20260814/browser-runs/run-sJ7iot/grant-desktop.png`，SHA-256 `D2FD43E8F4204124D8138C24A0DD83A469CA10A7A7634D2CCEC233EEF206B681`
  - `temp/codex-admin-20260814/browser-runs/run-sJ7iot/accounts-mobile.png`，SHA-256 `13F231CA9E3CE3153A96C5991557627D7FE35F4126A4738A0E853BA2F5A17FE7`
- DOCX 结构：A4、15 mm 页边距、19 个表格及 19 个重复表头、3 张 Figma PNG、5 个 Figma 外链、TOC、PAGE/NUMPAGES 字段通过；DOCX SHA-256 `DB709E0371218A8B223E14963591A127160ED8A16F3432C345760ED1754AE60F`。
- DOCX 视觉验收例外：本机无 LibreOffice，Microsoft Word 隐藏导出两次挂起，相关 Automation 进程已终止；因此本回执不把逐页 PNG 视觉验收标记为通过。
- 静态检查：Node / PowerShell / Python / Bash 语法、`git diff --check`、敏感口令与旧环境变量扫描通过。

## 安全决定

- 指定管理员名 `tian` 保留用于目标环境 Owner 初始化。
- 用户给出的 7 位数字口令不满足现有至少 12 位密码策略；没有降低策略，也没有把该口令写入仓库、文档、状态、日志或部署模板。
- 浏览器验收中的 `tian` 仅存在于已清理的临时状态，并使用运行时随机强口令。

## 阿里云阻断

`production/deployment/aliyun-profile.yaml` 的 producer、deployment owner、staging/production SSH alias、region、host role、OS、domains/ports、runtime/service/release paths、dependencies、TLS/reverse proxy、health、backup、rollback、monitoring 均为空；两环境 remote writes 均为 `false`。当前还没有可用 SSH config/agent baseline。

因此本次没有 SSH、上传、远端目录或账号写入、服务安装/重启、域名/TLS 变更、数据迁移或生产发布。远端继续前必须先补齐并批准 staging profile、提供 SSH agent/alias、打开 staging remote writes，并通过只读预检、备份和回滚门禁；生产仍需单独批准。
