extends Node

signal enemy_killed(score_amount: int)

const EnemyScene = preload("res://src/enemy/enemy.tscn")
const ShamblerType = preload("res://src/enemy/resources/zombie_shambler.tres")
const RunnerType = preload("res://src/enemy/resources/zombie_runner.tres")
const BruteType = preload("res://src/enemy/resources/zombie_brute.tres")

@export var world_gen: WorldGen

@export var type_weight_shambler: float = 60.0
@export var type_weight_runner: float = 25.0
@export var type_weight_brute: float = 15.0

var max_enemies: int = 60
var spawn_cooldown: float = 2.0
var spawn_timer: float = 0.0
var min_spawn_dist: float = 16.0
var max_spawn_dist: float = 60.0

var enemies: Array[Enemy] = []
var _enemy_spawn_index: int = 0

var _raycast_cache: Dictionary = {}
var _raycast_cache_times: Dictionary = {}


func _ready() -> void:
	if not world_gen:
		world_gen = get_parent().find_child("WorldGen") as WorldGen

	# Godot 4.6 approach: Server is the single authority for NPC AI. Clients receive periodic position
	# updates via "authority"-mode RPCs rather than running their own AI. This matches the idiomatic
	# server-authoritative model where the server owns all non-player entities.
	# Without this, client-side enemy replicas stand frozen at their spawn point forever.
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		var sync_timer := Timer.new()
		sync_timer.name = "EnemySyncTimer"
		# Sync every 0.5s — frequent enough for smooth movement, sparse enough to avoid flooding
		sync_timer.wait_time = 0.5
		sync_timer.timeout.connect(_on_enemy_sync_timer_timeout)
		add_child(sync_timer)
		sync_timer.start()


func _process(delta: float) -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return
	_cleanup_dead()
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = spawn_cooldown + randf_range(-1.0, 1.0)
		_try_spawn()


func _cleanup_dead() -> void:
	enemies = enemies.filter(func(e): return is_instance_valid(e)) as Array[Enemy]


func roll_zombie_type() -> ZombieType:
	var total := type_weight_shambler + type_weight_runner + type_weight_brute
	var roll := randf() * total
	if roll < type_weight_shambler:
		return ShamblerType
	elif roll < type_weight_shambler + type_weight_runner:
		return RunnerType
	return BruteType


func _ground_height_at(x: float, z: float) -> float:
	# Returns terrain height from physics raycast, or INF if no terrain
	# collision shape exists yet (chunk still loading async).
	var cell := Vector2i(floori(x / 10.0), floori(z / 10.0))
	var now := Time.get_ticks_msec()
	if _raycast_cache.has(cell) and now - _raycast_cache_times.get(cell, 0) < 5000:
		return _raycast_cache[cell]

	var space: PhysicsDirectSpaceState3D = get_viewport().get_world_3d().direct_space_state
	if not space:
		return INF
	var query := PhysicsRayQueryParameters3D.new()
	query.from = Vector3(x, 20.0, z)
	query.to = Vector3(x, -20.0, z)
	query.collision_mask = 1
	var result: Dictionary = space.intersect_ray(query)
	if result.is_empty():
		return INF
	_raycast_cache[cell] = result.position.y
	_raycast_cache_times[cell] = now
	return result.position.y


func _try_spawn() -> void:
	if enemies.size() >= max_enemies:
		return

	var player := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return

	for attempt in 15:
		var angle := randf_range(0.0, TAU)
		var dist := randf_range(min_spawn_dist, max_spawn_dist)
		var sx: float = player.global_position.x + cos(angle) * dist
		var sz: float = player.global_position.z + sin(angle) * dist

		if abs(sx) > 255.0 or abs(sz) > 255.0:
			continue

		var h_estimate := world_gen.get_terrain_height(sx, sz)
		if h_estimate < 0.1:
			continue

		var biome := world_gen.get_biome(sx, sz)
		if biome == WorldGen.Biome.OCEAN:
			continue
		if biome == WorldGen.Biome.MOUNTAIN:
			if randf() > 0.2:
				continue

		if world_gen.is_blocked(sx, sz):
			continue

		var delta_terrain := world_gen.get_terrain_delta(sx, sz, 2.0)
		if delta_terrain > 0.8:
			continue

		var h := _ground_height_at(sx, sz)
		if h == INF or h < 0.1:
			# Terrain collision shape not loaded yet — skip this frame,
			# the next spawn attempt will re-query.
			continue

		var enemy: Enemy = EnemyScene.instantiate() as Enemy
		enemy.name = "Enemy_%d" % _enemy_spawn_index
		add_child(enemy, true)
		var spawn_pos := Vector3(sx, h + 15.0, sz)
		enemy.global_position = spawn_pos
		enemies.append(enemy)
		enemy.died.connect(_on_enemy_died.bind(enemy))
		if multiplayer.multiplayer_peer != null:
			rpc("_spawn_enemy_replica", _enemy_spawn_index, spawn_pos, enemy.zombie_type.resource_path, enemy.skeleton.body_scale)
		_enemy_spawn_index += 1
		return


@rpc("authority", "call_remote", "reliable")
func _spawn_enemy_replica(index: int, spawn_pos: Vector3, type_path: String, body_scale: float) -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		return
	if get_node_or_null("Enemy_%d" % index):
		return
	var enemy := EnemyScene.instantiate() as Enemy
	enemy.name = "Enemy_%d" % index
	enemy.zombie_type = load(type_path)
	enemy._replica = true
	enemy.set_meta("replica_body_scale", body_scale)
	add_child(enemy, true)
	enemy.skeleton.body_scale = body_scale
	enemy.global_position = spawn_pos
	enemy.collision_shape.disabled = true
	enemies.append(enemy)


func _on_enemy_died(pos: Vector3, enemy: Enemy) -> void:
	var idx := int(enemy.name.trim_prefix("Enemy_"))
	if multiplayer.multiplayer_peer != null:
		rpc("_despawn_enemy_replica", idx)
	enemy_killed.emit(enemy.zombie_type.health)
	_cleanup_dead()


@rpc("authority", "call_remote", "reliable")
func _despawn_enemy_replica(index: int) -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		return
	var enemy := get_node_or_null("Enemy_%d" % index) as Enemy
	if enemy:
		var pos := enemy.global_position
		if enemy.zombie_type:
			var fx := preload("res://src/enemy/effects/death_explosion.tscn").instantiate()
			fx.set_zombie_type(enemy.zombie_type)
			add_child(fx)
			fx.global_position = pos
		AudioManager.play_enemy_death()
		_shake_replica_camera(0.06, 0.35)
		enemy.queue_free()
		_cleanup_dead()


# Server-side periodic broadcast of all enemy positions to clients.
# Called by EnemySyncTimer. Only the server runs this because replica positions must be authoritative.
func _on_enemy_sync_timer_timeout() -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy._dead:
			continue
		rpc("_sync_enemy_position", int(enemy.name.trim_prefix("Enemy_")), enemy.global_position)


# Applies server-authoritative enemy position on client replicas.
# Without this, enemy replicas are frozen at spawn — clients never see enemies move.
@rpc("authority", "call_remote", "unreliable")
func _sync_enemy_position(index: int, position: Vector3) -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		return
	var enemy := get_node_or_null("Enemy_%d" % index) as Enemy
	if enemy:
		enemy.global_position = position


func _shake_replica_camera(amount: float, duration: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return
	var orig_rot_x: float = camera.rotation.x
	var orig_rot_y: float = camera.rotation.y
	var tween: Tween = create_tween()
	var elapsed: float = 0.0
	tween.tween_method(func(_v: Variant):
		elapsed += get_process_delta_time()
		if not is_instance_valid(camera):
			tween.kill()
			return
		var decay: float = max(1.0 - elapsed / duration, 0.0)
		camera.rotation.x = orig_rot_x + randf_range(-amount, amount) * decay
		camera.rotation.y = orig_rot_y + randf_range(-amount, amount) * decay
	, 0.0, 1.0, duration)
	tween.tween_callback(func():
		if is_instance_valid(camera):
			camera.rotation.x = orig_rot_x
			camera.rotation.y = orig_rot_y
	)
