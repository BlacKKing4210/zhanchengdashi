extends Node

const MatchAnalyticsStore = preload("res://scripts/server/match_analytics_store.gd")
const PlayerAccountStore = preload("res://scripts/server/player_account_store.gd")
const OnlineRoomTransport = preload("res://scripts/network/online_room.gd")

const TEST_ROOT = "user://tests/admin_backend_features"
const ANALYTICS_PATH = TEST_ROOT + "/match_analytics.json"
const DASHBOARD_PATH = TEST_ROOT + "/dashboard_snapshot.json"
const ACCOUNT_PATH = TEST_ROOT + "/player_accounts.json"
const LEGACY_ACCOUNT_PATH = TEST_ROOT + "/legacy_player_accounts.json"
const RECOVERY_ACCOUNT_PATH = TEST_ROOT + "/recovery_player_accounts.json"
const PRIMARY_PRIORITY_ACCOUNT_PATH = TEST_ROOT + "/primary_priority_player_accounts.json"
const CORRUPT_ACCOUNT_PATH = TEST_ROOT + "/corrupt_player_accounts.json"
const FUTURE_ACCOUNT_PATH = TEST_ROOT + "/future_player_accounts.json"
const DECIMAL_VERSION_ACCOUNT_PATH = TEST_ROOT + "/decimal_version_player_accounts.json"
const ATOMIC_LOCK_ACCOUNT_PATH = TEST_ROOT + "/atomic_lock_player_accounts.json"
const PROFILE_READ_ROLLBACK_ACCOUNT_PATH = TEST_ROOT + "/profile_read_rollback_accounts.json"
const PROFILE_SAVE_ROLLBACK_ACCOUNT_PATH = TEST_ROOT + "/profile_save_rollback_accounts.json"
const ENVIRONMENT_ACCOUNT_PATH = TEST_ROOT + "/environment/player_accounts.json"
const SERVER_START_ACCOUNT_PATH = TEST_ROOT + "/server_start/player_accounts.json"
const FOREIGN_TOKEN_ACCOUNT_PATH = TEST_ROOT + "/foreign_token/player_accounts.json"
const CRASH_LOCK_ACCOUNT_PATH = TEST_ROOT + "/crash_lock/player_accounts.json"
const ACCOUNT_SNAPSHOT_PATH = TEST_ROOT + "/admin_accounts_snapshot.json"
const CORRUPT_SNAPSHOT_PATH = TEST_ROOT + "/corrupt/admin_accounts_snapshot.json"
const FUTURE_SNAPSHOT_PATH = TEST_ROOT + "/future/admin_accounts_snapshot.json"
const COMMAND_ROOT = TEST_ROOT + "/admin_commands"
const LEGACY_KNOWN_ACCOUNT = "Legacy00"
const LEGACY_KNOWN_PASSWORD = "legacy-safe-pass-2026"

var failures = 0
var opened_account_stores: Array = []


func _ready() -> void:
	_remove_tree(TEST_ROOT)
	OS.set_environment("ZHANCHENG_DASHBOARD_SNAPSHOT_PATH", ProjectSettings.globalize_path(DASHBOARD_PATH))
	OS.set_environment("ZHANCHENG_DASHBOARD_ACCOUNT_SNAPSHOT_PATH", ProjectSettings.globalize_path(ACCOUNT_SNAPSHOT_PATH))
	OS.set_environment("ZHANCHENG_DASHBOARD_COMMAND_ROOT", ProjectSettings.globalize_path(COMMAND_ROOT))
	_test_environment_path_contract()
	_test_server_start_rejects_competing_authority_writer()
	_test_placement_aggregation_and_legacy_backfill()
	_test_legacy_account_store_migration()
	_test_authority_primary_priority_and_previous_recovery()
	_test_corrupt_and_future_authority_fail_closed()
	_test_decimal_version_and_unavailable_directory_fail_closed()
	_test_authority_lifecycle_lock_is_exclusive_and_recoverable()
	_test_storage_failure_rolls_back_memory()
	_test_account_projection_grants_idempotency_and_cas()
	OS.set_environment("ZHANCHENG_DASHBOARD_SNAPSHOT_PATH", "")
	OS.set_environment("ZHANCHENG_DASHBOARD_ACCOUNT_SNAPSHOT_PATH", "")
	OS.set_environment("ZHANCHENG_DASHBOARD_COMMAND_ROOT", "")
	_close_all_account_stores()
	_remove_tree(TEST_ROOT)
	if failures == 0:
		print("ADMIN_BACKEND_FEATURES_TEST_PASS")
	else:
		push_error("ADMIN_BACKEND_FEATURES_TEST_FAIL: %d failure(s)" % failures)
	get_tree().quit(failures)


func _test_environment_path_contract() -> void:
	var transport = OnlineRoomTransport.new()
	transport.set("_account_store_factory", func(): return _open_account_store(ENVIRONMENT_ACCOUNT_PATH))
	var account_store = transport.call("_create_account_store")
	var analytics_store = transport.call("_create_match_analytics_store")
	_expect(account_store != null and analytics_store != null, "OnlineRoom creates both no-argument dedicated-server stores")
	if account_store != null:
		_expect(String(account_store.admin_accounts_snapshot_path) == ProjectSettings.globalize_path(ACCOUNT_SNAPSHOT_PATH), "no-argument account store resolves ZHANCHENG_DASHBOARD_ACCOUNT_SNAPSHOT_PATH")
		_expect(String(account_store.admin_command_root) == ProjectSettings.globalize_path(COMMAND_ROOT), "no-argument account store resolves ZHANCHENG_DASHBOARD_COMMAND_ROOT")
	if analytics_store != null:
		_expect(String(analytics_store.dashboard_path) == ProjectSettings.globalize_path(DASHBOARD_PATH), "no-argument analytics store resolves ZHANCHENG_DASHBOARD_SNAPSHOT_PATH")
	_expect(_close_account_store(account_store), "environment contract test explicitly releases its lifecycle lock")


func _test_server_start_rejects_competing_authority_writer() -> void:
	var authority_owner = _open_account_store(SERVER_START_ACCOUNT_PATH)
	_expect(bool(authority_owner.call("is_authority_storage_ready")), "test authority owner acquires its isolated lifecycle lock")
	var competing_transport = OnlineRoomTransport.new()
	competing_transport.set("_account_store_factory", func(): return _open_account_store(SERVER_START_ACCOUNT_PATH))
	add_child(competing_transport)
	var start_error: Error = competing_transport.start_server("127.0.0.1", 29876, null, 1)
	_expect(start_error != OK, "server startup returns a non-zero error while another authority writer owns the lifecycle lock")
	_expect(int(competing_transport.mode) == 0, "server remains offline after authority lifecycle lock rejection")
	competing_transport.stop_transport()
	competing_transport.free()
	competing_transport = null
	_expect(_close_account_store(authority_owner), "server-start authority owner explicitly releases its lifecycle lock")
	authority_owner = null


func _test_placement_aggregation_and_legacy_backfill() -> void:
	var store = MatchAnalyticsStore.new(ANALYTICS_PATH, DASHBOARD_PATH)
	var catalog = {"rabbit": "兔子", "wolf": "狼", "duck": "鸭子"}
	_expect(bool(store.register_animal_catalog(catalog).get("ok", false)), "animal catalog is registered")
	var roster = [
		{"user_id": "U-ONE", "team_id": 1, "deck": ["rabbit"], "card_levels": {"rabbit": 2}},
		{"user_id": "U-TWO", "team_id": 2, "deck": ["wolf"], "card_levels": {"wolf": 2}},
		{"user_id": "U-THREE", "team_id": 3, "deck": ["duck"], "card_levels": {"duck": 2}},
	]
	_expect(bool(store.begin_match({"match_id": "placement-ffa-1", "map_id": "ffa_test"}, roster, catalog).get("ok", false)), "placement test match begins")
	_expect(bool(store.finalize_match("placement-ffa-1", {
		"team_outcomes": {"1": "win", "2": "loss", "3": "loss"},
		"placements_by_team": {"1": 1, "2": 2, "3": 3},
	}).get("ok", false)), "placement test match finalizes")
	var animals: Dictionary = store.data.get("animals", {})
	_expect_close(float((animals.get("rabbit", {}) as Dictionary).get("placement_sum", -1.0)), 1.0, "winner placement sum is retained")
	_expect_close(float((animals.get("rabbit", {}) as Dictionary).get("placement_score_sum", -1.0)), 1.0, "winner normalized placement score is one")
	_expect_close(float((animals.get("wolf", {}) as Dictionary).get("placement_score_sum", -1.0)), 0.5, "middle normalized placement score is one half")
	_expect_close(float((animals.get("duck", {}) as Dictionary).get("placement_score_sum", -1.0)), 0.0, "last normalized placement score is zero")
	_expect(int((animals.get("rabbit", {}) as Dictionary).get("placement_field_size_sum", 0)) == 3, "placement aggregate records field size")
	var dashboard = store.dashboard_snapshot()
	var rabbit_row = _row_by_id(dashboard.get("animals", []), "card_id", "rabbit")
	_expect_close(float(rabbit_row.get("average_placement", -1.0)), 1.0, "dashboard exposes animal average placement")
	_expect_close(float(rabbit_row.get("average_placement_score", -1.0)), 1.0, "dashboard exposes normalized average placement score")
	_expect(String(rabbit_row.get("balance_signal", "")) == "insufficient_samples", "small samples cannot trigger a balance adjustment")
	var confidence: Dictionary = rabbit_row.get("confidence", {})
	_expect(not bool(confidence.get("sample_sufficient", true)), "balance confidence declares insufficient samples")
	_expect(confidence.has("win_rate_lower") and confidence.has("win_rate_upper"), "balance confidence exposes Wilson bounds")

	var legacy_data = store.data.duplicate(true)
	legacy_data["version"] = 1
	legacy_data["placement_aggregation_version"] = 0
	for collection_name in ["animals", "players"]:
		var collection: Dictionary = legacy_data.get(collection_name, {})
		for record_id in collection:
			if typeof(collection[record_id]) != TYPE_DICTIONARY:
				continue
			var record: Dictionary = collection[record_id]
			for field_name in ["placement_samples", "placement_sum", "placement_score_sum", "placement_field_size_sum"]:
				record.erase(field_name)
			collection[record_id] = record
		legacy_data[collection_name] = collection
	_expect(_write_json(ANALYTICS_PATH, legacy_data), "legacy analytics fixture is written")
	var reloaded = MatchAnalyticsStore.new(ANALYTICS_PATH, DASHBOARD_PATH)
	var reloaded_rabbit: Dictionary = (reloaded.data.get("animals", {}) as Dictionary).get("rabbit", {})
	_expect(int(reloaded.data.get("placement_aggregation_version", 0)) == 1, "legacy placement migration is marked complete")
	_expect(int(reloaded_rabbit.get("placement_samples", 0)) == 1, "legacy finalized matches backfill placement samples")
	_expect_close(float(reloaded_rabbit.get("placement_score_sum", -1.0)), 1.0, "legacy finalized matches backfill normalized scores")


func _test_legacy_account_store_migration() -> void:
	var legacy_payload = _legacy_v2_account_payload()
	_expect(_write_json(LEGACY_ACCOUNT_PATH, legacy_payload), "24-account version 2 authority fixture is written")
	var legacy_text = _read_text(LEGACY_ACCOUNT_PATH)
	var legacy_disk_payload = JSON.parse_string(legacy_text)
	_expect(typeof(legacy_disk_payload) == TYPE_DICTIONARY, "version 2 authority fixture can be parsed before migration")
	var migrated = _open_account_store(LEGACY_ACCOUNT_PATH)
	_expect(bool(migrated.call("is_authority_storage_ready")), "version 2 authority remains ready after migration")
	_expect(migrated.admin_command_receipts.is_empty(), "missing admin receipt ledger migrates as an empty dictionary")
	var migrated_snapshot = migrated.admin_accounts_snapshot()
	var migrated_rows: Array = migrated_snapshot.get("accounts", [])
	_expect(migrated_rows.size() == 24, "all 24 legacy accounts remain available after migration")
	_expect(_deck_size_histogram(migrated_rows) == {0: 3, 2: 1, 3: 1, 8: 19}, "legacy deck distribution 0:3, 2:1, 3:1, 8:19 is preserved")
	var migrated_text = _read_text(LEGACY_ACCOUNT_PATH)
	var migrated_payload = JSON.parse_string(migrated_text)
	_expect(typeof(migrated_payload) == TYPE_DICTIONARY and int(migrated_payload.get("version", 0)) == 3, "legacy account authority file is upgraded to version 3")
	_expect(migrated_payload.has("admin_command_receipts") and (migrated_payload.get("admin_command_receipts", {}) as Dictionary).is_empty(), "migrated authority file persists the empty admin receipt ledger")
	if typeof(legacy_disk_payload) == TYPE_DICTIONARY and typeof(migrated_payload) == TYPE_DICTIONARY:
		var legacy_accounts: Dictionary = legacy_disk_payload.get("accounts", {})
		var migrated_accounts: Dictionary = migrated_payload.get("accounts", {})
		_expect(migrated_accounts.size() == legacy_accounts.size(), "migration preserves the exact account count")
		for account_key_value in legacy_accounts:
			var account_key = String(account_key_value)
			var expected_record: Dictionary = (legacy_accounts.get(account_key, {}) as Dictionary).duplicate(true)
			var actual_record: Dictionary = (migrated_accounts.get(account_key, {}) as Dictionary).duplicate(true)
			_expect(int(actual_record.get("profile_revision", 0)) == 1, "migration adds profile revision 1 for %s" % account_key)
			actual_record.erase("profile_revision")
			_expect(_same_json(actual_record, expected_record), "migration preserves credentials, timestamps, resources, levels, and deck for %s" % account_key)
		_expect((legacy_disk_payload.get("installations", {}) as Dictionary).size() == 13, "version 2 fixture contains the current 13-installation shape")
		_expect(_same_json(migrated_payload.get("installations", {}), legacy_disk_payload.get("installations", {})), "migration preserves all 13 installation bindings exactly")
		_expect(_same_json(migrated_payload.get("migration_marker", {}), legacy_disk_payload.get("migration_marker", {})), "migration preserves unknown top-level authority fields")
	_expect(_read_text("%s.previous" % LEGACY_ACCOUNT_PATH) == legacy_text, "migration keeps the exact version 2 authority as the previous generation")

	_expect(_close_account_store(migrated), "migration owner explicitly releases its lifecycle lock before restart")
	migrated = null
	var second_load = _open_account_store(LEGACY_ACCOUNT_PATH)
	_expect(bool(second_load.call("is_authority_storage_ready")), "second load of migrated authority remains ready")
	_expect(_read_text(LEGACY_ACCOUNT_PATH) == migrated_text, "second load is byte-idempotent and does not rewrite authority")
	var known_login: Dictionary = second_load.login(LEGACY_KNOWN_ACCOUNT, LEGACY_KNOWN_PASSWORD)
	_expect(bool(known_login.get("ok", false)), "known legacy password still logs in after migration")
	var old_client_profile: Dictionary = (known_login.get("profile", {}) as Dictionary).duplicate(true)
	old_client_profile["gacha_tickets"] = int(old_client_profile.get("gacha_tickets", 0)) + 1
	var first_old_client_save: Dictionary = second_load.save_profile(String(known_login.get("session_token", "")), old_client_profile)
	_expect(bool(first_old_client_save.get("ok", false)) and not bool(first_old_client_save.get("conflict", true)) and int(first_old_client_save.get("profile_revision", 0)) == 2, "pre-CAS client receives exactly one revision-free compatibility save")
	var repeated_old_client_save: Dictionary = second_load.save_profile(String(known_login.get("session_token", "")), old_client_profile)
	_expect(bool(repeated_old_client_save.get("ok", false)) and bool(repeated_old_client_save.get("conflict", false)), "second revision-free save is rejected as a CAS conflict")


func _test_authority_primary_priority_and_previous_recovery() -> void:
	var primary_payload = _single_v3_account_payload("PrimaryWinner", "U-PRIMARY-001", "primary-safe-pass-2026", "primary-salt")
	var previous_payload = _single_v3_account_payload("BackupOnly", "U-BACKUP-001", "backup-safe-pass-2026", "backup-salt")
	_expect(_write_json(PRIMARY_PRIORITY_ACCOUNT_PATH, primary_payload), "valid primary authority fixture is written")
	_expect(_write_json("%s.previous" % PRIMARY_PRIORITY_ACCOUNT_PATH, previous_payload), "different valid previous authority fixture is written")
	var primary_text = _read_text(PRIMARY_PRIORITY_ACCOUNT_PATH)
	var previous_text = _read_text("%s.previous" % PRIMARY_PRIORITY_ACCOUNT_PATH)
	var primary_store = _open_account_store(PRIMARY_PRIORITY_ACCOUNT_PATH)
	_expect(bool(primary_store.call("is_authority_storage_ready")), "valid primary authority is ready even when a previous generation exists")
	_expect(bool(primary_store.login("PrimaryWinner", "primary-safe-pass-2026").get("ok", false)), "valid primary authority wins over the previous generation")
	_expect(String(primary_store.login("BackupOnly", "backup-safe-pass-2026").get("error", "")) == "invalid_credentials", "previous-only account is not loaded while a valid primary exists")
	_expect(_read_text(PRIMARY_PRIORITY_ACCOUNT_PATH) == primary_text and _read_text("%s.previous" % PRIMARY_PRIORITY_ACCOUNT_PATH) == previous_text, "primary-priority load does not rewrite either generation")

	var recovery_payload = _single_v3_account_payload("RecoveredOwner", "U-RECOVERED-001", "recovery-safe-pass-2026", "recovery-salt")
	_expect(not FileAccess.file_exists(RECOVERY_ACCOUNT_PATH), "recovery primary starts missing")
	_expect(_write_json("%s.previous" % RECOVERY_ACCOUNT_PATH, recovery_payload), "valid previous generation is written for recovery")
	var recovery_store = _open_account_store(RECOVERY_ACCOUNT_PATH)
	_expect(bool(recovery_store.call("is_authority_storage_ready")), "missing primary recovers from a valid previous generation")
	_expect(FileAccess.file_exists(RECOVERY_ACCOUNT_PATH), "previous-generation recovery recreates the primary authority file")
	_expect(FileAccess.file_exists("%s.previous" % RECOVERY_ACCOUNT_PATH), "recovery retains the validated previous generation")
	_expect(bool(recovery_store.login("RecoveredOwner", "recovery-safe-pass-2026").get("ok", false)), "recovered authority accepts the preserved credential")


func _test_corrupt_and_future_authority_fail_closed() -> void:
	var original_snapshot_environment = OS.get_environment("ZHANCHENG_DASHBOARD_ACCOUNT_SNAPSHOT_PATH")
	OS.set_environment("ZHANCHENG_DASHBOARD_ACCOUNT_SNAPSHOT_PATH", ProjectSettings.globalize_path(CORRUPT_SNAPSHOT_PATH))
	var corrupt_text = "{corrupt-authority"
	var corrupt_snapshot_sentinel = "corrupt-snapshot-must-remain"
	_expect(_write_text(CORRUPT_ACCOUNT_PATH, corrupt_text), "corrupt authority fixture is written")
	_expect(_write_json("%s.previous" % CORRUPT_ACCOUNT_PATH, _single_v3_account_payload("ShouldNotRecover", "U-NO-RECOVERY-001", "no-recovery-pass-2026", "no-recovery-salt")), "valid previous generation exists behind corrupt primary")
	_expect(_write_text(CORRUPT_SNAPSHOT_PATH, corrupt_snapshot_sentinel), "corrupt-authority snapshot sentinel is written")
	var corrupt_store = _open_account_store(CORRUPT_ACCOUNT_PATH)
	_expect(not bool(corrupt_store.call("is_authority_storage_ready")), "corrupt existing primary fails closed")
	_expect(not bool(corrupt_store.call("is_admin_snapshot_ready")), "corrupt primary leaves the admin projection unready")
	_expect(String(corrupt_store.register_account("MustNotWrite", "must-not-write-2026").get("error", "")) == "authority_storage_unavailable", "corrupt primary blocks account writes")
	_expect(String(corrupt_store.process_admin_commands(["rabbit"]).get("error", "")) == "authority_storage_unavailable", "corrupt primary blocks admin grants")
	_expect(_read_text(CORRUPT_ACCOUNT_PATH) == corrupt_text, "corrupt primary is never overwritten by an empty authority")
	_expect(_read_text(CORRUPT_SNAPSHOT_PATH) == corrupt_snapshot_sentinel, "corrupt primary never overwrites the existing snapshot with an empty projection")

	OS.set_environment("ZHANCHENG_DASHBOARD_ACCOUNT_SNAPSHOT_PATH", ProjectSettings.globalize_path(FUTURE_SNAPSHOT_PATH))
	var future_payload = _single_v3_account_payload("FutureOwner", "U-FUTURE-001", "future-safe-pass-2026", "future-salt")
	future_payload["version"] = 4
	_expect(_write_json(FUTURE_ACCOUNT_PATH, future_payload), "future-version authority fixture is written")
	var future_text = _read_text(FUTURE_ACCOUNT_PATH)
	var future_snapshot_sentinel = "future-snapshot-must-remain"
	_expect(_write_text(FUTURE_SNAPSHOT_PATH, future_snapshot_sentinel), "future-version snapshot sentinel is written")
	var future_store = _open_account_store(FUTURE_ACCOUNT_PATH)
	_expect(not bool(future_store.call("is_authority_storage_ready")), "unsupported future authority version fails closed")
	_expect(String(future_store.login("FutureOwner", "future-safe-pass-2026").get("error", "")) == "authority_storage_unavailable", "future authority blocks login instead of guessing its schema")
	_expect(_read_text(FUTURE_ACCOUNT_PATH) == future_text, "future authority is never rewritten or downgraded")
	_expect(_read_text(FUTURE_SNAPSHOT_PATH) == future_snapshot_sentinel, "future authority never writes an empty admin projection")
	OS.set_environment("ZHANCHENG_DASHBOARD_ACCOUNT_SNAPSHOT_PATH", original_snapshot_environment)


func _test_decimal_version_and_unavailable_directory_fail_closed() -> void:
	var decimal_payload = _single_v3_account_payload("DecimalOwner", "U-DECIMAL-001", "decimal-safe-pass-2026", "decimal-salt")
	decimal_payload["version"] = 3.5
	_expect(_write_json(DECIMAL_VERSION_ACCOUNT_PATH, decimal_payload), "fractional authority version fixture is written")
	var decimal_text = _read_text(DECIMAL_VERSION_ACCOUNT_PATH)
	var decimal_store = _open_account_store(DECIMAL_VERSION_ACCOUNT_PATH)
	_expect(not bool(decimal_store.call("is_authority_storage_ready")), "fractional authority version fails closed instead of truncating to version 3")
	_expect(String(decimal_store.login("DecimalOwner", "decimal-safe-pass-2026").get("error", "")) == "authority_storage_unavailable", "fractional authority version blocks login")
	_expect(_read_text(DECIMAL_VERSION_ACCOUNT_PATH) == decimal_text, "fractional authority version is never rewritten")

	var blocker_path = TEST_ROOT + "/authority_parent_blocker"
	var blocker_text = "regular-file-parent-must-remain"
	_expect(_write_text(blocker_path, blocker_text), "authority parent blocker is written")
	var blocked_authority_path = blocker_path.path_join("player_accounts.json")
	var blocked_store = _open_account_store(blocked_authority_path)
	_expect(not bool(blocked_store.call("is_authority_storage_ready")), "unavailable authority parent fails closed instead of becoming an empty database")
	_expect(String(blocked_store.register_account("MustNotCreate", "must-not-create-2026").get("error", "")) == "authority_storage_unavailable", "unavailable authority parent blocks account creation")
	_expect(_read_text(blocker_path) == blocker_text and not FileAccess.file_exists(blocked_authority_path), "unavailable authority parent is never replaced or populated")


func _test_authority_lifecycle_lock_is_exclusive_and_recoverable() -> void:
	var primary_payload = _single_v3_account_payload("LockedOwner", "U-LOCKED-001", "locked-safe-pass-2026", "locked-salt")
	var previous_payload = _single_v3_account_payload("PreviousOwner", "U-PREVIOUS-002", "previous-safe-pass-2026", "previous-salt")
	_expect(_write_json(ATOMIC_LOCK_ACCOUNT_PATH, primary_payload), "lifecycle-lock primary fixture is written")
	_expect(_write_json("%s.previous" % ATOMIC_LOCK_ACCOUNT_PATH, previous_payload), "lifecycle-lock previous fixture is written")
	var primary_text = _read_text(ATOMIC_LOCK_ACCOUNT_PATH)
	var previous_text = _read_text("%s.previous" % ATOMIC_LOCK_ACCOUNT_PATH)
	var lock_path = "%s.write_lock" % ATOMIC_LOCK_ACCOUNT_PATH
	_expect(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(lock_path)) == OK, "residual lifecycle lock fixture is created")
	var residual_lock_store = _open_account_store(ATOMIC_LOCK_ACCOUNT_PATH)
	_expect(not bool(residual_lock_store.call("is_authority_storage_ready")), "pre-existing or residual lifecycle lock fails closed during initialization")
	_expect(String(residual_lock_store.login("LockedOwner", "locked-safe-pass-2026").get("error", "")) == "authority_storage_unavailable", "residual lifecycle lock blocks authority use")
	_expect(_read_text(ATOMIC_LOCK_ACCOUNT_PATH) == primary_text, "residual lifecycle lock preserves the exact primary generation")
	_expect(_read_text("%s.previous" % ATOMIC_LOCK_ACCOUNT_PATH) == previous_text, "residual lifecycle lock preserves the exact previous generation")
	_expect(_close_account_store(residual_lock_store), "residual-lock rejected store close is idempotently safe")
	residual_lock_store = null
	_remove_tree(lock_path)

	var writer = _open_account_store(ATOMIC_LOCK_ACCOUNT_PATH)
	var login: Dictionary = writer.login("LockedOwner", "locked-safe-pass-2026")
	_expect(bool(writer.call("is_authority_storage_ready")) and bool(login.get("ok", false)), "first store owns the lifecycle lock and loads authority")
	_expect(_path_is_directory(lock_path), "first store keeps its lifecycle lock for the object lifetime")
	var competing_writer = _open_account_store(ATOMIC_LOCK_ACCOUNT_PATH)
	_expect(not bool(competing_writer.call("is_authority_storage_ready")), "second store cannot load stale in-memory authority while the first writer lives")
	var changed_profile: Dictionary = (login.get("profile", {}) as Dictionary).duplicate(true)
	changed_profile["_profile_revision"] = int(login.get("profile_revision", 0))
	changed_profile["gacha_tickets"] = int(changed_profile.get("gacha_tickets", 0)) + 1
	var successful_save: Dictionary = writer.save_profile(String(login.get("session_token", "")), changed_profile)
	_expect(bool(successful_save.get("ok", false)), "lifecycle lock owner can atomically save authority")
	var committed_text = _read_text(ATOMIC_LOCK_ACCOUNT_PATH)
	_expect(committed_text != primary_text, "owner save advances the primary generation")
	_expect(String(competing_writer.register_account("StaleWriter", "stale-writer-pass-2026").get("error", "")) == "authority_storage_unavailable", "non-owner cannot perform a stale authority write")
	_expect(_read_text(ATOMIC_LOCK_ACCOUNT_PATH) == committed_text, "rejected stale writer cannot overwrite the committed generation")
	_expect(_close_account_store(competing_writer), "failed competing store close is idempotently safe")
	competing_writer = null
	_expect(_path_is_directory(lock_path), "failed competing store never removes the active owner's lifecycle lock")
	_expect(_close_account_store(writer), "owner explicitly closes its lifecycle lock")
	_expect(_close_account_store(writer), "repeated owner close is idempotently safe")
	writer = null
	_expect(not _path_is_directory(lock_path), "object destruction releases only its owned lifecycle lock")

	var restarted_writer = _open_account_store(ATOMIC_LOCK_ACCOUNT_PATH)
	_expect(bool(restarted_writer.call("is_authority_storage_ready")), "authority restarts normally after the owner releases its lifecycle lock")
	var restarted_login: Dictionary = restarted_writer.login("LockedOwner", "locked-safe-pass-2026")
	_expect(bool(restarted_login.get("ok", false)) and int((restarted_login.get("profile", {}) as Dictionary).get("gacha_tickets", 0)) == int(changed_profile.get("gacha_tickets", 0)), "restart loads the latest committed authority generation")
	_expect(_close_account_store(restarted_writer), "restarted owner explicitly closes its lifecycle lock")
	restarted_writer = null
	_expect(not _path_is_directory(lock_path), "normal restart also releases the lifecycle lock on object destruction")

	var foreign_owner = _open_account_store(FOREIGN_TOKEN_ACCOUNT_PATH)
	var foreign_lock_path = "%s.write_lock" % FOREIGN_TOKEN_ACCOUNT_PATH
	var foreign_owner_path = foreign_lock_path.path_join("owner_token")
	var owned_token = String(foreign_owner.authority_lifecycle_lock_token)
	_expect(_write_text(foreign_owner_path, "different-owner-token"), "foreign owner token fixture replaces the recorded token")
	_expect(not _close_account_store(foreign_owner), "explicit close refuses a lifecycle lock with another owner token")
	_expect(_path_is_directory(foreign_lock_path) and _read_text(foreign_owner_path) == "different-owner-token", "foreign owner token and lock are never deleted")
	_expect(_write_text(foreign_owner_path, owned_token), "test restores the exact recorded owner token for bounded cleanup")
	_expect(_close_account_store(foreign_owner), "restored exact owner token permits bounded cleanup")

	var crash_lock_path = "%s.write_lock" % CRASH_LOCK_ACCOUNT_PATH
	_expect(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(crash_lock_path)) == OK, "crash-simulation residual lock directory is written")
	_expect(_write_text(crash_lock_path.path_join("owner_token"), "dead-process-token"), "crash-simulation residual owner token is written")
	var crash_restart = _open_account_store(CRASH_LOCK_ACCOUNT_PATH)
	_expect(not bool(crash_restart.call("is_authority_storage_ready")), "crash-simulation residual lock remains fail-closed")
	_expect(_close_account_store(crash_restart), "crash-rejected store close does not claim the residual lock")
	_expect(_path_is_directory(crash_lock_path), "crash residual lock is never guessed safe or deleted")
	_remove_tree(crash_lock_path)


func _test_storage_failure_rolls_back_memory() -> void:
	var read_store = _open_account_store(PROFILE_READ_ROLLBACK_ACCOUNT_PATH)
	var read_registration: Dictionary = read_store.register_account("ReadRollback", "read-rollback-pass-2026")
	var read_login: Dictionary = read_store.login("ReadRollback", "read-rollback-pass-2026")
	_expect(bool(read_registration.get("ok", false)) and bool(read_login.get("ok", false)), "profile-read rollback account is ready")
	var read_key = "readrollback"
	var unnormalized_record: Dictionary = (read_store.accounts.get(read_key, {}) as Dictionary).duplicate(true)
	var unnormalized_profile: Dictionary = (unnormalized_record.get("profile", {}) as Dictionary).duplicate(true)
	unnormalized_profile["gacha_tickets"] = -99
	unnormalized_profile["unknown_transient_field"] = 7
	unnormalized_record["profile"] = unnormalized_profile
	read_store.accounts[read_key] = unnormalized_record.duplicate(true)
	var read_record_before_failure = (read_store.accounts.get(read_key, {}) as Dictionary).duplicate(true)
	var read_blocker_path = TEST_ROOT + "/profile_read_blocker"
	_expect(_write_text(read_blocker_path, "regular file blocks directory creation"), "profile-read storage blocker is written")
	read_store.storage_path = read_blocker_path.path_join("player_accounts.json")
	var failed_read: Dictionary = read_store.profile_for_session(String(read_login.get("session_token", "")))
	_expect(String(failed_read.get("error", "")) == "storage_error", "profile normalization reports storage failure")
	_expect(_same_json(read_store.accounts.get(read_key, {}), read_record_before_failure), "profile normalization failure restores the exact in-memory profile, revision, and timestamp")

	var save_store = _open_account_store(PROFILE_SAVE_ROLLBACK_ACCOUNT_PATH)
	var save_registration: Dictionary = save_store.register_account("SaveRollback", "save-rollback-pass-2026")
	var save_login: Dictionary = save_store.login("SaveRollback", "save-rollback-pass-2026")
	_expect(bool(save_registration.get("ok", false)) and bool(save_login.get("ok", false)), "profile-save rollback account is ready")
	var save_key = "saverollback"
	var save_record_before_failure = (save_store.accounts.get(save_key, {}) as Dictionary).duplicate(true)
	var save_blocker_path = TEST_ROOT + "/profile_save_blocker"
	_expect(_write_text(save_blocker_path, "regular file blocks directory creation"), "profile-save storage blocker is written")
	save_store.storage_path = save_blocker_path.path_join("player_accounts.json")
	var changed_profile: Dictionary = (save_login.get("profile", {}) as Dictionary).duplicate(true)
	changed_profile["_profile_revision"] = int(save_login.get("profile_revision", 0))
	changed_profile["gacha_tickets"] = int(changed_profile.get("gacha_tickets", 0)) + 500
	var failed_save: Dictionary = save_store.save_profile(String(save_login.get("session_token", "")), changed_profile)
	_expect(String(failed_save.get("error", "")) == "storage_error", "profile save reports storage failure")
	_expect(_same_json(save_store.accounts.get(save_key, {}), save_record_before_failure), "profile save failure restores the exact in-memory profile, revision, and timestamp")


func _legacy_v2_account_payload() -> Dictionary:
	var deck_sizes = [0, 0, 0, 2, 3]
	for _index in range(19):
		deck_sizes.append(8)
	var card_pool = ["rabbit", "wolf", "duck", "fox", "bear", "eagle", "tiger", "deer"]
	var fixture_accounts = {}
	for account_index in range(24):
		var deck = []
		for card_index in range(int(deck_sizes[account_index])):
			deck.append(card_pool[card_index])
		var card_counts = {}
		var card_levels = {}
		for card_index in range(card_pool.size()):
			var card_id = String(card_pool[card_index])
			card_counts[card_id] = account_index + card_index + 1
			card_levels[card_id] = 1 + ((account_index + card_index) % 9)
		var account_name = "Legacy%02d" % account_index
		var account_key = account_name.to_lower()
		var salt = "legacy-salt-%02d" % account_index
		var password_hash = _legacy_password_hash(LEGACY_KNOWN_PASSWORD, salt) if account_index == 0 else "preserved-fixture-hash-%02d" % account_index
		fixture_accounts[account_key] = {
			"user_id": "U-LEGACY-%03d" % (account_index + 1),
			"account": account_name,
			"salt": salt,
			"password_hash": password_hash,
			"created_at_unix": 1700000000 + account_index,
			"updated_at_unix": 1700001000 + account_index,
			"profile": {
				"card_counts": card_counts,
				"card_levels": card_levels,
				"deck": deck,
				"gacha_tickets": 10 + account_index,
				"rank_stars": 1 + account_index,
				"rank_key": ["bronze", "silver", "gold", "platinum"][account_index % 4],
				"elo": 1000 + account_index * 17,
				"rank_mirrors": {},
				"rank_mirror_policy_version": 4,
			},
		}
	var fixture_installations = {}
	for installation_index in range(13):
		var active_user_id = "U-LEGACY-%03d" % (installation_index + 1)
		var user_ids = [active_user_id]
		var secondary_account_index = installation_index + 13
		if secondary_account_index < 24:
			user_ids.append("U-LEGACY-%03d" % (secondary_account_index + 1))
		fixture_installations["installation-hash-%02d" % installation_index] = {
			"user_id": active_user_id,
			"user_ids": user_ids,
			"token_salt": "token-salt-%02d" % installation_index,
			"refresh_token_hash": "refresh-hash-%02d" % installation_index,
			"recovery_secret_salt": "recovery-salt-%02d" % installation_index,
			"recovery_secret_hash": "recovery-hash-%02d" % installation_index,
			"created_at_unix": 1700010000 + installation_index,
			"updated_at_unix": 1700020000 + installation_index,
		}
	return {
		"version": 2,
		"accounts": fixture_accounts,
		"installations": fixture_installations,
		"migration_marker": {"source": "synthetic-current-shape", "account_count": 24},
	}


func _single_v3_account_payload(account: String, user_id: String, password: String, salt: String) -> Dictionary:
	return {
		"version": 3,
		"accounts": {
			account.to_lower(): {
				"user_id": user_id,
				"account": account,
				"salt": salt,
				"password_hash": _legacy_password_hash(password, salt),
				"created_at_unix": 1700100000,
				"updated_at_unix": 1700100001,
				"profile_revision": 1,
				"profile": {
					"card_counts": {"rabbit": 4},
					"card_levels": {"rabbit": 2},
					"deck": ["rabbit"],
					"gacha_tickets": 12,
					"rank_stars": 2,
					"rank_key": "bronze",
					"elo": 1010,
					"rank_mirrors": {},
					"rank_mirror_policy_version": 4,
				},
			},
		},
		"installations": {},
		"admin_command_receipts": {},
	}


func _legacy_password_hash(password: String, salt: String) -> String:
	var value = (salt + ":" + password).sha256_text()
	for _round in range(11999):
		value = (value + ":" + salt).sha256_text()
	return value


func _deck_size_histogram(rows: Array) -> Dictionary:
	var histogram = {}
	for row_value in rows:
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var deck_value = (row_value as Dictionary).get("deck", [])
		var deck_size = (deck_value as Array).size() if typeof(deck_value) == TYPE_ARRAY else 0
		histogram[deck_size] = int(histogram.get(deck_size, 0)) + 1
	return histogram


func _same_json(first: Variant, second: Variant) -> bool:
	return JSON.stringify(first) == JSON.stringify(second)


func _open_account_store(path: String) -> RefCounted:
	var store = PlayerAccountStore.new(path)
	opened_account_stores.append(store)
	return store


func _close_account_store(store: Variant) -> bool:
	if store == null or not store.has_method("close"):
		return store == null
	return bool(store.call("close"))


func _close_all_account_stores() -> void:
	for store in opened_account_stores:
		if store != null and store.has_method("close"):
			store.call("close")
	opened_account_stores.clear()


func _test_account_projection_grants_idempotency_and_cas() -> void:
	var store = _open_account_store(ACCOUNT_PATH)
	var catalog_result: Dictionary = store.register_admin_card_catalog({
		"rabbit": "兔子",
		"wolf": "狼",
		"gold_mine_card": "金矿",
		"defense_watch_tower": "防御塔",
	})
	_expect(bool(catalog_result.get("ok", false)) and int(catalog_result.get("card_count", 0)) == 4, "admin account projection registers the complete Chinese card catalog")
	var first_registration: Dictionary = store.register_account("FieldMouse", "safe-pass-1936")
	var second_registration: Dictionary = store.register_account("RiverWolf", "safe-pass-2048")
	_expect(bool(first_registration.get("ok", false)) and bool(second_registration.get("ok", false)), "two target accounts are registered")
	var first_user_id = String(first_registration.get("user_id", ""))
	var second_user_id = String(second_registration.get("user_id", ""))
	var first_login: Dictionary = store.login("FieldMouse", "safe-pass-1936")
	var first_token = String(first_login.get("session_token", ""))
	var initial_revision = int(first_login.get("profile_revision", 0))
	var initial_save: Dictionary = store.save_profile(first_token, {
		"_profile_revision": initial_revision,
		"card_counts": {"rabbit": 7, "wolf": 2},
		"card_levels": {"rabbit": 3, "wolf": 2},
		"deck": ["rabbit", "wolf"],
		"gacha_tickets": 19,
		"rank_stars": 8,
		"rank_key": "gold",
		"elo": 1234,
		"rank_mirrors": {},
	})
	_expect(bool(initial_save.get("ok", false)) and not bool(initial_save.get("conflict", true)), "initial CAS profile save succeeds")
	var stale_revision = int(initial_save.get("profile_revision", 0))
	var stale_profile: Dictionary = (initial_save.get("profile", {}) as Dictionary).duplicate(true)

	_expect(FileAccess.file_exists(ACCOUNT_SNAPSHOT_PATH), "sanitized account snapshot is written")
	var snapshot_text = _read_text(ACCOUNT_SNAPSHOT_PATH)
	var snapshot = JSON.parse_string(snapshot_text)
	_expect(typeof(snapshot) == TYPE_DICTIONARY and (snapshot.get("accounts", []) as Array).size() == 2, "account snapshot contains every saved account")
	_expect(String((snapshot.get("card_names", {}) as Dictionary).get("rabbit", "")) == "兔子", "account snapshot exposes Chinese card names without exposing account credentials")
	_expect(not snapshot_text.contains("FieldMouse") and not snapshot_text.contains("RiverWolf"), "account snapshot masks login names")
	_expect(not snapshot_text.contains("password_hash") and not snapshot_text.contains("salt") and not snapshot_text.contains("installations") and not snapshot_text.contains("sessions"), "account snapshot excludes credentials, installations, and sessions")
	var first_snapshot_row = _row_by_id(snapshot.get("accounts", []), "user_id", first_user_id)
	_expect((first_snapshot_row.get("deck", []) as Array) == ["rabbit", "wolf"], "account snapshot exposes the full current deck")
	_expect(int((first_snapshot_row.get("resources", {}) as Dictionary).get("gacha_tickets", 0)) == 19, "account snapshot exposes supported resource balances")

	var target_command_id = "11111111-1111-4111-8111-111111111111"
	_expect(_write_command(store, target_command_id, "target", [first_user_id], [{"resource": "gacha_tickets", "amount": 5}], "客服补发", ""), "target grant command is queued")
	var target_result: Dictionary = store.process_admin_commands(["rabbit", "wolf"])
	_expect(int(target_result.get("processed", 0)) == 1, "target grant is processed once")
	var first_after_target: Dictionary = store.profile_for_session(first_token)
	_expect(int((first_after_target.get("profile", {}) as Dictionary).get("gacha_tickets", 0)) == 24, "target account receives tickets")
	_expect(_write_command(store, target_command_id, "target", [first_user_id], [{"resource": "gacha_tickets", "amount": 5}], "客服补发", ""), "duplicate target command is replayed")
	var duplicate_result: Dictionary = store.process_admin_commands(["rabbit", "wolf"])
	_expect(int(duplicate_result.get("idempotent", 0)) == 1, "duplicate command id is recognized from the durable ledger")
	_expect(int((store.profile_for_session(first_token).get("profile", {}) as Dictionary).get("gacha_tickets", 0)) == 24, "duplicate command never credits twice")

	var all_command_id = "22222222-2222-4222-8222-222222222222"
	_expect(_write_command(store, all_command_id, "all", [first_user_id, second_user_id], [{"resource": "card_copies", "card_id": "rabbit", "amount": 3}], "全服补偿", "SEND TO ALL"), "all-account command freezes explicit targets")
	var all_result: Dictionary = store.process_admin_commands(["rabbit", "wolf"])
	_expect(int(all_result.get("processed", 0)) == 1, "all-account grant is processed")
	var first_after_all: Dictionary = store.profile_for_session(first_token)
	_expect(int((((first_after_all.get("profile", {}) as Dictionary).get("card_counts", {}) as Dictionary).get("rabbit", 0))) == 10, "first account receives all-account card copies")
	var second_login: Dictionary = store.login("RiverWolf", "safe-pass-2048")
	_expect(int(((((second_login.get("profile", {}) as Dictionary).get("card_counts", {})) as Dictionary).get("rabbit", 0))) == 3, "second account receives all-account card copies")
	_expect(FileAccess.file_exists(store.admin_command_root.path_join("processed").path_join("%s.json" % all_command_id)), "processed command writes an authoritative receipt")

	stale_profile["_profile_revision"] = stale_revision
	stale_profile["gacha_tickets"] = 1
	var conflict: Dictionary = store.save_profile(first_token, stale_profile)
	_expect(bool(conflict.get("ok", false)) and bool(conflict.get("conflict", false)), "stale client save returns a successful conflict")
	_expect(int((conflict.get("profile", {}) as Dictionary).get("gacha_tickets", 0)) == 24, "CAS conflict returns the latest resource-bearing profile")
	_expect(int(conflict.get("profile_revision", 0)) > stale_revision, "CAS conflict returns the latest revision")

	_expect(_close_account_store(store), "grant authority owner explicitly closes before restart")
	store = null
	var reloaded = _open_account_store(ACCOUNT_PATH)
	_expect(_write_command(reloaded, all_command_id, "all", [first_user_id, second_user_id], [{"resource": "card_copies", "card_id": "rabbit", "amount": 3}], "全服补偿", "SEND TO ALL"), "processed command is replayed after restart")
	var replay_after_restart: Dictionary = reloaded.process_admin_commands(["rabbit", "wolf"])
	_expect(int(replay_after_restart.get("idempotent", 0)) == 1, "idempotency ledger survives restart")
	var reloaded_login: Dictionary = reloaded.login("FieldMouse", "safe-pass-1936")
	_expect(int(((((reloaded_login.get("profile", {}) as Dictionary).get("card_counts", {})) as Dictionary).get("rabbit", 0))) == 10, "restart replay does not duplicate card copies")
	_expect(_close_account_store(reloaded), "reloaded grant authority explicitly closes")


func _write_command(store: RefCounted, command_id: String, scope: String, target_user_ids: Array, grants: Array, reason: String, all_confirmation: String) -> bool:
	var command = {
		"version": 1,
		"command_id": command_id,
		"idempotency_key": command_id,
		"status": "pending",
		"actor": "owner-one",
		"reason": reason,
		"scope": scope,
		"all_confirmation": all_confirmation,
		"target_user_ids": target_user_ids,
		"target_count": target_user_ids.size(),
		"grants": grants,
		"created_at_unix": int(Time.get_unix_time_from_system()),
	}
	return _write_json(store.admin_command_root.path_join("pending").path_join("%s.json" % command_id), command)


func _row_by_id(rows_value: Variant, field_name: String, expected_value: String) -> Dictionary:
	if typeof(rows_value) != TYPE_ARRAY:
		return {}
	for row_value in rows_value:
		if typeof(row_value) == TYPE_DICTIONARY and String((row_value as Dictionary).get(field_name, "")) == expected_value:
			return (row_value as Dictionary).duplicate(true)
	return {}


func _write_json(path: String, payload: Dictionary) -> bool:
	return _write_text(path, JSON.stringify(payload, "\t"))


func _write_text(path: String, text: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	var write_error = file.get_error()
	file.close()
	return write_error == OK


func _read_text(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text = file.get_as_text()
	file.close()
	return text


func _path_is_directory(path: String) -> bool:
	var parent = DirAccess.open(path.get_base_dir())
	if parent == null:
		return false
	return parent.dir_exists(path.get_file())


func _remove_tree(path: String) -> void:
	var absolute_path = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute_path)
		return
	var directory = DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry = directory.get_next()
	while not entry.is_empty():
		if entry not in [".", ".."]:
			var child = path.path_join(entry)
			if directory.current_is_dir():
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(absf(actual - expected) <= 0.0001, "%s (actual=%f expected=%f)" % [message, actual, expected])
