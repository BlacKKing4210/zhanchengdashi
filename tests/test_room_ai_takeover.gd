extends Node

const RoomProtocol = preload("res://scripts/network/room_protocol.gd")
const RoomRegistry = preload("res://scripts/network/room_registry.gd")

var failures = 0


func _ready() -> void:
	_test_running_host_disconnect_becomes_ai()
	if failures == 0:
		print("Room AI takeover tests passed.")
	get_tree().quit(failures)


func _test_running_host_disconnect_becomes_ai() -> void:
	var registry = RoomRegistry.new(87123)
	var host_deck = ["wolf", "rabbit", "rabbit", "rabbit", "rabbit", "rabbit", "gold_mine_card", "defense_watch_tower"]
	var created = registry.create_room(101, "Host", 1, false, {
		"user_id": "host-user",
		"rank_key": "gold",
		"rank_stars": 7,
		"elo": 1900,
		"deck": host_deck,
		"card_levels": {"wolf": 4, "rabbit": 2, "gold_mine_card": 3, "defense_watch_tower": 3},
	})
	_expect_true(bool(created.get("ok", false)), "room is created")
	var room_code = String(created.get("room_code", ""))
	var joined = registry.join_room(202, room_code, "Guest", {
		"user_id": "guest-user",
		"rank_key": "silver",
		"rank_stars": 3,
		"deck": ["rabbit"],
		"card_levels": {"rabbit": 1},
	})
	_expect_true(bool(joined.get("ok", false)), "guest joins the room")
	registry.set_ready(101, true)
	registry.set_ready(202, true)
	var started = registry.start_room(101)
	_expect_true(bool(started.get("ok", false)), "room starts before disconnect")
	var host_assignment = registry.assignment_for_peer(101)
	var host_team = int(host_assignment.get("team_id", 0))

	var takeover = registry.peer_disconnected(101)
	_expect_equal(String(takeover.get("action", "")), "ai_takeover", "running disconnect converts the slot to AI")
	_expect_equal(int(takeover.get("team_id", 0)), host_team, "AI keeps the departed player's team slot")
	_expect_equal(int(takeover.get("new_host_peer_id", 0)), 202, "authority host migrates to the remaining human")

	var snapshot = registry.snapshot_for_peer(202)
	_expect_equal(String(snapshot.get("status", "")), RoomProtocol.RUNNING_STATUS, "match remains running")
	_expect_equal(int(snapshot.get("human_count", 0)), 1, "one human remains")
	_expect_equal(int(snapshot.get("ai_count", 0)), 1, "departed human is now one AI")
	_expect_equal(int(snapshot.get("authority_peer_id", 0)), 202, "remaining human becomes synchronization authority")
	var takeover_slot = _slot_for_team(snapshot, host_team)
	_expect_equal(String(takeover_slot.get("kind", "")), "ai", "departed slot is advertised as AI")
	_expect_true(bool(takeover_slot.get("takeover", false)), "snapshot marks the AI as a takeover")
	_expect_equal(String(takeover_slot.get("display_name", "")), "Host（AI）", "takeover keeps the original player identity visible")
	_expect_equal(takeover_slot.get("deck", []), host_deck, "takeover preserves the frozen player deck")
	_expect_equal(int((takeover_slot.get("card_levels", {}) as Dictionary).get("wolf", 0)), 4, "takeover preserves card levels")
	_expect_equal(String(takeover_slot.get("rank_key", "")), "gold", "takeover preserves rank packaging")

	var closed = registry.peer_disconnected(202)
	_expect_equal(String(closed.get("action", "")), "room_closed", "room closes when the final human leaves")
	_expect_equal(registry.room_count(), 0, "no AI-only room remains without an authority client")


func _slot_for_team(snapshot: Dictionary, team_id: int) -> Dictionary:
	for raw_slot in snapshot.get("slots", []):
		if typeof(raw_slot) == TYPE_DICTIONARY and int((raw_slot as Dictionary).get("team_id", 0)) == team_id:
			return raw_slot
	return {}


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
