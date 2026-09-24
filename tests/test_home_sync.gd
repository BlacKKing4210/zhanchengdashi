extends Node
const Base = preload("res://tests/test_online_rewards_release.gd")
const Rules = preload("res://scripts/shared/home_rules.gd")
class TestApp extends Base.TestApp:
	var sent = 0
	func _dispatch_home_action(_action: String, _id: String, _day: int) -> bool:
		sent += 1
		return true
var checks = 0
var failures = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func _ready() -> void:
	GameAudio.sfx_enabled = false
	GameAudio.set_music_enabled(false)
	var app = TestApp.new()
	add_child(app)
	await get_tree().process_frame
	app.set_process(false)
	OnlineRoom.current_user_id = "fixture-home-sync"
	OnlineRoom.server_home_rpc_supported = true
	app.account_applied_user_id = OnlineRoom.current_user_id
	app.wallet_gold = 100
	var view = app._ensure_home()
	view.available = true
	view.state = Rules.initial_state(Rules.day_key())
	view.snapshot = Rules.daily_snapshot(view.state, Rules.day_key())
	var baseline = app._server_profile_snapshot().duplicate(true)
	app.account_confirmed_profile = baseline.duplicate(true)
	app.account_profile_signature = JSON.stringify(baseline)
	app.account_pending_profile = baseline.duplicate(true)
	app._home_request("state")
	app._home_update_request(0.01)
	check(app.sent == 0, "home waits for outstanding generic save")
	app.account_pending_profile.clear()
	app._home_update_request(0.01)
	check(app.sent == 1, "home sends once after exact balance sync")
	app.wallet_gold += 20
	app.gacha_tickets += 2
	app._home_update_request(16.0)
	check(not view.busy, "timeout releases UI")
	app._home_request("claim")
	app._home_update_request(0.01)
	check(app.sent == 1, "uncertain operation cannot be replaced by a retry")
	app._update_server_profile_sync(2.0)
	check(app.account_pending_profile.is_empty(), "uncertain operation pauses generic saves")
	# The same protected scenario is used before and after the repair.
	app._on_account_state_changed({"logged_in": true, "user_id": OnlineRoom.current_user_id, "operation": "home_state", "profile": baseline})
	check(app.wallet_gold == 120, "late home ACK preserves 20 earned gold after timeout")
	check(app.gacha_tickets == int(baseline.gacha_tickets) + 2, "late home ACK preserves earned tickets after timeout")
	app._home_operation_completed("home_state", {"profile": baseline, "home_snapshot": view.snapshot})
	check(app.wallet_gold == 120, "completion handler never adds or drops deltas twice")
	app.wallet_gold = 0
	app.screen = "lobby"
	view.snapshot.day = Rules.day_key() - 1
	view.snapshot.can_claim = false
	view.update(0.1)
	check(view.busy and app.home_pending_action.get("action", "") == "state", "midnight refresh requests authoritative state outside home")
	app._home_operation_completed("home_state", {"home_snapshot": Rules.daily_snapshot(view.state, Rules.day_key())})
	check(view.has_dot(), "authoritative new-day reward dots tab without opening home")
	view.snapshot.day = Rules.day_key() - 1
	view.update(0.1)
	check(app.home_pending_action.is_empty(), "clock mismatch does not spam server refresh every frame")
	app._home_reset_account()
	check(not view.available and view.snapshot.is_empty() and not view.busy, "account reset clears home ownership availability")
	OnlineRoom.current_user_id = ""
	OnlineRoom.server_home_rpc_supported = false
	print("HOME_SYNC checks=%d failures=%d" % [checks, failures])
	app.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
