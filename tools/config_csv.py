#!/usr/bin/env python3
"""Shared three-row-header CSV helpers for game configuration tables.

Row 1 contains machine field names, row 2 contains Chinese field names,
row 3 contains optional usage notes, and runtime data starts on row 4.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Mapping, Sequence


HEADER_ROW_COUNT = 3
DATA_START_LINE = 4

FIELD_LABEL_OVERRIDES = {
    "zh-CN": "简体中文",
    "zh_cn": "简体中文",
    "en": "英文",
    "en_us": "英文（美国）",
    "id": "ID",
    "key": "键",
    "name": "名称",
    "notes": "备注",
    "description": "描述",
    "design_notes": "设计备注",
    "display_name": "显示名称",
    "display_key": "显示文本键",
    "name_key": "名称文本键",
    "text_key": "文本键",
    "name_locale_key": "名称本地化键",
    "title_locale_key": "标题本地化键",
    "description_locale_key": "描述本地化键",
    "description_key": "描述文本键",
    "adjacent_to": "相邻对象",
    "arrival_seconds": "到达时间（秒）",
    "build_seconds": "建造时间（秒）",
    "capacity_per_level": "每级容量增量",
    "departure_seconds": "离开时间（秒）",
    "end_minute": "结束时间（分钟）",
    "grow_seconds": "生长时间（秒）",
    "load_seconds": "装载时间（秒）",
    "order_id": "订单ID",
    "refresh_seconds": "刷新时间（秒）",
    "seconds": "时长（秒）",
    "sort_order": "排序序号",
    "staff_max": "最大员工数",
    "staff_min": "最小员工数",
    "start_minute": "开始时间（分钟）",
    "visitor_capacity": "访客容量",
    "work_seconds": "工作时间（秒）",
    "appearance_probability_pct": "出现概率（%）",
    "probability_pct": "概率（%）",
    "randomize_cell_type_at_start": "开始时随机地块类型",
    "randomize_price_at_start": "开始时随机价格",
    "lock_cell_type_after_generation": "生成后锁定地块类型",
    "lock_price_after_generation": "生成后锁定价格",
    "speed_cells_per_second": "移动速度（格/秒）",
    "spawn_rate_per_sec": "生成速率（个/秒）",
    "income_interval_sec": "收益间隔（秒）",
    "attack_cooldown_sec": "攻击冷却（秒）",
    "skill_cooldown_sec": "技能冷却（秒）",
    "summon_interval_sec": "召唤间隔（秒）",
    "time_limit_sec": "时间限制（秒）",
    "cooldown_sec": "冷却时间（秒）",
    "duration_sec": "持续时间（秒）",
    "duration_seconds": "持续时间（秒）",
    "duration_ms": "持续时间（毫秒）",
    "cooldown_ms": "冷却时间（毫秒）",
    "frequency_hz": "频率（赫兹）",
    "gain_db": "增益（分贝）",
    "card_id": "卡牌ID",
    "locale": "语言地区",
    "voice_path": "语音路径",
    "persona_id": "角色声线ID",
    "voice_name": "系统语音名称",
    "rate_pct": "语速调整（%）",
    "pitch_pct": "音高调整（%）",
    "status": "制作状态",
    "base_damage": "基础伤害",
    "attack": "攻击力",
    "range": "作用范围",
    "power": "效果强度",
    "scaling_formula": "增长公式",
    "base_amount": "基础数量",
    "base_capacity": "基础容量",
    "base_reveal_cost": "基础揭示费用",
    "max_hp": "最大生命值",
    "max_count": "最大数量",
    "min_count": "最小数量",
    "max_concurrency": "最大并发数",
    "initially_unlocked": "初始解锁",
    "initially_invited": "初始已邀请",
    "initial_placed": "初始已放置",
    "initial_amount": "初始数量",
    "initial_value": "初始值",
    "initial_level": "初始等级",
    "initial_state": "初始状态",
    "reward_coins": "奖励金币",
    "coin_reward": "金币奖励",
    "reward_renown": "奖励声望",
    "prosperity_reward": "繁荣度奖励",
    "market_coin_value": "市场金币价值",
    "build_coin_cost": "建造金币费用",
    "fixed_price": "固定价格",
    "shop_cost": "商店费用",
    "unlock_cost": "解锁费用",
    "unlock_level": "解锁等级",
    "unlock_stage": "解锁阶段",
    "unlock_condition": "解锁条件",
    "unlock_rule": "解锁规则",
    "prerequisite_rule": "前置规则",
    "appearance_weight": "出现权重",
    "recommended_power": "推荐战力",
    "reduced_motion_value": "减少动态值",
    "normal_value": "常规值",
    "world_x": "世界X坐标",
    "world_y": "世界Y坐标",
    "grid_x": "网格X坐标",
    "grid_y": "网格Y坐标",
    "origin_x": "原点X坐标",
    "origin_y": "原点Y坐标",
    "anchor_x": "锚点X坐标",
    "anchor_y": "锚点Y坐标",
    "from_x": "起点X坐标",
    "from_y": "起点Y坐标",
    "to_x": "终点X坐标",
    "to_y": "终点Y坐标",
    "entry_x": "入口X坐标",
    "entry_y": "入口Y坐标",
    "entry_dx": "入口X偏移",
    "entry_dy": "入口Y偏移",
    "entrance_dx": "入口X偏移",
    "entrance_dy": "入口Y偏移",
    "default_x": "默认X坐标",
    "default_y": "默认Y坐标",
    "work_x": "作业点X坐标",
    "work_y": "作业点Y坐标",
    "bounds_min_x": "边界最小X坐标",
    "bounds_min_y": "边界最小Y坐标",
    "bounds_max_x": "边界最大X坐标",
    "bounds_max_y": "边界最大Y坐标",
    "footprint_w": "占地宽度",
    "footprint_h": "占地高度",
    "max_w": "最大宽度",
    "max_h": "最大高度",
}

TOKEN_LABELS = {
    "accent": "强调色",
    "action": "操作",
    "adjacent": "相邻",
    "after": "之后",
    "amount": "数量",
    "anchor": "锚点",
    "animal": "动物",
    "appearance": "出现",
    "arrival": "到达",
    "art": "美术",
    "asset": "资源",
    "assignable": "可分配",
    "assignment": "分配",
    "at": "时",
    "attack": "攻击",
    "axis": "轴",
    "base": "基础",
    "block": "时段",
    "blocked": "阻塞",
    "bounds": "边界",
    "build": "建造",
    "buildable": "可建造",
    "building": "建筑",
    "cap": "上限",
    "capacity": "容量",
    "card": "卡牌",
    "carry": "搬运",
    "category": "类别",
    "cell": "地块",
    "cells": "地块列表",
    "chance": "概率",
    "chapter": "章节",
    "checkpoint": "检查点",
    "choice": "选项",
    "cn": "中文",
    "coin": "金币",
    "coins": "金币",
    "concurrency": "并发数",
    "condition": "条件",
    "content": "内容",
    "cooldown": "冷却",
    "cost": "费用",
    "costs": "费用列表",
    "count": "数量",
    "currency": "货币",
    "daily": "每日",
    "damage": "伤害",
    "db": "分贝",
    "default": "默认",
    "defense": "防御",
    "delay": "延迟",
    "departure": "离开",
    "description": "描述",
    "design": "设计",
    "destination": "目的地",
    "difficulty": "难度",
    "display": "显示",
    "district": "区域",
    "duration": "持续时间",
    "dx": "X偏移",
    "dy": "Y偏移",
    "effect": "效果",
    "emoji": "表情符号",
    "en": "英文",
    "end": "结束",
    "enemy": "敌人",
    "entrance": "入口",
    "entry": "条目",
    "event": "事件",
    "extra": "额外",
    "family": "族系",
    "feed": "饲料",
    "fixed": "固定",
    "focus": "聚焦",
    "footprint": "占地",
    "formula": "公式",
    "frequency": "频率",
    "from": "起点",
    "function": "功能",
    "gain": "增益",
    "generation": "生成",
    "grid": "网格",
    "group": "组",
    "grow": "生长",
    "growth": "增长",
    "h": "高度",
    "hard": "硬性",
    "harvest": "收获",
    "height": "高度",
    "home": "住宅",
    "house": "房屋",
    "hp": "生命值",
    "hz": "赫兹",
    "icon": "图标",
    "id": "ID",
    "idle": "空闲",
    "ids": "ID列表",
    "income": "收益",
    "initial": "初始",
    "initially": "初始",
    "input": "输入",
    "inputs": "输入列表",
    "interactive": "可交互",
    "interrupt": "中断",
    "interval": "间隔",
    "invite": "邀请",
    "invited": "已邀请",
    "is": "是否",
    "item": "物品",
    "items": "物品列表",
    "job": "工作",
    "key": "键",
    "kind": "类型",
    "landmark": "地标",
    "level": "等级",
    "life": "生活",
    "limit": "限制",
    "load": "装载",
    "locale": "本地化",
    "lock": "锁定",
    "lot": "地块",
    "machine": "机器",
    "map": "地图",
    "market": "市场",
    "max": "最大",
    "min": "最小",
    "minute": "分钟",
    "mirror": "镜像",
    "mode": "模式",
    "motion": "动态",
    "move": "移动",
    "ms": "毫秒",
    "name": "名称",
    "next": "下一",
    "normal": "常规",
    "notes": "备注",
    "object": "对象",
    "objective": "目标",
    "offsets": "偏移列表",
    "order": "顺序",
    "origin": "原点",
    "outcome": "结果",
    "output": "输出",
    "outputs": "输出列表",
    "parcel": "生产地块",
    "path": "路径",
    "pct": "百分比",
    "pen": "畜栏",
    "per": "每",
    "phase": "阶段",
    "placed": "已放置",
    "placement": "放置",
    "plant": "种植",
    "point": "点位",
    "policy": "策略",
    "pool": "池",
    "power": "强度",
    "prerequisite": "前置",
    "price": "价格",
    "priority": "优先级",
    "probability": "概率",
    "prosperity": "繁荣度",
    "quality": "品质",
    "quantity": "数量",
    "queue": "队列",
    "radius": "半径",
    "randomize": "随机化",
    "range": "范围",
    "rarity": "稀有度",
    "recipe": "配方",
    "recommended": "推荐",
    "reduced": "减少",
    "refresh": "刷新",
    "region": "地区",
    "renown": "声望",
    "repeat": "重复",
    "repeatable": "可重复",
    "required": "需求",
    "requirements": "需求列表",
    "reserve": "保留量",
    "resident": "居民",
    "reveal": "揭示",
    "reward": "奖励",
    "risk": "风险",
    "road": "道路",
    "role": "定位",
    "route": "路线",
    "rule": "规则",
    "runtime": "运行时",
    "salt": "随机盐值",
    "scaling": "缩放",
    "schedule": "日程",
    "sec": "秒",
    "second": "秒",
    "seconds": "秒",
    "seed": "种子",
    "sequence": "序列",
    "service": "服务",
    "shop": "商店",
    "site": "设施点",
    "skill": "技能",
    "slot": "槽位",
    "slots": "槽位数",
    "sort": "排序",
    "source": "来源",
    "species": "物种",
    "speed": "速度",
    "stack": "堆叠",
    "staff": "员工数",
    "stage": "阶段",
    "start": "开始",
    "stat": "属性",
    "state": "状态",
    "storage": "仓储",
    "summon": "召唤",
    "table": "表",
    "tags": "标签",
    "target": "目标",
    "targeting": "目标选择",
    "task": "任务",
    "terrain": "地形",
    "text": "文本",
    "theme": "主题",
    "tier": "档位",
    "time": "时间",
    "timeout": "超时",
    "title": "标题",
    "to": "终点",
    "token": "参数",
    "trigger": "触发条件",
    "type": "类型",
    "types": "类型列表",
    "unit": "单位",
    "unlock": "解锁",
    "unlocked": "已解锁",
    "upgrade": "升级",
    "us": "美国",
    "usage": "用法",
    "value": "值",
    "variants": "变体列表",
    "vehicle": "车辆",
    "vfx": "视觉特效",
    "visitor": "访客数",
    "visual": "视觉参数",
    "w": "宽度",
    "weight": "权重",
    "width": "宽度",
    "work": "工作",
    "workplace": "工作场所",
    "workpoint": "作业点",
    "world": "世界",
    "x": "X坐标",
    "y": "Y坐标",
    "yield": "产量",
    "zh": "中文",
}

UNIT_SUFFIXES = {
    "_seconds": "秒",
    "_second": "秒",
    "_sec": "秒",
    "_ms": "毫秒",
    "_hz": "赫兹",
    "_db": "分贝",
    "_pct": "%",
}


class ConfigCsvError(ValueError):
    """Raised when a configuration table breaks the three-row contract."""


@dataclass(frozen=True)
class ConfigTable:
    path: Path
    fieldnames: list[str]
    chinese_names: list[str]
    usage_notes: list[str]
    data_rows: list[list[str]]
    had_utf8_bom: bool

    def dict_rows(self) -> list[dict[str, str]]:
        return [dict(zip(self.fieldnames, row, strict=True)) for row in self.data_rows]


def chinese_name(field: str) -> str:
    if field in FIELD_LABEL_OVERRIDES:
        return FIELD_LABEL_OVERRIDES[field]
    for suffix, unit in UNIT_SUFFIXES.items():
        if field.endswith(suffix):
            base = field[: -len(suffix)]
            return f"{_translate_tokens(base)}（{unit}）"
    return _translate_tokens(field)


def _translate_tokens(field: str) -> str:
    tokens = field.replace("-", "_").split("_")
    missing = [token for token in tokens if token not in TOKEN_LABELS]
    if missing:
        raise ConfigCsvError(
            f"{field}: missing Chinese token mapping for {', '.join(sorted(set(missing)))}"
        )
    return "".join(TOKEN_LABELS[token] for token in tokens)


def expected_chinese_names(fieldnames: Sequence[str]) -> list[str]:
    names = [chinese_name(field) for field in fieldnames]
    if any(not name.strip() for name in names):
        raise ConfigCsvError("Chinese field names must not be empty")
    return names


def _read_rows(path: Path) -> tuple[list[list[str]], bool]:
    raw = path.read_bytes()
    had_utf8_bom = raw.startswith(b"\xef\xbb\xbf")
    try:
        text = raw.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise ConfigCsvError(f"{path}: configuration CSV must be UTF-8") from exc
    return list(csv.reader(text.splitlines())), had_utf8_bom


def read_config_table(path: str | Path, *, allow_legacy: bool = False) -> ConfigTable:
    table_path = Path(path)
    rows, had_utf8_bom = _read_rows(table_path)
    if not rows or not rows[0]:
        raise ConfigCsvError(f"{table_path}: missing machine header row")
    fieldnames = rows[0]
    if any(not field.strip() for field in fieldnames):
        raise ConfigCsvError(f"{table_path}: machine field names must not be empty")
    if len(set(fieldnames)) != len(fieldnames):
        raise ConfigCsvError(f"{table_path}: duplicate machine field name")

    expected_names = expected_chinese_names(fieldnames)
    has_metadata = (
        len(rows) >= HEADER_ROW_COUNT
        and rows[1] == expected_names
        and len(rows[2]) == len(fieldnames)
    )
    if not has_metadata and not allow_legacy:
        raise ConfigCsvError(
            f"{table_path}: expected Chinese names on row 2 and usage notes on row 3"
        )

    if has_metadata:
        chinese_names = rows[1]
        usage_notes = rows[2]
        data_rows = rows[HEADER_ROW_COUNT:]
    else:
        chinese_names = expected_names
        usage_notes = [""] * len(fieldnames)
        data_rows = rows[1:]

    if len(chinese_names) != len(fieldnames):
        raise ConfigCsvError(f"{table_path}: row 2 width does not match row 1")
    if any(not value.strip() for value in chinese_names):
        raise ConfigCsvError(f"{table_path}: row 2 contains an empty Chinese field name")
    if len(usage_notes) != len(fieldnames):
        raise ConfigCsvError(f"{table_path}: row 3 width does not match row 1")
    for line_number, row in enumerate(data_rows, start=DATA_START_LINE):
        if len(row) != len(fieldnames):
            raise ConfigCsvError(
                f"{table_path}:{line_number}: expected {len(fieldnames)} columns, "
                f"found {len(row)}"
            )
    return ConfigTable(
        path=table_path,
        fieldnames=list(fieldnames),
        chinese_names=list(chinese_names),
        usage_notes=list(usage_notes),
        data_rows=[list(row) for row in data_rows],
        had_utf8_bom=had_utf8_bom,
    )


def read_config_dicts(path: str | Path) -> list[dict[str, str]]:
    return read_config_table(path).dict_rows()


def _write_rows(
    path: Path,
    fieldnames: Sequence[str],
    chinese_names: Sequence[str],
    usage_notes: Sequence[str],
    data_rows: Iterable[Sequence[object]],
    *,
    utf8_bom: bool,
) -> None:
    encoding = "utf-8-sig" if utf8_bom else "utf-8"
    with path.open("w", newline="", encoding=encoding) as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(fieldnames)
        writer.writerow(chinese_names)
        writer.writerow(usage_notes)
        writer.writerows(data_rows)


def write_config_dicts(
    path: str | Path,
    fieldnames: Sequence[str],
    rows: Iterable[Mapping[str, object]],
    *,
    usage_notes: Mapping[str, str] | None = None,
    utf8_bom: bool = False,
) -> None:
    table_path = Path(path)
    table_path.parent.mkdir(parents=True, exist_ok=True)
    notes_by_field = usage_notes or {}
    _write_rows(
        table_path,
        fieldnames,
        expected_chinese_names(fieldnames),
        [notes_by_field.get(field, "") for field in fieldnames],
        ([row.get(field, "") for field in fieldnames] for row in rows),
        utf8_bom=utf8_bom,
    )
    read_config_table(table_path)


def _table_snapshot(table: ConfigTable) -> dict[str, object]:
    payload = {
        "fieldnames": table.fieldnames,
        "data_rows": table.data_rows,
    }
    canonical = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    return {
        **payload,
        "data_sha256": hashlib.sha256(canonical).hexdigest(),
        "data_row_count": len(table.data_rows),
        "had_utf8_bom": table.had_utf8_bom,
    }


def snapshot_tables(tables_dir: str | Path, output: str | Path) -> dict[str, object]:
    root = Path(tables_dir)
    tables = {
        path.name: _table_snapshot(read_config_table(path, allow_legacy=True))
        for path in sorted(root.glob("*.csv"))
    }
    result = {
        "schema": "config-csv-three-row-baseline-v1",
        "table_count": len(tables),
        "tables": tables,
    }
    output_path = Path(output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return result


def migrate_tables(tables_dir: str | Path, baseline_output: str | Path) -> dict[str, object]:
    root = Path(tables_dir)
    baseline = snapshot_tables(root, baseline_output)
    pending: list[tuple[Path, Path, ConfigTable]] = []
    try:
        for path in sorted(root.glob("*.csv")):
            table = read_config_table(path, allow_legacy=True)
            temp_path = path.with_name(f".{path.name}.metadata.tmp")
            _write_rows(
                temp_path,
                table.fieldnames,
                expected_chinese_names(table.fieldnames),
                [""] * len(table.fieldnames),
                table.data_rows,
                utf8_bom=table.had_utf8_bom,
            )
            read_config_table(temp_path)
            pending.append((path, temp_path, table))
        for path, temp_path, _table in pending:
            os.replace(temp_path, path)
    finally:
        for _path, temp_path, _table in pending:
            if temp_path.exists():
                temp_path.unlink()
    validated = validate_tables(root)
    compared = compare_baseline(root, baseline_output)
    return {
        "table_count": validated["table_count"],
        "data_row_count": validated["data_row_count"],
        "baseline_table_count": baseline["table_count"],
        "data_equivalent": compared["data_equivalent"],
    }


def validate_tables(tables_dir: str | Path) -> dict[str, object]:
    root = Path(tables_dir)
    tables = [read_config_table(path) for path in sorted(root.glob("*.csv"))]
    return {
        "table_count": len(tables),
        "data_row_count": sum(len(table.data_rows) for table in tables),
        "all_row2_names_non_empty": all(
            all(value.strip() for value in table.chinese_names) for table in tables
        ),
        "all_row_widths_match": True,
        "data_start_line": DATA_START_LINE,
    }


def compare_baseline(tables_dir: str | Path, baseline_path: str | Path) -> dict[str, object]:
    root = Path(tables_dir)
    baseline = json.loads(Path(baseline_path).read_text(encoding="utf-8"))
    actual_names = sorted(path.name for path in root.glob("*.csv"))
    expected_names = sorted(baseline["tables"].keys())
    mismatches: list[str] = []
    if actual_names != expected_names:
        mismatches.append("table set changed")
    for name in sorted(set(actual_names) & set(expected_names)):
        actual = _table_snapshot(read_config_table(root / name))
        expected = baseline["tables"][name]
        if actual["fieldnames"] != expected["fieldnames"]:
            mismatches.append(f"{name}: machine header changed")
        if actual["data_rows"] != expected["data_rows"]:
            mismatches.append(f"{name}: runtime data changed")
    return {
        "table_count": len(actual_names),
        "data_equivalent": not mismatches,
        "mismatches": mismatches,
    }


def _main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    labels_parser = subparsers.add_parser("labels")
    labels_parser.add_argument("--tables-dir", required=True)

    snapshot_parser = subparsers.add_parser("snapshot")
    snapshot_parser.add_argument("--tables-dir", required=True)
    snapshot_parser.add_argument("--output", required=True)

    migrate_parser = subparsers.add_parser("migrate")
    migrate_parser.add_argument("--tables-dir", required=True)
    migrate_parser.add_argument("--baseline", required=True)

    validate_parser = subparsers.add_parser("validate")
    validate_parser.add_argument("--tables-dir", required=True)

    compare_parser = subparsers.add_parser("compare")
    compare_parser.add_argument("--tables-dir", required=True)
    compare_parser.add_argument("--baseline", required=True)

    args = parser.parse_args()
    if args.command == "labels":
        fields = sorted(
            {
                field
                for path in Path(args.tables_dir).glob("*.csv")
                for field in read_config_table(path, allow_legacy=True).fieldnames
            }
        )
        result: object = {field: chinese_name(field) for field in fields}
    elif args.command == "snapshot":
        result = snapshot_tables(args.tables_dir, args.output)
    elif args.command == "migrate":
        result = migrate_tables(args.tables_dir, args.baseline)
    elif args.command == "validate":
        result = validate_tables(args.tables_dir)
    else:
        result = compare_baseline(args.tables_dir, args.baseline)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
