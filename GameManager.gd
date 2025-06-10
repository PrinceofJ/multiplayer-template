extends Node2D

@export var TestingLabel: Label

func _ready() -> void:

	multiplayer.peer_connected.connect(_on_network_peer_connected)
	multiplayer.connect("peer_disconnected", self._on_network_peer_disconnected)
	multiplayer.connect("server_disconnected", self._on_server_disconnected)
	multiplayer.connect("connected_to_server", self._on_connection_success)

	if MatchSetupInfo.local_debug_mode:
		print("ENTERING LOCAL DEBUG")
		if MatchSetupInfo.local_player_index == 0:
			setup_local_debug_host()
			return
		elif MatchSetupInfo.local_player_index == 1:
			setup_local_debug_client()
			return

	#get_tree().multiplayer.connect("peer_connected", self._on_network_peer_connected)

	SyncManager.connect("sync_started", self.on_SyncManager_sync_started)
	SyncManager.connect("sync_stopped", self.on_SyncManager_sync_stopped)
	SyncManager.connect("sync_lost", self.on_SyncManager_sync_lost)
	SyncManager.connect("sync_regained", self.on_SyncManager_sync_regained)

	var _localSteamID = MatchSetupInfo.player_steam_ids[MatchSetupInfo.local_player_index]
	if MatchSetupInfo.local_player_index == 0:
		print("i am a host")

		var peer = SteamMultiplayerPeer.new()
		var error = peer.create_host(0)
		if error==OK:
			multiplayer.multiplayer_peer = peer
			print("it happened")
		else:
			print("DISASTER")

	else:
		print("i am a client")
		var peer = SteamMultiplayerPeer.new()
		print(MatchSetupInfo.player_steam_ids[0])
		var error = peer.create_client(MatchSetupInfo.player_steam_ids[0], 0) #should always be the host
		if error==OK:
			multiplayer.multiplayer_peer = peer
			print("yayayaya")
		else:
			print("DISASTER 2")

func _on_connection_success():
	print("yay!")

func _on_network_peer_connected(peer_id: int):
	TestingLabel.text = "connected"
	SyncManager.add_peer(peer_id)
	print("connected")
	if multiplayer.is_server():
		TestingLabel.text = "Starting"
		print("host is now starting up SyncManager")
		await get_tree().create_timer(2.0).timeout
		SyncManager.start()

func _on_network_peer_disconnected(peer_id: int):
	TestingLabel.text = "disconnected"
	SyncManager.remove_peer(peer_id)
	print("disconnected")

func _on_server_disconnected():
	print("server disconnected")
	_on_network_peer_disconnected(1)

func on_SyncManager_sync_started() -> void:
	print("Sync Started!")

func on_SyncManager_sync_stopped() -> void:
	print("sync stopped")
	pass

func on_SyncManager_sync_lost() -> void:
	print("sync lost")
	pass

func on_SyncManager_sync_regained() -> void:
	print("sync regained")
	pass

func _on_SyncManager_sync_error(msg: String) -> void:
	print("fatal sync error:", msg)
	var peer = multiplayer.multiplayer_peer
	if peer:
		print("should close connection here")
	SyncManager.clear_peers()


func setup_local_debug_host():
	print("debug mode local host")
	var peer = ENetMultiplayerPeer.new()
	TestingLabel.text = "listening"
	peer.create_server(9999, 1)
	multiplayer.multiplayer_peer = peer

func setup_local_debug_client():
	print("debug mode local client")
	var peer = ENetMultiplayerPeer.new()
	TestingLabel.text = "joining"
	peer.create_client("127.0.0.1", 9999)
	multiplayer.multiplayer_peer = peer
