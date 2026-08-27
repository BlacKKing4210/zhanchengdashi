extends Node

const MainApp = preload("res://scripts/app/main.gd")

const EXPECTED_SKILL_TEXT = {
	"defense_watch_tower": "",
	"defense_longshot_tower": "攻击距离+1.5，优先攻击远程",
	"defense_cannon_tower": "攻击+1",
	"defense_plunder_tower": "攻击时，掠夺1金币",
	"defense_rapid_tower": "攻击速度+200%",
	"defense_repair_beacon": "生命值+200%",
	"defense_twinshot_tower": "攻击目标+1，攻击距离+1",
	"defense_bounty_tower": "攻击+2，击杀时，获得10金币",
	"defense_territory_tower": "无视攻击距离，只要敌人处于我方领地上即可攻击",
	"defense_storm_obelisk": "每5秒对所有动物造成1点伤害",
}

var failures = 0
var app


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	_test_visible_skill_text_is_exact()
	_test_both_tower_detail_pages_hide_range_and_interval()
	if failures == 0:
		print("Defense tower UI contract tests passed.")
	app.queue_free()
	get_tree().quit(failures)


func _test_visible_skill_text_is_exact() -> void:
	for card_id in EXPECTED_SKILL_TEXT.keys():
		var card: Dictionary = app.call("_card_by_id", card_id)
		_expect_false(card.is_empty(), "%s exists for UI contract checks" % card_id)
		if card.is_empty():
			continue
		_expect_equal(
			String(app.call("_card_detail_skill_text", card)),
			String(EXPECTED_SKILL_TEXT[card_id]),
			"%s exposes the exact producer skill description" % card_id
		)
	_expect_equal(
		String(app.call("_card_detail_skill_text", app.call("_card_by_id", "defense_watch_tower"))),
		"",
		"the blank base-tower skill cell stays blank instead of inventing a no-skill description"
	)


func _test_both_tower_detail_pages_hide_range_and_interval() -> void:
	var source = FileAccess.get_file_as_string("res://scripts/app/main.gd")
	var battle_summary = _function_source(source, "_draw_building_card_summary")
	var deck_detail = _function_source(source, "_draw_card_detail")
	_expect_true(battle_summary != "", "battle tower detail function is available")
	_expect_true(deck_detail != "", "deck tower detail function is available")
	for function_source in [battle_summary, deck_detail]:
		_expect_true(function_source.contains("\"attack\""), "tower detail keeps the attack field")
		_expect_true(function_source.contains("\"hp\""), "tower detail keeps the health field")
		_expect_false(function_source.contains("_defense_range_text"), "tower detail does not render range text")
		_expect_false(function_source.contains("summon_interval_sec"), "tower detail does not render attack interval")
		_expect_false(function_source.contains("%.1fs"), "tower detail does not render a seconds label")


func _function_source(source: String, function_name: String) -> String:
	var marker = "func %s(" % function_name
	var start = source.find(marker)
	if start < 0:
		return ""
	var next_function = source.find("\nfunc ", start + marker.length())
	if next_function < 0:
		return source.substr(start)
	return source.substr(start, next_function - start)


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
