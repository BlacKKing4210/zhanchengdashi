extends RefCounted
## Home page uses the same canvas, terrain textures and resource icons as battle.
const Rules = preload("res://scripts/shared/home_rules.gd")
const Simulation = preload("res://scripts/app/systems/home_simulation.gd")
const Palette = preload("res://scripts/app/ui/handdrawn_ui_skin.gd")
const Visuals = preload("res://scripts/app/ui/home_visual_catalog.gd")
const MAP_RECT = Rect2(0, 194, 720, 756)
const TYPE_COLORS = {"castle": 7, "residence": 1, "dining": 5, "entertainment": 2, "sport": 4}
const TYPE_LABELS = {"castle": "主城堡", "residence": "居住", "dining": "吃饭", "entertainment": "娱乐", "sport": "运动"}
var app
var simulation = Simulation.new()
var state: Dictionary = {}
var snapshot: Dictionary = {}
var selected = "0,0"
var pan = Vector2.ZERO
var zoom = 1.0
var modal = ""
var reward: Dictionary = {}
var reward_page = 0
var busy = false
var status = "正在连接家园"
var preview = false
var available = false
var dragging = false
var dragged = false
var pointer_start = Vector2.ZERO
var last_pointer = Vector2.ZERO
var touch_id = -1
var textures: Dictionary = {}
var visible: Array = []
var pending_pop = true
var last_frame_ms = 0.0
var refresh_retry_seconds = 0.0

func _init(owner) -> void:
	app = owner
	state = Rules.initial_state(Rules.day_key())
	refresh()

func refresh() -> void:
	visible = Rules.visible_plots(state)
	var animals: Array = []
	for card in app.cards:
		if app._card_kind(card) == "animal" and app._card_total_count(String(card.id)) > 0:
			animals.append(String(card.id))
	simulation.configure(state.get("owned", {}), visible, animals)
	if not state.get("owned", {}).has(selected) and Rules.plot(selected).is_empty(): selected = "0,0"

func enter() -> void:
	pending_pop = true
	modal = ""
	reward_page = 0
	refresh()
	app._home_request("state")

func accept_snapshot(data: Dictionary, auto_popup: bool = true) -> void:
	snapshot = data.duplicate(true)
	available = true
	status = ""
	if pending_pop and auto_popup and bool(snapshot.get("can_claim", false)):
		modal = "claim"
		pending_pop = false
	refresh()

func has_dot() -> bool:
	# A connection failure does not consume rewards; only a new snapshot clears them.
	return bool(snapshot.get("can_claim", false))

func update(delta: float) -> void:
	if app.screen == "home": simulation.update(minf(delta, 0.25))
	refresh_retry_seconds = maxf(0.0, refresh_retry_seconds - delta)
	if preview and int(snapshot.get("day", -1)) != Rules.day_key():
		accept_snapshot(Rules.daily_snapshot(state, Rules.day_key()), false)
	if not preview and available and not busy and refresh_retry_seconds <= 0.0 and int(snapshot.get("day", -1)) != Rules.day_key():
		# Ask the authoritative service at midnight; never grant using this clock.
		# Throttle retries if the device clock and server clock disagree.
		refresh_retry_seconds = 60.0
		app._home_request("state")

func map_point(world: Vector2) -> Vector2:
	return Vector2(360, 564) + pan + world * zoom

func plot_point(id: String) -> Vector2:
	var p = Rules.plot(id)
	return map_point(Simulation.center(int(p.get("q", 0)), int(p.get("r", 0))))

func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result = points.duplicate()
	if not points.is_empty(): result.append(points[0])
	return result

func _text(value: String, rect: Rect2, size: int = 24, color: Color = Palette.INK) -> void:
	app._draw_text_center(value, rect, size, color)

func _panel(rect: Rect2, color: Color = Palette.RAISED, radius: int = 16) -> void:
	app.draw_style_box(Palette.panel(color, radius, false), rect)

func _texture(id: String) -> Texture2D:
	if id == "soft_pillow": id = "pillow"
	if textures.has(id): return textures[id]
	var path = "res://assets/art/home/%s.png" % id
	var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if texture != null: textures[id] = texture
	return texture

func _art(id: String, rect: Rect2, tint: Color = Color.WHITE) -> void:
	if id == "castle":
		_draw_building(Rules.plot("0,0"), rect)
		return
	var texture = _texture(id)
	if texture != null:
		app.draw_texture_rect(texture, rect, false, tint)

func _building_texture(p: Dictionary) -> Texture2D:
	var path = String(Visuals.definition(p).get("art_path", ""))
	if textures.has(path): return textures[path]
	if path.is_empty() or not ResourceLoader.exists(path): return null
	var texture: Texture2D = load(path)
	textures[path] = texture
	return texture

func _draw_building(p: Dictionary, rect: Rect2) -> void:
	var texture = _building_texture(p)
	if texture == null: return
	var visual = Visuals.definition(p)
	var source = Rect2(float(visual.get("crop_left", 0)), float(visual.get("crop_top", 0)), float(visual.get("crop_width", 1)), float(visual.get("crop_height", 1)))
	source = Rect2(source.position * texture.get_size(), source.size * texture.get_size())
	if not source.has_area(): return
	var scale = minf(rect.size.x / source.size.x, rect.size.y / source.size.y)
	var size = source.size * scale
	app.draw_texture_rect_region(texture, Rect2(rect.get_center() - size * 0.5, size), source)

func _type_icon(kind: String, center: Vector2, size: float, background: Color = Color("dedad3")) -> void:
	var ink = Palette.DISABLED_INK
	var s = size / 64.0
	match kind:
		"residence":
			app.draw_colored_polygon(PackedVector2Array([center + Vector2(-29, -3) * s, center + Vector2(0, -27) * s, center + Vector2(29, -3) * s]), ink)
			app.draw_rect(Rect2(center + Vector2(-21, -4) * s, Vector2(42, 29) * s), ink)
			app.draw_rect(Rect2(center + Vector2(-6, 7) * s, Vector2(12, 18) * s), background)
		"dining":
			app.draw_colored_polygon(PackedVector2Array([center + Vector2(-29, -4) * s, center + Vector2(28, -4) * s, center + Vector2(18, 23) * s, center + Vector2(-18, 23) * s]), ink)
			app.draw_line(center + Vector2(-30, -7) * s, center + Vector2(29, -7) * s, ink, 5 * s, true)
			app.draw_line(center + Vector2(6, -10) * s, center + Vector2(18, -31) * s, ink, 6 * s, true)
			app.draw_circle(center + Vector2(20, -33) * s, 7 * s, ink)
		"entertainment":
			app.draw_circle(center + Vector2(-17, 20) * s, 10 * s, ink)
			app.draw_circle(center + Vector2(18, 11) * s, 10 * s, ink)
			app.draw_line(center + Vector2(-10, 20) * s, center + Vector2(-10, -22) * s, ink, 7 * s, true)
			app.draw_line(center + Vector2(25, 11) * s, center + Vector2(25, -30) * s, ink, 7 * s, true)
			app.draw_line(center + Vector2(-10, -22) * s, center + Vector2(25, -30) * s, ink, 10 * s, true)
		"sport":
			app.draw_circle(center, 28 * s, ink)
			app.draw_line(center + Vector2(-25, -12) * s, center + Vector2(25, 12) * s, background, 3 * s, true)
			app.draw_line(center + Vector2(-12, 25) * s, center + Vector2(12, -25) * s, background, 3 * s, true)
			app.draw_arc(center + Vector2(-26, -12) * s, 29 * s, -1.1, 1.55, 18, background, 3 * s, true)
			app.draw_arc(center + Vector2(26, 12) * s, 29 * s, 2.0, 4.7, 18, background, 3 * s, true)

func draw() -> void:
	app.draw_rect(Rect2(0, 0, 720, 1280), Color("e7e6d7") if not simulation.is_night() else Color("bec6ce"))
	for p in visible:
		_draw_plot(p)
	_draw_residents()
	# Opaque UI masks the pan-able world, keeping all essential labels in bounds.
	app.draw_rect(Rect2(0, 0, 720, 194), Palette.PAPER)
	app.draw_rect(Rect2(0, 950, 720, 330), Palette.PAPER)
	app._draw_top_bar()
	_text("动物家园", Rect2(26, 81, 236, 50), 40)
	_panel(Rect2(487, 84, 201, 43), Palette.BLUE if simulation.is_night() else Palette.GOLD)
	_text(("夜晚" if simulation.is_night() else "白天") + "  %02d:00" % simulation.hour(), Rect2(487, 84, 201, 43), 24)
	_text("%d 位居民 · %d 座建筑" % [simulation.residents.size(), state.get("owned", {}).size()], Rect2(28, 136, 348, 36), 24)
	for i in range(4):
		var type: String = ["residence", "dining", "entertainment", "sport"][i]
		var c = Vector2(419 + i * 72, 153)
		_type_icon(type, c, 18, Palette.PAPER)
		_text(TYPE_LABELS[type], Rect2(c + Vector2(10, -17), Vector2(52, 34)), 21)
	if available and bool(snapshot.get("can_claim", false)):
		app._cta(claim_button(), "领取收益", true, not busy)
		app.draw_circle(claim_button().position + Vector2(claim_button().size.x - 4, 3), 8, Palette.UPGRADE_DOT)
	_draw_details()

func _draw_plot(p: Dictionary) -> void:
	var c = plot_point(p.id)
	var radius = Simulation.RADIUS * zoom
	if not MAP_RECT.grow(radius + 96.0).has_point(c): return
	var owned = state.get("owned", {}).has(p.id)
	var terrain: int = TYPE_COLORS.get(p.type, 7)
	var points = Simulation.corners(c, radius * 0.93)
	var uv = PackedVector2Array()
	for point in points: uv.append((point - c) / (Vector2(radius * 2, radius * sqrt(3.0)) * 1.01) + Vector2(0.5, 0.5))
	app.draw_polyline(_closed(Simulation.corners(c, radius)), Color("b7aa91"), 5.0 * zoom, true)
	if owned: app.draw_polygon(points, PackedColorArray([Color.WHITE]), uv, Palette.TERRAIN[terrain])
	else: app.draw_colored_polygon(points, Color("dedad3"))
	if owned and p.id == selected:
		app.draw_polyline(_closed(Simulation.corners(c, radius * 0.95)), Color("795c2c"), 4.0, true)
	# Draw the whole world continuously; the opaque page chrome clips it naturally.
	# Full-price visibility below is a purchase guard, never a drawing switch.
	if owned:
		var visual = Visuals.definition(p)
		var size = Vector2(float(visual.get("width", 138)), float(visual.get("height", 136))) * zoom
		_draw_building(p, Rect2(c - size * 0.5, size))
	elif bool(Rules.can_unlock(state, p.id, int(p.cost)).get("ok", false)):
		_type_icon(p.type, c + Vector2(0, -18) * zoom, 58 * zoom)
		app._draw_resource_icon(c + Vector2(-44, 43), "金币", Palette.GOLD)
		_text(str(p.cost), Rect2(c + Vector2(-27, 26), Vector2(105, 36)), 25)

func _plot_price_visible(id: String) -> bool:
	var c = plot_point(id)
	return zoom >= 0.85 and MAP_RECT.grow(-30).has_point(c) and Rect2(8, 194, 704, 756).encloses(Rect2(c + Vector2(-75, -62), Vector2(150, 132)))

func _draw_residents() -> void:
	var actors = simulation.residents.duplicate()
	actors.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	for a in actors:
		if a.inside: continue
		var position: Vector2 = map_point(a.pos)
		if not MAP_RECT.grow(-32).has_point(position): continue
		var stride = sin(simulation.clock * 10 + float(String(a.id).hash() % 20)) * 2.0 if not a.route.is_empty() else 0.0
		var size = Vector2(62, 64) * zoom
		app.draw_set_transform(app.canvas_offset + (position + Vector2(0, stride)) * app.canvas_scale, 0, Vector2(a.facing, 1) * app.canvas_scale)
		app._draw_animal_art_in_rect(app._card_by_id(a.id), Rect2(Vector2(-size.x * 0.5, -size.y), size))
		app._set_tracked_draw_transform(app.canvas_offset, 0, Vector2.ONE * app.canvas_scale)
		if a.mood_time > 0: _draw_mood(position + Vector2(0, -66 * zoom), a.mood)

func _draw_mood(c: Vector2, mood: String) -> void:
	app.draw_line(c + Vector2(0, 17), c + Vector2(-4, 27), Palette.INK, 3, true)
	app.draw_circle(c, 22, Palette.RAISED)
	app.draw_arc(c, 22, 0, TAU, 32, Palette.INK, 2, true)
	if mood == "love":
		app._draw_heart_icon(c, Color("da7381"))
	else:
		for x in [-7, 7]:
			if mood == "tired": app.draw_line(c + Vector2(x - 3, -5), c + Vector2(x + 3, -5), Palette.INK, 2, true)
			else: app.draw_circle(c + Vector2(x, -5), 2.2, Palette.INK)
		app.draw_arc(c + Vector2(0, 1 if mood != "tired" else 12), 8, 0 if mood != "tired" else PI, PI if mood != "tired" else TAU, 16, Palette.INK, 2, true)

func _draw_details() -> void:
	var p = Rules.plot(selected)
	if p.is_empty() or not state.get("owned", {}).has(p.id): return
	_panel(Rect2(24, 967, 672, 155), Palette.SURFACE)
	_draw_building(p, Rect2(40, 989, 104, 104))
	_text(p.name, Rect2(156, 990, 266, 40), 29)
	_text("每日产出", Rect2(440, 978, 220, 34), 25)
	if p.type == "castle":
		var economy = Rules.economy()
		_draw_output_cell("金币", int(economy.castle_gold), Rect2(450, 1020, 92, 88))
		_draw_output_cell("券", int(economy.castle_tickets), Rect2(554, 1020, 92, 88))
	else:
		_draw_output_cell(p.item_id, 1, Rect2(506, 1020, 88, 88), _item_quality(int(p.value)))
		if int(state.owned[p.id]) >= int(snapshot.get("day", Rules.day_key())):
			_text("明日开始产出", Rect2(156, 1044, 266, 36), 23)


func _item_quality(value: int) -> String:
	# Presentation bands only. Exchange values and grants remain server-owned.
	if value >= 70: return "legendary"
	if value >= 40: return "epic"
	if value >= 15: return "rare"
	return "common"


func _draw_output_cell(id: String, quantity: int, rect: Rect2, quality: String = "") -> void:
	_panel(rect, Palette.RAISED if quality.is_empty() else Palette.rarity(quality), 12)
	var art_size = minf(rect.size.x - 12, rect.size.y - 36)
	var art_rect = Rect2(rect.position + Vector2((rect.size.x - art_size) * 0.5, 3), Vector2.ONE * art_size)
	if id in ["金币", "券"]:
		app._draw_resource_icon(art_rect.get_center(), id, Palette.GOLD if id == "金币" else Palette.BLUE)
	else:
		_art(id, art_rect)
	_text("×%d" % quantity, Rect2(rect.position + Vector2(4, rect.size.y - 32), Vector2(rect.size.x - 8, 28)), 23)


func claim_button() -> Rect2: return Rect2(466, 876, 224, 56)
func exchange_button() -> Rect2: return Rect2(116, 950, 488,  60)
func close_button() -> Rect2: return Rect2(612, 247, 50, 50)

func _reward_groups() -> Array:
	var groups: Dictionary = {}
	for item in snapshot.get("items", []):
		var id = String(item.get("item_id", ""))
		var source_plot = Rules.plot(String(item.get("plot_id", "")))
		var quality = _item_quality(int(source_plot.get("value", 1)))
		var key = id + ":" + quality
		if not groups.has(key): groups[key] = {"id": id, "name": item.get("item_name", id), "quality": quality, "count": 0}
		groups[key].count += int(item.get("quantity", 1))
	return groups.values()

func _draw_modal() -> void:
	app.draw_rect(Rect2(0, 0, 720, 1280), Color(0.12, 0.13, 0.17, 0.58))
	_panel(Rect2(48, 235, 624, 808), Palette.PAPER, 24)
	_text("今日家园收益" if modal == "claim" else "收益已到账", Rect2(74, 268, 530, 54), 38)
	app._cta(close_button(), "×", false, not busy)
	if modal == "claim":
		var days: Array = snapshot.get("days", [])
		_text("累计 %d 天 · 最多保留 3 天" % days.size(), Rect2(80, 337, 560, 36), 25)
		_panel(Rect2(84, 394, 552, 106), Palette.SURFACE)
		_art("castle", Rect2(96, 402, 86, 86))
		_text("主城堡", Rect2(186, 406, 140, 35), 27)
		app._draw_resource_icon(Vector2(371, 448), "金币", Palette.GOLD)
		_text(str(snapshot.get("castle_gold", 0)), Rect2(391, 427, 85,  40), 29)
		app._draw_resource_icon(Vector2(527, 448), "券", Palette.BLUE)
		_text(str(snapshot.get("castle_tickets", 0)), Rect2(548, 427,  60,  40), 29)
		var groups = _reward_groups()
		if groups.is_empty():
			_text("解锁更多建筑，收获家园道具", Rect2(84, 588, 552,  40), 25)
			_text("新建筑从明天开始产出", Rect2(84, 642, 552,  40), 24)
		else:
			for index in range(mini(4, groups.size() - reward_page * 4)):
				var item: Dictionary = groups[reward_page * 4 + index]
				var cell = Rect2(152 + (index % 2) * 272, 522 + (index / 2) * 160, 144, 144)
				_draw_output_cell(item.id, int(item.count), cell, item.quality)
		if groups.size() > 4:
			app._cta(Rect2( 90, 865, 132, 52), "上一页", false)
			app._cta(Rect2(498, 865, 132, 52), "下一页", false)
		_text("道具随机兑换金币，有机会获得抽卡券", Rect2( 70, 899, 580, 35), 23)
		app._cta(exchange_button(), "兑换并领取" if not busy else "领取中…", true, not busy and available)
	else:
		_text("已存入你的账户", Rect2(80, 351, 560,  40), 26)
		_panel(Rect2(105, 462, 510, 214), Palette.SURFACE)
		app._draw_resource_icon(Vector2(233, 521), "金币", Palette.GOLD)
		_text("+%d" % int(reward.get("gold", 0)), Rect2(265, 492, 252, 58), 42)
		app._draw_resource_icon(Vector2(233, 613), "券", Palette.BLUE)
		_text("+%d" % int(reward.get("tickets", 0)), Rect2(265, 584, 252, 58), 42)
		_text("明天再来，动物们还会准备新的礼物", Rect2(80, 743, 560,  50), 25)
		app._cta(exchange_button(), "收下啦", true)


func tap(pos: Vector2) -> void:
	if not modal.is_empty():
		if busy: return
		if close_button().has_point(pos): modal = ""
		elif exchange_button().has_point(pos):
			if modal == "claim": app._home_request("claim")
			else: modal = ""
		elif Rect2(90, 865, 132, 52).has_point(pos): reward_page = maxi(0, reward_page - 1)
		elif Rect2(498, 865, 132, 52).has_point(pos): reward_page = mini(maxi(0, ceili(_reward_groups().size() / 4.0) - 1), reward_page + 1)
		return
	if busy: return
	if available and bool(snapshot.get("can_claim", false)) and claim_button().has_point(pos):
		modal = "claim"
		return
	if MAP_RECT.has_point(pos):
		for p in visible:
			if Geometry2D.is_point_in_polygon(pos, Simulation.corners(plot_point(p.id), Simulation.RADIUS * zoom)):
				if state.owned.has(p.id):
					selected = p.id
					GameAudio.play_sfx("ui_click")
				else:
					var eligibility = Rules.can_unlock(state, p.id, app.wallet_gold)
					if eligibility.get("error", "") == "plot_not_adjacent":
						app._toast("请先解锁相邻地块")
						return
					if not _plot_price_visible(p.id):
						zoom = maxf(1.0, zoom)
						pan += Vector2(360, 564) - plot_point(p.id)
						app._toast("再次点击地块即可建造")
						return
					if not bool(eligibility.ok):
						app._toast("金币不足" if eligibility.error == "insufficient_gold" else "请先解锁相邻地块")
					elif not available:
						app._toast("暂时无法建设，请稍后再试")
						app._home_request("state")
					else: app._home_request("unlock", p.id)
				return

func handle_pointer(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
		var pos: Vector2 = app._screen_to_canvas(event.position)
		if MAP_RECT.has_point(pos) and modal.is_empty():
			zoom = clampf(zoom + (0.08 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.08), 0.70, 1.35)
			return true
	var pressed = false
	var released = false
	var position = Vector2.ZERO
	if event is InputEventScreenTouch:
		if touch_id != -1 and event.index != touch_id: return true
		pressed = event.pressed
		released = not event.pressed
		position = app._screen_to_canvas(event.position)
		if pressed: touch_id = event.index
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		released = not event.pressed
		position = app._screen_to_canvas(event.position)
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if event is InputEventScreenDrag and event.index != touch_id: return true
		if not dragging: return false
		position = app._screen_to_canvas(event.position)
		if position.distance_to(pointer_start) > 12.0: dragged = true
		if dragged:
			pan += position - last_pointer
			var bound = 2100.0 * zoom
			pan = pan.clamp(Vector2(-bound, -bound), Vector2(bound, bound))
		last_pointer = position
		return true
	var on_claim = available and bool(snapshot.get("can_claim", false)) and claim_button().has_point(position)
	if pressed and MAP_RECT.has_point(position) and modal.is_empty() and not on_claim:
		dragging = true
		dragged = false
		pointer_start = position
		last_pointer = position
		return true
	if released and dragging:
		dragging = false
		touch_id = -1
		if not dragged: tap(position)
		return true
	if released and event is InputEventScreenTouch: touch_id = -1
	return false
