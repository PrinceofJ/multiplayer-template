extends Control

# --- UI Node References (use @onready or export NodePath) ---
@export var lobby_title_label: Label
@export var p1_name_label: Label
@export var p1_ready_label: Label
@export var p2_name_label: Label
@export var p2_ready_label: Label
@export var ready_button: Button
@export var start_game_button: Button
@export var leave_lobby_button: Button

var local_player_steam_id = null
var is_host = false
var players_in_lobby = {} # Dictionary: { steam_id: {name: "Name", ready: false, slot: 1 or 2} }
var player_slots = [null, null] # [P1_SteamID, P2_SteamID]

var local_player_ready_state = false

func _ready():
	if SteamManager.current_lobby_id == null or SteamManager.current_lobby_id == 0:
		printerr("LobbyScene: No valid lobby ID found. Returning to main menu.")
		get_tree().change_scene_to_file("res://Menu.tscn") # Adjust path
		return

	local_player_steam_id = Steam.getSteamID() # Get local player's Steam ID
	is_host = (Steam.getLobbyOwner(SteamManager.current_lobby_id) == local_player_steam_id)

	# Connect to signals from SteamManager
	if SteamManager.has_signal("player_joined_lobby"):
		SteamManager.player_joined_lobby.connect(Callable(self, "_on_player_joined_lobby"))
	if SteamManager.has_signal("player_left_lobby"):
		SteamManager.player_left_lobby.connect(Callable(self, "_on_player_left_lobby"))
	if SteamManager.has_signal("lobby_metadata_updated"):
		SteamManager.lobby_metadata_updated.connect(Callable(self, "_on_lobby_metadata_updated"))
	if SteamManager.has_signal("local_player_kicked_from_lobby"):
		SteamManager.local_player_kicked_from_lobby.connect(Callable(self, "_on_local_player_kicked"))
	# if SteamManager.has_signal("game_start_initiated"): # Ensure this signal exists in SteamManager if you uncomment
	#	SteamManager.game_start_initiated.connect(Callable(self, "_on_game_start_initiated"))

	# Connect UI element signals
	if ready_button: # Good practice to check if the node exists
		ready_button.pressed.connect(Callable(self, "_on_ready_button_pressed"))
	if leave_lobby_button:
		leave_lobby_button.pressed.connect(Callable(self, "_on_leave_lobby_button_pressed"))

	if start_game_button:
		start_game_button.pressed.connect(Callable(self, "_on_start_game_button_pressed"))
		start_game_button.visible = is_host # Only host sees start button
		start_game_button.disabled = true # Disabled until conditions are met

	print("LobbyScene: Joined/Created Lobby ID: " + str(SteamManager.current_lobby_id))
	print("LobbyScene: Local player Steam ID: " + str(local_player_steam_id))
	print("LobbyScene: Is host? " + str(is_host))

	initial_lobby_member_scan()
	update_ui_display()

func initial_lobby_member_scan():
	if SteamManager.current_lobby_id == null or SteamManager.current_lobby_id == 0: return

	var num_members = Steam.getNumLobbyMembers(SteamManager.current_lobby_id)
	print("LobbyScene: Initial scan, " + str(num_members) + " members found.")
	for i in range(num_members):
		var member_id = Steam.getLobbyMemberByIndex(SteamManager.current_lobby_id, i)
		if member_id != 0 and member_id != null:
			var member_name = Steam.getFriendPersonaName(member_id)
			add_player_to_lobby_data(member_id, member_name)
	assign_slots_and_refresh_data()


func add_player_to_lobby_data(steam_id, player_name):
	if not players_in_lobby.has(steam_id):
		players_in_lobby[steam_id] = {"name": player_name, "ready": false, "slot": -1}
		print("LobbyScene: Added player to data: " + player_name + " (" + str(steam_id) + ")")

func remove_player_from_lobby_data(steam_id):
	if players_in_lobby.has(steam_id):
		var player_data = players_in_lobby[steam_id]
		if player_data.slot != -1:
			player_slots[player_data.slot -1] = null # Clear slot
		players_in_lobby.erase(steam_id)
		print("LobbyScene: Removed player from data: " + str(steam_id))


func assign_slots_and_refresh_data():
	# Simple slot assignment: host is P1, first joiner is P2
	var current_members = players_in_lobby.keys()
	var assigned_count = 0

	# Prioritize host as P1
	var lobby_owner_id = Steam.getLobbyOwner(SteamManager.current_lobby_id)
	if lobby_owner_id in current_members and assigned_count < 2 and (player_slots[0] == null or player_slots[0] == lobby_owner_id) :
		player_slots[0] = lobby_owner_id
		players_in_lobby[lobby_owner_id].slot = 1
		assigned_count += 1

	# Assign other players
	for member_id in current_members:
		if assigned_count >= 2: break
		if member_id != lobby_owner_id: # If not the host already assigned
			if player_slots[0] == null: # P1 slot is free
				player_slots[0] = member_id
				players_in_lobby[member_id].slot = 1
				assigned_count +=1
			elif player_slots[1] == null: # P2 slot is free
				player_slots[1] = member_id
				players_in_lobby[member_id].slot = 2
				assigned_count +=1

	# Fetch readiness (if stored in lobby member data)
	for member_id in current_members:
		if players_in_lobby.has(member_id):
			var ready_status_str = Steam.getLobbyMemberData(SteamManager.current_lobby_id, member_id, "ready")
			players_in_lobby[member_id].ready = (ready_status_str == "true")
			print("LobbyScene: Player " + players_in_lobby[member_id].name + " ready status from Steam: " + ready_status_str)

	update_ui_display()
	check_start_game_conditions()


func update_ui_display():
	lobby_title_label.text = "Lobby ID: " + str(SteamManager.current_lobby_id)

	# Player 1 Slot
	if player_slots[0] != null and players_in_lobby.has(player_slots[0]):
		var p1_data = players_in_lobby[player_slots[0]]
		p1_name_label.text = "Player 1: " + p1_data.name
		p1_ready_label.text = "Ready" if p1_data.ready else "Not Ready"
	else:
		p1_name_label.text = "Player 1: Waiting..."
		p1_ready_label.text = ""

	# Player 2 Slot
	if player_slots[1] != null and players_in_lobby.has(player_slots[1]):
		var p2_data = players_in_lobby[player_slots[1]]
		p2_name_label.text = "Player 2: " + p2_data.name
		p2_ready_label.text = "Ready" if p2_data.ready else "Not Ready"
	else:
		p2_name_label.text = "Player 2: Waiting..."
		p2_ready_label.text = ""

	# Update local player's ready button text
	if players_in_lobby.has(local_player_steam_id):
		ready_button.text = "Unready" if players_in_lobby[local_player_steam_id].ready else "Ready"


func check_start_game_conditions():
	if not is_host or not start_game_button:
		return

	if player_slots[0] != null and player_slots[1] != null and \
	   players_in_lobby.has(player_slots[0]) and players_in_lobby[player_slots[0]].ready and \
	   players_in_lobby.has(player_slots[1]) and players_in_lobby[player_slots[1]].ready:
		start_game_button.disabled = false
		lobby_title_label.text = "Ready to Start!"
	else:
		start_game_button.disabled = true
		if not (player_slots[0]) != null and player_slots[1] != null:
			lobby_title_label.text = "Waiting for 1 more player..."
		else:
			lobby_title_label.text = "Waiting for players to be ready..."


# --- Signal Handlers from SteamManager ---
func _on_player_joined_lobby(player_steam_id, player_name):
	print("LobbyScene: Player joined event: " + player_name)
	add_player_to_lobby_data(player_steam_id, player_name)
	assign_slots_and_refresh_data()

func _on_player_left_lobby(player_steam_id):
	print("LobbyScene: Player left event: " + str(player_steam_id))
	remove_player_from_lobby_data(player_steam_id)
	assign_slots_and_refresh_data() # Re-assign slots if necessary and update UI

func _on_lobby_metadata_updated():
	print("LobbyScene: Lobby metadata updated event.")
	# This could be triggered by ready status changes or game start signal
	# Re-fetch all relevant data and update UI
	assign_slots_and_refresh_data()

	var game_starting_flag = Steam.getLobbyData(SteamManager.current_lobby_id, "game_starting")
	if game_starting_flag == "true":
		_initiate_game_transition()


func _on_local_player_kicked():
	print("LobbyScene: Local player was kicked!")
	get_tree().change_scene("res://scenes/MainMenuScene.tscn")


func _on_ready_button_pressed():
	if not players_in_lobby.has(local_player_steam_id): return

	local_player_ready_state = not players_in_lobby[local_player_steam_id].ready
	players_in_lobby[local_player_steam_id].ready = local_player_ready_state # Update local cache immediately for responsiveness
	ready_button.text = "Unready" if local_player_ready_state else "Ready"

	var ready_str: String = "true" if local_player_ready_state else "false"
	Steam.setLobbyMemberData(SteamManager.current_lobby_id, "ready", ready_str)
	_on_lobby_metadata_updated()

func _on_start_game_button_pressed():
	if not is_host: return
	print("LobbyScene: Host clicked Start Game.")
	Steam.setLobbyData(SteamManager.current_lobby_id, "game_starting", "true")

func _initiate_game_transition():
	print("LobbyScene: Initiating game transition!")

	if player_slots[0] == null or player_slots[1] == null:
		printerr("LobbyScene: Cannot start game, player slots not filled correctly.")
		if is_host:
			Steam.deleteLobbyData(SteamManager.current_lobby_id, "game_starting")
		return

	MatchSetupInfo.player_steam_ids[0] = player_slots[0]
	MatchSetupInfo.player_steam_ids[1] = player_slots[1]

	if local_player_steam_id == player_slots[0]:
		MatchSetupInfo.local_player_index = 0 # Local player is P1
	elif local_player_steam_id == player_slots[1]:
		MatchSetupInfo.local_player_index = 1 # Local player is P2
	else:
		# This local player is a spectator or something went wrong
		printerr("LobbyScene: Local player is not P1 or P2 in the match setup!")
		MatchSetupInfo.local_player_index = -1 # Indicate spectator or error
		# For a 1v1, non-spectator game, you might want to prevent transition or handle error

	print("MatchSetupInfo: P1 ID: " + str(MatchSetupInfo.player_steam_ids[0]) +
		  ", P2 ID: " + str(MatchSetupInfo.player_steam_ids[1]) +
		  ", Local Player Index: " + str(MatchSetupInfo.local_player_index))

	# TODO: Store selected characters, stage, etc., in MatchSetupInfo if applicable

	# Disable further lobby interactions (optional)
	ready_button.disabled = true
	start_game_button.disabled = true
	leave_lobby_button.disabled = true

	get_tree().change_scene("res://scenes/GameScene.tscn") # Path to your actual game scene


func _on_leave_lobby_button_pressed():
	if SteamManager.current_lobby_id != null and SteamManager.current_lobby_id != 0:
		Steam.leaveLobby(SteamManager.current_lobby_id)
		# SteamManager will get a lobby_chat_update for self, and then current_lobby_id can be cleared.
		# Or clear it here and let other players get the update.

	players_in_lobby.clear()
	player_slots = [null, null]
	SteamManager.current_lobby_id = null # Clear it for the local player
	get_tree().change_scene_to_file("res://Menu.tscn")


func _exit_tree() -> void:
	if not is_instance_valid(SteamManager):
		print("SteamManager instance is not valid in _exit_tree. Skipping disconnects.")
		return

	# Create Callables for each method once to avoid repetition
	var on_player_joined_callable = Callable(self, "_on_player_joined_lobby")
	var on_player_left_callable = Callable(self, "_on_player_left_lobby")
	var on_metadata_updated_callable = Callable(self, "_on_lobby_metadata_updated")
	var on_kicked_callable = Callable(self, "_on_local_player_kicked")
	# var on_game_start_callable = Callable(self, "_on_game_start_initiated") # If you add this one

	if SteamManager.has_signal("player_joined_lobby"):
		if SteamManager.player_joined_lobby.is_connected(on_player_joined_callable):
			SteamManager.player_joined_lobby.disconnect(on_player_joined_callable)
			print("LobbyScene: Disconnected player_joined_lobby.")

	if SteamManager.has_signal("player_left_lobby"):
		if SteamManager.player_left_lobby.is_connected(on_player_left_callable):
			SteamManager.player_left_lobby.disconnect(on_player_left_callable)
			print("LobbyScene: Disconnected player_left_lobby.")

	if SteamManager.has_signal("lobby_metadata_updated"):
		if SteamManager.lobby_metadata_updated.is_connected(on_metadata_updated_callable):
			SteamManager.lobby_metadata_updated.disconnect(on_metadata_updated_callable)
			print("LobbyScene: Disconnected lobby_metadata_updated.")

	if SteamManager.has_signal("local_player_kicked_from_lobby"):
		if SteamManager.local_player_kicked_from_lobby.is_connected(on_kicked_callable):
			SteamManager.local_player_kicked_from_lobby.disconnect(on_kicked_callable)
			print("LobbyScene: Disconnected local_player_kicked_from_lobby.")
