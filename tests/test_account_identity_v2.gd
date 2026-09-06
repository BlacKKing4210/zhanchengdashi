extends Node

const PlayerAccountStore = preload("res://scripts/server/player_account_store.gd")
const AccountIdentityRules = preload("res://scripts/shared/account_identity_rules.gd")
const TEST_PATH = "user://tests/account_identity_v2_test.json"

var failures = 0


func _ready() -> void:
	_cleanup()
	var cards_value = JSON.parse_string(FileAccess.get_file_as_string("res://runtime/config/cards.json"))
	var cards: Array = cards_value if typeof(cards_value) == TYPE_ARRAY else []
	var avatar_catalog = AccountIdentityRules.runtime_avatar_catalog(cards)
	var animal_card_ids = []
	var rarity_counts = {"common": 0, "rare": 0, "epic": 0, "legendary": 0}
	for entry_value in avatar_catalog:
		var entry: Dictionary = entry_value
		animal_card_ids.append(String(entry.get("card_id", "")))
		var rarity = String(entry.get("rarity", ""))
		rarity_counts[rarity] = int(rarity_counts.get(rarity, 0)) + 1
	_expect(avatar_catalog.size() == 60, "runtime avatar catalog includes all 60 animal cards")
	var expected_rarity_counts = {"common": 0, "rare": 0, "epic": 0, "legendary": 0}
	for card in cards:
		if not String(card.get("art_path", "")).contains("/animals/"):
			continue
		var rarity = String(card.get("rarity", "common"))
		expected_rarity_counts[rarity] = int(expected_rarity_counts.get(rarity, 0)) + 1
		var matches = avatar_catalog.filter(func(entry): return entry.get("card_id") == card.get("id"))
		_expect(matches.size() == 1 and matches[0].get("rarity") == rarity, "avatar rarity matches current producer table: " + String(card.id))
	_expect(rarity_counts == expected_rarity_counts, "avatar catalog preserves every current card rarity")
	var store = PlayerAccountStore.new(TEST_PATH)
	var installation_id = "a7".repeat(32)
	var recovery_secret = "b8".repeat(32)
	var device = store.authenticate_installation(installation_id, "", {}, animal_card_ids, recovery_secret)
	_expect(bool(device.get("ok", false)), "device account is created")
	_expect(AccountIdentityRules.is_valid_username(device.get("username", "")), "device account receives a valid default username")
	_expect(String(device.get("avatar_id", "")) == AccountIdentityRules.DEFAULT_AVATAR_ID, "device account receives the default animal avatar")
	_expect(not bool(device.get("identity_complete", true)), "new device account still needs one-step identity confirmation")
	var refresh_token = String(device.get("refresh_token", ""))

	var alpha_registration = store.register_account("AlphaAccount", "alpha-pass-2026")
	var beta_registration = store.register_account("BetaAccount", "beta-pass-2026")
	_expect(bool(alpha_registration.get("ok", false)) and bool(beta_registration.get("ok", false)), "named accounts register")
	var alpha_login = store.login(
		"AlphaAccount",
		"alpha-pass-2026",
		installation_id,
		refresh_token,
		animal_card_ids,
		recovery_secret
	)
	_expect(bool(alpha_login.get("ok", false)), "account id and password log in")
	_expect(String(alpha_login.get("username", "")) == "AlphaAccount", "named registration initializes an independent display username")
	_expect(not alpha_login.has("password") and not alpha_login.has("salt") and not alpha_login.has("password_hash"), "identity response exposes no password material")
	var alpha_token = String(alpha_login.get("session_token", ""))
	_expect(bool(store.save_profile(alpha_token, {"card_counts": {"fox": 1}, "_profile_revision": 1}).get("ok", false)), "alpha fixture owns the fox avatar card")
	var alpha_update = store.update_identity(alpha_token, "林地旅者", "animal_fox", 1, animal_card_ids)
	_expect(bool(alpha_update.get("ok", false)), "valid identity update succeeds")
	_expect(String(alpha_update.get("username", "")) == "林地旅者", "identity update persists the username")
	_expect(String(alpha_update.get("avatar_id", "")) == "animal_fox", "identity update persists the avatar")
	_expect(int(alpha_update.get("identity_revision", 0)) == 2, "identity revision increments independently")
	_expect(bool(alpha_update.get("identity_complete", false)), "identity update completes first-time setup")

	var conflict = store.update_identity(alpha_token, "覆盖失败", "animal_fox", 1, animal_card_ids)
	_expect(bool(conflict.get("ok", false)) and bool(conflict.get("conflict", false)), "stale identity revision is rejected without overwriting")
	_expect(String(conflict.get("username", "")) == "林地旅者", "revision conflict returns the latest server username")
	_expect(int(conflict.get("identity_revision", 0)) == 2, "revision conflict returns the latest revision")
	_expect(String(store.update_identity(alpha_token, "一", "animal_cat", 2, animal_card_ids).get("error", "")) == "invalid_username_length", "too-short username is rejected")
	_expect(String(store.update_identity(alpha_token, "坏\n名字", "animal_cat", 2, animal_card_ids).get("error", "")) == "invalid_username_characters", "control characters are rejected")
	_expect(String(store.update_identity(alpha_token, "合法名字", "human_option_01", 2, animal_card_ids).get("error", "")) == "invalid_avatar", "unapproved human avatar stays outside runtime")
	_expect(String(store.update_identity(alpha_token, "合法名字", "animal_tiger", 2, animal_card_ids).get("error", "")) == "avatar_locked", "server rejects an animal avatar whose card is not owned")
	_expect(bool(store.save_profile(alpha_token, {"card_counts": {}, "_profile_revision": 2}).get("ok", false)), "alpha fixture can remove its owned-card copy after selecting the avatar")
	var legacy_current_update = store.update_identity(alpha_token, "林地旅者", "animal_fox", 2, animal_card_ids)
	_expect(bool(legacy_current_update.get("ok", false)), "the currently equipped legacy avatar remains saveable without an owned card")

	var beta_login = store.login(
		"BetaAccount",
		"beta-pass-2026",
		installation_id,
		refresh_token,
		animal_card_ids,
		recovery_secret
	)
	_expect(bool(beta_login.get("ok", false)), "second named account binds to the same installation")
	var beta_token = String(beta_login.get("session_token", ""))
	_expect(bool(store.save_profile(beta_token, {"card_counts": {"rabbit": 1}, "_profile_revision": 1}).get("ok", false)), "beta fixture owns the rabbit avatar card")
	var beta_update = store.update_identity(beta_token, "林地旅者", "animal_rabbit", 1, animal_card_ids)
	_expect(bool(beta_update.get("ok", false)) and not bool(beta_update.get("conflict", false)), "duplicate usernames are allowed across distinct accounts")
	_expect(not bool(store.login("林地旅者", "alpha-pass-2026").get("ok", true)), "username never acts as the login account id")

	var summaries = store.account_summaries_for_session(beta_token, animal_card_ids)
	_expect(bool(summaries.get("ok", false)), "owned account summaries load")
	var summary_rows: Array = summaries.get("accounts", [])
	_expect(summary_rows.size() == 3, "device summary keeps device and two named accounts")
	var named_summary_count = 0
	for row_value in summary_rows:
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_value
		if String(row.get("username", "")) == "林地旅者":
			named_summary_count += 1
		_expect(AccountIdentityRules.is_runtime_avatar_id(row.get("avatar_id", ""), animal_card_ids), "every summary returns a runtime avatar")
	_expect(named_summary_count == 2, "summary proves duplicate display names do not merge accounts")

	var alpha_key = String(store.call("_account_key", "AlphaAccount"))
	var original_record: Dictionary = (store.accounts[alpha_key] as Dictionary).duplicate(true)
	var legacy_record = original_record.duplicate(true)
	legacy_record.erase("username")
	legacy_record.erase("avatar_id")
	legacy_record.erase("identity_revision")
	legacy_record.erase("identity_complete")
	store.accounts[alpha_key] = legacy_record
	_expect(bool(store.call("_save")), "legacy-shaped authority fixture is saved")
	var legacy_disk_payload = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH)) as Dictionary
	var legacy_disk_record: Dictionary = ((legacy_disk_payload.get("accounts", {}) as Dictionary).get(alpha_key, {}) as Dictionary).duplicate(true)
	var legacy_disk_installations: Dictionary = (legacy_disk_payload.get("installations", {}) as Dictionary).duplicate(true)
	_expect(bool(store.close()), "store releases lifecycle lock before migration reload")
	store = null

	var migrated_store = PlayerAccountStore.new(TEST_PATH)
	var migrated_record: Dictionary = (migrated_store.accounts[alpha_key] as Dictionary).duplicate(true)
	var migrated_disk_payload = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH)) as Dictionary
	var migrated_disk_record: Dictionary = ((migrated_disk_payload.get("accounts", {}) as Dictionary).get(alpha_key, {}) as Dictionary).duplicate(true)
	_expect(AccountIdentityRules.is_valid_username(migrated_record.get("username", "")), "legacy record receives a valid migrated username")
	_expect(String(migrated_record.get("avatar_id", "")) == AccountIdentityRules.DEFAULT_AVATAR_ID, "legacy record receives the default avatar")
	_expect(int(migrated_record.get("identity_revision", 0)) == 1, "legacy record receives identity revision one")
	_expect(bool(migrated_record.get("identity_complete", false)), "legacy player is not forced through blocking setup")
	for field_name in ["user_id", "salt", "password_hash", "profile_revision", "profile", "created_at_unix"]:
		_expect(migrated_disk_record.get(field_name) == legacy_disk_record.get(field_name), "migration preserves %s" % field_name)
	_expect((migrated_disk_payload.get("installations", {}) as Dictionary) == legacy_disk_installations, "migration preserves installation bindings exactly")
	_expect(bool(migrated_store.close()), "migrated store releases lifecycle lock")
	migrated_store = null

	var original_online_state = {
		"user_id": OnlineRoom.current_user_id,
		"account": OnlineRoom.current_account_name,
		"username": OnlineRoom.current_username,
		"avatar_id": OnlineRoom.current_avatar_id,
		"identity_revision": OnlineRoom.current_identity_revision,
		"identity_complete": OnlineRoom.current_identity_complete,
		"local_player_name": OnlineRoom.local_player_name,
	}
	var emitted = {"state": {}}
	var state_callback = func(state: Dictionary) -> void:
		emitted["state"] = state.duplicate(true)
	OnlineRoom.account_state_changed.connect(state_callback)
	OnlineRoom.call("_apply_account_operation", "update_account_identity", {
		"user_id": "U-online-identity",
		"account": "OnlineAccount",
		"username": "联网水獭",
		"avatar_id": "animal_otter",
		"identity_revision": 4,
		"identity_complete": true,
		"conflict": false,
	})
	OnlineRoom.account_state_changed.disconnect(state_callback)
	_expect(OnlineRoom.current_username == "联网水獭" and OnlineRoom.current_avatar_id == "animal_otter", "OnlineRoom applies identity RPC fields")
	_expect(String((emitted.get("state", {}) as Dictionary).get("username", "")) == "联网水獭", "account state signal exposes username")
	_expect(String((emitted.get("state", {}) as Dictionary).get("avatar_id", "")) == "animal_otter", "account state signal exposes avatar")
	_expect(
		String(OnlineRoom.call("_server_player_display_name", {"username": "联网水獭", "account": "OnlineAccount"}, "玩家8", 8)) == "联网水獭",
		"room display name prefers the server-authoritative username"
	)
	OnlineRoom.current_user_id = String(original_online_state["user_id"])
	OnlineRoom.current_account_name = String(original_online_state["account"])
	OnlineRoom.current_username = String(original_online_state["username"])
	OnlineRoom.current_avatar_id = String(original_online_state["avatar_id"])
	OnlineRoom.current_identity_revision = int(original_online_state["identity_revision"])
	OnlineRoom.current_identity_complete = bool(original_online_state["identity_complete"])
	OnlineRoom.local_player_name = String(original_online_state["local_player_name"])
	_cleanup()
	if failures == 0:
		print("ACCOUNT_IDENTITY_V2_TEST_PASS")
	else:
		push_error("ACCOUNT_IDENTITY_V2_TEST_FAIL: %d failure(s)" % failures)
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _cleanup() -> void:
	for suffix in ["", ".previous", ".tmp"]:
		var path = TEST_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var lock_path = TEST_PATH + ".write_lock"
	var owner_path = lock_path.path_join("owner_token")
	if FileAccess.file_exists(owner_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(owner_path))
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(lock_path)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(lock_path))
