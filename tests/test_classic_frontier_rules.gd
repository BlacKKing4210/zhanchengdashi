extends Node

const ClassicMapRules = preload("res://scripts/app/systems/classic_map_rules.gd")
const MultiplayerRules = preload("res://scripts/app/systems/multiplayer_rules.gd")

var failures = 0


func _ready() -> void:
	for map_id in MultiplayerRules.map_ids_for_size(1):
		var player_frontier_rows = {}
		for seed in range(1, 51):
			var original = MultiplayerRules.create_match(1, String(map_id), [], seed)
			var original_signature = _tile_signature(original.get("tiles", {}))
			var optimized = ClassicMapRules.optimize_match(original)
			var tiles: Dictionary = optimized.get("tiles", {})
			var frontier: Dictionary = optimized.get("classic_frontier", {})
			_expect_true(bool(frontier.get("ok", false)), "%s seed %d has a valid classic frontier" % [map_id, seed])
			_expect_true(
				ClassicMapRules.shared_border_edges(tiles, 1, 4) >= ClassicMapRules.MIN_SHARED_BORDER_EDGES,
				"%s seed %d has at least nine shared border edges" % [map_id, seed]
			)
			_expect_equal(ClassicMapRules.territory_count(tiles, 1), 37, "%s seed %d player has 37 frontier cells" % [map_id, seed])
			_expect_equal(ClassicMapRules.territory_count(tiles, 4), 37, "%s seed %d enemy has 37 frontier cells" % [map_id, seed])
			_expect_true(ClassicMapRules.is_team_connected(tiles, 1), "%s seed %d player territory remains connected" % [map_id, seed])
			_expect_true(ClassicMapRules.is_team_connected(tiles, 4), "%s seed %d enemy territory remains connected" % [map_id, seed])
			_expect_true(ClassicMapRules.neutral_count(tiles) >= 1, "%s seed %d keeps a neutral contest cell" % [map_id, seed])
			_expect_true(int(frontier.get("frontier_distance_gap", 99)) <= 2, "%s seed %d frontier distance gap is at most two" % [map_id, seed])
			var player_key: Vector2i = frontier.get("player_frontier_key", MultiplayerRules.INVALID_KEY)
			var enemy_key: Vector2i = frontier.get("enemy_frontier_key", MultiplayerRules.INVALID_KEY)
			if player_key != MultiplayerRules.INVALID_KEY and enemy_key != MultiplayerRules.INVALID_KEY:
				player_frontier_rows[player_key.y] = true
				_expect_equal(_site_signature(tiles[player_key]), _site_signature(tiles[enemy_key]), "%s seed %d frontier site opportunities match" % [map_id, seed])
			_expect_equal(_tile_signature(original.get("tiles", {})), original_signature, "%s seed %d optimizer does not mutate multiplayer match data" % [map_id, seed])
			var regenerated = MultiplayerRules.create_match(1, String(map_id), [], seed)
			_expect_equal(_tile_signature(regenerated.get("tiles", {})), original_signature, "%s seed %d multiplayer generator output remains unchanged" % [map_id, seed])
		_expect_true(player_frontier_rows.size() > 1, "%s alternates the assigned player frontier across match seeds" % map_id)

	if failures == 0:
		print("CLASSIC_FRONTIER_RULES_TEST_PASS")
	else:
		push_error("CLASSIC_FRONTIER_RULES_TEST_FAIL: %d failure(s)" % failures)
	get_tree().quit(failures)


func _tile_signature(tiles: Dictionary) -> String:
	var keys = tiles.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)
	var rows = []
	for key in keys:
		rows.append("%d,%d=%s" % [key.x, key.y, JSON.stringify(tiles[key])])
	return "|".join(rows)


func _site_signature(tile: Dictionary) -> String:
	var comparable = tile.duplicate(true)
	comparable.erase("territory_team")
	return JSON.stringify(comparable)


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
