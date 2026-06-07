extends Node

var score: int = 0
var world_gen: WorldGen
var environment_node: Node3D
var player_node: CharacterBody3D
var arrow_container: Node3D
var enemy_mgr: Node
var ui_layer: CanvasLayer

var _client_spawn_pos: Vector3
var _player_spawner: MultiplayerSpawner

const LoadingScreenScene = preload("res://src/ui/loading_screen.tscn")
const EnvironmentNode = preload("res://src/world/environment.gd")
const PlayerScene = preload("res://src/player/player.tscn")
const UIScene = preload("res://src/ui/ui.tscn")
const ArrowScript = preload("res://src/player/arrow.gd")
const EnemyManager = preload("res://src/enemies/enemy_manager.gd")
const BiomeOverlayScene = preload("res://src/world/biome_overlay.gd")


func _ready() -> void:
	_player_spawner = MultiplayerSpawner.new()
	_player_spawner.name = "PlayerSpawner"
	_player_spawner.spawn_path = NodePath(".")
	_player_spawner.spawn_function = _player_spawn_function
	add_child(_player_spawner)

	if multiplayer.multiplayer_peer == null:
		_host_setup()
		return
	if NetworkManager.is_host:
		_host_setup()
	else:
		_client_setup()


func _host_setup() -> void:
	NetworkManager.player_connected.connect(_on_host_player_connected)

	var loading: CanvasLayer = LoadingScreenScene.instantiate()
	add_child(loading)

	loading.update("Generating heightmap...", 0.0)
	world_gen = WorldGen.new()
	add_child(world_gen)
	await get_tree().process_frame

	loading.update("Building terrain and scattering foliage...", 0.15)
	environment_node = EnvironmentNode.new()
	environment_node.world_gen = world_gen
	add_child(environment_node)
	await get_tree().process_frame

	var overlay := BiomeOverlayScene.new()
	overlay.world_gen = world_gen
	overlay.name = "BiomeOverlay"
	add_child(overlay)

	loading.update("Spawning entities...", 0.55)
	var spawn_pos := _find_spawn_position()
	player_node = _player_spawner.spawn({"peer_id": multiplayer.get_unique_id(), "spawn_pos": spawn_pos})

	ui_layer = UIScene.instantiate()
	add_child(ui_layer)

	arrow_container = Node3D.new()
	arrow_container.name = "Arrows"
	add_child(arrow_container)

	enemy_mgr = EnemyManager.new()
	enemy_mgr.name = "EnemyManager"
	enemy_mgr.world_gen = world_gen
	add_child(enemy_mgr, true)
	enemy_mgr.enemy_killed.connect(_on_enemy_killed.bind(ui_layer))

	loading.update("Ready!", 1.0)
	await get_tree().create_timer(0.2).timeout

	var tween := create_tween()
	tween.tween_property(loading.get_node("ColorRect"), "modulate", Color(1, 1, 1, 0), 0.15)
	tween.parallel().tween_property(loading.get_node("VBoxContainer"), "modulate", Color(1, 1, 1, 0), 0.15)
	await tween.finished
	loading.queue_free()

	rpc("send_world_config", world_gen.seed_value, world_gen.world_size, world_gen.water_level, spawn_pos)

	MusicManager.play_song(MusicManager.Song.OVERWORLD)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _client_setup() -> void:
	var loading: CanvasLayer = LoadingScreenScene.instantiate()
	loading.name = "LoadingScreen"
	add_child(loading)
	loading.update("Receiving world...", 0.0)

	# enemy_mgr is created here but world_gen is set later in send_world_config
	# after the host sends the seed. Client enemy_mgr won't spawn enemies
	# (only the server spawns), but it needs world_gen for any potential lookups.
	enemy_mgr = EnemyManager.new()
	enemy_mgr.name = "EnemyManager"
	add_child(enemy_mgr)


func _find_spawn_position() -> Vector3:
	var spawn_pos := Vector3(0, 2.0, 0)
	for attempt in 20:
		var angle := randf() * TAU
		var dist := randf_range(0.0, 8.0)
		var sx := cos(angle) * dist
		var sz := sin(angle) * dist
		var h := world_gen.get_terrain_height(sx, sz)
		if h < world_gen.water_level - 0.5:
			continue
		var delta := world_gen.get_terrain_delta(sx, sz, 2.0)
		if delta > 0.3:
			continue
		spawn_pos = Vector3(sx, h + 1.5, sz)
		break
	return spawn_pos


func _player_spawn_function(data: Variant) -> Node:
	var dict := data as Dictionary
	var peer_id := dict["peer_id"] as int
	var spawn_pos := dict["spawn_pos"] as Vector3

	var player := PlayerScene.instantiate()
	player.name = "Player_%d" % peer_id
	# set_multiplayer_authority(id) cascades to all children by default (recursive=true) in Godot 4.5+.
	# No manual recursion needed — Camera3D, Ultimate, Bow, etc. inherit the authority automatically.
	player.set_multiplayer_authority(peer_id)
	# Position is NOT set here because MultiplayerSpawner.spawn_function runs BEFORE the node is added to the
	# scene tree. Setting position triggers get_global_transform() internally, which errors when not in tree.
	# Instead, the player's _ready() applies _spawn_position after it enters the tree.
	player._spawn_position = spawn_pos
	player.add_to_group("player")

	var self_id := multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 1
	var is_local := peer_id == self_id
	if is_local:
		player.add_to_group("local_player")
		var cam := player.get_node_or_null("Camera3D") as Camera3D
		if cam:
			cam.current = true
		var bow := player.get_node_or_null("Camera3D/Bow")
		if bow:
			if NetworkManager.is_host:
				bow.arrow_fired.connect(_on_host_arrow_fired)
			else:
				bow.arrow_fired.connect(_on_client_arrow_fired)

	return player


# @rpc("mode", "sync", "transfer_mode") uses string identifiers — this is the correct Godot 4.6 GDScript
# syntax per the official docs. The string values are compile-time annotation parameters, not runtime
# enums. Using unquoted identifiers or enum-class paths (e.g. MultiplayerPeer.RPCMode.ANY_PEER) causes
# parse errors in 4.6 GDScript. Order of the first three strings is flexible; channel (int) must be last.
@rpc("authority", "call_local", "reliable")
func send_world_config(seed_val: int, w_size: float, w_level: float, spawn_pos: Vector3) -> void:
	if NetworkManager.is_host:
		return

	_client_spawn_pos = spawn_pos
	world_gen = WorldGen.new(seed_val)
	world_gen.world_size = w_size
	world_gen.water_level = w_level
	add_child(world_gen)

	# Now that world_gen exists, give it to enemy_mgr so it won't crash on any lookups.
	if enemy_mgr:
		enemy_mgr.world_gen = world_gen

	await get_tree().process_frame

	var loading := get_node_or_null("LoadingScreen")
	if not loading:
		for child in get_children():
			if child is CanvasLayer:
				loading = child
				break

	if loading and loading.has_method("update"):
		loading.update("Building terrain...", 0.2)

	environment_node = EnvironmentNode.new()
	environment_node.world_gen = world_gen
	add_child(environment_node)
	await get_tree().process_frame

	var overlay := BiomeOverlayScene.new()
	overlay.world_gen = world_gen
	overlay.name = "BiomeOverlay"
	add_child(overlay)

	if loading and loading.has_method("update"):
		loading.update("Spawning player...", 0.6)

	ui_layer = UIScene.instantiate()
	add_child(ui_layer)

	arrow_container = Node3D.new()
	arrow_container.name = "Arrows"
	add_child(arrow_container)

	if loading and loading.has_method("update"):
		loading.update("Ready!", 1.0)
	await get_tree().create_timer(0.2).timeout

	if is_instance_valid(loading):
		var tween := create_tween()
		if loading.get_node_or_null("ColorRect"):
			tween.tween_property(loading.get_node("ColorRect"), "modulate", Color(1, 1, 1, 0), 0.15)
		if loading.get_node_or_null("VBoxContainer"):
			tween.parallel().tween_property(loading.get_node("VBoxContainer"), "modulate", Color(1, 1, 1, 0), 0.15)
		await tween.finished
		loading.queue_free()

	MusicManager.play_song(MusicManager.Song.OVERWORLD)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_host_player_connected(id: int) -> void:
	if not NetworkManager.is_host:
		return
	var spawn_pos := _find_spawn_position()
	_player_spawner.spawn({"peer_id": id, "spawn_pos": spawn_pos})
	rpc_id(id, "send_world_config", world_gen.seed_value, world_gen.world_size, world_gen.water_level, spawn_pos)

	for enemy in enemy_mgr.enemies:
		if not is_instance_valid(enemy):
			continue
		var idx := int(enemy.name.trim_prefix("Enemy_"))
		enemy_mgr.rpc_id(id, "_spawn_enemy_replica", idx, enemy.global_position, enemy.zombie_type.resource_path, enemy.skeleton.body_scale)


func _on_host_arrow_fired(origin: Vector3, direction: Vector3, speed: float) -> void:
	# Host spawns the authoritative arrow locally, then tells clients to show visuals
	ArrowScript.spawn_authoritative(arrow_container, origin, direction, speed)
	rpc("_spawn_arrow_visual", origin, direction, speed)


func _on_client_arrow_fired(origin: Vector3, direction: Vector3, speed: float) -> void:
	# Client sends request to server; server validates and spawns authoritative arrow
	rpc_id(NetworkManager.SERVER_ID, "_request_arrow", origin, direction, speed)


@rpc("any_peer", "call_remote", "reliable")
func _request_arrow(origin: Vector3, direction: Vector3, speed: float) -> void:
	if not NetworkManager.is_host:
		return
	ArrowScript.spawn_authoritative(arrow_container, origin, direction, speed)
	rpc("_spawn_arrow_visual", origin, direction, speed)


# Tells clients to spawn a visual-only arrow (no collision damage).
# The authoritative arrow is spawned server-side and handles all damage logic.
@rpc("authority", "call_remote", "reliable")
func _spawn_arrow_visual(origin: Vector3, direction: Vector3, speed: float) -> void:
	ArrowScript.spawn_visual(arrow_container, origin, direction, speed)


func _on_enemy_killed(pts: int, ui: CanvasLayer) -> void:
	if not NetworkManager.is_host:
		return
	score += pts
	rpc("update_score", score)
	ui.set_score(score)


@rpc("authority", "call_local", "reliable")
func update_score(new_score: int) -> void:
	score = new_score
	if ui_layer:
		ui_layer.set_score(score)





func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		NetworkManager.leave_game()
		var menu := get_parent()
		if menu:
			menu.show()
		queue_free()
