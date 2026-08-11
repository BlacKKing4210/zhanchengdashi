extends Node

const MainApp = preload("res://scripts/app/main.gd")

const DESIGN_SIZE = Vector2(720.0, 1280.0)
const BACKGROUND_BASE_COLOR = Color(0.60, 0.85, 0.50)
const BACKGROUND_TOP_COLOR = Color(0.68, 0.90, 0.60)
const COLOR_TOLERANCE = 0.04

var failures = 0
var app: Node
var test_viewport: SubViewport


func _ready() -> void:
	test_viewport = SubViewport.new()
	test_viewport.size = _target_size()
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	test_viewport.transparent_bg = false
	add_child(test_viewport)
	app = MainApp.new()
	test_viewport.add_child(app)
	await get_tree().process_frame
	await get_tree().process_frame
	app.set_process(false)
	app.queue_redraw()
	await RenderingServer.frame_post_draw

	var view_size = app.get_viewport().get_visible_rect().size
	var expected_scale = minf(view_size.x / DESIGN_SIZE.x, view_size.y / DESIGN_SIZE.y)
	var expected_offset = (view_size - DESIGN_SIZE * expected_scale) * 0.5
	_expect_vector_close(app.get("canvas_offset"), expected_offset, "design canvas remains centered")
	_expect_close(float(app.get("canvas_scale")), expected_scale, "design canvas keeps uniform fit scaling")

	var image = test_viewport.get_texture().get_image()
	_validate_surplus_pixels(image, view_size, expected_offset)
	_save_capture(image)

	if failures == 0:
		print("MOBILE_FULL_BLEED_PASS viewport=%s image=%s offset=%s scale=%.6f" % [
			str(view_size),
			str(image.get_size()),
			str(expected_offset),
			expected_scale,
		])
	else:
		push_error("Mobile full-bleed QA failed with %d error(s)." % failures)
	app.queue_free()
	test_viewport.queue_free()
	await get_tree().process_frame
	get_tree().quit(failures)


func _target_size() -> Vector2i:
	var requested = OS.get_environment("ZC_MOBILE_VIEWPORT_SIZE")
	var parts = requested.to_lower().split("x", false)
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		var width = int(parts[0])
		var height = int(parts[1])
		if width > 0 and height > 0:
			return Vector2i(width, height)
	return Vector2i(1080, 2400)


func _validate_surplus_pixels(image: Image, view_size: Vector2, offset: Vector2) -> void:
	var image_size = Vector2(image.get_width(), image.get_height())
	var image_per_view = Vector2(image_size.x / view_size.x, image_size.y / view_size.y)
	if offset.y > 0.5:
		var top_sample = Vector2(view_size.x * 0.5, offset.y * 0.5)
		var bottom_sample = Vector2(view_size.x * 0.5, view_size.y - offset.y * 0.5)
		_expect_color_close(_sample(image, top_sample, image_per_view), BACKGROUND_TOP_COLOR, "top surplus uses the extended scene background")
		_expect_color_close(_sample(image, bottom_sample, image_per_view), BACKGROUND_BASE_COLOR, "bottom surplus uses the extended scene background")
	if offset.x > 0.5:
		var side_sample = Vector2(offset.x * 0.5, view_size.y * 0.75)
		_expect_color_close(_sample(image, side_sample, image_per_view), BACKGROUND_BASE_COLOR, "side surplus uses the extended scene background")
	var top_edge = _sample(image, Vector2(view_size.x * 0.5, 1.0), image_per_view)
	_expect_true(_color_saturation(top_edge) > 0.08, "top edge is not a neutral gray clear color")


func _sample(image: Image, view_position: Vector2, image_per_view: Vector2) -> Color:
	var x = clampi(int(round(view_position.x * image_per_view.x)), 0, image.get_width() - 1)
	var y = clampi(int(round(view_position.y * image_per_view.y)), 0, image.get_height() - 1)
	return image.get_pixel(x, y)


func _save_capture(image: Image) -> void:
	var capture_path = OS.get_environment("ZC_MOBILE_VIEWPORT_CAPTURE")
	if capture_path.is_empty():
		return
	var make_dir_error = DirAccess.make_dir_recursive_absolute(capture_path.get_base_dir())
	if make_dir_error != OK:
		_fail("capture directory creation failed for %s: %s" % [capture_path.get_base_dir(), error_string(make_dir_error)])
		return
	var save_error = image.save_png(capture_path)
	if save_error != OK:
		_fail("capture save failed for %s: %s" % [capture_path, error_string(save_error)])


func _color_saturation(color: Color) -> float:
	return maxf(color.r, maxf(color.g, color.b)) - minf(color.r, minf(color.g, color.b))


func _expect_color_close(actual: Color, expected: Color, label: String) -> void:
	var distance = maxf(
		absf(actual.r - expected.r),
		maxf(absf(actual.g - expected.g), absf(actual.b - expected.b))
	)
	if distance <= COLOR_TOLERANCE:
		return
	_fail("%s: expected %s, got %s (distance %.6f)" % [label, str(expected), str(actual), distance])


func _expect_vector_close(actual: Vector2, expected: Vector2, label: String) -> void:
	if actual.distance_to(expected) <= 0.01:
		return
	_fail("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _expect_close(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) <= 0.0001:
		return
	_fail("%s: expected %.6f, got %.6f" % [label, expected, actual])


func _expect_true(value: bool, label: String) -> void:
	if value:
		return
	_fail("%s: expected true" % label)


func _fail(message: String) -> void:
	failures += 1
	push_error(message)
