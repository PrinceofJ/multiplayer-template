extends Control

@export var create_lobby_button: Button
@export var join_button: Button
@export var lobby_id_input: LineEdit

@export var local_host_button: Button
@export var local_join_button: Button


func _ready():
	create_lobby_button.pressed.connect(_on_create_lobby_button_pressed)
	join_button.pressed.connect(_on_join_by_id_button_pressed)
	local_host_button.pressed.connect(_on_local_host_button_pressed)
	local_join_button.pressed.connect(_on_local_join_button_pressed)

	var on_lobby_created_callable = Callable(self, "_on_steam_lobby_creation_result")
	if not SteamManager.is_connected("steam_lobby_created", on_lobby_created_callable):
		SteamManager.steam_lobby_created.connect(on_lobby_created_callable)

	if create_lobby_button:
		if not Steam.isSteamRunning():
			create_lobby_button.disabled = true
			create_lobby_button.tooltip_text = "Steam is not available."
		else:
			create_lobby_button.disabled = false
			create_lobby_button.text = "Host Game"


func _on_local_host_button_pressed():
	MatchSetupInfo.local_player_index = 0 # Local player is P1
	MatchSetupInfo.local_debug_mode = true
	get_tree().change_scene_to_file("res://Scenes/GameScene.tscn")

func _on_local_join_button_pressed():
	MatchSetupInfo.local_player_index = 1 # Local player is P2
	MatchSetupInfo.local_debug_mode = true
	get_tree().change_scene_to_file("res://Scenes/GameScene.tscn")

func _on_create_lobby_button_pressed():
	if create_lobby_button:
		print("MainMenuScene: Create Lobby Button Pressed!")
		create_lobby_button.disabled = true
		create_lobby_button.text = "Creating..."

	var lobby_type = Steam.LOBBY_TYPE_FRIENDS_ONLY
	var max_players = 4

	SteamManager.create_steam_lobby(lobby_type, max_players)


func _on_steam_lobby_creation_result(result_code, lobby_id):
	if result_code == Steam.RESULT_OK:
		print("MainMenuScene: Successfully created lobby! Lobby ID:", lobby_id, ". Transitioning...")
		get_tree().change_scene_to_file("res://Scenes/lobby.tscn")
	else:
		printerr("MainMenuScene: Failed to create lobby. Error code:", result_code)
		if create_lobby_button:
			create_lobby_button.text = "Host Game"
			create_lobby_button.disabled = false

func _on_join_by_id_button_pressed():
	if not lobby_id_input:
		printerr("LobbyIDInput node not found!")
		return

	var id_string = lobby_id_input.text.strip_edges()
	if id_string == "":
		print("Lobby ID input is empty.")
		return


	if not id_string.is_valid_int():
		print("Invalid Lobby ID format: " + id_string)
		return

	print("MainMenuScene: Attempting to join lobby by ID: " + id_string)
	if join_button:
		join_button.disabled = true
		join_button.text = "Joining..."

	SteamManager.join_steam_lobby_by_id(id_string)


func _exit_tree():
	var on_lobby_created_callable = Callable(self, "_on_steam_lobby_creation_result")
	if SteamManager.is_connected("steam_lobby_created", on_lobby_created_callable):
		SteamManager.steam_lobby_created.disconnect(on_lobby_created_callable)
