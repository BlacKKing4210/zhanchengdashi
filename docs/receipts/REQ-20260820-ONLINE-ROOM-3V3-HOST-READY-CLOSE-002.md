# REQ-20260820-ONLINE-ROOM-3V3-HOST-READY-002 完成回执

- 状态：`LOCAL_IMPLEMENTATION_AND_ANDROID_PACKAGE_VERIFIED / ANDROID_DEVICE_PENDING`
- 完成时间：2026-08-20（Asia/Hong_Kong）
- 分支：`codex/animal-art-integration-20260811`
- 基线提交：`8b2161a6676a119899644928dffdf687e43dc343`
- 任务指纹：`33025EB05D63F9314AB99C87BB8B50BD71FD7C260E81ACB592A41505595570FA`
- 最终 RAG：`READY`；64 个来源、890 个分块、8 条请求引用；并行后台部署来源漂移后已重新准备并重建本任务上下文，最终索引签名 `163bebb8576f9e831db672ef6f466adfc6efc08deeeeac8b06e9123063e2ad0a`。

## 玩家可见结果

1. 互联网 3V3 房间中，房主始终按已准备状态显示；即使旧服务端快照仍返回房主 `ready=false`，房主槽位也使用绿色准备视觉，不再呈现未准备语义。
2. 六个有效槽位已占用且五名非房主真人都准备后，即使旧服务端仍返回 `can_start=false`，房主右侧“开始”按钮仍可点击。
3. 兼容路径在一次点击中按可靠有序控制通道先发送一次 `set_ready(true)`，随后立即发送一次 `start_room()`；当前新服务端已返回房主准备时不会发送多余准备请求。
4. 任一有效槽位为空或任一客人未准备时，“开始”保持不可用；客户端兼容逻辑不能绕过服务端最终开局校验。
5. 房间底部仍只有左侧“离开房间”和右侧“开始”；旧截图中的独立等待面板不再出现。

## 关键产物 SHA-256

| 产物 | SHA-256 |
|---|---|
| `docs/INTERNET_ROOM_NETWORKING.md` | `C0B86226AF81DA3D9AD286F97B7E3EC6BDB9E72FF70881702C3D606F8C8A684D` |
| `scripts/app/main.gd` | `D9A6347B02206500AF1920E0471FC4CCCBE61B3F32CC659CAF4FE392F2E39D02` |
| `tests/test_online_main_adapter.gd` | `831273053D218AE3243581D533BE066AABA44F3A1F725771B9F8AC15F9038854` |
| `output/qa/REQ-20260820-online-room-3v3-host-ready/host-ready-legacy-server.png` | `2775FDED888C2165E451EC044A61B6950B3C5F33360F19515CCEC17F53FF4F20` |
| `build/android/JungleLaw-android-2026-08-20-3v3-host-ready-r1.apk` | `75DF2A2CDCFCCB77EC60129F7D4212B57F065962FE1566453BCCC8C64DBB31B3` |

## 行为与回归验收

| 门禁 | 结果 |
|---|---|
| GDScript 缩进检查 | PASS，tab 2 |
| `git diff --check` | PASS |
| 主流程适配 | PASS；旧 3V3 快照的空位、客人未准备、五客人全准备、房主显示准备、ready-first/start-second 顺序均覆盖 |
| 当前服务端路径 | PASS；房主已准备时只发送 `start_room()`，不发送冗余准备请求 |
| 房间注册表 | PASS |
| 房间码输入 | PASS |
| 真实 ENet 回环 | PASS |
| 主流程战斗回环 | PASS |
| 六真人 3V3 回环 | PASS |
| 房主离开与 AI 接管 | PASS |
| 720×1280 图形运行截图 | PASS；房主槽位绿色、五名客人已准备、“开始”橙色可点击、无独立等待面板 |

Godot 在隔离环境中仍打印 Windows 根证书读取失败、测试退出时 ObjectDB/资源清理警告；所有目标测试场景退出码均为 0。编辑器解析时另有既存运行编辑器导致的项目元数据保存失败，这不影响目标脚本解析与上述独立测试。

## Android APK 验收

- 唯一新包：`build/android/JungleLaw-android-2026-08-20-3v3-host-ready-r1.apk`
- 构建时间：2026-08-20 21:57:04（Asia/Hong_Kong）
- 大小：50,886,581 字节
- 包名：`com.blackking4210.junglelaw`
- 应用名：`丛林法则`
- 版本：`versionName 1.0.0 / versionCode 1`
- 平台：`arm64-v8a`，`minSdk 24`，`targetSdk 35`
- ZIP 完整性：PASS，430 个条目，包含 AndroidManifest、arm64 Godot 库与 Godot PCK
- 4 字节对齐：PASS
- 签名：PASS，APK Signature Scheme v2/v3；证书 SHA-256 `BA0AE26C9BFE6E0F28A2ECB9C1464F626F57023D39622051D229A0A7620E926C`
- 升级兼容：与 2026-08-15 内测 APK 的包名和签名证书一致；本包仍为 Godot 内测签名，不是商店生产签名。
- 配置：现场 `runtime/config/global.json` 被正在运行的 Godot 4.6.3 编辑器占用；没有关闭用户编辑器。隔离打包副本重新验证 16 表/387 行并导出 17 个运行时 JSON，全部与现场文件 SHA-256 一致后才导出 APK。
- 设备验收：当前 `adb devices -l` 无连接设备，因此未执行安装、覆盖升级和手机真人公网点击；此项保持 `PENDING`，不得用静态包检查代替。

`aapt2 dump badging` 仍报告既有 `themed_icon.xml` 资源警告，但包导出、对齐、签名和清单解析均通过；该警告不属于本次房间逻辑改动。

## 边界与清理

- 未部署、重启或修改阿里云公网服务端；兼容修复完全位于新客户端。
- 未触碰并行后台部署任务持有的 `docs/active_scope.yaml`、`knowledge/knowledge_manifest.csv`、部署配置和后台代码。
- 隔离打包副本、截图驱动、测试用户目录、日志、缓存与临时校验脚本已删除；正式截图和唯一命名 APK 保留。
- 本次是项目专用旧服务端准备握手兼容，不形成新的通用 Skill 候选：`reusable_method_candidate: none`。
