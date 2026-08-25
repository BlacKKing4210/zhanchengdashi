extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")
const MultiplayerRules = preload("res://scripts/app/systems/multiplayer_rules.gd")

const CAPTURE_SIZE = Vector2i(720, 1280)
const OUTPUT_ROOT = "res://output/qa/F-ZC-BATTLE-ECONOMY-AI-MAP-004"

var app: Node
var capture_viewport: SubViewport


func _ready() -> void:
	capture_viewport = SubViewport.new()
	capture_viewport.size = CAPTURE_SIZE
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	capture_viewport.transparent_bg = false
	add_child(capture_viewport)
	app = MainApp.new()
	capture_viewport.add_child(app)
	await get_tree().process_frame
	await get_tree().process_frame
	app.set_process(false)
	app.set("battle_mode", "classic")
	app.set("screen", "battle")
	app.call("_reset_battle")
	if not _install_visible_player_mine():
		_fail("Unable to place a visible player mine beside the base.")
		return
	app.set("income_timer", 1.5)
	app.set("effects", [])
	if not await _save_capture("income_progress.png"):
		return
	app.call("_award_periodic_building_income")
	app.set("income_timer", 3.0)
	if not await _save_capture("income_payout_effect.png"):
		return
	print("BATTLE_INCOME_CAPTURE_PASS size=%s output=%s" % [str(CAPTURE_SIZE), OUTPUT_ROOT])
	_cleanup_and_quit(0)


func _install_visible_player_mine() -> bool:
	var player_base: Vector2i = app.call("_battle_base_key", BoardRules.PLAYER)
	var tiles: Dictionary = app.get("tiles")
	for key_value in MultiplayerRules.neighbors(tiles, player_base):
		var key: Vector2i = key_value
		var tile: Dictionary = (tiles[key] as Dictionary).duplicate(true)
		if not String(tile.get("building", "")).is_empty():
			continue
		tile["building"] = "mine"
		tile["team"] = BoardRules.PLAYER
		tile["owner"] = BoardRules.PLAYER
		tile["occupier"] = BoardRules.PLAYER
		tile["territory_team"] = BoardRules.PLAYER
		tile["unlocked"] = true
		tile["hp"] = 125.0
		tile["max_hp"] = 125.0
		tile["site"] = "mine"
		tile["site_card"] = "mine_epic"
		tiles[key] = tile
		app.set("tiles", tiles)
		return true
	return false


func _save_capture(filename: String) -> bool:
	app.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image = capture_viewport.get_texture().get_image()
	if image.get_size() != CAPTURE_SIZE:
		_fail("Expected %s capture, got %s." % [str(CAPTURE_SIZE), str(image.get_size())])
		return false
	var output_dir = ProjectSettings.globalize_path(OUTPUT_ROOT)
	var make_dir_error = DirAccess.make_dir_recursive_absolute(output_dir)
	if make_dir_error != OK:
		_fail("Unable to create capture directory: %s" % error_string(make_dir_error))
		return false
	var output_path = output_dir.path_join(filename)
	var save_error = image.save_png(output_path)
	if save_error != OK:
		_fail("Unable to save capture: %s" % error_string(save_error))
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	_cleanup_and_quit(1)


func _cleanup_and_quit(code: int) -> void:
	if app != null:
		app.queue_free()
	if capture_viewport != null:
		capture_viewport.queue_free()
	get_tree().quit(code)
