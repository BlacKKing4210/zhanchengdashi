extends Node
const Base = preload("res://tests/test_home_runtime.gd")
const Rules = preload("res://scripts/shared/home_rules.gd")
const Visuals = preload("res://scripts/app/ui/home_visual_catalog.gd")
const OUT = "res://temp/qa/home-polish-20260925/"
class CatalogApp extends Base.TestApp:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1480, 980), Color("f4eee3"))
		_layout(Vector2(720, 1280))
		canvas_offset = Vector2.ZERO
		canvas_scale = 1.0
		var types = ["residence", "dining", "entertainment", "sport"]
		for row in range(4):
			for ring in range(1, 9):
				var p = {"type": types[row], "ring": ring}
				var c = Vector2(90 + (ring - 1) * 180, 140 + row * 235)
				var visual = Visuals.definition(p)
				var size = Vector2(float(visual.get("width", 138)), float(visual.get("height", 136)))
				_ensure_home()._draw_building(p, Rect2(c - size * 0.5, size))
				_draw_text_native("%s · 第%d圈" % [home_view.TYPE_LABELS[types[row]], ring], Rect2(c + Vector2(-88, 86), Vector2(176, 40)), 24, Color("332f29"), HORIZONTAL_ALIGNMENT_CENTER)

func _ready() -> void:
	GameAudio.set_music_enabled(false)
	GameAudio.set_sfx_enabled(false)
	var viewport = SubViewport.new()
	viewport.size = Vector2i(1480, 980)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var app = CatalogApp.new()
	viewport.add_child(app)
	await get_tree().process_frame
	app.set_process(false)
	var missing: Array[String] = []
	for type in ["residence", "dining", "entertainment", "sport"]:
		for tier in range(1, 9):
			if app.home_view._building_texture({"type": type, "ring": tier}) == null: missing.append("%s_%02d" % [type, tier])
	if app.home_view._building_texture(Rules.plot("0,0")) == null: missing.append("castle")
	app.queue_redraw()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(OUT + "home-32-building-catalog.png")
	print("HOME_CATALOG missing=", JSON.stringify(missing))
	app.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if missing.is_empty() else 1)
