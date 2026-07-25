extends Node

const MainApp = preload("res://scripts/app/main.gd")
const BoardRules = preload("res://scripts/app/systems/board_rules.gd")

const GOLD_SKILLS = [
	"chicken",
	"pigeon",
	"dog",
	"squirrel",
	"pig",
	"otter",
	"cow",
]

var failures = 0
var app: Node


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	await get_tree().process_frame
	_test_gold_skill_configuration()
	_test_death_gold()
	_test_no_stale_interval_gold()
	_test_capture_gold()
	_test_ally_death_gold()
	if failures == 0:
		print("Animal gold economy tests passed.")
	app.queue_free()
	get_tree().quit(failures)


func _test_gold_skill_configuration() -> void:
	for card_id in GOLD_SKILLS:
		var card: Dictionary = app.call("_card_by_id", String(card_id))
		_expect_false(card.is_empty(), "%s exists" % card_id)
		if card.is_empty():
			continue
		var display_text = String(app.call("_card_display_skill_text", card, true))
		_expect_equal(
			display_text,
			String(card.get("skill_text", "")).strip_edges(),
			"%s displays only its cards.csv skill description" % card_id
		)


func _test_death_gold() -> void:
	_expect_death_gold("chicken", 1)
	_expect_death_gold("pigeon", 3)
	_expect_death_gold("pig", 0, 5)


func _expect_death_gold(card_id: String, owner_amount: int, enemy_amount: int = 0) -> void:
	_reset_and_spawn(card_id)
	var gold_before = int(app.get("gold"))
	var enemy_gold_before = int(app.get("enemy_gold"))
	app.call("_damage_unit", 0, 999.0, -1, BoardRules.ENEMY)
	_expect_equal(int(app.get("gold")), gold_before + owner_amount, "%s death credits the owner with %d gold" % [card_id, owner_amount])
	_expect_equal(int(app.get("enemy_gold")), enemy_gold_before + enemy_amount, "%s death credits the opposing side with %d gold" % [card_id, enemy_amount])


func _test_no_stale_interval_gold() -> void:
	_reset_and_spawn("hamster")
	var gold_before = int(app.get("gold"))
	app.call("_apply_unit_interval_skill", 0)
	_expect_equal(int(app.get("gold")), gold_before, "hamster no longer gains stale interval gold when its description is a death reward")


func _test_capture_gold() -> void:
	_reset_and_spawn("squirrel")
	var gold_before = int(app.get("gold"))
	app.call("_apply_unit_capture_skill", 0, Vector2i.ZERO)
	_expect_equal(int(app.get("gold")), gold_before + 5, "squirrel capture grants 5 gold")
	_reset_and_spawn("cow")
	gold_before = int(app.get("gold"))
	app.call("_apply_unit_capture_skill", 0, Vector2i.ZERO)
	_expect_equal(int(app.get("gold")), gold_before + 3, "cow capture grants 3 gold")


func _test_ally_death_gold() -> void:
	app.call("_reset_battle")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, "otter")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, "otter")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, "mouse")
	var gold_before = int(app.get("gold"))
	app.call("_damage_unit", 2, 999.0, -1, BoardRules.NEUTRAL)
	_expect_equal(int(app.get("gold")), gold_before + 2, "each living otter grants 1 gold when an ally dies")


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
