extends SceneTree

const RankingRules = preload("res://scripts/app/systems/ranking_rules.gd")

var failures = 0


func _init() -> void:
	_test_positive_deltas_cross_rank_boundaries()
	_test_loss_crosses_rank_boundaries()
	_test_rank_floor_and_king_growth()
	_test_legacy_star_result_wrapper()
	if failures == 0:
		print("Ranking delta tests passed.")
	quit(failures)


func _test_positive_deltas_cross_rank_boundaries() -> void:
	_expect_rank("bronze", 9, 3, "silver", 3, "bronze +3 crosses into silver")
	_expect_rank("silver", 9, 2, "gold", 2, "silver +2 crosses into gold")
	_expect_rank("gold", 16, 3, "platinum", 3, "gold +3 crosses into platinum")
	_expect_rank("platinum", 16, 2, "diamond", 2, "platinum +2 crosses into diamond")
	_expect_rank("diamond", 25, 2, "star", 2, "diamond +2 crosses into star")
	_expect_rank("star", 25, 2, "king", 2, "star +2 crosses into king")


func _test_loss_crosses_rank_boundaries() -> void:
	_expect_rank("silver", 1, -1, "bronze", 9, "silver -1 falls into bronze")
	_expect_rank("gold", 1, -1, "silver", 9, "gold -1 falls into silver")
	_expect_rank("platinum", 1, -1, "gold", 16, "platinum -1 falls into gold")
	_expect_rank("diamond", 1, -1, "platinum", 16, "diamond -1 falls into platinum")
	_expect_rank("star", 1, -1, "diamond", 25, "star -1 falls into diamond")
	_expect_rank("king", 1, -1, "star", 25, "king -1 falls into star")


func _test_rank_floor_and_king_growth() -> void:
	_expect_rank("bronze", 1, -1, "bronze", 1, "bronze floor is preserved")
	_expect_rank("king", 4, 3, "king", 7, "king stars remain unbounded")


func _test_legacy_star_result_wrapper() -> void:
	var win_result = RankingRules.star_result("bronze", 9, true)
	_expect_result(win_result, "silver", 1, 1, true, "legacy win wrapper")
	var loss_result = RankingRules.star_result("king", 1, false)
	_expect_result(loss_result, "star", 25, -1, false, "legacy loss wrapper")


func _expect_rank(
	rank_key: String,
	stars: int,
	star_delta: int,
	expected_rank_key: String,
	expected_stars: int,
	label: String
) -> void:
	var result = RankingRules.star_result_for_delta(rank_key, stars, star_delta)
	_expect_result(result, expected_rank_key, expected_stars, star_delta, star_delta > 0, label)


func _expect_result(
	result: Dictionary,
	expected_rank_key: String,
	expected_stars: int,
	expected_delta: int,
	expected_won: bool,
	label: String
) -> void:
	var new_rank = result.get("new_rank", {})
	var actual = [
		String(new_rank.get("key", "")),
		int(new_rank.get("stars", 0)),
		int(result.get("star_delta", 0)),
		bool(result.get("won", false)),
	]
	var expected = [expected_rank_key, expected_stars, expected_delta, expected_won]
	if actual == expected:
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])
