extends Node

const MainApp = preload("res://scripts/app/main.gd")
const UISkin = preload("res://scripts/app/ui/handdrawn_ui_skin.gd")
const OUT = "res://output/runtime_ui_states_20260906/"

class IsolatedApp extends MainApp:
	var probe = false
	var action_states: Dictionary = {}
	func _auto_login_saved_account_on_startup() -> void:
		pass
	func _setup_online_room() -> void:
		online_room_service = OnlineRoom
	func _cta(rect: Rect2, label: String, primary: bool, enabled: bool = true) -> void:
		action_states[label] = {"primary": primary, "enabled": enabled}
		super._cta(rect, label, primary, enabled)
	func _draw() -> void:
		if not probe:
			super._draw()
			return
		_layout(get_viewport_rect().size)
		_set_tracked_draw_transform(canvas_offset, 0.0, Vector2.ONE * canvas_scale)
		draw_rect(Rect2(0, 0, 720, 1280), UISkin.PAPER)
		_draw_card(Rect2(20, 20, 126, 140), _card_by_id("duck"), false)
		_draw_card_clipped(Rect2(180, 20, 126, 140), _card_by_id("duck"), false, Rect2(180, 20, 126, 140))
		_draw_card_clipped(Rect2(340, 20, 126, 140), _card_by_id("duck"), false, Rect2(340, 50, 126, 110))
		_draw_card(Rect2(20, 190, 126, 140), _card_by_id("bear"), false)
		_cta(Rect2(20, 380, 160, 60), "升级", true, _card_can_upgrade("duck"))
		_cta(Rect2(200, 380, 160, 60), "返回", false)
		_cta(Rect2(380, 380, 160, 60), "升级", true, false)

var app: IsolatedApp
var viewport: SubViewport
var checks = 0
var failures = 0


func _ready() -> void:
	GameAudio.sfx_enabled = false
	viewport = SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	app = IsolatedApp.new()
	viewport.add_child(app)
	app.set_process(false)
	await get_tree().process_frame
	app.screen = "deck"
	app.account_center_open = false
	app._layout(Vector2(720, 1280))
	check(UISkin.rarity("legendary") == UISkin.GOLD and UISkin.GOLD != UISkin.PEACH, "legendary uses gold, not peach")
	for fill in [UISkin.GOLD, UISkin.PRIMARY, UISkin.SECONDARY, UISkin.DISABLED, UISkin.NAV_IDLE]:
		check(UISkin.surface_color(fill) == fill, "semantic color survives surface mapping")
		check(contrast(UISkin.INK, fill) >= 4.5, "normal text contrast >= 4.5")
	check(contrast(UISkin.DISABLED_INK, UISkin.DISABLED) >= 4.5, "disabled label stays readable")
	check(UISkin.action_fill(false, true) == UISkin.SECONDARY, "secondary is actionable")
	check(UISkin.action_fill(true, false) == UISkin.DISABLED, "unavailable primary stays disabled")
	check(UISkin.SECONDARY != UISkin.SURFACE and UISkin.NAV_IDLE != UISkin.SURFACE, "actions distinct from information")
	check(UISkin.TILE_READY.s > 0.98 and UISkin.TILE_READY.v > 0.99, "tile highlight saturated and bright")
	check(contrast(UISkin.TILE_READY, UISkin.TILE_READY_EDGE) >= 3.0, "tile highlight has contrast under-stroke")
	for card in app.cards:
		var id = String(card["id"])
		app.card_levels = {id: 2}
		app.card_counts = {id: 0}
		check(not app._card_can_upgrade(id), "unowned: " + id)
		app.card_counts[id] = 2
		check(not app._card_can_upgrade(id), "insufficient: " + id)
		app.card_counts[id] = 3
		check(app._card_can_upgrade(id), "exact cost: " + id)
		app.card_levels[id] = 10
		app.card_counts[id] = 1000
		check(not app._card_can_upgrade(id), "max level: " + id)
	set_deck_state()
	var corner_card = Rect2(20, 20, 126, 140)
	var corner_dot = app._card_upgrade_dot_rect(corner_card)
	check(corner_dot.get_center() == Vector2(142, 24), "badge centered on rounded top-right rim")
	check(corner_dot.end.x - corner_card.end.x == 5.0 and corner_card.position.y - corner_dot.position.y == 5.0, "badge overlaps both edges by five pixels")
	var gpu = DisplayServer.get_name() != "headless"
	if gpu:
		app.probe = true
		var before = await render_image()
		check(near(before.get_pixel(142, 24), UISkin.UPGRADE_DOT), "equipped dot rendered on corner")
		check(near(before.get_pixel(302, 24), UISkin.UPGRADE_DOT), "collection first-row dot rendered on corner")
		check(near(before.get_pixel(147, 24), UISkin.UPGRADE_DOT), "equipped dot extends past card edge")
		check(near(before.get_pixel(307, 24), UISkin.UPGRADE_DOT), "collection dot extends past card edge")
		check(near(before.get_pixel(462, 24), UISkin.PAPER), "scrolled notification clipped")
		check(near(before.get_pixel(40, 215), UISkin.GOLD), "legendary actual card pixels are gold")
		check(near(before.get_pixel(28, 410), UISkin.PRIMARY), "ready upgrade rendered primary")
		check(near(before.get_pixel(208, 410), UISkin.SECONDARY), "secondary button rendered teal")
		check(near(before.get_pixel(388, 410), UISkin.DISABLED), "disabled button rendered gray")
	app.probe = false
	app.selected_card_id = "duck"
	app._handle_tap(app._upgrade_button_rect().get_center())
	check(app._card_level("duck") == 3 and app._card_total_count("duck") == 1, "real upgrade tap spends exact fragments")
	check(not app._card_can_upgrade("duck"), "red dot clears after upgrade")
	app._handle_tap(app._upgrade_button_rect().get_center())
	check(app._card_level("duck") == 3 and app._card_total_count("duck") == 1, "unavailable upgrade tap never spends")
	if gpu:
		app.probe = true
		var after = await render_image()
		check(near(after.get_pixel(147, 24), UISkin.PAPER), "equipped overhang pixels removed after upgrade")
		check(near(after.get_pixel(307, 24), UISkin.PAPER), "collection overhang pixels removed after upgrade")
		check(near(after.get_pixel(28, 410), UISkin.DISABLED), "upgrade button disables with dot removal")
		app.probe = false
		await check_relogin_affordance()
		if "--capture-ui-states" in OS.get_cmdline_user_args():
			await capture_pages()
		if "--capture-dot-corner" in OS.get_cmdline_user_args():
			set_deck_state()
			app.screen = "deck"
			app.card_counts["defense_longshot_tower"] = 2
			var folder = "res://output/runtime_ui_dot_corner_20260906/"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
			var frame = await render_image()
			check(frame.save_png(ProjectSettings.globalize_path(folder + "deck_corner_badges.png")) == OK, "corner badge page capture")
	app.queue_free()
	await get_tree().process_frame
	print("UI_ACTION_STATES ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures, " gpu=", gpu)
	get_tree().quit(0 if failures == 0 else 1)


func check_relogin_affordance() -> void:
	var previous = {}
	for key in ["current_user_id", "current_account_name", "current_account_has_password", "current_account_is_generated"]:
		previous[key] = OnlineRoom.get(key)
	OnlineRoom.current_user_id = "U-ui-state-test"
	OnlineRoom.current_account_name = "UIStateTest"
	OnlineRoom.current_account_has_password = true
	OnlineRoom.current_account_is_generated = false
	app.account_center_open = true
	app.account_session_password = ""
	await render_image()
	check(not app._account_password_available_for_view(), "relogin fixture has no visible password")
	check(bool(app.action_states["重新登录"]["enabled"]), "relogin remains visually actionable")
	check(bool(app.action_states["复制"]["enabled"]), "copy recovery path remains visually actionable")
	app._handle_tap(app._account_password_view_rect().get_center())
	check(app.account_manual_login_open, "relogin button still opens manual login")
	app.account_manual_login_open = false
	app.account_center_open = false
	app._set_account_fields_visible(false)
	for key in previous:
		OnlineRoom.set(key, previous[key])


func set_deck_state() -> void:
	app.deck = ["gold_mine_card", "defense_watch_tower", "hamster", "defense_cannon_tower", "fox", "bear", "mouse", "sheep"]
	app.card_counts.clear()
	app.card_levels.clear()
	for id in app.deck + ["lynx", "cat", "defense_longshot_tower", "dog", "duck", "goat", "hedgehog", "parrot", "squirrel"]:
		app.card_counts[String(id)] = 1
	app.card_levels = {"duck": 2, "cat": 2, "defense_watch_tower": 3, "hamster": 4, "mouse": 4}
	app.card_counts.merge({"duck": 3, "cat": 2, "defense_watch_tower": 7, "hamster": 4, "mouse": 5}, true)
	app.selected_card_id = "bear"
	app.detail_pulse_timer = 0.0
	app.detail_upgrade_motion_timer = 0.0
	app.toast_timer = 0.0


func capture_pages() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	set_deck_state()
	app.screen = "lobby"
	await snap("01_lobby_buttons")
	app.screen = "deck"
	await snap("02_deck_gold_and_upgrade_dots")
	app.card_counts["defense_bounty_tower"] = 1
	app.selected_card_id = "defense_bounty_tower"
	await snap("10_gold_tower")
	app.card_counts.erase("defense_bounty_tower")
	app.selected_card_id = "duck"
	await snap("03_upgrade_ready")
	app._handle_tap(app._upgrade_button_rect().get_center())
	app.detail_pulse_timer = 0.0
	app.detail_upgrade_motion_timer = 0.0
	app.toast_timer = 0.0
	await snap("04_after_upgrade")
	app.screen = "room"
	app.online_connection_state = "connected"
	app.online_room_active = false
	app.online_room_join_code = ""
	app._update_online_room_code_field_layout()
	await snap("05_room_disabled_join")
	app.online_room_join_code = "123456"
	app._update_online_room_code_field_layout()
	await snap("06_room_ready_join")
	app.screen = "battle"
	app._update_online_room_code_field_layout()
	app.battle_mode = "classic"
	app._reset_battle()
	app.battle_match_seed = 5 # Player 1's actual territory PNG is yellow.
	app.gold = 102
	app._initialize_battle_team_colors(5)
	await snap("07_yellow_battle_highlights")
	var ready_image = await render_image()
	for key in app.tiles:
		if not app._can_unlock(key, 1) or app._unlock_cost(key, 1) > 102:
			continue
		var points = app._hex_points(app._world_to_canvas(app._hex_center(key)))
		var sample = (points[0] + points[1]) * 0.5
		if not Rect2(40, 220, 640, 840).has_point(sample):
			continue
		check(near(ready_image.get_pixelv(Vector2i(sample)), UISkin.TILE_READY), "affordable tile actual highlight pixels")
		app.gold = 0
		var unavailable_image = await render_image()
		check(near(unavailable_image.get_pixelv(Vector2i(sample)), UISkin.TILE_UNAVAILABLE), "same tile unavailable at zero gold")
		app.gold = 102
		break
	app.battle_match_seed = 0
	app._initialize_battle_team_colors(0)
	await snap("08_green_battle_highlights")
	viewport.size = Vector2i(720, 1600)
	app.screen = "deck"
	set_deck_state()
	await snap("09_tall_deck")


func render_image() -> Image:
	app.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func snap(id: String) -> void:
	var frame = await render_image()
	check(frame.save_png(ProjectSettings.globalize_path(OUT + id + ".png")) == OK, "capture " + id)


func near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.06


func contrast(a: Color, b: Color) -> float:
	var x = a.srgb_to_linear().get_luminance()
	var y = b.srgb_to_linear().get_luminance()
	return (maxf(x, y) + 0.05) / (minf(x, y) + 0.05)


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
