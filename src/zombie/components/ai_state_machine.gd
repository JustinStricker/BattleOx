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

@onready var _perception: PerceptionComponent = owner.get_node("PerceptionComponent")
@onready var _movement: MovementComponent = owner.get_node("MovementComponent")


func _ready() -> void:
	target_pos = owner.global_position
	idle_timer = randf_range(1.0, 3.0)


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
