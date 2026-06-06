extends Node

signal player_connected(id: int)
signal player_disconnected(id: int)
signal server_disconnected()
signal connection_failed()

const DEFAULT_PORT: int = 23456
const DEFAULT_MAX_CLIENTS: int = 4
const SERVER_ID: int = 1
const ENetChannels: int = 4
const ENetInBandwidth: int = 0
const ENetOutBandwidth: int = 0

var _is_host: bool = false
var _is_dedicated_server: bool = false
var max_clients: int = DEFAULT_MAX_CLIENTS

var local_player_id: int:
	get: return multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 1

var is_host: bool:
	get: return _is_host

var is_client: bool:
	get: return not _is_host and not _is_dedicated_server

var is_dedicated_server: bool:
	get: return _is_dedicated_server

var peer: ENetMultiplayerPeer
var _upnp: UPNP


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_game(port: int = DEFAULT_PORT, max_players: int = DEFAULT_MAX_CLIENTS) -> void:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_players, ENetChannels, ENetInBandwidth, ENetOutBandwidth)
	if err != OK:
		push_error("Failed to create server: %d" % err)
		return
	max_clients = max_players
	multiplayer.multiplayer_peer = peer
	_is_host = true
	_try_upnp(port)


func host_dedicated(port: int = DEFAULT_PORT, max_players: int = DEFAULT_MAX_CLIENTS) -> void:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_players, ENetChannels, ENetInBandwidth, ENetOutBandwidth)
	if err != OK:
		push_error("Failed to create dedicated server: %d" % err)
		return
	max_clients = max_players
	multiplayer.multiplayer_peer = peer
	_is_host = true
	_is_dedicated_server = true
	_try_upnp(port)


func join_game(ip: String, port: int = DEFAULT_PORT) -> void:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port, ENetChannels, ENetInBandwidth, ENetOutBandwidth)
	if err != OK:
		push_error("Failed to create client: %d" % err)
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	_is_host = false


func leave_game() -> void:
	multiplayer.multiplayer_peer = null
	_is_host = false
	_is_dedicated_server = false
	if peer:
		peer.close()
		peer = null
	_remove_upnp()


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


func _try_upnp(port: int) -> void:
	if not _upnp:
		_upnp = UPNP.new()
	var err := _upnp.discover()
	if err != OK:
		push_warning("UPNP discovery failed: %d — online players may not connect" % err)
		return
	err = _upnp.add_port_mapping(port, port, "Godot Demo", "UDP")
	if err != OK:
		push_warning("UPNP port mapping failed: %d" % err)
	else:
		print("UPNP: Port %d forwarded successfully" % port)


func _remove_upnp() -> void:
	if _upnp and _upnp.get_gateway():
		_upnp.delete_port_mapping(DEFAULT_PORT, "UDP")
	_upnp = null
