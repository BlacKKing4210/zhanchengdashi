extends Node


func _ready() -> void:
  var game_name := ConfigDB.get_global("game_name", "zhanchengdashi")
  print("%s foundation loaded. Config tables: %s" % [game_name, ConfigDB.tables.keys()])
