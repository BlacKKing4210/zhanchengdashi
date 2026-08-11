extends SceneTree

const DeckService = preload("res://scripts/foundation/deck/deck_service.gd")
const GachaService = preload("res://scripts/foundation/gacha/gacha_service.gd")
const RoomRules = preload("res://scripts/foundation/room/room_rules.gd")
const PageRouter = preload("res://scripts/foundation/ui/page_router.gd")
const MainPageLayout = preload("res://scripts/foundation/ui/main_page_layout.gd")

var failures = 0


func _init() -> void:
	_test_deck_service()
	_test_gacha_service()
	_test_room_rules()
	_test_page_services()
	if failures == 0:
		print("PORTABLE_FOUNDATION_TEST_PASS")
	quit(failures)


func _test_deck_service() -> void:
	var deck = DeckService.normalize(["wolf", "missing", "rabbit"], ["rabbit", "wolf", "mine", "tower"], 3, ["mine", "tower"])
	_expect(deck.size() == 3, "deck fills requested slot count")
	_expect(DeckService.has_required(deck, ["mine", "tower"]), "deck preserves required items")
	var replacement = DeckService.can_replace(deck, 2, "wolf", ["mine", "tower"])
	_expect(bool(replacement.get("ok", false)), "deck supports valid replacement")
	var blocked = DeckService.can_replace(deck, 0, "wolf", ["mine", "tower"])
	_expect(not bool(blocked.get("ok", true)), "deck blocks removing a required item")


func _test_gacha_service() -> void:
	var cards = [{"id": "rabbit", "rarity": "common"}, {"id": "bear", "rarity": "legendary"}]
	var reward = GachaService.roll(cards, {"common": 80.0, "legendary": 20.0}, 95.0, 0)
	_expect(String(reward.get("id", "")) == "bear", "gacha selects configured rarity")
	var card_rule_reward = GachaService.roll(cards, [{"rarity": "common", "rate": 80.0}, {"rarity": "legendary", "rate": 20.0}], 95.0, 0)
	_expect(String(card_rule_reward.get("id", "")) == "bear", "gacha accepts CardRules rarity-rate arrays")
	var inventory = GachaService.apply_reward({"bear": 1}, {}, reward)
	_expect(int(inventory["counts"]["bear"]) == 2, "gacha increments inventory")
	_expect(int(inventory["levels"]["bear"]) == 1, "gacha initializes level")


func _test_room_rules() -> void:
	_expect(RoomRules.active_team_ids(2) == [1, 2, 4, 5], "room default topology remains compatible")
	var configured = RoomRules.configure({"max_players_per_side": 2, "sides": {"left": [10, 11], "right": [20, 21]}, "join_priority": [10, 20, 11, 21]})
	_expect(bool(configured.get("ok", false)), "room rules accepts portable topology")
	_expect(RoomRules.active_team_ids(2) == [10, 11, 20, 21], "room rules uses configured topology")
	RoomRules.configure({"min_players_per_side": 1, "max_players_per_side": 3, "room_code_length": 6, "player_name_max_length": 24, "sides": {"A": [1, 2, 3], "B": [4, 5, 6]}, "join_priority": [1, 4, 2, 5, 3, 6]})


func _test_page_services() -> void:
	var router = PageRouter.new(["lobby", "deck"], "lobby")
	_expect(String(router.go_to("deck").get("current_page", "")) == "deck", "router changes pages")
	var layout = MainPageLayout.new(Vector2(720.0, 1280.0))
	_expect(layout.navigation_rect(1, 4).position.x == 183.0, "layout produces stable navigation geometry")


func _expect(value: bool, label: String) -> void:
	if value:
		return
	failures += 1
	push_error(label)
