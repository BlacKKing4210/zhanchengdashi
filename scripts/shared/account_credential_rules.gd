extends RefCounted

const AUTO_PASSWORD_DOMAIN = "zhanchengdashi:auto-account:v1:"
const RECOVERY_SECRET_HEX_LENGTH = 64
const AUTO_PASSWORD_HEX_LENGTH = 64
const USER_ID_RANDOM_HEX_LENGTH = 10


static func normalize_user_id(user_id: String) -> String:
	return user_id.strip_edges().to_lower()


static func is_valid_recovery_secret(recovery_secret: String) -> bool:
	var normalized = recovery_secret.strip_edges().to_lower()
	return (
		normalized.length() == RECOVERY_SECRET_HEX_LENGTH
		and normalized.is_valid_hex_number(false)
	)


static func is_valid_auto_account_id(user_id: String) -> bool:
	var normalized = normalize_user_id(user_id)
	var parts = normalized.split("-", false)
	if parts.size() != 3 or parts[0] != "u" or not parts[1].is_valid_int():
		return false
	return (
		parts[2].length() == USER_ID_RANDOM_HEX_LENGTH
		and parts[2].is_valid_hex_number(false)
	)


static func derive_auto_password(user_id: String, recovery_secret: String) -> String:
	var normalized_user_id = normalize_user_id(user_id)
	var normalized_secret = recovery_secret.strip_edges().to_lower()
	if not is_valid_auto_account_id(normalized_user_id) or not is_valid_recovery_secret(normalized_secret):
		return ""
	return (AUTO_PASSWORD_DOMAIN + normalized_user_id + ":" + normalized_secret).sha256_text()


static func is_auto_account(account: String, user_id: String, auto_generated: bool) -> bool:
	return (
		auto_generated
		and is_valid_auto_account_id(user_id)
		and normalize_user_id(account) == normalize_user_id(user_id)
	)
