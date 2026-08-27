extends Node

const MainApp = preload("res://scripts/app/main.gd")

const TOWER_IDS = [
	"defense_watch_tower",
	"defense_longshot_tower",
	"defense_cannon_tower",
	"defense_plunder_tower",
	"defense_rapid_tower",
	"defense_repair_beacon",
	"defense_twinshot_tower",
	"defense_bounty_tower",
	"defense_territory_tower",
	"defense_storm_obelisk",
]

var failures = 0
var app: Node2D


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	_test_unique_loadable_runtime_art()
	_test_site_card_binding_and_safe_fallback()
	if failures == 0:
		print("Defense tower art integration tests passed: 10 unique 480x480 RGBA tower textures.")
	app.queue_free()
	await get_tree().process_frame
	get_tree().quit(failures)


func _test_unique_loadable_runtime_art() -> void:
	var paths = {}
	for tower_id in TOWER_IDS:
		var card: Dictionary = app.call("_card_by_id", tower_id)
		_expect_false(card.is_empty(), "%s card exists" % tower_id)
		if card.is_empty():
			continue
		var expected_path = "res://assets/art/buildings/defense_towers/%s.png" % tower_id
		var art_path = String(card.get("art_path", ""))
		_expect_equal(art_path, expected_path, "%s uses its stable runtime art path" % tower_id)
		_expect_false(paths.has(art_path), "%s art path is unique" % tower_id)
		paths[art_path] = true
		_expect_true(ResourceLoader.exists(art_path), "%s art resource exists" % tower_id)
		if not ResourceLoader.exists(art_path):
			continue
		var texture = load(art_path) as Texture2D
		_expect_true(texture != null, "%s loads as Texture2D" % tower_id)
		if texture == null:
			continue
		_expect_equal(texture.get_size(), Vector2(480, 480), "%s texture is 480x480" % tower_id)
		var image = texture.get_image()
		_expect_true(image != null and not image.is_empty(), "%s texture exposes a valid image" % tower_id)
		if image != null and not image.is_empty():
			_expect_true(image.detect_alpha() != Image.ALPHA_NONE, "%s keeps transparent alpha" % tower_id)
	_expect_equal(paths.size(), TOWER_IDS.size(), "all defense towers have distinct art paths")


func _test_site_card_binding_and_safe_fallback() -> void:
	for tower_id in TOWER_IDS:
		var tile = {
			"building": "tower",
			"site_card": tower_id,
		}
		var card: Dictionary = app.call("_tile_display_card", tile)
		_expect_equal(String(card.get("id", "")), tower_id, "%s site_card resolves its tower card" % tower_id)
		_expect_true(app.call("_tower_card_texture", tile) != null, "%s site_card resolves its tower texture" % tower_id)
	var legacy_tile = {
		"building": "tower",
		"site_card": "",
	}
	_expect_true(app.call("_tower_card_texture", legacy_tile) == null, "legacy empty site_card requests generic tower fallback")
	var missing_card = {
		"id": "defense_missing_tower_art",
		"art_path": "res://assets/art/buildings/defense_towers/does_not_exist.png",
	}
	_expect_true(app.call("_card_art_texture_or_null", missing_card) == null, "missing tower art stays null instead of using rabbit art")
	var missing_fallback = app.call("_card_texture", missing_card) as Texture2D
	_expect_true(missing_fallback != null, "missing defense art resolves a generic building texture for card UI")
	if missing_fallback != null:
		_expect_equal(missing_fallback.resource_path, "res://assets/art/buildings/tower.png", "missing defense art never falls back to rabbit art")
	var animal_tile = {
		"building": "tower",
		"site_card": "rabbit",
	}
	_expect_true(app.call("_tower_card_texture", animal_tile) == null, "invalid animal site_card requests generic tower fallback")


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
