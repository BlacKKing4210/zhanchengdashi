extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")

const TOWER_IDS = [
	"defense_watch_tower",
	"defense_longshot_tower",
	"defense_cannon_tower",
	"defense_plunder_tower",
	"defense_rapid_tower",
	"defense_repair_beacon",
	"defense_twinshot_tower",
	"defense_bounty_tower",
	"defense_territory_tower",
	"defense_storm_obelisk",
]

var app: Node2D
var capture_viewport: SubViewport
var output_dir = ""


func _ready() -> void:
	output_dir = OS.get_environment("ZC_DEFENSE_TOWER_CATALOG_CAPTURE_DIR")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("res://temp/qa/F-ZC-DEFENSE-TOWER-005/runtime-art-a/catalog")
	var make_dir_error = DirAccess.make_dir_recursive_absolute(output_dir)
	if make_dir_error != OK:
		push_error("Unable to create defense tower catalog capture directory: %s" % error_string(make_dir_error))
		get_tree().quit(1)
		return

	capture_viewport = SubViewport.new()
	capture_viewport.size = Vector2i(720, 1280)
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	capture_viewport.transparent_bg = false
	add_child(capture_viewport)
	app = MainApp.new()
	capture_viewport.add_child(app)
	await get_tree().process_frame
	await get_tree().process_frame
	app.call("_layout", Vector2(720, 1280))
	app.set_process(false)

	for index in range(TOWER_IDS.size()):
		await _capture_tower(index, TOWER_IDS[index])

	print("DEFENSE_TOWER_ART_CATALOG_CAPTURE_PASS: %s" % output_dir)
	app.queue_free()
	capture_viewport.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)


func _capture_tower(index: int, tower_id: String) -> void:
	app.set("card_counts", {tower_id: 1})
	app.set("card_levels", {tower_id: 1})
	app.set("screen", "deck")
	app.set("selected_card_id", tower_id)
	await _capture("%02d_%s_card_720x1280.png" % [index + 1, tower_id])

	app.set("battle_mode", "classic")
	app.set("screen", "battle")
	app.call("_reset_battle")
	var tower_key: Vector2i = app.call("_battle_base_key", BoardRules.PLAYER)
	var tiles: Dictionary = app.get("tiles")
	var tile: Dictionary = (tiles[tower_key] as Dictionary).duplicate(true)
	var tower_card: Dictionary = app.call("_card_by_id", tower_id)
	var tower_stats: Dictionary = app.call("_card_stats", tower_card)
	var max_hp = float(tower_stats.get("max_hp", 1.0))
	tile["building"] = "tower"
	tile["team"] = BoardRules.PLAYER
	tile["site_card"] = tower_id
	tile["hp"] = maxf(1.0, max_hp - 1.0)
	tile["max_hp"] = max_hp
	tiles[tower_key] = tile
	app.set("tiles", tiles)
	app.call("_show_building_card_preview", tile, tower_key)
	await _capture("%02d_%s_battle_720x1280.png" % [index + 1, tower_id])


func _capture(file_name: String) -> void:
	app.queue_redraw()
	await RenderingServer.frame_post_draw
	var image = capture_viewport.get_texture().get_image()
	var save_error = image.save_png(output_dir.path_join(file_name))
	if save_error != OK:
		push_error("Unable to save %s: %s" % [file_name, error_string(save_error)])
		get_tree().quit(1)
