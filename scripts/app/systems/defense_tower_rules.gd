extends RefCounted

const SKILL_BASIC = "defense_basic"
const SKILL_FAR_SIGHT = "defense_far_sight"
const SKILL_HEAVY_BOLT = "defense_heavy_bolt"
const SKILL_PLUNDER = "defense_plunder"
const SKILL_RAPID_FIRE = "defense_rapid_fire"
const SKILL_SHELL_BASTION = "defense_shell_bastion"
const SKILL_TWIN_SHOT = "defense_twin_shot"
const SKILL_BOUNTY = "defense_bounty"
const SKILL_TERRITORY = "defense_territory"
const SKILL_GLOBAL_PULSE = "defense_global_pulse"

const MIN_ATTACK_INTERVAL = 0.10
const RANGED_UNIT_THRESHOLD_TILES = 1.45


static func skill_id(card: Dictionary) -> String:
	return String(card.get("skill_id", ""))


static func prioritizes_ranged(card: Dictionary) -> bool:
	return skill_id(card) == SKILL_FAR_SIGHT


static func plunders_gold(card: Dictionary) -> bool:
	return skill_id(card) == SKILL_PLUNDER


static func has_extra_target(card: Dictionary) -> bool:
	return skill_id(card) == SKILL_TWIN_SHOT


static func awards_kill_bounty(card: Dictionary) -> bool:
	return skill_id(card) == SKILL_BOUNTY


static func uses_territory_range(card: Dictionary) -> bool:
	return skill_id(card) == SKILL_TERRITORY


static func uses_global_animal_pulse(card: Dictionary) -> bool:
	return skill_id(card) == SKILL_GLOBAL_PULSE


static func range_world(range_tiles: float, hex_size: float) -> float:
	return maxf(0.0, range_tiles) * maxf(0.0, hex_size) * sqrt(3.0)


static func interval_seconds(base_interval: float, level_multiplier: float) -> float:
	return maxf(MIN_ATTACK_INTERVAL, maxf(MIN_ATTACK_INTERVAL, base_interval) / maxf(0.01, level_multiplier))


static func is_ranged_unit(unit: Dictionary, hex_size: float) -> bool:
	if unit.has("is_ranged"):
		return bool(unit.get("is_ranged", false))
	var stable_range = float(unit.get("base_card_range", unit.get("range", 0.0)))
	return stable_range > maxf(0.0, hex_size) * RANGED_UNIT_THRESHOLD_TILES


static func transfer_amount(available_gold: int, requested_amount: int) -> int:
	return mini(maxi(0, available_gold), maxi(0, requested_amount))


static func extra_target_count(card: Dictionary) -> int:
	if not has_extra_target(card):
		return 0
	return maxi(1, roundi(float(card.get("skill_power", 1.0))))


static func plunder_amount(card: Dictionary) -> int:
	if not plunders_gold(card):
		return 0
	return maxi(1, roundi(float(card.get("skill_power", 1.0))))


static func bounty_amount(card: Dictionary) -> int:
	if not awards_kill_bounty(card):
		return 0
	return maxi(1, roundi(float(card.get("skill_power", 10.0))))


static func pulse_damage(card: Dictionary) -> float:
	if not uses_global_animal_pulse(card):
		return 0.0
	return maxf(0.0, float(card.get("skill_power", 1.0)))
