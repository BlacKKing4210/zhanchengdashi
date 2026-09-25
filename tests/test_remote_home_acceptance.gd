extends Node
## Explicitly armed staging-only client. Launch in a child process with APPDATA
## redirected to HOME_QA_DATA_ROOT before Godot starts (autoloads run first).
## Never print or include raw account operation responses in evidence.
const Home = preload("res://scripts/shared/home_rules.gd")
const HOST = "106.15.61.103"
const PORT = 24567
const OUT = "res://temp/qa/home-polish-20260925/"
const DATA_MARKER = "remote-home-appdata"
var transport: Node
var checks: Array = []
var trace: Array = []
var replies: Dictionary = {}
var failures = 0
var run_id = ""
var credential_path = ""
var checkpoint_path = ""
var resume = false
var capability_only = false
var network_used = false

func _ready() -> void:
	var audio = get_node_or_null("/root/GameAudio")
	if audio != null:
		audio.set_music_enabled(false)
		audio.set_sfx_enabled(false)
	call_deferred("_run")

func _run() -> void:
	var args = OS.get_cmdline_user_args()
	if not args.has("--home-qa-approved-staging"):
		print("REMOTE_HOME_NOT_ARMED: no network request or test account creation")
		get_tree().quit(2)
		return
	var isolated_root = OS.get_environment("HOME_QA_DATA_ROOT").replace("\\", "/").trim_suffix("/")
	var actual_root = ProjectSettings.globalize_path("user://").replace("\\", "/")
	if not check(isolated_root.get_file() == DATA_MARKER and actual_root.to_lower().begins_with(isolated_root.to_lower() + "/"), "autoload user data is inside explicit isolated QA root"):
		_finish("ISOLATION_REJECTED")
		return
	resume = args.has("--home-qa-resume")
	capability_only = args.has("--home-qa-capability-only")
	run_id = OS.get_environment("HOME_QA_RUN_ID").strip_edges().to_lower()
	if run_id.is_empty() and not resume: run_id = Crypto.new().generate_random_bytes(8).hex_encode()
	if not check(run_id.length() == 16 and run_id.is_valid_hex_number(false), "unique QA run id is valid"):
		_finish("INVALID_RUN_ID")
		return
	credential_path = "user://qa/remote_home_" + run_id + ".json"
	checkpoint_path = OUT + "remote-home-" + run_id + "-checkpoint.json"
	if resume:
		if not check(FileAccess.file_exists(credential_path) and FileAccess.file_exists(checkpoint_path), "resume has the dedicated QA credential and checkpoint"):
			_finish("MISSING_RESUME_STATE")
			return
	else:
		if not check(not FileAccess.file_exists(credential_path) and not FileAccess.file_exists(checkpoint_path), "fresh run never overwrites an existing account credential"):
			_finish("RUN_ID_COLLISION")
			return
		_write_credentials(true)
		if failures > 0:
			_finish("QA_CREDENTIAL_WRITE_FAILED")
			return
	transport = get_node("/root/OnlineRoom")
	transport.stop_transport()
	transport.set("_device_credential_path", credential_path)
	transport.operation_completed.connect(_on_complete)
	transport.operation_failed.connect(_on_failure)
	if not await _connect():
		_finish("CONNECTION_OR_AUTH_FAILED")
		return
	if not resume:
		# An unknown installation plus a nonempty invalid token cannot create an
		# account. This reads capability from the normal rejected-auth reply.
		var rejected = await _reply("authenticate_installation")
		if not check(not bool(rejected.get("ok", false)) and rejected.get("error", "") == "invalid_device_credentials", "read-only capability probe rejects synthetic stale credential"):
			_finish("CAPABILITY_PROBE_FAILED")
			return
		if not check(transport.server_home_rpc_supported, "server advertises HomeRPC before creating QA account"):
			_finish("OLD_SERVER_NO_ACCOUNT_CREATED")
			return
		if capability_only:
			_finish("CAPABILITY_SUPPORTED")
			return
		# The same never-registered installation is now explicitly authorized to
		# create one synthetic account on the freshly deployed home-capable server.
		transport.set("_refresh_token", "")
		transport.call("_save_device_credentials")
		replies.erase("authenticate_installation")
		if not check(transport.authenticate_default_account(), "synthetic account authentication sent"):
			_finish("AUTH_SEND_FAILED")
			return
	var authenticated = await _reply("authenticate_installation")
	if not check(bool(authenticated.get("ok", false)) and not transport.current_user_id.is_empty(), "dedicated synthetic account authenticated"):
		_finish("AUTH_FAILED")
		return
	# Allow the existing automatic credential setup to finish before reading a
	# profile; its reply uses the same account-state delivery path.
	await get_tree().create_timer(0.35).timeout
	var auto_deadline = Time.get_ticks_msec() + 15000
	while bool(transport.get("_auto_credential_request_pending")) and Time.get_ticks_msec() < auto_deadline:
		await get_tree().process_frame
	if not check(not bool(transport.get("_auto_credential_request_pending")), "automatic synthetic credential setup completed"):
		_finish("AUTO_CREDENTIAL_TIMEOUT")
		return
	var state = await _action("state")
	if not _ok(state, "server returns authoritative home state"):
		_finish("HOME_STATE_FAILED")
		return
	if resume:
		var checkpoint: Variant = JSON.parse_string(FileAccess.get_file_as_string(checkpoint_path))
		check(typeof(checkpoint) == TYPE_DICTIONARY and _persistent_view(state) == checkpoint, "new client process retains checkpoint after server restart")
		_finish("RESUME_PASS" if failures == 0 else "RESUME_FAILED")
		return
	var initial: Dictionary = state.profile
	check(initial.home.owned.size() == 1 and initial.home.owned.has("0,0"), "new account starts with castle only")
	var snapshot: Dictionary = state.home_snapshot
	var day = int(snapshot.day)
	if not check(bool(snapshot.can_claim) and int(snapshot.castle_gold) == 100 and int(snapshot.castle_tickets) == 1, "new account has exactly first-day castle income"):
		_finish("NO_FRESH_CASTLE_INCOME")
		return
	var claim_revision = int(state.profile_revision)
	var claimed = await _action("claim", "", day)
	if not _ok(claimed, "castle claim committed"):
		_finish("CLAIM_FAILED")
		return
	check(int(claimed.profile.wallet_gold) == int(initial.wallet_gold) + 100 and int(claimed.profile.gacha_tickets) == int(initial.gacha_tickets) + 1, "castle claim adds exactly 100 coins and one ticket")
	check(int(claimed.reward.gold) == 100 and int(claimed.reward.tickets) == 1 and claimed.reward.items.is_empty(), "castle receipt has no unearned building items")
	var repeated_claim = await _raw_action("claim", "", claim_revision, day)
	check(_same_balance_and_home(claimed, repeated_claim) and bool(repeated_claim.get("already_claimed", false)), "exact stale-revision claim retry is idempotent")
	var cheapest: Dictionary = {}
	for plot in Home.visible_plots(claimed.profile.home):
		if plot.id == "0,0" or not Home.can_unlock(claimed.profile.home, plot.id, 2147483647).ok: continue
		if cheapest.is_empty() or int(plot.cost) < int(cheapest.cost): cheapest = plot
	if not check(not cheapest.is_empty() and int(claimed.profile.wallet_gold) >= int(cheapest.cost), "castle income funds cheapest adjacent plot without administrator grant"):
		_finish("INSUFFICIENT_SYNTHETIC_FUNDS")
		return
	var unlock_revision = int(claimed.profile_revision)
	var unlocked = await _action("unlock", cheapest.id)
	if not _ok(unlocked, "cheapest adjacent unlock committed"):
		_finish("UNLOCK_FAILED")
		return
	check(int(unlocked.profile.wallet_gold) == int(claimed.profile.wallet_gold) - int(cheapest.cost), "unlock deducts exact configured coin price")
	check(int(unlocked.profile.gacha_tickets) == int(claimed.profile.gacha_tickets) + 1, "unlock awards exactly one immediate ticket")
	check(unlocked.profile.home.owned.size() == 2 and int(unlocked.profile.home.owned[cheapest.id]) == day, "unlocked plot records the server day")
	check(not bool(unlocked.home_snapshot.can_claim) and unlocked.home_snapshot.items.is_empty(), "new building earns no same-day production")
	var repeated_unlock = await _raw_action("unlock", cheapest.id, unlock_revision, -1)
	check(_same_balance_and_home(unlocked, repeated_unlock) and bool(repeated_unlock.get("already_unlocked", false)), "exact stale-revision unlock retry does not spend or grant twice")
	var checkpoint = _persistent_view(unlocked)
	_write_json(checkpoint_path, checkpoint)
	transport.disconnect_from_server()
	await get_tree().create_timer(0.25).timeout
	replies.clear()
	if not await _connect():
		_finish("RECONNECT_FAILED")
		return
	var relogin = await _reply("authenticate_installation")
	if not check(bool(relogin.get("ok", false)), "same isolated credential reconnects successfully"):
		_finish("REAUTH_FAILED")
		return
	await get_tree().create_timer(0.3).timeout
	var restored = await _action("state")
	check(_persistent_view(restored) == checkpoint, "disconnect/reconnect preserves wallet, ticket, claim day and owned plot")
	_finish("PASS" if failures == 0 else "FAILED")

func _connect() -> bool:
	replies.erase("authenticate_installation")
	network_used = true
	if not check(int(transport.connect_to_server(HOST, PORT, "家园验收")) == OK, "staging ENet connection requested"):
		return false
	# Disable fallback before ENet can deliver the first authentication response.
	transport.set("_automatic_auth_retry_used", true)
	var deadline = Time.get_ticks_msec() + 15000
	while not transport.is_connected_to_server() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return check(transport.is_connected_to_server(), "external staging ENet connected")

func _action(action: String, id: String = "", day: int = -1) -> Dictionary:
	var operation = "home_" + action
	replies.erase(operation)
	var sent = false
	match action:
		"state": sent = transport.request_home_state()
		"claim": sent = transport.claim_home_daily(day)
		"unlock": sent = transport.unlock_home_plot(id)
	if not sent: return {"ok": false, "error": "send_failed"}
	return await _reply(operation)

func _raw_action(action: String, id: String, revision: int, day: int) -> Dictionary:
	var operation = "home_" + action
	replies.erase(operation)
	transport.get_node("HomeRpc").rpc_id(1, "execute", transport.get("_client_session_token"), action, id, revision, day)
	return await _reply(operation)

func _reply(operation: String) -> Dictionary:
	var deadline = Time.get_ticks_msec() + 15000
	while not replies.has(operation) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not replies.has(operation):
		check(false, "bounded response timeout for " + operation)
		return {"ok": false, "error": "timeout"}
	return replies[operation].duplicate(true)

func _on_complete(operation: String, result: Dictionary) -> void:
	replies[operation] = result.duplicate(true)
	var safe = {"operation": operation, "ok": true, "home_rpc_v1": bool(result.get("home_rpc_v1", false))}
	if typeof(result.get("profile")) == TYPE_DICTIONARY:
		safe.wallet_gold = int(result.profile.get("wallet_gold", -1))
		safe.gacha_tickets = int(result.profile.get("gacha_tickets", -1))
		safe.profile_revision = int(result.get("profile_revision", -1))
	trace.append(safe)

func _on_failure(operation: String, error: String) -> void:
	replies[operation] = {"ok": false, "error": error}
	trace.append({"operation": operation, "ok": false, "error": error})

func _ok(result: Dictionary, label: String) -> bool:
	return check(bool(result.get("ok", false)) and not bool(result.get("conflict", false)) and typeof(result.get("profile")) == TYPE_DICTIONARY and typeof(result.get("home_snapshot")) == TYPE_DICTIONARY, label)

func _same_balance_and_home(a: Dictionary, b: Dictionary) -> bool:
	return bool(b.get("ok", false)) and _persistent_view(a) == _persistent_view(b)

func _persistent_view(result: Dictionary) -> Dictionary:
	var profile: Dictionary = result.get("profile", {})
	return {"user_id": result.get("user_id", ""), "wallet_gold": profile.get("wallet_gold", -1), "gacha_tickets": profile.get("gacha_tickets", -1), "home": profile.get("home", {})}

func _write_credentials(stale: bool) -> void:
	_write_json(credential_path, {"version": 3, "installation_id": Crypto.new().generate_random_bytes(32).hex_encode(), "refresh_token": Crypto.new().generate_random_bytes(32).hex_encode() if stale else "", "recovery_secret": Crypto.new().generate_random_bytes(32).hex_encode(), "server_identity": "%s:%d" % [HOST, PORT]})

func _write_json(path: String, value: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		check(false, "QA output write available")
		return
	file.store_string(JSON.stringify(value, "\t"))
	file.close()

func check(ok: bool, label: String) -> bool:
	checks.append({"ok": ok, "label": label})
	if not ok:
		failures += 1
		push_error("REMOTE_HOME: " + label)
	return ok

func _finish(status: String) -> void:
	if transport != null: transport.stop_transport()
	var result = {"status": status, "run_id": run_id, "checks": checks, "failures": failures, "trace": trace, "network_used": network_used, "endpoint": "%s:%d" % [HOST, PORT], "resume": resume, "credential_scope": "isolated QA APPDATA, unique installation, no real user credential access", "limits": "staging synthetic account only; reconnect is not server restart proof unless a separate --home-qa-resume is run after producer restart"}
	_write_json(OUT + "remote-home-" + run_id + ("-resume" if resume else "") + ".json", result)
	print("REMOTE_HOME_ACCEPTANCE ", JSON.stringify(result))
	get_tree().quit(0 if status in ["PASS", "RESUME_PASS", "CAPABILITY_SUPPORTED"] and failures == 0 else 1)
