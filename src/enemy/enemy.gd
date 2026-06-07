extends CharacterBody3D
class_name Enemy

signal died(pos: Vector3)

const FALL_KILL_HEIGHT: float = -10.0
const DESPAWN_DISTANCE: float = 120.0
const CHASE_RANGE: float = 18.0
const ATTACK_RANGE: float = 1.8
const ATTACK_COOLDOWN: float = 1.2

@export var zombie_type: ZombieType

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var skeleton: ZombieSkeleton = $ZombieSkeleton
@onready var health: HealthComponent = $HealthComponent
@onready var perception: PerceptionComponent = $PerceptionComponent
@onready var movement: MovementComponent = $MovementComponent
@onready var ai: AIStateMachine = $AIStateMachine

var _dead: bool = false
var _prev_ai_state: int = -1
var _replica_moving: bool = false
var _replica_attacking: bool = false


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 2
	up_direction = Vector3.UP
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(45.0)
	floor_snap_length = 0.1
	_pick_type_and_build()
	ai.reset_timers()
	_apply_type_to_ai()
	_resize_collision()
	health.died.connect(_on_death)
	health.damaged.connect(_on_damaged)
	ai.attack_hit.connect(_on_ai_attack)
	ai.despawned.connect(_cleanup)


var _replica: bool = false


func _pick_type_and_build() -> void:
	if zombie_type != null:
		var scale_val: float
		if _replica:
			scale_val = get_meta("replica_body_scale", zombie_type.body_scale_min)
		else:
			scale_val = randf_range(zombie_type.body_scale_min, zombie_type.body_scale_max)
		skeleton.body_scale = scale_val
		skeleton.build(zombie_type, scale_val)
		health.max_health = zombie_type.health
		health.current_health = zombie_type.health
		health.invulnerability_time = 0.0
		return
	var zm := get_parent()
	if zm and zm.has_method("roll_zombie_type"):
		zombie_type = zm.roll_zombie_type()
	if zombie_type == null:
		zombie_type = preload("res://src/enemy/resources/zombie_shambler.tres")

	var body_scale: float = randf_range(zombie_type.body_scale_min, zombie_type.body_scale_max)
	skeleton.build(zombie_type, body_scale)
	health.max_health = zombie_type.health
	health.current_health = zombie_type.health
	health.invulnerability_time = 0.0


func _apply_type_to_ai() -> void:
	ai.speed_multiplier = zombie_type.speed_multiplier
	ai.zombie_damage = zombie_type.damage
	# Scale attack range proportionally to body size
	var scale_factor := skeleton.body_scale / 5.0
	ai.attack_range = ATTACK_RANGE * scale_factor


func _resize_collision() -> void:
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = collision_shape.shape
		var scale_factor := skeleton.body_scale / 0.75
		capsule.height = 1.4 * scale_factor
		capsule.radius = 0.2 * scale_factor
		collision_shape.position.y = capsule.height * 0.5


func _physics_process(delta: float) -> void:
	if _dead:
		return

	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		skeleton.update_animation(delta, _replica_moving, _replica_attacking, false, 0.0)
		return

	if global_position.y < FALL_KILL_HEIGHT:
		health.take_damage(999999)
		return

	ai.process_ai(delta)

	var st := ai.state
	var is_moving := st == AIStateMachine.State.WANDER or st == AIStateMachine.State.CHASE
	var is_attacking := st == AIStateMachine.State.ATTACK

	if Engine.get_process_frames() % 3 == 0 and multiplayer.multiplayer_peer != null:
		rpc("_sync_enemy_anim", is_moving, is_attacking)

	st = ai.state
	is_moving = st == AIStateMachine.State.WANDER or st == AIStateMachine.State.CHASE
	is_attacking = st == AIStateMachine.State.ATTACK
	var speed := ai.chase_speed * ai.speed_multiplier if st == AIStateMachine.State.CHASE else ai.wander_speed * ai.speed_multiplier

	if is_attacking and _prev_ai_state != AIStateMachine.State.ATTACK:
		skeleton.set_attack_timer(ATTACK_COOLDOWN - ai.attack_timer)
	_prev_ai_state = st

	var target_dir := Vector3.FORWARD
	if perception.target and is_instance_valid(perception.target):
		target_dir = (perception.target.global_position - global_position).normalized()
	skeleton.update_animation(delta, is_moving, is_attacking, ai.is_surprised(), speed, target_dir)

	movement.apply_gravity_and_slide(delta)

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.new()
	q.from = global_position + Vector3.UP * 0.5
	q.to = global_position + Vector3.DOWN * 1.0
	q.collision_mask = 1
	var hit: Dictionary = space.intersect_ray(q)
	if hit and global_position.y < hit.position.y - 0.05:
		global_position.y = hit.position.y
		velocity.y = 0.0


@rpc("authority", "call_remote", "unreliable")
func _sync_enemy_anim(is_moving: bool = false, is_attacking: bool = false) -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		return
	_replica_moving = is_moving
	_replica_attacking = is_attacking


func _on_ai_attack(target: Node3D, damage: int) -> void:
	AudioManager.play_enemy_attack()
	if multiplayer.multiplayer_peer != null:
		rpc("_attack_fx")
	if is_instance_valid(target) and target.has_method("take_damage"):
		var dist := global_position.distance_to(target.global_position)
		if dist < ai.attack_range + 0.5:
			target.take_damage(damage)


func take_damage(amount: int, knockback := false) -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		rpc("_take_damage_rpc", amount, knockback)
		return
	health.take_damage(amount, knockback)


@rpc("any_peer", "call_local", "reliable")
func _take_damage_rpc(amount: int, knockback: bool) -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	health.take_damage(amount, knockback)


@rpc("authority", "call_remote", "unreliable")
func _hit_fx(pos: Vector3) -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		return
	var fx := preload("res://src/enemy/effects/hit_fx.tscn").instantiate()
	var parent: Node3D = get_parent() as Node3D
	if not parent:
		parent = get_tree().current_scene as Node3D
	parent.add_child(fx)
	fx.global_position = pos + Vector3.UP * 0.5
	AudioManager.play_enemy_hit()


@rpc("authority", "call_remote", "unreliable")
func _attack_fx() -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		return
	AudioManager.play_enemy_attack()


# Enemy health is synced via MultiplayerSynchronizer (HealthComponent:current_health).
# No manual health RPC needed.


func _on_damaged(_amount: int, _knockback: bool) -> void:
	AudioManager.play_enemy_hit()
	skeleton.play_hit_flinch()
	var fx := preload("res://src/enemy/effects/hit_fx.tscn").instantiate()
	var parent: Node3D = get_parent() as Node3D
	if not parent:
		parent = get_tree().current_scene as Node3D
	parent.add_child(fx)
	fx.global_position = global_position + Vector3.UP * 0.5
	# Health is synced automatically via MultiplayerSynchronizer (HealthComponent:current_health).
	# Only the hit visual effect needs a manual RPC since it's a one-shot event.
	if multiplayer.multiplayer_peer != null:
		rpc("_hit_fx", global_position)


func _on_death() -> void:
	if _dead:
		return
	_dead = true
	if collision_shape:
		collision_shape.disabled = true
	var pos := global_position

	AudioManager.play_enemy_death()
	var fx := preload("res://src/enemy/effects/death_explosion.tscn").instantiate()
	var parent: Node3D = get_parent() as Node3D
	if not parent:
		parent = get_tree().current_scene as Node3D
	if zombie_type:
		fx.set_zombie_type(zombie_type)
	parent.add_child(fx)
	fx.global_position = pos

	_shake_camera(0.06, 0.35)

	# Play death collapse animation, then clean up
	skeleton.play_death_animation()
	skeleton.death_animation_finished.connect(func():
		visible = false
		died.emit(pos)
		queue_free()
	, CONNECT_ONE_SHOT)


func _shake_camera(amount: float, duration: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return
	var orig_rot_x: float = camera.rotation.x
	var orig_rot_y: float = camera.rotation.y
	var tween: Tween = create_tween()
	tween.tween_method(func(progress: float):
		if not is_instance_valid(camera):
			tween.kill()
			return
		var decay: float = max(1.0 - progress, 0.0)
		camera.rotation.x = orig_rot_x + randf_range(-amount, amount) * decay
		camera.rotation.y = orig_rot_y + randf_range(-amount, amount) * decay
	, 0.0, 1.0, duration)
	tween.tween_callback(func():
		if is_instance_valid(camera):
			camera.rotation.x = orig_rot_x
			camera.rotation.y = orig_rot_y
	)


func _cleanup() -> void:
	if collision_shape:
		collision_shape.disabled = true
	died.emit(global_position)
	queue_free()
