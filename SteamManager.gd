extends Node

signal steam_lobby_created(result_code, lobby_id)

var current_lobby_id = null

func _ready():
	if Steam.steamInit():
		print("Steam Initialized successfully! App ID: " + str(Steam.getAppID()))
		Steam.connect("lobby_created", self._on_steam_lobby_created_callback)
		Steam.connect("join_requested", self._on_game_lobby_join_requested_callback)
		Steam.connect("lobby_joined", self._on_lobby_entered_callback)
	else:
		printerr("Failed to initialize Steam.")

func _process(delta: float) -> void:
	Steam.run_callbacks()

func create_steam_lobby(lobby_type_enum, max_players: int) -> void:
	if not Steam.isSteamRunning():
		printerr("SteamManager: Cannot create lobby, Steam is not running or not initialized.")
		emit_signal("steam_lobby_created", Steam.RESULT_FAIL, 0)
		return

	print("SteamManager: Requesting to create Steam lobby...")
	Steam.createLobby(lobby_type_enum, max_players)

func _on_steam_lobby_created_callback(result_code, lobby_id):
	print("SteamManager: Received lobby_created callback. Result: " + str(result_code) + " Lobby ID: " + str(lobby_id))
	if result_code == Steam.RESULT_OK:
		print("SteamManager: Lobby created successfully! Lobby ID: " + str(lobby_id))

	else:
		printerr("SteamManager: Failed to create lobby. Steam Result code: " + str(result_code))
	current_lobby_id = lobby_id
	emit_signal("steam_lobby_created", result_code, lobby_id)


func join_steam_lobby_by_id(lobby_id_to_join):
	if not Steam.isSteamRunning():
		printerr("SteamManager: Cannot join lobby, Steam is not running or not initialized.")
		emit_signal("steam_lobby_joined", Steam.RESULT_FAIL, 0) # Or a specific error code
		return

	if lobby_id_to_join == null or lobby_id_to_join == "0":
		printerr("SteamManager: Invalid lobby_id_to_join provided: " + str(lobby_id_to_join))
		emit_signal("steam_lobby_joined", Steam.RESULT_FAIL, 0)
		return

	print("SteamManager: Requesting to join Steam lobby by ID: " + str(lobby_id_to_join))
	Steam.joinLobby(int(lobby_id_to_join))

func _on_game_lobby_join_requested_callback(lobby_id_from_invite, friend_steam_id):
	print("SteamManager: Received game_lobby_join_requested. Lobby ID: " + str(lobby_id_from_invite) + ", Friend ID: " + str(friend_steam_id))
	Steam.joinLobby(int(lobby_id_from_invite))


func _on_lobby_entered_callback(lobby_id, permissions, locked, response_code):
	print("SteamManager: Received lobby_entered callback. Lobby ID: " + str(lobby_id) + ", Response Code: " + str(response_code))

	var final_result_code = Steam.RESULT_FAIL
	var final_lobby_id = 0

	if response_code == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		print("SteamManager: Successfully entered lobby: " + str(lobby_id))
		current_lobby_id = lobby_id
		final_result_code = Steam.RESULT_OK
		final_lobby_id = lobby_id
		var owner_id = Steam.getLobbyOwner(current_lobby_id)
		print("SteamManager: Lobby owner is " + Steam.getFriendPersonaName(owner_id))
		Steam.setLobbyData(current_lobby_id, "Players", "HELLO WORLD")

		get_tree().change_scene_to_file("res://lobby.tscn")
	else:
		printerr("SteamManager: Failed to enter lobby. Steam Response code: " + str(response_code))
		current_lobby_id = null

	#emit_signal("steam_lobby_joined", final_result_code, final_lobby_id)
