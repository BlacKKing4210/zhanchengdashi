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


static func runtime_avatar_catalog() -> Array:
	return RUNTIME_AVATARS.duplicate(true)


static func avatar_definition(avatar_id: Variant) -> Dictionary:
	var normalized_id = String(avatar_id).strip_edges().to_lower()
	for entry_value in RUNTIME_AVATARS:
		var entry: Dictionary = entry_value
		if String(entry.get("id", "")) == normalized_id:
			return entry.duplicate(true)
	return {}


static func is_runtime_avatar_id(avatar_id: Variant) -> bool:
	return not avatar_definition(avatar_id).is_empty()


static func avatar_texture_path(avatar_id: Variant) -> String:
	return String(avatar_definition(avatar_id).get("path", ""))


static func normalized_avatar_id(avatar_id: Variant) -> String:
	var normalized_id = String(avatar_id).strip_edges().to_lower()
	return normalized_id if is_runtime_avatar_id(normalized_id) else DEFAULT_AVATAR_ID
