extends Node3D 

const PLAYER = preload("uid://xp045ovbqpjw")

func _ready() -> void:
	var build_client = get_tree().root.get_node("build_client") # adjust to your autoload name
	build_client.socket.received_match_presence.connect(_on_presence)
	
	# Spawn local player immediately
	var local = PLAYER.instantiate()
	build_client.players[build_client.session.user_id] = local
	add_child(local)

func _on_presence(presence: NakamaRTAPI.MatchPresenceEvent) -> void:
	var build_client = get_tree().root.get_node("build_client")
	for p in presence.joins:
		if p.session_id not in build_client.players:
			var go = PLAYER.instantiate()
			build_client.players[p.session_id] = go
			add_child(go)
	for p in presence.leaves:
		if p.session_id in build_client.players:
			build_client.players[p.session_id].queue_free()
			build_client.players.erase(p.session_id)
