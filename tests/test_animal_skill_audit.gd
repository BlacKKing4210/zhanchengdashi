extends Node

const MainApp = preload("res://scripts/app/main.gd")
const BoardRules = preload("res://scripts/app/systems/board_rules.gd")

const SUPPORTED_EFFECTS = {
	"aura": ["buff_attack", "buff_hp", "buff_speed", "shield"],
	"on_spawn": ["gold", "shield", "buff_attack", "buff_hp", "buff_speed", "stun", "copy"],
	"on_attack": ["gold", "slow", "stun", "damage", "shield", "execute"],
	"on_damage": ["gold", "heal", "shield", "thorns"],
	"on_death": ["gold", "summon"],
	"on_ally_death": ["gold"],
	"on_capture": ["gold"],
	"on_interval": ["gold", "heal", "shield", "repair"],
}

var failures = 0
var app: Node


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	await get_tree().process_frame
	_test_structured_animal_skill_contracts()
	_test_duck_death_summon_feedback()
	if failures == 0:
		print("Animal skill audit tests passed.")
	app.queue_free()
	get_tree().quit(failures)


func _test_structured_animal_skill_contracts() -> void:
	var structured_count = 0
	for card in app.get("cards"):
		if String(app.call("_card_kind", card)) != "animal":
			continue
		var trigger = String(card.get("skill_trigger", ""))
		var effect = String(card.get("skill_effect", ""))
		if trigger.is_empty() and effect.is_empty():
			continue
		structured_count += 1
		_expect_true(SUPPORTED_EFFECTS.has(trigger), "%s uses a known trigger %s" % [card.get("id", ""), trigger])
		_expect_true(
			SUPPORTED_EFFECTS.has(trigger) and (SUPPORTED_EFFECTS[trigger] as Array).has(effect),
			"%s uses a supported %s/%s effect pair" % [card.get("id", ""), trigger, effect]
		)
	_expect_true(structured_count > 0, "animal skill audit finds structured cards")


func _test_duck_death_summon_feedback() -> void:
	app.call("_reset_battle")
	var duck = app.call("_card_by_id", "duck")
	_expect_equal(
		String(app.call("_card_display_skill_text", duck, true)),
		"阵亡时，在原位置召唤1只鸭",
		"duck card detail says exactly when its replacement is summoned"
	)
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, "duck")
	_expect_true((app.get("units") as Array).size() == 1, "duck enters the battle")
	app.call("_damage_unit", 0, 999.0, -1, BoardRules.NEUTRAL)
	var units: Array = app.get("units")
	_expect_equal(units.size(), 2, "duck death creates exactly one replacement duck")
	if units.size() >= 2:
		_expect_equal(String(units[units.size() - 1].get("card", "")), "duck", "duck replacement preserves its card id")
		_expect_false(bool(units[units.size() - 1].get("skill_triggers_enabled", true)), "duck replacement cannot trigger skills again")
		app.call("_damage_unit", units.size() - 1, 999.0, -1, BoardRules.NEUTRAL)
		_expect_equal((app.get("units") as Array).size(), 2, "disabled duck replacement does not create a third duck")
	var has_summon_feedback = false
	for effect in app.get("effects"):
		if String(effect.get("kind", "")) == "unit_value" and String(effect.get("stat", "")) == "summon":
			has_summon_feedback = true
	_expect_true(has_summon_feedback, "duck replacement creates a visible summon feedback effect")
	_test_non_cyclic_death_summon_keeps_skills()


func _test_non_cyclic_death_summon_keeps_skills() -> void:
	app.call("_reset_battle")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, "silverback")
	app.call("_damage_unit", 0, 999.0, -1, BoardRules.NEUTRAL)
	var units: Array = app.get("units")
	_expect_equal(units.size(), 2, "silverback death creates one gorilla")
	if units.size() >= 2:
		var replacement: Dictionary = units[units.size() - 1]
		_expect_equal(String(replacement.get("card", "")), "gorilla", "silverback keeps its intended non-cyclic summon")
		_expect_true(bool(replacement.get("skill_triggers_enabled", false)), "non-cyclic death summon retains skill triggers")


func _expect_true(value: bool, label: String) -> void:
	if value:
		return
	failures += 1
	push_error(label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _expect_false(value: bool, label: String) -> void:
	_expect_true(not value, label)
