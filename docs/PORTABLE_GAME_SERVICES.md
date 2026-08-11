# 可移植游戏服务

## 目标

账户、编组、抽奖、房间和主页导航不再依赖当前的绘制代码。它们由 `scripts/foundation/` 下的纯数据服务提供，项目只保留一层 UI 适配：绘制控件、将点击转换为服务调用、展示服务返回的状态。

这套划分不改变本项目现有的页面坐标、交互、网络协议或存档字段。迁移到新项目时，复制 `scripts/foundation/`，接入对应的服务状态，即可用自己的 Godot Control、CanvasItem 或场景替换 UI。

## 模块与职责

| 模块 | 核心文件 | 不包含 | 项目适配点 |
| --- | --- | --- | --- |
| 账户 | `account/profile_adapter.gd`、`scripts/server/player_account_store.gd` | 登录表单、账户中心绘制 | `player_account_profile_adapter.gd` 定义资料清洗和摘要 |
| 编组 | `deck/deck_service.gd` | 卡牌详情、拖拽、按钮 | 卡牌列表、拥有数量、必带卡 ID |
| 抽奖 | `gacha/gacha_service.gd` | 翻牌动画、音效、卡面 | 奖池、稀有度概率、库存字段 |
| 房间 | `room/room_rules.gd` | 房间页面、ENet 传输、战斗 | 玩法人数、队伍布局、名称库 |
| 主页 | `ui/page_router.gd`、`ui/main_page_layout.gd` | 图标、美术、页面内容 | 页面 ID、导航项目、设计尺寸和语义矩形 |

## UI 适配契约

UI 层只应执行以下工作：

1. 将用户输入传给服务，并读取返回的 `ok`、`error` 和新状态。
2. 使用 `PageRouter` 决定当前页面，使用 `MainPageLayout` 取得按钮和容器的语义矩形。
3. 根据服务状态播放动画、音效和提示；这些表现不进入核心服务。
4. 网络层继续由 `OnlineRoom` 处理身份校验、RPC 和快照；`RoomRules` 只负责可复用的房间规则与校验。

核心服务不能 preload `main.gd`、贴图、音频、场景或项目 UI 脚本。

## 新项目接入

1. 复制 `scripts/foundation/` 到新项目。
2. 在项目启动处创建 `PageRouter` 和 `MainPageLayout`；注册页面 ID 后，把 UI 的点击交给路由。
3. 将玩家库存转换为 `DeckService` 与 `GachaService` 所需的 Dictionary/Array，渲染层只读取返回结果。
4. 为服务器创建或替换账户资料适配器；资料字段、排行文字和收藏计数都在适配器内定义。
5. 在服务器启动前用 `RoomRules.configure()` 写入房间人数和队伍布局（不配置时使用本项目的 1–3 人双边默认值）。

抽奖概率可直接传入 `{"common": 80.0, "legendary": 20.0}` 形式的 Dictionary，也可传入卡牌规则使用的 `[{"rarity": "common", "rate": 80.0}]` 形式的 Array；两种形式都按同一顺序和概率累计抽取。

## 兼容性与验证

- `scripts/network/room_protocol.gd` 是兼容薄层，现有 `RoomRegistry` 仍可不改调用方地使用通用房间规则。
- `scripts/app/main.gd` 已将主页导航、关键布局、抽奖抽取和编组校验调用到通用服务；其余代码只保留当前项目的绘制和玩法适配。
- `tests/test_portable_foundation.gd` 覆盖纯数据服务；原有账户与房间回归测试继续覆盖实际接入路径。
