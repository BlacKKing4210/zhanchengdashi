extends RefCounted

# Presentation only: source identity survives bounces and network snapshots.
# Geometry is the physical projectile body; never draw its travelled path.
const CARD_PROFILES = {
	"sparrow": {"shape": "seed", "tint": "c89d5d", "scale": 0.9},
	"frog": {"shape": "droplet", "tint": "7ca9aa", "scale": 1.0},
	"duck": {"shape": "droplet", "tint": "87b5c1", "scale": 1.0},
	"swan": {"shape": "droplet", "tint": "b3d4d2", "scale": 1.1},
	"parrot": {"shape": "feather", "tint": "92ad76", "scale": 1.0},
	"falcon": {"shape": "feather", "tint": "c0b099", "scale": 1.0},
	"crane": {"shape": "feather", "tint": "dfddd0", "scale": 1.0},
	"eagle": {"shape": "feather", "tint": "ad967d", "scale": 1.1},
	"golden_eagle": {"shape": "feather", "tint": "cdb477", "scale": 1.15},
	"fox": {"shape": "stone", "tint": "be9e7e", "scale": 1.0},
	"defense_watch_tower": {"shape": "bolt", "tint": "b8a383", "scale": 1.0},
	"defense_rapid_tower": {"shape": "bolt", "tint": "b8a383", "scale": 0.85},
	"defense_longshot_tower": {"shape": "bolt", "tint": "a0adb0", "scale": 1.15},
	"defense_territory_tower": {"shape": "bolt", "tint": "cab67d", "scale": 1.15},
	"defense_cannon_tower": {"shape": "iron", "tint": "7f8791", "scale": 1.1},
	"defense_bounty_tower": {"shape": "iron", "tint": "a49167", "scale": 1.1},
	"defense_plunder_tower": {"shape": "nut", "tint": "be8a4e", "scale": 1.0},
	"defense_repair_beacon": {"shape": "stone", "tint": "9ca18c", "scale": 1.15},
	"defense_twinshot_tower": {"shape": "feather", "tint": "92ad76", "scale": 1.0},
}
const DEFAULT_PROFILE = {"shape": "stone", "tint": "b8ab92", "scale": 1.0}
const INK = Color("403c36")

static func profile_for(source_card: String) -> Dictionary:
	return CARD_PROFILES.get(source_card, DEFAULT_PROFILE)

static func draw_body(canvas: CanvasItem, center: Vector2, direction: Vector2, profile: Dictionary, zoom: float, opacity: float = 1.0) -> void:
	var size = clampf(zoom, 0.85, 1.35) * float(profile.get("scale", 1.0))
	var forward = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	var normal = Vector2(-forward.y, forward.x)
	var tint = Color(String(profile.get("tint", "b8ab92")), opacity)
	var ink = Color(INK, opacity)
	var highlight = Color(tint.lightened(0.3), opacity)
	var shape = String(profile.get("shape", "stone"))
	match shape:
		"iron":
			canvas.draw_circle(center, 4.3 * size, ink)
			canvas.draw_circle(center, 3.2 * size, tint)
			canvas.draw_circle(center + Vector2(-1, -1) * size, 1.1 * size, highlight)
		"bolt":
			# Shaft and fletching are bounded parts of the arrow, not a motion streak.
			canvas.draw_line(center - forward * 4.5 * size, center + forward * 3 * size, ink, 2.6 * size, true)
			canvas.draw_line(center - forward * 4 * size, center + forward * 3 * size, Color("ac875c", opacity), 1.2 * size, true)
			_polygon(canvas, [Vector2(5, 0), Vector2(1.5, -2.4), Vector2(1.5, 2.4)], center, forward, normal, size, tint, ink)
			canvas.draw_line(center - forward * 2.5 * size, center + (-forward * 5 + normal * 2) * size, ink, 1.2 * size, true)
			canvas.draw_line(center - forward * 2.5 * size, center + (-forward * 5 - normal * 2) * size, ink, 1.2 * size, true)
		"feather":
			_polygon(canvas, [Vector2(-6, 0), Vector2(-2, -2.5), Vector2(2, -2.8), Vector2(6, 0), Vector2(1, 2.6), Vector2(-3, 2)], center, forward, normal, size, tint, ink)
			canvas.draw_line(center - forward * 5 * size, center + forward * 4 * size, Color(INK.lightened(0.25), opacity), size, true)
		"droplet":
			_polygon(canvas, [Vector2(-6, 0), Vector2(-2, -2.2), Vector2(1, -3.1), Vector2(3.5, -2), Vector2(4.3, 0), Vector2(3.5, 2), Vector2(1, 3.1), Vector2(-2, 2.2)], center, forward, normal, size, tint, ink)
			canvas.draw_circle(center + (-normal + forward) * size, size, highlight)
		"seed", "nut":
			_polygon(canvas, [Vector2(-4.5, 0), Vector2(-2.8, -2.8), Vector2(1, -3.2), Vector2(4, -1.5), Vector2(4.8, 0), Vector2(3, 2.6), Vector2(-1, 3.2), Vector2(-3.7, 2)], center, forward, normal, size, tint, ink)
			if shape == "nut":
				canvas.draw_line(center + (-forward * 2 - normal * 2.3) * size, center + (-forward * 2 + normal * 2.4) * size, Color("71533c", opacity), 2 * size, true)
			else:
				canvas.draw_line(center - forward * 1.5 * size, center + forward * 2.2 * size, highlight, 1.1 * size, true)
		_:
			_polygon(canvas, [Vector2(-4, -1.7), Vector2(-1, -3.5), Vector2(3, -2.5), Vector2(4.1, 1), Vector2(1.5, 3.5), Vector2(-2.8, 2.7)], center, forward, normal, size, tint, ink)
			canvas.draw_line(center + Vector2(-1.8, -1) * size, center + Vector2(0.7, -1.8) * size, highlight, 1.3 * size, true)

static func _polygon(canvas: CanvasItem, points: Array, center: Vector2, forward: Vector2, normal: Vector2, size: float, fill: Color, outline: Color) -> void:
	var vertices = PackedVector2Array()
	for point in points:
		vertices.append(center + (forward * point.x + normal * point.y) * size)
	canvas.draw_colored_polygon(vertices, fill)
	vertices.append(vertices[0])
	canvas.draw_polyline(vertices, outline, 1.1 * size, true)
