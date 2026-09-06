extends Node

const BaseTest = preload("res://tests/test_online_rewards_release.gd")
var app
var viewport: SubViewport
var failures = 0
var checks = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func tap(point: Vector2) -> void:
	app._layout(viewport.size)
	app._handle_tap(app.canvas_offset + point * app.canvas_scale)

func _ready() -> void:
	GameAudio.sfx_enabled = false
	viewport = SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	add_child(viewport)
	app = BaseTest.TestApp.new()
	viewport.add_child(app)
	app.set_process(false)
	await get_tree().process_frame
	test_dog()
	test_wallet()
	for resolution in [Vector2i(720, 1280), Vector2i(360, 640)]:
		viewport.size = resolution
		test_gacha()
	print("DOG_REWARDS_GACHA checks=", checks, " failures=", failures)
	app.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)

func test_dog() -> void:
	app._start_match("1v1_crossroads")
	app.units.clear()
	var key = app._battle_base_key(app.PLAYER)
	app._spawn_unit(app.PLAYER, key, "dog")
	var before = app.units[0].attack
	for n in range(6): app._spawn_unit(app.PLAYER, key, "rabbit")
	check(app.units[0].attack == before, "ordinary friendly camp births never grant attack")
	for id in ["mouse", "ant", "duck", "wolf"]:
		app._spawn_unit(app.PLAYER, key, id)
		before += 1
		check(app.units[0].attack == before, "one extra birth grants exactly one: " + id)
	app._spawn_unit(app.ENEMY, key, "mouse")
	check(app.units[0].attack == before, "enemy extra summon grants nothing")
	app._spawn_unit(app.PLAYER, key, "mouse", true)
	check(app.units[0].attack == before, "generic extra-positioning spawn is not a birth summon")
	app._spawn_unit(app.PLAYER, key, "mouse", false, 0, {"skill_triggers_enabled": false})
	check(app.units[0].attack == before, "disabled summoning skill grants nothing")
	app.units[0].skill_triggers_enabled = false
	app._spawn_unit(app.PLAYER, key, "mouse")
	check(app.units[0].attack == before, "disabled dog does not receive trigger")
	app.units[0].skill_triggers_enabled = true
	while app._multiplayer_alive_unit_count(app.PLAYER) < app._animal_cap_per_living_faction() - 1:
		app._spawn_unit(app.PLAYER, key, "rabbit")
	app._spawn_unit(app.PLAYER, key, "mouse")
	check(app.units[0].attack == before, "population cap permits original but blocks extra and buff")
	check(app._card_extra_spawn_count(app._card_by_id("dog")) == 0, "dog description cannot cause self-summoning")

func test_wallet() -> void:
	for outcome in ["胜利", "失败"]:
		app._start_match("1v1_crossroads")
		app.wallet_gold = 120
		app.gold = 60
		check(app._display_gold() == 60, "active battle still shows spendable battle gold")
		var base = app._battle_base_key(app.ENEMY if outcome == "胜利" else app.PLAYER)
		app._damage_tile(base, app.PLAYER if outcome == "胜利" else app.ENEMY, 999999)
		var settled = app.wallet_gold
		check(settled > 120 and app._display_gold() == settled, "settlement HUD immediately shows credited wallet")
		tap(app._result_return_rect().get_center())
		check(app.screen == app.SCREEN_LOBBY and app._display_gold() == settled, "return click preserves visible credited wallet")
		var profile = app._server_profile_snapshot()
		app.account_applied_user_id = "fixture-wallet"
		app.account_pending_profile = profile.duplicate(true)
		app._on_account_state_changed({"logged_in": true, "user_id": "fixture-wallet", "operation": "save_player_profile", "profile": profile})
		check(app._display_gold() == settled, "save acknowledgement leaves displayed balance unchanged")
		app._on_account_state_changed({"logged_in": true, "user_id": "fixture-wallet", "operation": "load_player_profile", "profile": profile})
		check(app._display_gold() == settled, "same-account reload retains credited wallet")

func test_gacha() -> void:
	app.screen = app.SCREEN_LOBBY
	app.last_gacha_cards = ["dog", "rabbit", "cat", "mouse", "hamster", "fox", "lion", "turtle", "sheep", "parrot"]
	app.gacha_pending_cards.clear()
	app.gacha_card_flip_timers.clear()
	app.gacha_fx_timer = 0
	app.card_counts["dog"] = 99
	app.card_counts["fox"] = 99
	app.gacha_detail_card_id = "cat"
	tap(app._nav_rect(3).get_center())
	check(app.screen == app.SCREEN_GACHA and app.gacha_detail_card_id.is_empty(), "entry hides detail even after prior selection")
	tap(app._gacha_reward_card_rect(0, 10).get_center())
	check(app.gacha_detail_card_id == "dog", "real tap selects recent dog")
	check(app._gacha_detail_rect().end.y < app._nav_rect(3).position.y, "detail clears bottom navigation")
	check(app._gacha_detail_rect().encloses(app._upgrade_button_rect()), "upgrade click target belongs to detail")
	var level = app._card_level("dog")
	tap(app._upgrade_button_rect().get_center())
	check(app._card_level("dog") == level + 1, "detail upgrades selected card through existing action")
	tap(app._gacha_reward_card_rect(1, 10).get_center())
	check(app.gacha_detail_card_id == "rabbit", "another card replaces detail")
	tap(app._gacha_reward_card_rect(1, 10).get_center())
	check(app.gacha_detail_card_id.is_empty(), "same card closes detail")
	tap(app._gacha_reward_card_rect(0, 10).get_center())
	tap(Vector2(360, 750))
	check(app.gacha_detail_card_id.is_empty(), "empty background closes detail")
	app.gacha_tickets = 20
	tap(app._gacha_reward_card_rect(0, 10).get_center())
	tap(app._gacha_draw_rect().get_center())
	check(app.gacha_detail_card_id.is_empty() and app._is_gacha_animating(), "starting a draw clears old detail")
	for n in range(400): app._update_gacha_animation(0.02)
	check(app.gacha_detail_card_id.is_empty(), "automatic reveal never automatically opens detail")
	app.last_gacha_cards = ["fox"]
	app.gacha_card_flip_timers.clear()
	app.deck = ["gold_mine", "defense_watch_tower", "cat", "dog", "rabbit", "mouse", "hamster", "sheep"]
	tap(app._gacha_reward_card_rect(0, 1).get_center())
	tap(app._equip_button_rect().get_center())
	check(app.screen == app.SCREEN_DECK and app.pending_equip_card_id == "fox", "equip opens existing deck-slot selection")
