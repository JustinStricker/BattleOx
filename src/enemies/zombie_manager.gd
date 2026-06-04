extends Node

signal zombie_killed(score_amount: int)

const ZombieScene = preload("res://src/zombie/zombie.tscn")
const ShamblerType = preload("res://src/zombie/resources/zombie_shambler.tres")
const RunnerType = preload("res://src/zombie/resources/zombie_runner.tres")
const BruteType = preload("res://src/zombie/resources/zombie_brute.tres")

@export var world_gen: WorldGen

@export var type_weight_shambler: float = 60.0
@export var type_weight_runner: float = 25.0
@export var type_weight_brute: float = 15.0

var max_zombies: int = 60
var spawn_cooldown: float = 2.0
var spawn_timer: float = 0.0
var min_spawn_dist: float = 16.0
var max_spawn_dist: float = 60.0

var zombies: Array[Zombie] = []

var _raycast_cache: Dictionary = {}
var _raycast_cache_times: Dictionary = {}


func _ready() -> void:
	if not world_gen:
		world_gen = get_parent().find_child("WorldGen") as WorldGen


func _process(delta: float) -> void:
	_cleanup_dead()
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = spawn_cooldown + randf_range(-1.0, 1.0)
		_try_spawn()


func _cleanup_dead() -> void:
	zombies = zombies.filter(func(z): return is_instance_valid(z)) as Array[Zombie]


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
	if zombies.size() >= max_zombies:
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

		var zombie: Zombie = ZombieScene.instantiate() as Zombie
		add_child(zombie)
		zombie.global_position = Vector3(sx, h + 15.0, sz)
		zombies.append(zombie)
		zombie.died.connect(_on_zombie_died.bind(zombie))
		return


func _on_zombie_died(pos: Vector3, zombie: Zombie) -> void:
	zombie_killed.emit(zombie.zombie_type.health)
	_cleanup_dead()
