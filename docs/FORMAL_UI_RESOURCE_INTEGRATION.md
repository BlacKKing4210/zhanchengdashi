# 正式 UI 资源配合说明

生成日期：2026-07-05

## 目标

- 解决上一版只有背景正式、UI 仍像系统图的问题。
- 为 B 街机营地版生成一套可复用 UI 资源：资源条、进度面板、卡槽、按钮和底部导航。
- 保持当前动物 PNG 不变，只让 UI 与背景、建筑、动物统一到蓝金街机风。

## 资源清单

| 类型 | 路径 | 用途 |
| --- | --- | --- |
| UI 源图 | `assets/ui/formal_arcade/arcade_ui_overlay_source.png` | AI 生成原图，保留洋红背景，便于回溯。 |
| 透明 UI 覆盖层 | `assets/ui/formal_arcade/arcade_ui_overlay_alpha.png` | 去除洋红背景后的原始比例透明层。 |
| 720x1280 覆盖层 | `assets/ui/formal_arcade/arcade_ui_overlay_alpha_720x1280.png` | 规范化到游戏页面尺寸，用于大厅合成。 |
| 顶部资源条 | `assets/ui/formal_arcade/components/top_resource_bar.png` | 金币、宝石、券和设置入口。 |
| 模式进度条 | `assets/ui/formal_arcade/components/mode_progress_panel.png` | 荣耀之路、宝箱节点和进度表达。 |
| 编组卡槽面板 | `assets/ui/formal_arcade/components/squad_card_panel.png` | 出战动物卡槽和编组区域。 |
| 主按钮 | `assets/ui/formal_arcade/components/primary_cta_button.png` | 开始战斗按钮底图。 |
| 次按钮 | `assets/ui/formal_arcade/components/secondary_button.png` | 编组或次级操作按钮底图。 |
| 底部导航 | `assets/ui/formal_arcade/components/bottom_nav_bar.png` | 大厅、编组、战斗、宝箱、商店五入口。 |
| 合成预览 | `output/formal_page_options/formal_page_option_b_generated_ui.png` | B 街机营地版与生成 UI 资源配合后的页面稿。 |

## 合成原则

- 背景继续使用 `background_b_arcade_jungle.png`。
- 动物仍来自 `assets/card_art/animals/`，没有重新生成或改形。
- UI 使用 `arcade_ui_overlay_alpha_720x1280.png` 作为主覆盖层。
- 中文文字、数值和动物卡槽内容由脚本二次叠加，避免 AI 生成乱码。
- 后续进 Godot 时，可以先用整张 overlay 走快速验证，再逐步替换为 components 下的独立切片。

## 下一步落地建议

1. 先把大厅改成 `background_b_arcade_jungle.png` 加 `arcade_ui_overlay_alpha_720x1280.png` 的结构。
2. 将资源条数值、关卡进度、编组卡槽和底部导航文字保留为 Godot 绘制文本。
3. 组件成熟后，再用 `components/` 里的切片替换整张 overlay，方便做按钮反馈和局部动效。
4. 主按钮文字目前与双剑图标共享空间，正式落地时建议做成文字在右侧或图标在左侧的固定布局。
