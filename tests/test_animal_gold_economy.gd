extends Node

const MainApp = preload("res://scripts/app/main.gd")
const BoardRules = preload("res://scripts/app/systems/board_rules.gd")

const GOLD_SKILLS = [
	{"id": "chicken", "trigger": "on_death", "amount": 8, "chance": 1.0},
	{"id": "pigeon", "trigger": "on_death", "amount": 24, "chance": 1.0},
	{"id": "hamster", "trigger": "on_interval", "amount": 10, "chance": 1.0},
	{"id": "dog", "trigger": "on_attack", "amount": 5, "chance": 0.35},
	{"id": "squirrel", "trigger": "on_capture", "amount": 8, "chance": 1.0},
	{"id": "pig", "trigger": "on_death", "amount": 40, "chance": 1.0},
	{"id": "otter", "trigger": "on_ally_death", "amount": 10, "chance": 1.0},
	{"id": "cow", "trigger": "on_capture", "amount": 10, "chance": 1.0},
]

var failures = 0
var app: Node


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	await get_tree().process_frame
	_test_gold_skill_configuration()
	_test_death_gold()
	_test_interval_gold()
	_test_attack_gold()
	_test_capture_gold()
	_test_ally_death_gold()
	if failures == 0:
		print("Animal gold economy tests passed.")
	app.queue_free()
	get_tree().quit(failures)


func _test_gold_skill_configuration() -> void:
	for expected in GOLD_SKILLS:
		var card: Dictionary = app.call("_card_by_id", String(expected["id"]))
		_expect_false(card.is_empty(), "%s exists" % expected["id"])
		if card.is_empty():
			continue
		_expect_equal(String(card.get("skill_trigger", "")), String(expected["trigger"]), "%s uses the configured gold trigger" % expected["id"])
		_expect_equal(String(card.get("skill_effect", "")), "gold", "%s uses a structured gold effect" % expected["id"])
		_expect_equal(int(roundi(float(card.get("skill_power", 0.0)))), int(expected["amount"]), "%s uses the tuned gold amount" % expected["id"])
		_expect_close(float(card.get("skill_chance", 1.0)), float(expected["chance"]), "%s uses the configured gold chance" % expected["id"])
		_expect_equal(String(card.get("skill_text", "")), "", "%s leaves display text to the structured skill data" % expected["id"])
		_expect_true(String(app.call("_card_display_skill_text", card, true)).contains(str(expected["amount"])), "%s displays its real gold amount" % expected["id"])


func _test_death_gold() -> void:
	_expect_death_gold("chicken", 8)
	_expect_death_gold("pigeon", 24)
	_expect_death_gold("pig", 40)


func _expect_death_gold(card_id: String, amount: int) -> void:
	_reset_and_spawn(card_id)
	var gold_before = int(app.get("gold"))
	var enemy_gold_before = int(app.get("enemy_gold"))
	app.call("_damage_unit", 0, 999.0, -1, BoardRules.NEUTRAL)
	_expect_equal(int(app.get("gold")), gold_before + amount, "%s death credits the owner with %d gold" % [card_id, amount])
	_expect_equal(int(app.get("enemy_gold")), enemy_gold_before, "%s death does not credit the opposing side" % card_id)


func _test_interval_gold() -> void:
	_reset_and_spawn("hamster")
	var gold_before = int(app.get("gold"))
	app.call("_apply_unit_interval_skill", 0)
	_expect_equal(int(app.get("gold")), gold_before + 10, "hamster interval skill grants 10 gold")


func _test_attack_gold() -> void:
	_reset_and_spawn("dog")
	var units: Array = app.get("units")
	units[0]["skill_chance"] = 1.0
	app.set("units", units)
	var gold_before = int(app.get("gold"))
	app.call("_apply_unit_attack_skill", 0, {})
	_expect_equal(int(app.get("gold")), gold_before + 5, "dog successful gold proc grants 5 gold")


func _test_capture_gold() -> void:
	_reset_and_spawn("squirrel")
	var gold_before = int(app.get("gold"))
	app.call("_apply_unit_capture_skill", 0, Vector2i.ZERO)
	_expect_equal(int(app.get("gold")), gold_before + 8, "squirrel capture grants 8 gold")
	_reset_and_spawn("cow")
	gold_before = int(app.get("gold"))
	app.call("_apply_unit_capture_skill", 0, Vector2i.ZERO)
	_expect_equal(int(app.get("gold")), gold_before + 10, "cow capture grants 10 gold")


func _test_ally_death_gold() -> void:
	app.call("_reset_battle")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, "otter")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, "otter")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, "mouse")
	var gold_before = int(app.get("gold"))
	app.call("_damage_unit", 2, 999.0, -1, BoardRules.NEUTRAL)
	_expect_equal(int(app.get("gold")), gold_before + 20, "each living otter grants 10 gold when an ally dies")


func _reset_and_spawn(card_id: String) -> void:
	app.call("_reset_battle")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, card_id)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _expect_true(value: bool, label: String) -> void:
	if value:
		return
	failures += 1
	push_error(label)


func _expect_false(value: bool, label: String) -> void:
	_expect_true(not value, label)


func _expect_close(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) <= 0.001:
		return
	failures += 1
	push_error("%s: expected %.3f, got %.3f" % [label, expected, actual])
