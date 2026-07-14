extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")

var failures = 0
var app


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	_test_animal_resolution_uses_each_team_deck()
	_test_multiplayer_slots_keep_independent_deck_snapshots()
	_test_defense_resolution_uses_each_team_deck()
	_test_green_defense_replacement_guard()
	if failures == 0:
		print("Defense deck integration tests passed.")
	app.queue_free()
	get_tree().quit(failures)


func _test_animal_resolution_uses_each_team_deck() -> void:
	var original_deck = (app.get("deck") as Array).duplicate()
	var original_enemy_deck = (app.get("enemy_deck") as Array).duplicate()
	var player_deck = [
		"gold_mine_card",
		"defense_watch_tower",
		"rabbit",
		"wolf",
	]
	var enemy_roster = [
		"gold_mine_card",
		"defense_watch_tower",
		"mouse",
		"kangaroo",
	]
	app.set("deck", player_deck)
	app.set("enemy_deck", enemy_roster)
	_expect_equal(String(app.call("_deck_card_for_target_rarity", player_deck, "legendary", 7, "animal")), "wolf", "legendary animal target falls to the player's highest lower rarity")
	_expect_equal(String(app.call("_deck_card_for_target_rarity", player_deck, "rare", 11, "animal")), "rabbit", "rare animal target skips the higher epic card and falls to common")
	_expect_equal(String(app.call("_deck_card_for_target_rarity", ["wolf"], "common", 13, "animal")), "", "common animal target never advances to epic")
	_expect_false(bool(app.call("_can_use_config_card", "unit_beast_swift_fox", player_deck, "animal")), "configured animal outside the player's deck is rejected")
	for roll_seed in range(1, 41):
		var player_pick: Dictionary = app.call("_roll_card_from_config_pool", "unit_cards_price_250", BoardRules.PLAYER, "animal", roll_seed)
		var enemy_pick: Dictionary = app.call("_roll_card_from_config_pool", "unit_cards_price_250", BoardRules.ENEMY, "animal", roll_seed)
		_expect_true(String(player_pick.get("card_id", "")) in ["rabbit", "wolf"], "player pool roll stays inside the player's animal deck")
		_expect_true(String(enemy_pick.get("card_id", "")) in ["mouse", "kangaroo"], "enemy pool roll stays inside the enemy animal deck")
	app.set("deck", original_deck)
	app.set("enemy_deck", original_enemy_deck)


func _test_multiplayer_slots_keep_independent_deck_snapshots() -> void:
	var original_mode = String(app.get("battle_mode"))
	var original_active_teams = (app.get("room_active_team_ids") as Array).duplicate()
	var original_team_decks = (app.get("multiplayer_team_decks") as Dictionary).duplicate(true)
	var original_deck = (app.get("deck") as Array).duplicate()
	var original_enemy_deck = (app.get("enemy_deck") as Array).duplicate()
	app.set("battle_mode", "multiplayer")
	app.set("room_active_team_ids", [1, 2, 4, 5])
	app.set("deck", ["gold_mine_card", "defense_watch_tower", "rabbit", "wolf"])
	app.set("enemy_deck", ["gold_mine_card", "defense_watch_tower", "mouse", "ant"])
	app.call("_init_multiplayer_state")
	var snapshots: Dictionary = app.get("multiplayer_team_decks")
	_expect_equal(snapshots.size(), 4, "2v2 creates one deck snapshot per active slot")
	var team_two: Array = snapshots[2]
	team_two.append("kangaroo")
	snapshots[2] = team_two
	app.set("multiplayer_team_decks", snapshots)
	_expect_false((snapshots[4] as Array).has("kangaroo"), "mutating team two's snapshot cannot alter team four")
	snapshots[2] = ["gold_mine_card", "defense_watch_tower", "defense_cannon_tower", "mouse", "kangaroo"]
	snapshots[4] = ["gold_mine_card", "defense_watch_tower", "ant"]
	app.set("multiplayer_team_decks", snapshots)
	_expect_equal(String(app.call("_defense_card_for_target_rarity", "legendary", 31, 2)), "defense_cannon_tower", "team two defense falls only to its own blue tower")
	_expect_equal(String(app.call("_defense_card_for_target_rarity", "legendary", 31, 4)), "defense_watch_tower", "team four defense falls only to its own green tower")
	for roll_seed in range(1, 21):
		var team_two_pick: Dictionary = app.call("_roll_card_from_config_pool", "unit_cards_price_250", 2, "animal", roll_seed)
		var team_four_pick: Dictionary = app.call("_roll_card_from_config_pool", "unit_cards_price_250", 4, "animal", roll_seed)
		_expect_true(String(team_two_pick.get("card_id", "")) in ["mouse", "kangaroo"], "team two resolves only from its own snapshot")
		_expect_equal(String(team_four_pick.get("card_id", "")), "ant", "team four resolves only from its own snapshot")
	app.set("battle_mode", original_mode)
	app.set("room_active_team_ids", original_active_teams)
	app.set("multiplayer_team_decks", original_team_decks)
	app.set("deck", original_deck)
	app.set("enemy_deck", original_enemy_deck)


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
