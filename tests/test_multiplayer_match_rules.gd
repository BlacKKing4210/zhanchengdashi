extends Node

const MainApp = preload("res://scripts/app/main.gd")
const MultiplayerRules = preload("res://scripts/app/systems/multiplayer_rules.gd")

const SIX_MINUTES = 360.0

var failures = 0
var app: Node


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	await get_tree().process_frame
	_test_team_mode_timer_and_early_wins()
	_test_free_for_all_timer_and_last_survivor_win()
	if failures == 0:
		print("Multiplayer match rule tests passed.")
	app.queue_free()
	get_tree().quit(failures)


func _test_team_mode_timer_and_early_wins() -> void:
	for players_per_side in [1, 2, 3]:
		app.call("_start_multiplayer_match", "%dv%d_crossroads" % [players_per_side, players_per_side], players_per_side)
		_expect_equal(float(app.get("battle_timer")), SIX_MINUTES, "%dv%d starts at six minutes" % [players_per_side, players_per_side])
		var opposing_teams = []
		for team in app.get("room_active_team_ids"):
			if int(team) >= 4:
				opposing_teams.append(int(team))
		for index in range(opposing_teams.size()):
			app.call("_eliminate_multiplayer_team", opposing_teams[index], 1)
			_expect_equal(
				bool(app.get("game_over")),
				index == opposing_teams.size() - 1,
				"%dv%d only ends after its final opposing player is defeated" % [players_per_side, players_per_side]
			)
		_expect_equal(String(app.get("room_result")), "win", "%dv%d awards the surviving side a win" % [players_per_side, players_per_side])


func _test_free_for_all_timer_and_last_survivor_win() -> void:
	app.call("_start_multiplayer_match", "", MultiplayerRules.MAX_PLAYERS_PER_SIDE, true)
	_expect_equal(float(app.get("battle_timer")), SIX_MINUTES, "six-player free-for-all starts at six minutes")
	for team in [2, 3, 4, 5, 6]:
		app.call("_eliminate_multiplayer_team", team, 1)
	_expect_true(bool(app.get("game_over")), "free-for-all ends when every other player is defeated")
	_expect_equal(int(app.get("multiplayer_placement")), 1, "last surviving free-for-all player is first")


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
