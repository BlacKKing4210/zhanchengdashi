extends Node

const UnitMotionFeedback = preload("res://scripts/app/systems/unit_motion_feedback.gd")
const UnitSequenceAnimation = preload("res://scripts/app/systems/unit_sequence_animation.gd")

var failures = 0


func _ready() -> void:
	UnitSequenceAnimation.reset_for_tests()
	_test_manifest_and_registration()
	_test_idle_and_move_sampling()
	_test_attack_sampling_and_generic_hit_overlay()
	_test_missing_registration_uses_generic_fallback()
	_test_manifest_validation_fails_closed()
	if failures == 0:
		print("UNIT_SEQUENCE_ANIMATION_TEST_PASS")
	get_tree().quit(failures)


func _test_manifest_and_registration() -> void:
	var status = UnitSequenceAnimation.manifest_status()
	_expect_true(bool(status["valid"]), "shipped sequence manifest validates")
	_expect_equal(status["errors"], [], "shipped sequence manifest has no errors")
	_expect_equal(status["animal_ids"], ["fox"], "only the user-supplied fox sequence is registered")
	_expect_true(UnitSequenceAnimation.has_sequence("fox"), "fox uses the sequence registry")
	_expect_false(UnitSequenceAnimation.has_sequence("rabbit"), "unregistered rabbit remains on generic animation")


func _test_idle_and_move_sampling() -> void:
	var idle_unit = {"id": 0, "motion_time": 0.0, "motion_moving": false}
	var idle_before = idle_unit.duplicate(true)
	var idle_first = UnitSequenceAnimation.sample_for_unit("fox", idle_unit, 0.0)
	var idle_next = UnitSequenceAnimation.sample_for_unit("fox", idle_unit, 0.11)
	_expect_equal(String(idle_first.get("action", "")), "idle", "stationary fox selects idle sequence")
	_expect_equal(int(idle_first.get("frame_index", -1)), 0, "idle sequence starts at frame zero for seed zero")
	_expect_equal(int(idle_next.get("frame_index", -1)), 1, "idle sequence advances at configured 10 fps")
	_expect_true(idle_first.get("texture") is Texture2D, "idle sample loads a Texture2D")
	_expect_equal(idle_first.get("source_rect"), Rect2(230.0, 50.0, 410.0, 410.0), "fox sample uses audited square source region")
	_expect_close(float(idle_first.get("bottom_padding_ratio", -1.0)), 80.0 / 410.0, "fox sequence preserves audited foot alignment")
	_expect_equal(idle_unit, idle_before, "sampling does not mutate stationary unit state")

	var move_unit = {"id": 0, "motion_time": 0.0, "motion_moving": true}
	var move_first = UnitSequenceAnimation.sample_for_unit("fox", move_unit, 0.0)
	var move_next = UnitSequenceAnimation.sample_for_unit("fox", move_unit, 0.07)
	_expect_equal(String(move_first.get("action", "")), "move", "moving fox selects move sequence")
	_expect_equal(String(move_first.get("embedded_motion", "")), "move", "move frames replace duplicate generic bounce")
	_expect_equal(int(move_first.get("frame_index", -1)), 0, "move sequence begins at frame zero")
	_expect_equal(int(move_next.get("frame_index", -1)), 1, "move sequence advances at configured 15 fps")


func _test_attack_sampling_and_generic_hit_overlay() -> void:
	var attack_unit = {
		"id": 5,
		"motion_kind": UnitMotionFeedback.KIND_ATTACK,
		"motion_duration": UnitMotionFeedback.ATTACK_DURATION,
		"motion_time": UnitMotionFeedback.ATTACK_DURATION,
		"motion_moving": true,
	}
	var first = UnitSequenceAnimation.sample_for_unit("fox", attack_unit, 8.0)
	attack_unit["motion_time"] = UnitMotionFeedback.ATTACK_DURATION * 0.5
	var middle = UnitSequenceAnimation.sample_for_unit("fox", attack_unit, 8.0)
	attack_unit["motion_time"] = 0.00001
	var last = UnitSequenceAnimation.sample_for_unit("fox", attack_unit, 8.0)
	_expect_equal(String(first.get("action", "")), "attack", "active attack selects attack sequence")
	_expect_equal(String(first.get("embedded_motion", "")), "attack", "attack frames replace duplicate generic lunge")
	_expect_equal(int(first.get("frame_index", -1)), 0, "attack progress starts at the first frame")
	_expect_equal(int(middle.get("frame_index", -1)), 5, "attack midpoint samples the middle frame")
	_expect_equal(int(last.get("frame_index", -1)), 9, "attack completion clamps to the final frame")

	var hit_unit = {
		"id": 0,
		"motion_kind": UnitMotionFeedback.KIND_HIT,
		"motion_duration": UnitMotionFeedback.HIT_DURATION,
		"motion_time": UnitMotionFeedback.HIT_DURATION * 0.5,
		"motion_direction": Vector2.RIGHT,
		"motion_moving": true,
	}
	var hit_sample = UnitSequenceAnimation.sample_for_unit("fox", hit_unit, 0.0)
	var hit_pose = UnitMotionFeedback.pose(hit_unit)
	_expect_equal(String(hit_sample.get("action", "")), "idle", "hit keeps a valid sequence texture instead of flashing static art")
	_expect_equal(String(hit_sample.get("embedded_motion", "")), "", "hit retains generic procedural feedback")
	_expect_true(Vector2(hit_pose["offset"]).x > 0.0, "generic hit displacement remains available over the idle frame")


func _test_missing_registration_uses_generic_fallback() -> void:
	var rabbit = {
		"id": 4,
		"motion_kind": UnitMotionFeedback.KIND_ATTACK,
		"motion_duration": UnitMotionFeedback.ATTACK_DURATION,
		"motion_time": UnitMotionFeedback.ATTACK_DURATION * 0.5,
		"motion_direction": Vector2.RIGHT,
	}
	_expect_true(UnitSequenceAnimation.sample_for_unit("rabbit", rabbit, 1.0).is_empty(), "unregistered animal returns no sequence sample")
	_expect_true(Vector2(UnitMotionFeedback.pose(rabbit)["offset"]).x > 0.0, "unregistered animal keeps the previous generic attack motion")


func _test_manifest_validation_fails_closed() -> void:
	var raw_text = FileAccess.get_file_as_string(UnitSequenceAnimation.MANIFEST_PATH)
	var original = JSON.parse_string(raw_text)
	var unexpected = (original as Dictionary).duplicate(true)
	unexpected["unexpected_field"] = true
	var unexpected_result = UnitSequenceAnimation.validate_manifest_data(unexpected, false)
	_expect_false(bool(unexpected_result["valid"]), "unexpected manifest fields fail closed")
	_expect_true(_contains_error(unexpected_result["errors"], "unexpected_key:manifest:unexpected_field"), "unexpected-field error is explicit")

	var bad_path = (original as Dictionary).duplicate(true)
	bad_path["animals"]["fox"]["actions"]["idle"]["frames"][0] = "res://assets/card_art/animals/fox.png"
	var bad_path_result = UnitSequenceAnimation.validate_manifest_data(bad_path, false)
	_expect_false(bool(bad_path_result["valid"]), "frame outside the registered animal/action directory fails closed")
	_expect_true(_contains_error_prefix(bad_path_result["errors"], "frame_path_invalid:fox:idle:"), "bad path error identifies the animal and action")


func _contains_error(errors: Array, expected: String) -> bool:
	for value in errors:
		if String(value) == expected:
			return true
	return false


func _contains_error_prefix(errors: Array, prefix: String) -> bool:
	for value in errors:
		if String(value).begins_with(prefix):
			return true
	return false


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_fail(message)


func _expect_false(value: bool, message: String) -> void:
	if value:
		_fail(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_fail("%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])


func _expect_close(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_fail("%s (expected=%.6f actual=%.6f)" % [message, expected, actual])


func _fail(message: String) -> void:
	failures += 1
	push_error(message)
