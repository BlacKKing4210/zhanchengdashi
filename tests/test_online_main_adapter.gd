extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MultiplayerRules = preload("res://scripts/app/systems/multiplayer_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")
const OnlineRoomTransport = preload("res://scripts/network/online_room.gd")

var failures = 0
var app: Node


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	await get_tree().process_frame
	_test_room_layout_targets()
	_test_legacy_server_profile_without_rank_mirrors()
	_test_room_snapshot_and_match_bridge()
	_test_side_b_authority_receives_victory()
	_test_three_vs_three_snapshot_budget()
	if failures == 0:
		print("Online main adapter tests passed.")
	app.queue_free()
	get_tree().quit(failures)


func _test_room_layout_targets() -> void:
	var create_rect: Rect2 = app.call("_room_online_create_rect")
	var code_rect: Rect2 = app.call("_room_online_code_input_rect")
	var join_rect: Rect2 = app.call("_room_online_join_rect")
	var fill_rect: Rect2 = app.call("_room_entry_ai_fill_rect")
	var retry_rect: Rect2 = app.call("_room_online_retry_rect")
	_expect_false(create_rect.intersects(code_rect), "create and join-code targets do not overlap")
	_expect_false(code_rect.intersects(join_rect), "code input and join button remain distinct")
	_expect_false(fill_rect.intersects(retry_rect), "AI preference and reconnect targets do not overlap")
	var ready_rect: Rect2 = app.call("_room_ready_rect")
	var leave_rect: Rect2 = app.call("_room_leave_rect")
	var start_rect: Rect2 = app.call("_room_start_rect")
	_expect_false(ready_rect.intersects(leave_rect), "ready and leave targets remain distinct")
	_expect_false(ready_rect.intersects(start_rect), "ready target does not cover the start button")
	_expect_false(leave_rect.intersects(start_rect), "leave target does not cover the start button")
	_expect_true(start_rect.end.y < 1138.0, "internet room actions stay above bottom navigation")


func _test_legacy_server_profile_without_rank_mirrors() -> void:
	var existing_mirrors = {"silver": [{"deck": ["rabbit"]}]}
	app.set("rank_db", {
		"version": 2,
		"player": (app.call("_player_profile") as Dictionary).duplicate(true),
		"mirrors": existing_mirrors.duplicate(true),
	})
	app.call("_apply_server_profile", {
		"gacha_tickets": 10,
		"rank_key": "silver",
		"rank_stars": 2,
		"elo": 1100,
	})
	_expect_equal(
		(app.get("rank_db") as Dictionary).get("mirrors", {}),
		existing_mirrors,
		"legacy server profile without rank_mirrors keeps local winner lineups without errors"
	)


func _test_room_snapshot_and_match_bridge() -> void:
	var room_snapshot = _room_snapshot_for_guest()
	app.call("_on_online_room_snapshot", room_snapshot)
	_expect_true(bool(app.get("online_room_active")), "authoritative room snapshot activates internet room state")
	_expect_equal(int(app.get("local_team_id")), 4, "guest uses its server-assigned team")
	_expect_equal(String((app.get("room_human_teams") as Dictionary).get(1, "")), "房主", "host slot comes from server snapshot")
	_expect_equal(String((app.get("room_human_teams") as Dictionary).get(4, "")), "访客", "guest slot comes from server snapshot")

	app.call("_on_online_match_started", {
		"match_id": "123456-1",
		"map_id": "1v1_crossroads",
		"players_per_side": 1,
		"match_seed": 987654,
		"local_team_id": 4,
		"is_authority": false,
		"authority_peer_id": 2,
		"room_snapshot": room_snapshot,
	})
	_expect_equal(String(app.get("screen")), "battle", "match start enters battle only after server broadcast")
	_expect_equal(String(app.get("room_map_id")), "1v1_crossroads", "all clients use the server-selected map")
	_expect_equal(int(app.get("battle_match_seed")), 987654, "all clients use the server-provided match seed")
	_expect_false(bool(app.get("online_match_authority")), "guest does not simulate while host authority is present")
	var guest_base: Vector2i = (app.get("room_base_keys") as Dictionary).get(4, MultiplayerRules.INVALID_KEY)
	var guest_base_center: Vector2 = app.call("_world_to_canvas", app.call("_hex_center", guest_base))
	_expect_true((app.call("_battle_view_rect") as Rect2).has_point(guest_base_center), "guest camera opens on its assigned base")
	var timer_before = float(app.get("battle_timer"))
	app.call("_process", 0.5)
	_expect_equal(float(app.get("battle_timer")), timer_before, "non-authority client does not advance battle simulation")

	app.call("_on_online_authority_changed", {
		"match_id": "123456-1",
		"is_authority": true,
		"authority_peer_id": 3,
	})
	_expect_true(bool(app.get("online_match_authority")), "authority migration promotes the remaining client without restarting")
	var unlock_key = _first_unlockable_team_tile(4)
	_expect_not_equal(unlock_key, MultiplayerRules.INVALID_KEY, "server-assigned team has an unlockable tile")
	app.call("_on_online_battle_command", {
		"match_id": "123456-1",
		"sender_peer_id": 3,
		"sender_team_id": 4,
		"command": {
			"action": "unlock_tile",
			"sequence": 1,
			"q": unlock_key.x,
			"r": unlock_key.y,
		},
	})
	_expect_equal(int((app.get("tiles") as Dictionary)[unlock_key].get("team", BoardRules.NEUTRAL)), 4, "authority executes the authenticated remote team's command")

	app.set("online_match_authority", false)
	var snapshot: Dictionary = app.call("_online_battle_snapshot")
	_expect_true(snapshot.has("team_territory_colors") and snapshot.has("team_unlocked_colors"), "authority snapshot synchronizes both tile color states")
	_expect_true(snapshot.has("effects"), "authority snapshot synchronizes short combat feedback")
	snapshot["battle_timer"] = 123.0
	snapshot["gold"] = 111
	var team_gold: Dictionary = snapshot["multiplayer_gold"]
	team_gold[4] = 222
	snapshot["multiplayer_gold"] = team_gold
	app.call("_apply_online_battle_snapshot", snapshot)
	_expect_equal(float(app.get("battle_timer")), 123.0, "guest applies authority battle time")
	_expect_equal(int(app.call("_display_gold")), 222, "guest HUD displays its assigned team's gold")

	snapshot["game_over"] = true
	snapshot["room_result"] = "win"
	snapshot["authority_room_result"] = "win"
	app.call("_apply_online_battle_snapshot", snapshot)
	_expect_equal(String(app.get("result_text")), "失败", "side-B client inverts the authority side-A result")
	_expect_true(bool(app.get("battle_reward_given")), "remote result is awarded once on the local client")


func _test_side_b_authority_receives_victory() -> void:
	app.call("_reset_online_room_state")
	app.call("_clear_online_match_state")
	app.call("_on_online_match_started", {
		"match_id": "side-b-authority",
		"map_id": "1v1_crossroads",
		"players_per_side": 1,
		"match_seed": 1234,
		"local_team_id": 4,
		"is_authority": true,
		"authority_peer_id": 4,
		"room_snapshot": _room_snapshot_for_guest(),
	})
	app.call("_eliminate_multiplayer_team", 1, 4)
	_expect_true(bool(app.get("game_over")), "side-B authority ends the match after defeating its final opponent")
	_expect_equal(String(app.get("authority_room_result")), "loss", "snapshot preserves the global side-A result")
	_expect_equal(String(app.get("room_result")), "win", "side-B authority receives its own victory result")
	_expect_equal(String(app.get("result_text")), "胜利", "side-B authority sees victory")


func _test_three_vs_three_snapshot_budget() -> void:
	app.call("_reset_online_room_state")
	app.call("_clear_online_match_state")
	app.set("room_fill_with_ai", true)
	app.call("_start_multiplayer_match", "3v3_crossroads", 3)
	app.set("online_match_id", "snapshot-budget")
	var snapshot: Dictionary = app.call("_online_battle_snapshot")
	_expect_true(var_to_bytes(snapshot).size() < OnlineRoomTransport.MAX_SNAPSHOT_BYTES, "full 3v3 snapshot stays under the transport safety limit")


func _first_unlockable_team_tile(team: int) -> Vector2i:
	for key in (app.get("tiles") as Dictionary).keys():
		if bool(app.call("_can_unlock", key, team)) and int(app.call("_unlock_cost", key, team)) <= int(app.call("_gold_for_team", team)):
			return key
	return MultiplayerRules.INVALID_KEY


func _room_snapshot_for_guest() -> Dictionary:
	return {
		"ok": true,
		"room_code": "123456",
		"status": "lobby",
		"players_per_side": 1,
		"fill_with_ai": false,
		"is_host": false,
		"can_start": false,
		"local_team_id": 4,
		"slots": [
			{"team_id": 1, "kind": "human", "display_name": "房主", "ready": true, "is_local": false, "is_host": true},
			{"team_id": 2, "kind": "empty", "display_name": "", "ready": false, "is_local": false, "is_host": false},
			{"team_id": 3, "kind": "empty", "display_name": "", "ready": false, "is_local": false, "is_host": false},
			{"team_id": 4, "kind": "human", "display_name": "访客", "ready": true, "is_local": true, "is_host": false},
			{"team_id": 5, "kind": "empty", "display_name": "", "ready": false, "is_local": false, "is_host": false},
			{"team_id": 6, "kind": "empty", "display_name": "", "ready": false, "is_local": false, "is_host": false},
		],
	}


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


func _expect_not_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		return
	failures += 1
	push_error("%s: did not expect %s" % [label, str(expected)])
