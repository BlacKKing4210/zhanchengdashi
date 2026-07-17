extends Node

const MainApp = preload("res://scripts/app/main.gd")
const PlayerAccountStore = preload("res://scripts/server/player_account_store.gd")
const RankingRules = preload("res://scripts/app/systems/ranking_rules.gd")
const RankMirrorRules = preload("res://scripts/app/systems/rank_mirror_rules.gd")

var failures = 0


func _ready() -> void:
	_test_color_eligibility()
	_test_one_time_legacy_migration()
	_test_main_recording_gate()
	_test_server_profile_migration()
	if failures == 0:
		print("Rank mirror policy tests passed.")
	get_tree().quit(failures)


func _test_color_eligibility() -> void:
	var rarities = RankMirrorRules.animal_rarities_from_cards(_card_catalog())
	_expect_true(
		RankMirrorRules.deck_has_only_common_animals(["rabbit", "gold_mine_card", "rabbit"], rarities),
		"building cards do not prevent an all-green animal deck from being rejected"
	)
	_expect_false(
		RankMirrorRules.deck_has_only_common_animals(["rabbit", "wolf", "gold_mine_card"], rarities),
		"one blue animal makes the deck eligible"
	)
	_expect_true(
		RankMirrorRules.should_record_deck(["rabbit", "wolf", "gold_mine_card"], rarities),
		"eligible mixed-rarity animal deck can be recorded"
	)


func _test_one_time_legacy_migration() -> void:
	var history = {
		"bronze": [{"deck": ["rabbit"]}],
		"silver": [{"deck": ["rabbit"]}],
		"gold": [{"deck": ["wolf"]}],
		"diamond": [{"deck": ["wolf"]}],
	}
	var migrated = RankMirrorRules.migrate_legacy_mirrors(history, 0)
	_expect_true(migrated.has("bronze") and migrated.has("silver"), "migration retains bronze and silver history")
	_expect_false(migrated.has("gold") or migrated.has("diamond"), "migration removes legacy gold-and-above history")
	var current = RankMirrorRules.migrate_legacy_mirrors(history, RankMirrorRules.POLICY_VERSION)
	_expect_true(current.has("gold") and current.has("diamond"), "current-policy high-rank mirrors remain eligible")


func _test_main_recording_gate() -> void:
	var app = MainApp.new()
	app.set("cards", _card_catalog())
	app.set("card_levels", {"rabbit": 1, "wolf": 1, "gold_mine_card": 1})
	app.set("rank_db", {
		"version": RankingRules.DB_VERSION,
		"mirror_policy_version": RankMirrorRules.POLICY_VERSION,
		"player": RankingRules.default_profile(),
		"mirrors": {},
	})
	app.set("deck", ["gold_mine_card", "rabbit", "rabbit", "rabbit", "rabbit", "rabbit", "rabbit", "rabbit"])
	app.call("_record_victory_mirror", "bronze", 1)
	_expect_equal(_mirror_count(app, "bronze"), 0, "all-green animal victory is not recorded")
	app.set("deck", ["gold_mine_card", "wolf", "rabbit", "rabbit", "rabbit", "rabbit", "rabbit", "rabbit"])
	app.call("_record_victory_mirror", "gold", 1)
	_expect_equal(_mirror_count(app, "gold"), 1, "qualified high-rank victory is recorded after migration")
	app.free()


func _test_server_profile_migration() -> void:
	var store = PlayerAccountStore.new("user://tests/rank_mirror_policy_test.json")
	var normalized: Dictionary = store.call("_normalize_profile", {
		"rank_mirrors": {
			"silver": [{"mirror_id": "silver-old", "deck": ["rabbit"]}],
			"platinum": [{"mirror_id": "platinum-old", "deck": ["wolf"]}],
		},
	})
	var mirrors: Dictionary = normalized.get("rank_mirrors", {})
	_expect_true(mirrors.has("silver"), "server migration keeps historical silver mirrors")
	_expect_false(mirrors.has("platinum"), "server migration removes historical platinum mirrors")
	_expect_equal(
		int(normalized.get("rank_mirror_policy_version", 0)),
		RankMirrorRules.POLICY_VERSION,
		"server stamps the current mirror policy version"
	)
	var current: Dictionary = store.call("_normalize_profile", {
		"rank_mirror_policy_version": RankMirrorRules.POLICY_VERSION,
		"rank_mirrors": {
			"platinum": [{"mirror_id": "platinum-new", "deck": ["wolf"]}],
		},
	})
	_expect_true(
		(current.get("rank_mirrors", {}) as Dictionary).has("platinum"),
		"server retains new qualified high-rank mirrors after migration"
	)


func _card_catalog() -> Dictionary:
	return {
		"rabbit": {"id": "rabbit", "rarity": "common", "tags": []},
		"wolf": {"id": "wolf", "rarity": "rare", "tags": []},
		"gold_mine_card": {"id": "gold_mine_card", "rarity": "common", "tags": ["building"]},
	}


func _mirror_count(app: Node, rank_key: String) -> int:
	var database: Dictionary = app.get("rank_db")
	var mirrors: Dictionary = database.get("mirrors", {})
	return (mirrors.get(rank_key, []) as Array).size()


func _expect_true(value: bool, label: String) -> void:
	if value:
		return
	failures += 1
	push_error("%s: expected true" % label)


func _expect_false(value: bool, label: String) -> void:
	_expect_true(not value, label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])
