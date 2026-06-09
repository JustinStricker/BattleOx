class_name AIStateMachine
extends Node

enum State { IDLE, WANDER, CHASE, ATTACK }

signal attack_hit(target: Node3D, damage: int)
signal despawned

@export var wander_speed: float = 2.0
@export var chase_speed: float = 3.5
@export var attack_range: float = 1.8
@export var attack_cooldown: float = 1.2
@export var chase_range: float = 18.0
@export var wander_radius: float = 8.0
@export var despawn_distance: float = 120.0

var state: State = State.IDLE
var speed_multiplier: float = 1.0
var zombie_damage: int = 8
var target_pos: Vector3
var idle_timer: float = 0.0
var attack_timer: float = 0.0
var despawn_timer: float = 0.0
var surprise_timer: float = 0.0
var is_ranged: bool = false
var _projectile_container: Node3D

@onready var _perception: PerceptionComponent = owner.get_node("PerceptionComponent")
@onready var _movement: MovementComponent = owner.get_node("MovementComponent")


func _ready() -> void:
	target_pos = owner.global_position
	idle_timer = randf_range(1.0, 3.0)
	# Find or create projectile container
	_find_projectile_container()


func _find_projectile_container() -> void:
	# Look for existing container in parent scene
	var tree := owner.get_tree()
	if tree:
		_projectile_container = tree.current_scene.get_node_or_null("Arrows")
		if not _projectile_container:
			# Create a temporary container
			_projectile_container = Node3D.new()
			_projectile_container.name = "EnemyProjectiles"
			tree.current_scene.add_child(_projectile_container)


func reset_timers() -> void:
	idle_timer = randf_range(1.0, 3.0)
	attack_timer = 0.0
	despawn_timer = 0.0
	surprise_timer = 0.0


func process_ai(delta: float) -> void:
	attack_timer = max(attack_timer - delta, 0.0)
	despawn_timer += delta

	var dist := _perception.distance_to_target()
	if dist > despawn_distance and despawn_timer > 5.0:
		despawned.emit()
		return

	var can_see := _perception.has_line_of_sight()
	var target := _perception.target
	if not is_instance_valid(target):
		return

	match state:
		State.IDLE:
			idle_timer -= delta
			_movement.face_target(target.global_position, delta * 2.0)
			if idle_timer <= 0.0:
				state = State.WANDER
				target_pos = owner.global_position + Vector3(randf_range(-wander_radius, wander_radius), 0, randf_range(-wander_radius, wander_radius))
				target_pos.y = _movement.ground_height(target_pos)
			if dist < chase_range and can_see:
				_enter_chase()

		State.WANDER:
			_movement.move_toward(target_pos, wander_speed * speed_multiplier, delta)
			if owner.global_position.distance_to(target_pos) < 1.0:
				state = State.IDLE
				idle_timer = randf_range(2.0, 5.0)
			if dist < chase_range and can_see:
				_enter_chase()

		State.CHASE:
			if surprise_timer > 0.0:
				surprise_timer -= delta
				_movement.face_target(target.global_position, delta * 2.0)
			else:
				target_pos = target.global_position
				_movement.move_toward(target_pos, chase_speed * speed_multiplier, delta)
			if dist > chase_range * 1.3:
				_exit_chase()
			if dist < attack_range:
				state = State.ATTACK

		State.ATTACK:
			_movement.face_target(target.global_position, delta * 4.0)
			if attack_timer <= 0.0:
				attack_timer = attack_cooldown
				if is_ranged:
					_fire_ranged_attack(target)
				else:
					if dist < attack_range + 0.5:
						attack_hit.emit(target, zombie_damage)
			if dist > attack_range * 1.3:
				state = State.CHASE


func is_surprised() -> bool:
	return surprise_timer > 0.0


func _enter_chase() -> void:
	state = State.CHASE
	surprise_timer = 0.2


func _exit_chase() -> void:
	state = State.IDLE
	idle_timer = randf_range(1.0, 3.0)


func _fire_ranged_attack(target: Node3D) -> void:
	# Fire a projectile toward the target
	if not _projectile_container:
		return

	var origin: Vector3 = owner.global_position + Vector3.UP * 0.5
	var direction: Vector3 = (target.global_position - origin).normalized()
	var speed: float = 15.0

	# Create a simple projectile (energy bolt)
	var projectile := _create_projectile(origin, direction, speed)
	_projectile_container.add_child(projectile)
	projectile.global_position = origin


func _create_projectile(_origin: Vector3, direction: Vector3, speed: float) -> Node3D:
	# Create a simple energy bolt projectile
	var projectile := Node3D.new()
	projectile.name = "EnergyBolt"

	# Visual mesh (glowing sphere)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	mesh.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.1, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.1, 0.8)
	mat.emission_energy_multiplier = 3.0
	mesh.material_override = mat
	projectile.add_child(mesh)

	# Set up projectile movement
	projectile.set_meta("direction", direction)
	projectile.set_meta("speed", speed)
	projectile.set_meta("lifetime", 3.0)
	projectile.set_meta("damage", zombie_damage)

	# Add a simple collision check using process
	var script := GDScript.new()
	script.source_code = """
extends Node3D

var _time: float = 0.0

func _process(delta: float) -> void:
	_time += delta
	var dir: Vector3 = get_meta("direction")
	var spd: float = get_meta("speed")
	var lt: float = get_meta("lifetime")
	var dmg: int = get_meta("damage")

	global_position += dir * spd * delta

	if _time > lt:
		queue_free()
		return

	# Check for player collision
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.new()
	q.from = global_position - dir * spd * delta
	q.to = global_position + dir * spd * delta * 0.5
	q.exclude = [get_parent()]
	var hit: Dictionary = space.intersect_ray(q)
	if hit and hit.collider.has_method("take_damage"):
		hit.collider.take_damage(dmg)
		queue_free()
"""
	script.reload()
	projectile.set_script(script)

	return projectile