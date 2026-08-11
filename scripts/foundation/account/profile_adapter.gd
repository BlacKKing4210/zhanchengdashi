## Project-facing account profile contract.
## Override these methods to keep game-specific fields out of session persistence.
extends RefCounted


func normalize_profile(source: Dictionary) -> Dictionary:
	return source.duplicate(true)


func summary_for_profile(profile: Dictionary, _summary_filter_ids: Array = []) -> Dictionary:
	return {
		"display_name": String(profile.get("display_name", "")),
		"progress_value": maxi(0, int(profile.get("progress_value", 0))),
	}


func token_namespace() -> String:
	return "portable-account-v1"


func installation_token_prefix() -> String:
	return token_namespace() + ":installation:"


func refresh_token_prefix() -> String:
	return token_namespace() + ":refresh:"

