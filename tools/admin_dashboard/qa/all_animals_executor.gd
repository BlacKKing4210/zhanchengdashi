extends SceneTree

const Store = preload("res://scripts/server/player_account_store.gd")
var failures := 0
var fixture_root := ""

func _initialize() -> void:
	call_deferred("run_test")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func write_json(file_path: String, value: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(file_path.get_base_dir())
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	check(file != null, "fixture file opens")
	if file != null:
		file.store_string(JSON.stringify(value))
		file.close()

func remove_fixture(directory: String) -> void:
	for child in DirAccess.get_directories_at(directory):
		remove_fixture(directory.path_join(child))
	for child in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(child))
	DirAccess.remove_absolute(directory)

func run_test() -> void:
	fixture_root = ProjectSettings.globalize_path("user://tests/admin_all_animals_%s" % Time.get_ticks_usec())
	OS.set_environment("ZHANCHENG_DASHBOARD_ACCOUNT_SNAPSHOT_PATH", fixture_root.path_join("admin_accounts_snapshot.json"))
	OS.set_environment("ZHANCHENG_DASHBOARD_COMMAND_ROOT", fixture_root.path_join("commands"))
	var authority := fixture_root.path_join("fixture_accounts.json")
	var store = Store.new(authority)
	var created: Dictionary = store.register_account("FixtureOne", "isolated-fixture-password")
	var other: Dictionary = store.register_account("FixtureTwo", "isolated-fixture-password")
	check(bool(created.get("ok", false)) and bool(other.get("ok", false)), "isolated accounts register")
	var login: Dictionary = store.login("FixtureOne", "isolated-fixture-password")
	var token := String(login.get("session_token", ""))
	var before: Dictionary = login.get("profile", {}).duplicate(true)
	var ids: Array = []
	var grants: Array = []
	for i in range(60):
		var card_id := "fixture_species_%d" % i
		ids.append(card_id)
		grants.append({"resource": "card_copies", "card_id": card_id, "amount": 1})
	var command := {
		"version": 1, "command_id": "77777777-7777-4777-8777-777777777777",
		"idempotency_key": "77777777-7777-4777-8777-777777777777",
		"status": "pending", "actor": "qa-owner", "reason": "isolated all animals test",
		"scope": "target", "target_user_ids": [created.get("user_id")], "target_count": 1,
		"grants": grants, "created_at_unix": int(Time.get_unix_time_from_system()),
	}
	var pending: String = store.admin_command_root.path_join("pending").path_join(command.command_id + ".json")
	write_json(pending, command)
	var result: Dictionary = store.process_admin_commands(ids)
	check(int(result.get("processed", 0)) == 1, "60 animals apply in one command")
	var after: Dictionary = store.profile_for_session(token).get("profile", {})
	for id in ids:
		check(int(after.get("card_counts", {}).get(id, 0)) == 1, "every animal awarded")
	check(after.get("gacha_tickets") == before.get("gacha_tickets"), "tickets unchanged")
	check(after.get("deck") == before.get("deck"), "deck unchanged")
	var other_profile: Dictionary = store.login("FixtureTwo", "isolated-fixture-password").get("profile", {})
	check(other_profile.get("card_counts", {}).is_empty(), "unselected account unchanged")
	check(store.close(), "authority closes")
	store = Store.new(authority)
	write_json(pending, command)
	store.process_admin_commands(ids)
	var persisted: Dictionary = store.login("FixtureOne", "isolated-fixture-password").get("profile", {})
	for id in ids:
		check(int(persisted.get("card_counts", {}).get(id, 0)) == 1, "restart replay does not duplicate animal")
	check(persisted.get("gacha_tickets") == before.get("gacha_tickets"), "restart retains tickets")
	var invalid: Dictionary = command.duplicate(true)
	invalid.command_id = "88888888-8888-4888-8888-888888888888"
	invalid.idempotency_key = invalid.command_id
	invalid.grants[59].card_id = "unknown_animal"
	write_json(store.admin_command_root.path_join("pending").path_join(invalid.command_id + ".json"), invalid)
	var rejected: Dictionary = store.process_admin_commands(ids)
	check(int(rejected.get("failed", 0)) == 1, "invalid last animal rejects whole command")
	var final_profile: Dictionary = store.login("FixtureOne", "isolated-fixture-password").get("profile", {})
	for id in ids:
		check(int(final_profile.get("card_counts", {}).get(id, 0)) == 1, "invalid vector has no partial award")
	store.close()
	remove_fixture(fixture_root)
	print("ALL_ANIMALS_EXECUTOR_TEST_PASS" if failures == 0 else "ALL_ANIMALS_EXECUTOR_TEST_FAIL")
	quit(failures)
