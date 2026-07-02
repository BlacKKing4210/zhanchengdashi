# 单位属性与卡池平衡设计文档

生成日期：2026-06-30

## 设计目标

- 让每个移植来的单位族群都能在卡池中实际出现，而不是只停留在单位表。
- 地块价格在开局完成随机，单位/防御价格越高，越倾向抽到高品质卡牌。
- 上下半图以地图中心水平镜像，保证双方信息结构和资源机会一致。
- 普通卡负责铺场和识别基础玩法，稀有卡提供战术主题，史诗/传说卡制造阵容核心和翻盘点。

## 当前规则快照

| 地块ID | 类型 | 价格模式 | 价格/价格池 | 产出 | 产出间隔 | 出现概率% | 说明 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| cell_question | question | fixed | 25 | 0 | 0 | 50.0 | 开局随机地块类型之一，价格永远25，购买后按问号池抽空/防御/单位/金币 |
| cell_unit | unit | random_pool | 0 | 0 | 0 | 20.0 | 开局随机出类型和价格，价格从50/100/250中抽，价格越高进入越高品质的单位卡池 |
| cell_defense | defense | random_pool | 0 | 0 | 0 | 20.0 | 开局随机出类型和价格，价格池同单位地块，价格越高进入越高品质的防御卡池 |
| cell_gold_mine | gold_mine | fixed | 50 | 10 | 3.0 | 10.0 | 默认唯一金矿类型，价格永远50，占领后每3秒产出10金币 |
| cell_home_base | home_base | free | 0 | 12 | 3.0 | 0.0 | 固定大本营，不参与普通随机地块池，每3秒产出12金币 |

## 问号与地块翻开规则

| 池ID | 结果 | 类型 | 概率% | 最小数量 | 最大数量 |
| --- | --- | --- | --- | --- | --- |
| reveal_pool_question | empty | empty | 70.0 | 0 | 0 |
| reveal_pool_question | defense_cards_question | defense_pool | 10.0 | 1 | 1 |
| reveal_pool_question | unit_cards_question | unit_pool | 10.0 | 1 | 1 |
| reveal_pool_question | gold | currency | 10.0 | 25 | 40 |
| reveal_pool_unit_tile | selected_price_unit_pool | unit_pool | 100.0 | 1 | 1 |
| reveal_pool_defense_tile | selected_price_defense_pool | defense_pool | 100.0 | 1 | 1 |
| reveal_pool_gold_mine | cell_gold_mine | gold_mine | 100.0 | 1 | 1 |
| reveal_pool_home_base | cell_home_base | fixed | 100.0 | 1 | 1 |

## 单位/防御价格池

| 价格 | 概率% | 品质档 | 单位卡池 | 防御卡池 |
| --- | --- | --- | --- | --- |
| 50 | 30.0 | low | unit_cards_price_50 | defense_cards_price_50 |
| 100 | 50.0 | mid | unit_cards_price_100 | defense_cards_price_100 |
| 250 | 20.0 | high | unit_cards_price_250 | defense_cards_price_250 |

## 品质数值概览

| 品质 | 数量 | 平均HP | 平均速度 | 平均射程 | 平均伤害 | 平均DPS |
| --- | --- | --- | --- | --- | --- | --- |
| common | 10 | 107.5 | 3.85 | 2.03 | 13.4 | 12.5 |
| rare | 9 | 177.8 | 2.99 | 3.4 | 22.7 | 15.41 |
| epic | 8 | 257.5 | 3.11 | 3.19 | 26.2 | 18.25 |
| legendary | 3 | 436.7 | 2.77 | 3.87 | 42.7 | 23.87 |

## 召唤单位全表

| 名称 | 族群/外形 | 品质 | 内部费用 | HP | 速度 | 射程 | 伤害/CD(DPS) | 标签 | 技能效果 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 疾步狐 | beast | common | 2 | 85 | 5.0 | 1.1 | 10/0.9 (11.1) | fast\|melee\|flanker | 快速撕咬敌人并短暂加速 [damage\|haste; CD 0.9s] |
| 领嚎狼 | beast | rare | 4 | 135 | 4.2 | 1.2 | 18/1.1 (16.4) | aura\|melee\|pack | 嚎叫提升附近同族的攻击速度 [buff\|attack_speed\|pack; CD 7.0s] |
| 雷掌熊 | beast | epic | 6 | 360 | 2.4 | 1.5 | 34/1.8 (18.9) | tank\|stun\|high_hp | 重击地面造成伤害和短暂眩晕 [damage\|stun\|shock; CD 6.0s] |
| 冲牙奔袭者 | boarfolk | common | 3 | 145 | 4.1 | 1.2 | 16/1.2 (13.3) | charge\|fast\|melee | 向前冲锋并击退敌人 [damage\|dash\|knockback; CD 5.0s] |
| 钢鬃守卫 | boarfolk | rare | 4 | 280 | 2.5 | 1.3 | 22/1.6 (13.8) | tank\|retaliate | 进入防御姿态并反刺攻击者 [armor\|retaliate\|thorns; CD 4.0s] |
| 刺羽队长 | boarfolk | epic | 6 | 250 | 3.1 | 3.8 | 24/1.3 (18.5) | ranged\|retaliate\|aura | 齐射尖刺造成范围伤害 [damage\|projectile\|retaliate; CD 6.5s] |
| 齿轮兵 | clockwork | common | 2 | 150 | 2.8 | 1.3 | 14/1.2 (11.7) | sturdy\|melee | 齿轮拳击造成近战伤害 [damage; CD 1.2s] |
| 炮台步机 | clockwork | rare | 5 | 180 | 2.3 | 5.4 | 32/1.9 (16.8) | ranged\|high_attack\|slow | 发射炮弹造成远程范围伤害 [damage\|aoe\|projectile; CD 5.5s] |
| 修复核心 | clockwork | epic | 6 | 240 | 2.9 | 3.0 | 16/1.4 (11.4) | support\|shield\|repair | 展开修复场治疗并提供护盾 [heal\|shield\|repair; CD 8.0s] |
| 火星幼龙 | dragonkin | common | 3 | 120 | 3.3 | 3.8 | 15/1.3 (11.5) | ranged\|splash | 喷吐火星造成小范围溅射 [damage\|splash\|burn; CD 1.3s] |
| 天焰飞龙 | dragonkin | epic | 6 | 260 | 3.5 | 4.5 | 30/1.5 (20.0) | ranged\|cone\|aoe | 向前喷出扇形火焰 [damage\|burn\|cone; CD 7.5s] |
| 古老巨龙 | dragonkin | legendary | 9 | 520 | 2.6 | 5.2 | 42/2.0 (21.0) | legendary\|ranged\|aoe | 召下陨火造成大范围伤害 [damage\|burn\|stun; CD 11.0s] |
| 电火元素 | elemental | common | 2 | 90 | 3.9 | 4.2 | 12/0.95 (12.6) | ranged\|chain | 电弧弹射到额外目标 [damage\|chain; CD 0.95s] |
| 磐石元素 | elemental | rare | 4 | 310 | 2.0 | 1.2 | 20/1.7 (11.8) | tank\|shield\|slow | 生成岩壳护盾抵挡伤害 [shield\|armor; CD 9.0s] |
| 风暴元素 | elemental | epic | 6 | 210 | 3.4 | 4.8 | 26/1.2 (21.7) | ranged\|chain\|burst | 召唤链式风暴打击多个敌人 [damage\|chain\|shock; CD 6.5s] |
| 烬爪小邪裔 | fiend | common | 2 | 70 | 4.7 | 1.2 | 13/1.0 (13.0) | fast\|fragile\|burn | 爪击附带持续灼烧 [damage\|burn; CD 1.0s] |
| 血契蛮徒 | fiend | rare | 4 | 165 | 3.3 | 1.4 | 27/1.4 (19.3) | high_attack\|lifesteal\|risk | 牺牲少量生命换取吸血和狂暴 [lifesteal\|rage\|self_damage; CD 8.0s] |
| 裂隙领主 | fiend | legendary | 8 | 430 | 2.7 | 2.0 | 48/1.9 (25.3) | legendary\|summon\|burst | 打开裂隙召唤援兵并造成爆发 [summon\|damage\|rift; CD 12.0s] |
| 潮泽斥候 | marshkin | common | 2 | 100 | 4.4 | 1.5 | 11/0.9 (12.2) | fast\|melee | 向前潮涌突刺并造成伤害 [damage\|dash; CD 4.5s] |
| 泥沼萨满 | marshkin | rare | 4 | 145 | 3.1 | 4.3 | 17/1.25 (13.6) | ranged\|poison\|regen | 放置泥沼图腾让敌人中毒并回复友军 [poison\|regen\|zone; CD 8.0s] |
| 泥浪斗士 | marshkin | epic | 6 | 300 | 2.8 | 1.5 | 29/1.5 (19.3) | control\|tank\|slow | 推出泥浪伤害并减速敌人 [slow\|damage\|wave; CD 7.0s] |
| 弯刀海盗 | pirate | common | 3 | 125 | 3.5 | 1.3 | 18/1.05 (17.1) | melee\|high_attack | 连续挥砍造成高频近战伤害 [damage\|combo; CD 1.05s] |
| 火药炮手 | pirate | rare | 5 | 150 | 2.9 | 5.0 | 28/1.8 (15.6) | ranged\|aoe\|bomb | 投掷火药桶延迟爆炸 [damage\|aoe\|bomb; CD 6.5s] |
| 舰队统领 | pirate | legendary | 8 | 360 | 3.0 | 4.4 | 38/1.5 (25.3) | legendary\|aura\|ranged | 呼叫炮击并提升友军开火节奏 [damage\|aura\|barrage; CD 10.0s] |
| 礁枪卫 | serpentfolk | common | 3 | 115 | 3.6 | 3.6 | 16/1.2 (13.3) | ranged\|pierce | 投出穿透直线的礁枪 [damage\|pierce\|projectile; CD 1.2s] |
| 鸣潮射手 | serpentfolk | rare | 4 | 130 | 3.7 | 5.6 | 19/1.15 (16.5) | ranged\|focus\|kite | 短暂专注以提高远程伤害 [buff\|damage\|focus; CD 6.0s] |
| 潮汐先知 | serpentfolk | epic | 6 | 210 | 3.2 | 4.8 | 20/1.35 (14.8) | support\|slow\|shield | 为友军加盾并减速附近敌人 [shield\|slow\|water; CD 8.5s] |
| 碎骨仆从 | undead | common | 2 | 75 | 3.2 | 1.1 | 9/1.0 (9.0) | swarm\|fragile | 唤起碎骨群涌向敌人 [summon\|swarm\|damage; CD 5.0s] |
| 墓地射手 | undead | rare | 4 | 105 | 2.9 | 5.2 | 21/1.4 (15.0) | ranged\|curse | 射出诅咒箭降低目标防御 [damage\|curse\|projectile; CD 1.4s] |
| 幽魂骑士 | undead | epic | 6 | 230 | 3.6 | 1.6 | 31/1.45 (21.4) | revive\|melee\|elite | 首次倒下后化为幽魂短暂返场 [revive\|ghost\|haste; CD 12.0s] |

## 防御塔全表

| 名称 | 品质 | HP | 射程 | 伤害/CD(DPS) | 标签 | 技能效果 |
| --- | --- | --- | --- | --- | --- | --- |
| 哨戒箭塔 | common | 180 | 5.2 | 16/1.2 (13.3) | tower\|ranged\|single_target | 射击最近的敌人并造成稳定伤害 [damage\|projectile; CD 1.2s] |
| 火炮塔 | rare | 240 | 5.8 | 34/1.9 (17.9) | tower\|ranged\|aoe | 发射炮弹造成远程范围伤害 [damage\|aoe\|projectile; CD 5.5s] |
| 修复信标 | epic | 220 | 3.5 | 0/2.0 (0.0) | tower\|support\|repair | 展开修复场治疗并提供护盾 [heal\|shield\|repair; CD 8.0s] |
| 风暴方尖碑 | legendary | 300 | 6.0 | 42/2.2 (19.1) | tower\|legendary\|chain | 召唤链式风暴打击多个敌人 [damage\|chain\|shock; CD 6.5s] |

## 卡池品质分布

| 卡池 | 条目数 | 普通% | 稀有% | 史诗% | 传说% |
| --- | --- | --- | --- | --- | --- |
| defense_cards_price_100 | 4 | 25.0 | 40.0 | 25.0 | 10.0 |
| defense_cards_price_250 | 3 | 0 | 15.0 | 45.0 | 40.0 |
| defense_cards_price_50 | 3 | 70.0 | 25.0 | 5.0 | 0 |
| defense_cards_question | 2 | 80.0 | 20.0 | 0 | 0 |
| unit_cards_price_100 | 18 | 29.0 | 46.0 | 20.0 | 5.0 |
| unit_cards_price_250 | 12 | 0 | 10.0 | 50.0 | 40.0 |
| unit_cards_price_50 | 12 | 65.0 | 30.0 | 5.0 | 0 |
| unit_cards_question | 7 | 80.0 | 20.0 | 0 | 0 |

## 卡池明细

| 卡池 | 卡牌 | 类型 | 品质 | 权重 | 概率% |
| --- | --- | --- | --- | --- | --- |
| unit_cards_question | 疾步狐 | unit | common | 20 | 20.0 |
| unit_cards_question | 烬爪小邪裔 | unit | common | 15 | 15.0 |
| unit_cards_question | 电火元素 | unit | common | 15 | 15.0 |
| unit_cards_question | 齿轮兵 | unit | common | 15 | 15.0 |
| unit_cards_question | 碎骨仆从 | unit | common | 15 | 15.0 |
| unit_cards_question | 领嚎狼 | unit | rare | 10 | 10.0 |
| unit_cards_question | 炮台步机 | unit | rare | 10 | 10.0 |
| defense_cards_question | 哨戒箭塔 | defense | common | 80 | 80.0 |
| defense_cards_question | 火炮塔 | defense | rare | 20 | 20.0 |
| unit_cards_price_50 | 疾步狐 | unit | common | 16 | 16.0 |
| unit_cards_price_50 | 烬爪小邪裔 | unit | common | 13 | 13.0 |
| unit_cards_price_50 | 电火元素 | unit | common | 13 | 13.0 |
| unit_cards_price_50 | 齿轮兵 | unit | common | 11 | 11.0 |
| unit_cards_price_50 | 潮泽斥候 | unit | common | 12 | 12.0 |
| unit_cards_price_50 | 领嚎狼 | unit | rare | 8 | 8.0 |
| unit_cards_price_50 | 泥沼萨满 | unit | rare | 7 | 7.0 |
| unit_cards_price_50 | 鸣潮射手 | unit | rare | 5 | 5.0 |
| unit_cards_price_50 | 炮台步机 | unit | rare | 5 | 5.0 |
| unit_cards_price_50 | 磐石元素 | unit | rare | 5 | 5.0 |
| unit_cards_price_50 | 雷掌熊 | unit | epic | 3 | 3.0 |
| unit_cards_price_50 | 风暴元素 | unit | epic | 2 | 2.0 |
| unit_cards_price_100 | 火星幼龙 | unit | common | 8 | 8.0 |
| unit_cards_price_100 | 弯刀海盗 | unit | common | 8 | 8.0 |
| unit_cards_price_100 | 礁枪卫 | unit | common | 7 | 7.0 |
| unit_cards_price_100 | 冲牙奔袭者 | unit | common | 6 | 6.0 |
| unit_cards_price_100 | 领嚎狼 | unit | rare | 8 | 8.0 |
| unit_cards_price_100 | 血契蛮徒 | unit | rare | 7 | 7.0 |
| unit_cards_price_100 | 炮台步机 | unit | rare | 7 | 7.0 |
| unit_cards_price_100 | 鸣潮射手 | unit | rare | 7 | 7.0 |
| unit_cards_price_100 | 墓地射手 | unit | rare | 7 | 7.0 |
| unit_cards_price_100 | 火药炮手 | unit | rare | 5 | 5.0 |
| unit_cards_price_100 | 钢鬃守卫 | unit | rare | 5 | 5.0 |
| unit_cards_price_100 | 雷掌熊 | unit | epic | 5 | 5.0 |
| unit_cards_price_100 | 天焰飞龙 | unit | epic | 5 | 5.0 |
| unit_cards_price_100 | 修复核心 | unit | epic | 5 | 5.0 |
| unit_cards_price_100 | 泥浪斗士 | unit | epic | 5 | 5.0 |
| unit_cards_price_100 | 舰队统领 | unit | legendary | 2 | 2.0 |
| unit_cards_price_100 | 裂隙领主 | unit | legendary | 1 | 1.0 |
| unit_cards_price_100 | 古老巨龙 | unit | legendary | 2 | 2.0 |
| unit_cards_price_250 | 血契蛮徒 | unit | rare | 5 | 5.0 |
| unit_cards_price_250 | 炮台步机 | unit | rare | 5 | 5.0 |
| unit_cards_price_250 | 雷掌熊 | unit | epic | 9 | 9.0 |
| unit_cards_price_250 | 天焰飞龙 | unit | epic | 9 | 9.0 |
| unit_cards_price_250 | 风暴元素 | unit | epic | 8 | 8.0 |
| unit_cards_price_250 | 修复核心 | unit | epic | 7 | 7.0 |
| unit_cards_price_250 | 潮汐先知 | unit | epic | 5 | 5.0 |
| unit_cards_price_250 | 幽魂骑士 | unit | epic | 5 | 5.0 |
| unit_cards_price_250 | 刺羽队长 | unit | epic | 7 | 7.0 |
| unit_cards_price_250 | 裂隙领主 | unit | legendary | 14 | 14.0 |
| unit_cards_price_250 | 古老巨龙 | unit | legendary | 14 | 14.0 |
| unit_cards_price_250 | 舰队统领 | unit | legendary | 12 | 12.0 |
| defense_cards_price_50 | 哨戒箭塔 | defense | common | 70 | 70.0 |
| defense_cards_price_50 | 火炮塔 | defense | rare | 25 | 25.0 |
| defense_cards_price_50 | 修复信标 | defense | epic | 5 | 5.0 |
| defense_cards_price_100 | 哨戒箭塔 | defense | common | 25 | 25.0 |
| defense_cards_price_100 | 火炮塔 | defense | rare | 40 | 40.0 |
| defense_cards_price_100 | 修复信标 | defense | epic | 25 | 25.0 |
| defense_cards_price_100 | 风暴方尖碑 | defense | legendary | 10 | 10.0 |
| defense_cards_price_250 | 火炮塔 | defense | rare | 15 | 15.0 |
| defense_cards_price_250 | 修复信标 | defense | epic | 45 | 45.0 |
| defense_cards_price_250 | 风暴方尖碑 | defense | legendary | 40 | 40.0 |

## 平衡设计说明

- 50金币单位池：用于早期铺场，普通单位权重最高，同时保留少量稀有和极低概率史诗，让低价地块有惊喜但不稳定。
- 100金币单位池：中期主力池，稀有单位覆盖最多，史诗稳定出现，传说保持低概率，避免中价位过早决定胜负。
- 250金币单位池：高投入高回报，史诗和传说成为主要权重，适合作为玩家围绕经济优势做出的明确赌点。
- 防御池：同价位逻辑与单位一致，但条目更少；这会让防御地块更可读，也方便后续按塔型扩展。
- 族群差异：野兽偏速度和群体攻速，邪裔偏高风险爆发，龙裔偏远程范围，元素偏弹射/护盾，机械偏炮击/修复，沼泽偏毒和回复，海蛇偏远程控制，海盗偏高攻和炮击，豪猪偏冲锋反击，亡灵偏群涌和返场。
- 外形资产：当前配置已经让所有移植单位进入卡池；实际美术资源仍需要按族群补齐 sprite/序列帧或程序化变体。

## 调参检查清单

- 改 `card_random_pools.csv` 后，同一个 `pool_id` 的 `probability_pct` 应合计100。
- 低价池不要放太多传说，否则25问号和50单位地块会过早破坏节奏。
- 高价池可以提高传说权重，但要同步观察金矿和大本营每3秒产出的经济节奏。
- 新增单位时，先补 `units.csv` 和 `skills.csv`，再加入至少一个 `card_random_pools.csv` 池。
- 新增防御塔时，先补 `defenses.csv`，再加入对应防御池。

## 覆盖状态

- 召唤单位总数：30
- 已进入单位卡池：30
- 未进入卡池：无
