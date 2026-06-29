# 配置表说明

## 设计原则

- 设计数值进入 CSV，不写死在游戏代码里。
- 每张表都有稳定 ID，ID 使用小写字母、数字和下划线。
- 表之间通过 ID 引用，引用由校验脚本检查。
- 运行时读取 `runtime/config/*.json`，设计师主要编辑 `config/tables/*.csv`。

## 表清单

| 表 | 文件 | 用途 |
| --- | --- | --- |
| Global | `config/tables/global.csv` | 全局参数 |
| Units | `config/tables/units.csv` | 玩家、敌人、召唤物等单位 |
| Skills | `config/tables/skills.csv` | 主动/被动技能、攻击、效果 |
| Items | `config/tables/items.csv` | 装备、道具、升级项 |
| Stages | `config/tables/stages.csv` | 关卡、章节、难度和地图引用 |
| Drop Pools | `config/tables/drop_pools.csv` | 奖励和掉落池 |
| Economy | `config/tables/economy.csv` | 经济产出和消耗基础 |
| Localization ZH | `config/tables/localization_zh.csv` | 中文和英文文本键 |

## 修改流程

1. 编辑 `config/tables/*.csv`。
2. 运行 `python tools/validate_config.py`，Windows 也可使用 `py -3 tools/validate_config.py`。
3. 运行 `python tools/export_config.py`，Windows 也可使用 `py -3 tools/export_config.py`。
4. 检查 `runtime/config/*.json` 是否符合预期。
5. 提交 CSV、Schema 和需要的 JSON 变更。

## 常见错误

- ID 重复。
- 引用不存在的技能、关卡、掉落池或文本键。
- 数字字段填入了非数字文本。
- 列名被误删或重命名。
- 运行时 JSON 没有在 CSV 修改后重新导出。
