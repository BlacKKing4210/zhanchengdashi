extends Node

const Home = preload("res://scripts/shared/home_rules.gd")
const Store = preload("res://scripts/server/player_account_store.gd")
const Transport = preload("res://scripts/network/online_room.gd")

class ClockStore extends Store:
	var today = 22000
	var fail_save = false
	func _home_today() -> int:
		return today
	func _save() -> bool:
		return false if fail_save else super._save()

class TransportProbe extends Transport:
	var responses: Array = []
	func _send_operation_result(peer_id: int, operation: String, result: Dictionary) -> void:
		responses.append({"peer": peer_id, "operation": operation, "result": result})

var checks = 0
var failures = 0
var observed: Dictionary = {}


func _ready() -> void:
	GameAudio.set_music_enabled(false)
	GameAudio.set_sfx_enabled(false)
	_test_catalog()
	_test_calendar_and_items()
	_test_conversion()
	_test_store()
	_test_protocol()
	print("HOME_ECONOMY_RESULT ", JSON.stringify({"checks": checks, "failures": failures, "observed": observed}))
	await get_tree().process_frame
	get_tree().quit(1 if failures > 0 else 0)


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("HOME_ECONOMY: " + label)


func _test_catalog() -> void:
	var plots = Home.all_plots()
	check(plots.size() == 217, "8 rings yield 217 plots including castle")
	var types: Dictionary = {}
	var ring_counts: Dictionary = {}
	var state = Home.initial_state(22000)
	check(Home.visible_plots(state).size() == 7, "initial frontier shows castle plus six plots")
	for entry in plots:
		check(Home.plot(entry.id) == entry, "stable immutable plot lookup " + entry.id)
		if int(entry.ring) == 0:
			continue
		var base = 100 * int(pow(3, int(entry.ring) - 1))
		check(int(entry.cost) >= base / 2 and int(entry.cost) <= base * 3 / 2, "ring cost bounds " + entry.id)
		check(int(entry.value) >= 5 and int(entry.value) <= 100, "bounded daily value " + entry.id)
		check(entry.terrain_index == Home.TERRAIN_INDICES[entry.type], "battle terrain mapping " + entry.id)
		if entry.type == "residence":
			check(int(entry.capacity) >= 1 and int(entry.capacity) <= 5, "residence capacity " + entry.id)
		ring_counts[entry.ring] = int(ring_counts.get(entry.ring, 0)) + 1
		if entry.ring == 1:
			types[entry.type] = true
			check(entry.value == round(float(entry.cost) / 10.0), "first ring yield " + entry.id)
	for ring in range(1, 9):
		check(int(ring_counts[ring]) == 6 * ring, "correct hex ring count")
	check(types.size() == 4, "first ring contains all four activity types")
	check(Home.plot("99999999999,3").is_empty(), "unknown plot rejected")
	check(Home.can_unlock(state, "2,0", 100000).error == "plot_not_adjacent", "nonadjacent unlock blocked")
	check(Home.can_unlock(state, "1,0", 0).error == "insufficient_gold", "insufficient wallet blocked")
	var cost = int(Home.plot("1,0").cost)
	var unlocked = Home.unlock(state, "1,0", cost, 4, 22000)
	check(unlocked.ok and unlocked.wallet_gold == 0 and unlocked.gacha_tickets == 5, "exact funds debit and one immediate ticket")
	check(not state.owned.has("1,0"), "pure unlock does not mutate caller")
	check(not Home.unlock(unlocked.home, "1,0", 9999, 5, 22000).ok, "duplicate pure unlock rejected")
	check(Home.visible_plots(unlocked.home).size() == 19, "frontier reveals next ring")
	var previous = 0
	for price in range(50, 328051, 137):
		var value = Home.daily_value(price)
		check(value >= previous and value <= 100, "increasing price never reduces daily value")
		previous = value
	observed["plot_count"] = plots.size()
	observed["first_ring_types"] = types.keys()
	observed["outer_ring_value"] = Home.daily_value(328050)


func _test_calendar_and_items() -> void:
	check(Home.day_key(57599) == 0 and Home.day_key(57600) == 1, "Beijing midnight exact boundary")
	var state = Home.initial_state(22000)
	var initial = Home.daily_snapshot(state, 22000)
	check(initial.days == [22000] and initial.castle_gold == 100 and initial.castle_tickets == 1, "castle earns on initialization day")
	check(initial.items.is_empty(), "initial castle has no manufactured items")
	var unlocked = Home.unlock(state, "1,0", 1000, 0, 22000)
	state = unlocked.home
	check(Home.daily_snapshot(state, 22000).items.is_empty(), "new building produces next day only")
	var next = Home.daily_snapshot(state, 22001)
	check(next.days.size() == 2 and next.items.size() == 1 and next.items[0].quantity == 1, "new building next-day eligibility")
	var missed = Home.daily_snapshot(state, 22009)
	check(missed.days == [22007, 22008, 22009] and missed.castle_gold == 300, "missed rewards capped to latest three days")
	check(missed.items[0].quantity == 3, "three daily items per eligible building")
	state.owned["0,1"] = 22008
	missed = Home.daily_snapshot(state, 22009)
	var new_count = 0
	for item in missed.items:
		if item.plot_id == "0,1":
			new_count = item.quantity
	check(new_count == 1, "new plot cannot backfill earlier days")
	state.last_claim_day = 22009
	check(not Home.daily_snapshot(state, 22009).can_claim, "same day not claimable")
	check(not Home.daily_snapshot(state, 22008).can_claim, "clock rollback never reopens reward")
	check(Home.daily_snapshot(state, 22010).days == [22010], "next day reopens precisely one day")
	check(Home.normalize_state({}).is_empty(), "missing home remains uninitialized until first access")
	observed["catchup_days"] = missed.days


func _test_conversion() -> void:
	var state = Home.initial_state(22000)
	state.owned["1,0"] = 22000
	state.last_claim_day = 22000
	var rng = RandomNumberGenerator.new()
	rng.seed = 92624001
	var value = int(Home.plot("1,0").value)
	var gold_values: Dictionary = {}
	var tickets = 0
	var samples = 3000
	for index in range(samples):
		var result = Home.settle_daily(state, 22001, rng)
		var item: Dictionary = result.reward.items[0]
		check(item.gold >= ceil(value * 0.8) and item.gold <= floor(value * 1.2), "random coins remain 80 to 120 percent")
		check(result.reward.gold == 100 + item.gold and result.reward.tickets == 1 + item.tickets, "castle guarantee plus exact item sum")
		check(result.home.last_claim_day == 22001 and state.last_claim_day == 22000, "settlement marks only returned state")
		gold_values[item.gold] = true
		tickets += int(item.tickets)
	var expected = samples * float(value) * 0.1 / 100.0
	check(gold_values.size() > 1, "coins actually random")
	check(absf(tickets - expected) < 6.0 * sqrt(expected + 1), "ticket rate follows value times ten percent divided by 100")
	observed["conversion_samples"] = samples
	observed["item_value"] = value
	observed["item_tickets_observed"] = tickets
	observed["item_tickets_expected"] = expected


func _test_store() -> void:
	var directory = "res://temp/qa/home-economy-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var path = directory.path_join("player_accounts.json")
	var store = ClockStore.new(path)
	var auth = store.authenticate_installation("ac".repeat(32), "", {"wallet_gold": 10000, "gacha_tickets": 2}, [], "bd".repeat(32))
	check(auth.ok, "isolated account created")
	var token = String(auth.session_token)
	check(not store.home_for_session("untrusted").ok, "unauthenticated state rejected")
	var first = store.home_for_session(token)
	check(first.ok and first.home_snapshot.can_claim and first.profile.home.started_day == 22000, "authoritative state initialization")
	var initialized_revision = int(first.profile_revision)
	check(store.home_for_session(token).profile_revision == initialized_revision, "read state does not churn revision")
	var claimed = store.claim_home_daily(token, initialized_revision, 22000)
	check(claimed.ok and claimed.profile.wallet_gold == 10100 and claimed.profile.gacha_tickets == 3, "castle atomic credit")
	var repeated = store.claim_home_daily(token, initialized_revision, 22000)
	check(repeated.already_claimed and repeated.reward == claimed.reward and repeated.profile == claimed.profile, "lost-response claim retry returns stored reward without credit")
	var stale = store.unlock_home_plot(token, "1,0", initialized_revision)
	check(stale.conflict and not stale.profile.home.owned.has("1,0"), "concurrent stale unlock returns CAS conflict")
	check(not store.unlock_home_plot(token, "7,7", int(claimed.profile_revision)).ok, "invalid plot rejected server-side")
	check(not store.unlock_home_plot(token, "3,0", int(claimed.profile_revision)).ok, "nonadjacent plot rejected server-side")
	var unlocked = store.unlock_home_plot(token, "1,0", int(claimed.profile_revision))
	check(unlocked.ok and unlocked.profile.wallet_gold == 10100 - int(Home.plot("1,0").cost), "server determines unlock cost")
	check(unlocked.profile.gacha_tickets == 4, "server grants exactly one unlock ticket")
	var retry = store.unlock_home_plot(token, "1,0", int(claimed.profile_revision))
	check(retry.already_unlocked and retry.profile == unlocked.profile, "unlock retry does not charge or grant twice")
	var tampered: Dictionary = unlocked.profile.duplicate(true)
	tampered.home = Home.initial_state(1)
	tampered.home.owned["8,0"] = 1
	tampered["_profile_revision"] = unlocked.profile_revision
	var saved = store.save_profile(token, tampered)
	check(saved.profile.home == unlocked.profile.home, "generic save cannot reset claims or forge ownership")
	var legacy: Dictionary = saved.profile.duplicate(true)
	legacy.erase("home")
	legacy.erase("wallet_gold")
	legacy["_profile_revision"] = saved.profile_revision
	saved = store.save_profile(token, legacy)
	check(saved.profile.home == unlocked.profile.home, "old client omission preserves authoritative home")
	check(saved.profile.wallet_gold == unlocked.profile.wallet_gold, "old client missing wallet field preserves actual post-unlock balance")
	store.today = 22010
	var pending = store.home_for_session(token)
	check(pending.home_snapshot.days == [22008, 22009, 22010], "server returns exact three-day preview")
	var wrong_day = store.claim_home_daily(token, int(pending.profile_revision), 22009)
	check(wrong_day.conflict and wrong_day.profile == pending.profile, "stale day preview cannot settle a changed batch")
	var before_failure = pending.profile.duplicate(true)
	store.fail_save = true
	var failed = store.claim_home_daily(token, int(pending.profile_revision), 22010)
	check(not failed.ok and failed.error == "storage_error", "failed persistence rejects claim")
	check(store.home_for_session(token).profile == before_failure, "failed persistence rolls back wallet and claim marker")
	var failed_unlock = store.unlock_home_plot(token, "0,1", int(pending.profile_revision))
	check(not failed_unlock.ok and store.home_for_session(token).profile == before_failure, "failed unlock rolls back gold ticket ownership")
	store.fail_save = false
	var batch = store.claim_home_daily(token, int(pending.profile_revision), 22010)
	check(batch.ok and batch.reward.days.size() == 3 and batch.reward.items[0].quantity == 3, "three-day transaction completes after recovered persistence")
	var auth_two = store.authenticate_installation("ef".repeat(32), "", {"wallet_gold": 5, "gacha_tickets": 0}, [], "fe".repeat(32))
	var second = store.home_for_session(String(auth_two.session_token))
	check(second.profile.home.owned.size() == 1 and second.profile.wallet_gold == 5, "other account never inherits home or wallet")
	check(store.unlock_home_plot(String(auth_two.session_token), "1,0", int(second.profile_revision)).error == "insufficient_gold", "server rejects insufficient funds")
	check(store.close(), "lifecycle lock released before restart")
	store = null
	store = ClockStore.new(path)
	store.today = 22010
	var resumed = store.authenticate_installation("ac".repeat(32), String(auth.refresh_token), {}, [], "bd".repeat(32))
	var reload = store.home_for_session(String(resumed.session_token))
	if reload.profile != batch.profile:
		for key in reload.profile:
			if reload.profile[key] != batch.profile.get(key):
				print("RESTART_DIFFERENCE ", key, " before=", JSON.stringify(batch.profile.get(key)), " after=", JSON.stringify(reload.profile[key]))
	check(reload.profile == batch.profile and not reload.home_snapshot.can_claim, "restart retains balances ownership claim and sampled outcome")
	var replay = store.claim_home_daily(String(resumed.session_token), 1, 22010)
	check(replay.already_claimed and replay.reward == batch.reward, "restart retries replay same item conversion")
	check(store.close(), "test store closed")
	store = null
	_remove_test_directory(directory)
	observed["server_day"] = 22010
	observed["restart_reward_gold"] = batch.reward.gold
	observed["restart_reward_tickets"] = batch.reward.tickets


func _test_protocol() -> void:
	var service = TransportProbe.new()
	var names: Array = []
	for method in service.get_script().get_base_script().get_script_method_list():
		if String(method.name).begins_with("_rpc_"):
			names.append(String(method.name))
	names.sort()
	check(names.size() == 27 and names.find("_rpc_submit_battle_command") == 26, "all frozen 27 deployed RPC indices retained")
	service._server_peer_sessions[4] = "bound-session"
	service._server_home_action(5, "bound-session", "claim", "", 1, 22000)
	check(service.responses.back().result.error == "invalid_session", "home RPC cannot use another peer's session")
	service._server_home_action(4, "bound-session", "admin", "", 1, 22000)
	check(service.responses.back().result.error == "invalid_home_action", "home RPC rejects arbitrary action")
	service._server_home_action(4, "bound-session", "unlock", "x".repeat(100), 1, 22000)
	check(service.responses.back().result.error == "invalid_home_action", "home RPC bounds plot input")
	var events: Array = []
	service.account_state_changed.connect(func(state): events.append(state))
	service._apply_account_operation("home_claim", {"profile": {"wallet_gold": 999, "home": Home.initial_state(22000)}, "profile_revision": 9, "home_snapshot": {"day": 22000, "can_claim": false}})
	check(service.current_profile.wallet_gold == 999 and service.current_profile_revision == 9, "home ACK applies profile and revision")
	check(events.size() == 1 and events[0].home_snapshot.day == 22000, "home ACK carries authoritative day to main")
	service._apply_account_operation("login_account", {"user_id": "other-account", "profile": {}, "profile_revision": 1})
	check(service.current_home_snapshot.is_empty(), "account change never carries old home snapshot")
	service.free()


func _remove_test_directory(path: String) -> void:
	var absolute = ProjectSettings.globalize_path(path)
	var root = ProjectSettings.globalize_path("res://temp/qa/")
	if not absolute.begins_with(root) or not path.get_file().begins_with("home-economy-"):
		check(false, "test cleanup rejects unexpected root")
		return
	_remove_contents(absolute)
	DirAccess.remove_absolute(absolute)


func _remove_contents(path: String) -> void:
	var directory = DirAccess.open(path)
	if directory == null:
		return
	for name in directory.get_files():
		DirAccess.remove_absolute(path.path_join(name))
	for name in directory.get_directories():
		var child = path.path_join(name)
		_remove_contents(child)
		DirAccess.remove_absolute(child)
