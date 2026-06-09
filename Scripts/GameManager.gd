extends Node2D

@export var TestingLabel: Label

var player_scene := preload("res://Scenes/player.tscn")

const SPAWN_POSITIONS := [Vector2(298, 293), Vector2(836, 293), Vector2(298, 493), Vector2(836, 493)]
var _spawn_index := 0

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)

	if MatchSetupInfo.local_debug_mode:
		if MatchSetupInfo.local_player_index == 0:
			_setup_local_debug_host()
		else:
			_setup_local_debug_client()
		return

	if MatchSetupInfo.local_player_index == 0:
		_setup_steam_host()
	else:
		_setup_steam_client()

func _setup_steam_host() -> void:
	var peer := SteamMultiplayerPeer.new()
	if peer.create_host(0) == OK:
		multiplayer.multiplayer_peer = peer
		TestingLabel.text = "Hosting..."
		_spawn_player(1)
	else:
		TestingLabel.text = "Failed to host"

func _setup_steam_client() -> void:
	var peer := SteamMultiplayerPeer.new()
	if peer.create_client(MatchSetupInfo.player_steam_ids[0], 0) == OK:
		multiplayer.multiplayer_peer = peer
		TestingLabel.text = "Connecting..."
	else:
		TestingLabel.text = "Failed to connect"

func _setup_local_debug_host() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(9999, 4)
	multiplayer.multiplayer_peer = peer
	TestingLabel.text = "Hosting (local debug)"
	_spawn_player(1)

func _setup_local_debug_client() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 9999)
	multiplayer.multiplayer_peer = peer
	TestingLabel.text = "Joining (local debug)"

func _spawn_player(peer_id: int) -> void:
	var player := player_scene.instantiate()
	player.name = str(peer_id)
	player.position = SPAWN_POSITIONS[_spawn_index % SPAWN_POSITIONS.size()]
	_spawn_index += 1
	$Players.add_child(player, true)

func _on_peer_connected(peer_id: int) -> void:
	TestingLabel.text = "Peer connected: %s" % peer_id
	if multiplayer.is_server():
		_spawn_player(peer_id)

func _on_connected_to_server() -> void:
	TestingLabel.text = "Connected to server"

func _on_peer_disconnected(peer_id: int) -> void:
	TestingLabel.text = "Peer disconnected: %s" % peer_id
	if multiplayer.is_server():
		var player := $Players.get_node_or_null(str(peer_id))
		if player:
			player.queue_free()

func _on_server_disconnected() -> void:
	TestingLabel.text = "Server disconnected"
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
