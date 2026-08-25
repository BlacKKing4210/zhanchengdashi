extends Node

const MainApp = preload("res://scripts/app/main.gd")

var failures = 0
var app: Node


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	await get_tree().process_frame
	await get_tree().process_frame
	app.set_process(false)
	_test_project_resolution_contract()
	_test_native_font_sizes()
	_test_screen_rect_mapping()
	_test_layout_scales()
	if failures == 0:
		print("RENDERING_CLARITY_TEST_PASS checks=15")
	else:
		push_error("Rendering clarity test failed with %d error(s)." % failures)
	app.queue_free()
	await get_tree().process_frame
	get_tree().quit(failures)


func _test_project_resolution_contract() -> void:
	_expect_equal(int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)), 720, "portrait viewport width")
	_expect_equal(int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)), 1280, "portrait viewport height")
	_expect_equal(int(ProjectSettings.get_setting("display/window/handheld/orientation", 0)), 1, "portrait orientation")
	_expect_true(bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel", false)), "2D transforms snap to pixels")
	_expect_true(bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_vertices_to_pixel", false)), "2D vertices snap to pixels")


func _test_native_font_sizes() -> void:
	_expect_equal(int(app.call("_native_font_size_for_scale", 20, 0.75)), 15, "540x960 font size")
	_expect_equal(int(app.call("_native_font_size_for_scale", 20, 1.0)), 20, "720x1280 default font size")
	_expect_equal(int(app.call("_native_font_size_for_scale", 20, 1.5)), 30, "1080x1920 font size")
	_expect_equal(int(app.call("_native_font_size_for_scale", 20, 2.0)), 40, "1440x2560 font size")
	_expect_equal(int(app.call("_native_font_size_for_scale", 1, 0.01)), 1, "native font minimum")


func _test_screen_rect_mapping() -> void:
	app.set("text_draw_origin", Vector2(10.0, 20.0))
	app.set("text_draw_scale", Vector2(0.75, 0.75))
	var mapped: Rect2 = app.call("_text_screen_rect", Rect2(4.0, 8.0, 100.0, 40.0))
	_expect_vector_close(mapped.position, Vector2(13.0, 26.0), "screen rect position")
	_expect_vector_close(mapped.size, Vector2(75.0, 30.0), "screen rect size")


func _test_layout_scales() -> void:
	app.call("_layout", Vector2(540.0, 960.0))
	_expect_close(float(app.get("canvas_scale")), 0.75, "540x960 canvas scale")
	app.call("_layout", Vector2(720.0, 1280.0))
	_expect_close(float(app.get("canvas_scale")), 1.0, "720x1280 default canvas scale")
	app.call("_layout", Vector2(1080.0, 1920.0))
	_expect_close(float(app.get("canvas_scale")), 1.5, "1080x1920 canvas scale")


func _expect_equal(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		return
	_fail("%s: expected %d, got %d" % [label, expected, actual])


func _expect_close(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) <= 0.0001:
		return
	_fail("%s: expected %.4f, got %.4f" % [label, expected, actual])


func _expect_vector_close(actual: Vector2, expected: Vector2, label: String) -> void:
	if actual.distance_to(expected) <= 0.001:
		return
	_fail("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _expect_true(value: bool, label: String) -> void:
	if value:
		return
	_fail("%s: expected true" % label)


func _fail(message: String) -> void:
	failures += 1
	push_error(message)
