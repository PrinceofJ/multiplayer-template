extends Control

@export var lobby_title_label: Label
@export var player_name_labels: Array[Label]
@export var player_ready_labels: Array[Label]
@export var ready_button: Button
@export var start_game_button: Button
@export var leave_lobby_button: Button

var local_player_steam_id = null
var is_host := false
var players_in_lobby := {}
var player_slots := [null, null, null, null]

var local_player_ready_state := false

func _ready():
	if SteamManager.current_lobby_id == null or SteamManager.current_lobby_id == 0:
		printerr("LobbyScene: No valid lobby ID found. Returning to main menu.")
		get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
		return

	local_player_steam_id = Steam.getSteamID()
	is_host = (Steam.getLobbyOwner(SteamManager.current_lobby_id) == local_player_steam_id)
	Steam.connect("lobby_data_update", self._on_lobby_metadata_updated)

	if ready_button:
		ready_button.pressed.connect(_on_ready_button_pressed)
	if leave_lobby_button:
		leave_lobby_button.pressed.connect(_on_leave_lobby_button_pressed)

	if start_game_button:
		start_game_button.pressed.connect(_on_start_game_button_pressed)
		start_game_button.visible = is_host
		start_game_button.disabled = true

	if is_host:
		Steam.setLobbyData(SteamManager.current_lobby_id, "host_id", str(local_player_steam_id))

	initial_lobby_member_scan()
	update_ui_display()

func initial_lobby_member_scan():
	if SteamManager.current_lobby_id == null or SteamManager.current_lobby_id == 0:
		return

	var num_members = Steam.getNumLobbyMembers(SteamManager.current_lobby_id)
	for i in range(num_members):
		var member_id = Steam.getLobbyMemberByIndex(SteamManager.current_lobby_id, i)
		if member_id != 0 and member_id != null:
			var member_name = Steam.getFriendPersonaName(member_id)
			add_player_to_lobby_data(member_id, member_name)
	assign_slots_and_refresh_data()

func add_player_to_lobby_data(steam_id, player_name):
	if not players_in_lobby.has(steam_id):
		players_in_lobby[steam_id] = {"name": player_name, "ready": false, "slot": -1}

func remove_player_from_lobby_data(steam_id):
	if players_in_lobby.has(steam_id):
		var player_data = players_in_lobby[steam_id]
		if player_data != null and player_data.slot >= 0:
			player_slots[player_data.slot] = null
		players_in_lobby.erase(steam_id)

func assign_slots_and_refresh_data():
	var current_members = players_in_lobby.keys()
	var lobby_owner_id = Steam.getLobbyOwner(SteamManager.current_lobby_id)

	# Host always gets slot 0
	if lobby_owner_id in current_members:
		if player_slots[0] == null or player_slots[0] == lobby_owner_id:
			player_slots[0] = lobby_owner_id
			players_in_lobby[lobby_owner_id].slot = 0

	# Assign remaining players to open slots
	for member_id in current_members:
		if member_id == lobby_owner_id:
			continue
		var data = players_in_lobby[member_id]
		if data == null:
			continue
		if data.slot >= 0 and player_slots[data.slot] == member_id:
			continue
		for i in range(MatchSetupInfo.MAX_PLAYERS):
			if player_slots[i] == null:
				player_slots[i] = member_id
				data.slot = i
				break

	# Refresh ready states from Steam lobby data
	for member_id in current_members:
		if players_in_lobby.has(member_id) and players_in_lobby[member_id] != null:
			var ready_status_str = Steam.getLobbyMemberData(SteamManager.current_lobby_id, member_id, "ready")
			players_in_lobby[member_id].ready = (ready_status_str == "true")

	update_ui_display()
	check_start_game_conditions()

func update_ui_display():
	lobby_title_label.text = "Lobby ID: " + str(SteamManager.current_lobby_id)

	for i in range(MatchSetupInfo.MAX_PLAYERS):
		if i >= player_name_labels.size() or i >= player_ready_labels.size():
			break
		if player_slots[i] != null and players_in_lobby.has(player_slots[i]) and players_in_lobby[player_slots[i]] != null:
			var p_data = players_in_lobby[player_slots[i]]
			player_name_labels[i].text = "Player %s: %s" % [i + 1, p_data.name]
			player_ready_labels[i].text = "Ready" if p_data.ready else "Not Ready"
		else:
			player_name_labels[i].text = "Player %s: Waiting..." % (i + 1)
			player_ready_labels[i].text = ""

	if players_in_lobby.has(local_player_steam_id) and players_in_lobby[local_player_steam_id] != null:
		ready_button.text = "Unready" if players_in_lobby[local_player_steam_id].ready else "Ready"

func check_start_game_conditions():
	if not is_host or not start_game_button:
		return

	var filled_count := 0
	var all_ready := true
	for i in range(MatchSetupInfo.MAX_PLAYERS):
		if player_slots[i] != null and players_in_lobby.has(player_slots[i]) and players_in_lobby[player_slots[i]] != null:
			filled_count += 1
			if not players_in_lobby[player_slots[i]].ready:
				all_ready = false

	if filled_count >= 2 and all_ready:
		start_game_button.disabled = false
		lobby_title_label.text = "Ready to Start! (%s players)" % filled_count
	else:
		start_game_button.disabled = true
		if filled_count < 2:
			lobby_title_label.text = "Waiting for players... (%s/4)" % filled_count
		else:
			lobby_title_label.text = "Waiting for players to be ready..."

func _on_lobby_metadata_updated(_a: int, _b: int, _c: bool):
	check_for_players()
	assign_slots_and_refresh_data()

	var game_starting_flag = Steam.getLobbyData(SteamManager.current_lobby_id, "game_starting")
	if game_starting_flag == "true":
		_initiate_game_transition()

func check_for_players():
	var num_members = Steam.getNumLobbyMembers(SteamManager.current_lobby_id)
	var known_ids := []

	for i in range(num_members):
		var member_id = Steam.getLobbyMemberByIndex(SteamManager.current_lobby_id, i)
		if member_id != 0 and member_id != null:
			known_ids.append(member_id)
			if not players_in_lobby.has(member_id):
				add_player_to_lobby_data(member_id, Steam.getFriendPersonaName(member_id))

	# Remove players who left
	for steam_id in players_in_lobby.keys():
		if steam_id not in known_ids:
			remove_player_from_lobby_data(steam_id)

func _on_ready_button_pressed():
	if not players_in_lobby.has(local_player_steam_id):
		return

	local_player_ready_state = not players_in_lobby[local_player_steam_id].ready
	players_in_lobby[local_player_steam_id].ready = local_player_ready_state
	ready_button.text = "Unready" if local_player_ready_state else "Ready"

	var ready_str: String = "true" if local_player_ready_state else "false"
	Steam.setLobbyMemberData(SteamManager.current_lobby_id, "ready", ready_str)

func _on_start_game_button_pressed():
	if not is_host:
		get_tree().change_scene_to_file("res://Scenes/GameScene.tscn")
		return
	Steam.setLobbyData(SteamManager.current_lobby_id, "game_starting", "true")

func _initiate_game_transition():
	for i in range(MatchSetupInfo.MAX_PLAYERS):
		MatchSetupInfo.player_steam_ids[i] = player_slots[i] if player_slots[i] != null else 0

	MatchSetupInfo.local_player_index = -1
	for i in range(MatchSetupInfo.MAX_PLAYERS):
		if local_player_steam_id == player_slots[i]:
			MatchSetupInfo.local_player_index = i
			break

	if MatchSetupInfo.local_player_index == -1:
		printerr("LobbyScene: Local player not found in any slot!")
		return

	ready_button.disabled = true
	start_game_button.disabled = true
	leave_lobby_button.disabled = true

	get_tree().change_scene_to_file("res://Scenes/GameScene.tscn")

func _on_leave_lobby_button_pressed():
	if SteamManager.current_lobby_id != null and SteamManager.current_lobby_id != 0:
		Steam.leaveLobby(SteamManager.current_lobby_id)
	players_in_lobby.clear()
	player_slots = [null, null, null, null]
	SteamManager.current_lobby_id = null
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

func _on_local_player_kicked():
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

func _exit_tree() -> void:
	if not is_instance_valid(SteamManager):
		return
	if Steam.is_connected("lobby_data_update", _on_lobby_metadata_updated):
		Steam.disconnect("lobby_data_update", _on_lobby_metadata_updated)
