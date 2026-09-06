extends RefCounted
## Approved B skin. Cached styles and original terrain, no gameplay state.
const PAPER = Color("f4eee3")
const SURFACE = Color("e9dfce")
const RAISED = Color("f6f0e7")
const INK = Color("332f29")
const PRIMARY = Color("f3c454")
const PROMOTED = Color("f5a13e")
const SECONDARY = Color("87babb")
const NAV_IDLE = Color("b6c9c6")
const DISABLED = Color("ddd7cc")
const DISABLED_INK = Color("625d55")
const GOLD = Color("ecc45f")
const UPGRADE_DOT = Color("e94b4f")
const TILE_READY = Color("fff000")
const TILE_READY_EDGE = Color("9d721b")
const TILE_UNAVAILABLE = Color(0.78, 0.72, 0.62)
const SAGE = Color("ced4a9")
const BLUE = Color("b8cfdf")
const LILAC = Color("cdb9d6")
const PEACH = Color("eabca5")
const PROGRESS = Color("518878")
const LOCKED = Color("d3cbbd")
const TERRAIN_COLORS = [Color("f5d46c"), Color("88c9df"), Color("c697d0"), Color("858580"), Color("b4d574"), Color("f4a372"), Color("e77e9a"), Color("f5e7ce")]
const TERRAIN = [
	preload("res://assets/art/terrain/handdrawn/yellow.png"),
	preload("res://assets/art/terrain/handdrawn/blue.png"),
	preload("res://assets/art/terrain/handdrawn/lilac.png"),
	preload("res://assets/art/terrain/handdrawn/gray.png"),
	preload("res://assets/art/terrain/handdrawn/lime.png"),
	preload("res://assets/art/terrain/handdrawn/orange.png"),
	preload("res://assets/art/terrain/handdrawn/pink.png"),
	preload("res://assets/art/terrain/handdrawn/cream.png"),
]
static var _styles: Dictionary = {}


static func panel(fill: Color, radius: float = 12.0, shadow: bool = true) -> StyleBoxFlat:
	# Animated opacity must not grow the style cache indefinitely.
	fill.a = snappedf(fill.a, 0.05)
	var key = "%s:%s:%s" % [fill.to_html(), radius, shadow]
	if not _styles.has(key):
		var style = StyleBoxFlat.new()
		style.bg_color = fill
		style.set_corner_radius_all(int(radius))
		style.anti_aliasing = true
		if shadow:
			style.shadow_color = Color(0.28, 0.22, 0.14, 0.13 * fill.a)
			style.shadow_size = 3
			style.shadow_offset = Vector2(0, 3)
		_styles[key] = style
	return _styles[key]


static func surface_color(fill: Color) -> Color:
	if fill in [PAPER, SURFACE, RAISED, INK, PRIMARY, PROMOTED, SECONDARY, NAV_IDLE, DISABLED, GOLD, SAGE, BLUE, LILAC, PEACH, PROGRESS, LOCKED]:
		return fill
	var mapped = SURFACE
	if fill.v > 0.90 and fill.s < 0.20: mapped = RAISED
	elif fill.s > 0.2 and fill.h > 0.18 and fill.h < 0.45: mapped = SAGE
	elif fill.s > 0.2 and fill.h > 0.45 and fill.h < 0.65: mapped = BLUE
	mapped.a = fill.a
	return mapped


static func rarity(rarity_id: String) -> Color:
	match rarity_id:
		"common": return SAGE
		"rare": return BLUE
		"epic": return LILAC
		"legendary": return GOLD
	return SURFACE


static func action_fill(primary: bool, enabled: bool) -> Color:
	if not enabled: return DISABLED
	return PRIMARY if primary else SECONDARY


static func terrain_index(team: int, team_mode: bool, seed_value: int) -> int:
	if team == 0: return 7
	# Classic battles use -1 for the enemy; this is not a neutral tile.
	if team == -1: team = 2
	if team < 1: return 7
	if team_mode:
		return [0, 5, 6, 1, 2, 4][posmod(team - 1, 6)]
	return [4, 2, 1, 5, 6, 0][posmod(team - 1 + posmod(seed_value, 6), 6)]
