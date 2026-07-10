# 当前页面 1930s 手绘动画美术方案

生成日期：2026-07-10

本轮忽略之前的设计，从当前正在使用的主页面和战场页出发，只做设计评审图，不应用到游戏里。

风格学习范围：转译 1930s 橡皮管动画、手绘赛璐璐、胶片颗粒、复古海报印刷与墨线质感；不复制茶杯头角色、Logo、专有造型、关卡或 UI。

## 硬性要求

- 主页面和战场都生成独立背景底图。
- 当前页面信息、布局、控件位置、点击区域和点击反馈不变。
- 效果图只展示美术升级方向，不进入 Godot 实装。

## 方案总览

| 方案 | 名称 | 视觉句子 | 定位 | 主页面背景 | 战场背景 | 总览图 |
| --- | --- | --- | --- | --- | --- | --- |
| A | 经典赛璐璐 | 暖纸胶片森林 + 黑墨线 UI + 金色 CTA。 | 最接近 1930s 手绘动画短片的原创转译，画面高级、复古、克制。 | `output/visual_concepts/current_game_1930s_v4_a_classic_cel_lobby_background.png` | `output/visual_concepts/current_game_1930s_v4_a_classic_cel_battle_background.png` | `output/visual_concepts/current_game_1930s_v4_a_classic_cel_sheet.png` |
| B | 游园海报 | 亮盒彩印游园 + 红蓝错版边 + 剧场感棋盘。 | 更明亮、更漂亮、更适合商业化主界面，仍保持手绘墨线和复古动画气质。 | `output/visual_concepts/current_game_1930s_v4_b_fairground_poster_lobby_background.png` | `output/visual_concepts/current_game_1930s_v4_b_fairground_poster_battle_background.png` | `output/visual_concepts/current_game_1930s_v4_b_fairground_poster_sheet.png` |
| C | 轻欢游园背景版 | 阳光游园入口 + 手绘墨线 + 明亮复古 CTA。 | 主页面背景气氛成立，但 UI 仍混有旧按钮体系，暂不作为最终主推。 | `output/visual_concepts/current_game_1930s_v5_c_cheerful_fair_lobby_background.png` | 暂不生成 | `output/visual_concepts/current_game_1930s_v5_c_cheerful_fair_lobby_mockup.png` |
| D | 全套手绘主页面 | 票券资源条 + 舞台海报框 + 椭圆匹配按钮 + 剪纸票券导航。 | 针对反馈重做整套主页面 UI，动物图暂时保留项目原图不改。 | `output/visual_concepts/current_game_1930s_v6_d_full_rubberhose_lobby_background.png` | 暂不生成 | `output/visual_concepts/current_game_1930s_v6_d_full_rubberhose_lobby_mockup.png` |
| E | AI 手绘信息完整版 | AI 手绘整套 UI 底稿 + 完整页面信息 + 原项目动物 PNG 合成。 | 当前最接近目标的主页面效果图：不是空白皮肤稿，也不是简单几何按钮，而是带真实信息的完整页面。 | `output/visual_concepts/current_game_1930s_v8_f_ai_painted_info_ui_background.png` | 暂不生成 | `output/visual_concepts/current_game_1930s_v8_f_ai_painted_info_ui_lobby_mockup.png` |
| F | 干净信息主页面 | 去掉图标旁冗余文字，保留并放大必要信息。 | 当前主页面推荐版，已按标注删除金币/券等冗余标签，保留信息更清楚。 | `output/visual_concepts/current_game_1930s_v9_g_ai_painted_clean_info_ui_background.png` | 暂不生成 | `output/visual_concepts/current_game_1930s_v9_g_ai_painted_clean_info_ui_lobby_mockup.png` |

## 方案 A：经典赛璐璐

![方案 A：经典赛璐璐](../output/visual_concepts/current_game_1930s_v4_a_classic_cel_sheet.png)

- 视觉句子：暖纸胶片森林 + 黑墨线 UI + 金色 CTA。
- 定位：最接近 1930s 手绘动画短片的原创转译，画面高级、复古、克制。
- 适合：想要更强艺术辨识度，同时保持当前页面信息完全不变。
- 风险：色彩较克制，后续需要用按钮高光和地块描边保护奖励感。
- 主页面背景底图：`output/visual_concepts/current_game_1930s_v4_a_classic_cel_lobby_background.png`
- 战场背景底图：`output/visual_concepts/current_game_1930s_v4_a_classic_cel_battle_background.png`
- 主页面效果图：`output/visual_concepts/current_game_1930s_v4_a_classic_cel_lobby_mockup.png`
- 战场效果图：`output/visual_concepts/current_game_1930s_v4_a_classic_cel_battle_mockup.png`

## 方案 B：游园海报

![方案 B：游园海报](../output/visual_concepts/current_game_1930s_v4_b_fairground_poster_sheet.png)

- 视觉句子：亮盒彩印游园 + 红蓝错版边 + 剧场感棋盘。
- 定位：更明亮、更漂亮、更适合商业化主界面，仍保持手绘墨线和复古动画气质。
- 适合：想要更美观、更有奖励感，后续方便接活动、赛季和礼包包装。
- 风险：装饰更强，落地时要控制饱和度，不让背景抢棋盘和资源条。
- 主页面背景底图：`output/visual_concepts/current_game_1930s_v4_b_fairground_poster_lobby_background.png`
- 战场背景底图：`output/visual_concepts/current_game_1930s_v4_b_fairground_poster_battle_background.png`
- 主页面效果图：`output/visual_concepts/current_game_1930s_v4_b_fairground_poster_lobby_mockup.png`
- 战场效果图：`output/visual_concepts/current_game_1930s_v4_b_fairground_poster_battle_mockup.png`

## 方案 C：轻欢游园背景版

![方案 C：轻欢游园主页面](../output/visual_concepts/current_game_1930s_v5_c_cheerful_fair_lobby_mockup.png)

- 视觉句子：阳光游园入口 + 手绘墨线 + 明亮复古 CTA。
- 定位：按“学习 2D 茶杯头的轻松欢快气质”进行原创转译，只借鉴 1930s 橡皮管动画、手绘墨线、水彩纸感和胶片颗粒，不复制茶杯头角色、Logo、专有造型、关卡或 UI。
- 适合：想要主页面更可爱、更明亮、更容易建立亲和力，同时仍保持当前主页面 UE。
- 风险：这一版主要解决了背景和气氛，资源条、按钮、段位板、底部导航仍和旧方案不够统一，因此不作为当前主推。
- 本轮范围：只生成主页面效果图，不生成战场图，不进入 Godot 实装。
- AI 背景源图：`output/visual_concepts/current_game_1930s_v5_c_cheerful_fair_lobby_bg_source.png`
- 主页面背景底图：`output/visual_concepts/current_game_1930s_v5_c_cheerful_fair_lobby_background.png`
- 主页面效果图：`output/visual_concepts/current_game_1930s_v5_c_cheerful_fair_lobby_mockup.png`

## 方案 D：全套手绘主页面

![方案 D：全套手绘主页面](../output/visual_concepts/current_game_1930s_v6_d_full_rubberhose_lobby_mockup.png)

- 视觉句子：票券资源条 + 舞台海报框 + 椭圆匹配按钮 + 剪纸票券导航。
- 定位：针对“不要只换背景、不要沿用旧按钮”的反馈重做整套主页面效果图；所有 UI 面板、按钮、导航、标题和主场景框都改为原创 1930s 手绘动画转译。
- 动物约束：暂时不改动物图片，中央展示区继续使用项目现有动物 PNG，只调整承载舞台、阴影和排布效果图。
- 适合：作为下一轮主页面视觉确认的优先候选；如果确认 OK，再继续设计战场页或拆分 UI 组件。
- 风险：动物图与复古 UI 仍存在风格差异，这是本轮按“先不改动物图片”的结果；后续若确认整体方向，再单独处理动物族群美术统一。
- 本轮范围：只生成主页面效果图，不生成战场图，不进入 Godot 实装。
- 主页面背景底图：`output/visual_concepts/current_game_1930s_v6_d_full_rubberhose_lobby_background.png`
- 主页面效果图：`output/visual_concepts/current_game_1930s_v6_d_full_rubberhose_lobby_mockup.png`

## 方案 E：AI 手绘信息完整版

![方案 E：AI 手绘信息完整版](../output/visual_concepts/current_game_1930s_v8_f_ai_painted_info_ui_lobby_mockup.png)

- 视觉句子：AI 手绘整套 UI 底稿 + 完整页面信息 + 原项目动物 PNG 合成。
- 定位：针对“要带信息的完整 UI 页面”的反馈制作。资源条、标题牌、中央舞台框、段位条、匹配按钮、底部导航图标都来自同一张 AI 手绘复古 UI 底稿，不再使用程序简单几何按钮。
- 信息完整度：包含金币、招募券、主标题、玩法副标、当前阵容、总战力、段位胜负、段位赛、首胜奖励、匹配预计时间、底部入口与入口状态。
- 动物约束：暂时不改动物图片，中央舞台中的动物继续使用项目现有 PNG，只做合成定位。
- 适合：作为当前主页面风格确认的优先候选；确认 OK 后，再继续做战场页同风格效果图或拆分 UI 组件状态。
- 风险：动物图仍与 1930s 手绘 UI 存在风格差异，这是本轮按“暂时不要改动物图片”的结果；后续若确认整体页面方向，再单独处理动物统一。
- 本轮范围：只生成主页面效果图，不生成战场图，不进入 Godot 实装。
- AI 手绘底稿：`output/visual_concepts/current_game_1930s_v7_e_ai_painted_full_ui_base_with_icons.png`
- 主页面背景底图：`output/visual_concepts/current_game_1930s_v8_f_ai_painted_info_ui_background.png`
- 主页面效果图：`output/visual_concepts/current_game_1930s_v8_f_ai_painted_info_ui_lobby_mockup.png`

## 方案 F：干净信息主页面

![方案 F：干净信息主页面](../output/visual_concepts/current_game_1930s_v9_g_ai_painted_clean_info_ui_lobby_mockup.png)

- 视觉句子：图标表达资源类型 + 必要文字信息清晰保留。
- 定位：针对标注反馈清理主页面信息层。金币、招募券等已有图标表达的文字被删除，只保留数值；玩法副标、首胜奖励、底部小状态等冗余小字被删除。
- 保留信息：资源数值、主标题、阵容数量、战力、段位胜负、匹配按钮、底部主入口名。
- 动物约束：仍不改动物图片，只使用项目现有动物 PNG 合成。
- 当前建议：主页面以 F 作为评审基准，后续页面套件按 F 的信息密度执行。
- 主页面背景底图：`output/visual_concepts/current_game_1930s_v9_g_ai_painted_clean_info_ui_background.png`
- 主页面效果图：`output/visual_concepts/current_game_1930s_v9_g_ai_painted_clean_info_ui_lobby_mockup.png`

## 页面套件 v10

![页面套件 v10 总览](../output/visual_concepts/current_game_1930s_v10_h_page_set_overview.png)

本轮按“AI 手绘底稿/组件 + 清晰中文信息叠层 + 不改动物图片”的流程，继续制作其他页面效果图。所有页面仍然只是视觉评审图，不进入 Godot 实装。

| 页面 | 文件 | 制作说明 |
| --- | --- | --- |
| 主页面 | `output/visual_concepts/current_game_1930s_v9_g_ai_painted_clean_info_ui_lobby_mockup.png` | 推荐主页面基准，清理冗余文字 |
| 编组页 | `output/visual_concepts/current_game_1930s_v10_h_deck_page_mockup.png` | AI 手绘编组底稿 + 当前动物 PNG + 编组信息 |
| 战斗页 | `output/visual_concepts/current_game_1930s_v10_h_battle_page_mockup.png` | AI 手绘战斗底稿 + 棋盘信息 + 当前动物 PNG |
| 抽卡页 | `output/visual_concepts/current_game_1930s_v10_h_gacha_page_mockup.png` | 复用 AI 手绘卡框底稿 + 抽卡信息 |
| 商店页 | `output/visual_concepts/current_game_1930s_v10_h_shop_page_mockup.png` | 复用 AI 手绘卡框底稿 + 商品信息 |
| 更多/任务页 | `output/visual_concepts/current_game_1930s_v10_h_more_tasks_page_mockup.png` | 任务信息页效果图 |
| 弹窗合集 | `output/visual_concepts/current_game_1930s_v10_h_popup_sheet_mockup.png` | 卡牌详情、战斗胜利、确认购买三个弹窗效果 |

说明：抽卡页和商店页的独立 AI 生成请求曾遇到网络错误，因此本轮先用已生成成功的 AI 手绘卡框页面作为组件基底进行效果图合成。后续若确认方向，可再为这些页面补独立 AI 底稿。

## 初步建议

1. 选 A：如果你想要最有艺术辨识度、最高级、最克制的复古动画质感。
2. 选 B：如果你想要更亮、更美、更商业化、更适合后续活动包装。
3. 选 C：如果你只想评审背景气氛，不评审整套 UI。
4. 选 D：如果你想看上一轮“程序合成整套 UI”的对照。
5. 选 E：如果你想看完整信息但尚未清理冗余标签的版本。
6. 选 F：如果你想确认当前最干净、最接近标注反馈的主页面版本。

我建议这次优先评审 F 和页面套件 v10。F 作为主页面基准，v10 作为其他页面和弹窗的流程验证；确认后再继续细化每个页面的独立 AI 底稿和信息密度。
