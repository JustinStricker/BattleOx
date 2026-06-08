class_name StoneGolemSkeleton
extends EnemySkeleton
## Procedural massive blocky bipedal: rectangular torso, thick limbs, glowing cracks.

const ATTACK_COOLDOWN: float = 2.0

var _body_mat: StandardMaterial3D
var _crack_mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D
var _zombie_type_ref: EnemyType
var _anim_time: float = 0.0
var _attack_anim_timer: float = 0.0
var _flinch_timer: float = 0.0
var _flash_timer: float = 0.0
var _original_emission: Color = Color.BLACK
var _original_emission_energy: float = 0.0
var _is_dying: bool = false
var _surprise_anim_time: float = 0.0

var _torso: MeshInstance3D
var _head_pivot: Node3D
var _pivot_arm_l: Node3D
var _pivot_arm_r: Node3D
var _pivot_forearm_l: Node3D
var _pivot_forearm_r: Node3D
var _pivot_leg_l: Node3D
var _pivot_leg_r: Node3D
var _pivot_shin_l: Node3D
var _pivot_shin_r: Node3D
var _cracks: Array[MeshInstance3D] = []


func build(type: EnemyType, scale_val: float) -> void:
	body_scale = scale_val
	_zombie_type_ref = type
	scale = Vector3(scale_val * 0.5, scale_val, scale_val * 0.5)

	_body_mat = _create_body_mat(type)
	_crack_mat = _create_crack_mat(type)
	_eye_mat = _create_eye_mat()
	_original_emission = type.emissive_color
	_original_emission_energy = type.emissive_strength

	_build_torso()
	_build_head()
	_build_arms()
	_build_legs()
	_build_cracks()
	_build_eyes()


func _create_body_mat(type: EnemyType) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var hue := randf_range(type.color_hue_min, type.color_hue_max)
	mat.albedo_color = Color.from_hsv(hue, type.color_saturation, type.color_value)
	mat.roughness = type.roughness
	mat.metallic = type.metallic
	mat.emission_enabled = false
	return mat


func _create_crack_mat(type: EnemyType) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.05, 0.0)
	mat.roughness = 0.3
	mat.metallic = 0.0
	mat.emission_enabled = true
	mat.emission = type.emissive_color
	mat.emission_energy_multiplier = type.emissive_strength
	return mat


func _create_eye_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.3, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.0)
	mat.emission_energy_multiplier = 3.0
	return mat


func _build_torso() -> void:
	# Large rectangular torso (BoxMesh)
	var torso_mesh := BoxMesh.new()
	torso_mesh.size = Vector3(0.5, 0.55, 0.35)
	_torso = MeshInstance3D.new()
	_torso.mesh = torso_mesh
	_torso.name = "Torso"
	_torso.position = Vector3(0, 0.35, 0)
	_torso.material_override = _body_mat
	add_child(_torso)

	# Shoulder plates
	for side in [-1, 1]:
		var plate := MeshInstance3D.new()
		var plate_mesh := BoxMesh.new()
		plate_mesh.size = Vector3(0.15, 0.06, 0.2)
		plate.mesh = plate_mesh
		plate.position = Vector3(side * 0.32, 0.22, 0)
		plate.rotation.z = deg_to_rad(side * -8)
		plate.material_override = _body_mat
		_torso.add_child(plate)


func _build_head() -> void:
	_head_pivot = Node3D.new()
	_head_pivot.name = "HeadPivot"
	_head_pivot.position = Vector3(0, 0.35, 0)
	_torso.add_child(_head_pivot)

	# Blocky head set into shoulders
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.25, 0.2, 0.22)
	var head := MeshInstance3D.new()
	head.mesh = head_mesh
	head.name = "Head"
	head.position = Vector3(0, 0.05, 0)
	head.material_override = _body_mat
	_head_pivot.add_child(head)

	# Brow ridge
	var brow := MeshInstance3D.new()
	var brow_mesh := BoxMesh.new()
	brow_mesh.size = Vector3(0.28, 0.04, 0.06)
	brow.mesh = brow_mesh
	brow.position = Vector3(0, 0.1, -0.1)
	brow.material_override = _body_mat
	_head_pivot.add_child(brow)


func _build_arms() -> void:
	for side in [-1, 1]:
		var sign_str := "L" if side < 0 else "R"
		var arm_r := 0.06
		var upper_len := 0.3
		var lower_len := 0.25

		# Upper arm pivot
		var upper_pivot := Node3D.new()
		upper_pivot.name = "UpperArm" + sign_str
		upper_pivot.position = Vector3(side * 0.32, 0.18, 0)
		_torso.add_child(upper_pivot)

		# Upper arm mesh (boxy)
		var upper_mesh := MeshInstance3D.new()
		var upper_box := BoxMesh.new()
		upper_box.size = Vector3(arm_r * 2, upper_len, arm_r * 2)
		upper_mesh.mesh = upper_box
		upper_mesh.name = "UpperArmMesh" + sign_str
		upper_mesh.position = Vector3(0, -upper_len * 0.5, 0)
		upper_mesh.material_override = _body_mat
		upper_pivot.add_child(upper_mesh)

		# Forearm pivot
		var forearm_pivot := Node3D.new()
		forearm_pivot.name = "Forearm" + sign_str
		forearm_pivot.position = Vector3(0, -upper_len, 0)
		upper_pivot.add_child(forearm_pivot)

		# Forearm mesh
		var forearm_mesh := MeshInstance3D.new()
		var forearm_box := BoxMesh.new()
		forearm_box.size = Vector3(arm_r * 1.7, lower_len, arm_r * 1.7)
		forearm_mesh.mesh = forearm_box
		forearm_mesh.name = "ForearmMesh" + sign_str
		forearm_mesh.position = Vector3(0, -lower_len * 0.5, 0)
		forearm_mesh.material_override = _body_mat
		forearm_pivot.add_child(forearm_mesh)

		# Fist
		var fist := MeshInstance3D.new()
		fist.mesh = BoxMesh.new()
		(fist.mesh as BoxMesh).size = Vector3(arm_r * 2.2, arm_r * 2, arm_r * 2.2)
		fist.position = Vector3(0, -lower_len - arm_r, 0)
		fist.material_override = _body_mat
		forearm_pivot.add_child(fist)

		if side < 0:
			_pivot_arm_l = upper_pivot
			_pivot_forearm_l = forearm_pivot
		else:
			_pivot_arm_r = upper_pivot
			_pivot_forearm_r = forearm_pivot


func _build_legs() -> void:
	for side in [-1, 1]:
		var sign_str := "L" if side < 0 else "R"
		var leg_r := 0.07
		var thigh_len := 0.25
		var shin_len := 0.22

		# Thigh pivot
		var thigh_pivot := Node3D.new()
		thigh_pivot.name = "Thigh" + sign_str
		thigh_pivot.position = Vector3(side * 0.13, -0.25, 0)
		_torso.add_child(thigh_pivot)

		# Thigh mesh
		var thigh_mesh := MeshInstance3D.new()
		var thigh_box := BoxMesh.new()
		thigh_box.size = Vector3(leg_r * 2, thigh_len, leg_r * 2)
		thigh_mesh.mesh = thigh_box
		thigh_mesh.name = "ThighMesh" + sign_str
		thigh_mesh.position = Vector3(0, -thigh_len * 0.5, 0)
		thigh_mesh.material_override = _body_mat
		thigh_pivot.add_child(thigh_mesh)

		# Shin pivot
		var shin_pivot := Node3D.new()
		shin_pivot.name = "Shin" + sign_str
		shin_pivot.position = Vector3(0, -thigh_len, 0)
		thigh_pivot.add_child(shin_pivot)

		# Shin mesh
		var shin_mesh := MeshInstance3D.new()
		var shin_box := BoxMesh.new()
		shin_box.size = Vector3(leg_r * 1.7, shin_len, leg_r * 1.7)
		shin_mesh.mesh = shin_box
		shin_mesh.name = "ShinMesh" + sign_str
		shin_mesh.position = Vector3(0, -shin_len * 0.5, 0)
		shin_mesh.material_override = _body_mat
		shin_pivot.add_child(shin_mesh)

		# Foot
		var foot := MeshInstance3D.new()
		foot.mesh = BoxMesh.new()
		(foot.mesh as BoxMesh).size = Vector3(leg_r * 2, leg_r * 0.8, leg_r * 3)
		foot.position = Vector3(0, -shin_len - leg_r * 0.4, leg_r * 0.5)
		foot.material_override = _body_mat
		shin_pivot.add_child(foot)

		if side < 0:
			_pivot_leg_l = thigh_pivot
			_pivot_shin_l = shin_pivot
		else:
			_pivot_leg_r = thigh_pivot
			_pivot_shin_r = shin_pivot


func _build_cracks() -> void:
	# Glowing orange cracks on the torso
	var crack_positions := [
		Vector3(0.1, 0.1, -0.18),
		Vector3(-0.08, -0.05, -0.18),
		Vector3(0.15, -0.12, -0.18),
		Vector3(-0.05, 0.15, 0.18),
		Vector3(0.12, -0.08, 0.18),
	]
	var crack_sizes := [
		Vector3(0.02, 0.12, 0.01),
		Vector3(0.015, 0.08, 0.01),
		Vector3(0.01, 0.15, 0.01),
		Vector3(0.02, 0.1, 0.01),
		Vector3(0.015, 0.07, 0.01),
	]

	for i in crack_positions.size():
		var crack := MeshInstance3D.new()
		var crack_box := BoxMesh.new()
		crack_box.size = crack_sizes[i]
		crack.mesh = crack_box
		crack.position = crack_positions[i]
		crack.rotation.z = deg_to_rad(randf_range(-20, 20))
		crack.material_override = _crack_mat
		_torso.add_child(crack)
		_cracks.append(crack)

	# Cracks on arms too
	for arm_pivot in [_pivot_arm_l, _pivot_arm_r]:
		if not arm_pivot:
			continue
		var crack := MeshInstance3D.new()
		var crack_box := BoxMesh.new()
		crack_box.size = Vector3(0.015, 0.1, 0.01)
		crack.mesh = crack_box
		crack.position = Vector3(0, -0.1, -0.04)
		crack.material_override = _crack_mat
		arm_pivot.add_child(crack)
		_cracks.append(crack)


func _build_eyes() -> void:
	# Glowing eyes in the head
	for side in [-1, 1]:
		var eye := MeshInstance3D.new()
		eye.mesh = BoxMesh.new()
		(eye.mesh as BoxMesh).size = Vector3(0.04, 0.025, 0.01)
		(eye.mesh as BoxMesh).material = _eye_mat
		eye.position = Vector3(side * 0.06, 0.06, -0.12)
		_head_pivot.add_child(eye)


# --- Animation ---

func update_animation(delta: float, is_moving: bool, is_attacking: bool,
		is_surprised: bool, speed: float, _target_dir: Vector3 = Vector3.FORWARD) -> void:
	_anim_time += delta

	if _flinch_timer > 0.0:
		_flinch_timer = max(_flinch_timer - delta, 0.0)

	if _flash_timer > 0.0:
		_flash_timer = max(_flash_timer - delta, 0.0)
		if _flash_timer <= 0.0 and _crack_mat:
			_crack_mat.emission = Color(1.0, 0.3, 0.0)
			_crack_mat.emission_energy_multiplier = _original_emission_energy

	if _is_dying:
		return

	if is_surprised:
		_surprise_anim_time += delta
		_animate_surprise()
	elif is_attacking:
		_attack_anim_timer += delta
		_animate_attack()
	elif is_moving:
		_surprise_anim_time = 0.0
		_animate_walk(speed)
	else:
		_surprise_anim_time = 0.0
		_animate_idle()

	# Flinch — barely moves (low flinch_strength handled in Enemy.gd, but we add visual)
	if _flinch_timer > 0.0:
		var flinch_t := _flinch_timer / 0.15
		_torso.rotation.x += 0.08 * flinch_t

	pulse_cracks(delta)


func _animate_idle() -> void:
	var breath := sin(_anim_time * 1.5) * 0.003
	_torso.position.y = 0.35 + breath

	# Arms hang heavy
	if _pivot_arm_l:
		_pivot_arm_l.rotation.x = 0.15 + sin(_anim_time * 1.0) * 0.01
		_pivot_arm_r.rotation.x = 0.15 - sin(_anim_time * 1.2) * 0.01
		_pivot_forearm_l.rotation.x = 0.1
		_pivot_forearm_r.rotation.x = 0.1

	# Head slight movement
	if _head_pivot:
		_head_pivot.rotation.y = sin(_anim_time * 0.8) * 0.02


func _animate_walk(speed: float) -> void:
	var cadence_mult: float = _zombie_type_ref.walk_cadence_mult if _zombie_type_ref else 0.7
	var freq: float = clamp(speed * 2.0 * cadence_mult, 1.5, 6.0)
	var phase: float = _anim_time * freq

	# Heavy bob
	var bob: float = abs(sin(phase * 0.5)) * 0.008 * speed
	_torso.position.y = 0.35 + bob
	_torso.rotation.x = sin(phase * 0.5) * 0.015 * speed
	_torso.rotation.z = sin(phase * 0.5) * 0.01 * speed

	# Legs swing
	var leg_swing: float = clamp(speed * 0.25, 0.15, 0.4)
	if _pivot_leg_l:
		_pivot_leg_l.rotation.x = sin(phase) * leg_swing
		_pivot_leg_r.rotation.x = sin(phase + PI) * leg_swing

		if _pivot_shin_l:
			_pivot_shin_l.rotation.x = abs(sin(phase)) * 0.15
			_pivot_shin_r.rotation.x = abs(sin(phase + PI)) * 0.15

	# Arms swing heavily
	if _pivot_arm_l:
		_pivot_arm_l.rotation.x = sin(phase + PI) * leg_swing * 0.6 + 0.15
		_pivot_arm_r.rotation.x = sin(phase) * leg_swing * 0.6 + 0.15
		_pivot_forearm_l.rotation.x = 0.1
		_pivot_forearm_r.rotation.x = 0.1

	# Head stays relatively stable
	if _head_pivot:
		_head_pivot.rotation.y = 0.0


func _animate_attack() -> void:
	var windup_ratio := _zombie_type_ref.attack_windup_ratio if _zombie_type_ref else 0.5
	var recover_ratio := _zombie_type_ref.attack_recover_ratio if _zombie_type_ref else 0.35
	var strike_start := windup_ratio
	var strike_end := strike_start + (1.0 - windup_ratio - recover_ratio)

	var t := clampf(_attack_anim_timer / ATTACK_COOLDOWN, 0.0, 1.0)

	if t < strike_start:
		# Wind-up: arms raise overhead
		var r := t / strike_start
		if _pivot_arm_l:
			_pivot_arm_l.rotation.x = lerp(0.15, -1.2, r)
			_pivot_arm_r.rotation.x = lerp(0.15, -1.2, r)
			_pivot_forearm_l.rotation.x = lerp(0.1, -0.5, r)
			_pivot_forearm_r.rotation.x = lerp(0.1, -0.5, r)
		_torso.rotation.x = lerp(0.0, -0.1, r)
		# Ground slam warning — cracks glow brighter
		if _crack_mat:
			_crack_mat.emission_energy_multiplier = lerp(
					_original_emission_energy, _original_emission_energy * 3.0, r)
	elif t < strike_end:
		# Strike: overhead slam down
		var r := (t - strike_start) / (strike_end - strike_start)
		if _pivot_arm_l:
			_pivot_arm_l.rotation.x = lerp(-1.2, 0.8, r)
			_pivot_arm_r.rotation.x = lerp(-1.2, 0.8, r)
			_pivot_forearm_l.rotation.x = lerp(-0.5, 0.3, r)
			_pivot_forearm_r.rotation.x = lerp(-0.5, 0.3, r)
		_torso.rotation.x = lerp(-0.1, 0.15, r)
		# Impact flash at the moment of strike
		if r > 0.3 and r < 0.5 and _crack_mat:
			_crack_mat.emission_energy_multiplier = _original_emission_energy * 5.0
	else:
		# Recover: slow return
		var r := (t - strike_end) / recover_ratio
		if _pivot_arm_l:
			_pivot_arm_l.rotation.x = lerp(0.8, 0.15, r)
			_pivot_arm_r.rotation.x = lerp(0.8, 0.15, r)
			_pivot_forearm_l.rotation.x = lerp(0.3, 0.1, r)
			_pivot_forearm_r.rotation.x = lerp(0.3, 0.1, r)
		_torso.rotation.x = lerp(0.15, 0.0, r)


func _animate_surprise() -> void:
	var t := clampf(_surprise_anim_time / 0.2, 0.0, 1.0)
	# Slight lean back
	_torso.rotation.x = lerp(0.0, -0.05, t)
	if _pivot_arm_l:
		_pivot_arm_l.rotation.x = lerp(0.15, 0.3, t)
		_pivot_arm_r.rotation.x = lerp(0.15, 0.3, t)


func play_hit_flinch() -> void:
	_flinch_timer = 0.15
	_flash_cracks()


func _flash_cracks() -> void:
	if _crack_mat:
		_crack_mat.emission = Color.WHITE
		_crack_mat.emission_energy_multiplier = 5.0
		_flash_timer = 0.12


func play_death_animation() -> void:
	_is_dying = true
	var collapse_time := 0.8

	# Golem crumbles: torso tilts, limbs go limp, cracks flare
	var dt := create_tween().set_parallel(true)
	dt.tween_property(_torso, "rotation:x", 0.6, collapse_time).set_ease(Tween.EASE_IN)
	dt.tween_property(_torso, "position:y", _torso.position.y - 0.2, collapse_time).set_ease(Tween.EASE_IN)

	# Arms drop
	if _pivot_arm_l:
		dt.tween_property(_pivot_arm_l, "rotation:x", 0.8, collapse_time * 0.7)
		dt.tween_property(_pivot_arm_r, "rotation:x", 0.8, collapse_time * 0.7)

	# Head drops
	if _head_pivot:
		dt.tween_property(_head_pivot, "rotation:x", 0.4, collapse_time * 0.5)

	# Cracks flare bright on death
	if _crack_mat:
		dt.tween_property(_crack_mat, "emission_energy_multiplier",
				_original_emission_energy * 4.0, collapse_time * 0.3)

	# After collapse, crack glow fades
	var done_tween := create_tween()
	done_tween.tween_interval(collapse_time * 0.5)
	if _crack_mat:
		done_tween.tween_property(_crack_mat, "emission_energy_multiplier", 0.0, collapse_time * 0.5)
	done_tween.tween_interval(0.1)
	done_tween.tween_callback(func(): death_animation_finished.emit())


func set_attack_timer(val: float) -> void:
	_attack_anim_timer = val


func pulse_cracks(_delta: float) -> void:
	if _crack_mat and _flash_timer <= 0.0:
		var pulse := _original_emission_energy \
				+ sin(_anim_time * 1.5) * _original_emission_energy * 0.3 \
				+ sin(_anim_time * 4.0) * _original_emission_energy * 0.1
		_crack_mat.emission_energy_multiplier = pulse