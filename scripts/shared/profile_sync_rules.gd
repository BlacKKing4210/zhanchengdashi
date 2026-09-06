extends RefCounted
## Rebase local mutations made after a save was sent onto its acknowledged profile.
## A CAS conflict uses the last confirmed baseline instead of the rejected request.
static func rebase(remote: Dictionary, local: Dictionary, baseline: Dictionary) -> Dictionary:
	var merged = remote.duplicate(true)
	for key in local:
		if local[key] == baseline.get(key):
			continue
		if key in ["gacha_tickets", "wallet_gold"]:
			merged[key] = maxi(0, int(remote.get(key, baseline.get(key, 0))) + int(local[key]) - int(baseline.get(key, 0)))
		elif key == "card_counts":
			var counts: Dictionary = remote.get(key, {}).duplicate(true)
			var before: Dictionary = baseline.get(key, {})
			for card_id in local[key]:
				counts[card_id] = maxi(0, int(counts.get(card_id, 0)) + int(local[key][card_id]) - int(before.get(card_id, 0)))
			merged[key] = counts
		else:
			merged[key] = local[key]
	return merged
