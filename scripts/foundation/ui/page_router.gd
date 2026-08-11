## Stateful page routing with no dependency on how pages are drawn.
extends RefCounted

signal page_changed(previous_page: String, current_page: String)

var _pages: Dictionary = {}
var _current_page = ""


func _init(pages: Array = [], initial_page: String = "") -> void:
	for page in pages:
		register_page(String(page))
	if not initial_page.is_empty():
		go_to(initial_page)


func register_page(page_id: String, enabled: bool = true) -> void:
	var normalized = page_id.strip_edges()
	if not normalized.is_empty():
		_pages[normalized] = enabled


func set_enabled(page_id: String, enabled: bool) -> void:
	if _pages.has(page_id):
		_pages[page_id] = enabled


func go_to(page_id: String) -> Dictionary:
	var normalized = page_id.strip_edges()
	if not _pages.has(normalized):
		return {"ok": false, "error": "unknown_page"}
	if not bool(_pages[normalized]):
		return {"ok": false, "error": "page_locked"}
	var previous = _current_page
	_current_page = normalized
	if previous != _current_page:
		page_changed.emit(previous, _current_page)
	return {"ok": true, "previous_page": previous, "current_page": _current_page}


func current_page() -> String:
	return _current_page
