extends Control

@export var create_lobby_button: Button
@export var join_button: Button
@export var lobby_id_input: LineEdit
@export var local_host_button: Button
@export var local_join_button: Button

const AUTO_DEBUG_PORT := 9999

func _ready():
	create_lobby_button.pressed.connect(_on_create_lobby_button_pressed)
	join_button.pressed.connect(_on_join_by_id_button_pressed)
	local_host_button.pressed.connect(_on_local_host_button_pressed)
	local_join_button.pressed.connect(_on_local_join_button_pressed)

	var on_lobby_created_callable = Callable(self, "_on_steam_lobby_creation_result")
	if not SteamManager.is_connected("steam_lobby_created", on_lobby_created_callable):
		SteamManager.steam_lobby_created.connect(on_lobby_created_callable)

	# Auto-launch support:
	# --server / --client: explicit role (from debug_launch.sh)
	# --auto-debug: try to host, fall back to client (for Godot's "Run Multiple Instances")
	var args = OS.get_cmdline_user_args()
	if "--server" in args:
		_auto_start_host()
	elif "--client" in args:
		_auto_start_client()
	elif "--auto-debug" in args:
		_auto_detect_role()

func _auto_detect_role():
	var peer := ENetMultiplayerPeer.new()
	var err = peer.create_server(AUTO_DEBUG_PORT, 4)
	if err == OK:
		# Port was free - we're the first instance, so we're the host
		peer.close()
		_auto_start_host()
	else:
		# Port taken - a host already exists, join as client
		_auto_start_client()

func _auto_start_host():
	MatchSetupInfo.local_player_index = 0
	MatchSetupInfo.local_debug_mode = true
	get_tree().change_scene_to_file("res://Scenes/GameScene.tscn")

func _auto_start_client():
	MatchSetupInfo.local_player_index = 1
	MatchSetupInfo.local_debug_mode = true
	get_tree().change_scene_to_file("res://Scenes/GameScene.tscn")

func _on_local_host_button_pressed():
	_auto_start_host()

func _on_local_join_button_pressed():
	_auto_start_client()

func _on_create_lobby_button_pressed():
	if create_lobby_button:
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
