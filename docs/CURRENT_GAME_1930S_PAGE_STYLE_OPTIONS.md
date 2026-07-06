# 当前页面 1930s 手绘动画美术方案

生成日期：2026-07-06

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

## 初步建议

1. 选 A：如果你想要最有艺术辨识度、最高级、最克制的复古动画质感。
2. 选 B：如果你想要更亮、更美、更商业化、更适合后续活动包装。

我建议优先看 B 是否符合你想要的“美观度”，如果觉得过热闹，再回到 A 的高级克制路线。
