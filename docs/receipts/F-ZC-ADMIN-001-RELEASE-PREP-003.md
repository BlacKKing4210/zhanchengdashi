# F-ZC-ADMIN-001 本地发布准备回执

- Request ID：`REQ-20260814-ADMIN-ANALYTICS-RESOURCE-GRANTS`
- Feature ID：`F-ZC-ADMIN-001`
- 版本：`v1.1.2-local-bundle-rc2`
- 日期：`2026-08-14`
- Owner：`codex-primary`
- 执行级别：`L2`
- 当前状态：`LOCAL NODE + LINUX ARTIFACTS VERIFIED / ALIYUN NOT READY`
- 远程写入：`NOT AUTHORIZED / NOT EXECUTED`

## 已登记写集

- `tools/admin_dashboard/**`
- `tests/admin_dashboard/dashboard.test.mjs`
- `tools/package_admin_dashboard.ps1`
- `deploy/linux/*admin-dashboard*`
- `deploy/linux/junglelaw-server.service`
- `deploy/linux/junglelaw-server-stop.sh`
- `deploy/linux/install_junglelaw_server.sh`
- `deploy/linux/test_junglelaw_server_deploy.sh`
- `deploy/linux/test_junglelaw_server_stop.py`
- `deploy/linux/ADMIN_DASHBOARD_DEPLOYMENT.md`
- `scripts/server/player_account_store.gd`
- `scripts/server/player_account_lifecycle_lock.gd`
- `scripts/server/dedicated_shutdown_control.gd`
- `scripts/server/server_main.gd`
- `scripts/network/online_room.gd`
- `tests/test_admin_backend_features.gd`
- `tests/test_dedicated_shutdown_control.gd`
- `tests/test_player_account_store.gd`
- `tests/test_account_password_login_loop.gd`
- `docs/ADMIN_ANALYTICS_DASHBOARD_DESIGN.md`
- `docs/ADMIN_ANALYTICS_DASHBOARD_DESIGN.docx`
- `output/visual_concepts/admin_dashboard_v1_1_2_*.png`
- `build/admin-dashboard/JungleLaw-admin-dashboard-v1.1.2-local-runtime-only-rc1.zip`
- `build/admin-dashboard/JungleLaw-admin-dashboard-v1.1.2-local-runtime-only-rc1.manifest.json`
- `build/linux/candidates/v1.1.2-local-linux-rc2/**`
- 本回执

## 本地 Node 制品

- ZIP：`build/admin-dashboard/JungleLaw-admin-dashboard-v1.1.2-local-runtime-only-rc1.zip`
- ZIP 字节数：`60023`
- ZIP SHA-256：`552024C87C70FB167CAD590C812698E952D1CE68DEBDA3585C144B572F4A2D92`
- Manifest：`build/admin-dashboard/JungleLaw-admin-dashboard-v1.1.2-local-runtime-only-rc1.manifest.json`
- Manifest 字节数：`7866`
- Manifest SHA-256：`98D16DDDFA8BCFF5687DA1F377104A61BA3619A7AAEA06A25ADF0A21C8730FAF`
- 组件版本：`1.1.2`
- 归档条目：`16`
- 状态：`local_release_candidate_not_deployed`

这是 runtime-only 候选，固定白名单仅包含 Node 后台运行时与 Linux 部署模板。它不包含测试、README、后台认证/会话/审计状态、玩家权威账号库、统计或账号快照、资源命令队列、TLS 证书/私钥、真实环境文件、`node_modules` 或游戏服二进制。旧 v1.1.0 本地候选保留作历史证据，但已被本候选取代，禁止用于本次部署。

## 验证结果

- 打包前 Node 测试：`13/13 PASS`。
- 解压候选后所有 `.mjs` / `.js`：`node --check 8/8 PASS`。
- 解压入口 `server.mjs --help`：`PASS`。
- ZIP 与 manifest 条目：`16/16`；逐文件字节数与 SHA-256：`16/16 PASS`。
- 禁入路径：`0`；manifest 的制品哈希与 ZIP：一致。
- 隔离目录重复打包：ZIP SHA-256 完全相同，字节级可重复。
- 用户提供的后台账号名、原始数字口令、私钥头和常见阿里云访问密钥模式扫描：`0` 命中。
- 本地复验临时目录已做边界校验并清理。

runtime-only ZIP 不含测试；因此远端 release 验证只允许执行 `node --check`、`server.mjs --help`、manifest/哈希检查与健康检查。完整 `13/13` 测试证据绑定在打包前本地源码，不得在远端把缺少测试目录解释为测试失败或伪称包内测试通过。

## 本地 Linux 专服候选

- 目录：`build/linux/candidates/v1.1.2-local-linux-rc2`
- ELF：`JungleLawServer.x86_64`
- ELF 字节数：`95477656`
- ELF SHA-256：`50E07B1EE533229ABAFF327333EE4DE2BE88DDE93761A1BE2F707A048B27608D`
- 确定性归档：`build/linux/JungleLawServer-v1.1.2-local-linux-rc2.tar.gz`，`51171538` 字节，SHA-256 `875F0D5CA3148CB07592C84AE0D1E743F0053457481F9EE3B3496CF660E97037`
- 归档 sidecar：`JungleLawServer-v1.1.2-local-linux-rc2.tar.gz.sha256`，`112` 字节，SHA-256 `3A0DD76F50D429AF6422CB929BB91BCE097A69A3EC9FD01FCA2FECD4A045B5BB`
- 隔离重复打包：两个 tar.gz 字节完全一致；最终归档 `86` 个条目、无绝对路径或 `..` 路径，包含 ELF、manifest 与 provenance；owner/group 固定为 `0/0`，目录、ELF 与获准脚本为 `0755`，其余普通文件为 `0644`，gzip 时间戳与源文件名已清零。
- Manifest：`manifest.json`，`9148` 字节，SHA-256 `CC53D99AD72B9B1326BBA3B70BB3C1C32818AE9D0C1030EAC492B6310800E3C1`
- Provenance：`PROVENANCE.md`，`7359` 字节，SHA-256 `6D17872808FB1087BDA030DAD0119C4A1E6F07A603ABC0DDF862507CCAC2EE84`
- 状态：`LOCAL ARTIFACT VERIFIED / NOT DEPLOYED`
- 配套 Node 候选：上一节 runtime-only ZIP；两个制品共同构成本次后台与专服的本地部署输入。

本候选由记录的 Git commit 与六个明确哈希的 analytics/authority/shutdown runtime 源文件在隔离树中导出，未混入 cards、project、UI 等无关脏改动。Godot `4.6.2.stable.official.71f334935` 导出日志以 `[ DONE ] savepack` 结束，脚本/解析/断言/硬错误命中为 `0`。首个 `v1.1.2-local-linux-rc1` 因 raw SIGTERM 后遗留 lifecycle lock 且无法同数据重启，已明确 `SUPERSEDED / DO NOT DEPLOY`；RC2 增加同步应用层停服桥，未覆盖或删除该失败证据。

RC2 验证时间线：

1. `local-validation-20260814T174100`：`FAILED_EXCLUDED`。验收器把 `[::ffff:127.0.0.1]` 的 IPv4 映射回环显示误判为非回环；失败后进程、端口和临时根清理通过。
2. `local-validation-20260814T174657`：`FAILED_EXCLUDED`。核心矩阵已完成，但最终 `pgrep -f` 自匹配了包含候选路径的 verifier 命令行；该轮不计 PASS，失败后清理通过。
3. `local-validation-20260814T174948`：`PASS`。最终验收按 `/proc/<pid>/exe` 与 ELF 真实路径精确比对，并继续拒绝 wildcard/非回环监听。

最终接受轮验证：

- 三次同步 helper stop / 同数据 restart，helper 与进程均退出 `0`；三轮 authority SHA-256 固定为 `010c5999d66176f1ac86d1a151430609a829025007d3923209e5d02c7ab537de`。
- malformed、wrong-token、stale-pid 请求均被拒绝并保留，服务未误停。
- raw SIGTERM 退出 `143`，按合同保留 lifecycle lock 与 control session 并在下次启动 fail closed；它不是正常停服路径。
- 损坏 authority 与预存 residual lifecycle lock 均退出 `19` 且不监听 UDP。
- 最终 cleanup：候选进程 `0`、测试端口 `0`、WSL `/tmp/junglelaw-server-candidate.*` `0`；项目默认 authority/control lock `0`。
- pre-export 与 final deploy static 均 PASS；stop helper 故障矩阵 `9/9 PASS`。

账号权威/停机代码独立组合终审未发现 P0/P1。根代理最终复跑 Node `13/13 PASS`、Godot 4.6.2 十一个无头场景全部 `exit 0` 且无 SCRIPT/Parse/TEST_FAIL、GDScript `tab 2 PASS`；隔离 APPDATA 已清理。

## RAG 门禁

- 状态：`READY`
- 正式来源：`62`
- 分块：`848`
- Golden queries：`16/16 PASS`
- Mean recall@k / pass rate：`1.0 / 1.0`
- Index signature：`867740e08740c4b51fb74935549d6d33db2d07f71736641a9ab61baa12746c91`
- Gate receipt：`temp/rag/receipts/rag-gate.json`，`27618` 字节，SHA-256 `7B1E5757372795C08C1B286866EFFD65A34230A360501387B7A8BD94C081FBB6`
- 后台 task receipt：`REQ-20260814-ADMIN-ANALYTICS-RESOURCE-GRANTS`，`READY`，`5887` 字节，SHA-256 `FEFF51308252F1A249518A93D094010550EF16B1567B36493BFC313797854336`；context SHA-256 `C7FBA47256D0434B925F8DD2A408DCD6CE4EAAE6BF8D04CBE340475CED03774A`。
- RC2 task receipt：`REQ-20260814-ADMIN-LINUX-V1.1.2-RC2`，`READY`，`6517` 字节，SHA-256 `002C05B1CB2A689C8CE89E30A2401153D04D47B60837592D6AA843FF1C430E9C`；context SHA-256 `F355059EE76BED638B7D95C727FE6E97618A1D36A0DAD77B28AA7822D094C7DA`。
- 候选导出后，正式 active scope 新增了无关任务 `auto_account_250_health_rule_20260814` 的 `HELD` 共享锁，并覆盖 `online_room.gd` 与 `player_account_store.gd`。本次未在该锁之后修改这些 runtime 源；候选继续绑定 manifest 中的明确源哈希，仅刷新了当前 scope 下的 RAG 证据元数据。

## 视觉与文档证据

- 参考页仅用于提炼深蓝黑、暖金、紧凑导航、左侧动物索引与右侧排名表密度；未复制第三方品牌、图标、素材、源码或固定宽移动画布。
- 浏览器断言：1440 桌面表头 `42px`、排名行 `56px`；1440/1024/768/390/667×375 均无页面级横向溢出；390 导航只在组件内部滚动，触控目标不小于 `44px`。
- Owner 资源发放只走到预览：密码重新认证、`SEND` 二次确认、幂等键和红色不可撤销按钮均存在；未提交命令。
- 管理员危险操作确认框初始焦点在“取消”，取消后焦点返回触发按钮。
- `output/visual_concepts/admin_dashboard_v1_1_2_animals_1440.png`：SHA-256 `EAA1F528ECDBC6AAFBF0B5D71CDB39980FC5B2056D14DC6BB8915E7556A35A31`。
- `output/visual_concepts/admin_dashboard_v1_1_2_animals_390.png`：SHA-256 `F43EEB531B057AF2AC0BB5A473EC99028FE84C6D9C9A880B9CB2E54053A5FFE7`。
- `output/visual_concepts/admin_dashboard_v1_1_2_resource_grant_preview_1440.png`：SHA-256 `876366996AEDD699EAF606380C705238D079D90699955AE9F56F091E81CB14E4`。
- 正式 DOCX SHA-256：`F4737FD8E31F49074BAD7BD43FD87C4628B923ED51BFCB3075035EF2312AF11F`；`395835` 字节；A4、15 mm 四边距、22 个表格/22 个重复表头、3 张嵌图/3 个替代说明、5 个外链、TOC、PAGE/NUMPAGES 字段和更新字段结构检查通过。
- 本机无 LibreOffice/Word 可执行程序；标准 `render_docx.py` 本轮因转换程序缺失退出 1，临时渲染目录已清理。因此 DOCX 只声称结构验证通过，不声称页面 PNG 视觉渲染通过。
- Figma v1.1 页面 10:33 与三张旧核心画板仍为可编辑基线；v1.1.2 同步在 2026-08-14 被 Starter 套餐 MCP 调用上限阻断，正式文档已标记 `PENDING`，不以本地 PNG 冒充可编辑 Figma 源。

## 来源与发布边界

- 来源 Git commit：`8b52782ab862a6e901df96c4c1f2d9a5c7bed435`
- 来源分支：`codex/animal-art-integration-20260811`
- 来源工作树：`DIRTY`

Node 制品来自脏工作树；Linux RC2 来自隔离 Git-archive + 明确哈希 runtime overlay。两者都不是可由单一 commit 重现的生产候选。工作树同时包含与本功能无关的用户改动，因此没有自动 stage、commit 或 push；RC2 隔离源在证据复制、manifest 校验后已按精确边界清理。

Node ZIP 不能独立形成完整闭环；它必须与 RC2 专服候选共同使用。账号权威存储、v2→v3 无损迁移、生命周期单写者、资源命令幂等/CAS、同步停服与结果歧义故障路径均已完成本地实现和独立回归。旧 Linux overlay3 与 RC1 均明确为 `SUPERSEDED / DO NOT DEPLOY`。本地验证仍不能替代阿里云 staging 的真实 systemd 239、持久化、外部 HTTPS、资源到账和回滚验收。

## Aliyun 门禁

- staging 只读基线已登记：cn-shanghai 的共享 SWAS 主机、现有游戏服路径、Node/nginx/systemd 与 24 账号 v2 权威文件形态已核对。
- 现有 authority 为 v2：24 个账号/资料、21 个非空保存阵容、13 个 installation、0 个资源命令回执；历史 placement samples 为 0，因此不能追溯生成旧对局平均名次，只有升级后的未来比赛会逐步形成真实排名样本。
- 仍缺：producer/deployment owner、正式 SSH alias 与安全凭据通道、是否批准复用共享主机、后台 service/release 路径、域名/TLS、后台健康检查、可用备份槽位或经批准的服务器内备份/回滚方案、监控告警 owner、维护窗口和 staging 写入授权。
- staging 与 production 的 `remote_writes` 均为 `false`；production 仍未配置。
- 本次没有上传、安装、重启、改防火墙、创建账号/服务、删除快照或执行任何远端写入。

## 凭据状态

目标 Owner 必须在获准的阿里云环境中交互式初始化。用户原始数字口令不满足当前至少 12 位的密码策略；本次没有降低策略，也没有把账号、口令或其哈希写入源码、制品、manifest、部署模板、状态、日志或命令行。

结论：v1.1.2 Node 后台候选、浏览器视觉实现、正式 DOCX、账号权威与资源命令实现、同步停服部署合同及匹配的 Linux RC2 候选均已完成本地可验证门禁。仍未完成的是 Figma v1.1.2 可编辑同步、Aliyun staging 部署、真实外部 HTTPS 登录、资源发放到账、systemd 239 停服/重启持久化与回滚。状态保持 `NOT READY: Aliyun deployment profile / staging write authorization`。
