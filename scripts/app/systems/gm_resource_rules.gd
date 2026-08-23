extends RefCounted

const RESOURCE_BATTLE_GOLD = "battle_gold"
const RESOURCE_GACHA_TICKETS = "gacha_tickets"
const RESOURCE_CARD_COUNT = "card_count"
const RESOURCE_CARD_LEVEL = "card_level"

const OPERATION_ADD = "add"
const OPERATION_SUBTRACT = "subtract"
const OPERATION_SET = "set"

const MAX_RESOURCE_VALUE = 1_000_000
const MIN_CARD_LEVEL = 1
const MAX_CARD_LEVEL = 10


static func resource_options() -> Array[Dictionary]:
	return [
		{"id": RESOURCE_BATTLE_GOLD, "label": "战斗金币"},
		{"id": RESOURCE_GACHA_TICKETS, "label": "抽卡券"},
		{"id": RESOURCE_CARD_COUNT, "label": "卡牌数量"},
		{"id": RESOURCE_CARD_LEVEL, "label": "卡牌等级"},
	]


static func operation_options() -> Array[Dictionary]:
	return [
		{"id": OPERATION_ADD, "label": "增加"},
		{"id": OPERATION_SUBTRACT, "label": "减少"},
		{"id": OPERATION_SET, "label": "设为"},
	]


static func uses_card(resource_id: String) -> bool:
	return resource_id == RESOURCE_CARD_COUNT or resource_id == RESOURCE_CARD_LEVEL


static func resource_label(resource_id: String) -> String:
	for option in resource_options():
		if String(option.get("id", "")) == resource_id:
			return String(option.get("label", resource_id))
	return resource_id


static func availability(resource_id: String, context: Dictionary) -> Dictionary:
	if not bool(context.get("debug_build", false)):
		return _denied("GM 面板仅在调试构建中可用")
	if bool(context.get("online_match_active", false)):
		return _denied("互联网对战期间禁止使用 GM 操作")
	if resource_id == RESOURCE_BATTLE_GOLD:
		if not bool(context.get("classic_battle_active", false)):
			return _denied("战斗金币仅可在本地单人战斗中修改")
		return _allowed()
	if resource_id in [RESOURCE_GACHA_TICKETS, RESOURCE_CARD_COUNT, RESOURCE_CARD_LEVEL]:
		if bool(context.get("logged_in", false)):
			return _denied("已登录账号的账户资源受服务器保护；请退出登录后修改本地测试数据")
		return _allowed()
	return _denied("未知资源")


static func evaluate(
	resource_id: String,
	operation_id: String,
	amount_text: String,
	current_value: int,
	context: Dictionary,
	card_id: String = ""
) -> Dictionary:
	var availability_result = availability(resource_id, context)
	if not bool(availability_result.get("ok", false)):
		return availability_result
	if uses_card(resource_id) and card_id.strip_edges().is_empty():
		return _denied("请选择卡牌")
	if operation_id not in [OPERATION_ADD, OPERATION_SUBTRACT, OPERATION_SET]:
		return _denied("未知操作")

	var parsed_amount = _parse_amount(amount_text)
	if not bool(parsed_amount.get("ok", false)):
		return parsed_amount
	var amount = int(parsed_amount.get("value", 0))
	var next_value = current_value
	match operation_id:
		OPERATION_ADD:
			next_value = current_value + amount
		OPERATION_SUBTRACT:
			next_value = current_value - amount
		OPERATION_SET:
			next_value = amount

	var bounds = _resource_bounds(resource_id)
	var minimum = int(bounds.x)
	var maximum = int(bounds.y)
	if next_value < minimum or next_value > maximum:
		return _denied("结果必须在 %d 到 %d 之间" % [minimum, maximum])
	return {
		"ok": true,
		"message": "%s已修改：%d → %d" % [resource_label(resource_id), current_value, next_value],
		"next_value": next_value,
	}


static func _parse_amount(amount_text: String) -> Dictionary:
	var normalized = amount_text.strip_edges()
	if normalized.is_empty():
		return _denied("请输入整数数值")
	if normalized.length() > 10 or not normalized.is_valid_int():
		return _denied("数值必须是 0 到 1000000 的整数")
	var value = int(normalized)
	if value < 0 or value > MAX_RESOURCE_VALUE:
		return _denied("数值必须是 0 到 1000000 的整数")
	return {"ok": true, "value": value}


static func _resource_bounds(resource_id: String) -> Vector2i:
	if resource_id == RESOURCE_CARD_LEVEL:
		return Vector2i(MIN_CARD_LEVEL, MAX_CARD_LEVEL)
	return Vector2i(0, MAX_RESOURCE_VALUE)


static func _allowed() -> Dictionary:
	return {"ok": true, "message": ""}


static func _denied(message: String) -> Dictionary:
	return {"ok": false, "message": message}
