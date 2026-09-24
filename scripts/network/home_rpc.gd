extends Node
## Keep home RPC methods off OnlineRoom's frozen deployed battle RPC table.

@rpc("any_peer", "call_remote", "reliable", 0)
func execute(session_token: String, action: String, id: String, revision: int, day: int) -> void:
	var transport = get_parent()
	if not transport._accept_server_request():
		return
	transport._server_home_action(multiplayer.get_remote_sender_id(), session_token, action, id, revision, day)
