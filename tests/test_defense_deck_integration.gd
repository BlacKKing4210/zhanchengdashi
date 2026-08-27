extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const CardRules = preload("res://scripts/app/systems/card_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")

var failures = 0
var app


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	app.set("card_levels", {})
	_test_animal_resolution_uses_each_team_deck()
	_test_multiplayer_slots_keep_independent_deck_snapshots()
	_test_defense_resolution_uses_each_team_deck()
	_test_legendary_building_is_limited_per_battle()
	_test_defense_tower_combat_stats()
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
	var original_team_levels = (app.get("multiplayer_team_card_levels") as Dictionary).duplicate(true)
	var original_slots = (app.get("online_room_slots") as Array).duplicate(true)
	var original_humans = (app.get("room_human_teams") as Dictionary).duplicate(true)
	var original_deck = (app.get("deck") as Array).duplicate()
	var original_enemy_deck = (app.get("enemy_deck") as Array).duplicate()
	app.set("battle_mode", "multiplayer")
	app.set("room_active_team_ids", [1, 2, 4, 5])
	app.set("deck", ["gold_mine_card", "defense_watch_tower", "rabbit", "wolf"])
	app.set("enemy_deck", ["gold_mine_card", "defense_watch_tower", "mouse", "ant"])
	app.set("room_human_teams", {1: "自己", 2: "队友", 4: "对手"})
	app.set("online_room_slots", [
		{"team_id": 2, "kind": "human", "deck": ["gold_mine_card", "defense_watch_tower", "kangaroo"], "card_levels": {"kangaroo": 4}},
		{"team_id": 4, "kind": "human", "deck": ["gold_mine_card", "defense_watch_tower", "ant"], "card_levels": {"ant": 3}},
	])
	app.call("_init_multiplayer_state")
	var snapshots: Dictionary = app.get("multiplayer_team_decks")
	_expect_equal(snapshots.size(), 4, "2v2 creates one deck snapshot per active slot")
	_expect_equal(snapshots[2], ["gold_mine_card", "defense_watch_tower", "kangaroo"], "human teammate uses their server-synchronized deck")
	_expect_equal(snapshots[4], ["gold_mine_card", "defense_watch_tower", "ant"], "human opponent uses their server-synchronized deck")
	_expect_equal(int((app.get("multiplayer_team_card_levels") as Dictionary)[2].get("kangaroo", 0)), 4, "human teammate uses their own card level")
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
	app.set("multiplayer_team_card_levels", original_team_levels)
	app.set("online_room_slots", original_slots)
	app.set("room_human_teams", original_humans)
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


func _test_legendary_building_is_limited_per_battle() -> void:
	var original_deck = (app.get("deck") as Array).duplicate()
	var original_tiles = (app.get("tiles") as Dictionary).duplicate(true)
	var original_used = (app.get("team_spawned_legendary_buildings") as Dictionary).duplicate(true)
	app.set("deck", [
		"gold_mine_card",
		"defense_watch_tower",
		"defense_storm_obelisk",
		"rabbit",
	])
	app.set("team_spawned_legendary_buildings", {})
	var first_key = Vector2i(90, 1)
	var second_key = Vector2i(91, 1)
	var tower_tile = BoardRules.with_site(BoardRules.empty_locked_tile(), BoardRules.site_payload("tower", 250))
	app.set("tiles", {first_key: tower_tile.duplicate(true), second_key: tower_tile.duplicate(true)})

	_expect_true(bool(app.call("_is_legendary_building_card_id", "defense_storm_obelisk")), "storm obelisk is a legendary building")
	_expect_true(bool(app.call("_complete_building_unlock", first_key, BoardRules.PLAYER, "tower", "defense_storm_obelisk")), "first legendary building unlock succeeds")
	_expect_equal(String((app.get("tiles") as Dictionary)[first_key].get("site_card", "")), "defense_storm_obelisk", "first tile retains the legendary building card")
	_expect_false(bool(app.call("_can_spawn_building_card", BoardRules.PLAYER, "defense_storm_obelisk")), "used legendary building is blocked for the rest of the battle")
	_expect_equal(
		String(app.call("_defense_card_for_target_rarity", "legendary", 77, BoardRules.PLAYER)),
		"defense_watch_tower",
		"later legendary target falls back to an available lower-rarity building"
	)
	_expect_false(bool(app.call("_complete_building_unlock", second_key, BoardRules.PLAYER, "tower", "defense_storm_obelisk")), "second copy of the same legendary building is rejected")
	_expect_equal(String((app.get("tiles") as Dictionary)[second_key].get("building", "")), "", "rejected legendary building leaves the tile empty")

	app.set("deck", original_deck)
	app.set("tiles", original_tiles)
	app.set("team_spawned_legendary_buildings", original_used)


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


func _test_defense_tower_combat_stats() -> void:
	var expected = {
		"defense_watch_tower": [1, 5, 2.0, 1.5, ""],
		"defense_longshot_tower": [1, 5, 3.5, 1.5, "攻击距离+1.5，优先攻击远程"],
		"defense_cannon_tower": [2, 6, 2.0, 1.5, "攻击+1"],
		"defense_plunder_tower": [1, 7, 2.0, 1.5, "攻击时，掠夺1金币"],
		"defense_rapid_tower": [1, 6, 2.0, 0.5, "攻击速度+200%"],
		"defense_repair_beacon": [1, 21, 2.0, 1.5, "生命值+200%"],
		"defense_twinshot_tower": [1, 10, 3.0, 1.5, "攻击目标+1，攻击距离+1"],
		"defense_bounty_tower": [3, 12, 2.0, 1.5, "攻击+2，击杀时，获得10金币"],
		"defense_territory_tower": [1, 12, 2.0, 1.5, "无视攻击距离，只要敌人处于我方领地上即可攻击"],
		"defense_storm_obelisk": [1, 12, 2.0, 5.0, "每5秒对所有动物造成1点伤害"],
	}
	for card_id in expected.keys():
		var card: Dictionary = app.call("_card_by_id", card_id)
		_expect_false(card.is_empty(), "%s is available for combat stat checks" % card_id)
		if card.is_empty():
			continue
		var target: Array = expected[card_id]
		_expect_equal(String(card.get("skill_text", "")), String(target[4]), "%s exposes the full producer design in skill text" % card_id)
		for level in [1, 2, 3, 8, 10]:
			var adjusted_stats: Dictionary = app.call("_card_stats_with_levels", card, {card_id: level})
			_expect_equal(int(adjusted_stats.get("attack", 0)), int(target[0]), "%s level %d attack is the producer final value" % [card_id, level])
			_expect_equal(int(adjusted_stats.get("max_hp", 0)), int(target[1]), "%s level %d health is the producer final value" % [card_id, level])
			_expect_close(
				float(adjusted_stats.get("attack_range_cells", 0.0)),
				float(target[2]),
				"%s level %d range stays at the producer final tile distance" % [card_id, level]
			)
			_expect_close(
				float(adjusted_stats.get("attack_range", 0.0)),
				float(target[2]) * MainApp.HEX_SIZE,
				"%s level %d converts final tile distance to world units once" % [card_id, level]
			)
			_expect_close(
				float(adjusted_stats.get("summon_interval_sec", 0.0)),
				float(target[3]),
				"%s level %d interval is the producer final value" % [card_id, level]
			)
			app.set("card_levels", {card_id: level})
			_expect_close(
				float(app.call("_building_delay", "tower", BoardRules.PLAYER, card_id)),
				float(target[3]),
				"%s level %d building timer uses the producer final interval" % [card_id, level]
			)
	app.set("card_levels", {})


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


func _expect_close(actual: float, expected: float, label: String) -> void:
	if is_equal_approx(actual, expected):
		return
	failures += 1
	push_error("%s: expected %.3f, got %.3f" % [label, expected, actual])
