# REQ-20260812 制作人组合交付完成回执

- 请求：`REQ-20260812-PRODUCER-CAMERA-MAP-ACCOUNT-APK`
- 状态：`COMPLETE`
- 完成日期：`2026-08-12`
- 执行者：`codex-primary`
- 正式规则：`docs/CURRENT_GAME_DESIGN.docx` 第 14 节；版本控制同步源为 `docs/CURRENT_GAME_DESIGN.md`

## 玩家可见结果

1. 所有轴向六边形战斗地图使用 `1.30` 默认镜头投影。六角格、建筑与动物按同一镜头关系放大，点击反算、拖动和世界坐标保持稳定，战斗速度、射程、寻路及服务器状态不变。
2. 除多人对战外，经典、单人和排位 AI 共用的 5 张 `1V1` 地图在生成后执行经典战线优化。双方各有 37 格领地，公共接壤边不少于 9 条，领地保持连通，至少保留 1 格中立地，新增战线格机会模板一致，到双方基地的距离差不超过 2。
3. 多人 `create_match()` 生成器未修改；相同地图、相同种子的多人生成结果保持不变。
4. 用户可以在账号中心使用用户名和密码注册、登录；错误密码被拒绝，用户名大小写不敏感，密码输入隐藏且长度上限为 72。密码登录成功后下发会话和刷新凭据，安装绑定可在重启后恢复账号和服务器档案，持久化数据不含明文密码。

## 行为与回归证据

- `tests/test_classic_frontier_rules.tscn`：5 张地图 × 50 个种子全部通过，输出 `CLASSIC_FRONTIER_RULES_TEST_PASS`。
- `tests/test_classic_battle_regression.tscn`：5 张经典地图回归通过。
- `tests/test_multiplayer_camera.tscn`：`1.30` 投影、六角格半径、动物画面、点击反算与拖动稳定性通过。
- `tests/test_account_password_login_loop.tscn`：注册、错误密码拒绝、登录、安装绑定、刷新凭据、档案保存、重启恢复、密码清理和通用错误文案通过。
- 既有账号回归：`test_player_account_store`、`test_account_manual_login_entry`、`test_saved_account_auto_login`、`test_device_account_credentials`、`test_online_room_gameplay_loopback`、`test_online_main_adapter` 全部通过。
- 公网只读协议探针：当前配置的 `106.15.61.103:24567` 对故意无效的认证请求返回预期错误，未创建账号或修改远端档案。
- GDScript 缩进检查：`tab 2` 通过。
- 配置检查：16 张表、387 行通过；运行时 JSON 已重新导出且无额外配置差异。
- 玩家画面证据：`output/qa/REQ-20260812-camera-map-account/camera_zoom_1080x1920.png`，尺寸 `1080×1920`。

## Android 交付

- 版本包：`build/android/JungleLaw-android-2026-08-12-camera-map-account-r2.apk`
- 最新包：`build/android/JungleLaw-android.apk`
- 大小：`50,820,440` 字节
- SHA-256：`FEA7331831DE69D47493550EFD5311AD176541B68814D385F269E2AAFCD24CFB`
- 包名：`com.blackking4210.junglelaw`
- 应用名：`丛林法则`
- 版本：`1.0.0`（versionCode `1`）
- 平台：`arm64-v8a`，minSdk 24，targetSdk 35
- 方向：Android manifest `screenOrientation=1`，固定竖屏
- 网络：包含 `android.permission.INTERNET`；当前阿里云主机配置已进入包内
- 签名：Android APK Signature Scheme v2/v3 验签通过，单一调试签名者；适合内部安装测试，不是商店生产签名
- 内容审计：`temp/tests/docs/knowledge/output` 内部文件进入 APK 的数量为 0；为此补充了 `export_presets.cfg` 的 `temp/` 排除规则并重新导出 r2

## 未覆盖边界

- 本机 `adb devices -l` 没有发现连接中的 Android 真机，因此本次没有宣称真机安装、启动、触控或真实账号成功登录已通过。
- `production/deployment/aliyun-profile.yaml` 缺少远程写入授权、目标、所有者、备份和回滚事实；本次未部署、重启或修改阿里云服务，也未创建真实远端账号。
- `project.godot` 与 `knowledge/*` 在任务开始前已有用户工作区修改，本次保留且不整文件纳入提交；手机包使用了当前工作区中已经存在的竖屏、品牌图和云端 endpoint 设置。

## 锁与清理

- 共享写锁 `camera_map_account_release_20260812` 已释放。
- 构建目录不纳入 Git；以本回执中的完整路径、大小和 SHA-256 作为产物身份。
