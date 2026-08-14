extends Node

const AccountCredentialRules = preload("res://scripts/shared/account_credential_rules.gd")

var failures = 0


func _ready() -> void:
	var user_id = "U-1700000000-ABCDEF0123"
	var second_user_id = "U-1700000001-ABCDEF0124"
	var recovery_secret = "a1".repeat(32)
	var second_recovery_secret = "b2".repeat(32)
	var password = AccountCredentialRules.derive_auto_password(user_id, recovery_secret)
	var repeated_password = AccountCredentialRules.derive_auto_password(
		user_id.to_lower(),
		recovery_secret.to_upper()
	)
	var other_user_password = AccountCredentialRules.derive_auto_password(
		second_user_id,
		recovery_secret
	)
	var other_secret_password = AccountCredentialRules.derive_auto_password(
		user_id,
		second_recovery_secret
	)

	_expect(
		password.length() == AccountCredentialRules.AUTO_PASSWORD_HEX_LENGTH
		and password.is_valid_hex_number(false),
		"derived automatic-account password is a 64-character hexadecimal value"
	)
	_expect(password == repeated_password, "the same normalized inputs derive the same password")
	_expect(password != other_user_password, "different UserIDs derive different passwords")
	_expect(password != other_secret_password, "different recovery secrets derive different passwords")
	_expect(
		AccountCredentialRules.derive_auto_password("invalid-user", recovery_secret).is_empty(),
		"invalid automatic-account UserIDs are rejected"
	)
	_expect(
		AccountCredentialRules.derive_auto_password(user_id, "short-secret").is_empty(),
		"invalid recovery secrets are rejected"
	)

	if failures == 0:
		print("ACCOUNT_CREDENTIAL_RULES_TEST_PASS")
	else:
		push_error("ACCOUNT_CREDENTIAL_RULES_TEST_FAIL: %d failure(s)" % failures)
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
