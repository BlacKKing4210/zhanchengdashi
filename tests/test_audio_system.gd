extends Node

const MainApp = preload("res://scripts/app/main.gd")

var failures = 0
var audio: Node
var app: Node


func _ready() -> void:
	audio = get_node_or_null("/root/GameAudio")
	_expect_true(audio != null, "GameAudio autoload exists")
	if audio == null:
		get_tree().quit(failures)
		return
	_test_resource_maps_and_loading()
	_test_audio_buses_and_players()
	_test_music_state_and_runtime_loop()
	_test_sfx_cooldown_and_switches()
	_test_main_flow_integration()
	if failures == 0:
		print("Game audio system tests passed.")
	if is_instance_valid(app):
		app.queue_free()
	get_tree().quit(failures)


func _test_resource_maps_and_loading() -> void:
	var music_paths: Dictionary = audio.call("get_music_paths")
	var sfx_paths: Dictionary = audio.call("get_sfx_paths")
	_expect_equal(music_paths.size(), 2, "music map contains the menu and battle loops")
	for required_music_id in ["menu", "battle"]:
		_expect_true(music_paths.has(required_music_id), "music map contains %s" % required_music_id)
	for required_sfx_id in [
		"ui_click",
		"ui_confirm",
		"ui_error",
		"battle_start",
		"unit_spawn",
		"unit_attack",
		"ranged_attack",
		"tower_attack",
		"unit_hit",
		"shield_hit",
		"unit_death",
		"building_break",
		"territory_capture",
		"stat_gain",
		"power_up",
		"victory",
		"draw",
		"defeat",
	]:
		_expect_true(sfx_paths.has(required_sfx_id), "SFX map contains %s" % required_sfx_id)
	for music_id in music_paths:
		_expect_audio_resource(String(music_paths[music_id]), "music %s" % music_id)
	for event_id in sfx_paths:
		_expect_audio_resource(String(sfx_paths[event_id]), "SFX %s" % event_id)


func _test_audio_buses_and_players() -> void:
	for bus_name in ["Music", "SFX", "UI"]:
		_expect_true(AudioServer.get_bus_index(bus_name) >= 0, "%s audio bus exists" % bus_name)
	_expect_equal(int(audio.call("get_music_player_count")), 2, "music uses two players for crossfades")
	_expect_equal(int(audio.call("get_sfx_player_count")), 12, "SFX pool contains twelve players")
	_expect_equal(int(audio.call("get_priority_sfx_player_count")), 2, "two SFX players are reserved for UI and results")
	var default_mix: Dictionary = audio.call("get_default_mix_db")
	_expect_equal(float(default_mix.get("music", 0.0)), -12.0, "music default is softened by two decibels")
	_expect_equal(float(default_mix.get("sfx", 0.0)), -10.0, "battle SFX default is reduced by six decibels")
	_expect_equal(float(default_mix.get("ui", 0.0)), -6.0, "UI feedback keeps its separate readable level")
	for event_id in ["unit_attack", "ranged_attack", "tower_attack", "unit_hit"]:
		_expect_true(float(audio.call("get_event_cooldown", event_id)) >= 0.08, "%s is density-limited for crowded battles" % event_id)

	var master_index = AudioServer.get_bus_index("Master")
	_expect_true(master_index >= 0, "Master audio bus exists")
	var has_limiter = false
	if master_index >= 0:
		for effect_index in range(AudioServer.get_bus_effect_count(master_index)):
			if AudioServer.get_bus_effect(master_index, effect_index) is AudioEffectLimiter:
				has_limiter = true
				break
	_expect_true(has_limiter, "Master bus has a limiter for peak protection")


func _test_music_state_and_runtime_loop() -> void:
	audio.call("set_music_enabled", true)
	audio.call("play_music", "menu", 0.0)
	_expect_equal(String(audio.get("active_music_id")), "menu", "menu music is active")
	var menu_switch_count = int(audio.get("music_switch_count"))
	_expect_true(bool(audio.call("play_menu_music")), "requesting active menu music succeeds")
	_expect_equal(int(audio.get("music_switch_count")), menu_switch_count, "repeated menu request does not restart music")

	_expect_true(bool(audio.call("play_battle_music")), "battle music request succeeds")
	_expect_equal(String(audio.get("active_music_id")), "battle", "battle music becomes active")
	_expect_equal(int(audio.get("music_switch_count")), menu_switch_count + 1, "menu-to-battle switches once")
	_test_active_wav_loop("battle")
	var battle_switch_count = int(audio.get("music_switch_count"))
	_expect_true(bool(audio.call("play_battle_music")), "repeated battle music request succeeds")
	_expect_equal(int(audio.get("music_switch_count")), battle_switch_count, "repeated battle request does not restart music")

	_expect_true(bool(audio.call("play_menu_music")), "returning to menu music succeeds")
	_expect_equal(String(audio.get("active_music_id")), "menu", "menu music resumes")
	_expect_equal(int(audio.get("music_switch_count")), battle_switch_count + 1, "battle-to-menu switches once")
	_test_active_wav_loop("menu")


func _test_sfx_cooldown_and_switches() -> void:
	audio.call("set_sfx_enabled", true)
	audio.call("clear_event_cooldowns")
	var count_before = int(audio.call("get_sfx_play_count", "unit_hit"))
	_expect_true(bool(audio.call("play_sfx", "unit_hit")), "first hit sound plays")
	_expect_false(bool(audio.call("play_sfx", "unit_hit")), "immediate duplicate hit sound is cooled down")
	_expect_equal(int(audio.call("get_sfx_play_count", "unit_hit")), count_before + 1, "cooldown counts only the first hit")
	_expect_true(bool(audio.call("play_sfx", "unit_hit", 0.0, 1.0, true)), "forced hit sound bypasses cooldown")
	_expect_equal(int(audio.call("get_sfx_play_count", "unit_hit")), count_before + 2, "forced hit increments play count")

	audio.call("set_sfx_enabled", false)
	var disabled_count = int(audio.call("get_sfx_play_count", "ui_click"))
	_expect_false(bool(audio.call("play_sfx", "ui_click", 0.0, 1.0, true)), "disabled SFX rejects playback")
	_expect_equal(int(audio.call("get_sfx_play_count", "ui_click")), disabled_count, "disabled SFX does not increment play count")
	audio.call("set_sfx_enabled", true)
	_expect_true(bool(audio.call("play_sfx", "ui_click", 0.0, 1.0, true)), "re-enabled SFX plays")

	audio.call("set_music_enabled", false)
	_expect_equal(String(audio.get("active_music_id")), "", "disabling music stops the active track")
	_expect_false(bool(audio.call("play_music", "battle", 0.0)), "disabled music rejects playback")
	audio.call("set_music_enabled", true)
	_expect_equal(String(audio.get("active_music_id")), "battle", "re-enabling music resumes the last requested track")
	audio.call("play_menu_music")


func _test_main_flow_integration() -> void:
	audio.call("set_music_enabled", true)
	audio.call("set_sfx_enabled", true)
	audio.call("play_menu_music")
	audio.call("clear_event_cooldowns")
	app = MainApp.new()
	add_child(app)

	app.call("_start_match")
	_expect_equal(String(audio.get("active_music_id")), "battle", "starting a main battle switches to battle music")
	_expect_equal(String(audio.get("last_sfx_id")), "battle_start", "starting a main battle plays its stinger")

	audio.call("set_paused_mix", true)
	audio.call("clear_event_cooldowns")
	app.call("_restart_battle")
	_expect_false(bool(app.get("pause_open")), "R restart clears pause state")
	_expect_equal(String(audio.get("active_music_id")), "battle", "R restart keeps battle music active")
	_expect_equal(String(audio.get("last_sfx_id")), "battle_start", "R restart restores battle mix and plays the start stinger")

	audio.call("clear_event_cooldowns")
	var victory_count = int(audio.call("get_sfx_play_count", "victory"))
	app.call("_finish_battle", "胜利")
	_expect_equal(String(audio.get("last_sfx_id")), "victory", "winning a main battle plays the victory result")
	_expect_equal(int(audio.call("get_sfx_play_count", "victory")), victory_count + 1, "victory result plays once")
	app.call("_finish_battle", "失败")
	_expect_equal(int(audio.call("get_sfx_play_count", "victory")), victory_count + 1, "duplicate battle finish does not replay the result")

	app.call("_return_to_lobby")
	_expect_equal(String(audio.get("active_music_id")), "menu", "returning through main flow restores menu music")


func _test_active_wav_loop(label: String) -> void:
	var stream = audio.call("get_active_music_stream")
	_expect_true(stream is AudioStreamWAV, "%s runtime music stream is WAV" % label)
	if not stream is AudioStreamWAV:
		return
	var wav = stream as AudioStreamWAV
	_expect_equal(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s runtime WAV loops forward" % label)
	_expect_equal(wav.loop_begin, 0, "%s runtime WAV loop begins at sample zero" % label)
	var expected_loop_end = maxi(1, roundi(wav.get_length() * float(wav.mix_rate)))
	_expect_equal(wav.loop_end, expected_loop_end, "%s runtime WAV loop ends at the final sample" % label)


func _expect_audio_resource(path: String, label: String) -> void:
	_expect_true(path.begins_with("res://assets/audio/"), "%s stays in the exported audio tree" % label)
	_expect_false(path.begins_with("res://tmp/"), "%s is not stored under tmp" % label)
	_expect_true(ResourceLoader.exists(path), "%s resource exists at %s" % [label, path])
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	_expect_true(stream is AudioStream, "%s loads as AudioStream" % label)
	if stream is AudioStream:
		_expect_true((stream as AudioStream).get_length() > 0.0, "%s has nonzero duration" % label)


func _expect_true(value: bool, label: String) -> void:
	if value:
		return
	failures += 1
	push_error("%s: expected true" % label)


func _expect_false(value: bool, label: String) -> void:
	if not value:
		return
	failures += 1
	push_error("%s: expected false" % label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])
