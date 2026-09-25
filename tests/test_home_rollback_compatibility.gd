extends Node
## Pure Store fixture. No transport instance, login UI, or real user credential.
## QA packs must have no OnlineRoom autoload and no server main scene.
const Store = preload("res://scripts/server/player_account_store.gd")
const Home = preload("res://scripts/shared/home_rules.gd")
var checks: Array = []
var failures = 0
var store
var fixture_path = ""
var original_environment: Dictionary = {}

func _ready() -> void:
	# Do not let inherited dashboard paths escape the isolated fixture directory.
	for key in ["ZHANCHENG_DASHBOARD_ACCOUNT_SNAPSHOT_PATH", "ZHANCHENG_DASHBOARD_COMMAND_ROOT"]:
		original_environment[key] = OS.get_environment(key)
		OS.set_environment(key, "")
	var root = OS.get_environment("HOME_ROLLBACK_QA_ROOT").replace("\\", "/").trim_suffix("/")
	if root.is_empty(): root = "res://temp/qa/home-rollback-qa"
	if not check(root.get_file() == "home-rollback-qa", "explicit fixture root is scoped to home-rollback-qa"):
		_finish()
		return
	fixture_path = root.path_join("fixture-%d-%s" % [Time.get_ticks_usec(), Crypto.new().generate_random_bytes(4).hex_encode()]).path_join("accounts.json")
	if not check(not FileAccess.file_exists(fixture_path), "fixture never overwrites an existing authority file"):
		_finish()
		return
	var state = Home.initial_state(22000)
	state.owned["1,0"] = 22000
	state.owned["0,1"] = 22002
	state.last_claim_day = 22001
	var rng = RandomNumberGenerator.new()
	rng.seed = 250925
	var settled = Home.settle_daily(state, 22004, rng)
	check(bool(settled.ok) and not settled.reward.items.is_empty(), "fixture contains sampled multi-building daily reward")
	var profile = {"wallet_gold": 1379, "gacha_tickets": 19, "home": settled.home, "card_counts": {"mouse": 5}, "card_levels": {"mouse": 3}, "deck": ["mouse"], "rank_stars": 7, "rank_key": "bronze", "elo": 1234}
	var installation = Crypto.new().generate_random_bytes(32).hex_encode()
	var recovery = Crypto.new().generate_random_bytes(32).hex_encode()
	store = Store.new(fixture_path)
	if not check(store.is_authority_storage_ready(), "isolated store ready"):
		_finish()
		return
	var created: Dictionary = store.authenticate_installation(installation, "", profile, ["mouse"], recovery)
	if not check(bool(created.get("ok", false)), "synthetic fixture account written using baseline store API"):
		_finish()
		return
	var expected = _protected_view(profile)
	var refresh = String(created.refresh_token)
	check(_protected_view(created.profile) == expected, "fixture write retains every home reward and balance field")
	check(store.close(), "fixture authority lock released before rollback load")
	store = null
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	check(typeof(raw) == TYPE_DICTIONARY and int(raw.get("version", 0)) == 3, "on-disk fixture is existing authority schema v3")
	store = Store.new(fixture_path)
	check(not store.has_method("home_for_session") and not store.has_method("claim_home_daily"), "tested store is compatibility rollback without home transactions")
	var auth: Dictionary = store.authenticate_installation(installation, refresh, {}, ["mouse"], recovery)
	if not check(bool(auth.get("ok", false)), "rollback loads the existing synthetic installation"):
		_finish()
		return
	var token = String(auth.session_token)
	var loaded: Dictionary = store.profile_for_session(token)
	check(bool(loaded.get("ok", false)) and _protected_view(loaded.get("profile", {})) == expected, "rollback profile read retains owned, claim day, sampled reward, gold and ticket")
	var legacy: Dictionary = loaded.profile.duplicate(true)
	legacy.erase("home")
	legacy.erase("wallet_gold")
	legacy["_profile_revision"] = loaded.profile_revision
	legacy.rank_stars = 8
	var saved: Dictionary = store.save_profile(token, legacy)
	check(bool(saved.get("ok", false)) and not bool(saved.get("conflict", false)), "old client save without home/wallet succeeds at current revision")
	check(_protected_view(saved.get("profile", {})) == expected, "old save preserves exact home receipt, ownership and balances")
	check(int(saved.profile.rank_stars) == 8, "old save still applies its unrelated rank update")
	var tampered: Dictionary = saved.profile.duplicate(true)
	tampered.home = Home.initial_state(1)
	tampered.home.owned["8,0"] = 1
	tampered["_profile_revision"] = saved.profile_revision
	var rejected_home: Dictionary = store.save_profile(token, tampered)
	check(_protected_view(rejected_home.get("profile", {})) == expected, "rollback generic save cannot overwrite home with stale or forged ownership")
	check(store.close(), "rollback lock released before second restart")
	store = null
	store = Store.new(fixture_path)
	var after_auth: Dictionary = store.authenticate_installation(installation, refresh, {}, ["mouse"], recovery)
	if not check(bool(after_auth.get("ok", false)), "second store process-equivalent reopen authenticates same fixture"):
		_finish()
		return
	var reopened: Dictionary = store.profile_for_session(String(after_auth.session_token))
	check(_protected_view(reopened.get("profile", {})) == expected, "reopen retains exact owned, last_claim_day, last_reward, gold and ticket")
	check(int(reopened.profile.rank_stars) == 8, "unrelated old-client progress is durable")
	check(not Home.daily_snapshot(reopened.profile.home, 22004).can_claim, "rollback cannot recreate the already claimed daily reward")
	_finish()

func _protected_view(profile: Dictionary) -> Dictionary:
	return {"wallet_gold": profile.get("wallet_gold", -1), "gacha_tickets": profile.get("gacha_tickets", -1), "home": profile.get("home", {})}

func check(ok: bool, label: String) -> bool:
	checks.append({"ok": ok, "label": label})
	if not ok:
		failures += 1
		push_error("HOME_ROLLBACK: " + label)
	return ok

func _finish() -> void:
	if store != null:
		check(store.close(), "final fixture lifecycle lock released")
		store = null
	for key in original_environment:
		OS.set_environment(key, original_environment[key])
	var result = {"checks": checks.size(), "failures": failures, "results": checks, "fixture_path": fixture_path, "fixture_sha256": FileAccess.get_sha256(fixture_path) if FileAccess.file_exists(fixture_path) else "", "network_used": false, "default_credentials_used": false, "scope": "Pure compatibility rollback Store using existing v3 synthetic fixture, old save and reopen"}
	print("HOME_ROLLBACK_COMPATIBILITY ", JSON.stringify(result))
	if not fixture_path.is_empty() and DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(fixture_path.get_base_dir())):
		var file = FileAccess.open(fixture_path.get_base_dir().path_join("result.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(result, "\t"))
			file.close()
	get_tree().quit(1 if failures else 0)
