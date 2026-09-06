extends Node

const MainApp = preload("res://scripts/app/main.gd")
const OUT = "res://output/runtime_animal_v3_20260906/"

class IsolatedApp extends MainApp:
	func _auto_login_saved_account_on_startup() -> void: pass
	func _setup_online_room() -> void: online_room_service = OnlineRoom

var app: IsolatedApp
var viewport: SubViewport

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("GPU required for visual evidence")
		get_tree().quit(1)
		return
	GameAudio.sfx_enabled = false
	viewport = SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	app = IsolatedApp.new()
	viewport.add_child(app)
	app.set_process(false)
	await get_tree().process_frame
	app.battle_mode = "classic"
	app.screen = "battle"
	app.card_levels.clear()
	app.enemy_card_levels.clear()
	app._reset_battle()
	app._layout(Vector2(720, 1280))
	app.board_pan = Vector2.ZERO
	app.units.clear()
	var positions = [Vector2(210, 300), Vector2(350, 300), Vector2(490, 300), Vector2(250, 520), Vector2(440, 520), Vector2(245, 735), Vector2(440, 735), Vector2(255, 950), Vector2(435, 950)]
	var roster = ["fox", "monkey", "deer", "kangaroo", "rhino", "shark", "leopard", "bear", "golden_eagle"]
	for n in range(roster.size()):
		var key = app._battle_base_key(app.PLAYER)
		app._spawn_unit(app.PLAYER if n % 2 == 0 else app.ENEMY, key, roster[n], true)
		var u = app.units.back()
		u.pos = app._canvas_to_world(positions[n])
		u.tile = app._tile_at_world(u.pos)
	app.effects.clear()
	app.units[3]["jump_height"] = 26.0
	app.units[4]["charge_windup"] = 1.0
	app.units[4]["charge_finish"] = Vector2(app.units[4].pos) + Vector2(100, 0)
	app.units[6]["dodge_time"] = 0.15
	app.animal_skills.feedback(Vector2(app.units[5].pos), "18", true)
	app.animal_skills.feedback(Vector2(app.units[6].pos), "miss", false)
	app.effects.append({"kind": "skill_splash", "pos": Vector2(app.units[7].pos), "time": 0.2, "duration": 0.4})
	app.effects.append({"kind": "combat_projectile", "pos": Vector2(app.units[8].pos) + Vector2(45, -8), "from": Vector2(app.units[8].pos), "time": 0.05, "duration": 0.06})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await capture("battle_skill_feedback.png")
	app.screen = "deck"
	app.selected_card_id = "monkey"
	app.card_levels["monkey"] = 3
	app.card_counts["monkey"] = 20
	await capture("deck_new_skill_description.png")
	print("ANIMAL_V3_GPU_CAPTURE_PASS 720x1280")
	app.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func capture(filename: String) -> void:
	app.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture = viewport.get_texture().get_image()
	assert(picture.get_width() == 720 and picture.get_height() == 1280)
	assert(picture.save_png(OUT + filename) == OK)
