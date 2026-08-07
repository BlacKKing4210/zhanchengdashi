extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")

var app: Node
var output_dir = ""


func _ready() -> void:
	output_dir = ProjectSettings.globalize_path("res://output/qa/F-ZC-001-battle-card-voice")
	var make_dir_error = DirAccess.make_dir_recursive_absolute(output_dir)
	if make_dir_error != OK:
		push_error("Unable to create visual QA output: %s" % error_string(make_dir_error))
		get_tree().quit(1)
		return

	app = MainApp.new()
	add_child(app)
	await get_tree().process_frame
	app.set("battle_mode", "classic")
	app.set("screen", "battle")
	app.call("_reset_battle")
	app.call("_layout", get_viewport().get_visible_rect().size)
	app.call("_show_building_card_preview", {
		"building": "hall",
		"site_card": "eagle",
		"team": BoardRules.PLAYER,
	})
	app.set_process(false)
	await _capture("battle_camp_animal_card.png")

	app.call("_clear_building_card_preview", true)
	var player_base: Vector2i = app.call("_battle_base_key", BoardRules.PLAYER)
	app.call("_spawn_unit", BoardRules.PLAYER, player_base, "eagle")
	var units: Array = app.get("units")
	if not units.is_empty():
		app.set("selected_unit_id", int((units.back() as Dictionary).get("id", -1)))
	await _capture("battle_selected_animal_card.png")

	app.set("screen", "deck")
	app.set("selected_card_id", "eagle")
	await _capture("deck_animal_card_detail.png")

	print("VISUAL_QA_CAPTURE_PASS: %s" % output_dir)
	app.queue_free()
	get_tree().quit(0)


func _capture(file_name: String) -> void:
	app.queue_redraw()
	await RenderingServer.frame_post_draw
	var image = get_viewport().get_texture().get_image()
	var path = output_dir.path_join(file_name)
	var save_error = image.save_png(path)
	if save_error != OK:
		push_error("Unable to save %s: %s" % [path, error_string(save_error)])
		get_tree().quit(1)
