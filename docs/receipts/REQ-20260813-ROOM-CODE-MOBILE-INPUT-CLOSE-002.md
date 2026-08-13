# REQ-20260813 房间码桌面与手机输入修复完成回执

- Request ID: `REQ-20260813-ROOM-CODE-MOBILE-INPUT`
- Feature ID: `F-ZC-NETWORK-001`
- Engineering status: `COMPLETE`
- Target-device acceptance: `PENDING_NO_CONNECTED_DEVICE`
- Date: `2026-08-13`
- Owner: `codex-primary`
- Task fingerprint: `FA4F37C79DE31D3C6B1E60B4732AA75E25D412C405E32C8B7AE39CD8A3B01C2C`
- Formal source: `docs/CURRENT_GAME_DESIGN.docx` and `docs/CURRENT_GAME_DESIGN.md`
- RAG task context: `temp/rag/context/REQ-20260813-ROOM-CODE-MOBILE-INPUT.md`

## 玩家可见结果

1. 互联网房间的房间码区域不再是只绘制的矩形，而是名为 `OnlineRoomCodeField` 的 Godot `LineEdit`。
2. 鼠标左键与 `InputEventScreenTouch` 在应用输入入口显式聚焦同一控件；控件自身继续处理光标、选择、粘贴与文字输入。
3. 控件启用 `virtual_keyboard_enabled`、`virtual_keyboard_show_on_focus`，键盘类型为 `KEYBOARD_TYPE_NUMBER`，供 Android 请求数字软键盘。
4. 房间码只保留前六位数字；控件文本、旧键盘兜底路径与 `online_room_join_code` 保持同步，避免双重输入。
5. 非六位提交不会发送加入请求并保持焦点；六位提交沿用现有 `join_room` 服务边界，随后释放焦点并调用 `DisplayServer.virtual_keyboard_hide()`。
6. 离开房间入口页、收到房间快照或进入其他页面时，控件会隐藏并释放焦点，不让软键盘残留。

运行时竖屏截图：`output/qa/REQ-20260813-room-code-mobile-input/room-code-input-focused.png`，`1080x1920`，SHA-256 `D506A9A2481A0274E7DB0B3AF3F9C594A7C77B91C66B24781792F01C6F7179CF`。

## 行为与回归证据

- `tests/test_online_room_code_input.tscn`: `PASS`
  - 真实 `LineEdit`、六位上限、可编辑和焦点模式；
  - Android 虚拟数字键盘属性；
  - 桌面鼠标输入入口和手机触摸输入入口；
  - 非数字/粘贴净化；
  - 非法提交留焦点、合法提交只调用一次房间服务并收起键盘；
  - 切页隐藏与释放焦点。
- `tests/test_online_main_adapter.tscn`: `PASS`
- `tests/test_online_room_gameplay_loopback.tscn`: `PASS`
- `tests/test_account_manual_login_entry.tscn`: `PASS`
- 正常入口十帧启动烟测：`PASS`
- `tools/check_gd_indentation.py`: `PASS (tab 2)`
- `tools/validate_config.py`: `PASS (16 tables, 387 rows)`
- `tools/export_config.py`: 当前运行时 JSON 导出成功。
- Godot 测试退出时仍会显示项目既有的 ObjectDB/resource 使用警告；四个测试均以退出码 `0` 和明确 PASS 文本结束，本修复没有引入解析、输入或联网断言失败。

## Android 交付

- 版本包：`build/android/JungleLaw-android-2026-08-13-room-code-mobile-input-r1.apk`
- 最新包：`build/android/JungleLaw-android.apk`
- 大小：`52,643,698` bytes
- SHA-256：`772A3AF7DAF0710803C772F0A2E97D75548A76820327C468E3A19E75B8781632`
- 包名：`com.blackking4210.junglelaw`
- 应用名：`丛林法则`
- 版本：`1.0.0` / versionCode `1`
- 平台：仅 `arm64-v8a`，minSdk `24`，targetSdk `35`
- 方向：manifest `screenOrientation=1`，并声明 portrait feature
- 网络：包含 `android.permission.INTERNET`
- 签名：调试签名；APK Signature Scheme v2/v3 验证通过，单一签名者
- 内容审计：`434` 个条目；`tests/docs/knowledge/output/temp/tmp/tools` 载荷计数 `0`；包含编译后的 `assets/scripts/app/main.gdc`
- 导出期间临时填写的本机调试密钥库路径已从 `export_presets.cfg` 恢复；该文件最终 SHA-256 与起始值一致。

## 未覆盖边界

- `adb devices -l` 返回空设备列表，因此没有执行实体 Android 手机上的安装、启动、点击和软键盘现场截图。
- 自动化已经覆盖真实 Godot 输入控件、`InputEventScreenTouch` 应用入口以及 Android 数字虚拟键盘请求配置，但这些证据不能冒充实体设备验收。
- 本任务未修改服务器、账号服务、网络协议或阿里云环境。

## 文件与清理

- `scripts/app/main.gd` 起始 SHA-256：`2476F8879DA197722AECD6BBBAEF49621FD6F8198BCB38FD6D0F12AB085E2AAC`
- `scripts/app/main.gd` 最终 SHA-256：`2E6E42CE53A0F72AC4B21643EFE1EF1CD4C6653B08F18215A7AE694AE79509FB`
- 新增专项测试：
  - `tests/test_online_room_code_input.gd`：`CF8F4107E7EF390E214B324CCEA2DA4068911F9EA40C3F39FFBF88515F771FD3`
  - `tests/test_online_room_code_input.tscn`：`010F6AA196FBE78DDADA3A5A202EFB069DDC91532028F1F737A63194BBF410B7`
- 已删除临时截图驱动和中间帧，只保留最终 QA 截图。
- 工作区中上一“群体增益升级”任务和用户拥有的其他未提交改动均被保留；本任务提交必须精确排除它们。
- Shared lock `room_code_mobile_input_20260813`: `RELEASED`
- Reusable method candidate: `none`
