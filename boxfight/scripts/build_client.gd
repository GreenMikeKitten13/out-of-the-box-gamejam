extends Node
class_name NakamaMultiplayer

var lobby_min_players = 1
var lobby_max_players = 10
var limit = 10
var authoritative = false

var globby_id #gloabl lobby id
var client : NakamaClient
var socket :NakamaSocket
var session : NakamaSession

var device_id = OS.get_unique_id()

var listed_lobbies = []

@onready var start_game: Button = get_tree().root.get_node("start_menu/Start game")
@onready var lobbylist: VBoxContainer = get_tree().root.get_node("start_menu/Lobbylist")
@onready var lobbyname: TextEdit = get_tree().root.get_node("start_menu/Lobbyname")
@onready var new_lobby_button:Button = get_tree().root.get_node("start_menu/Newlobby")
@onready var lobbylist_refresh_timer:Timer = lobbylist.get_node("lobbylist_refresh_timer")

const PLAYER = preload("uid://xp045ovbqpjw")

func _ready() -> void:
	new_lobby_button.pressed.connect(_on_newlobby_pressed)
	start_game.pressed.connect(_on_start_game_pressed)
	lobbylist_refresh_timer.timeout.connect(_on_lobbylist_refresh_timer_timeout)
	
	client = Nakama.create_client("defaultkey", "192.168.178.107", 7350, "http")
	client.logger._level = NakamaLogger.LOG_LEVEL.WARNING
	socket = Nakama.create_socket_from(client)
	session = await client.authenticate_device_async(OS.get_unique_id())
	
	if session.is_exception():
		print("Could not authenticate: %s" % session)
		return
	print("successfully authenticated: %s" % session)
	var connected:NakamaAsyncResult = await socket.connect_async(session)
	if connected.is_exception():
		print("And error occurred: %s" % connected)
		return
	print("Socket connected")
	socket.received_match_state.connect(on_data_recieved)

var match_connection

func join_lobby(lobby_id):
	match_connection = await socket.join_match_async(lobby_id)
	print("socket: ", socket, " connected to: ", lobby_id)
	globby_id = lobby_id

func _exit_tree() -> void:
	await client.session_logout_async(session)

func _on_newlobby_pressed() -> void:
	var lobby_name = lobbyname.text
	var lobby : NakamaRTAPI.Match = await socket.create_match_async()
	var lobby_id = lobby.match_id
	
	start_game.visible = true
	
	var write_object = NakamaWriteStorageObject.new("lobbies",lobby_id,2,1,JSON.stringify({"name":lobby_name, "match_id" : lobby_id}), "")
	await client.write_storage_objects_async(session, [write_object])
	
	var join_button:Button = Button.new()
	join_button.text = lobby_name
	lobbylist.add_child(join_button)
	join_button.pressed.connect(join_lobby.bind(lobby.match_id))
	listed_lobbies.append(lobby.match_id)
	globby_id = lobby_id
	match_connection = lobby

func _on_lobbylist_refresh_timer_timeout() -> void:
	var result = await client.list_matches_async(session, lobby_min_players, lobby_max_players, limit, authoritative, "", "")
	for lobby in result.matches:
		if lobby.match_id not in listed_lobbies:
			var join_button:Button = Button.new()
			lobbylist.add_child(join_button)
			join_button.pressed.connect(join_lobby.bind(lobby.match_id))
			
			var storage = await  client.read_storage_objects_async(session, [NakamaStorageObjectId.new("lobbies", lobby.match_id, session.user_id)])
			var lobby_name = "Unknown"
			if not storage.is_exception() and storage.objects.size() > 0:
				var data = JSON.parse_string(storage.objects[0].value)
				lobby_name = data.get("name", "Unknown")
			join_button.text = lobby_name
			listed_lobbies.append(lobby.match_id)

var start_game_code = 10

func _on_start_game_pressed() -> void:
	await socket.send_match_state_async(globby_id, start_game_code, "")
	load_main_game()

func on_data_recieved(data:NakamaRTAPI.MatchData):
	match data.op_code:
		start_game_code:
			load_main_game()
		1: #player moving
			pass
		_:
			push_warning("Unsopported op code on build_client.gd")

var players = {}

func load_main_game():
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")

func on_presence_received(presence:NakamaRTAPI.MatchPresenceEvent):
	for p in presence.joins:
		if p.session_id not in players:
			var go = PLAYER.instantiate()
			players[p.session_id] = go
			get_tree().root.get_node("Main game").add_child(go)
	for p in presence.leaves:
		if p.session_id in players:
			players[p.session_id].queue_free()
			players.erase(p.session_id)
