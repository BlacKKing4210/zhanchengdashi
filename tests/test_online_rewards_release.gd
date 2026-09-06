extends Node

const Main = preload("res://scripts/app/main.gd")
const Transport = preload("res://scripts/network/online_room.gd")
const Names = preload("res://scripts/shared/player_display_name.gd")
const Sync = preload("res://scripts/shared/profile_sync_rules.gd")
const Adapter = preload("res://scripts/server/player_account_profile_adapter.gd")

class TestApp extends Main:
	func _auto_login_saved_account_on_startup() -> void: pass
	func _setup_online_room() -> void: online_room_service = OnlineRoom
	func _load_rank_database() -> void: _ensure_rank_database_shape()
	func _save_rank_database() -> void: pass
	func _report_completed_battle(_type: String, _map: String, _outcome: String, _placement: int) -> void: pass

class Relay extends Node:
	var current_username = "小松鼠"
	var current_identity_complete = true
	var app
	var commands: Array = []
	func is_connected_to_server() -> bool: return true
	func send_battle_command(command: Dictionary) -> bool:
		commands.append(command.duplicate(true))
		app._on_online_battle_command({"match_id": app.online_match_id, "sender_peer_id": 23, "sender_team_id": app.local_team_id, "command": command})
		return true

var app: TestApp
var relay: Relay
var checks = 0
var failures = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _ready() -> void:
	GameAudio.sfx_enabled = false
	var viewport = SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	add_child(viewport)
	app = TestApp.new()
	viewport.add_child(app)
	app.set_process(false)
	relay = Relay.new()
	add_child(relay)
	relay.app = app
	app.online_room_service = relay
	app._layout(Vector2(720, 1280))
	test_names()
	test_account_events()
	test_profile_sync()
	for size in [1, 3]: test_touch_build(size)
	test_rewards()
	test_snapshot_cost()
	print("ONLINE_REWARDS_RELEASE checks=", checks, " failures=", failures)
	app.queue_free()
	relay.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)

func test_names() -> void:
	check(Names.resolve("") == "神秘玩家", "unnamed player")
	check(Names.resolve("U-123456-ABCDEFG") == "神秘玩家", "no generated account ID")
	check(Names.resolve("登录账号", "登录账号") == "神秘玩家", "no login credential fallback")
	check(Names.resolve(" 雨后蜗牛 ") == "雨后蜗牛", "nickname retained")
	check(app._room_human_display_name({"is_local": true, "display_name": "U-123456-ABCDEFG"}) == "小松鼠", "local nickname overrides old server ID")
	relay.current_username = ""
	check(app._online_player_name() == "神秘玩家", "empty nickname no account fallback")
	check(app._room_human_display_name({"display_name": "U-123456-ABCDEFG"}) == "神秘玩家", "remote legacy ID hidden")
	check(app._room_human_display_name({"username": "风铃草", "display_name": "U-123456-ABCDEFG"}) == "风铃草", "remote nickname")
	relay.current_username = "小松鼠"
	relay.current_identity_complete = false
	check(app._online_player_name() == "神秘玩家", "auto-generated nickname is not a chosen nickname")
	relay.current_identity_complete = true

func test_account_events() -> void:
	var service = Transport.new()
	var events: Array = []
	service.account_state_changed.connect(func(state): events.append(state))
	for operation in ["create_room", "join_room", "set_ready", "start_room", "battle_command", "report_completed_local_battle"]:
		service._apply_account_operation(operation, {"ok": true})
	check(events.is_empty(), "non-account success never replays stale profile")
	service._apply_account_operation("save_player_profile", {"ok": true, "profile": {"gacha_tickets": 5}})
	check(events.size() == 1 and events[0].operation == "save_player_profile", "save ACK carries operation")
	var names: Array = []
	for method in service.get_script().get_script_method_list():
		if String(method.name).begins_with("_rpc_"): names.append(String(method.name))
	names.sort()
	check(names.find("_rpc_submit_authority_snapshot") == 25, "deployed authority snapshot RPC index preserved")
	check(names.find("_rpc_submit_battle_command") == 26, "deployed build command RPC index preserved")
	check(names.size() == 27 and names.back() == "_rpc_submit_battle_command", "frozen deployed RPC protocol; new account extension isolated")
	check(service._payload_fits({"action": "unlock_tile", "sequence": 1, "q": 2, "r": 3}, 65536), "small build payload accepted")
	check(not service._payload_fits({"padding": "x".repeat(65536)}, 65536), "oversize payload still rejected")
	service.free()

func test_profile_sync() -> void:
	var baseline = {"gacha_tickets": 5, "wallet_gold": 60, "card_counts": {"rabbit": 1}}
	var local = {"gacha_tickets": 8, "wallet_gold": 71, "card_counts": {"rabbit": 2}}
	var merged = Sync.rebase(baseline, local, baseline)
	check(merged == local, "late successful ACK preserves new rewards")
	var remote = {"gacha_tickets": 9, "wallet_gold": 70, "card_counts": {"rabbit": 3}}
	merged = Sync.rebase(remote, local, baseline)
	check(merged.gacha_tickets == 12 and merged.wallet_gold == 81 and merged.card_counts.rabbit == 4, "CAS conflict preserves both remote grants and unsaved local changes")
	var adapter = Adapter.new()
	check(adapter.normalize_profile(local).wallet_gold == 71, "gold survives cloud profile normalization")
	check(adapter.normalize_profile({}).wallet_gold == 60, "legacy profile migrates wallet")
	app._on_account_state_changed({"logged_in": true, "user_id": "qa-account", "operation": "login_account", "profile": baseline})
	app.account_pending_profile = app._server_profile_snapshot()
	var sent = app.account_pending_profile.duplicate(true)
	app.gacha_tickets += 3
	app.wallet_gold += 11
	app._on_account_state_changed({"logged_in": true, "user_id": "qa-account", "operation": "save_player_profile", "profile": sent})
	check(app.gacha_tickets == 8 and app.wallet_gold == 71, "actual account signal keeps pending rewards")
	check(app.account_pending_profile.is_empty(), "ACK frees single-flight save")
	app.account_pending_profile = app._server_profile_snapshot()
	sent = app.account_pending_profile.duplicate(true)
	sent.erase("wallet_gold")
	app.gacha_tickets += 3
	app.wallet_gold += 9
	app._on_account_state_changed({"logged_in": true, "user_id": "qa-account", "operation": "save_player_profile", "profile": sent})
	check(app.gacha_tickets == 11 and app.wallet_gold == 80, "legacy server missing wallet preserves reward exactly once")
	app.account_pending_profile = app._server_profile_snapshot()
	app.wallet_gold += 3
	app._on_account_state_changed({"logged_in": true, "user_id": "qa-account", "operation": "save_player_profile", "conflict": true, "profile": sent})
	check(app.wallet_gold == 83, "legacy conflict cannot multiply local wallet reward")
	app._on_account_state_changed({"logged_in": true, "user_id": "other-account", "operation": "switch_account", "profile": baseline})
	check(app.gacha_tickets == 5 and app.wallet_gold == 60, "switching accounts does not carry previous rewards")

func test_touch_build(size: int) -> void:
	app._init_player_collection()
	app._init_deck()
	app._on_online_match_started({"match_id": "qa-%d" % size, "map_id": "%dv%d_crossroads" % [size, size], "players_per_side": size, "local_team_id": 1, "is_authority": true, "match_seed": 219})
	app.online_room_service = relay
	app._layout(Vector2(720, 1280))
	var key = Vector2i(-9999, -9999)
	for candidate in app.tiles:
		if app._can_unlock(candidate, 1) and String(app.tiles[candidate].get("site", "")) == "tower":
			key = candidate
			break
	if key.x == -9999:
		for candidate in app.tiles:
			if app._can_unlock(candidate, 1):
				key = candidate
				app.tiles[key]["site"] = "tower"
				app.tiles[key]["site_cost"] = 50
				break
	check(key.x != -9999, "%dv%d has buildable site" % [size, size])
	if key.x == -9999: return
	app.gold = 1000
	var cost = app._unlock_cost(key, 1)
	var position = app._world_to_canvas(app._hex_center(key))
	# Frame the real tile at a HUD-free touch location using the normal camera transform.
	app.board_pan += Vector2(360, 500) - position
	position = app._world_to_canvas(app._hex_center(key))
	var screen_position = app.canvas_offset + position * app.canvas_scale
	var count = relay.commands.size()
	app._begin_board_pointer(screen_position)
	app._end_board_pointer(screen_position)
	check(relay.commands.size() == count + 1, "%dv%d tap dispatches exactly one command" % [size, size])
	check(String(app.tiles[key].get("building", "")) == "tower", "%dv%d command actually constructs tower" % [size, size])
	check(app.gold == 1000 - cost, "construction deducts cost once")
	if relay.commands.size() > count:
		app._on_online_battle_command({"match_id": app.online_match_id, "sender_peer_id": 23, "sender_team_id": 1, "command": relay.commands.back()})
		check(app.gold == 1000 - cost, "duplicate command rejected")
	var snapshot = app._online_battle_snapshot()
	app.online_match_authority = false
	app.tiles[key]["building"] = ""
	app._apply_online_battle_snapshot(snapshot)
	check(String(app.tiles[key].get("building", "")) == "tower", "client snapshot applies authority construction")

func test_rewards() -> void:
	app._clear_online_match_state()
	for outcome in ["胜利", "失败"]:
		app._start_match("1v1_crossroads")
		var tickets = app.gacha_tickets
		var wallet = app.wallet_gold
		var battle_gold = app.gold
		var base = app._battle_base_key(app.ENEMY if outcome == "胜利" else app.PLAYER)
		app._damage_tile(base, app.PLAYER if outcome == "胜利" else app.ENEMY, 999999)
		var awarded = 3 if outcome == "胜利" else 1
		check(app.gacha_tickets == tickets + awarded, "base defeat awards outcome tickets")
		check(app.wallet_gold >= wallet + awarded * 3 and app.wallet_gold <= wallet + awarded * 5, "gold in 3-5x ticket range")
		check(app.gold == battle_gold, "reward does not modify in-match gold")
		var after = app.wallet_gold
		app._finish_battle(outcome)
		check(app.gacha_tickets == tickets + awarded and app.wallet_gold == after, "settlement only once")
		app._start_match("1v1_crossroads")
		check(app.wallet_gold == after and app.gold == 60, "new battle resets battle currency only")
		app._exit_battle_without_settlement()
		check(app.gacha_tickets == tickets + awarded and app.wallet_gold == after, "quitting gives no rewards")

func test_snapshot_cost() -> void:
	var baseline: Array = []
	var optimized: Array = []
	var bytes_old = PackedByteArray()
	var bytes_new = PackedByteArray()
	for i in range(140):
		var snapshot = app._online_battle_snapshot()
		var start = Time.get_ticks_usec()
		bytes_old = var_to_bytes(snapshot.duplicate(true))
		var old_time = Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		bytes_new = var_to_bytes(snapshot)
		var new_time = Time.get_ticks_usec() - start
		if i > 20:
			baseline.append(old_time)
			optimized.append(new_time)
	check(bytes_old == bytes_new, "removing redundant snapshot copy produces identical wire bytes")
	baseline.sort()
	optimized.sort()
	print("SNAPSHOT_SERIALIZATION bytes=", bytes_new.size(), " before_p95_us=", baseline[int(baseline.size() * 0.95)], " after_p95_us=", optimized[int(optimized.size() * 0.95)])
