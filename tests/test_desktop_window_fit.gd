extends Node

const EXPECTED_VIEWPORT = Vector2i(1080, 1920)
const EXPECTED_DESKTOP_WINDOW = Vector2i(540, 960)

var failures := 0
var checks := 0


func _ready() -> void:
	var viewport_size := Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
	)
	var desktop_window_size := Vector2i(
		int(ProjectSettings.get_setting("display/window/size/window_width_override", 0)),
		int(ProjectSettings.get_setting("display/window/size/window_height_override", 0))
	)
	_expect_vector_equal(viewport_size, EXPECTED_VIEWPORT, "formal portrait viewport")
	_expect_vector_equal(desktop_window_size, EXPECTED_DESKTOP_WINDOW, "desktop preview window override")
	_expect_true(desktop_window_size.x * EXPECTED_VIEWPORT.y == desktop_window_size.y * EXPECTED_VIEWPORT.x, "desktop preview preserves the 9:16 aspect ratio")
	_expect_true(desktop_window_size.x < viewport_size.x and desktop_window_size.y < viewport_size.y, "desktop preview is smaller than the formal viewport")
	_expect_equal(viewport_size.x / desktop_window_size.x, 2, "desktop preview width uses 50 percent scale")
	_expect_equal(viewport_size.y / desktop_window_size.y, 2, "desktop preview height uses 50 percent scale")
	_expect_string(str(ProjectSettings.get_setting("display/window/stretch/mode", "")), "canvas_items", "stretch mode remains canvas_items")
	_expect_string(str(ProjectSettings.get_setting("display/window/stretch/aspect", "")), "expand", "stretch aspect remains expand")
	_expect_equal(int(ProjectSettings.get_setting("display/window/handheld/orientation", 0)), 1, "Android orientation remains fixed portrait")
	if failures == 0:
		print("DESKTOP_WINDOW_FIT_TEST_PASS checks=%d viewport=%s window=%s" % [checks, str(viewport_size), str(desktop_window_size)])
	else:
		push_error("Desktop window fit test failed with %d error(s)." % failures)
	get_tree().quit(failures)


func _expect_vector_equal(actual: Vector2i, expected: Vector2i, label: String) -> void:
	checks += 1
	if actual == expected:
		return
	_fail("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _expect_equal(actual: int, expected: int, label: String) -> void:
	checks += 1
	if actual == expected:
		return
	_fail("%s: expected %d, got %d" % [label, expected, actual])


func _expect_string(actual: String, expected: String, label: String) -> void:
	checks += 1
	if actual == expected:
		return
	_fail("%s: expected %s, got %s" % [label, expected, actual])


func _expect_true(value: bool, label: String) -> void:
	checks += 1
	if value:
		return
	_fail("%s: expected true" % label)


func _fail(message: String) -> void:
	failures += 1
	push_error(message)
