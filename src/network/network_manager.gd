extends Node

signal player_connected(id: int)
signal player_disconnected(id: int)
signal server_disconnected()
signal connection_failed()

const DEFAULT_PORT: int = 23456

var local_player_id: int:
	get: return multiplayer.get_unique_id()

var is_host: bool:
	get: return multiplayer.is_server()

var is_client: bool:
	get: return not multiplayer.is_server()

var peer: ENetMultiplayerPeer


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_game(port: int = DEFAULT_PORT) -> void:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		push_error("Failed to create server: %d" % err)
		return
	multiplayer.multiplayer_peer = peer


func join_game(ip: String, port: int = DEFAULT_PORT) -> void:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		push_error("Failed to create client: %d" % err)
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer


func leave_game() -> void:
	multiplayer.multiplayer_peer = null
	if peer:
		peer.close()
		peer = null


func _on_peer_connected(id: int) -> void:
	player_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
	player_disconnected.emit(id)


func _on_connected_to_server() -> void:
	pass


func _on_connection_failed() -> void:
	connection_failed.emit()


func _on_server_disconnected() -> void:
	leave_game()
	server_disconnected.emit()
