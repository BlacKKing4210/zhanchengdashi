extends Node

const CONFIG_MANIFEST_PATH := "res://runtime/config/config_manifest.json"

var tables: Dictionary = {}


func _ready() -> void:
  reload()


func reload() -> void:
  tables.clear()
  var manifest := _load_json(CONFIG_MANIFEST_PATH)
  if typeof(manifest) != TYPE_DICTIONARY:
    push_error("Config manifest is missing or invalid: %s" % CONFIG_MANIFEST_PATH)
    return

  for relative_path in manifest.get("tables", []):
    var path := "res://%s" % relative_path
    var table_name := String(relative_path).get_file().get_basename()
    var payload := _load_json(path)
    if payload != null:
      tables[table_name] = payload


func has_table(table_name: String) -> bool:
  return tables.has(table_name)


func get_table(table_name: String) -> Variant:
  return tables.get(table_name, [])


func get_global(key: String, default_value: Variant = null) -> Variant:
  var global := tables.get("global", {})
  if typeof(global) != TYPE_DICTIONARY:
    return default_value
  return global.get(key, default_value)


func get_by_id(table_name: String, id_value: String, id_field: String = "id") -> Dictionary:
  var table := get_table(table_name)
  if typeof(table) != TYPE_ARRAY:
    return {}

  for row in table:
    if typeof(row) == TYPE_DICTIONARY and row.get(id_field, "") == id_value:
      return row
  return {}


func _load_json(path: String) -> Variant:
  if not FileAccess.file_exists(path):
    push_error("Config file not found: %s" % path)
    return null

  var file := FileAccess.open(path, FileAccess.READ)
  if file == null:
    push_error("Config file cannot be opened: %s" % path)
    return null

  var text := file.get_as_text()
  var parsed := JSON.parse_string(text)
  if parsed == null:
    push_error("Config file is not valid JSON: %s" % path)
  return parsed
