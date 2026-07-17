extends Node

const MatchAnalyticsStore = preload("res://scripts/server/match_analytics_store.gd")
const TEST_STORE_PATH = "user://tests/match_analytics_store_test.json"
const TEST_DASHBOARD_PATH = "user://tests/dashboard_snapshot_test.json"

var failures = 0


func _ready() -> void:
	_cleanup()
	var store_without_dashboard_override = MatchAnalyticsStore.new(TEST_STORE_PATH)
	_expect(
		store_without_dashboard_override.data.has("matches") and store_without_dashboard_override.data.has("players"),
		"store initializes persisted analytics shape when using the default dashboard path"
	)
	var store = MatchAnalyticsStore.new(TEST_STORE_PATH, TEST_DASHBOARD_PATH)
	var roster = [
		{
			"user_id": "U-ALPHA",
			"team_id": 1,
			"display_name": "Alpha",
			"rank_key": "gold",
			"rank_stars": 7,
			"deck": ["rabbit", "wolf", "defense_watch_tower"],
			"card_levels": {"rabbit": 3, "wolf": 2, "defense_watch_tower": 9},
			"session_token": "must-never-persist",
			"password_hash": "must-never-persist",
		},
		{
			"user_id": "U-BETA",
			"team_id": 4,
			"display_name": "Beta",
			"rank_key": "silver",
			"rank_stars": 3,
			"deck": ["rabbit", "duck"],
			"card_levels": {"rabbit": 1, "duck": 4},
			"installation_id": "must-never-persist",
		},
	]
	var animal_ids = {
		"rabbit": "兔子",
		"wolf": "狼",
		"duck": "鸭子",
		"eagle": "老鹰",
	}
	var catalog_result: Dictionary = store.register_animal_catalog(animal_ids)
	_expect(bool(catalog_result.get("ok", false)) and int(catalog_result.get("animal_count", 0)) == 4, "registers the complete animal catalog before any match is played")
	_expect((store.data.get("animals", {}) as Dictionary).has("eagle"), "zero-sample animals remain visible to the dashboard")
	var begin: Dictionary = store.begin_match({
		"match_id": "analytics-match-1",
		"room_code": "123456",
		"map_id": "1v1_crossroads",
		"session_token": "must-never-persist",
	}, roster, animal_ids)
	_expect(bool(begin.get("ok", false)), "starts a server-owned analytics match")
	_expect(bool(begin.get("created", false)), "first match start creates a record")
	_expect(int(begin.get("tracked_player_count", 0)) == 2, "freezes both authenticated players")

	var frozen_match = store.get_match("analytics-match-1")
	_expect((frozen_match.get("players", []) as Array).size() == 2, "frozen match stores the roster")
	var frozen_text = JSON.stringify(frozen_match)
	_expect(not frozen_text.contains("must-never-persist"), "frozen match excludes credentials and device identifiers")
	var first_player: Dictionary = (frozen_match.get("players", []) as Array)[0]
	_expect((first_player.get("animal_deck", []) as Array) == ["rabbit", "wolf"], "only animals from the frozen deck are counted")

	var finished: Dictionary = store.finalize_match("analytics-match-1", {
		"team_outcomes": {"1": "win", "4": "loss"},
		"placements_by_team": {"1": 1, "4": 2},
	})
	_expect(bool(finished.get("ok", false)), "finalizes the first terminal result")
	_expect(bool(finished.get("finalized", false)), "first terminal result changes match state")
	_expect(not bool(finished.get("result_incomplete", true)), "complete team outcomes are counted")

	var players: Dictionary = store.data.get("players", {})
	var alpha: Dictionary = players.get("U-ALPHA", {})
	var beta: Dictionary = players.get("U-BETA", {})
	_expect(int(alpha.get("matches", 0)) == 1 and int(alpha.get("wins", 0)) == 1, "winner aggregate increments once")
	_expect(int(beta.get("matches", 0)) == 1 and int(beta.get("losses", 0)) == 1, "loser aggregate increments once")

	var animals: Dictionary = store.data.get("animals", {})
	var rabbit: Dictionary = animals.get("rabbit", {})
	var wolf: Dictionary = animals.get("wolf", {})
	var duck: Dictionary = animals.get("duck", {})
	var eagle: Dictionary = animals.get("eagle", {})
	_expect(int(rabbit.get("appearances", 0)) == 2 and int(rabbit.get("wins", 0)) == 1 and int(rabbit.get("losses", 0)) == 1, "shared animal gets per-deck win and loss counts")
	_expect(int(wolf.get("appearances", 0)) == 1 and int(wolf.get("wins", 0)) == 1, "winner-only animal gets one win")
	_expect(int(duck.get("appearances", 0)) == 1 and int(duck.get("losses", 0)) == 1, "loser-only animal gets one loss")
	_expect(int(eagle.get("appearances", 0)) == 0, "catalog includes animals without match data")

	var duplicate_finish: Dictionary = store.finalize_match("analytics-match-1", {
		"team_outcomes": {"1": "loss", "4": "win"},
	})
	_expect(bool(duplicate_finish.get("ok", false)) and bool(duplicate_finish.get("idempotent", false)), "same match id is finalized idempotently")
	_expect(int((store.data.get("players", {}) as Dictionary).get("U-ALPHA", {}).get("wins", 0)) == 1, "duplicate terminal snapshot does not alter aggregates")

	var incomplete_start: Dictionary = store.begin_match({
		"match_id": "analytics-match-2",
		"room_code": "123457",
		"map_id": "1v1_plateau",
	}, [{
		"user_id": "U-GAMMA",
		"team_id": 1,
		"display_name": "Gamma",
		"rank_key": "bronze",
		"rank_stars": 1,
		"deck": ["eagle"],
		"card_levels": {"eagle": 2},
	}], animal_ids)
	_expect(bool(incomplete_start.get("ok", false)), "starts an additional match for incomplete-result coverage")
	var incomplete_finish: Dictionary = store.finalize_match("analytics-match-2", {})
	_expect(not bool(incomplete_finish.get("ok", false)) and String(incomplete_finish.get("error", "")) == "incomplete_result", "missing terminal outcome keeps the match available for a valid later snapshot")
	var gamma: Dictionary = (store.data.get("players", {}) as Dictionary).get("U-GAMMA", {})
	_expect(gamma.is_empty(), "an incomplete start does not overwrite a player leaderboard projection")
	_expect(int(((store.data.get("animals", {}) as Dictionary).get("eagle", {}) as Dictionary).get("appearances", 0)) == 0, "incomplete result does not count animal statistics")
	var recovered_finish: Dictionary = store.finalize_match("analytics-match-2", {
		"team_outcomes": {"1": "win"},
	})
	_expect(bool(recovered_finish.get("ok", false)) and bool(recovered_finish.get("finalized", false)), "a valid later terminal snapshot can still finalize the active match")
	var active_begin: Dictionary = store.begin_match({
		"match_id": "analytics-match-active",
		"room_code": "123458",
		"map_id": "1v1_active",
	}, roster, animal_ids)
	_expect(bool(active_begin.get("ok", false)), "an active match can be stored without becoming a recent completed result")

	_expect(FileAccess.file_exists(TEST_DASHBOARD_PATH), "writes dashboard snapshot")
	var dashboard_file = FileAccess.open(TEST_DASHBOARD_PATH, FileAccess.READ)
	var dashboard_text = dashboard_file.get_as_text() if dashboard_file != null else ""
	var dashboard = JSON.parse_string(dashboard_text)
	_expect(typeof(dashboard) == TYPE_DICTIONARY, "dashboard snapshot is valid JSON")
	_expect(not dashboard_text.contains("must-never-persist"), "dashboard snapshot excludes credentials and installation identifiers")
	if typeof(dashboard) == TYPE_DICTIONARY:
		var dashboard_value: Dictionary = dashboard
		_expect(dashboard_value.has("overview") and dashboard_value.has("leaderboard") and dashboard_value.has("top_decks") and dashboard_value.has("animals"), "dashboard exposes only analytics views")
		var overview: Dictionary = dashboard_value.get("overview", {})
		_expect(int(overview.get("matches", 0)) == 2 and int(overview.get("players", 0)) == 3 and int(overview.get("active_24h", 0)) == 3, "dashboard overview reports only completed matches, tracked players, and recent activity")
		var dashboard_leaderboard: Array = dashboard_value.get("leaderboard", [])
		var dashboard_top_decks: Array = dashboard_value.get("top_decks", [])
		var dashboard_animals: Array = dashboard_value.get("animals", [])
		var dashboard_recent_matches: Array = dashboard_value.get("recent_matches", [])
		_expect(not dashboard_leaderboard.is_empty() and int((dashboard_leaderboard[0] as Dictionary).get("rank", 0)) == 1, "leaderboard emits stable one-based ranks")
		_expect(not dashboard_top_decks.is_empty() and int((dashboard_top_decks[0] as Dictionary).get("rank", 0)) == 1, "top deck entries retain leaderboard rank")
		_expect(not dashboard_animals.is_empty() and String((dashboard_animals[0] as Dictionary).get("name", "")) != "", "animal dashboard rows retain server catalog names")
		_expect(String(overview.get("source", "")) == "server_recorded_host_authority_full_human_online", "dashboard declares the server-recorded match source")
		_expect(not dashboard_recent_matches.is_empty() and typeof((dashboard_recent_matches[0] as Dictionary).get("team_outcomes", {})) == TYPE_DICTIONARY, "recent matches expose only safe frozen participants and terminal outcomes")
		var recent_matches_complete = true
		for recent_value in dashboard_recent_matches:
			if typeof(recent_value) != TYPE_DICTIONARY or String((recent_value as Dictionary).get("state", "")) != "finalized":
				recent_matches_complete = false
				break
		_expect(recent_matches_complete, "active or incomplete matches never appear in the recent completed matches panel")

	var reloaded = MatchAnalyticsStore.new(TEST_STORE_PATH, TEST_DASHBOARD_PATH)
	var reloaded_rabbit: Dictionary = (reloaded.data.get("animals", {}) as Dictionary).get("rabbit", {})
	_expect(int(reloaded_rabbit.get("appearances", 0)) == 2, "analytics survives store reload")

	_cleanup()
	if failures == 0:
		print("Match analytics store tests passed.")
	else:
		push_error("MATCH_ANALYTICS_STORE_TEST_FAIL: %d failure(s)" % failures)
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _cleanup() -> void:
	for base_path in [TEST_STORE_PATH, TEST_DASHBOARD_PATH]:
		for suffix in ["", ".tmp", ".previous"]:
			var path = String(base_path) + suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
