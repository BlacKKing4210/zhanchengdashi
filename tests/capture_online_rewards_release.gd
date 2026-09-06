extends Node
const Test = preload("res://tests/test_online_rewards_release.gd")
const OUT = "res://temp/qa/online-rewards-20260906/"
var app
var viewport: SubViewport

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	GameAudio.sfx_enabled = false
	viewport = SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	app = Test.TestApp.new()
	viewport.add_child(app)
	app.set_process(false)
	var relay = Test.Relay.new()
	add_child(relay)
	relay.app = app
	relay.current_username = "森林里的小动物一起快乐勇敢前进"
	app.online_room_service = relay
	app.screen = "lobby"
	app.gacha_tickets = 8
	app.wallet_gold = 72
	await capture("lobby.png")
	var slots: Array = []
	for i in range(6):
		slots.append({"kind": "human", "team_id": i + 1, "is_host": i == 0, "is_local": i == 0, "ready": true, "display_name": "U-123456-ABCDEF" if i == 1 else ["", "", "风铃草", "雨后蜗牛", "橘子海", "云朵邮局"][i]})
	app._on_online_room_snapshot({"ok": true, "slots": slots, "players_per_side": 3, "room_code": "091249", "local_team_id": 1, "fill_with_ai": true, "is_host": true, "can_start": true})
	app.online_connection_state = "connected"
	await capture("room.png")
	app._on_online_match_started({"match_id": "qa-1", "map_id": "1v1_crossroads", "players_per_side": 1, "local_team_id": 1, "is_authority": true, "match_seed": 219})
	await capture("battle.png")
	app._clear_online_match_state()
	app._start_match("1v1_crossroads")
	app._damage_tile(app._battle_base_key(app.ENEMY), app.PLAYER, 999999)
	await capture("rewards.png")
	print("ONLINE_REWARDS_GPU_PASS 720x1280 lobby room battle rewards")
	app.queue_free()
	relay.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func capture(filename: String) -> void:
	app.toast_timer = 0.0
	app.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(OUT + filename)
