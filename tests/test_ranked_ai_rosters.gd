extends Node

const MainApp = preload("res://scripts/app/main.gd")
const RankAIDecks = preload("res://scripts/app/systems/rank_ai_decks.gd")
const RankMirrorRules = preload("res://scripts/app/systems/rank_mirror_rules.gd")
const RankingRules = preload("res://scripts/app/systems/ranking_rules.gd")
const RoomRegistry = preload("res://scripts/network/room_registry.gd")

const KING_DECK_RARITY_COUNTS = {
	"common": 2,
	"rare": 2,
	"epic": 3,
	"legendary": 1,
}
const KING_LEVEL = 6
const RANK_DB_PATH = "user://rank_mirror_db.json"

var failures = 0
var app: Node


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	await get_tree().process_frame
	_install_test_card_catalog()
	_test_local_free_for_all_uses_king_rosters_without_rewriting_local_deck()
	_test_online_room_fill_ai_inherits_king_quality()
	_test_multiplayer_king_victory_records_one_pre_match_mirror()
	app.queue_free()
	if failures == 0:
		print("Ranked AI roster behavior tests passed.")
	get_tree().quit(failures)


func _test_local_free_for_all_uses_king_rosters_without_rewriting_local_deck() -> void:
	var local_deck = [
		"gold_mine_card",
		"defense_watch_tower",
		"rabbit",
		"mouse",
		"ant",
		"sparrow",
		"frog",
		"chicken",
	]
	var local_levels = _levels_for(local_deck, 3)
	_set_king_rank_profile()
	app.set("deck", local_deck.duplicate())
	app.set("card_levels", local_levels.duplicate(true))
	app.call("_start_multiplayer_match", "", 3, true)

	var local_team = int(app.call("_local_control_team"))
	var rosters: Dictionary = app.get("multiplayer_team_decks")
	var roster_levels: Dictionary = app.get("multiplayer_team_card_levels")
	_expect_equal(rosters.get(local_team, []), local_deck, "free-for-all leaves the local deck unchanged")
	_expect_equal(roster_levels.get(local_team, {}), local_levels, "free-for-all leaves the local card levels unchanged")

	var ai_count = 0
	for raw_team in app.get("room_active_team_ids"):
		var team = int(raw_team)
		if team == local_team:
			continue
		ai_count += 1
		_expect_king_roster(
			rosters.get(team, []),
			roster_levels.get(team, {}),
			"local free-for-all AI team %d" % team
		)
	_expect_equal(ai_count, 5, "six-player free-for-all has five AI opponents")


func _test_online_room_fill_ai_inherits_king_quality() -> void:
	var registry = RoomRegistry.new(73519)
	var created = registry.create_room(801, "King Host", 3, true, {
		"user_id": "king-host",
		"rank_key": "king",
		"rank_stars": 31,
		"elo": 6200,
		"deck": ["gold_mine_card", "defense_watch_tower", "rabbit", "mouse", "ant", "sparrow", "frog", "chicken"],
		"card_levels": _levels_for(["gold_mine_card", "defense_watch_tower", "rabbit", "mouse", "ant", "sparrow", "frog", "chicken"], 3),
	})
	_expect_true(bool(created.get("ok", false)), "King host can create a 3v3 AI-filled room")
	var snapshot = registry.snapshot_for_peer(801)
	var ai_count = 0
	for raw_slot in snapshot.get("slots", []):
		if typeof(raw_slot) != TYPE_DICTIONARY:
			continue
		var slot: Dictionary = raw_slot
		if String(slot.get("kind", "")) != "ai":
			continue
		ai_count += 1
		_expect_equal(String(slot.get("rank_key", "")), "king", "server AI slot inherits the King host rank")
		_expect_king_roster(
			slot.get("deck", []),
			slot.get("card_levels", {}),
			"server-filled AI slot %d" % int(slot.get("team_id", 0))
		)
	_expect_equal(ai_count, 5, "King 3v3 room is filled by five ranked AI participants")


func _test_multiplayer_king_victory_records_one_pre_match_mirror() -> void:
	var original_rank_db = _backup_rank_database()
	var king_deck: Array = (RankAIDecks.mirrors_for_rank("king")[0].get("deck", []) as Array).duplicate()
	var king_levels = _levels_for(king_deck, KING_LEVEL)
	_set_king_rank_profile()
	app.set("deck", king_deck.duplicate())
	app.set("card_levels", king_levels.duplicate(true))
	app.set("active_match_rank_key", "king")
	app.set("active_match_player_stars", 31)

	app.call("_apply_multiplayer_rank_result", "win", 3)
	_expect_equal(_mirror_count("king"), 1, "qualified multiplayer King victory records one mirror")
	var mirror = _latest_mirror("king")
	_expect_equal(String(mirror.get("rank_key", "")), "king", "multiplayer mirror records the pre-match King rank")
	_expect_equal(int(mirror.get("stars", 0)), 31, "multiplayer mirror records the pre-match King stars")
	_expect_equal(mirror.get("deck", []), king_deck, "multiplayer mirror stores the winning deck snapshot")
	_expect_equal(mirror.get("card_levels", {}), king_levels, "multiplayer mirror stores the winning card levels")

	app.call("_apply_multiplayer_rank_result", "win", 3)
	_expect_equal(_mirror_count("king"), 1, "the same qualified deck is stored once per rank pool")
	_restore_rank_database(original_rank_db)


func _set_king_rank_profile() -> void:
	var profile = RankingRules.default_profile()
	profile["player_id"] = "ranked-ai-roster-test"
	profile["name"] = "Rank Test"
	profile["rank_key"] = "king"
	profile["stars"] = 31
	profile["elo"] = 6200
	app.set("rank_db", {
		"version": RankingRules.DB_VERSION,
		"mirror_policy_version": RankMirrorRules.POLICY_VERSION,
		"player": profile,
		"mirrors": {},
	})


func _install_test_card_catalog() -> void:
	var catalog = [
		{"id": "gold_mine_card", "rarity": "epic", "tags": ["mine"]},
		{"id": "defense_watch_tower", "rarity": "common", "tags": ["defense"]},
		{"id": "defense_cannon_tower", "rarity": "rare", "tags": ["defense"]},
		{"id": "defense_repair_beacon", "rarity": "epic", "tags": ["defense"]},
		{"id": "defense_storm_obelisk", "rarity": "legendary", "tags": ["defense"]},
	]
	for raw_rarity in RankAIDecks.RARITY_KEYS:
		var rarity = String(raw_rarity)
		for raw_card_id in RankAIDecks.ANIMAL_POOLS[rarity]:
			catalog.append({"id": String(raw_card_id), "rarity": rarity, "tags": []})
	app.set("cards", catalog)


func _expect_king_roster(raw_deck: Variant, raw_levels: Variant, label: String) -> void:
	var deck: Array = raw_deck if typeof(raw_deck) == TYPE_ARRAY else []
	var levels: Dictionary = raw_levels if typeof(raw_levels) == TYPE_DICTIONARY else {}
	_expect_equal(deck.size(), 8, "%s has eight cards" % label)
	_expect_equal(deck.count("gold_mine_card"), 1, "%s contains the mandatory mine" % label)
	var defense_count = 0
	var animal_count = 0
	var counts = {"common": 0, "rare": 0, "epic": 0, "legendary": 0}
	for raw_card_id in deck:
		var card_id = String(raw_card_id)
		if card_id == "gold_mine_card":
			_expect_equal(int(levels.get(card_id, 0)), KING_LEVEL, "%s mine is level six" % label)
		elif card_id.begins_with("defense_"):
			defense_count += 1
			_expect_equal(int(levels.get(card_id, 0)), KING_LEVEL, "%s defense is level six" % label)
		else:
			animal_count += 1
			_expect_equal(int(levels.get(card_id, 0)), KING_LEVEL, "%s animal %s is level six" % [label, card_id])
		var rarity = _rarity_for_card(card_id)
		_expect_true(counts.has(rarity), "%s card %s has a known rarity" % [label, card_id])
		if counts.has(rarity):
			counts[rarity] = int(counts[rarity]) + 1
	_expect_equal(defense_count, 1, "%s has one defense card" % label)
	_expect_equal(animal_count, 6, "%s has six animal cards" % label)
	_expect_equal(counts, KING_DECK_RARITY_COUNTS, "%s follows the King full-deck quality gradient" % label)


func _rarity_for_card(card_id: String) -> String:
	return String(RankAIDecks.card_rarity_map().get(card_id, ""))


func _levels_for(deck: Array, level: int) -> Dictionary:
	var result = {}
	for raw_card_id in deck:
		result[String(raw_card_id)] = level
	return result


func _mirror_count(rank_key: String) -> int:
	var database: Dictionary = app.get("rank_db")
	var mirrors: Dictionary = database.get("mirrors", {})
	var entries = mirrors.get(rank_key, [])
	return entries.size() if typeof(entries) == TYPE_ARRAY else 0


func _latest_mirror(rank_key: String) -> Dictionary:
	var database: Dictionary = app.get("rank_db")
	var mirrors: Dictionary = database.get("mirrors", {})
	var entries = mirrors.get(rank_key, [])
	if typeof(entries) != TYPE_ARRAY or (entries as Array).is_empty():
		return {}
	var mirror = (entries as Array).back()
	return mirror if typeof(mirror) == TYPE_DICTIONARY else {}


func _backup_rank_database() -> Dictionary:
	if not FileAccess.file_exists(RANK_DB_PATH):
		return {"exists": false, "bytes": PackedByteArray()}
	return {"exists": true, "bytes": FileAccess.get_file_as_bytes(RANK_DB_PATH)}


func _restore_rank_database(backup: Dictionary) -> void:
	if bool(backup.get("exists", false)):
		var file = FileAccess.open(RANK_DB_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(backup.get("bytes", PackedByteArray()))
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RANK_DB_PATH))


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
