extends CharacterBody3D
class_name Enemy

signal died(pos: Vector3)

const FALL_KILL_HEIGHT: float = -10.0
const DESPAWN_DISTANCE: float = 120.0
const CHASE_RANGE: float = 18.0
const ATTACK_COOLDOWN: float = 1.2

@export var zombie_type: EnemyType

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var health: HealthComponent = $HealthComponent
@onready var perception: PerceptionComponent = $PerceptionComponent
@onready var movement: MovementComponent = $MovementComponent
@onready var ai: AIStateMachine = $AIStateMachine

var skeleton: EnemySkeleton
var _dead: bool = false
var _prev_ai_state: int = -1
var _replica_moving: bool = false
var _replica_attacking: bool = false

# IK modifiers (set up during _pick_type_and_build)
var _foot_modifier: FootPlacementModifier3D
var _hand_modifier: HandTargetModifier3D


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 2
	up_direction = Vector3.UP
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(45.0)
	floor_snap_length = 0.1
	_create_skeleton()
	_pick_type_and_build()
	ai.reset_timers()
	_apply_type_to_ai()
	_resize_collision()
	health.died.connect(_on_death)
	health.damaged.connect(_on_damaged)
	ai.attack_hit.connect(_on_ai_attack)
	ai.despawned.connect(_cleanup)


var _replica: bool = false


func _create_skeleton() -> void:
	var skeleton_script: Script
	match zombie_type.skeleton_type:
		EnemyType.SkeletonType.DIRE_WOLF:
			skeleton_script = preload("res://src/enemy/skeletons/dire_wolf_skeleton.gd")
		EnemyType.SkeletonType.WRAITH:
			skeleton_script = preload("res://src/enemy/skeletons/wraith_skeleton.gd")
		EnemyType.SkeletonType.STONE_GOLEM:
			skeleton_script = preload("res://src/enemy/skeletons/stone_golem_skeleton.gd")
		_:
			skeleton_script = preload("res://src/enemy/skeletons/dire_wolf_skeleton.gd")

	var node := Node3D.new()
	node.set_script(skeleton_script)
	skeleton = node as EnemySkeleton
	skeleton.name = "Skeleton"
	add_child(skeleton)


func _pick_type_and_build() -> void:
	if zombie_type == null:
		zombie_type = preload("res://src/enemy/resources/dire_wolf.tres")

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

	# Apply float height for flying enemies (Wraith)
	if zombie_type.float_height > 0.0:
		_apply_float_height(zombie_type.float_height)
	else:
		# Apply gravity for ground enemies
		movement.gravity = 9.8

	# Set up IK modifiers based on skeleton type
	_setup_ik_modifiers()


func _apply_float_height(height: float) -> void:
	# For floating enemies, disable gravity and set initial hover height
	movement.gravity = 0.0
	global_position.y = _get_ground_y() + height


func _get_ground_y() -> float:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.new()
	q.from = global_position + Vector3.UP * 50.0
	q.to = global_position + Vector3.DOWN * 50.0
	q.collision_mask = 1
	var hit: Dictionary = space.intersect_ray(q)
	if hit:
		return hit.position.y
	return global_position.y


func _apply_type_to_ai() -> void:
	ai.speed_multiplier = zombie_type.speed_multiplier
	ai.zombie_damage = zombie_type.damage
	ai.attack_range = zombie_type.attack_range
	ai.is_ranged = zombie_type.attack_type == EnemyType.AttackType.RANGED


func _resize_collision() -> void:
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = collision_shape.shape
		# Scale collision to match skeleton: feet at y=0, head top at ~0.93 * body_scale
		var s := skeleton.body_scale
		capsule.height = 0.93 * s
		capsule.radius = 0.2 * s
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

	# Drive IK modifiers (hand targeting during attacks)
	_update_ik_drivers(is_attacking)

	# Handle floating enemies
	if zombie_type.float_height > 0.0:
		_handle_float_movement(delta)
	else:
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


func _handle_float_movement(delta: float) -> void:
	# Floating enemies: move horizontally, maintain height above ground
	var target_y := _get_ground_y() + zombie_type.float_height
	var current_y := global_position.y
	# Smoothly interpolate to target height
	global_position.y = lerp(current_y, target_y, delta * 3.0)
	# Apply horizontal movement only
	velocity.y = 0.0
	velocity.x = velocity.x  # Keep horizontal velocity from movement component
	velocity.z = velocity.z
	move_and_slide()


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
		fx.set_enemy_type(zombie_type)
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


# --- IK Modifier Integration ---

func _setup_ik_modifiers() -> void:
	var skel := skeleton.get_node_or_null("Skeleton3D") as Skeleton3D
	if not skel:
		return

	match zombie_type.skeleton_type:
		EnemyType.SkeletonType.DIRE_WOLF:
			_setup_dire_wolf_ik(skel)
		EnemyType.SkeletonType.STONE_GOLEM:
			_setup_stone_golem_ik(skel)
		# Wraith has no feet — skip IK


func _setup_dire_wolf_ik(skel: Skeleton3D) -> void:
	# Foot placement for 4 legs
	var foot_mod := FootPlacementModifier3D.new()
	foot_mod.name = "FootPlacement"
	skel.add_child(foot_mod)

	# Bone indices: LowerLegFL=6, LowerLegFR=8, LowerLegBL=10, LowerLegBR=12
	# Parent indices: UpperLegFL=5, UpperLegFR=7, UpperLegBL=9, UpperLegBR=11
	foot_mod.initialize(skel,
		PackedInt32Array([6, 8, 10, 12]),
		PackedInt32Array([5, 7, 9, 11]))
	_foot_modifier = foot_mod


func _setup_stone_golem_ik(skel: Skeleton3D) -> void:
	# Foot placement for 2 feet
	var foot_mod := FootPlacementModifier3D.new()
	foot_mod.name = "FootPlacement"
	skel.add_child(foot_mod)

	# Bone indices: FootL=11, FootR=14 (Root=0 shifted everything +1)
	# Parent indices: ShinL=10, ShinR=13
	foot_mod.initialize(skel,
		PackedInt32Array([11, 14]),
		PackedInt32Array([10, 13]))
	_foot_modifier = foot_mod

	# Hand targeting for stone golem punches
	var hand_mod := HandTargetModifier3D.new()
	hand_mod.name = "HandTarget"
	skel.add_child(hand_mod)

	# Bone indices: FistL=5, FistR=8 (Root=0 shifted everything +1)
	hand_mod.initialize(skel, 5, 8)
	_hand_modifier = hand_mod


func _update_ik_drivers(is_attacking: bool) -> void:
	# Drive the hand target modifier during attacks (stone golem)
	if _hand_modifier:
		_hand_modifier.is_attacking = is_attacking
		if is_attacking and perception.target and is_instance_valid(perception.target):
			_hand_modifier.attack_target_pos = perception.target.global_position
			# Calculate attack phase from skeleton's attack timer
			if skeleton is StoneGolemSkeleton:
				_hand_modifier.attack_phase = skeleton._attack_anim_timer / StoneGolemSkeleton.ATTACK_COOLDOWN
			else:
				_hand_modifier.attack_phase = 0.0
		else:
			_hand_modifier.attack_phase = 0.0
