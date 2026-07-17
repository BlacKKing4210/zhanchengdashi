extends Node

const RankingRules = preload("res://scripts/app/systems/ranking_rules.gd")

const CASTLE_PATHS = {
	"bronze": "res://assets/art/buildings/rank_castles/castle_bronze.png",
	"silver": "res://assets/art/buildings/rank_castles/castle_silver.png",
	"gold": "res://assets/art/buildings/rank_castles/castle_gold.png",
	"platinum": "res://assets/art/buildings/rank_castles/castle_platinum.png",
	"diamond": "res://assets/art/buildings/rank_castles/castle_diamond.png",
	"star": "res://assets/art/buildings/rank_castles/castle_star.png",
	"king": "res://assets/art/buildings/rank_castles/castle_king.png",
}

var failures = 0


func _ready() -> void:
	var castle_keys = {}
	var panel_colors = {}
	_expect_equal(RankingRules.RANKS.size(), 7, "rank ladder exposes seven castle tiers")
	for rank in RankingRules.RANKS:
		var rank_key = String(rank.get("key", ""))
		var visual = RankingRules.visual_for_key(rank_key)
		var castle_key = String(visual.get("castle_key", ""))
		var panel_color = String(visual.get("panel_color", ""))
		var accent_color = String(visual.get("accent_color", ""))
		_expect_equal(castle_key, rank_key, "%s uses its matching castle" % rank_key)
		_expect_true(Color.from_string(panel_color, Color.TRANSPARENT).a > 0.0, "%s has a valid panel color" % rank_key)
		_expect_true(Color.from_string(accent_color, Color.TRANSPARENT).a > 0.0, "%s has a valid accent color" % rank_key)
		var texture = load(String(CASTLE_PATHS.get(castle_key, ""))) as Texture2D
		_expect_true(texture != null, "%s castle texture loads" % rank_key)
		if texture != null:
			_expect_equal(texture.get_size(), Vector2(512, 512), "%s castle keeps the stable 512 canvas" % rank_key)
			var image = texture.get_image()
			_expect_true(image != null and image.get_pixel(0, 0).a <= 0.01, "%s castle has a transparent outer canvas" % rank_key)
		castle_keys[castle_key] = true
		panel_colors[panel_color] = true
	_expect_equal(castle_keys.size(), 7, "every rank uses a distinct castle asset")
	_expect_equal(panel_colors.size(), 7, "every rank uses a distinct panel package")
	_expect_equal(String(RankingRules.visual_for_key("unknown").get("castle_key", "")), "bronze", "unknown ranks fall back to bronze visuals")
	if failures == 0:
		print("Rank castle visual tests passed.")
	get_tree().quit(failures)


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
