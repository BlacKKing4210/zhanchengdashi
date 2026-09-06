extends SceneTree

const CardRules = preload("res://scripts/app/systems/card_rules.gd")

func _init() -> void:
	var failures = 0
	var checks = 0
	var payload = JSON.parse_string(FileAccess.get_file_as_string("res://runtime/config/cards.json"))
	var rows = payload if payload is Array else payload.get("rows", [])
	for row in rows:
		var card = CardRules.card_from_row(row)
		for level in range(1, 11):
			var stats = CardRules.card_stats(card, {card.id: level})
			var expected = floori(float(row.max_hp) + (level - 1) * float(row.max_hp_lv) + 0.000001)
			checks += 1
			if int(stats.max_hp) != expected:
				failures += 1
				push_error("Per-card cumulative growth mismatch: " + String(card.id))
	print("Card upgrade per-card health checks=", checks, " failures=", failures)
	quit(1 if failures > 0 or checks != 710 else 0)
