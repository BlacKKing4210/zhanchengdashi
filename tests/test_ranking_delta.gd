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
	_expect_rank("bronze", 3, 3, "silver", 3, "bronze +3 crosses into silver")
	_expect_rank("silver", 3, 2, "gold", 2, "silver +2 crosses into gold")
	_expect_rank("gold", 4, 3, "diamond", 3, "gold +3 crosses into diamond")
	_expect_rank("diamond", 5, 2, "king", 2, "diamond +2 crosses into king")


func _test_loss_crosses_rank_boundaries() -> void:
	_expect_rank("silver", 1, -1, "bronze", 3, "silver -1 falls into bronze")
	_expect_rank("gold", 1, -1, "silver", 3, "gold -1 falls into silver")
	_expect_rank("diamond", 1, -1, "gold", 4, "diamond -1 falls into gold")
	_expect_rank("king", 1, -1, "diamond", 5, "king -1 falls into diamond")


func _test_rank_floor_and_king_growth() -> void:
	_expect_rank("bronze", 1, -1, "bronze", 1, "bronze floor is preserved")
	_expect_rank("king", 4, 3, "king", 7, "king stars remain unbounded")


func _test_legacy_star_result_wrapper() -> void:
	var win_result = RankingRules.star_result("bronze", 3, true)
	_expect_result(win_result, "silver", 1, 1, true, "legacy win wrapper")
	var loss_result = RankingRules.star_result("king", 1, false)
	_expect_result(loss_result, "diamond", 5, -1, false, "legacy loss wrapper")


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
