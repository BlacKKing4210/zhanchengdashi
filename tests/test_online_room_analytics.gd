extends Node

const OnlineRoomTransport = preload("res://scripts/network/online_room.gd")

var failures = 0


func _ready() -> void:
	var transport = OnlineRoomTransport.new()
	var side_b_authority_result = transport.call("_server_terminal_result_from_snapshot", {
		"side_a_outcome": "win",
	})
	_expect(
		String(side_b_authority_result.get("team_outcomes", {}).get(1, "")) == "win"
		and String(side_b_authority_result.get("team_outcomes", {}).get(4, "")) == "loss",
		"a side-B authority still records the canonical side-A win"
	)

	var side_a_draw = transport.call("_server_terminal_result_from_snapshot", {
		"side_a_outcome": "draw",
	})
	_expect(
		String(side_a_draw.get("team_outcomes", {}).get(1, "")) == "draw"
		and String(side_a_draw.get("team_outcomes", {}).get(4, "")) == "draw",
		"draw is recorded for both sides"
	)

	var placement_result = transport.call("_server_terminal_result_from_snapshot", {
		"multiplayer_placements": {"1": 2, "4": 1},
	})
	_expect(
		String(placement_result.get("team_outcomes", {}).get(4, "")) == "win"
		and String(placement_result.get("team_outcomes", {}).get(1, "")) == "loss",
		"placements produce outcomes when no side result is supplied"
	)
	_expect(
		bool(transport.call("_server_roster_is_valid_for_analytics", [
			{"user_id": "U-ONE", "team_id": 1},
			{"user_id": "U-TWO", "team_id": 4},
		], 2)),
		"a full roster with unique authenticated users is eligible for analytics"
	)
	_expect(
		not bool(transport.call("_server_roster_is_valid_for_analytics", [
			{"user_id": "U-ONE", "team_id": 1},
			{"user_id": "U-ONE", "team_id": 4},
		], 2)),
		"duplicate account slots are excluded from analytics rather than silently merged"
	)

	if failures == 0:
		print("Online room analytics attribution tests passed.")
	else:
		push_error("ONLINE_ROOM_ANALYTICS_TEST_FAIL: %d failure(s)" % failures)
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
