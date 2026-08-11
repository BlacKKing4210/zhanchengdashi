## Zhanchengdashi's profile adapter. Other games replace this file, not session logic.
extends "res://scripts/foundation/account/profile_adapter.gd"

const RankMirrorRules = preload("res://scripts/app/systems/rank_mirror_rules.gd")

const RANK_NAMES = {
	"bronze": "青铜", "silver": "白银", "gold": "黄金", "platinum": "铂金",
	"diamond": "钻石", "star": "星耀", "king": "王者",
}


func normalize_profile(source: Dictionary) -> Dictionary:
	var mirror_policy_version = maxi(0, int(source.get("rank_mirror_policy_version", 0)))
	var rank_mirrors = _normalize_rank_mirrors(source.get("rank_mirrors", {}))
	rank_mirrors = RankMirrorRules.migrate_legacy_mirrors(rank_mirrors, mirror_policy_version)
	return {
		"card_counts": _positive_int_dictionary(source.get("card_counts", {}), 0),
		"card_levels": _positive_int_dictionary(source.get("card_levels", {}), 1),
		"deck": _string_array(source.get("deck", []), 8),
		"gacha_tickets": maxi(0, int(source.get("gacha_tickets", 10))),
		"rank_stars": maxi(0, int(source.get("rank_stars", 1))),
		"rank_key": String(source.get("rank_key", "bronze")).strip_edges(),
		"elo": maxi(0, int(source.get("elo", 1000))),
		"rank_mirrors": rank_mirrors,
		"rank_mirror_policy_version": RankMirrorRules.POLICY_VERSION,
	}


func summary_for_profile(profile: Dictionary, animal_card_ids: Array = []) -> Dictionary:
	var rank_key = String(profile.get("rank_key", "bronze")).strip_edges().to_lower()
	var rank_stars = maxi(1, int(profile.get("rank_stars", 1)))
	return {
		"rank_key": rank_key,
		"rank_stars": rank_stars,
		"rank_display": "%s %d星" % [String(RANK_NAMES.get(rank_key, RANK_NAMES["bronze"])), rank_stars],
		"animal_count": _animal_count(profile, animal_card_ids),
	}


func token_namespace() -> String:
	return "zhanchengdashi-v1"


func installation_token_prefix() -> String:
	return "zhanchengdashi-installation-v1:"


func refresh_token_prefix() -> String:
	return "zhanchengdashi-refresh-v1:"




func _animal_count(profile: Dictionary, animal_card_ids: Array) -> int:
	var allowed_ids = {}
	for raw_card_id in animal_card_ids:
		var card_id = String(raw_card_id).strip_edges()
		if not card_id.is_empty():
			allowed_ids[card_id] = true
	var count = 0
	var card_counts = profile.get("card_counts", {})
	if typeof(card_counts) != TYPE_DICTIONARY:
		return 0
	for raw_card_id in card_counts:
		var card_id = String(raw_card_id)
		if allowed_ids.is_empty() or allowed_ids.has(card_id):
			count += maxi(0, int(card_counts[raw_card_id]))
	return count


func _normalize_rank_mirrors(value: Variant) -> Dictionary:
	var result = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for raw_rank_key in value:
		var rank_key = String(raw_rank_key).strip_edges().to_lower()
		if rank_key.is_empty() or rank_key.length() > 24 or typeof(value[raw_rank_key]) != TYPE_ARRAY:
			continue
		var records = []
		for raw_record in value[raw_rank_key]:
			if typeof(raw_record) != TYPE_DICTIONARY:
				continue
			var record: Dictionary = raw_record
			var record_deck = _string_array(record.get("deck", []), 8)
			if record_deck.is_empty():
				continue
			var levels = _positive_int_dictionary(record.get("card_levels", {}), 1)
			var deck_levels = {}
			for card_id in record_deck:
				deck_levels[card_id] = maxi(1, int(levels.get(card_id, 1)))
			records.append({"mirror_id": String(record.get("mirror_id", "")).strip_edges().left(80), "player_id": String(record.get("player_id", "")).strip_edges().left(80), "name": String(record.get("name", "")).strip_edges().left(40), "rank_key": rank_key, "rank_display": String(record.get("rank_display", "")).strip_edges().left(40), "stars": maxi(0, int(record.get("stars", 0))), "elo": maxi(0, int(record.get("elo", 0))), "deck": record_deck, "card_levels": deck_levels, "created_at_unix": maxi(0, int(record.get("created_at_unix", 0)))})
			if records.size() >= 15:
				break
		if not records.is_empty():
			result[rank_key] = records
	return result


func _positive_int_dictionary(value: Variant, minimum: int) -> Dictionary:
	var result = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for key in value:
		var id = String(key).strip_edges()
		if not id.is_empty():
			result[id] = maxi(minimum, int(value[key]))
	return result


func _string_array(value: Variant, limit: int) -> Array:
	var result = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		var id = String(item).strip_edges()
		if not id.is_empty() and not result.has(id):
			result.append(id)
		if result.size() >= limit:
			break
	return result
