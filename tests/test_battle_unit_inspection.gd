extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MultiplayerRules = preload("res://scripts/app/systems/multiplayer_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")

var failures = 0
var app: Node


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	await get_tree().process_frame
	_test_animal_tap_wins_over_tile_selection()
	_test_animal_tap_does_not_unlock_underlying_tile()
	_test_selection_tracks_stable_unit_id()
	_test_invalid_selection_clears_after_unit_disappears()
	_test_status_and_empty_skill_contracts()
	_test_animal_card_range_is_part_of_skill_text()
	_test_battle_summary_title_contract()
	_test_building_card_preview_contract()
	if failures == 0:
		print("Battle unit inspection tests passed.")
	app.queue_free()
	get_tree().quit(failures)


func _reset_with_animals() -> Array:
	app.set("battle_mode", "classic")
	app.set("screen", "battle")
	app.call("_reset_battle")
	app.call("_layout", app.get_viewport().get_visible_rect().size)
	var player_base: Vector2i = app.call("_battle_base_key", BoardRules.PLAYER)
	var enemy_base: Vector2i = app.call("_battle_base_key", BoardRules.ENEMY)
	app.call("_spawn_unit", BoardRules.PLAYER, player_base, "rabbit")
	app.call("_spawn_unit", BoardRules.ENEMY, enemy_base, "duck")
	var spawned_units = app.get("units")
	return spawned_units as Array


func _tap_unit(unit: Dictionary) -> void:
	var canvas_pos: Vector2 = app.call("_world_to_canvas", Vector2(unit.get("pos", Vector2.ZERO)))
	canvas_pos += Vector2(0.0, -8.0)
	var scale = float(app.get("canvas_scale"))
	var offset: Vector2 = app.get("canvas_offset")
	app.call("_handle_tap", offset + canvas_pos * scale)


func _tap_canvas_pos(canvas_pos: Vector2) -> void:
	var scale = float(app.get("canvas_scale"))
	var offset: Vector2 = app.get("canvas_offset")
	app.call("_handle_tap", offset + canvas_pos * scale)


func _first_affordable_unlockable_key() -> Vector2i:
	var tiles: Dictionary = app.get("tiles")
	var available_gold = int(app.get("gold"))
	var battle_view: Rect2 = app.call("_battle_view_rect")
	for key_value in tiles.keys():
		var key: Vector2i = key_value
		var world_pos: Vector2 = app.call("_hex_center", key)
		var canvas_pos: Vector2 = app.call("_world_to_canvas", world_pos)
		if not battle_view.has_point(canvas_pos):
			continue
		if bool(app.call("_can_unlock", key, BoardRules.PLAYER)) and int(app.call("_unlock_cost", key, BoardRules.PLAYER)) <= available_gold:
			return key
	return MultiplayerRules.INVALID_KEY


func _test_animal_tap_wins_over_tile_selection() -> void:
	var units: Array = _reset_with_animals()
	_expect_true(units.size() >= 2, "inspection test has two live animals")
	if units.size() < 2:
		return
	var player_unit: Dictionary = units[0]
	app.set("selected_tile", Vector2i(9, 9))
	_tap_unit(player_unit)
	_expect_equal(int(app.get("selected_unit_id")), int(player_unit.get("id", -1)), "tapping an animal selects its stable id")
	_expect_equal(app.get("selected_tile"), MultiplayerRules.INVALID_KEY, "animal tap clears the underlying tile selection")
	var selected: Dictionary = app.call("_selected_unit")
	_expect_equal(String(selected.get("card", "")), "rabbit", "bottom-panel data resolves the tapped animal")

	var battle_view: Rect2 = app.call("_battle_view_rect")
	var blank_canvas = battle_view.position + Vector2(8.0, 8.0)
	if int(app.call("_unit_index_at_canvas", blank_canvas)) >= 0:
		blank_canvas = battle_view.position + Vector2(8.0, battle_view.size.y - 8.0)
	var offset: Vector2 = app.get("canvas_offset")
	var scale = float(app.get("canvas_scale"))
	app.call("_handle_tap", offset + blank_canvas * scale)
	_expect_equal(int(app.get("selected_unit_id")), -1, "blank battle tap clears animal selection")


func _test_animal_tap_does_not_unlock_underlying_tile() -> void:
	app.set("battle_mode", "classic")
	app.set("screen", "battle")
	app.call("_reset_battle")
	app.call("_layout", app.get_viewport().get_visible_rect().size)
	var key = _first_affordable_unlockable_key()
	_expect_true(key != MultiplayerRules.INVALID_KEY, "inspection test finds an affordable player unlock")
	if key == MultiplayerRules.INVALID_KEY:
		return
	app.call("_spawn_unit", BoardRules.PLAYER, key, "rabbit")
	var units: Array = app.get("units")
	_expect_true(not units.is_empty(), "test animal spawns on the purchasable tile")
	if units.is_empty():
		return
	var tiles_before: Dictionary = app.get("tiles")
	var tile_before: Dictionary = (tiles_before[key] as Dictionary).duplicate(true)
	var gold_before = int(app.get("gold"))
	_tap_unit(units[0])
	var tiles_after_animal_tap: Dictionary = app.get("tiles")
	_expect_equal(tiles_after_animal_tap[key], tile_before, "animal tap leaves its purchasable tile unchanged")
	_expect_equal(int(app.get("gold")), gold_before, "animal tap does not spend tile-unlock gold")

	app.set("units", [])
	app.set("selected_unit_id", -1)
	var tile_world_pos: Vector2 = app.call("_hex_center", key)
	var tile_canvas_pos: Vector2 = app.call("_world_to_canvas", tile_world_pos)
	_tap_canvas_pos(tile_canvas_pos)
	var tiles_after_tile_tap: Dictionary = app.get("tiles")
	_expect_true(tiles_after_tile_tap[key] != tile_before, "the same tile unlocks normally after the animal is gone")


func _test_selection_tracks_stable_unit_id() -> void:
	var units: Array = _reset_with_animals()
	if units.size() < 2:
		return
	var chosen: Dictionary = units[1]
	app.set("selected_unit_id", int(chosen.get("id", -1)))
	app.set("units", [units[1], units[0]])
	var selected: Dictionary = app.call("_selected_unit")
	_expect_equal(int(selected.get("id", -1)), int(chosen.get("id", -1)), "selection survives unit-array reorder by id")
	_expect_equal(String(selected.get("card", "")), "duck", "selection keeps the intended animal after reorder")


func _test_invalid_selection_clears_after_unit_disappears() -> void:
	var units: Array = _reset_with_animals()
	if units.is_empty():
		return
	app.set("selected_unit_id", int((units[0] as Dictionary).get("id", -1)))
	app.call("_damage_unit", 0, 999.0, -1, BoardRules.NEUTRAL)
	_expect_equal(int(app.get("selected_unit_id")), -1, "unit death clears the bottom-panel selection immediately")

	units = _reset_with_animals()
	if units.is_empty():
		return
	app.set("selected_unit_id", int((units[0] as Dictionary).get("id", -1)))
	app.set("units", [])
	app.call("_clear_selected_unit_if_invalid")
	_expect_equal(int(app.get("selected_unit_id")), -1, "removed unit clears the bottom-panel selection")

	units = _reset_with_animals()
	if units.is_empty():
		return
	app.set("online_match_id", "unit-inspection-snapshot")
	app.set("selected_unit_id", int((units[0] as Dictionary).get("id", -1)))
	app.call("_apply_online_battle_snapshot", {"match_id": "unit-inspection-snapshot", "units": []})
	_expect_equal(int(app.get("selected_unit_id")), -1, "online snapshot removal clears the bottom-panel selection")
	app.set("online_match_id", "")


func _test_status_and_empty_skill_contracts() -> void:
	var units: Array = _reset_with_animals()
	if units.is_empty():
		return
	var unit: Dictionary = (units[0] as Dictionary).duplicate(true)
	unit["shield"] = 2.0
	unit["stun_timer"] = 1.2
	unit["slow_timer"] = 0.8
	unit["poison_timer"] = 0.6
	unit["haste_timer"] = 0.4
	var status_text = String(app.call("_unit_status_text", unit))
	for expected in ["盾2", "晕1.2s", "缓0.8s", "毒0.6s", "快0.4s"]:
		_expect_true(status_text.contains(expected), "active status %s is available to the unit panel" % expected)
	var duck: Dictionary = app.call("_card_by_id", "duck")
	_expect_equal(String(app.call("_card_skill_text", duck)), "", "empty skill_text remains empty for the unit panel")


func _test_animal_card_range_is_part_of_skill_text() -> void:
	var rabbit: Dictionary = app.call("_card_by_id", "rabbit")
	var sparrow: Dictionary = app.call("_card_by_id", "sparrow")
	var parrot: Dictionary = app.call("_card_by_id", "parrot")
	var eagle: Dictionary = app.call("_card_by_id", "eagle")
	_expect_equal(String(app.call("_card_ui_skill_text", rabbit)), "", "melee animal with no authored skill shows no synthetic skill")
	_expect_equal(String(app.call("_card_ui_skill_text", sparrow)), "远程", "ranged animal with no authored skill shows range in the skill area")
	_expect_true(String(app.call("_card_ui_skill_text", parrot)).begins_with("远程 · "), "ranged animal prefixes its authored skill with range")
	_expect_true(String(app.call("_card_ui_skill_text", eagle)).begins_with("超远程 · "), "ultra-ranged animal prefixes its authored skill with range")


func _test_battle_summary_title_contract() -> void:
	var units: Array = _reset_with_animals()
	if units.is_empty():
		return
	var unit: Dictionary = units[0]
	var card: Dictionary = app.call("_card_by_id", String(unit.get("card", "rabbit")))
	var animal_name = String(card.get("name", ""))
	var rarity_label = String(app.call("_rarity_label", String(card.get("rarity", "common"))))
	var selected_title = String(app.call("_unit_card_summary_title", unit, card))
	var camp_title = String(app.call("_building_animal_card_summary_title", card, int(unit.get("team", BoardRules.PLAYER))))
	_expect_equal(_substring_count(selected_title, animal_name), 1, "selected-animal summary shows the animal name exactly once")
	_expect_true(not selected_title.contains(rarity_label), "selected-animal summary omits the rarity label")
	_expect_equal(_substring_count(camp_title, animal_name), 1, "camp-animal summary shows the animal name exactly once")
	_expect_true(not camp_title.contains(rarity_label), "camp-animal summary omits the rarity label")


func _substring_count(text: String, needle: String) -> int:
	if needle == "":
		return 0
	return text.split(needle).size() - 1


func _test_building_card_preview_contract() -> void:
	app.call("_clear_building_card_preview", true)
	var audio = get_node_or_null("/root/GameAudio")
	var camp = {
		"building": "barracks",
		"site_card": "mouse",
		"team": BoardRules.PLAYER,
	}
	_expect_true(bool(app.call("_show_building_card_preview", camp)), "animal camp opens its corresponding animal card")
	_expect_equal(String(app.get("selected_building_card_id")), "mouse", "animal camp preview stores the corresponding card id")
	_expect_equal(float(app.get("selected_building_card_timer")), 3.0, "animal camp preview starts at three seconds")
	if audio != null:
		_expect_equal(String(audio.get("active_voice_card_id")), "mouse", "animal camp requests its matching skill voice")
		var pending_camp = camp.duplicate(true)
		pending_camp["site_card"] = "ant"
		_expect_true(bool(app.call("_show_building_card_preview", pending_camp)), "pending voice does not block the visual animal card")
		_expect_equal(String(audio.get("active_voice_card_id")), "", "pending voice request stops the previous animal voice")
		var silent_ranged_camp = camp.duplicate(true)
		silent_ranged_camp["site_card"] = "sparrow"
		_expect_true(bool(app.call("_show_building_card_preview", silent_ranged_camp)), "ranged animal without skill description still shows its card")
		_expect_equal(String(audio.get("active_voice_card_id")), "", "animal without authored skill description stays silent")
		app.call("_show_building_card_preview", camp)
	app.call("_update_building_card_preview", 2.99)
	_expect_equal(String(app.get("selected_building_card_id")), "mouse", "animal camp card remains visible before three seconds")
	app.call("_update_building_card_preview", 0.02)
	_expect_equal(String(app.get("selected_building_card_id")), "", "animal camp card disappears after three seconds")

	for building in ["tower", "mine", "base"]:
		var non_animal_building = {
			"building": building,
			"site_card": "mouse",
			"team": BoardRules.PLAYER,
		}
		_expect_true(not bool(app.call("_show_building_card_preview", non_animal_building)), "%s never invents an animal-card preview" % building)
	_expect_true(not bool(app.call("_show_building_card_preview", {"building": "hall", "site_card": "", "team": BoardRules.PLAYER})), "camp without a valid animal card shows no building information")

	var preview_key = Vector2i(33, 44)
	var tiles: Dictionary = app.get("tiles")
	tiles[preview_key] = camp.duplicate(true)
	_expect_true(bool(app.call("_show_building_card_preview", tiles[preview_key], preview_key)), "live tile preview records its board key")
	var changed_camp: Dictionary = tiles[preview_key]
	changed_camp["team"] = BoardRules.ENEMY
	tiles[preview_key] = changed_camp
	app.call("_update_building_card_preview", 0.0)
	_expect_equal(String(app.get("selected_building_card_id")), "", "camp ownership change invalidates stale preview and voice")
	tiles.erase(preview_key)
	app.call("_clear_building_card_preview", true)


func _expect_true(value: bool, label: String) -> void:
	if value:
		return
	failures += 1
	push_error("%s: expected true" % label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])
