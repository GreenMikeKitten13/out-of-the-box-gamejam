extends Node
class_name NakamaMultiplayer

var lobby_min_players = 1
var lobby_max_players = 10
var limit = 10
var authoritative = false

var game_started = false

var globby_id #gloabl lobby id
var client : NakamaClient
var socket :NakamaSocket
var session : NakamaSession

var device_id = OS.get_unique_id()

var listed_lobbies = []

@onready var start_game: Button = get_tree().root.get_node("start_menu/Start game")
@onready var lobbylist: VBoxContainer = get_tree().root.get_node("start_menu/Lobbylist")
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
	print(session)
	
	if session.is_exception():
		print("Could not authenticate: %s" % session)
		return
	print("successfully authenticated: %s" % session)
	var connected:NakamaAsyncResult = await socket.connect_async(session)
	if connected.is_exception():
		print("An error occurred: %s" % connected)
		return
	print("Socket connected")
	socket.received_match_state.connect(on_data_recieved)

var match_connection


func _process(delta: float) -> void:
	for user_id in players.keys():
		if user_id == session.user_id:
			continue
		var node = players[user_id]
		if node == null or not node.has_meta("target_position"):
			continue
		var target = node.get_meta("target_position")
		node.position = node.position.lerp(target, delta * 10)


func join_lobby(lobby_id):
	match_connection = await socket.join_match_async(lobby_id)
	socket.received_match_presence.connect(on_player_joined)
	print("socket: ", socket, " connected to: ", lobby_id)
	globby_id = lobby_id

func _exit_tree() -> void:
	await client.session_logout_async(session)

var players = {}

var server = false

func _on_newlobby_pressed() -> void:
	server = true
	var lobby : NakamaRTAPI.Match = await socket.create_match_async()
	var lobby_id = lobby.match_id
	
	start_game.visible = true

	
	var join_button:Button = Button.new()
	join_button.text = lobby_id
	lobbylist.add_child(join_button)
	join_button.pressed.connect(join_lobby.bind(lobby.match_id))
	listed_lobbies.append(lobby.match_id)
	globby_id = lobby_id
	match_connection = lobby
	socket.received_match_presence.connect(on_player_joined)
	
	players[lobby.self_user.user_id] = null

func _on_lobbylist_refresh_timer_timeout() -> void:
	var result = await client.list_matches_async(session, lobby_min_players, lobby_max_players, limit, authoritative, "", "")
	for lobby in result.matches:
		if lobby.match_id not in listed_lobbies:
			var join_button:Button = Button.new()
			lobbylist.add_child(join_button)
			join_button.pressed.connect(join_lobby.bind(lobby.match_id))
			
			var lobby_name = lobby.match_id

			join_button.text = lobby_name
			listed_lobbies.append(lobby.match_id)

var start_game_code = 10
var update_players_code = 2
var minigame_code = 3

func _on_start_game_pressed() -> void:
	await socket.send_match_state_async(globby_id, update_players_code, JSON.stringify(players))
	await socket.send_match_state_async(globby_id, start_game_code, "")
	load_main_game()
	decide_minigame()
	await socket.send_match_state_async(globby_id, minigame_code, JSON.stringify(current_minigame))

var lerp_speed = 4

func on_data_recieved(data:NakamaRTAPI.MatchData):
	match data.op_code:
		start_game_code:
			load_main_game()
		1:
			var position_status = JSON.parse_string(data.data)
			var user = data.presence.user_id
			if user in players and players[user] != null and user != session.user_id:
				players[user].set_meta("target_position", Vector3(
					position_status["X"],
					position_status["Y"],
					position_status["Z"]
				))
		update_players_code:
			var parsed = JSON.parse_string(data.data)
			players.clear()
			for key in parsed.keys():
				players[key] = null
		minigame_code:
			current_minigame = JSON.parse_string(data.data)
		_:
			push_warning("Unsopported op code on build_client.gd")

func load_main_game():
	if server:
		print("server vision: ", players.keys(), " are currently online, server_id is: ", session.user_id)
	else:
		print("client vision: ", players.keys(), " are currently online, client_id is: ", session.user_id)
	
	game_started = true
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")
	
	await get_tree().create_timer(0.5).timeout
	while players.keys().size() == 0 or !get_tree().root.get_node("Main game"):
		await get_tree().process_frame
	
	var start_y_position = 0
	
	for user_id in players.keys():
		var go = PLAYER.instantiate()
		go.name = user_id
		players[user_id] = go
		get_tree().root.get_node("Main game").add_child(go)
		go.position = Vector3(0, start_y_position,0)
		start_y_position += 4
		await get_tree().process_frame 
		go.set_physics_process(true)
		go.set_process(true)
		print("spawned: ", user_id, " at ", go.position)  
		var timer = go.get_node_or_null("Pos_send_timer")
		if timer:
			timer.stop()
			await get_tree().process_frame
			timer.start()

func on_player_joined(presence:NakamaRTAPI.MatchPresenceEvent):
	for p in presence.joins:
		if p.user_id not in players.keys():
			players[p.user_id] = null
	for p in presence.leaves:
		if p.user_id in players and game_started:
			players[p.user_id].queue_free()
			players.erase(p.user_id)
		elif p.user_id in players:
			players.erase(p.user_id)

var minigame_percentage = {"fps":0.33,"break":0.33, "build":0.33}
var current_minigame = ""

func decide_minigame():
	var randnumb = randf()
	if randnumb > minigame_percentage["fps"]:
		if randnumb > minigame_percentage["fps"] + minigame_percentage["break"]:
			current_minigame = "build"
		else:
			current_minigame = "break"
	else:
		current_minigame = "fps"
	set_percentage(current_minigame, minigame_percentage)

func set_percentage(winner, dictionary):
	dictionary[winner] -= 1
	for looser in dictionary.keys():
		dictionary[looser] += 0.5
