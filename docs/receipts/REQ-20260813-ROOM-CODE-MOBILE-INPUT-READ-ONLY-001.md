# REQ-20260813 房间码桌面与手机输入修复只读回执

- Request ID: `REQ-20260813-ROOM-CODE-MOBILE-INPUT`
- Feature ID: `F-ZC-NETWORK-001`
- Date: `2026-08-13`
- Producer authority: 当前用户指令“继续”，延续“点击后可输入且手机可输入”的修复要求
- Owner / unique writer: `codex-primary`
- Project root: `D:\AI\zhanchengdashi`
- Branch: `codex/animal-art-integration-20260811`
- Engine: Godot `4.6.2.stable`
- RAG gate: `READY`，index signature `9c361ebfff68dfd26ddc8959286ca4bdab5925564d6f4069e5732130e11ba69f`
- RAG task receipt: `temp/rag/receipts/tasks/REQ-20260813-ROOM-CODE-MOBILE-INPUT.json`
- Control plane: `READY / L3`
- Task fingerprint: `FA4F37C79DE31D3C6B1E60B4732AA75E25D412C405E32C8B7AE39CD8A3B01C2C`
- Previous conflicting lock: `REQ-20260813-GROUP-BUFF-UPGRADE-R2` is `COMPLETE / RELEASED`

## 正式来源与已确认根因

- `docs/CURRENT_GAME_DESIGN.docx` 与 `docs/CURRENT_GAME_DESIGN.md` 已规定互联网房间、六位房间码、触控输入和现有页面行为；本任务是缺陷修复，不新增产品规则。
- 当前 `scripts/app/main.gd` 的房间码区域仅通过 `_box()`、文字绘制与 `_unhandled_input()` 实体键盘事件维护字符串。
- 点击该区域只播放音效，没有可聚焦的 Godot `LineEdit`，因此桌面点击不能进入文本输入状态，Android 也不会通过控件请求数字软键盘。

## 写入范围

- `docs/active_scope.yaml`
- `docs/receipts/REQ-20260813-ROOM-CODE-MOBILE-INPUT-READ-ONLY-001.md`
- `docs/receipts/REQ-20260813-ROOM-CODE-MOBILE-INPUT-CLOSE-002.md`
- `scripts/app/main.gd`
- `tests/test_online_room_code_input.gd`
- `tests/test_online_room_code_input.tscn`
- 必要时窄改 `tests/test_online_main_adapter.gd`
- Android 构建输出位于 `build/android/`，不进入 Git 提交

不修改服务器、账号服务、在线传输协议、平衡配置、当前游戏设计正文、其他任务文件或阿里云环境。

## 起始基线

- `scripts/app/main.gd`: `2476F8879DA197722AECD6BBBAEF49621FD6F8198BCB38FD6D0F12AB085E2AAC`
- `tests/test_online_main_adapter.gd`: `B06CE20168D69D424E19109900AE328BEE629CFB33E312F6A27067887AD0561E`
- `project.godot`: `0989903F628863D30A61F449419A0646FB08B50F967BA068866959DC9EC46B92`
- `export_presets.cfg`: `4E9FDDB2B293479CA5C9DCA289D1CE1569928620B381F1688A1A56E0A2A5BA08`
- 工作区存在上一已完成任务及用户拥有的未提交改动；本任务必须保留并在提交时排除这些改动。

## 验收与证据

1. 房间码区域使用真实 `LineEdit`，鼠标点击和 `InputEventScreenTouch` 都能获得焦点。
2. 控件启用 Android 虚拟键盘并指定数字键盘类型；只保留最多六位数字，粘贴和非数字输入也被净化。
3. 回车或点击“加入房间”沿用现有加入逻辑；非法长度不发送请求，合法提交后释放焦点并收起键盘。
4. 离开房间页、进入房间或打开遮罩界面时隐藏控件并释放焦点。
5. Godot 解析、缩进检查、专项输入测试、在线房间适配回归和账号输入回归通过。
6. 新 Android APK 保持竖屏、包含 INTERNET 权限、签名有效，并不携带测试/RAG/文档内容。
7. 若无连接的 Android 设备，必须把真机软键盘验收明确标记为未执行，不能以自动测试替代。

## 清理与关闭

- 删除任务临时驱动、临时日志和未作为证据保留的截图。
- 完成回执映射验收证据，刷新 RAG，释放共享写锁。
- 可复用方法候选在完成后单独评估；未经制作人确认不修改全局 Skill 或流程。
