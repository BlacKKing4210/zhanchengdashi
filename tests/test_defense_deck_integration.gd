extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")

var failures = 0
var app


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	_test_defense_resolution_uses_each_team_deck()
	_test_green_defense_replacement_guard()
	if failures == 0:
		print("Defense deck integration tests passed.")
	app.queue_free()
	get_tree().quit(failures)


func _test_defense_resolution_uses_each_team_deck() -> void:
	var original_deck = (app.get("deck") as Array).duplicate()
	var original_enemy_deck = (app.get("enemy_deck") as Array).duplicate()
	app.set("deck", [
		"gold_mine_card",
		"defense_watch_tower",
		"defense_cannon_tower",
		"rabbit",
		"mouse",
		"ant",
		"sparrow",
		"frog",
	])
	app.set("enemy_deck", [
		"gold_mine_card",
		"defense_watch_tower",
		"rabbit",
		"mouse",
		"ant",
		"sparrow",
		"frog",
		"chicken",
	])
	_expect_equal(
		String(app.call("_defense_card_for_target_rarity", "legendary", 11, BoardRules.PLAYER)),
		"defense_cannon_tower",
		"player legendary target falls to the highest defense in player deck"
	)
	_expect_equal(
		String(app.call("_defense_card_for_target_rarity", "common", 13, BoardRules.PLAYER)),
		"defense_watch_tower",
		"common target uses common instead of a higher player defense"
	)
	_expect_equal(
		String(app.call("_defense_card_for_target_rarity", "legendary", 17, BoardRules.ENEMY)),
		"defense_watch_tower",
		"enemy resolves defenses only from enemy deck"
	)
	for roll_seed in range(1, 11):
		var pool_pick: Dictionary = app.call(
			"_roll_card_from_config_pool",
			"defense_cards_price_250",
			BoardRules.PLAYER,
			"defense",
			roll_seed
		)
		_expect_equal(
			String(pool_pick.get("card_id", "")),
			"defense_cannon_tower",
			"high-price defense pool cannot bypass the player's blue deck ceiling"
		)

	app.set("deck", [
		"gold_mine_card",
		"defense_cannon_tower",
		"defense_repair_beacon",
		"rabbit",
		"mouse",
		"ant",
		"sparrow",
		"frog",
	])
	_expect_equal(
		String(app.call("_defense_card_for_target_rarity", "common", 19, BoardRules.PLAYER)),
		"",
		"common target becomes empty when deck has only higher defenses"
	)
	app.set("deck", original_deck)
	app.set("enemy_deck", original_enemy_deck)


func _test_green_defense_replacement_guard() -> void:
	var original_deck = (app.get("deck") as Array).duplicate()
	var green_slot = original_deck.find("defense_watch_tower")
	_expect_true(green_slot >= 0, "default deck contains the mandatory green defense")
	if green_slot < 0:
		return
	var invalid_deck = original_deck.duplicate()
	invalid_deck[green_slot] = "defense_cannon_tower"
	_expect_false(bool(app.call("_deck_meets_required_cards", invalid_deck)), "blue defense cannot replace the last green defense")

	app.set("pending_equip_card_id", "defense_cannon_tower")
	app.set("toast_text", "")
	app.call("_equip_pending_card_to_slot", green_slot)
	_expect_equal(String((app.get("deck") as Array)[green_slot]), "defense_watch_tower", "blocked replacement keeps green defense slot")
	_expect_equal(String(app.get("pending_equip_card_id")), "defense_cannon_tower", "blocked replacement keeps selection pending")
	_expect_equal(String(app.get("toast_text")), "绿色防御塔必须在卡组中，否则会变成空地", "blocked replacement shows green defense warning")

	var animal_slot = -1
	for index in range(original_deck.size()):
		var card_id = String(original_deck[index])
		if card_id != "gold_mine_card" and card_id != "defense_watch_tower":
			animal_slot = index
			break
	_expect_true(animal_slot >= 0, "default deck contains a replaceable animal slot")
	if animal_slot >= 0:
		app.set("pending_equip_card_id", "defense_cannon_tower")
		app.call("_equip_pending_card_to_slot", animal_slot)
		_expect_equal(String((app.get("deck") as Array)[animal_slot]), "defense_cannon_tower", "higher defense can replace an animal while green remains")
		_expect_true((app.get("deck") as Array).has("defense_watch_tower"), "successful replacement preserves green defense")
	app.set("deck", original_deck)
	app.set("pending_equip_card_id", "")


func _expect_true(value: bool, label: String) -> void:
	if value:
		return
	failures += 1
	push_error("%s: expected true" % label)


func _expect_false(value: bool, label: String) -> void:
	if not value:
		return
	failures += 1
	push_error("%s: expected false" % label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])
