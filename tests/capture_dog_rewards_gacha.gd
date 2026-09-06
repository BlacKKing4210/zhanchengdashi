extends Node
const Fixture = preload("res://tests/test_online_rewards_release.gd")
var app
var viewport: SubViewport
const OUT = "res://temp/qa/dog-rewards-gacha-20260906/"

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	GameAudio.sfx_enabled = false
	viewport = SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	app = Fixture.TestApp.new()
	viewport.add_child(app)
	app.set_process(false)
	app.screen = app.SCREEN_GACHA
	app.last_gacha_cards = ["chicken", "rabbit", "snail", "mouse", "mouse", "rabbit", "dog", "frog", "frog", "hamster"]
	app.gacha_tickets = 20
	app.card_counts["dog"] = 8
	await capture("gacha-hidden.png")
	app._handle_gacha_tap(app._gacha_reward_card_rect(6, 10).get_center())
	app.detail_pulse_timer = 0
	await capture("gacha-dog.png")
	viewport.size = Vector2i(360, 640)
	await capture("gacha-dog-360.png")
	viewport.size = Vector2i(720, 1280)
	app._start_match("1v1_crossroads")
	app.wallet_gold = 120
	app.reward_rng.seed = 1729
	app._damage_tile(app._battle_base_key(app.ENEMY), app.PLAYER, 999999)
	await capture("settled-wallet.png")
	print("DOG_REWARDS_GACHA_GPU_PASS")
	app.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func capture(filename: String) -> void:
	app.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error = viewport.get_texture().get_image().save_png(OUT + filename)
	assert(error == OK)
