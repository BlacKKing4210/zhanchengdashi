extends Node

const BoardRules = preload("res://scripts/app/systems/board_rules.gd")
const MainApp = preload("res://scripts/app/main.gd")

const SAMPLE_CARD_IDS = [
	"rabbit",
	"ant",
	"seal",
	"sheep",
	"pig",
	"swan",
	"crane",
]

const INTEGRATED_CARD_IDS = [
	"mouse",
	"ant",
	"sparrow",
	"frog",
	"turtle",
	"snail",
	"rabbit",
	"hamster",
	"cat",
	"chicken",
	"duck",
	"pigeon",
	"squirrel",
	"hedgehog",
	"beaver",
	"dog",
	"goat",
	"pig",
	"deer",
	"monkey",
	"sheep",
	"cow",
	"horse",
	"boar",
	"camel",
	"zebra",
	"kangaroo",
	"wolf",
	"fox",
	"lynx",
	"otter",
	"seal",
	"penguin",
	"dolphin",
	"parrot",
	"peacock",
	"swan",
	"crane",
	"falcon",
	"tadpole",
]

const GROUNDLINE_AUDIT_ARG = "--animal-groundline-audit"

var app: Node
var output_dir = ""
var failures = 0


func _ready() -> void:
	var groundline_audit = GROUNDLINE_AUDIT_ARG in OS.get_cmdline_user_args()
	if groundline_audit:
		output_dir = ProjectSettings.globalize_path("res://tmp/animal_groundline_runtime")
	else:
		output_dir = ProjectSettings.globalize_path("res://output/qa/F-ZC-ANIMAL-ART-001")
	var make_dir_error = DirAccess.make_dir_recursive_absolute(output_dir)
	if make_dir_error != OK:
		push_error("Unable to create animal art QA output: %s" % error_string(make_dir_error))
		get_tree().quit(1)
		return

	app = MainApp.new()
	add_child(app)
	await get_tree().process_frame
	await get_tree().process_frame
	app.set_process(false)
	app.call("_layout", get_viewport().get_visible_rect().size)
	_validate_integrated_textures()

	if groundline_audit:
		for card_id in INTEGRATED_CARD_IDS:
			await _capture_battle_unit(card_id)
	else:
		for card_id in SAMPLE_CARD_IDS:
			await _capture_deck_card(card_id)
			await _capture_battle_unit(card_id)

	if failures == 0:
		print("ANIMAL_ART_CAPTURE_PASS: %s" % output_dir)
	else:
		push_error("Animal art capture failed with %d error(s)." % failures)
	app.queue_free()
	get_tree().quit(failures)


func _validate_integrated_textures() -> void:
	for card_id in INTEGRATED_CARD_IDS:
		var card: Dictionary = app.call("_card_by_id", card_id)
		if card.is_empty():
			_fail("Missing integrated card: %s" % card_id)
			continue
		var art_path = String(card.get("art_path", ""))
		if art_path.is_empty() or not ResourceLoader.exists(art_path):
			_fail("Missing integrated art resource for %s: %s" % [card_id, art_path])
			continue
		var texture = load(art_path) as Texture2D
		if texture == null:
			_fail("Unable to load integrated texture for %s: %s" % [card_id, art_path])
			continue
		if texture.get_width() != 480 or texture.get_height() != 480:
			_fail("Unexpected integrated texture size for %s: %dx%d" % [card_id, texture.get_width(), texture.get_height()])
	if failures == 0:
		print("ANIMAL_ART_TEXTURES_PASS: %d/%d" % [INTEGRATED_CARD_IDS.size(), INTEGRATED_CARD_IDS.size()])


func _capture_deck_card(card_id: String) -> void:
	var card: Dictionary = app.call("_card_by_id", card_id)
	if card.is_empty():
		_fail("Missing card: %s" % card_id)
		return
	app.set("screen", "deck")
	app.set("selected_card_id", card_id)
	await _capture("deck_%s.png" % card_id)


func _capture_battle_unit(card_id: String) -> void:
	app.set("battle_mode", "classic")
	app.set("screen", "battle")
	app.call("_reset_battle")
	var player_base: Vector2i = app.call("_battle_base_key", BoardRules.PLAYER)
	app.call("_spawn_unit", BoardRules.PLAYER, player_base, card_id)
	var units: Array = app.get("units")
	if units.is_empty():
		_fail("Unable to spawn battle unit: %s" % card_id)
		return
	var unit: Dictionary = units.back() as Dictionary
	unit["pos"] = app.call("_hex_center", player_base) + Vector2(0.0, -160.0)
	unit["tile"] = app.call("_tile_at_world", unit["pos"])
	units[units.size() - 1] = unit
	app.set("units", units)
	app.set("selected_unit_id", int(unit.get("id", -1)))
	await _capture("battle_%s.png" % card_id)


func _capture(file_name: String) -> void:
	app.queue_redraw()
	await RenderingServer.frame_post_draw
	var image = get_viewport().get_texture().get_image()
	var path = output_dir.path_join(file_name)
	var save_error = image.save_png(path)
	if save_error != OK:
		_fail("Unable to save %s: %s" % [path, error_string(save_error)])


func _fail(message: String) -> void:
	failures += 1
	push_error(message)
