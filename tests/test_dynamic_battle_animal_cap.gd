extends Node

const MainApp = preload("res://scripts/app/main.gd")

var failures = 0
var app


func _ready() -> void:
	app = MainApp.new()
	add_child(app)
	_test_multiplayer_cap_formula()
	_test_elimination_expands_remaining_capacity()
	_test_classic_cap_formula()
	if failures == 0:
		print("Dynamic battle animal-cap tests passed.")
	app.queue_free()
	get_tree().quit(failures)


func _test_multiplayer_cap_formula() -> void:
	_set_living_multiplayer_teams([1, 2, 3, 4, 5, 6])
	_expect_equal(int(app.call("_animal_cap_per_living_faction")), 12, "six living factions cap each faction at 12 animals")

	_set_living_multiplayer_teams([1, 2, 3, 4, 5])
	_expect_equal(int(app.call("_animal_cap_per_living_faction")), 14, "five living factions cap each faction at floor(72/5)")

	_set_living_multiplayer_teams([1, 2, 3, 4])
	_expect_equal(int(app.call("_animal_cap_per_living_faction")), 18, "four living factions cap each faction at 18 animals")

	_set_living_multiplayer_teams([1, 2, 3])
	_expect_equal(int(app.call("_animal_cap_per_living_faction")), 24, "three living factions cap each faction at 24 animals")

	_set_living_multiplayer_teams([1, 2])
	_expect_equal(int(app.call("_animal_cap_per_living_faction")), 36, "two living factions cap each faction at 36 animals")

	_set_living_multiplayer_teams([1])
	_expect_equal(int(app.call("_animal_cap_per_living_faction")), 72, "one living faction caps itself at the total 72-animal budget")


func _test_elimination_expands_remaining_capacity() -> void:
	_set_living_multiplayer_teams([1, 2, 3, 4, 5, 6])
	app.set("units", _alive_units(1, 12))
	_expect_true(not bool(app.call("_can_spawn_multiplayer_unit", 1)), "a faction at the six-player cap cannot spawn another animal")

	var alive: Dictionary = app.get("multiplayer_alive")
	alive[6] = false
	app.set("multiplayer_alive", alive)
	_expect_equal(int(app.call("_animal_cap_per_living_faction")), 14, "eliminating one faction raises the remaining cap to 14")
	_expect_true(bool(app.call("_can_spawn_multiplayer_unit", 1)), "the raised cap immediately frees two animal slots")


func _test_classic_cap_formula() -> void:
	app.set("battle_mode", MainApp.BATTLE_MODE_CLASSIC)
	app.set("units", _alive_units(1, 36))
	_expect_equal(int(app.call("_animal_cap_per_living_faction")), 36, "classic two-faction battles use a 36-animal cap per faction")
	_expect_true(not bool(app.call("_can_spawn_multiplayer_unit", 1)), "classic camps respect the two-faction animal cap")


func _set_living_multiplayer_teams(teams: Array) -> void:
	var alive = {}
	for team in teams:
		alive[int(team)] = true
	app.set("battle_mode", MainApp.BATTLE_MODE_MULTIPLAYER)
	app.set("room_active_team_ids", teams.duplicate())
	app.set("multiplayer_alive", alive)
	app.set("units", [])


func _alive_units(team: int, count: int) -> Array:
	var result = []
	for index in range(count):
		result.append({"id": index + 1, "team": team, "hp": 1.0})
	return result


func _expect_true(value: bool, label: String) -> void:
	if value:
		return
	failures += 1
	push_error("%s: expected true" % label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])
