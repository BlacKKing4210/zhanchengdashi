extends Node

const MainApp = preload("res://scripts/app/main.gd")
const UISkin = preload("res://scripts/app/ui/handdrawn_ui_skin.gd")

class IsolatedApp extends MainApp:
	func _auto_login_saved_account_on_startup() -> void:
		pass
	func _setup_online_room() -> void:
		online_room_service = OnlineRoom

var app: Node2D
var viewport: SubViewport
var failures = 0
var checks = 0


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	add_child(viewport)
	app = IsolatedApp.new()
	viewport.add_child(app)
	app.set_process(false)
	app.set("screen", "battle")
	app.set("battle_mode", "classic")
	app.call("_reset_battle")
	await get_tree().process_frame
	for size in [Vector2(720, 1280), Vector2(720, 1600), Vector2(1080, 2400), Vector2(540, 960)]:
		app.call("_layout", size)
		var view: Rect2 = app.call("_battle_view_rect")
		var scale: float = app.get("canvas_scale")
		var offset: Vector2 = app.get("canvas_offset")
		check((view.position * scale + offset).length() < 0.01, "full-page top left %s" % size)
		check((view.end * scale + offset).distance_to(size) < 0.01, "full-page bottom right %s" % size)
		var world = Vector2(115, -78)
		check(Vector2(app.call("_canvas_to_world", app.call("_world_to_canvas", world))).distance_to(world) < 0.01, "camera inverse %s" % size)
	app.call("_layout", Vector2(720, 1280))
	var gold_before: int = app.get("gold")
	for point in [Vector2(100, 40), Vector2(360, 40), Vector2(580, 40), Vector2(340, 1200)]:
		var pan: Vector2 = app.get("board_pan")
		app.call("_begin_board_pointer", point)
		check(not bool(app.get("board_pointer_started_in_view")), "HUD blocks drag start %s" % point)
		app.call("_move_board_pointer", point + Vector2(25, 0), Vector2(25, 0))
		app.call("_end_board_pointer", point)
		check(Vector2(app.get("board_pan")).is_equal_approx(pan), "HUD cannot pan map")
		check(int(app.get("gold")) == gold_before, "HUD cannot buy tile")
	var pan_before: Vector2 = app.get("board_pan")
	app.call("_begin_board_pointer", Vector2(100, 40))
	app.call("_move_board_pointer", Vector2(100, 400), Vector2(0, 360))
	app.call("_end_board_pointer", Vector2(100, 400))
	check(Vector2(app.get("board_pan")).is_equal_approx(pan_before) and int(app.get("gold")) == gold_before, "HUD gesture cannot release into world")
	var touch = InputEventScreenTouch.new()
	touch.position = Vector2(360, 600)
	touch.pressed = true
	app.call("_handle_multiplayer_pointer_input", touch)
	var drag = InputEventScreenDrag.new()
	drag.position = Vector2(392, 625)
	drag.relative = Vector2(32, 25)
	app.call("_handle_multiplayer_pointer_input", drag)
	touch.position = drag.position
	touch.pressed = false
	app.call("_handle_multiplayer_pointer_input", touch)
	check(not Vector2(app.get("board_pan")).is_equal_approx(pan_before), "single touch pans world")
	check(int(app.get("gold")) == gold_before, "touch drag does not purchase")
	app.call("_handle_tap", Vector2(640, 106))
	check(bool(app.get("pause_open")), "pause remains clickable above world")
	app.set("pause_open", false)
	app.set("battle_mode", "multiplayer")
	app.set("multiplayer_free_for_all", true)
	check(bool(app.call("_battle_hud_has_point", Vector2(540, 200))), "FFA leaderboard blocks world")
	app.set("multiplayer_free_for_all", false)
	app.set("room_players_per_side", 3)
	check(bool(app.call("_battle_hud_has_point", Vector2(90, 80))), "3v3 scoreboard blocks world")
	for seed_value in range(6):
		check(UISkin.terrain_index(-1, false, seed_value) != 7, "classic enemy is not neutral")
		check(UISkin.terrain_index(-1, false, seed_value) != UISkin.terrain_index(1, false, seed_value), "classic enemies distinct")
		var seen = {}
		for team in range(1, 7): seen[UISkin.terrain_index(team, false, seed_value)] = true
		check(seen.size() == 6, "six distinct factions")
	for texture in UISkin.TERRAIN:
		check(texture.get_width() > 0 and texture.get_height() > 0, "terrain imported")
	var style = UISkin.panel(UISkin.SURFACE)
	check(style.border_width_left == 0 and style.border_width_top == 0, "B surfaces have no outline")
	check(style.shadow_size <= 3, "shallow shadow")
	check(style == UISkin.panel(UISkin.SURFACE), "style objects cached")
	for field_name in ["account_username_field", "account_name_field", "account_password_field", "online_room_code_field"]:
		var field: LineEdit = app.get(field_name)
		check(field != null and field.virtual_keyboard_enabled and field.focus_mode == Control.FOCUS_ALL, "native touch input %s" % field_name)
	print("HANDDRAWN_UI_TEST %s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	app.queue_free()
	await get_tree().process_frame
	get_tree().quit(failures)


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
