extends Node
## Independent, frozen evaluator for REQ-20260925-HOME-GACHA-READABILITY.
const Base = preload("res://tests/test_home_runtime.gd")
const Home = preload("res://scripts/app/ui/home_view.gd")
const Rules = preload("res://scripts/shared/home_rules.gd")
const Palette = preload("res://scripts/app/ui/handdrawn_ui_skin.gd")
const OUT = "res://temp/qa/home-readability-20260925/home/"

class TraceHome extends Home:
	var trace: Array = []
	var scope = ""
	func _init(owner) -> void: super(owner)
	func draw() -> void:
		trace.clear()
		super()
	func _draw_plot(p: Dictionary) -> void:
		scope = p.id
		super(p)
		scope = ""
	func _draw_details() -> void:
		scope = "details"
		super()
		scope = ""
	func _draw_modal() -> void:
		scope = "modal"
		super()
		scope = ""
	func _type_icon(kind: String, center: Vector2, size: float, background: Color = Color("dedad3")) -> void:
		trace.append({"scope": scope, "kind": "type", "value": kind, "center": center})
		super(kind, center, size, background)
	func _draw_building(p: Dictionary, rect: Rect2) -> void:
		trace.append({"scope": scope, "kind": "building", "value": p.id, "rect": rect})
		super(p, rect)
	func _text(value: String, rect: Rect2, size: int = 24, color: Color = Palette.INK) -> void:
		trace.append({"scope": scope, "kind": "text", "value": value, "rect": rect, "font_size": size})
		super(value, rect, size, color)
	func _art(id: String, rect: Rect2, tint: Color = Color.WHITE) -> void:
		trace.append({"scope": scope, "kind": "art", "value": id, "rect": rect})
		super(id, rect, tint)
	func _panel(rect: Rect2, color: Color = Palette.RAISED, radius: int = 16) -> void:
		trace.append({"scope": scope, "kind": "panel", "color": color.to_html(), "rect": rect})
		super(rect, color, radius)

class TestApp extends Base.TestApp:
	func _ensure_home():
		if home_view == null:
			home_view = TraceHome.new(self)
			home_view.preview = true
		return home_view

var app
var viewport: SubViewport
var checks: Array = []
var failures = 0
var stage = "baseline"
var resolution = ""
var captures: Array = []

func check(value: bool, label: String, observed: Variant = null) -> void:
	checks.append({"id": label, "resolution": resolution, "pass": value, "observed": str(observed)})
	if not value:
		failures += 1
		print("HOME_READABILITY_FAIL ", label, " observed=", observed)

func rows(scope: String, kind: String) -> Array:
	return app.home_view.trace.filter(func(row): return row.scope == scope and row.kind == kind)

func values(scope: String, kind: String) -> Array:
	return rows(scope, kind).map(func(row): return row.value)

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-stage="): stage = arg.trim_prefix("--evidence-stage=")
	GameAudio.sfx_enabled = false
	GameAudio.set_music_enabled(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + stage))
	viewport = SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	for size in [Vector2i(720, 1280), Vector2i(360, 640)]:
		viewport.size = size
		resolution = "%dx%d" % [size.x, size.y]
		app = TestApp.new()
		viewport.add_child(app)
		await get_tree().process_frame
		app.set_process(false)
		app.screen = "lobby"
		app.home_view.modal = ""
		await tap(app._nav_rect(0).get_center())
		check(app.screen == "home", "native_navigation_opens_home")
		await test_claim_dot()
		await test_plots()
		await test_details()
		app.queue_free()
		await get_tree().process_frame
	var report = {"defect_id": "REQ-20260925-HOME-GACHA-READABILITY", "stage": stage, "renderer": RenderingServer.get_current_rendering_method(), "display": DisplayServer.get_name(), "engine": Engine.get_version_info(), "checks": checks, "failures": failures, "captures": captures, "probe_hash": FileAccess.get_sha256("res://tests/test_home_readability.gd"), "home_hash": FileAccess.get_sha256("res://scripts/app/ui/home_view.gd"), "main_hash": FileAccess.get_sha256("res://scripts/app/main.gd"), "seed": 250925, "boundary": "isolated in-memory native Godot runtime; no package/device/server acceptance"}
	var file = FileAccess.open(OUT + stage + "/report-" + DisplayServer.get_name() + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("HOME_READABILITY checks=%d failures=%d" % [checks.size(), failures])
	get_tree().quit(1 if failures else 0)

func test_claim_dot() -> void:
	var h = app.home_view
	app.reward_rng.seed = 250925
	check(h.has_dot(), "unclaimed_rewards_show_dot")
	h.busy = true
	check(h.has_dot(), "pending_claim_keeps_dot")
	h.busy = false
	app.reject_save = true
	await tap(h.exchange_button().get_center())
	check(h.has_dot() and bool(h.snapshot.can_claim), "failed_claim_keeps_dot")
	app.reject_save = false
	h.modal = "claim"
	await tap(h.exchange_button().get_center())
	check(not bool(h.snapshot.can_claim) and app.wallet_gold >= 700, "successful_claim_commits_rewards")
	check(not h.has_dot(), "successful_claim_removes_dot_even_with_affordable_land")
	await tap(h.exchange_button().get_center())
	await capture("after-claim")
	var day = Rules.day_key()
	h.accept_snapshot(Rules.daily_snapshot(h.state, day + 1), false)
	check(h.has_dot(), "next_day_authoritative_snapshot_restores_dot")
	h.accept_snapshot(Rules.daily_snapshot(h.state, day), false)
	h.modal = ""

func test_plots() -> void:
	var h = app.home_view
	app.wallet_gold = 10000
	await tap(h.plot_point("1,0"))
	check(h.state.owned.has("1,0"), "native_adjacent_unlock")
	var far = "-2,0"
	h.pan = Vector2(360, 564) - h.plot_point(far)
	await frame()
	check(values(far, "type").is_empty() and values(far, "text").is_empty(), "nonadjacent_has_bare_hex", values(far, "type"))
	h.zoom = 0.70
	h.pan = Vector2.ZERO
	h.pan = Vector2(360, 564) - h.plot_point(far)
	var before_pan: Vector2 = h.pan
	var before_gold = app.wallet_gold
	await tap(h.plot_point(far))
	check(h.pan == before_pan and is_equal_approx(h.zoom, 0.70) and app.wallet_gold == before_gold and not h.state.owned.has(far), "nonadjacent_tap_no_focus_no_spend", [h.pan, h.zoom])
	var adjacent = "0,-1"
	h.zoom = 1.0
	h.pan = Vector2.ZERO
	app.wallet_gold = 0
	await frame()
	check(values(adjacent, "type").size() == 1 and values(adjacent, "text").has(str(Rules.plot(adjacent).cost)), "poor_wallet_keeps_adjacent_type_price")
	await tap(h.plot_point(adjacent))
	check(not h.state.owned.has(adjacent) and app.wallet_gold == 0, "insufficient_wallet_tap_no_purchase")
	app.wallet_gold = 10000
	# Center remains visible while the full price footprint is clipped.
	h.pan = Vector2(0, 225 - h.plot_point(adjacent).y)
	check(not h._plot_price_visible(adjacent), "clipped_price_is_not_purchase_ready")
	before_gold = app.wallet_gold
	await tap(h.plot_point(adjacent))
	check(app.wallet_gold == before_gold and not h.state.owned.has(adjacent) and h._plot_price_visible(adjacent), "clipped_price_first_tap_focuses_without_spend")
	await tap(h.plot_point(adjacent))
	check(h.state.owned.has(adjacent) and app.wallet_gold == before_gold - Rules.plot(adjacent).cost, "focused_second_tap_purchases_once")
	# Each native drag moves labels/buildings through the old inset cutoff by 2px.
	var label = "-1,0"
	for kind in ["mouse", "touch"]:
		for edge in ["top", "bottom", "left", "right"]:
			h.zoom = 1.0
			h.pan = Vector2.ZERO
			var center = Vector2(360, 564)
			var delta = Vector2.ZERO
			match edge:
				"top": center.y = 225; delta.y = -2
				"bottom": center.y = 919; delta.y = 2
				"left": center.x = 31; delta.x = -2
				"right": center.x = 689; delta.x = 2
			h.pan += center - h.plot_point(label)
			await frame()
			check(values(label, "type").size() == 1 and values(label, "text").has(str(Rules.plot(label).cost)), kind + "_" + edge + "_label_before")
			var owned_before = h.state.owned.size()
			before_gold = app.wallet_gold
			await drag(Vector2(360, 600), Vector2(20, 0), kind)
			await drag(Vector2(360, 600), Vector2(-20, 0) + delta, kind)
			await frame()
			check(values(label, "type").size() == 1 and values(label, "text").has(str(Rules.plot(label).cost)), kind + "_" + edge + "_label_after", values(label, "text"))
			check(app.wallet_gold == before_gold and h.state.owned.size() == owned_before, kind + "_" + edge + "_drag_never_purchases")
			await capture(kind + "-" + edge + "-label")
			h.pan += center - h.plot_point("0,0")
			await frame()
			check(values("0,0", "building").size() == 1, kind + "_" + edge + "_building_before")
			await drag(Vector2(360, 600), Vector2(20, 0), kind)
			await drag(Vector2(360, 600), Vector2(-20, 0) + delta, kind)
			await frame()
			check(values("0,0", "building").size() == 1, kind + "_" + edge + "_building_after")
	h.pan = Vector2.ZERO
	h.zoom = 1.0
	h.pan += Vector2(360, 564) - h.plot_point("0,-2")
	await frame()
	check(values("0,-2", "type").size() == 1, "unlock_updates_next_adjacent_type")
	await capture("adjacency")

func expected_color(value: int) -> Color:
	if value < 15: return Palette.SAGE
	if value < 40: return Palette.BLUE
	if value < 70: return Palette.LILAC
	return Palette.GOLD

func cell_color(scope: String, item_id: String) -> String:
	for art in rows(scope, "art"):
		if art.value != item_id: continue
		var smallest = INF
		var color = ""
		for panel in rows(scope, "panel"):
			if panel.rect.encloses(art.rect) and panel.rect.get_area() < smallest:
				smallest = panel.rect.get_area()
				color = panel.color
		return color
	return "missing"

func test_details() -> void:
	var h = app.home_view
	var day = Rules.day_key()
	h.pan = Vector2.ZERO
	h.zoom = 1.0
	h.modal = ""
	var selected_plots: Array = []
	for boundary in [14, 15, 39, 40, 69, 70]:
		var found: Dictionary = {}
		for p in Rules.all_plots():
			if int(p.value) == boundary and p.item_id == "soft_pillow": found = p; break
		if found.is_empty():
			for p in Rules.all_plots():
				if int(p.value) == boundary: found = p; break
		# Some edge values have no configured plot; use nearest in that same band.
		if found.is_empty():
			var distance = INF
			for p in Rules.all_plots():
				if p.type != "castle" and expected_color(p.value) == expected_color(boundary) and absf(float(p.value) - boundary) < distance:
					found = p
					distance = absf(float(p.value) - boundary)
		check(not found.is_empty(), "fixture_has_band_near_%d" % boundary, found.get("value", -1))
		if found.is_empty(): continue
		selected_plots.append(found)
		h.state.owned[found.id] = day - 1
		h.selected = found.id
		h.refresh()
		await frame()
		var texts = values("details", "text")
		check(texts.has("每日产出"), "detail_daily_output_heading_%d" % boundary, texts)
		check(not texts.any(func(s): return String(s).contains(found.item_name) or String(s).contains("/ 日") or String(s).contains("每日收益可兑换")), "detail_no_duplicate_item_or_rate_%d" % boundary, texts)
		check(values("details", "art").has(found.item_id), "detail_official_icon_%d" % boundary)
		check(cell_color("details", found.item_id) == expected_color(boundary).to_html(), "detail_quality_band_%d" % boundary, cell_color("details", found.item_id))
		await capture("detail-value-%d" % boundary)
	# Same item from distant rings must remain distinguishable by its value quality.
	h.state = Rules.initial_state(day - 1)
	for band in range(4):
		for p in Rules.all_plots():
			if p.item_id == "soft_pillow" and expected_color(p.value) == [Palette.SAGE, Palette.BLUE, Palette.LILAC, Palette.GOLD][band]:
				h.state.owned[p.id] = day - 1
				break
	h.accept_snapshot(Rules.daily_snapshot(h.state, day), false)
	h.modal = "claim"
	await frame()
	var groups = h._reward_groups()
	check(groups.size() == 4, "reward_splits_same_item_across_four_qualities", groups)
	var quantity = 0
	for group in groups: quantity += int(group.count)
	check(quantity == 4, "reward_split_preserves_total_quantity", quantity)
	var colors: Array = []
	for panel in rows("modal", "panel"):
		if panel.color in [Palette.SAGE.to_html(), Palette.BLUE.to_html(), Palette.LILAC.to_html(), Palette.GOLD.to_html()]: colors.append(panel.color)
	check(colors.has(Palette.SAGE.to_html()) and colors.has(Palette.BLUE.to_html()) and colors.has(Palette.LILAC.to_html()) and colors.has(Palette.GOLD.to_html()), "reward_quality_cells_match_detail_bands", colors)
	await capture("four-quality-rewards")
	h.modal = ""
	h.selected = "1,0"
	h.state.owned["1,0"] = day
	h.refresh()
	await frame()
	check(values("details", "text").any(func(s): return String(s).contains("明日")), "new_building_keeps_next_day_status")
	await capture("tomorrow")

func frame() -> void:
	app._layout(viewport.size)
	app.queue_redraw()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func pointer(position: Vector2, down: bool, kind: String = "mouse") -> void:
	app._layout(viewport.size)
	var event
	if kind == "touch":
		event = InputEventScreenTouch.new()
		event.index = 0
	else:
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = app.canvas_offset + position * app.canvas_scale
	viewport.push_input(event, true)
	await get_tree().process_frame

func tap(position: Vector2) -> void:
	await pointer(position, true)
	await pointer(position, false)
	await frame()

func drag(start: Vector2, delta: Vector2, kind: String) -> void:
	await pointer(start, true, kind)
	var event
	if kind == "touch":
		event = InputEventScreenDrag.new()
		event.index = 0
	else:
		event = InputEventMouseMotion.new()
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = app.canvas_offset + (start + delta) * app.canvas_scale
	event.relative = delta * app.canvas_scale
	viewport.push_input(event, true)
	await get_tree().process_frame
	await pointer(start + delta, false, kind)

func capture(label: String) -> void:
	app.toast_timer = 0.0
	await frame()
	if DisplayServer.get_name() == "headless": return
	var path = OUT + stage + "/" + resolution + "-" + label + ".png"
	check(viewport.get_texture().get_image().save_png(path) == OK, "capture_" + label)
	captures.append(path)
