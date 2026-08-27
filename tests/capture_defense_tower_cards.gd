extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")

var app: Node2D
var capture_viewport: SubViewport
var output_dir = ""
var capture_card_id = "defense_territory_tower"
var capture_level = 1


func _ready() -> void:
	output_dir = OS.get_environment("ZC_DEFENSE_TOWER_CAPTURE_DIR")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("res://temp/qa/F-ZC-DEFENSE-TOWER-005/20260826/runtime")
	var requested_card_id = OS.get_environment("ZC_DEFENSE_TOWER_CAPTURE_CARD_ID")
	if not requested_card_id.is_empty():
		capture_card_id = requested_card_id
	var requested_level = OS.get_environment("ZC_DEFENSE_TOWER_CAPTURE_LEVEL")
	if requested_level.is_valid_int():
		capture_level = maxi(1, requested_level.to_int())
	var make_dir_error = DirAccess.make_dir_recursive_absolute(output_dir)
	if make_dir_error != OK:
		push_error("Unable to create defense tower capture directory: %s" % error_string(make_dir_error))
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
	app.set("card_counts", {capture_card_id: 1})
	app.set("card_levels", {capture_card_id: capture_level})
	app.set("screen", "deck")
	app.set("selected_card_id", capture_card_id)
	app.set_process(false)
	await _capture("tower_card_detail_720x1280.png")

	app.set("battle_mode", "classic")
	app.set("screen", "battle")
	app.call("_reset_battle")
	var tower_key: Vector2i = app.call("_battle_base_key", BoardRules.PLAYER)
	var tiles: Dictionary = app.get("tiles")
	var tile: Dictionary = (tiles[tower_key] as Dictionary).duplicate(true)
	tile["building"] = "tower"
	tile["team"] = BoardRules.PLAYER
	tile["site_card"] = capture_card_id
	var tower_card: Dictionary = app.call("_card_by_id", capture_card_id)
	var tower_stats: Dictionary = app.call("_card_stats", tower_card)
	tile["hp"] = float(tower_stats.get("max_hp", 1.0))
	tile["max_hp"] = float(tower_stats.get("max_hp", 1.0))
	tiles[tower_key] = tile
	app.set("tiles", tiles)
	app.call("_show_building_card_preview", tile, tower_key)
	await _capture("tower_battle_detail_720x1280.png")

	print("DEFENSE_TOWER_CAPTURE_PASS: %s (%s Lv.%d)" % [output_dir, capture_card_id, capture_level])
	app.queue_free()
	capture_viewport.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)


func _capture(file_name: String) -> void:
	app.queue_redraw()
	await RenderingServer.frame_post_draw
	var image = capture_viewport.get_texture().get_image()
	var path = output_dir.path_join(file_name)
	var save_error = image.save_png(path)
	if save_error != OK:
		push_error("Unable to save %s: %s" % [path, error_string(save_error)])
		get_tree().quit(1)
