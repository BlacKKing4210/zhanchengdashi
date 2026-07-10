# 占城大师 1930s UI 效果图 ui-ux-pro-max 审计

日期：2026-07-10

阶段：纯效果图，禁止实装

Skill 来源：`https://github.com/nextlevelbuilder/ui-ux-pro-max-skill/tree/main/.claude/skills/ui-ux-pro-max`

## 1. 使用确认

本轮实际安装并运行了 `ui-ux-pro-max`，不是只在流程文档中引用名称。

- 本机路径：`C:\Users\76398\.codex\skills\ui-ux-pro-max`
- 设计系统查询：`portrait mobile strategy card battle game playful vintage 1930s hand-drawn skeuomorphic information-dense`
- UX 查询：`mobile game touch navigation resource counters modal loading disabled locked text readability layout shift safe area`
- 风格查询：`vintage retro hand-drawn skeuomorphic playful game consistent components`
- 色彩查询：`entertainment game vintage warm paper red green blue high contrast`
- 字体查询：`mobile game readable display body numbers Chinese playful vintage`

## 2. 游戏化取舍

Skill 的第一次综合推荐包含 Bento Grid、3D/Hyperrealism 和深色界面。这些建议与已经确认的 1930s 轻松手绘方向、当前页面 UE 和移动游戏读图需求冲突，因此不采用。

本项目采用以下结果：

- `Sketch Hand-Drawn (Mobile)`：暖纸张、手绘边框、有限的不规则感、硬偏移阴影和一致组件语法。
- 中文可读字体：标题保留手写/楷体气质，正文、数值和状态使用清晰中文字体，不用只支持拉丁字符的装饰字体承担信息。
- 信息层级：每页只有一个最强主 CTA；次操作、取消和不可用状态必须明显降级。
- 动态数字：金币、票券、战力、价格和计时器使用稳定槽位并视觉居中，位数变化不改变周边布局。
- 状态清晰：selected、pressed、disabled、locked、loading、empty、error 和 unaffordable 不依赖单一颜色表达。
- 移动可用性：主要点击目标的视觉/预期点击区不小于 44 x 44 px，相邻目标保留至少 8 px 间隔。
- 跨页一致性：标题横幅、资源条、分区条、卡框、按钮、底部导航和弹窗使用统一边框、色彩角色和材质层级。
- 弹窗层级：背景只用于退后，弹窗标题、对象/结果、主操作和次操作按单一路径阅读。

不采用以下 Web/SaaS 特定建议：

- Bento 页面结构、网页 Hero、浮动操作按钮和桌面 hover 作为主交互。
- 3D/WebGL、多层视差、玻璃拟态和复杂模糊阴影。
- 原生系统控件外观直接覆盖项目的手绘游戏视觉。
- 为适配 skill 而新增、删除或移动当前页面控件。

## 3. v14 Design Tokens

| Token | 值 | 用途 |
| --- | --- | --- |
| `ink` | `#301E16` | 正文、数值、边框内线 |
| `paper` | `#FFFADE` | 高可读纸张底色和描边反差 |
| `paper-muted` | `#F2DBA6` | 次级面板和禁用底色 |
| `primary-red` | `#AC372D` | 主操作外框、危险或强提醒 |
| `secondary-blue` | `#26708B` | 次操作、信息状态和选中辅助 |
| `success-green` | `#2A734A` | 已完成、可用和正向状态 |
| `accent-gold` | `#CA801F` | 主 CTA、奖励和强调数字 |
| `disabled-wash` | `#766551`，约 38% 叠加 | 不可购买/禁用组件，不改变组件边界 |
| `outline` | 3-4 px 深墨线 | 保持 1930s 手绘组件统一 |
| `touch-min` | 44 x 44 px | 效果图阶段的最小可点击表达 |
| `touch-gap` | 8 px | 相邻操作的最小视觉间隔 |

关键文本组合的对比度：

- `ink` / `paper`：15.10:1。
- `paper` / `primary-red`：5.99:1。
- `paper` / `secondary-blue`：5.30:1。
- `paper` / `success-green`：5.47:1。
- `ink` / `accent-gold`：5.00:1。

## 4. v14 效果图改动

- 主页面：保持全部坐标和动物 PNG；资源数字继续居中；主操作保持唯一最强 CTA；战斗入口选中态增加更明确的描边/下划提示。
- 编组页：状态条和分区标题改用同一套手绘票券组件，减少简单圆角块与背景风格的割裂。
- 战斗页：保持 `648 x 1038` 外框、`592 x 982` 内场和 `7 x 13` 共 91 格；不改动物源图和格位坐标。
- 抽卡页：`抽 10 次`为主 CTA，`抽 1 次`为次操作；两者边界不移动。
- 商店页：余额不足商品增加整体禁用洗色，并保留文字原因；刷新操作保持单一主 CTA。
- 更多/任务页：完成状态使用“已完成”文字加 success 角色，不只靠颜色；设置、公告、邮件作为次操作，领取全部为主 CTA。
- 弹窗：购买为主 CTA、取消为次操作；背景只做轻微退后处理；卡牌详情与胜利弹窗保持一个明确出口。
- 全页面：标题、正文、数字、卡片、导航和弹窗状态统一；不改动物图片，不新增页面模块。

## 5. v14 QA Gate

- 九张独立页面均为 `720 x 1280`，另有 3 x 3 总览。
- 所有保留文字可辨认，无伪字、乱码、边框遮挡和低对比度丢失。
- 顶部金币/票券数字在各自数值栏中心，动态位数不会挤压图标。
- 战斗页检测到 91 个固定格位，外框不侵入有效内场。
- 主/次/禁用/完成/选中状态至少同时使用文字、明度、描边或材质中的两种表达。
- 原动物文件不修改，效果图继续直接合成项目现有 PNG。
- 只允许修改 `docs/`、`output/visual_concepts/`、`output/pdf/` 和效果图生成工具。
- 用户明确说“实装”前，不修改 `scripts/`、`scenes/`、运行时 `assets/`、输入逻辑或点击区域。

## 6. 实际执行结果

本轮最终输出前共完成三轮内部验收：

1. Producer / UI 首轮：主次 CTA、导航选中、任务完成和弹窗层级通过；商店禁用态洗色范围过大，记为 P1。
2. Art Director 复验：禁用洗色收回卡片内芯，P1 清零；洗色边缘仍略规则，记为 P2。
3. UI / QA 最终轮：改为柔和褪色纸张处理，保留手绘卡框；P0、P1 清零，P2 关闭。

量化结果：

- 10 张独立 PNG 均为 `720 x 1280`；总览为 `920 x 1980`。
- v14 战斗页与 v13 战斗页 SHA-256 一致，证明棋盘、91 格、单位位置和战斗区没有漂移。
- v14 大厅背景与 v13 大厅背景 SHA-256 一致，只调整信息/状态表现，不改场景构图。
- `assets/card_art/animals/`、`scripts/`、`scenes/` 和 `runtime/` 没有产生本轮差异。
- 五组关键文本/背景 token 对比度均达到或超过 4.5:1。
- 两个生成器通过 Python 语法检查，全部输出可重复生成。

## 7. Skill 解决的问题

`ui-ux-pro-max` 在本轮解决的是 UI/UX 质量问题，不负责生成 1930s 场景插画或重绘动物：

- 把“看起来不够专业”拆成 design tokens、组件一致性、信息层级、状态矩阵和 QA 项目。
- 明确主/次 CTA，并让 selected、completed 和 unaffordable 同时使用文字与视觉线索。
- 将简单圆角状态块替换为项目内已有的手绘票券组件，改善 UI 与背景风格割裂。
- 统一中文字体、数字槽位、对比度和弹窗阅读顺序。
- 以尺寸、哈希、目录差异和复验记录证明 UE/资产未漂移；skill 不生成 1930s 背景或动物，只负责 UI 设计与质量控制。
