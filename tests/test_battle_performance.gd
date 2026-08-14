extends Node

const MainApp = preload("res://scripts/app/main.gd")
const BoardRules = preload("res://scripts/app/systems/board_rules.gd")

const UNIT_COUNT = 72
const WARMUP_STEPS = 80
const SAMPLE_STEPS = 400
const STEP = 1.0 / 60.0
const P95_LIMIT_US = 4000

var failures = 0
var app: Node


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	await get_tree().process_frame
	await get_tree().process_frame
	app.set_process(false)
	app.set("battle_mode", "classic")
	app.set("screen", "battle")
	app.call("_reset_battle")
	_setup_units()
	_test_unit_index_cache_safety()
	app.call("_reset_battle")
	_setup_units()
	_run_benchmark()
	app.queue_free()
	await get_tree().process_frame
	get_tree().quit(failures)


func _test_unit_index_cache_safety() -> void:
	var units: Array = app.get("units")
	_expect_equal(units.size(), UNIT_COUNT, "benchmark unit setup")
	app.call("_refresh_unit_index_cache")
	var target_id = int(units[10].get("id", -1))
	_expect_equal(int(app.call("_unit_index_by_id", target_id)), 10, "cached lookup")
	units.remove_at(0)
	app.set("units", units)
	_expect_equal(int(app.call("_unit_index_by_id", target_id)), 9, "stale cache falls back after compaction")
	var appended: Dictionary = units[0].duplicate(true)
	appended["id"] = 900001
	units.append(appended)
	app.set("units", units)
	_expect_equal(int(app.call("_unit_index_by_id", 900001)), units.size() - 1, "new unit falls back and enters cache")
	_expect_equal(int(app.call("_unit_index_by_id", -1)), -1, "invalid ID exits early")


func _run_benchmark() -> void:
	for _step_index in range(WARMUP_STEPS):
		app.call("_update_units", STEP)
	var samples: Array[int] = []
	for _step_index in range(SAMPLE_STEPS):
		var started = Time.get_ticks_usec()
		app.call("_update_units", STEP)
		samples.append(Time.get_ticks_usec() - started)
	samples.sort()
	var median_us = samples[samples.size() / 2]
	var p95_index = mini(samples.size() - 1, ceili(float(samples.size()) * 0.95) - 1)
	var p95_us = samples[p95_index]
	var mean_us = 0.0
	for sample in samples:
		mean_us += float(sample)
	mean_us /= float(samples.size())
	if p95_us > P95_LIMIT_US:
		_fail("72-unit p95 exceeds %d us: %d us" % [P95_LIMIT_US, p95_us])
	print("BATTLE_PERFORMANCE_TEST_%s %s" % [
		"PASS" if failures == 0 else "FAIL",
		JSON.stringify({
			"unit_count": UNIT_COUNT,
			"warmup_steps": WARMUP_STEPS,
			"sample_steps": SAMPLE_STEPS,
			"median_us": median_us,
			"p95_us": p95_us,
			"mean_us": snappedf(mean_us, 0.01),
			"p95_limit_us": P95_LIMIT_US,
		}),
	])


func _setup_units() -> void:
	var player_base: Vector2i = app.call("_battle_base_key", BoardRules.PLAYER)
	var enemy_base: Vector2i = app.call("_battle_base_key", BoardRules.ENEMY)
	for _index in range(UNIT_COUNT / 2):
		app.call("_spawn_unit", BoardRules.PLAYER, player_base, "rabbit", false, 0, {"skill_triggers_enabled": false})
		app.call("_spawn_unit", BoardRules.ENEMY, enemy_base, "rabbit", false, 0, {"skill_triggers_enabled": false})
	var units: Array = app.get("units")
	for index in range(units.size()):
		var unit: Dictionary = units[index]
		var opposing_index = index + 1 if index % 2 == 0 else index - 1
		var pair = index / 2
		var row = pair / 9
		var column = pair % 9
		unit["pos"] = Vector2(160.0 + float(column) * 32.0 + (8.0 if index % 2 == 1 else 0.0), 360.0 + float(row) * 34.0)
		unit["tile"] = player_base if index % 2 == 0 else enemy_base
		unit["cooldown"] = 9999.0
		unit["attack_target_kind"] = "unit"
		unit["attack_target_unit_id"] = int(units[opposing_index].get("id", -1))
		unit["attack_target_key"] = Vector2i(-999, -999)
		units[index] = unit
	app.set("units", units)
	app.set("effects", [])


func _expect_equal(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		return
	_fail("%s: expected %d, got %d" % [label, expected, actual])


func _fail(message: String) -> void:
	failures += 1
	push_error(message)
