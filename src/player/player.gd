extends CharacterBody3D

signal jump_charge_changed(charge: float)
signal jump_launched(charge: float)
signal jump_landed()
signal roll_charges_changed(charges: int, recharging: bool, progress: float)

@onready var camera_node: Camera3D = $Camera3D
var health: int = 100
var max_health: int = 100
var invincible_timer: float = 0.0

const SPEED: float = 5.0
const DOUBLE_TAP_TIME: float = 0.3
const ROLL_SPEED: float = 60.0
const ROLL_DURATION: float = 0.25
const MAX_ROLL_CHARGES: int = 3
const ROLL_CHARGE_TIME: float = 3.0
var is_rolling: bool = false
var roll_timer: float = 0.0
var roll_charges: int = 3
var roll_charge_recharge_timer: float = 0.0

var w_last_press_time: float = 0.0
var s_last_press_time: float = 0.0
var a_last_press_time: float = 0.0
var d_last_press_time: float = 0.0

const JUMP_CHARGE_TIME: float = 0.35
const JUMP_VELOCITY_MIN: float = 4.5
const JUMP_VELOCITY_MAX: float = 20.0
const JUMP_CUT_MULTIPLIER: float = 0.5
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var is_charging_jump: bool = false
var jump_charge: float = 0.0
var _jump_held: bool = false
var _was_on_floor: bool = true

const DASH_SPEED: float = 60.0
const DASH_DURATION: float = 0.25
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown: float = 0.0

var slash_ability: Node3D
var _saved_mask: int
var _original_fov: float = 75.0

var _blink_trail: MeshInstance3D
var _blink_trail_mat: StandardMaterial3D
var _blink_flash: OmniLight3D
var _blink_particles: GPUParticles3D
var _blink_start_pos: Vector3

var _camera_bob_offset: float = 0.0

func _ready() -> void:
	add_to_group("player")
	collision_mask = 1 | 2
	_saved_mask = collision_mask
	roll_charges_changed.emit(roll_charges, false, 0.0)
	_setup_blink_effects()
	jump_launched.connect(_on_jump_launched)

	var sword = get_node_or_null("Camera3D/SwordSlash")
	if sword:
		slash_ability = sword
		sword.slash_started.connect(_on_slash_started)
		sword.slash_completed.connect(_on_slash_completed)

	var wings = get_node_or_null("Camera3D/Wings")
	if wings:
		jump_charge_changed.connect(wings.set_charge)
		jump_launched.connect(wings.launch)
		jump_landed.connect(wings.land)

func _setup_blink_effects() -> void:
	_blink_trail_mat = StandardMaterial3D.new()
	_blink_trail_mat.albedo_color = Color(0.4, 0.85, 1.0, 1.0)
	_blink_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_blink_trail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_blink_trail_mat.emission_enabled = true
	_blink_trail_mat.emission = Color(0.4, 0.85, 1.0)
	_blink_trail_mat.emission_energy_multiplier = 5.0
	_blink_trail_mat.no_depth_test = true

	var fade_grad := Gradient.new()
	fade_grad.set_color(0, Color(1, 1, 1, 0.0))
	fade_grad.add_point(0.25, Color(1, 1, 1, 0.5))
	fade_grad.add_point(0.5, Color(1, 1, 1, 1.0))
	fade_grad.add_point(0.75, Color(1, 1, 1, 0.5))
	fade_grad.set_color(fade_grad.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade_grad
	_blink_trail_mat.albedo_texture = fade_tex

	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.5, 0.05, 1.0)
	box_mesh.material = _blink_trail_mat
	_blink_trail = MeshInstance3D.new()
	_blink_trail.name = "BlinkTrail"
	_blink_trail.mesh = box_mesh
	_blink_trail.visible = false
	add_child(_blink_trail)

	_blink_flash = OmniLight3D.new()
	_blink_flash.light_color = Color(0.7, 0.85, 1.0)
	_blink_flash.light_energy = 15.0
	_blink_flash.omni_range = 5.0
	_blink_flash.visible = false
	add_child(_blink_flash)

	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 90.0
	pmat.initial_velocity_min = 2.0
	pmat.initial_velocity_max = 6.0
	pmat.gravity = Vector3(0, -2, 0)
	pmat.scale_min = 0.015
	pmat.scale_max = 0.04
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.6, 0.9, 1.0, 1.0))
	gradient.add_point(0.4, Color(0.3, 0.6, 1.0, 0.7))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.1, 0.2, 0.5, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	pmat.color_ramp = grad_tex

	var pmesh := SphereMesh.new()
	pmesh.radius = 0.015
	pmesh.height = 0.03
	var pm_mat := StandardMaterial3D.new()
	pm_mat.albedo_color = Color(0.6, 0.85, 1.0)
	pm_mat.emission_enabled = true
	pm_mat.emission = Color(0.3, 0.6, 1.0)
	pm_mat.emission_energy_multiplier = 4.0
	pmesh.material = pm_mat

	_blink_particles = GPUParticles3D.new()
	_blink_particles.amount = 20
	_blink_particles.lifetime = 0.4
	_blink_particles.one_shot = true
	_blink_particles.emitting = false
	_blink_particles.explosiveness = 1.0
	_blink_particles.process_material = pmat
	_blink_particles.draw_pass_1 = pmesh
	add_child(_blink_particles)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var mouse_event: InputEventMouseMotion = event as InputEventMouseMotion
		rotate_y(-mouse_event.relative.x * 0.002)
		camera_node.rotation.x -= mouse_event.relative.y * 0.002
		camera_node.rotation.x = clamp(camera_node.rotation.x, -1.4, 1.4)

	if event.is_action_pressed("move_forward"):
		var now: float = Time.get_ticks_msec() / 1000.0
		if _is_double_tap(now, w_last_press_time):
			_start_roll(-global_transform.basis.z)
		w_last_press_time = now

	if event.is_action_pressed("move_back"):
		var now: float = Time.get_ticks_msec() / 1000.0
		if _is_double_tap(now, s_last_press_time):
			_start_roll(global_transform.basis.z)
		s_last_press_time = now

	if event.is_action_pressed("move_left"):
		var now: float = Time.get_ticks_msec() / 1000.0
		if _is_double_tap(now, a_last_press_time):
			_start_roll(-global_transform.basis.x)
		a_last_press_time = now

	if event.is_action_pressed("move_right"):
		var now: float = Time.get_ticks_msec() / 1000.0
		if _is_double_tap(now, d_last_press_time):
			_start_roll(global_transform.basis.x)
		d_last_press_time = now

	if event.is_action_pressed("dash_slash"):
		_start_dash_slash()

	if event.is_action_pressed("ultimate"):
		var ultimate := get_node_or_null("Camera3D/Ultimate")
		if ultimate and ultimate.try_fire():
			pass

	if event.is_action_pressed("jump", false):
		_jump_held = true
	elif event.is_action_released("jump"):
		_jump_held = false

func take_damage(amount: int) -> void:
	if invincible_timer > 0.0:
		return
	health -= amount
	invincible_timer = 0.5
	AudioManager.play_player_hit()
	if health <= 0:
		die()

func die() -> void:
	health = 0
	AudioManager.play_player_death()
	await get_tree().create_timer(0.5).timeout
	get_tree().reload_current_scene()

func _on_slash_started() -> void:
	var bow = get_node_or_null("Camera3D/Bow")
	if bow:
		bow.cancel_charge()
		bow.visible = false

func _on_slash_completed() -> void:
	var bow = get_node_or_null("Camera3D/Bow")
	if bow:
		bow.visible = true

func _start_dash_slash() -> void:
	if dash_cooldown > 0.0 or is_dashing:
		return
	if slash_ability == null or not slash_ability.can_slash():
		return

	slash_ability.start_slash()

	collision_mask = 1

	var forward: Vector3 = -camera_node.global_transform.basis.z
	if forward.length() < 0.001:
		forward = -global_transform.basis.z
	forward = forward.normalized()

	velocity = forward * DASH_SPEED

	is_dashing = true
	dash_timer = DASH_DURATION
	dash_cooldown = 1.5

func _is_double_tap(now: float, last_press: float) -> bool:
	return now - last_press <= DOUBLE_TAP_TIME and now - last_press > 0.0 and not is_rolling and not is_dashing and roll_charges > 0

func _start_roll(direction: Vector3) -> void:
	if roll_charges <= 0 or is_rolling or is_dashing:
		return

	collision_mask = 1

	velocity = direction * ROLL_SPEED

	is_rolling = true
	roll_timer = ROLL_DURATION
	roll_charges -= 1
	if roll_charges < MAX_ROLL_CHARGES and roll_charge_recharge_timer <= 0.0:
		roll_charge_recharge_timer = 0.0
	roll_charges_changed.emit(roll_charges, roll_charges < MAX_ROLL_CHARGES, roll_charge_recharge_timer / ROLL_CHARGE_TIME)

	AudioManager.play_roll()
	_blink_start_pos = global_position
	var center := _blink_start_pos + Vector3(0, 0.5, 0)
	_blink_trail.global_position = center
	var up_vec := Vector3.UP
	if abs(direction.normalized().dot(Vector3.UP)) > 0.99:
		up_vec = Vector3.RIGHT
	_blink_trail.look_at(center + direction.normalized(), up_vec)
	_blink_trail.scale = Vector3(1, 1, 0.01)
	_blink_trail.visible = true
	_blink_trail_mat.albedo_color.a = 1.0

	_blink_flash.global_position = center
	_blink_flash.visible = true
	_blink_flash.light_energy = 15.0

	_blink_particles.global_position = center
	_blink_particles.restart()
	_blink_particles.emitting = true

	var fov_tween: Tween = create_tween()
	fov_tween.tween_property(camera_node, "fov", _original_fov + 5.0, 0.05).set_ease(Tween.EASE_OUT)
	fov_tween.tween_property(camera_node, "fov", _original_fov, 0.2).set_ease(Tween.EASE_IN)

func _on_jump_launched(charge: float) -> void:
	AudioManager.play_jump(charge)
	# FOV punch
	var fov_tween := create_tween()
	fov_tween.tween_property(camera_node, "fov", _original_fov + 5.0 + charge * 5.0, 0.05).set_ease(Tween.EASE_OUT)
	fov_tween.tween_property(camera_node, "fov", _original_fov, 0.3).set_ease(Tween.EASE_IN)

	# Camera bob
	_camera_bob_offset = -0.08 - charge * 0.06
	var bob_tween := create_tween()
	bob_tween.set_trans(Tween.TRANS_SPRING)
	bob_tween.set_ease(Tween.EASE_OUT)
	bob_tween.tween_property(self, "_camera_bob_offset", 0.0, 0.4)

func _physics_process(delta: float) -> void:
	invincible_timer = max(invincible_timer - delta, 0.0)
	dash_cooldown = max(dash_cooldown - delta, 0.0)

	if roll_charges < MAX_ROLL_CHARGES:
		roll_charge_recharge_timer += delta
		if roll_charge_recharge_timer >= ROLL_CHARGE_TIME:
			roll_charges += 1
			roll_charge_recharge_timer = 0.0
			if roll_charges < MAX_ROLL_CHARGES:
				roll_charge_recharge_timer = 0.0
		roll_charges_changed.emit(roll_charges, roll_charges < MAX_ROLL_CHARGES, roll_charge_recharge_timer / ROLL_CHARGE_TIME)
	elif roll_charge_recharge_timer != 0.0:
		roll_charge_recharge_timer = 0.0
		roll_charges_changed.emit(roll_charges, false, 0.0)

	if is_rolling:
		roll_timer -= delta
		if roll_timer <= 0.0:
			is_rolling = false
			collision_mask = _saved_mask
			velocity *= 0.2
			_blink_trail.visible = false
			_blink_flash.visible = false
			_blink_flash.light_energy = 0.0
			_blink_particles.emitting = false
			move_and_slide()
			return
		var start_center := _blink_start_pos + Vector3(0, 0.5, 0)
		var current_center := global_position + Vector3(0, 0.5, 0)
		var dir: Vector3 = current_center - start_center
		var dist: float = dir.length()
		if dist > 0.01:
			var mid := start_center + dir * 0.5
			_blink_trail.global_position = mid
			var dir_norm := dir.normalized()
			var up_vec := Vector3.UP
			if abs(dir_norm.dot(Vector3.UP)) > 0.99:
				up_vec = Vector3.RIGHT
			_blink_trail.look_at(mid + dir_norm, up_vec)
			_blink_trail.scale.z = dist
		velocity.y -= gravity * delta
		move_and_slide()
		return

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
			collision_mask = _saved_mask
			velocity *= 0.2
			move_and_slide()
			return
		if slash_ability and slash_ability.has_method("check_hit"):
			slash_ability.check_hit()
		velocity.y -= gravity * delta
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if is_charging_jump:
		if is_on_floor():
			jump_charge = min(jump_charge + delta / JUMP_CHARGE_TIME, 1.0)
			jump_charge_changed.emit(jump_charge)

		if not _jump_held or jump_charge >= 1.0 or not is_on_floor():
			velocity.y = lerp(JUMP_VELOCITY_MIN, JUMP_VELOCITY_MAX, jump_charge)
			is_charging_jump = false
			jump_launched.emit(jump_charge)
			jump_charge = 0.0
	elif _jump_held and is_on_floor():
		is_charging_jump = true
		jump_charge = 0.0

	if not is_on_floor() and not _jump_held and velocity.y > 0:
		velocity.y *= JUMP_CUT_MULTIPLIER

	if is_on_floor() and not _was_on_floor:
		jump_landed.emit()
		AudioManager.play_land()

	_was_on_floor = is_on_floor()

	var input_dir: Vector3 = Vector3.ZERO
	if Input.is_action_pressed("move_forward"): input_dir.z -= 1
	if Input.is_action_pressed("move_back"): input_dir.z += 1
	if Input.is_action_pressed("move_left"): input_dir.x -= 1
	if Input.is_action_pressed("move_right"): input_dir.x += 1
	input_dir = input_dir.normalized()

	var direction: Vector3 = (transform.basis * input_dir).normalized()
	var current_speed: float = SPEED
	var velocity_vec: Vector3 = direction * current_speed
	velocity.x = velocity_vec.x
	velocity.z = velocity_vec.z
	move_and_slide()

	camera_node.position.y = 1.5 + _camera_bob_offset
