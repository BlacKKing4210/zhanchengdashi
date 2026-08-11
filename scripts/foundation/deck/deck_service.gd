## UI-agnostic deck/loadout validation.
## All IDs are opaque strings; the host project owns card data and presentation.
extends RefCounted


static func normalize(
		current_deck: Array,
		owned_ids: Array,
		slot_count: int,
		required_ids: Array = [],
		allow_duplicates: bool = false
	) -> Array:
	var owned = _unique_ids(owned_ids)
	var target_size = maxi(0, slot_count)
	if target_size == 0 or owned.is_empty():
		return []
	var owned_lookup = _lookup(owned)
	var required = []
	for raw_required_id in _unique_ids(required_ids):
		if owned_lookup.has(raw_required_id) and required.size() < target_size:
			required.append(raw_required_id)
	var result = []
	for raw_card_id in current_deck:
		var card_id = String(raw_card_id).strip_edges()
		if card_id.is_empty() or not owned_lookup.has(card_id) or result.has(card_id):
			continue
		result.append(card_id)
		if result.size() >= target_size:
			break
	for required_id in required:
		if result.has(required_id):
			continue
		var replacement_index = _replacement_index(result, required)
		if replacement_index >= 0:
			result[replacement_index] = required_id
		else:
			result.append(required_id)
	while result.size() < target_size:
		for owned_id in owned:
			if allow_duplicates or not result.has(owned_id):
				result.append(owned_id)
				break
		if result.size() >= target_size or (not allow_duplicates and result.size() >= owned.size()):
			break
	return result.slice(0, target_size)


static func can_replace(deck: Array, slot_index: int, card_id: String, required_ids: Array = []) -> Dictionary:
	if slot_index < 0 or slot_index >= deck.size():
		return {"ok": false, "error": "invalid_slot"}
	var normalized_id = card_id.strip_edges()
	if normalized_id.is_empty():
		return {"ok": false, "error": "invalid_item"}
	if deck.has(normalized_id):
		return {"ok": false, "error": "already_equipped"}
	var candidate = deck.duplicate()
	candidate[slot_index] = normalized_id
	for required_id in _unique_ids(required_ids):
		if not candidate.has(required_id):
			return {"ok": false, "error": "required_item_missing", "required_id": required_id}
	return {"ok": true, "deck": candidate}


static func has_required(deck: Array, required_ids: Array) -> bool:
	for required_id in _unique_ids(required_ids):
		if not deck.has(required_id):
			return false
	return true


static func _replacement_index(deck: Array, required_ids: Array) -> int:
	for index in range(deck.size() - 1, -1, -1):
		if not required_ids.has(String(deck[index])):
			return index
	return -1


static func _unique_ids(values: Array) -> Array:
	var result = []
	for raw_value in values:
		var value = String(raw_value).strip_edges()
		if not value.is_empty() and not result.has(value):
			result.append(value)
	return result


static func _lookup(values: Array) -> Dictionary:
	var result = {}
	for value in values:
		result[String(value)] = true
	return result
