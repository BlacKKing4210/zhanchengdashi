extends SceneTree

const CardRules = preload("res://scripts/app/systems/card_rules.gd")

var failures = 0


func _init() -> void:
	_test_ranged_animals_gain_guaranteed_health_every_two_levels()
	_test_summon_animals_gain_guaranteed_health_even_when_melee()
	_test_non_qualifying_cards_keep_their_existing_formula()
	if failures == 0:
		print("Card upgrade health rule tests passed.")
	quit(failures)


func _test_ranged_animals_gain_guaranteed_health_every_two_levels() -> void:
	var card = _card("ranged", 1, 80.0, "", ["ranged"])
	_expect_equal(CardRules.guaranteed_upgrade_hp_bonus(card, {"ranged": 1}), 0, "ranged level one has no bonus")
	_expect_equal(CardRules.guaranteed_upgrade_hp_bonus(card, {"ranged": 2}), 1, "ranged level two gains one guaranteed health")
	_expect_equal(CardRules.guaranteed_upgrade_hp_bonus(card, {"ranged": 3}), 1, "ranged level three keeps one guaranteed health")
	_expect_equal(CardRules.guaranteed_upgrade_hp_bonus(card, {"ranged": 4}), 2, "ranged level four gains two guaranteed health")
	_expect_equal(int(CardRules.card_stats(card, {"ranged": 2})["max_hp"]), 2, "one-health ranged animal visibly gains health at level two")


func _test_summon_animals_gain_guaranteed_health_even_when_melee() -> void:
	var card = _card("summoner", 4, 40.0, "summon", ["summon"])
	_expect_true(CardRules.is_ranged_or_summon_animal(card), "melee summon animal qualifies for the health rule")
	_expect_equal(CardRules.guaranteed_upgrade_hp_bonus(card, {"summoner": 2}), 1, "melee summon gains health at level two")
	_expect_equal(CardRules.guaranteed_upgrade_hp_bonus(card, {"summoner": 6}), 3, "melee summon gains health at every second level")


func _test_non_qualifying_cards_keep_their_existing_formula() -> void:
	var melee_card = _card("melee", 10, 40.0, "", ["bruiser"])
	var building_card = _card("tower", 10, 80.0, "", ["building", "defense", "tower"])
	_expect_false(CardRules.is_ranged_or_summon_animal(melee_card), "melee animal does not receive the special bonus")
	_expect_equal(CardRules.guaranteed_upgrade_hp_bonus(melee_card, {"melee": 8}), 0, "melee animal has no special bonus")
	_expect_false(CardRules.is_ranged_or_summon_animal(building_card), "ranged building does not receive the animal bonus")
	_expect_equal(CardRules.guaranteed_upgrade_hp_bonus(building_card, {"tower": 8}), 0, "building has no special bonus")


func _card(card_id: String, hp: int, attack_range: float, effect: String, tags: Array) -> Dictionary:
	return {
		"id": card_id,
		"base_attack": 1,
		"base_max_hp": hp,
		"base_move_speed": 40.0,
		"base_attack_range": attack_range,
		"base_summon_interval_sec": 5.0,
		"skill_effect": effect,
		"tags": tags,
	}


func _expect_true(value: bool, label: String) -> void:
	if value:
		return
	failures += 1
	push_error(label)


func _expect_false(value: bool, label: String) -> void:
	_expect_true(not value, label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])
