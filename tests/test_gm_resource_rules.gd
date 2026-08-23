extends Node

const GmResourceRules = preload("res://scripts/app/systems/gm_resource_rules.gd")

var failures = 0


func _ready() -> void:
	var guest_battle = {
		"debug_build": true,
		"online_match_active": false,
		"logged_in": false,
		"classic_battle_active": true,
	}
	_expect_next_value(
		GmResourceRules.evaluate(
			GmResourceRules.RESOURCE_BATTLE_GOLD,
			GmResourceRules.OPERATION_ADD,
			"250",
			60,
			guest_battle
		),
		310,
		"battle gold can be added in a local classic battle"
	)
	_expect_next_value(
		GmResourceRules.evaluate(
			GmResourceRules.RESOURCE_GACHA_TICKETS,
			GmResourceRules.OPERATION_SET,
			"88",
			5,
			guest_battle
		),
		88,
		"guest tickets can be set for the current session"
	)
	_expect_next_value(
		GmResourceRules.evaluate(
			GmResourceRules.RESOURCE_CARD_LEVEL,
			GmResourceRules.OPERATION_SET,
			"10",
			1,
			guest_battle,
			"rabbit"
		),
		10,
		"card level accepts the configured maximum"
	)
	_expect_denied(
		GmResourceRules.evaluate(
			GmResourceRules.RESOURCE_CARD_LEVEL,
			GmResourceRules.OPERATION_ADD,
			"1",
			10,
			guest_battle,
			"rabbit"
		),
		"card level cannot exceed its maximum"
	)
	_expect_denied(
		GmResourceRules.evaluate(
			GmResourceRules.RESOURCE_CARD_COUNT,
			GmResourceRules.OPERATION_SET,
			"10",
			0,
			guest_battle
		),
		"card resources require a card selection"
	)
	_expect_denied(
		GmResourceRules.evaluate(
			GmResourceRules.RESOURCE_BATTLE_GOLD,
			GmResourceRules.OPERATION_SET,
			"12.5",
			60,
			guest_battle
		),
		"decimal values are rejected"
	)
	_expect_denied(
		GmResourceRules.evaluate(
			GmResourceRules.RESOURCE_BATTLE_GOLD,
			GmResourceRules.OPERATION_SUBTRACT,
			"61",
			60,
			guest_battle
		),
		"resource results cannot become negative"
	)
	var online_context = guest_battle.duplicate()
	online_context["online_match_active"] = true
	_expect_denied(
		GmResourceRules.evaluate(
			GmResourceRules.RESOURCE_BATTLE_GOLD,
			GmResourceRules.OPERATION_ADD,
			"100",
			60,
			online_context
		),
		"all operations are denied during online matches"
	)
	var logged_in_context = guest_battle.duplicate()
	logged_in_context["logged_in"] = true
	_expect_denied(
		GmResourceRules.evaluate(
			GmResourceRules.RESOURCE_GACHA_TICKETS,
			GmResourceRules.OPERATION_ADD,
			"1",
			5,
			logged_in_context
		),
		"account-backed resources are denied while logged in"
	)
	var release_context = guest_battle.duplicate()
	release_context["debug_build"] = false
	_expect_denied(
		GmResourceRules.evaluate(
			GmResourceRules.RESOURCE_CARD_COUNT,
			GmResourceRules.OPERATION_ADD,
			"1",
			0,
			release_context,
			"rabbit"
		),
		"release builds cannot execute GM operations"
	)

	if failures == 0:
		print("GM_RESOURCE_RULES_PASS")
	get_tree().quit(failures)


func _expect_next_value(result: Dictionary, expected: int, label: String) -> void:
	if bool(result.get("ok", false)) and int(result.get("next_value", -1)) == expected:
		return
	_fail("%s: expected %d, got %s" % [label, expected, str(result)])


func _expect_denied(result: Dictionary, label: String) -> void:
	if not bool(result.get("ok", false)) and not String(result.get("message", "")).is_empty():
		return
	_fail("%s: expected a denial with a message, got %s" % [label, str(result)])


func _fail(message: String) -> void:
	failures += 1
	push_error(message)
