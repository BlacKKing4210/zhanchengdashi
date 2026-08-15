extends Node

const MainApp = preload("res://scripts/app/main.gd")
const BoardRules = preload("res://scripts/app/systems/board_rules.gd")

const SUPPORTED_EFFECTS = {
	"aura": ["buff_attack", "buff_hp", "buff_speed", "shield"],
	"on_spawn": ["gold", "shield", "buff_attack", "buff_hp", "buff_speed", "stun", "copy"],
	"on_attack": ["gold", "slow", "stun", "damage", "shield", "execute"],
	"on_damage": ["gold", "heal", "shield", "thorns"],
	"on_death": ["gold", "summon"],
	"on_ally_death": ["gold"],
	"on_capture": ["gold"],
	"on_interval": ["gold", "heal", "shield", "repair"],
}

const GROUP_STAT_SNAPSHOT_RULES = {
	"sheep": {"effect": "buff_hp", "power": 1.0, "stat": "hp", "expected_bonus": 1.0},
	"fox": {"effect": "buff_attack", "power": 1.0, "stat": "attack", "expected_bonus": 1.0},
	"swan": {"effect": "buff_attack", "power": 1.0, "stat": "attack", "expected_bonus": 1.0},
	"horse": {"effect": "buff_speed", "power": 20.0, "stat": "speed", "expected_bonus": 10.0},
	"zebra": {"effect": "buff_attack", "power": 1.0, "stat": "attack", "expected_bonus": 4.0},
	"giraffe": {"effect": "buff_hp", "power": 3.0, "stat": "hp", "expected_bonus": 3.0},
}

var failures = 0
var app: Node


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	await get_tree().process_frame
	_test_structured_animal_skill_contracts()
	_test_group_stat_snapshot_configuration()
	_test_skill_display_uses_cards_csv_only()
	_test_duck_death_summon_feedback()
	_test_text_skill_runtime_alignment()
	_test_group_stat_spawn_snapshots()
	if failures == 0:
		print("Animal skill audit tests passed.")
	app.queue_free()
	get_tree().quit(failures)


func _test_structured_animal_skill_contracts() -> void:
	var structured_count = 0
	for card in app.get("cards"):
		if String(app.call("_card_kind", card)) != "animal":
			continue
		var trigger = String(card.get("skill_trigger", ""))
		var effect = String(card.get("skill_effect", ""))
		if trigger.is_empty() and effect.is_empty():
			continue
		structured_count += 1
		_expect_true(SUPPORTED_EFFECTS.has(trigger), "%s uses a known trigger %s" % [card.get("id", ""), trigger])
		_expect_true(
			SUPPORTED_EFFECTS.has(trigger) and (SUPPORTED_EFFECTS[trigger] as Array).has(effect),
			"%s uses a supported %s/%s effect pair" % [card.get("id", ""), trigger, effect]
		)
	_expect_true(structured_count > 0, "animal skill audit finds structured cards")


func _test_group_stat_snapshot_configuration() -> void:
	var text_ids = []
	var tagged_ids = []
	for card in app.get("cards"):
		if String(app.call("_card_kind", card)) != "animal":
			continue
		var card_id = String(card.get("id", ""))
		var text = String(card.get("skill_text", ""))
		if _is_group_stat_skill_text(text):
			text_ids.append(card_id)
		if not bool(app.call("_card_has_tag", card, "group_buff")):
			continue
		tagged_ids.append(card_id)
		_expect_true(GROUP_STAT_SNAPSHOT_RULES.has(card_id), "%s is an approved group-stat snapshot card" % card_id)
		if not GROUP_STAT_SNAPSHOT_RULES.has(card_id):
			continue
		var rule: Dictionary = GROUP_STAT_SNAPSHOT_RULES[card_id]
		_expect_equal(String(card.get("skill_trigger", "")), "on_spawn", "%s triggers only on summon" % card_id)
		_expect_equal(String(card.get("skill_effect", "")), String(rule["effect"]), "%s has the matching group-stat effect" % card_id)
		_expect_close(float(card.get("skill_power", 0.0)), float(rule["power"]), "%s has the matching group-stat power" % card_id)
		_expect_close(float(card.get("skill_cooldown_sec", 0.0)), 0.0, "%s has no periodic cooldown" % card_id)
	var expected_ids = GROUP_STAT_SNAPSHOT_RULES.keys()
	expected_ids.sort()
	text_ids.sort()
	tagged_ids.sort()
	_expect_equal(text_ids, expected_ids, "all and only current allied group-stat skill texts are audited")
	_expect_equal(tagged_ids, expected_ids, "all and only current allied group-stat skills use the snapshot tag")


func _is_group_stat_skill_text(text: String) -> bool:
	return (
		text.contains("我方动物攻击+1")
		or text.contains("所有动物攻击+1")
		or text.contains("我方所有动物速度+20")
		or text.contains("每20点速度，提供1攻击力")
		or text.contains("所有友军生命+1")
		or text.contains("提高所有友军生命值3点")
	)


func _test_duck_death_summon_feedback() -> void:
	app.call("_reset_battle")
	var duck = app.call("_card_by_id", "duck")
	_expect_equal(
		String(app.call("_card_display_skill_text", duck, true)),
		String(duck.get("skill_text", "")).strip_edges(),
		"duck card detail mirrors cards.csv and does not invent a skill description"
	)
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, "duck")
	_expect_true((app.get("units") as Array).size() == 1, "duck enters the battle")
	app.call("_damage_unit", 0, 999.0, -1, BoardRules.NEUTRAL)
	var units: Array = app.get("units")
	_expect_equal(units.size(), 2, "duck death creates exactly one replacement duck")
	if units.size() >= 2:
		_expect_equal(String(units[units.size() - 1].get("card", "")), "duck", "duck replacement preserves its card id")
		_expect_false(bool(units[units.size() - 1].get("skill_triggers_enabled", true)), "duck replacement cannot trigger skills again")
		app.call("_damage_unit", units.size() - 1, 999.0, -1, BoardRules.NEUTRAL)
		_expect_equal((app.get("units") as Array).size(), 2, "disabled duck replacement does not create a third duck")
	var has_summon_feedback = false
	for effect in app.get("effects"):
		if String(effect.get("kind", "")) == "unit_value" and String(effect.get("stat", "")) == "summon":
			has_summon_feedback = true
	_expect_true(has_summon_feedback, "duck replacement creates a visible summon feedback effect")
	_test_non_cyclic_death_summon_keeps_skills()


func _test_skill_display_uses_cards_csv_only() -> void:
	for card in app.get("cards"):
		var expected = String(card.get("skill_text", "")).strip_edges()
		_expect_equal(
			String(app.call("_card_display_skill_text", card, true)),
			expected,
			"%s displays only its configured skill_text" % String(card.get("id", ""))
		)
		if expected == "":
			_expect_equal(
				String(app.call("_card_skill_text", card)),
				"",
				"%s hides its skill line when cards.csv has no description" % String(card.get("id", ""))
			)


func _test_non_cyclic_death_summon_keeps_skills() -> void:
	app.call("_reset_battle")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, "silverback")
	app.call("_damage_unit", 0, 999.0, -1, BoardRules.NEUTRAL)
	var units: Array = app.get("units")
	_expect_equal(units.size(), 2, "silverback death creates one gorilla")
	if units.size() >= 2:
		var replacement: Dictionary = units[units.size() - 1]
		_expect_equal(String(replacement.get("card", "")), "gorilla", "silverback keeps its intended non-cyclic summon")
		_expect_false(bool(replacement.get("skill_triggers_enabled", true)), "silverback replacement honours its configured no-skill description")


func _test_text_skill_runtime_alignment() -> void:
	_test_text_death_and_capture_rewards()
	_test_text_damage_and_aura_rules()
	_test_hedgehog_melee_thorns_rule()
	_test_text_poison_rule()
	_test_text_ranged_kill_reward()


func _test_text_death_and_capture_rewards() -> void:
	app.call("_reset_battle")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, "chicken")
	var gold_before = int(app.get("gold"))
	app.call("_damage_unit", 0, 999.0, -1, BoardRules.NEUTRAL)
	_expect_equal(int(app.get("gold")), gold_before + 1, "chicken death reward follows its skill_text")

	app.call("_reset_battle")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, "hamster")
	app.call("_spawn_unit", BoardRules.ENEMY, Vector2i(1, 0), "mouse")
	app.call("_damage_unit", 0, 999.0, 1, BoardRules.ENEMY)
	var units: Array = app.get("units")
	_expect_equal(int(units[1].get("attack", 0.0)), 2, "hamster death grants the killer attack +1")
	_expect_equal(int(units[1].get("max_hp", 0.0)), 2, "hamster death grants the killer life +1")

	app.call("_reset_battle")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, "squirrel")
	gold_before = int(app.get("gold"))
	app.call("_apply_unit_capture_skill", 0, Vector2i.ZERO)
	_expect_equal(int(app.get("gold")), gold_before + 5, "squirrel capture reward follows its skill_text")

	app.call("_reset_battle")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, "cow")
	gold_before = int(app.get("gold"))
	app.call("_apply_unit_capture_skill", 0, Vector2i.ZERO)
	_expect_equal(int(app.get("gold")), gold_before + 3, "cow capture reward follows its skill_text")

	app.call("_reset_battle")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, "otter")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i(1, 0), "mouse")
	gold_before = int(app.get("gold"))
	app.call("_damage_unit", 1, 999.0, -1, BoardRules.NEUTRAL)
	_expect_equal(int(app.get("gold")), gold_before + 1, "otter ally-death reward follows its skill_text")


func _test_text_damage_and_aura_rules() -> void:
	app.call("_reset_battle")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, "beaver")
	var units: Array = app.get("units")
	var beaver_damage = float(app.call("_unit_attack_damage_against_target", 0, {"kind": "building"}))
	_expect_close(beaver_damage, float(units[0].get("attack", 0.0)) * 2.0, "beaver doubles damage against buildings")

	app.call("_reset_battle")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, "peacock")
	app.call("_spawn_unit", BoardRules.ENEMY, Vector2i(1, 0), "sparrow")
	units = app.get("units")
	var peacock_damage = float(app.call("_unit_attack_damage_against_target", 0, {"kind": "unit", "index": 1}))
	_expect_close(peacock_damage, float(units[0].get("attack", 0.0)) * 2.0, "peacock doubles damage against ranged units")

	app.call("_reset_battle")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, "polar_bear")
	_expect_close(float(app.call("_incoming_unit_damage", 0, 5.0)), 3.0, "polar bear reduces incoming damage by 2")

	var boar: Dictionary = app.call("_card_by_id", "boar")
	_expect_true(bool(app.call("_card_has_priority_attack_text", boar)), "boar priority attack wording is recognized")


func _test_group_stat_spawn_snapshots() -> void:
	for card_id in GROUP_STAT_SNAPSHOT_RULES.keys():
		_run_group_stat_spawn_snapshot_case(String(card_id), GROUP_STAT_SNAPSHOT_RULES[card_id])


func _run_group_stat_spawn_snapshot_case(card_id: String, rule: Dictionary) -> void:
	app.call("_reset_battle")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, "snail")
	app.call("_spawn_unit", BoardRules.ENEMY, Vector2i(1, 0), "snail")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i(2, 0), card_id)
	var units: Array = app.get("units")
	var stat = String(rule["stat"])
	var expected_bonus = float(rule["expected_bonus"])
	_expect_equal(units.size(), 3, "%s setup creates exactly ally, enemy, and source" % card_id)
	_expect_close(_unit_stat_bonus(units[0], stat), expected_bonus, "%s buffs the ally present at summon" % card_id)
	_expect_close(_unit_stat_bonus(units[1], stat), 0.0, "%s excludes the enemy" % card_id)
	_expect_close(_unit_stat_bonus(units[2], stat), expected_bonus, "%s includes the summoned source itself" % card_id)
	var ally_value_after_spawn = _unit_stat_value(units[0], stat)
	for tick in range(4):
		app.call("_refresh_unit_skill_state", 0.25)
	units = app.get("units")
	_expect_close(_unit_stat_bonus(units[0], stat), expected_bonus, "%s does not repeat during timed refresh" % card_id)
	_expect_close(_unit_stat_value(units[0], stat), ally_value_after_spawn, "%s keeps one stable derived bonus after refresh" % card_id)
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i(3, 0), "snail")
	units = app.get("units")
	_expect_close(_unit_stat_bonus(units[3], stat), 0.0, "%s does not backfill an ally summoned later" % card_id)
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i(4, 0), card_id)
	units = app.get("units")
	_expect_equal(units.size(), 5, "%s second source adds exactly one animal" % card_id)
	_expect_close(_unit_stat_bonus(units[0], stat), expected_bonus * 2.0, "%s second summon adds one new snapshot to the original ally" % card_id)
	_expect_close(_unit_stat_bonus(units[2], stat), expected_bonus * 2.0, "%s first source receives the second summon snapshot" % card_id)
	_expect_close(_unit_stat_bonus(units[3], stat), expected_bonus, "%s late ally receives only the later snapshot" % card_id)
	_expect_close(_unit_stat_bonus(units[4], stat), expected_bonus, "%s second source receives only its own snapshot" % card_id)
	_expect_close(_unit_stat_bonus(units[1], stat), 0.0, "%s never buffs the enemy across repeated summons" % card_id)


func _unit_stat_bonus(unit: Dictionary, stat: String) -> float:
	match stat:
		"attack":
			return float(unit.get("attack_bonus", 0.0))
		"hp":
			return float(unit.get("max_hp_bonus", 0.0))
		"speed":
			return float(unit.get("speed_bonus", 0.0))
	return 0.0


func _unit_stat_value(unit: Dictionary, stat: String) -> float:
	match stat:
		"attack":
			return float(unit.get("attack", 0.0))
		"hp":
			return float(unit.get("max_hp", 0.0))
		"speed":
			return float(unit.get("speed", 0.0))
	return 0.0


func _test_hedgehog_melee_thorns_rule() -> void:
	var hedgehog_card: Dictionary = app.call("_card_by_id", "hedgehog")
	_expect_equal(
		String(hedgehog_card.get("skill_text", "")),
		"受到近战伤害时，对伤害来源造成3伤害。",
		"hedgehog skill text follows the updated cards.csv design"
	)

	app.call("_reset_battle")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, "hedgehog")
	app.call("_spawn_unit", BoardRules.ENEMY, Vector2i(1, 0), "snail")
	var units: Array = app.get("units")
	var melee_hp_before = float(units[1].get("hp", 0.0))
	_expect_close(float(app.call("_unit_effect_damage", units[0])), 3.0, "hedgehog skill power maps to 3 thorns damage")
	app.call("_damage_unit", 0, 1.0, 1, BoardRules.ENEMY)
	units = app.get("units")
	_expect_close(float(units[1].get("hp", 0.0)), melee_hp_before - 3.0, "hedgehog reflects 3 damage after actual melee damage")

	app.call("_reset_battle")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, "hedgehog")
	app.call("_spawn_unit", BoardRules.ENEMY, Vector2i(1, 0), "sparrow")
	units = app.get("units")
	var sparrow_hp_before = float(units[1].get("hp", 0.0))
	app.call("_damage_unit", 0, 1.0, 1, BoardRules.ENEMY)
	units = app.get("units")
	_expect_close(float(units[1].get("hp", 0.0)), sparrow_hp_before, "hedgehog does not reflect ranged damage")

	app.call("_reset_battle")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, "hedgehog")
	app.call("_spawn_unit", BoardRules.ENEMY, Vector2i(1, 0), "hedgehog")
	units = app.get("units")
	var defender_hp_before = float(units[0].get("hp", 0.0))
	var attacker_hp_before = float(units[1].get("hp", 0.0))
	app.call("_damage_unit", 0, 1.0, 1, BoardRules.ENEMY)
	units = app.get("units")
	_expect_close(float(units[0].get("hp", 0.0)), defender_hp_before - 1.0, "hedgehog reflection does not feed back into the defender")
	_expect_close(float(units[1].get("hp", 0.0)), attacker_hp_before - 3.0, "hedgehog reflection deals one non-recursive hit")


func _test_text_poison_rule() -> void:
	app.call("_reset_battle")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, "komodo_dragon")
	app.call("_spawn_unit", BoardRules.ENEMY, Vector2i(1, 0), "hippo")
	app.call("_apply_unit_attack_skill", 0, {"kind": "unit", "index": 1})
	var units: Array = app.get("units")
	_expect_true(float(units[1].get("poison_timer", 0.0)) > 0.0, "komodo attack applies poison")
	app.call("_refresh_unit_skill_state", 1.0)
	units = app.get("units")
	_expect_close(float(units[1].get("hp", 0.0)), 8.0, "komodo poison deals 50 percent max-life damage each second")


func _test_text_ranged_kill_reward() -> void:
	app.call("_reset_battle")
	app.call("_spawn_unit", BoardRules.PLAYER, Vector2i.ZERO, "leopard")
	app.call("_spawn_unit", BoardRules.ENEMY, Vector2i(1, 0), "sparrow")
	var gold_before = int(app.get("gold"))
	app.call("_apply_unit_kill_skill", 0, {"kind": "unit", "index": 1})
	_expect_equal(int(app.get("gold")), gold_before + 5, "leopard gets 5 gold only for a ranged kill")


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


func _expect_false(value: bool, label: String) -> void:
	_expect_true(not value, label)


func _expect_close(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) <= 0.001:
		return
	failures += 1
	push_error("%s: expected %.3f, got %.3f" % [label, expected, actual])
