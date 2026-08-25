extends Node

const PORTRAIT_DEFAULT = Vector2i(720, 1280)
const LANDSCAPE_DEFAULT = Vector2i(1280, 720)

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
	_expect_vector_equal(viewport_size, PORTRAIT_DEFAULT, "portrait viewport default")
	_expect_vector_equal(desktop_window_size, PORTRAIT_DEFAULT, "desktop window uses the portrait default")
	_expect_true(PORTRAIT_DEFAULT.x * 16 == PORTRAIT_DEFAULT.y * 9, "portrait default preserves the 9:16 aspect ratio")
	_expect_true(LANDSCAPE_DEFAULT.x * 9 == LANDSCAPE_DEFAULT.y * 16, "landscape default preserves the 16:9 aspect ratio")
	_expect_true(PORTRAIT_DEFAULT.x == LANDSCAPE_DEFAULT.y and PORTRAIT_DEFAULT.y == LANDSCAPE_DEFAULT.x, "portrait and landscape defaults are transposed")
	_expect_true(desktop_window_size == viewport_size, "desktop window renders the default viewport at 100 percent scale")
	_expect_string(str(ProjectSettings.get_setting("display/window/stretch/mode", "")), "canvas_items", "stretch mode remains canvas_items")
	_expect_string(str(ProjectSettings.get_setting("display/window/stretch/aspect", "")), "expand", "stretch aspect remains expand")
	_expect_equal(int(ProjectSettings.get_setting("display/window/handheld/orientation", 0)), 1, "Android orientation remains fixed portrait")
	if failures == 0:
		print("RESOLUTION_STANDARD_TEST_PASS checks=%d portrait=%s landscape=%s window=%s" % [checks, str(PORTRAIT_DEFAULT), str(LANDSCAPE_DEFAULT), str(desktop_window_size)])
	else:
		push_error("Resolution standard test failed with %d error(s)." % failures)
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
