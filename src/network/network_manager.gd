extends Node

## Manages multiplayer networking transport.
## Game code should only use multiplayer API and RPCs — never access transport directly.
## Transport can be swapped (ENet for LAN, EOS for internet) without changing game logic.

signal player_connected(id: int)
signal player_disconnected(id: int)
signal server_disconnected()
signal connection_failed()
signal connected_to_server()

const DEFAULT_PORT: int = 23456
const DEFAULT_MAX_CLIENTS: int = 4
const SERVER_ID: int = 1

# ENet defaults (used when transport is ENET_LAN)
const _ENET_CHANNELS: int = 4
const _ENET_IN_BANDWIDTH: int = 0
const _ENET_OUT_BANDWIDTH: int = 0

## Transport layer types. Game code can query this to branch on capabilities.
enum TransportType { ENET_LAN, EOS_P2P }

var _is_host: bool = false
var _is_dedicated_server: bool = false
var max_clients: int = DEFAULT_MAX_CLIENTS
var _transport: int = TransportType.ENET_LAN

## Internal peer — game code must not reference this directly.
## Use multiplayer API and RPCs instead.
var _peer: MultiplayerPeer
var _upnp: UPNP


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func get_transport() -> int:
	return _transport


## Returns true if connected via internet transport (EOS) rather than direct LAN.
func is_internet_transport() -> bool:
	return _transport != TransportType.ENET_LAN


var local_player_id: int:
	get: return multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 1

var is_host: bool:
	get: return _is_host

var is_client: bool:
	get: return not _is_host and not _is_dedicated_server

var is_dedicated_server: bool:
	get: return _is_dedicated_server


## Host a game using ENet (LAN). For internet play, EOS transport will be used instead.
func host_game(port: int = DEFAULT_PORT, max_players: int = DEFAULT_MAX_CLIENTS) -> void:
	_transport = TransportType.ENET_LAN
	_peer = ENetMultiplayerPeer.new()
	var err: Error = _peer.create_server(port, max_players, _ENET_CHANNELS, _ENET_IN_BANDWIDTH, _ENET_OUT_BANDWIDTH)
	if err != OK:
		push_error("Failed to create server: %d" % err)
		return
	max_clients = max_players
	multiplayer.multiplayer_peer = _peer
	_is_host = true
	_try_upnp(port)


## Host a dedicated server (headless, no player host).
func host_dedicated(port: int = DEFAULT_PORT, max_players: int = DEFAULT_MAX_CLIENTS) -> void:
	_transport = TransportType.ENET_LAN
	_peer = ENetMultiplayerPeer.new()
	var err: Error = _peer.create_server(port, max_players, _ENET_CHANNELS, _ENET_IN_BANDWIDTH, _ENET_OUT_BANDWIDTH)
	if err != OK:
		push_error("Failed to create dedicated server: %d" % err)
		return
	max_clients = max_players
	multiplayer.multiplayer_peer = _peer
	_is_host = true
	_is_dedicated_server = true
	_try_upnp(port)


## Join a game at the given IP and port using ENet transport.
func join_game(ip: String, port: int = DEFAULT_PORT) -> void:
	_transport = TransportType.ENET_LAN
	_peer = ENetMultiplayerPeer.new()
	var err: Error = _peer.create_client(ip, port, _ENET_CHANNELS, _ENET_IN_BANDWIDTH, _ENET_OUT_BANDWIDTH)
	if err != OK:
		push_error("Failed to create client: %d" % err)
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = _peer
	_is_host = false


## Disconnect and clean up all networking state.
func leave_game() -> void:
	multiplayer.multiplayer_peer = null
	_is_host = false
	_is_dedicated_server = false
	if _peer:
		_peer.close()
		_peer = null
	_remove_upnp()


# --- Internal signal handlers ---

func _on_peer_connected(id: int) -> void:
	player_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
	player_disconnected.emit(id)


func _on_connected_to_server() -> void:
	connected_to_server.emit()


func _on_connection_failed() -> void:
	connection_failed.emit()


func _on_server_disconnected() -> void:
	leave_game()
	server_disconnected.emit()


# --- UPNP (best-effort, not required for LAN play) ---

func _try_upnp(port: int) -> void:
	if not _upnp:
		_upnp = UPNP.new()
	var err := _upnp.discover()
	if err != OK:
		push_warning("UPNP discovery failed: %d — online players may not connect" % err)
		return
	err = _upnp.add_port_mapping(port, port, "BattleOx", "UDP")
	if err != OK:
		push_warning("UPNP port mapping failed: %d" % err)
	else:
		print("UPNP: Port %d forwarded successfully" % port)


func _remove_upnp() -> void:
	if _upnp and _upnp.get_gateway():
		_upnp.delete_port_mapping(DEFAULT_PORT, "UDP")
	_upnp = null
