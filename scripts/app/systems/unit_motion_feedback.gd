extends RefCounted

const KIND_ATTACK = "attack"
const KIND_HIT = "hit"
const KIND_STAT_GAIN = "stat_gain"
const KIND_POWER_UP = "power_up"
const KIND_DEATH = "unit_death_snapshot"

const MOVE_PERIOD = 0.32
const ATTACK_DURATION = 0.24
const HIT_DURATION = 0.16
const STAT_GAIN_DURATION = 0.36
const POWER_UP_DURATION = 0.55
const DEATH_DURATION = 0.42

const _DURATIONS = {
	KIND_ATTACK: ATTACK_DURATION,
	KIND_HIT: HIT_DURATION,
	KIND_STAT_GAIN: STAT_GAIN_DURATION,
	KIND_POWER_UP: POWER_UP_DURATION,
}

const _PRIORITIES = {
	KIND_STAT_GAIN: 2,
	KIND_POWER_UP: 3,
	KIND_ATTACK: 4,
	KIND_HIT: 5,
}


static func begin_frame(unit: Dictionary, delta: float) -> void:
	unit["motion_moving"] = false
	var time_left = maxf(0.0, float(unit.get("motion_time", 0.0)) - maxf(0.0, delta))
	unit["motion_time"] = time_left
	if time_left <= 0.0:
		_promote_pending(unit)


static func mark_moving(unit: Dictionary, direction: Vector2, delta: float) -> void:
	unit["motion_moving"] = true
	unit["motion_move_direction"] = _safe_direction(direction, Vector2.RIGHT)
	unit["motion_move_phase"] = fmod(float(unit.get("motion_move_phase", 0.0)) + maxf(0.0, delta) / MOVE_PERIOD, 1.0)


static func trigger(unit: Dictionary, kind: String, direction: Vector2 = Vector2.RIGHT) -> void:
	if not _DURATIONS.has(kind):
		return
	var safe_direction = _safe_direction(direction, _last_direction(unit))
	var current_kind = String(unit.get("motion_kind", ""))
	var current_time = float(unit.get("motion_time", 0.0))
	if current_kind == "" or current_time <= 0.0:
		_set_active(unit, kind, safe_direction)
		return
	if current_kind == kind:
		_set_active(unit, kind, safe_direction)
		return
	if _priority(kind) > _priority(current_kind):
		_set_active(unit, kind, safe_direction)
		return
	var pending_kind = String(unit.get("motion_pending_kind", ""))
	if pending_kind == kind or pending_kind == "" or _priority(kind) > _priority(pending_kind):
		unit["motion_pending_kind"] = kind
		unit["motion_pending_direction"] = safe_direction


static func pose(unit: Dictionary) -> Dictionary:
	var result = _default_pose()
	var kind = String(unit.get("motion_kind", ""))
	var time_left = float(unit.get("motion_time", 0.0))
	var duration = maxf(0.001, float(unit.get("motion_duration", 0.0)))
	if kind != "" and time_left > 0.0:
		var progress = clampf(1.0 - time_left / duration, 0.0, 1.0)
		var direction = _safe_direction(Vector2(unit.get("motion_direction", Vector2.RIGHT)), Vector2.RIGHT)
		match kind:
			KIND_ATTACK:
				return _attack_pose(progress, direction)
			KIND_HIT:
				return _hit_pose(progress, direction)
			KIND_STAT_GAIN:
				return _stat_gain_pose(progress)
			KIND_POWER_UP:
				return power_up_pose(progress)
	if bool(unit.get("motion_moving", false)):
		var phase = fmod(float(unit.get("motion_move_phase", 0.0)), 1.0)
		var move_direction = _safe_direction(Vector2(unit.get("motion_move_direction", Vector2.RIGHT)), Vector2.RIGHT)
		return _move_pose(phase, move_direction)
	return result


static func death_pose(effect: Dictionary) -> Dictionary:
	var duration = maxf(0.001, float(effect.get("duration", DEATH_DURATION)))
	var progress = clampf(1.0 - float(effect.get("time", duration)) / duration, 0.0, 1.0)
	var eased = _smoothstep(progress)
	var direction = _safe_direction(Vector2(effect.get("direction", Vector2.RIGHT)), Vector2.RIGHT)
	var fall_sign = signf(direction.x)
	if absf(fall_sign) < 0.5:
		fall_sign = 1.0 if direction.y >= 0.0 else -1.0
	var shrink_progress = pow(eased, 1.6)
	var shrink = lerpf(1.0, 0.06, shrink_progress)
	return {
		"offset": direction * (3.0 * eased) + Vector2(0.0, 8.0 * eased * eased),
		"scale": Vector2(shrink, shrink),
		"rotation": fall_sign * 0.52 * eased,
	}


static func power_up_pose(progress: float) -> Dictionary:
	var p = clampf(progress, 0.0, 1.0)
	var main_pop = sin(p * PI)
	var settle = sin(p * TAU) * 0.035
	var scale_value = 1.0 + main_pop * 0.18 + settle
	return {
		"offset": Vector2(0.0, -5.0 * main_pop),
		"scale": Vector2(scale_value, scale_value),
		"rotation": sin(p * TAU) * 0.05,
	}


static func current_kind(unit: Dictionary) -> String:
	return String(unit.get("motion_kind", "")) if float(unit.get("motion_time", 0.0)) > 0.0 else ""


static func _move_pose(phase: float, direction: Vector2) -> Dictionary:
	var cycle = phase * TAU
	var bounce = absf(sin(cycle))
	return {
		"offset": Vector2(0.0, -2.5 * bounce),
		"scale": Vector2(1.0 + 0.035 * bounce, 1.0 - 0.035 * bounce),
		"rotation": sin(cycle) * 0.045 * direction.x,
	}


static func _attack_pose(progress: float, direction: Vector2) -> Dictionary:
	var along = 0.0
	if progress < 0.25:
		along = lerpf(0.0, -2.5, _smoothstep(progress / 0.25))
	elif progress < 0.55:
		along = lerpf(-2.5, 9.0, _smoothstep((progress - 0.25) / 0.30))
	else:
		along = lerpf(9.0, 0.0, _smoothstep((progress - 0.55) / 0.45))
	var impulse = sin(progress * PI)
	return {
		"offset": direction * along,
		"scale": Vector2(1.0 + 0.12 * impulse, 1.0 - 0.08 * impulse),
		"rotation": direction.x * 0.065 * impulse,
	}


static func _hit_pose(progress: float, direction: Vector2) -> Dictionary:
	var impulse = sin(progress * PI)
	return {
		"offset": direction * (6.0 * impulse),
		"scale": Vector2(1.0 - 0.12 * impulse, 1.0 + 0.10 * impulse),
		"rotation": -direction.x * 0.09 * impulse,
	}


static func _stat_gain_pose(progress: float) -> Dictionary:
	var pop = sin(progress * PI)
	var scale_value = 1.0 + 0.10 * pop
	return {
		"offset": Vector2(0.0, -3.0 * pop),
		"scale": Vector2(scale_value, scale_value),
		"rotation": 0.0,
	}


static func _default_pose() -> Dictionary:
	return {
		"offset": Vector2.ZERO,
		"scale": Vector2.ONE,
		"rotation": 0.0,
	}


static func _set_active(unit: Dictionary, kind: String, direction: Vector2) -> void:
	unit["motion_kind"] = kind
	unit["motion_time"] = float(_DURATIONS[kind])
	unit["motion_duration"] = float(_DURATIONS[kind])
	unit["motion_direction"] = direction


static func _promote_pending(unit: Dictionary) -> void:
	var pending_kind = String(unit.get("motion_pending_kind", ""))
	if pending_kind != "" and _DURATIONS.has(pending_kind):
		var direction = _safe_direction(Vector2(unit.get("motion_pending_direction", Vector2.RIGHT)), _last_direction(unit))
		unit["motion_pending_kind"] = ""
		unit["motion_pending_direction"] = Vector2.RIGHT
		_set_active(unit, pending_kind, direction)
		return
	unit["motion_kind"] = ""
	unit["motion_time"] = 0.0
	unit["motion_duration"] = 0.0


static func _last_direction(unit: Dictionary) -> Vector2:
	var active = Vector2(unit.get("motion_direction", Vector2.ZERO))
	if active.length_squared() > 0.0001:
		return active.normalized()
	var moving = Vector2(unit.get("motion_move_direction", Vector2.ZERO))
	if moving.length_squared() > 0.0001:
		return moving.normalized()
	return Vector2.RIGHT


static func _safe_direction(direction: Vector2, fallback: Vector2) -> Vector2:
	if direction.length_squared() > 0.0001:
		return direction.normalized()
	if fallback.length_squared() > 0.0001:
		return fallback.normalized()
	return Vector2.RIGHT


static func _priority(kind: String) -> int:
	return int(_PRIORITIES.get(kind, 0))


static func _smoothstep(value: float) -> float:
	var t = clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
