extends SceneTree

const EXPECTED_POOL_BY_PRICE = {
	50: "unit_cards_price_50",
	100: "unit_cards_price_100",
	250: "unit_cards_price_250",
}
const EXPECTED_RARITY_WEIGHTS = {
	50: {"common": 70, "rare": 25, "epic": 5},
	100: {"common": 15, "rare": 70, "epic": 12, "legendary": 3},
	250: {"rare": 10, "epic": 55, "legendary": 35},
}
const EXPECTED_PRIMARY_RARITY = {
	50: "common",
	100: "rare",
	250: "epic",
}
const EXPECTED_PRIMARY_WEIGHT = {
	50: 70,
	100: 70,
	250: 55,
}

var failures = 0
var price_rows: Array = []
var card_pool_rows: Array = []


func _init() -> void:
	price_rows = _load_json_array("res://runtime/config/cell_price_pools.json")
	card_pool_rows = _load_json_array("res://runtime/config/card_random_pools.json")
	_test_price_pool_mapping()
	_test_rarity_distributions()
	if failures == 0:
		print("Camp rarity pool tests passed.")
	quit(failures)


func _test_price_pool_mapping() -> void:
	for price in EXPECTED_POOL_BY_PRICE:
		var matching_rows = price_rows.filter(func(row: Variant) -> bool:
			return typeof(row) == TYPE_DICTIONARY and int(row.get("price", 0)) == int(price)
		)
		_expect_equal(matching_rows.size(), 1, "%d-price row count" % int(price))
		if matching_rows.size() != 1:
			continue
		_expect_equal(
			String(matching_rows[0].get("unit_card_pool_id", "")),
			String(EXPECTED_POOL_BY_PRICE[price]),
			"%d-price unit pool mapping" % int(price)
		)


func _test_rarity_distributions() -> void:
	for price in EXPECTED_POOL_BY_PRICE:
		var pool_id = String(EXPECTED_POOL_BY_PRICE[price])
		var totals = {}
		var total_weight = 0
		var total_probability = 0.0
		for row in card_pool_rows:
			if typeof(row) != TYPE_DICTIONARY or String(row.get("pool_id", "")) != pool_id:
				continue
			_expect_equal(String(row.get("entry_type", "")), "unit", "%s entry type" % pool_id)
			var rarity = String(row.get("rarity", ""))
			var weight = int(row.get("weight", 0))
			var probability = float(row.get("probability_pct", 0.0))
			totals[rarity] = int(totals.get(rarity, 0)) + weight
			total_weight += weight
			total_probability += probability
			_expect_approx(probability, float(weight), "%s row probability mirrors runtime weight" % pool_id)

		_expect_equal(total_weight, 100, "%s total runtime weight" % pool_id)
		_expect_approx(total_probability, 100.0, "%s total documented probability" % pool_id)
		_expect_equal(totals, EXPECTED_RARITY_WEIGHTS[price], "%s rarity distribution" % pool_id)
		_expect_equal(
			_highest_weight_rarity(totals),
			String(EXPECTED_PRIMARY_RARITY[price]),
			"%s primary rarity" % pool_id
		)
		_expect_equal(
			int(totals.get(EXPECTED_PRIMARY_RARITY[price], 0)),
			int(EXPECTED_PRIMARY_WEIGHT[price]),
			"%s primary rarity probability" % pool_id
		)


func _highest_weight_rarity(totals: Dictionary) -> String:
	var result = ""
	var best_weight = -1
	for rarity in totals:
		var weight = int(totals[rarity])
		if weight > best_weight:
			best_weight = weight
			result = String(rarity)
	return result


func _load_json_array(path: String) -> Array:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		failures += 1
		push_error("Cannot open runtime config: %s" % path)
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		failures += 1
		push_error("Runtime config is not an array: %s" % path)
		return []
	return parsed


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failures += 1
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _expect_approx(actual: float, expected: float, label: String) -> void:
	if is_equal_approx(actual, expected):
		return
	failures += 1
	push_error("%s: expected %.2f, got %.2f" % [label, expected, actual])
