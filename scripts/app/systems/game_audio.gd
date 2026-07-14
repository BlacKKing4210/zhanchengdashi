extends Node

const MUSIC_PATHS = {
	"menu": "res://assets/audio/music/menu_happy_loop.wav",
	"battle": "res://assets/audio/music/battle_happy_drive_loop.wav",
}

const SFX_PATHS = {
	"ui_click": "res://assets/audio/sfx/ui_click.wav",
	"ui_confirm": "res://assets/audio/sfx/ui_confirm.wav",
	"ui_error": "res://assets/audio/sfx/ui_error.wav",
	"card_select": "res://assets/audio/sfx/card_select.wav",
	"card_upgrade": "res://assets/audio/sfx/card_upgrade.wav",
	"gacha_open": "res://assets/audio/sfx/gacha_open.wav",
	"gacha_reveal": "res://assets/audio/sfx/gacha_reveal.wav",
	"room_join": "res://assets/audio/sfx/room_join.wav",
	"pause": "res://assets/audio/sfx/pause.wav",
	"battle_start": "res://assets/audio/sfx/battle_start.wav",
	"unit_spawn": "res://assets/audio/sfx/unit_spawn.wav",
	"unit_attack": "res://assets/audio/sfx/unit_attack.wav",
	"ranged_attack": "res://assets/audio/sfx/ranged_attack.wav",
	"tower_attack": "res://assets/audio/sfx/tower_attack.wav",
	"unit_hit": "res://assets/audio/sfx/unit_hit.wav",
	"shield_hit": "res://assets/audio/sfx/shield_hit.wav",
	"unit_death": "res://assets/audio/sfx/unit_death.wav",
	"building_break": "res://assets/audio/sfx/building_break.wav",
	"territory_capture": "res://assets/audio/sfx/territory_capture.wav",
	"unlock": "res://assets/audio/sfx/unlock.wav",
	"stat_gain": "res://assets/audio/sfx/stat_gain.wav",
	"power_up": "res://assets/audio/sfx/power_up.wav",
	"victory": "res://assets/audio/sfx/victory.wav",
	"draw": "res://assets/audio/sfx/draw.wav",
	"defeat": "res://assets/audio/sfx/defeat.wav",
}

const UI_EVENTS = {
	"ui_click": true,
	"ui_confirm": true,
	"ui_error": true,
	"card_select": true,
	"card_upgrade": true,
	"gacha_open": true,
	"gacha_reveal": true,
	"room_join": true,
	"pause": true,
}

const PRIORITY_EVENTS = {
	"battle_start": true,
	"unlock": true,
	"victory": true,
	"draw": true,
	"defeat": true,
}

const EVENT_COOLDOWNS = {
	"ui_click": 0.04,
	"ui_confirm": 0.04,
	"ui_error": 0.08,
	"card_select": 0.05,
	"card_upgrade": 0.20,
	"gacha_open": 0.25,
	"gacha_reveal": 0.08,
	"room_join": 0.12,
	"pause": 0.10,
	"battle_start": 0.30,
	"unit_spawn": 0.14,
	"unit_attack": 0.09,
	"ranged_attack": 0.09,
	"tower_attack": 0.11,
	"unit_hit": 0.08,
	"shield_hit": 0.10,
	"unit_death": 0.12,
	"building_break": 0.16,
	"territory_capture": 0.22,
	"unlock": 0.18,
	"stat_gain": 0.12,
	"power_up": 0.18,
}

const PITCH_VARIATION = {
	"unit_spawn": Vector2(0.97, 1.04),
	"unit_attack": Vector2(0.95, 1.05),
	"ranged_attack": Vector2(0.97, 1.04),
	"tower_attack": Vector2(0.96, 1.03),
	"unit_hit": Vector2(0.95, 1.05),
	"shield_hit": Vector2(0.98, 1.03),
	"unit_death": Vector2(0.96, 1.04),
	"building_break": Vector2(0.96, 1.02),
	"territory_capture": Vector2(0.98, 1.03),
	"stat_gain": Vector2(0.98, 1.03),
}

const MUSIC_BUS = "Music"
const SFX_BUS = "SFX"
const UI_BUS = "UI"
const SFX_POOL_SIZE = 12
const PRIORITY_SFX_SLOTS = 2
const MUSIC_SILENCE_DB = -60.0
const MENU_FADE_SECONDS = 1.0
const BATTLE_FADE_SECONDS = 0.8
const MUSIC_DEFAULT_DB = -12.0
const SFX_DEFAULT_DB = -10.0
const UI_DEFAULT_DB = -6.0

var music_enabled = true
var sfx_enabled = true
var active_music_id = ""
var requested_music_id = "menu"
var last_sfx_id = ""
var music_switch_count = 0

var _music_players: Array[AudioStreamPlayer] = []
var _sfx_players: Array[AudioStreamPlayer] = []
var _stream_cache = {}
var _event_cooldowns = {}
var _warned_missing = {}
var _sfx_play_counts = {}
var _sfx_started_by_instance = {}
var _active_music_slot = 0
var _sfx_play_serial = 0
var _music_volume_db = MUSIC_DEFAULT_DB
var _sfx_volume_db = SFX_DEFAULT_DB
var _ui_volume_db = UI_DEFAULT_DB
var _duck_db = 0.0
var _music_tween: Tween
var _duck_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_master_limiter()
	_ensure_bus(MUSIC_BUS, _music_volume_db)
	_ensure_bus(SFX_BUS, _sfx_volume_db)
	_ensure_bus(UI_BUS, _ui_volume_db)
	_build_players()
	play_music("menu", 0.0)


func _process(delta: float) -> void:
	for event_id in _event_cooldowns.keys():
		var remaining = maxf(0.0, float(_event_cooldowns[event_id]) - delta)
		if remaining <= 0.0:
			_event_cooldowns.erase(event_id)
		else:
			_event_cooldowns[event_id] = remaining


func play_menu_music() -> bool:
	set_music_duck(0.0, 0.18)
	return play_music("menu", MENU_FADE_SECONDS)


func play_battle_music() -> bool:
	set_music_duck(0.0, 0.18)
	var changed = play_music("battle", BATTLE_FADE_SECONDS)
	play_sfx("battle_start", 0.0, -1.0, true)
	return changed


func play_result(outcome: String) -> bool:
	set_music_duck(-8.0, 0.22)
	var event_id = outcome if outcome in ["victory", "draw", "defeat"] else "draw"
	return play_sfx(event_id, 1.5, 1.0, true)


func set_paused_mix(paused: bool) -> void:
	set_music_duck(-6.0 if paused else 0.0, 0.15)
	play_sfx("pause", -1.0)


func play_music(music_id: String, fade_seconds: float = 0.8) -> bool:
	if not MUSIC_PATHS.has(music_id):
		_warn_missing_once("music:" + music_id)
		return false
	requested_music_id = music_id
	if not music_enabled:
		return false
	if active_music_id == music_id and not _music_players.is_empty() and _music_players[_active_music_slot].playing:
		return true
	var stream = _music_stream(music_id)
	if stream == null:
		return false
	var next_slot = 0 if active_music_id == "" else 1 - _active_music_slot
	var next_player = _music_players[next_slot]
	var previous_player = _music_players[_active_music_slot]
	next_player.stop()
	next_player.stream = stream
	next_player.pitch_scale = 1.0
	next_player.volume_db = MUSIC_SILENCE_DB if fade_seconds > 0.0 else 0.0
	next_player.play()
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	if fade_seconds <= 0.0 or active_music_id == "":
		if previous_player != next_player:
			previous_player.stop()
		next_player.volume_db = 0.0
	else:
		_music_tween = create_tween()
		_music_tween.set_parallel(true)
		_music_tween.tween_property(next_player, "volume_db", 0.0, fade_seconds)
		_music_tween.tween_property(previous_player, "volume_db", MUSIC_SILENCE_DB, fade_seconds)
		_music_tween.chain().tween_callback(Callable(previous_player, "stop"))
	_active_music_slot = next_slot
	active_music_id = music_id
	music_switch_count += 1
	return true


func play_sfx(event_id: String, volume_offset_db: float = 0.0, pitch_override: float = -1.0, force: bool = false) -> bool:
	if not sfx_enabled:
		return false
	if not SFX_PATHS.has(event_id):
		_warn_missing_once("sfx:" + event_id)
		return false
	if not force and float(_event_cooldowns.get(event_id, 0.0)) > 0.0:
		return false
	var stream = _load_stream(String(SFX_PATHS[event_id]))
	if stream == null:
		return false
	var player = _next_sfx_player(UI_EVENTS.has(event_id) or PRIORITY_EVENTS.has(event_id))
	player.stop()
	player.stream = stream
	player.bus = UI_BUS if UI_EVENTS.has(event_id) else SFX_BUS
	player.volume_db = volume_offset_db
	if pitch_override > 0.0:
		player.pitch_scale = pitch_override
	elif PITCH_VARIATION.has(event_id):
		var pitch_range = Vector2(PITCH_VARIATION[event_id])
		player.pitch_scale = randf_range(pitch_range.x, pitch_range.y)
	else:
		player.pitch_scale = 1.0
	player.play()
	_sfx_play_serial += 1
	_sfx_started_by_instance[player.get_instance_id()] = _sfx_play_serial
	_event_cooldowns[event_id] = float(EVENT_COOLDOWNS.get(event_id, 0.02))
	last_sfx_id = event_id
	_sfx_play_counts[event_id] = int(_sfx_play_counts.get(event_id, 0)) + 1
	return true


func set_music_enabled(enabled: bool) -> void:
	if music_enabled == enabled:
		return
	music_enabled = enabled
	if not enabled:
		if _music_tween != null and _music_tween.is_valid():
			_music_tween.kill()
		_music_tween = null
		for player in _music_players:
			player.stop()
		active_music_id = ""
	else:
		play_music(requested_music_id, 0.0)


func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	if not enabled:
		for player in _sfx_players:
			player.stop()


func set_music_volume_db(value: float) -> void:
	_music_volume_db = clampf(value, -40.0, 6.0)
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = null
	_apply_music_bus_volume()


func set_sfx_volume_db(value: float) -> void:
	_sfx_volume_db = clampf(value, -40.0, 6.0)
	var bus_index = AudioServer.get_bus_index(SFX_BUS)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, _sfx_volume_db)


func set_ui_volume_db(value: float) -> void:
	_ui_volume_db = clampf(value, -40.0, 6.0)
	var bus_index = AudioServer.get_bus_index(UI_BUS)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, _ui_volume_db)


func set_music_duck(duck_db: float, seconds: float = 0.15) -> void:
	_duck_db = clampf(duck_db, -18.0, 0.0)
	var bus_index = AudioServer.get_bus_index(MUSIC_BUS)
	if bus_index < 0:
		return
	var target = _music_volume_db + _duck_db
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	if seconds <= 0.0:
		AudioServer.set_bus_volume_db(bus_index, target)
		return
	var start = AudioServer.get_bus_volume_db(bus_index)
	_duck_tween = create_tween()
	_duck_tween.tween_method(func(value: float): AudioServer.set_bus_volume_db(bus_index, value), start, target, seconds)


func get_music_paths() -> Dictionary:
	return MUSIC_PATHS.duplicate()


func get_sfx_paths() -> Dictionary:
	return SFX_PATHS.duplicate()


func get_music_player_count() -> int:
	return _music_players.size()


func get_sfx_player_count() -> int:
	return _sfx_players.size()


func get_priority_sfx_player_count() -> int:
	return PRIORITY_SFX_SLOTS


func get_default_mix_db() -> Dictionary:
	return {
		"music": MUSIC_DEFAULT_DB,
		"sfx": SFX_DEFAULT_DB,
		"ui": UI_DEFAULT_DB,
	}


func get_event_cooldown(event_id: String) -> float:
	return float(EVENT_COOLDOWNS.get(event_id, 0.0))


func get_sfx_play_count(event_id: String) -> int:
	return int(_sfx_play_counts.get(event_id, 0))


func get_active_music_stream() -> AudioStream:
	if _music_players.is_empty():
		return null
	return _music_players[_active_music_slot].stream


func clear_event_cooldowns() -> void:
	_event_cooldowns.clear()


func _build_players() -> void:
	for index in range(2):
		var music_player = AudioStreamPlayer.new()
		music_player.name = "Music%d" % index
		music_player.bus = MUSIC_BUS
		add_child(music_player)
		_music_players.append(music_player)
	for index in range(SFX_POOL_SIZE):
		var sfx_player = AudioStreamPlayer.new()
		sfx_player.name = "SFX%02d" % index
		sfx_player.bus = SFX_BUS
		add_child(sfx_player)
		_sfx_players.append(sfx_player)


func _next_sfx_player(priority: bool) -> AudioStreamPlayer:
	var normal_end = _sfx_players.size() - PRIORITY_SFX_SLOTS
	var start_index = normal_end if priority else 0
	var end_index = _sfx_players.size() if priority else normal_end
	for index in range(start_index, end_index):
		var available = _sfx_players[index]
		if not available.playing:
			return available
	var oldest = _sfx_players[start_index]
	var oldest_serial = int(_sfx_started_by_instance.get(oldest.get_instance_id(), -1))
	for index in range(start_index + 1, end_index):
		var candidate = _sfx_players[index]
		var candidate_serial = int(_sfx_started_by_instance.get(candidate.get_instance_id(), -1))
		if candidate_serial < oldest_serial:
			oldest = candidate
			oldest_serial = candidate_serial
	return oldest


func _music_stream(music_id: String) -> AudioStream:
	var source = _load_stream(String(MUSIC_PATHS[music_id]))
	if source == null:
		return null
	var stream = source.duplicate(true)
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = maxi(1, roundi(stream.get_length() * float(stream.mix_rate)))
	return stream


func _load_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	if not ResourceLoader.exists(path):
		_warn_missing_once(path)
		return null
	var stream = load(path) as AudioStream
	if stream == null:
		_warn_missing_once(path)
		return null
	_stream_cache[path] = stream
	return stream


func _ensure_bus(bus_name: String, volume_db: float) -> void:
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, bus_name)
		AudioServer.set_bus_send(bus_index, "Master")
	AudioServer.set_bus_volume_db(bus_index, volume_db)


func _ensure_master_limiter() -> void:
	var master_index = AudioServer.get_bus_index("Master")
	if master_index < 0:
		return
	for effect_index in range(AudioServer.get_bus_effect_count(master_index)):
		if AudioServer.get_bus_effect(master_index, effect_index) is AudioEffectLimiter:
			return
	var limiter = AudioEffectLimiter.new()
	limiter.threshold_db = -3.0
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(master_index, limiter)


func _apply_music_bus_volume() -> void:
	var bus_index = AudioServer.get_bus_index(MUSIC_BUS)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, _music_volume_db + _duck_db)


func _warn_missing_once(key: String) -> void:
	if _warned_missing.has(key):
		return
	_warned_missing[key] = true
	push_warning("GameAudio missing or unknown audio resource: %s" % key)
