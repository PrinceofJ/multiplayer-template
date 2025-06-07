extends Node2D

@export var TestingLabel: Label

func _ready() -> void:
	multiplayer.connect("peer_connected", self._on_network_peer_connected)
	multiplayer.connect("peer_disconnected", self._on_network_peer_disconnected)
	multiplayer.connect("server_disconnected", self._on_server_disconnected)

	multiplayer.connect("connected_to_server", self._on_connection_success)

	var localSteamID = MatchSetupInfo.player_steam_ids[MatchSetupInfo.local_player_index]
	if MatchSetupInfo.local_player_index == 0:
		print("i am a host")

		var peer = SteamMultiplayerPeer.new()
		peer.create_host(0)
		#multiplayer.multiplayer_peer = peer
	else:
		print("i am a client")
		var peer = SteamMultiplayerPeer.new()
		print(MatchSetupInfo.player_steam_ids[0])
		var test = peer.create_client(MatchSetupInfo.player_steam_ids[0], 0) #should always be the host
		#multiplayer.multiplayer_peer = peer

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
