extends RefCounted
## Home page uses the same canvas, terrain textures and resource icons as battle.
const Rules = preload("res://scripts/shared/home_rules.gd")
const Simulation = preload("res://scripts/app/systems/home_simulation.gd")
const Palette = preload("res://scripts/app/ui/handdrawn_ui_skin.gd")
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
	if not available: return false
	if bool(snapshot.get("can_claim", false)): return true
	for p in visible:
		if bool(Rules.can_unlock(state, p.id, app.wallet_gold).get("ok", false)): return true
	return false

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
	var texture = app.BUILDING_ART["base"] if id == "castle" else _texture(id)
	if texture != null:
		app.draw_texture_rect(texture, rect, false, tint)

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
		app.draw_circle(c, 6, Palette.TERRAIN_COLORS[TYPE_COLORS[type]])
		_text(TYPE_LABELS[type], Rect2(c + Vector2(10, -17), Vector2(52, 34)), 21)
	if preview:
		_panel(Rect2(26, 209, 180, 35), Palette.RAISED)
		_text("独立玩法预览", Rect2(26, 209, 180, 35), 22)
	elif not status.is_empty():
		_panel(Rect2(30, 205, 660, 65), Palette.RAISED)
		_text(status, Rect2(40, 211, 640, 50), 24)
	for i in range(3):
		app._cta(camera_button(i), ["−", "+", "归位"][i], false)
	var claim_label = "领取收益" if bool(snapshot.get("can_claim", false)) else "今日已领取"
	if not available: claim_label = "重试连接"
	app._cta(claim_button(), claim_label, bool(snapshot.get("can_claim", false)), not busy)
	if bool(snapshot.get("can_claim", false)):
		app.draw_circle(claim_button().position + Vector2(claim_button().size.x - 4, 3), 8, Palette.UPGRADE_DOT)
	_draw_details()

func _draw_plot(p: Dictionary) -> void:
	var c = plot_point(p.id)
	var radius = Simulation.RADIUS * zoom
	if not MAP_RECT.grow(radius).has_point(c): return
	var owned = state.get("owned", {}).has(p.id)
	var terrain: int = TYPE_COLORS.get(p.type, 7)
	var points = Simulation.corners(c, radius * 0.93)
	var uv = PackedVector2Array()
	for point in points: uv.append((point - c) / (Vector2(radius * 2, radius * sqrt(3.0)) * 1.01) + Vector2(0.5, 0.5))
	app.draw_polyline(_closed(Simulation.corners(c, radius)), Color("b7aa91"), 5.0 * zoom, true)
	app.draw_polygon(points, PackedColorArray([Color.WHITE if owned else Color(0.9, 0.9, 0.87, 0.62)]), uv, Palette.TERRAIN[terrain])
	if p.id == selected:
		app.draw_polyline(_closed(Simulation.corners(c, radius * 0.95)), Color("795c2c"), 4.0, true)
	elif not owned and available and bool(Rules.can_unlock(state, p.id, app.wallet_gold).get("ok", false)):
		app.draw_polyline(_closed(Simulation.corners(c, radius * 0.95)), Color("ac8745"), 2.0, true)
	var art_size = 110.0 * zoom if owned else 68.0 * zoom
	if MAP_RECT.grow(-30).has_point(c):
		_art(p.type, Rect2(c + Vector2(-art_size * 0.5, -art_size * 0.62), Vector2.ONE * art_size), Color.WHITE if owned else Color(0.55, 0.51, 0.44, 0.86))
		var label_bounds = Rect2(c + Vector2(-75, -70), Vector2(150, 150))
		if zoom >= 0.85 and Rect2(8, 194, 704, 664).encloses(label_bounds):
			var label_y = 42.0 * zoom if owned else 13.0 * zoom
			_panel(Rect2(c + Vector2(-55, label_y), Vector2(110, 28)), Color("f5efe2"), 7)
			_text(TYPE_LABELS.get(p.type, "建筑"), Rect2(c + Vector2(-55, label_y), Vector2(110, 28)), 23)
			if not owned:
				app._draw_resource_icon(c + Vector2(-48, 61), "金币", Palette.GOLD)
				_text(str(p.cost), Rect2(c + Vector2(-29, 44), Vector2(106, 32)), 25)

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
	if p.is_empty(): return
	var owned = state.get("owned", {}).has(p.id)
	_panel(Rect2(24, 967, 672, 155), Palette.SURFACE)
	_art(p.type, Rect2(34, 976, 84, 84))
	_text(p.name, Rect2(121, 979, 312, 38), 29)
	var sub = "每日固定产出" if p.type == "castle" else ("容纳 %d 位居民" % p.capacity if p.type == "residence" else ("夜晚娱乐" if p.type == "entertainment" else "白天" + TYPE_LABELS[p.type]))
	_text(sub, Rect2(119, 1020, 312, 34), 23)
	if owned:
		if p.type == "castle":
			app._draw_resource_icon(Vector2(484, 1003), "金币", Palette.GOLD)
			_text("100", Rect2(498, 984,  70, 38), 27)
			app._draw_resource_icon(Vector2(592, 1003), "券", Palette.BLUE)
			_text("1", Rect2(610, 984,  50, 38), 27)
			_text("住房不足时，动物住在城堡里", Rect2(54, 1070, 610, 35), 24)
		else:
			_art(p.item_id, Rect2(492, 982, 60, 60))
			_text("×1 / 日", Rect2(554, 996, 116, 35), 24)
			var next_day = int(state.owned[p.id]) >= int(snapshot.get("day", Rules.day_key()))
			_text(p.item_name + (" · 明日开始产出" if next_day else " · 每日收益可兑换"), Rect2(54, 1070, 610, 35), 24)
	else:
		var eligibility = Rules.can_unlock(state, p.id, app.wallet_gold)
		var label = "解锁" if bool(eligibility.ok) else ("金币不足" if eligibility.error == "insufficient_gold" else "先解锁相邻地块")
		app._cta(unlock_button(), label, true, available and bool(eligibility.ok) and not busy)
		app._draw_resource_icon(Vector2(150, 1086), "金币", Palette.GOLD)
		_text(str(p.cost), Rect2(172, 1068, 118, 36), 26)
		_text("解锁立即得", Rect2(310, 1068, 196, 36), 24)
		app._draw_resource_icon(Vector2(531, 1086), "券", Palette.BLUE)
		_text("×1", Rect2(546, 1068, 68, 36), 25)


func claim_button() -> Rect2: return Rect2(466, 876, 224, 56)
func unlock_button() -> Rect2: return Rect2(447, 987, 226,  60)
func camera_button(index: int) -> Rect2: return Rect2(26 + index * 68, 876,  60, 56)
func exchange_button() -> Rect2: return Rect2(116, 950, 488,  60)
func close_button() -> Rect2: return Rect2(612, 247, 50, 50)

func _reward_groups() -> Array:
	var groups: Dictionary = {}
	for item in snapshot.get("items", []):
		var id = String(item.get("item_id", ""))
		if not groups.has(id): groups[id] = {"id": id, "name": item.get("item_name", id), "count": 0}
		groups[id].count += int(item.get("quantity", 1))
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
				var y = 522 + index * 82
				_panel(Rect2(84, y, 552, 72), Palette.RAISED)
				_art(item.id, Rect2(101, y + 4, 64, 64))
				_text(item.name, Rect2(178, y + 15, 260,  40), 27)
				_text("×%d" % item.count, Rect2(463, y + 15, 136,  40), 29)
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
	if claim_button().has_point(pos):
		if not available: app._home_request("state")
		elif bool(snapshot.get("can_claim", false)): modal = "claim"
		else: app._toast("今天的收益已领取，明天再来")
		return
	if unlock_button().has_point(pos) and not state.owned.has(selected):
		app._home_request("unlock", selected)
		return
	for i in range(3):
		if camera_button(i).has_point(pos):
			if i == 2: pan = Vector2.ZERO; zoom = 1.0
			else: zoom = clampf(zoom + (-0.12 if i == 0 else 0.12), 0.70, 1.35)
			return
	if MAP_RECT.has_point(pos):
		for p in visible:
			if Geometry2D.is_point_in_polygon(pos, Simulation.corners(plot_point(p.id), Simulation.RADIUS * zoom)):
				selected = p.id
				GameAudio.play_sfx("ui_click")
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
	if pressed and MAP_RECT.has_point(position) and modal.is_empty() and not claim_button().has_point(position):
		for i in range(3):
			if camera_button(i).has_point(position): return false
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
