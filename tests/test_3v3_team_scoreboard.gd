extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")
const MultiplayerRules = preload("res://scripts/app/systems/multiplayer_rules.gd")

var failures = 0
var app: Node


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	await get_tree().process_frame
	_test_3v3_scoreboard_data_and_visibility()
	_test_3v3_scoreboard_uses_visual_ownership()
	_test_scoreboard_local_side_highlight_tracks_online_slot()
	_test_other_modes_hide_scoreboard()
	if failures == 0:
		print("3V3 team scoreboard tests passed.")
	app.queue_free()
	get_tree().quit(failures)


func _test_3v3_scoreboard_data_and_visibility() -> void:
	app.call("_start_multiplayer_match", "3v3_plateau", MultiplayerRules.MAX_PLAYERS_PER_SIDE)
	_expect_true(bool(app.call("_should_draw_3v3_team_scoreboard")), "3V3 team battle shows the faction scoreboard")
	var left_rect: Rect2 = app.call("_multiplayer_team_scoreboard_rect", 0)
	var right_rect: Rect2 = app.call("_multiplayer_team_scoreboard_rect", 1)
	var board_rect: Rect2 = app.call("_battle_view_rect")
	_expect_true(left_rect.end.y <= board_rect.position.y, "left scoreboard remains above the clickable board")
	_expect_true(right_rect.end.y <= board_rect.position.y, "right scoreboard remains above the clickable board")
	_expect_false(left_rect.intersects(right_rect), "two faction panels do not overlap")

	var entries: Array = app.call("_multiplayer_team_scoreboard_entries")
	_expect_equal(entries.size(), 2, "scoreboard publishes two factions")
	if entries.size() != 2:
		return
	var side_a: Dictionary = entries[0]
	var side_b: Dictionary = entries[1]
	_expect_equal(side_a.get("team_ids", []), [1, 2, 3], "A faction keeps the three warm slots")
	_expect_equal(side_b.get("team_ids", []), [4, 5, 6], "B faction keeps the three cool slots")
	_expect_equal(int(side_a.get("tiles", 0)), 108, "A faction starts with 108 visible tiles")
	_expect_equal(int(side_b.get("tiles", 0)), 108, "B faction starts with 108 visible tiles")
	_expect_true(bool(side_a.get("is_local", false)), "offline local player highlights A faction")
	_expect_false(bool(side_b.get("is_local", false)), "opponent faction is not marked local")
	_expect_team_colors(side_a, [1, 2, 3], "A faction color dots")
	_expect_team_colors(side_b, [4, 5, 6], "B faction color dots")


func _test_3v3_scoreboard_uses_visual_ownership() -> void:
	var source_key = _first_key_with_visual_owner(1)
	_expect_false(source_key == MultiplayerRules.INVALID_KEY, "3V3 fixture contains a warm-faction tile")
	if source_key == MultiplayerRules.INVALID_KEY:
		return
	var before_a = int(app.call("_multiplayer_side_visual_tile_count", 0))
	var before_b = int(app.call("_multiplayer_side_visual_tile_count", 1))
	var tile_map: Dictionary = app.get("tiles")
	tile_map[source_key] = BoardRules.with_soft_occupation(tile_map[source_key], 4)
	app.set("tiles", tile_map)
	_expect_equal(int(app.call("_multiplayer_side_visual_tile_count", 0)), before_a - 1, "soft occupation removes one visible tile from A")
	_expect_equal(int(app.call("_multiplayer_side_visual_tile_count", 1)), before_b + 1, "soft occupation adds one visible tile to B")
	var entries: Array = app.call("_multiplayer_team_scoreboard_entries")
	_expect_equal(int((entries[0] as Dictionary).get("tiles", 0)), before_a - 1, "A panel uses visible ownership")
	_expect_equal(int((entries[1] as Dictionary).get("tiles", 0)), before_b + 1, "B panel uses visible ownership")


func _test_scoreboard_local_side_highlight_tracks_online_slot() -> void:
	app.set("online_match_id", "scoreboard-test")
	app.set("local_team_id", 4)
	var entries: Array = app.call("_multiplayer_team_scoreboard_entries")
	_expect_false(bool((entries[0] as Dictionary).get("is_local", true)), "A faction loses local highlight for a B-side client")
	_expect_true(bool((entries[1] as Dictionary).get("is_local", false)), "B faction gains local highlight for a B-side client")
	app.set("online_match_id", "")
	app.set("local_team_id", BoardRules.PLAYER)


func _test_other_modes_hide_scoreboard() -> void:
	app.call("_start_multiplayer_match", "2v2_plateau", 2)
	_expect_false(bool(app.call("_should_draw_3v3_team_scoreboard")), "2V2 keeps its existing HUD")
	app.call("_start_multiplayer_match", "", MultiplayerRules.MAX_PLAYERS_PER_SIDE, true)
	_expect_false(bool(app.call("_should_draw_3v3_team_scoreboard")), "six-player free-for-all keeps its personal leaderboard")
	app.call("_return_to_lobby")


func _first_key_with_visual_owner(team: int) -> Vector2i:
	var tile_map: Dictionary = app.get("tiles")
	for key in tile_map.keys():
		var tile: Dictionary = tile_map[key]
		if BoardRules.visual_owner(tile) == team:
			return key
	return MultiplayerRules.INVALID_KEY


func _expect_team_colors(entry: Dictionary, teams: Array, label: String) -> void:
	var actual: Array = entry.get("team_colors", [])
	_expect_equal(actual.size(), teams.size(), "%s count" % label)
	for index in range(mini(actual.size(), teams.size())):
		var expected: Color = app.call("_team_color", int(teams[index]))
		var got: Color = actual[index]
		if not got.is_equal_approx(expected):
			failures += 1
			push_error("%s index %d: expected %s, got %s" % [label, index, str(expected), str(got)])


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
