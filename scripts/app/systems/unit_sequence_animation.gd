extends RefCounted

const MANIFEST_PATH = "res://assets/animal_sequences/manifest.json"
const MANIFEST_VERSION = 1
const ACTION_IDLE = "idle"
const ACTION_MOVE = "move"
const ACTION_ATTACK = "attack"
const MODE_LOOP = "loop"
const MODE_MOTION_PROGRESS = "motion_progress"

const _TOP_LEVEL_KEYS = ["version", "source", "animals"]
const _SOURCE_KEYS = ["archive_name", "archive_size", "archive_sha256", "rights_status"]
const _ANIMAL_KEYS = ["frame_size", "source_rect", "bottom_padding_ratio", "actions", "frame_sha256"]
const _ACTION_KEYS = ["mode", "frames", "fps"]
const _ALLOWED_ACTIONS = [ACTION_IDLE, ACTION_MOVE, ACTION_ATTACK]

static var _manifest_loaded = false
static var _animals: Dictionary = {}
static var _manifest_errors: Array[String] = []
static var _texture_cache: Dictionary = {}
static var _warned_paths: Dictionary = {}


static func reset_for_tests() -> void:
	_manifest_loaded = false
	_animals.clear()
	_manifest_errors.clear()
	_texture_cache.clear()
	_warned_paths.clear()


static func manifest_status() -> Dictionary:
	_ensure_manifest_loaded()
	return {
		"valid": _manifest_errors.is_empty(),
		"errors": _manifest_errors.duplicate(),
		"animal_ids": _animals.keys(),
	}


static func has_sequence(card_id: String) -> bool:
	_ensure_manifest_loaded()
	return _animals.has(card_id)


static func sample_for_unit(card_id: String, unit: Dictionary, time_seconds: float) -> Dictionary:
	_ensure_manifest_loaded()
	if not _animals.has(card_id):
		return {}
	var animal: Dictionary = _animals[card_id]
	var actions: Dictionary = animal["actions"]
	var motion_kind = String(unit.get("motion_kind", "")) if float(unit.get("motion_time", 0.0)) > 0.0 else ""
	var action_id = ACTION_IDLE
	var embedded_motion = ""
	if motion_kind == ACTION_ATTACK and actions.has(ACTION_ATTACK):
		action_id = ACTION_ATTACK
		embedded_motion = ACTION_ATTACK
	elif motion_kind == "" and bool(unit.get("motion_moving", false)) and actions.has(ACTION_MOVE):
		action_id = ACTION_MOVE
		embedded_motion = ACTION_MOVE
	var sample = _sample_action(card_id, animal, action_id, unit, time_seconds)
	if sample.is_empty() and action_id != ACTION_IDLE:
		sample = _sample_action(card_id, animal, ACTION_IDLE, unit, time_seconds)
		embedded_motion = ""
	if not sample.is_empty():
		sample["embedded_motion"] = embedded_motion
	return sample


static func idle_sample(card_id: String, time_seconds: float, seed: int = 0) -> Dictionary:
	_ensure_manifest_loaded()
	if not _animals.has(card_id):
		return {}
	return _sample_action(card_id, _animals[card_id], ACTION_IDLE, {"id": seed}, time_seconds)


static func validate_manifest_data(value: Variant, check_resources: bool = true) -> Dictionary:
	var errors: Array[String] = []
	var normalized_animals: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return {"valid": false, "errors": ["manifest_not_dictionary"], "animals": normalized_animals}
	var root: Dictionary = value
	_validate_exact_keys(root, _TOP_LEVEL_KEYS, "manifest", errors)
	if not _is_integer_number(root.get("version")) or int(root.get("version", -1)) != MANIFEST_VERSION:
		errors.append("manifest_version_invalid")
	_validate_source(root.get("source"), errors)
	var raw_animals = root.get("animals")
	if typeof(raw_animals) != TYPE_DICTIONARY or (raw_animals as Dictionary).is_empty():
		errors.append("animals_invalid")
		return {"valid": false, "errors": errors, "animals": normalized_animals}
	for raw_card_id in (raw_animals as Dictionary).keys():
		var card_id = String(raw_card_id)
		_validate_animal(card_id, (raw_animals as Dictionary)[raw_card_id], check_resources, errors, normalized_animals)
	return {"valid": errors.is_empty(), "errors": errors, "animals": normalized_animals}


static func _validate_source(value: Variant, errors: Array[String]) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("source_invalid")
		return
	var source: Dictionary = value
	_validate_exact_keys(source, _SOURCE_KEYS, "source", errors)
	if String(source.get("archive_name", "")).strip_edges() == "":
		errors.append("source_archive_name_invalid")
	if not _is_integer_number(source.get("archive_size")) or int(source.get("archive_size", 0)) <= 0:
		errors.append("source_archive_size_invalid")
	if not _is_sha256(String(source.get("archive_sha256", ""))):
		errors.append("source_archive_sha256_invalid")
	if String(source.get("rights_status", "")).strip_edges() == "":
		errors.append("source_rights_status_invalid")


static func _validate_animal(card_id: String, value: Variant, check_resources: bool, errors: Array[String], normalized: Dictionary) -> void:
	if card_id == "" or card_id != card_id.to_lower() or not card_id.is_valid_identifier():
		errors.append("animal_id_invalid:%s" % card_id)
		return
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("animal_invalid:%s" % card_id)
		return
	var animal: Dictionary = value
	_validate_exact_keys(animal, _ANIMAL_KEYS, "animal:%s" % card_id, errors)
	var frame_size = _positive_pair(animal.get("frame_size"), "frame_size:%s" % card_id, errors)
	var source_rect = _source_rect(animal.get("source_rect"), frame_size, card_id, errors)
	var bottom_padding = animal.get("bottom_padding_ratio")
	if not _is_number(bottom_padding) or float(bottom_padding) < 0.0 or float(bottom_padding) > 0.5:
		errors.append("bottom_padding_invalid:%s" % card_id)
	var raw_actions = animal.get("actions")
	var raw_hashes = animal.get("frame_sha256")
	if typeof(raw_actions) != TYPE_DICTIONARY or not (raw_actions as Dictionary).has(ACTION_IDLE):
		errors.append("actions_or_idle_invalid:%s" % card_id)
		return
	if typeof(raw_hashes) != TYPE_DICTIONARY:
		errors.append("frame_hashes_invalid:%s" % card_id)
		return
	var actions: Dictionary = {}
	var expected_hash_paths: Dictionary = {}
	for raw_action_id in (raw_actions as Dictionary).keys():
		var action_id = String(raw_action_id)
		if not _ALLOWED_ACTIONS.has(action_id):
			errors.append("action_id_invalid:%s:%s" % [card_id, action_id])
			continue
		var action = _validate_action(card_id, action_id, (raw_actions as Dictionary)[raw_action_id], check_resources, errors, expected_hash_paths)
		if not action.is_empty():
			actions[action_id] = action
	for raw_path in (raw_hashes as Dictionary).keys():
		var path = String(raw_path)
		if not expected_hash_paths.has(path) or not _is_sha256(String((raw_hashes as Dictionary)[raw_path])):
			errors.append("frame_hash_invalid:%s:%s" % [card_id, path])
	for path in expected_hash_paths.keys():
		if not (raw_hashes as Dictionary).has(path):
			errors.append("frame_hash_missing:%s:%s" % [card_id, path])
	if actions.has(ACTION_IDLE) and not frame_size.is_empty() and not source_rect.is_empty() and _is_number(bottom_padding):
		normalized[card_id] = {
			"frame_size": Vector2(float(frame_size[0]), float(frame_size[1])),
			"source_rect": Rect2(float(source_rect[0]), float(source_rect[1]), float(source_rect[2]), float(source_rect[3])),
			"bottom_padding_ratio": clampf(float(bottom_padding), 0.0, 0.5),
			"actions": actions,
		}


static func _validate_action(card_id: String, action_id: String, value: Variant, check_resources: bool, errors: Array[String], expected_hash_paths: Dictionary) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("action_invalid:%s:%s" % [card_id, action_id])
		return {}
	var action: Dictionary = value
	_validate_exact_keys(action, _ACTION_KEYS, "action:%s:%s" % [card_id, action_id], errors, ["fps"])
	var mode = String(action.get("mode", ""))
	if mode != MODE_LOOP and mode != MODE_MOTION_PROGRESS:
		errors.append("action_mode_invalid:%s:%s" % [card_id, action_id])
	if action_id == ACTION_ATTACK and mode != MODE_MOTION_PROGRESS:
		errors.append("attack_mode_invalid:%s" % card_id)
	if action_id != ACTION_ATTACK and mode != MODE_LOOP:
		errors.append("loop_mode_invalid:%s:%s" % [card_id, action_id])
	if mode == MODE_LOOP and (not _is_number(action.get("fps")) or float(action.get("fps", 0.0)) <= 0.0 or float(action.get("fps", 0.0)) > 60.0):
		errors.append("action_fps_invalid:%s:%s" % [card_id, action_id])
	if mode == MODE_MOTION_PROGRESS and action.has("fps"):
		errors.append("motion_progress_fps_not_allowed:%s:%s" % [card_id, action_id])
	var raw_frames = action.get("frames")
	if typeof(raw_frames) != TYPE_ARRAY or (raw_frames as Array).is_empty() or (raw_frames as Array).size() > 120:
		errors.append("action_frames_invalid:%s:%s" % [card_id, action_id])
		return {}
	var frames: Array[String] = []
	var prefix = "res://assets/animal_sequences/%s/%s/" % [card_id, action_id]
	for raw_path in raw_frames as Array:
		if typeof(raw_path) != TYPE_STRING:
			errors.append("frame_path_not_string:%s:%s" % [card_id, action_id])
			continue
		var path = String(raw_path)
		if not path.begins_with(prefix) or not path.ends_with(".png") or path.contains("..") or frames.has(path):
			errors.append("frame_path_invalid:%s:%s:%s" % [card_id, action_id, path])
			continue
		if check_resources and not ResourceLoader.exists(path, "Texture2D"):
			errors.append("frame_resource_missing:%s" % path)
			continue
		frames.append(path)
		expected_hash_paths[path] = true
	if frames.size() != (raw_frames as Array).size():
		return {}
	var result = {"mode": mode, "frames": frames}
	if mode == MODE_LOOP:
		result["fps"] = float(action.get("fps", 0.0))
	return result


static func _positive_pair(value: Variant, label: String, errors: Array[String]) -> Array:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != 2:
		errors.append("%s_invalid" % label)
		return []
	var pair: Array = value
	if not _is_number(pair[0]) or not _is_number(pair[1]) or float(pair[0]) <= 0.0 or float(pair[1]) <= 0.0:
		errors.append("%s_invalid" % label)
		return []
	return [float(pair[0]), float(pair[1])]


static func _source_rect(value: Variant, frame_size: Array, card_id: String, errors: Array[String]) -> Array:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != 4 or frame_size.is_empty():
		errors.append("source_rect_invalid:%s" % card_id)
		return []
	var rect: Array = value
	for item in rect:
		if not _is_number(item):
			errors.append("source_rect_invalid:%s" % card_id)
			return []
	var x = float(rect[0])
	var y = float(rect[1])
	var width = float(rect[2])
	var height = float(rect[3])
	if x < 0.0 or y < 0.0 or width <= 0.0 or height <= 0.0 or x + width > float(frame_size[0]) or y + height > float(frame_size[1]):
		errors.append("source_rect_out_of_bounds:%s" % card_id)
		return []
	return [x, y, width, height]


static func _validate_exact_keys(value: Dictionary, allowed: Array, label: String, errors: Array[String], optional: Array = []) -> void:
	for key in value.keys():
		if not allowed.has(String(key)):
			errors.append("unexpected_key:%s:%s" % [label, String(key)])
	for key in allowed:
		if not optional.has(key) and not value.has(key):
			errors.append("missing_key:%s:%s" % [label, String(key)])


static func _sample_action(card_id: String, animal: Dictionary, action_id: String, unit: Dictionary, time_seconds: float) -> Dictionary:
	var actions: Dictionary = animal["actions"]
	if not actions.has(action_id):
		return {}
	var action: Dictionary = actions[action_id]
	var frames: Array = action["frames"]
	var frame_index = 0
	if String(action["mode"]) == MODE_MOTION_PROGRESS:
		var duration = maxf(0.001, float(unit.get("motion_duration", 0.0)))
		var progress = clampf(1.0 - float(unit.get("motion_time", duration)) / duration, 0.0, 1.0)
		frame_index = mini(int(floor(progress * float(frames.size()))), frames.size() - 1)
	else:
		var seed = posmod(int(unit.get("id", 0)), frames.size())
		frame_index = posmod(int(floor(maxf(0.0, time_seconds) * float(action["fps"]))) + seed, frames.size())
	var texture_path = String(frames[frame_index])
	var texture = _load_texture(texture_path)
	if texture == null:
		return {}
	return {
		"action": action_id,
		"frame_index": frame_index,
		"texture_path": texture_path,
		"texture": texture,
		"source_rect": animal["source_rect"],
		"bottom_padding_ratio": float(animal["bottom_padding_ratio"]),
	}


static func _load_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var resource = ResourceLoader.load(path, "Texture2D")
	if resource is Texture2D:
		_texture_cache[path] = resource
		return resource
	if not _warned_paths.has(path):
		_warned_paths[path] = true
		push_warning("Sequence frame could not be loaded; generic animation fallback will be used: %s" % path)
	_texture_cache[path] = null
	return null


static func _ensure_manifest_loaded() -> void:
	if _manifest_loaded:
		return
	_manifest_loaded = true
	var file = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		_manifest_errors = ["manifest_open_failed"]
		push_warning("Animal sequence manifest is unavailable; generic animation fallback remains active.")
		return
	var raw_text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(raw_text)
	var validation = validate_manifest_data(parsed, true)
	_manifest_errors.assign(validation["errors"])
	if not bool(validation["valid"]):
		push_warning("Animal sequence manifest is invalid; generic animation fallback remains active: %s" % ", ".join(_manifest_errors))
		return
	_animals = validation["animals"]


static func _is_sha256(value: String) -> bool:
	if value.length() != 64 or value != value.to_lower():
		return false
	for character in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _is_integer_number(value: Variant) -> bool:
	return _is_number(value) and is_equal_approx(float(value), floor(float(value)))
