extends Node

const RoomProtocol = preload("res://scripts/network/room_protocol.gd")
const RoomRegistry = preload("res://scripts/network/room_registry.gd")

var failures = 0


func _ready() -> void:
	_test_input_validation()
	_test_two_four_and_six_player_rooms()
	_test_ai_fill_and_slot_changes()
	_test_ai_display_names_are_player_like()
	_test_permissions_and_shrink_conflict()
	_test_ready_start_and_running_lock()
	_test_start_randomizes_spawn_assignments()
	_test_leave_and_host_migration()
	_test_snapshot_is_detached()
	if failures == 0:
		print("Online room registry tests passed.")
	get_tree().quit(failures)


func _test_input_validation() -> void:
	var registry = RoomRegistry.new(1001)
	_expect_error(registry.create_room("1", "Host"), "invalid_peer_id_type", "peer id type is strict")
	_expect_error(registry.create_room(0, "Host"), "invalid_peer_id", "peer id must be positive")
	_expect_error(registry.create_room(1, 123), "invalid_player_name_type", "player name type is strict")
	_expect_error(registry.create_room(1, "   "), "invalid_player_name", "blank player name is rejected")
	_expect_error(
		registry.create_room(1, "1234567890123456789012345"),
		"player_name_too_long",
		"player name length is capped"
	)
	_expect_error(registry.create_room(1, "Host", "2"), "invalid_room_size_type", "room size type is strict")
	_expect_error(registry.create_room(1, "Host", 0), "invalid_room_size", "0v0 is rejected")
	_expect_error(registry.create_room(1, "Host", 4), "invalid_room_size", "4v4 is rejected")
	_expect_error(
		registry.create_room(1, "Host", 1, 1),
		"invalid_fill_with_ai_type",
		"AI fill must be a boolean"
	)
	_expect_equal(registry.room_count(), 0, "invalid creates do not allocate rooms")

	var created = registry.create_room(1, " Host ", 1, false)
	_expect_true(bool(created.get("ok", false)), "valid room is created after rejected input")
	_expect_equal(String(created.get("room_code", "")).length(), 6, "room code always has six digits")
	_expect_true(RoomProtocol.room_code_error(created["room_code"]).is_empty(), "generated room code is numeric")
	var second_created = registry.create_room(3, "Second Host", 1, false)
	_expect_true(bool(second_created.get("ok", false)), "server can create another simultaneous room")
	_expect_true(
		String(second_created.get("room_code", "")) != String(created.get("room_code", "")),
		"simultaneous rooms receive unique server room codes"
	)
	_expect_error(registry.join_room(2, "12345", "Guest"), "invalid_room_code", "short room code is rejected")
	_expect_error(registry.join_room(2, "12A456", "Guest"), "invalid_room_code", "non-numeric room code is rejected")
	_expect_error(
		registry.join_room(2, 123456, "Guest"),
		"invalid_room_code_type",
		"numeric room code is not silently coerced"
	)
	_expect_error(registry.set_ready(1, 1), "invalid_ready_type", "ready input must be boolean")
	_expect_error(registry.move_to_slot(1, "4"), "invalid_team_id_type", "team id input must be integer")


func _test_two_four_and_six_player_rooms() -> void:
	var codes = {}
	for players_per_side in range(1, 4):
		var registry = RoomRegistry.new(2000 + players_per_side)
		var host_peer = players_per_side * 100
		var created = registry.create_room(host_peer, "Host", players_per_side, false)
		_expect_true(bool(created.get("ok", false)), "%dv%d room is created" % [players_per_side, players_per_side])
		var code = String(created.get("room_code", ""))
		_expect_false(codes.has(code), "generated room codes are unique in the test sample")
		codes[code] = true
		var capacity = players_per_side * 2
		for offset in range(1, capacity):
			var joined = registry.join_room(host_peer + offset, code, "P%d" % offset)
			_expect_true(bool(joined.get("ok", false)), "%dv%d accepts human %d" % [players_per_side, players_per_side, offset + 1])
		var snapshot = registry.snapshot_for_peer(host_peer)
		_expect_equal(int(snapshot.get("capacity", 0)), capacity, "%dv%d publishes its full capacity" % [players_per_side, players_per_side])
		_expect_equal(int(snapshot.get("human_count", 0)), capacity, "%dv%d contains the expected human count" % [players_per_side, players_per_side])
		_expect_equal(int(snapshot.get("ai_count", -1)), 0, "%dv%d contains no AI unless requested" % [players_per_side, players_per_side])
		_expect_equal(snapshot.get("slots", []).size(), 6, "snapshot always publishes all six fixed slots")
		_expect_equal(_active_slot_ids(snapshot), RoomProtocol.active_team_ids(players_per_side), "%dv%d activates fixed side slots" % [players_per_side, players_per_side])
		_expect_error(
			registry.join_room(host_peer + capacity, code, "Overflow"),
			"room_full",
			"%dv%d rejects a seventh-style overflow participant" % [players_per_side, players_per_side]
		)
		for peer_offset in range(capacity):
			var assignment = registry.assignment_for_peer(host_peer + peer_offset)
			_expect_equal(String(assignment.get("room_code", "")), code, "peer query returns the owning room")
			_expect_true(int(assignment.get("team_id", 0)) in RoomProtocol.active_team_ids(players_per_side), "peer query returns an active team")


func _test_ai_fill_and_slot_changes() -> void:
	var registry = RoomRegistry.new(3001)
	var created = registry.create_room(10, "Host", 2, true)
	var code = String(created.get("room_code", ""))
	var snapshot = registry.snapshot_for_peer(10)
	_expect_equal(int(snapshot.get("human_count", 0)), 1, "AI-filled room retains one human host")
	_expect_equal(int(snapshot.get("ai_count", 0)), 3, "2v2 AI fill occupies the other active slots")

	var joined = registry.join_room(20, code, "Remote")
	_expect_true(bool(joined.get("ok", false)), "internet participant can replace an AI slot")
	_expect_equal(int(joined.get("team_id", 0)), 4, "join priority balances the remote player onto side B")
	_expect_equal(int(registry.snapshot_for_peer(10).get("ai_count", 0)), 2, "human replacement removes exactly one AI")

	var moved = registry.move_to_slot(20, 2)
	_expect_true(bool(moved.get("ok", false)), "player can move their own participant to an AI slot")
	_expect_equal(registry.team_for_peer(20), 2, "team query follows a slot move")
	_expect_equal(int(registry.snapshot_for_peer(20).get("ai_count", 0)), 2, "AI fill replaces the vacated active slot")
	_expect_error(registry.move_to_slot(20, 1), "slot_occupied", "player cannot displace another human")
	_expect_error(registry.move_to_slot(20, 3), "inactive_team_slot", "player cannot move into an inactive slot")

	var disabled = registry.set_ai_fill(10, false)
	_expect_true(bool(disabled.get("ok", false)), "host can disable AI fill")
	_expect_equal(int(registry.snapshot_for_peer(10).get("ai_count", -1)), 0, "disabling AI fill removes all lobby AIs")
	var enabled = registry.set_ai_fill(10, true)
	_expect_true(bool(enabled.get("ok", false)), "host can enable AI fill again")
	_expect_equal(int(registry.snapshot_for_peer(10).get("ai_count", 0)), 2, "AI fill restores active empty slots")


func _test_ai_display_names_are_player_like() -> void:
	var registry = RoomRegistry.new(3251)
	var created = registry.create_room(10, "Host", 2, true)
	_expect_true(bool(created.get("ok", false)), "AI-filled room is created for display-name test")
	var names = {}
	for slot_value in registry.snapshot_for_peer(10).get("slots", []):
		if typeof(slot_value) != TYPE_DICTIONARY or String((slot_value as Dictionary).get("kind", "")) != "ai":
			continue
		var display_name = String((slot_value as Dictionary).get("display_name", ""))
		_expect_true(display_name != "", "automatic participant has a display name")
		_expect_false(display_name.contains("AI") or display_name.contains("电脑"), "automatic participant name does not disclose automation")
		names[display_name] = true
	_expect_equal(names.size(), 3, "automatic participants use distinct names in the same room")


func _test_permissions_and_shrink_conflict() -> void:
	var registry = RoomRegistry.new(4001)
	var created = registry.create_room(101, "Host", 3, false)
	var code = String(created.get("room_code", ""))
	registry.join_room(102, code, "Second")
	registry.join_room(103, code, "Third")
	_expect_equal(registry.team_for_peer(103), 2, "third join occupies side A slot 2")

	_expect_error(registry.set_room_size(102, 2), "host_only", "non-host cannot resize the room")
	_expect_error(registry.set_ai_fill(102, true), "host_only", "non-host cannot change AI fill")
	_expect_error(registry.update_room_settings(999, 2, true), "peer_not_in_room", "spoofed peer id has no host authority")
	_expect_error(registry.start_room(102), "host_only", "non-host cannot start the room")

	var conflict = registry.set_room_size(101, 1)
	_expect_error(conflict, "room_size_conflict", "shrink is rejected while a human occupies a removed slot")
	_expect_equal(int(registry.snapshot_for_peer(101).get("players_per_side", 0)), 3, "failed shrink is atomic")
	registry.leave_room(103)
	var resized = registry.set_room_size(101, 1)
	_expect_true(bool(resized.get("ok", false)), "host can shrink after removed slots contain no humans")
	_expect_equal(_active_slot_ids(registry.snapshot_for_peer(101)), [1, 4], "1v1 retains fixed slots 1 and 4")


func _test_ready_start_and_running_lock() -> void:
	var registry = RoomRegistry.new(5001)
	var created = registry.create_room(201, "Host", 1, false)
	var code = String(created.get("room_code", ""))
	registry.join_room(202, code, "Guest")
	_expect_error(registry.start_room(201), "players_not_ready", "host cannot start before all humans are ready")
	registry.set_ready(201, true)
	registry.set_ready(202, true)
	var host_snapshot = registry.snapshot_for_peer(201)
	var guest_snapshot = registry.snapshot_for_peer(202)
	_expect_true(bool(host_snapshot.get("all_ready", false)), "full ready room reports all_ready")
	_expect_true(bool(host_snapshot.get("can_start", false)), "ready host may start")
	_expect_false(bool(guest_snapshot.get("can_start", true)), "ready non-host still cannot start")

	var started = registry.start_room(201)
	_expect_true(bool(started.get("ok", false)), "host starts a full ready room")
	_expect_equal(int(started.get("authority_peer_id", 0)), 201, "start result publishes authoritative host peer")
	_expect_equal(started.get("assignments", []).size(), 2, "start result publishes human team assignments")
	_expect_equal(String(registry.snapshot_for_peer(202).get("status", "")), RoomProtocol.RUNNING_STATUS, "running status reaches every peer snapshot")
	_expect_error(registry.join_room(203, code, "Late"), "room_running", "running room rejects late join")
	_expect_error(registry.set_ready(202, false), "room_running", "ready state is locked after start")
	_expect_error(registry.move_to_slot(202, 1), "room_running", "slots are locked after start")
	_expect_error(registry.set_ai_fill(201, true), "room_running", "settings are locked after start")
	_expect_error(registry.start_room(201), "room_running", "room cannot start twice")


func _test_leave_and_host_migration() -> void:
	var registry = RoomRegistry.new(6001)
	var created = registry.create_room(301, "Host", 2, false)
	var code = String(created.get("room_code", ""))
	registry.join_room(302, code, "Oldest Guest")
	registry.join_room(303, code, "Newest Guest")
	var left = registry.leave_room(301)
	_expect_true(bool(left.get("ok", false)), "host can leave a lobby")
	_expect_equal(int(left.get("new_host_peer_id", 0)), 302, "host migrates to the oldest remaining human")
	_expect_error(registry.assignment_for_peer(301), "peer_not_in_room", "leaving peer assignment is removed")
	var migrated_snapshot = registry.snapshot_for_peer(302)
	_expect_true(bool(migrated_snapshot.get("is_host", false)), "migrated host sees host authority")
	_expect_equal(int(migrated_snapshot.get("authority_peer_id", 0)), 302, "snapshot authority follows host migration")
	_expect_true(bool(registry.set_ai_fill(302, true).get("ok", false)), "migrated host can change room settings")

	registry.peer_disconnected(303)
	_expect_error(registry.assignment_for_peer(303), "peer_not_in_room", "disconnect uses the same cleanup as leave")
	var closed = registry.leave_room(302)
	_expect_equal(String(closed.get("action", "")), "room_closed", "last human leaving closes the room")
	_expect_equal(registry.room_count(), 0, "closed room is removed from the registry")
	_expect_error(registry.join_room(304, code, "Too Late"), "room_not_found", "closed room code cannot be joined")


func _test_start_randomizes_spawn_assignments() -> void:
	var observed_host_teams = {}
	for seed in range(8100, 8120):
		var registry = RoomRegistry.new(seed)
		var host_peer = seed * 10
		var guest_peer = host_peer + 1
		var created = registry.create_room(host_peer, "Host", 1, false)
		var code = String(created.get("room_code", ""))
		registry.join_room(guest_peer, code, "Guest")
		registry.set_ready(host_peer, true)
		registry.set_ready(guest_peer, true)
		var started = registry.start_room(host_peer)
		_expect_true(bool(started.get("ok", false)), "seeded room starts before checking randomized assignment")
		var host_team = registry.team_for_peer(host_peer)
		var guest_team = registry.team_for_peer(guest_peer)
		observed_host_teams[host_team] = true
		_expect_true(host_team in [1, 4] and guest_team in [1, 4] and host_team != guest_team, "randomized 1v1 keeps both active slots distinct")
	_expect_true(observed_host_teams.has(1) and observed_host_teams.has(4), "multiple matches place the same player at both spawn positions")


func _test_snapshot_is_detached() -> void:
	var registry = RoomRegistry.new(7001)
	var created = registry.create_room(401, "Original", 1, true)
	var code = String(created.get("room_code", ""))
	var first = registry.snapshot_for_peer(401)
	_expect_false(first.has("room"), "public snapshot does not expose the internal room dictionary")
	first["room_code"] = "000000"
	first["slots"][0]["display_name"] = "Tampered"
	first["slots"].clear()
	var second = registry.snapshot_for_peer(401)
	_expect_equal(String(second.get("room_code", "")), code, "editing a snapshot cannot change the internal room code")
	_expect_equal(second.get("slots", []).size(), 6, "editing a snapshot cannot remove internal slots")
	_expect_equal(String(second["slots"][0].get("display_name", "")), "Original", "nested snapshot dictionaries are detached")
	_expect_equal(registry.peer_ids_in_same_room(401), [401], "same-room query returns a copied peer id list")


func _active_slot_ids(snapshot: Dictionary) -> Array:
	var result = []
	for slot in snapshot.get("slots", []):
		if bool(slot.get("active", false)):
			result.append(int(slot.get("team_id", 0)))
	return result


func _expect_error(result: Dictionary, expected_error: String, message: String) -> void:
	_expect_false(bool(result.get("ok", true)), message)
	_expect_equal(String(result.get("error", "")), expected_error, "%s uses stable error code" % message)


func _expect_true(value: bool, message: String) -> void:
	if value:
		return
	failures += 1
	push_error("Expected true: %s" % message)


func _expect_false(value: bool, message: String) -> void:
	if not value:
		return
	failures += 1
	push_error("Expected false: %s" % message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [message, str(expected), str(actual)])
