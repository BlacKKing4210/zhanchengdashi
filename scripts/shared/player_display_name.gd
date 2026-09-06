extends RefCounted
## Account identifiers are credentials, never a public fallback name.
const UNKNOWN = "神秘玩家"

static func resolve(value: String, account_id: String = "", user_id: String = "") -> String:
	var nickname = value.strip_edges()
	if nickname.is_empty() or nickname in ["玩家", "未命名玩家", "游客账号", account_id, user_id]:
		return UNKNOWN
	if nickname.begins_with("U-") and nickname.get_slice("-", 1).is_valid_int():
		return UNKNOWN
	return nickname
