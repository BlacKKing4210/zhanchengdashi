extends Node

const BattleAnalyticsContract = preload("res://scripts/shared/battle_analytics_contract.gd")
const OnlineRoomTransport = preload("res://scripts/network/online_room.gd")

var failures = 0


class FakeAccountStore extends RefCounted:
	func close() -> bool:
		return true


	func profile_for_session(session_token: String) -> Dictionary:
		if session_token != "session-one":
			return {"ok": false, "error": "invalid_session"}
		return {
			"ok": true,
			"user_id": "U-ANALYTICS-ONE",
			"account": "统计测试账号",
			"profile": {
				"rank_key": "gold",
				"rank_stars": 8,
				"elo": 1260,
				"deck": ["rabbit", "wolf", "defense_watch_tower"],
				"card_levels": {"rabbit": 3, "wolf": 2, "defense_watch_tower": 1},
			},
		}


class FakeAnalyticsStore extends RefCounted:
	var matches: Dictionary = {}
	var began: Array = []
	var finalized: Array = []


	func begin_match(match: Dictionary, roster: Array, _catalog: Dictionary) -> Dictionary:
		var match_id = String(match.get("match_id", ""))
		if matches.has(match_id):
			return {"ok": true, "created": false, "idempotent": true, "match_id": match_id}
		matches[match_id] = {"match": match.duplicate(true), "roster": roster.duplicate(true), "finalized": false}
		began.append(matches[match_id].duplicate(true))
		return {"ok": true, "created": true, "match_id": match_id}


	func finalize_match(match_id: String, result: Dictionary) -> Dictionary:
		if not matches.has(match_id):
			return {"ok": false, "error": "match_not_found"}
		var record: Dictionary = matches[match_id]
		if bool(record.get("finalized", false)):
			return {"ok": true, "finalized": false, "idempotent": true, "match_id": match_id}
		record["finalized"] = true
		record["result"] = result.duplicate(true)
		matches[match_id] = record
		finalized.append(record.duplicate(true))
		return {"ok": true, "finalized": true, "match_id": match_id}


func _ready() -> void:
	_expect(BattleAnalyticsContract.multiplayer_type(1) == BattleAnalyticsContract.MULTIPLAYER_1V1, "1v1 uses the controlled battle type")
	_expect(BattleAnalyticsContract.multiplayer_type(2) == BattleAnalyticsContract.MULTIPLAYER_2V2, "2v2 uses the controlled battle type")
	_expect(BattleAnalyticsContract.multiplayer_type(3) == BattleAnalyticsContract.MULTIPLAYER_3V3, "3v3 uses the controlled battle type")
	var ffa_result = BattleAnalyticsContract.local_terminal_result(BattleAnalyticsContract.FREE_FOR_ALL_6, "loss", 3)
	_expect(bool(ffa_result.get("ok", false)) and int(ffa_result.get("placements_by_team", {}).get(1, 0)) == 3, "free-for-all preserves the local placement")

	var transport = OnlineRoomTransport.new()
	add_child(transport)
	var account_store = FakeAccountStore.new()
	var analytics_store = FakeAnalyticsStore.new()
	transport.set("_account_store", account_store)
	transport.set("_match_analytics_store", analytics_store)
	transport.set("_server_peer_sessions", {42: "session-one"})
	var report_ids = [
		"00000000000000000000000000000001",
		"00000000000000000000000000000002",
		"00000000000000000000000000000003",
		"00000000000000000000000000000004",
		"00000000000000000000000000000005",
	]
	var report_types = [
		BattleAnalyticsContract.CLASSIC_RANKED_AI,
		BattleAnalyticsContract.MULTIPLAYER_1V1,
		BattleAnalyticsContract.MULTIPLAYER_2V2,
		BattleAnalyticsContract.MULTIPLAYER_3V3,
		BattleAnalyticsContract.FREE_FOR_ALL_6,
	]
	for index in range(report_types.size()):
		var battle_type: String = report_types[index]
		var placement = 3 if battle_type == BattleAnalyticsContract.FREE_FOR_ALL_6 else 1
		var outcome = "loss" if battle_type == BattleAnalyticsContract.FREE_FOR_ALL_6 else "win"
		var result: Dictionary = transport.call(
			"_record_authenticated_client_battle",
			42,
			battle_type,
			"map-%d" % index,
			outcome,
			placement,
			report_ids[index]
		)
		_expect(bool(result.get("ok", false)), "%s completed report is accepted" % battle_type)
		_expect(String(result.get("battle_type", "")) == battle_type, "%s remains classified" % battle_type)
		_expect(String(result.get("analytics_authority", "")) == BattleAnalyticsContract.AUTHENTICATED_CLIENT_REPORTED, "%s marks authenticated client authority" % battle_type)

	_expect(analytics_store.began.size() == report_types.size(), "every reportable completed battle type creates one analytics record")
	for record_value in analytics_store.began:
		var record: Dictionary = record_value
		var match: Dictionary = record.get("match", {})
		var roster: Array = record.get("roster", [])
		_expect(String(match.get("analytics_authority", "")) == BattleAnalyticsContract.AUTHENTICATED_CLIENT_REPORTED, "client-reported analytics authority is persisted")
		_expect(roster.size() == 1 and String((roster[0] as Dictionary).get("user_id", "")) == "U-ANALYTICS-ONE", "server freezes the authenticated account profile")
		_expect(not JSON.stringify(record).contains("session-one"), "session credentials never enter analytics records")

	var replay: Dictionary = transport.call(
		"_record_authenticated_client_battle",
		42,
		BattleAnalyticsContract.CLASSIC_RANKED_AI,
		"different-map-is-ignored-by-idempotency",
		"loss",
		2,
		report_ids[0]
	)
	_expect(bool(replay.get("ok", false)) and bool(replay.get("idempotent", false)), "the same account and report id finalize idempotently")
	_expect(analytics_store.began.size() == report_types.size(), "an idempotent replay never creates another analytics record")
	var invalid: Dictionary = transport.call("_record_authenticated_client_battle", 42, "not-a-type", "map", "win", 1, "bad")
	_expect(not bool(invalid.get("ok", false)), "invalid client reports fail closed")
	_expect(bool(transport.call("stop_transport_and_confirm")), "analytics test transport releases its account store")
	transport.free()

	if failures == 0:
		print("ALL_BATTLE_ANALYTICS_TEST_PASS")
	else:
		push_error("ALL_BATTLE_ANALYTICS_TEST_FAIL: %d failure(s)" % failures)
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
