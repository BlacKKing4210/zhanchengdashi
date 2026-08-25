extends RefCounted

const USERNAME_MIN_LENGTH = 2
const USERNAME_MAX_LENGTH = 16
const DEFAULT_AVATAR_ID = "animal_cat"

const RUNTIME_AVATARS = [
	{"id": "animal_cat", "name": "猫", "path": "res://assets/card_art/animals/cat.png"},
	{"id": "animal_dog", "name": "狗", "path": "res://assets/card_art/animals/dog.png"},
	{"id": "animal_fox", "name": "狐狸", "path": "res://assets/card_art/animals/fox.png"},
	{"id": "animal_rabbit", "name": "兔子", "path": "res://assets/card_art/animals/rabbit.png"},
	{"id": "animal_tiger", "name": "老虎", "path": "res://assets/card_art/animals/tiger.png"},
	{"id": "animal_lion", "name": "狮子", "path": "res://assets/card_art/animals/lion.png"},
	{"id": "animal_elephant", "name": "大象", "path": "res://assets/card_art/animals/elephant.png"},
	{"id": "animal_penguin", "name": "企鹅", "path": "res://assets/card_art/animals/penguin.png"},
	{"id": "animal_otter", "name": "水獭", "path": "res://assets/card_art/animals/otter.png"},
	{"id": "animal_squirrel", "name": "松鼠", "path": "res://assets/card_art/animals/squirrel.png"},
	{"id": "animal_hamster", "name": "仓鼠", "path": "res://assets/card_art/animals/hamster.png"},
	{"id": "animal_monkey", "name": "猴子", "path": "res://assets/card_art/animals/monkey.png"},
]


static func normalize_username(value: Variant) -> String:
	return String(value).strip_edges()


static func username_error(value: Variant) -> String:
	var username = normalize_username(value)
	if username.length() < USERNAME_MIN_LENGTH or username.length() > USERNAME_MAX_LENGTH:
		return "invalid_username_length"
	for index in range(username.length()):
		var code = username.unicode_at(index)
		if code < 32 or (code >= 127 and code <= 159):
			return "invalid_username_characters"
	return ""


static func is_valid_username(value: Variant) -> bool:
	return username_error(value).is_empty()


static func default_username(user_id: Variant, account: Variant = "", auto_generated: bool = false) -> String:
	var canonical_account = normalize_username(account)
	if not auto_generated and is_valid_username(canonical_account):
		return canonical_account.left(USERNAME_MAX_LENGTH)
	var canonical_user_id = String(user_id).strip_edges()
	var suffix_length = mini(4, canonical_user_id.length())
	var suffix = canonical_user_id.right(suffix_length).to_upper()
	var generated = "新玩家%s" % suffix
	return generated.left(USERNAME_MAX_LENGTH)


static func avatar_id_for_card(card_id: Variant) -> String:
	var normalized_card_id = String(card_id).strip_edges().to_lower()
	return "animal_%s" % normalized_card_id if not normalized_card_id.is_empty() else ""


static func avatar_card_id(avatar_id: Variant) -> String:
	var normalized_id = String(avatar_id).strip_edges().to_lower()
	if not normalized_id.begins_with("animal_"):
		return ""
	return normalized_id.trim_prefix("animal_")


static func runtime_avatar_catalog(cards: Array = []) -> Array:
	var source_cards: Array = cards
	if source_cards.is_empty() and FileAccess.file_exists("res://runtime/config/cards.json"):
		var parsed_cards = JSON.parse_string(FileAccess.get_file_as_string("res://runtime/config/cards.json"))
		if typeof(parsed_cards) == TYPE_ARRAY:
			source_cards = parsed_cards as Array
	if source_cards.is_empty():
		return RUNTIME_AVATARS.duplicate(true)
	var result = []
	for card_value in source_cards:
		if typeof(card_value) != TYPE_DICTIONARY:
			continue
		var card: Dictionary = card_value
		var card_id = String(card.get("id", "")).strip_edges().to_lower()
		var art_path = String(card.get("art_path", "")).strip_edges()
		if card_id.is_empty() or not art_path.contains("/animals/"):
			continue
		result.append({
			"id": avatar_id_for_card(card_id),
			"card_id": card_id,
			"name": String(card.get("name", card_id)).strip_edges(),
			"path": art_path,
			"rarity": String(card.get("rarity", "common")).strip_edges().to_lower(),
		})
	return result if not result.is_empty() else RUNTIME_AVATARS.duplicate(true)


static func avatar_definition(avatar_id: Variant, cards: Array = []) -> Dictionary:
	var normalized_id = String(avatar_id).strip_edges().to_lower()
	for entry_value in runtime_avatar_catalog(cards):
		var entry: Dictionary = entry_value
		if String(entry.get("id", "")) == normalized_id:
			return entry.duplicate(true)
	return {}


static func is_runtime_avatar_id(avatar_id: Variant, animal_card_ids: Array = []) -> bool:
	if animal_card_ids.is_empty():
		return not avatar_definition(avatar_id).is_empty()
	var card_id = avatar_card_id(avatar_id)
	if card_id.is_empty():
		return false
	for allowed_value in animal_card_ids:
		if String(allowed_value).strip_edges().to_lower() == card_id:
			return true
	return false


static func avatar_texture_path(avatar_id: Variant, cards: Array = []) -> String:
	return String(avatar_definition(avatar_id, cards).get("path", ""))


static func normalized_avatar_id(avatar_id: Variant, cards: Array = []) -> String:
	var normalized_id = String(avatar_id).strip_edges().to_lower()
	return normalized_id if not avatar_definition(normalized_id, cards).is_empty() else DEFAULT_AVATAR_ID


static func avatar_is_unlocked(
	avatar_id: Variant,
	card_counts: Dictionary,
	current_avatar_id: Variant = ""
) -> bool:
	var normalized_id = String(avatar_id).strip_edges().to_lower()
	if normalized_id.is_empty():
		return false
	if normalized_id == String(current_avatar_id).strip_edges().to_lower():
		return true
	var card_id = avatar_card_id(normalized_id)
	return not card_id.is_empty() and int(card_counts.get(card_id, 0)) > 0


static func avatar_unlock_hint(definition: Dictionary) -> String:
	var display_name = String(definition.get("name", definition.get("card_id", "该动物"))).strip_edges()
	if display_name.is_empty():
		display_name = "该动物"
	return "获得【%s】动物卡后解锁，可通过抽卡获得" % display_name
