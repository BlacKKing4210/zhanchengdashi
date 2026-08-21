extends RefCounted


static func release(lock_path: String, owner_path: String, expected_token: String, context: String) -> bool:
	if lock_path.is_empty() or owner_path.is_empty() or expected_token.is_empty():
		push_error("PlayerAccountStore lifecycle lock release has incomplete ownership data (%s)." % context)
		return false
	var owner_file = FileAccess.open(owner_path, FileAccess.READ)
	if owner_file == null:
		push_error("PlayerAccountStore lifecycle lock owner is unreadable during %s; the lock was not removed." % context)
		return false
	var recorded_token = owner_file.get_as_text()
	var owner_read_error = owner_file.get_error()
	owner_file.close()
	if owner_read_error != OK or recorded_token != expected_token:
		push_error("PlayerAccountStore lifecycle lock ownership does not match during %s; the lock was not removed." % context)
		return false
	var owner_remove_error = DirAccess.remove_absolute(ProjectSettings.globalize_path(owner_path))
	if owner_remove_error != OK:
		push_error("PlayerAccountStore lifecycle lock owner release failed during %s (error %d)." % [context, owner_remove_error])
		return false
	var lock_remove_error = DirAccess.remove_absolute(ProjectSettings.globalize_path(lock_path))
	if lock_remove_error != OK:
		push_error("PlayerAccountStore lifecycle lock directory release failed during %s (error %d)." % [context, lock_remove_error])
		return false
	return true
