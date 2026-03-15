extends Node
class_name NakamaMultiplayer

var session : NakamaSession
var client: NakamaClient
var socket: NakamaSocket
var ip = "192.168.178.107"
var multiplayer_bridge

func _ready() -> void:
	client = Nakama.create_client("defaultkey",ip, 7350, "http")
	
	session = await client.authenticate_device_async(OS.get_unique_id())
	
	socket = Nakama.create_socket_from(client)
	await socket.connect_async(session)
	
	socket.connected.connect(on_socket_connected)
	socket.received_error.connect(on_socket_error)
	socket.closed.connect(on_socket_closed)
	
	socket.received_match_presence.connect(on_match_presence)
	socket.received_match_state.connect(on_match_state)
	create_join_lobby("test")

func create_bridge():
	multiplayer_bridge = NakamaMultiplayerBridge.new(socket)
	multiplayer_bridge.match_join_error.connect(match_join_error)
	multiplayer_bridge.match_joined.connect(match_joined)
	get_tree().get_multiplayer().set_multiplayer_peer(multiplayer_bridge.multiplayer_peer)

func match_join_error(err):
	print("error joining match ", err.message)

func match_joined():
	print("match joined with id: ", multiplayer_bridge.match_id)

func create_join_lobby(lobby_name):
	var created_match = await socket.create_match_async(lobby_name)
	if created_match.is_exception():
		print("failed to create match ", created_match)
		return
	print("created match: ", created_match.match_id)

func on_match_presence(presence: NakamaRTAPI.MatchPresenceEvent):
	print(presence)

func on_match_state(state:NakamaRTAPI.MatchData):
	print(state)

func on_socket_connected():
	print("socket connected")

func on_socket_closed():
	print("socket closed")

func on_socket_error(err):
	print("error received: ", err)
