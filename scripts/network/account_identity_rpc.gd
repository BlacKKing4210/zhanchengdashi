extends Node
## Optional extension lives on its own node: adding account RPCs must never
## renumber the deployed OnlineRoom battle protocol (Godot sorts RPC names).

@rpc("any_peer", "call_remote", "reliable", 0)
func update_identity(session_token: String, username: String, avatar_id: String, revision: int) -> void:
	var transport = get_parent()
	if not transport._accept_server_request():
		return
	transport._server_update_account_identity(multiplayer.get_remote_sender_id(), session_token, username, avatar_id, revision)
