## Semantic page geometry. UI skins can keep the same IDs while changing art.
extends RefCounted

var design_size: Vector2
var navigation_y: float
var navigation_height: float
var navigation_inset: float
var rects: Dictionary = {}


func _init(
		p_design_size: Vector2 = Vector2(720.0, 1280.0),
		p_navigation_y: float = 1148.0,
		p_navigation_height: float = 122.0,
		p_navigation_inset: float = 3.0,
		p_rects: Dictionary = {}
	) -> void:
	design_size = p_design_size
	navigation_y = p_navigation_y
	navigation_height = p_navigation_height
	navigation_inset = p_navigation_inset
	rects = p_rects.duplicate(true)


func navigation_rect(index: int, item_count: int) -> Rect2:
	if index < 0 or item_count <= 0:
		return Rect2()
	var width = design_size.x / float(item_count)
	return Rect2(index * width + navigation_inset, navigation_y, width - navigation_inset * 2.0, navigation_height)


func rect_for(rect_id: String, fallback: Rect2 = Rect2()) -> Rect2:
	var value = rects.get(rect_id, fallback)
	if value is Rect2:
		return value
	return fallback
