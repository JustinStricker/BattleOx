extends Node

const PlayerScene = preload("res://src/player/player.tscn")


func spawn_player_for_peer(peer_id: int, spawn_pos: Vector3) -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return
	rpc("_spawn_player", peer_id, spawn_pos)


func spawn_local_player(spawn_pos: Vector3) -> CharacterBody3D:
	var player := PlayerScene.instantiate()
	var player_id := multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 1
	player.name = "Player_%d" % player_id
	player.set_multiplayer_authority(player_id)
	add_child(player)
	player.global_position = spawn_pos
	player.add_to_group("local_player")
	player.add_to_group("player")
	_setup_local_player(player)
	return player


@rpc("authority", "call_local", "reliable")
func _spawn_player(peer_id: int, spawn_pos: Vector3) -> void:
	if multiplayer.multiplayer_peer != null and multiplayer.is_server() and peer_id != multiplayer.get_unique_id():
		return
	var player := PlayerScene.instantiate()
	player.name = "Player_%d" % peer_id
	player.set_multiplayer_authority(peer_id)
	add_child(player)
	player.global_position = spawn_pos
	if multiplayer.multiplayer_peer != null and peer_id == multiplayer.get_unique_id():
		player.add_to_group("local_player")
		_setup_local_player(player)
	player.add_to_group("player")


func _setup_local_player(player: CharacterBody3D) -> void:
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	if cam:
		cam.current = true
