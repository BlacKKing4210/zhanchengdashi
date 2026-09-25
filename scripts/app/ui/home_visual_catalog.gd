extends RefCounted
## Ring-specific presentation only. No upgrade state or economic mutation.
static var _rows: Dictionary = {}

static func definition(plot: Dictionary) -> Dictionary:
	if _rows.is_empty():
		var source: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://runtime/config/home_visuals.json"))
		if source is Array:
			for row in source: _rows[String(row.id)] = row
	var id = "castle" if plot.get("type", "") == "castle" else "%s_%02d" % [plot.get("type", ""), int(plot.get("ring", 1))]
	return (_rows.get(id, {}) as Dictionary).duplicate()
