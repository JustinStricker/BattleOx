class_name WraithSkeleton
extends EnemySkeleton
## Procedural floating entity: glowing core orb with trailing tendrils. No legs.

const ATTACK_COOLDOWN: float = 0.8

var _body_mat: StandardMaterial3D
var _core_mat: StandardMaterial3D
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

var _core: MeshInstance3D
var _head_pivot: Node3D
var _tendrils: Array[Node3D] = []
var _tendril_meshes: Array[MeshInstance3D] = []


func build(type: EnemyType, scale_val: float) -> void:
	body_scale = scale_val
	_zombie_type_ref = type
	scale = Vector3(scale_val * 0.5, scale_val, scale_val * 0.5)

	_body_mat = _create_body_mat(type)
	_core_mat = _create_core_mat(type)
	_eye_mat = _create_eye_mat()
	_original_emission = type.emissive_color
	_original_emission_energy = type.emissive_strength

	_build_core()
	_build_tendrils()
	_build_eyes()


func _create_body_mat(type: EnemyType) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var hue := randf_range(type.color_hue_min, type.color_hue_max)
	mat.albedo_color = Color.from_hsv(hue, type.color_saturation, type.color_value)
	mat.albedo_color.a = 0.6
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = type.roughness
	mat.metallic = type.metallic
	mat.emission_enabled = type.emissive_strength > 0.1
	mat.emission = type.emissive_color
	mat.emission_energy_multiplier = type.emissive_strength
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _create_core_mat(type: EnemyType) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var hue := randf_range(type.color_hue_min, type.color_hue_max)
	mat.albedo_color = Color.from_hsv(hue, type.color_saturation, min(type.color_value + 0.3, 1.0))
	mat.roughness = 0.3
	mat.metallic = 0.2
	mat.emission_enabled = true
	mat.emission = type.emissive_color
	mat.emission_energy_multiplier = type.emissive_strength * 1.5
	return mat


func _create_eye_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.1, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.1, 1.0)
	mat.emission_energy_multiplier = 3.0
	return mat


func _build_core() -> void:
	# Central glowing orb
	_core = MeshInstance3D.new()
	_core.mesh = SphereMesh.new()
	(_core.mesh as SphereMesh).radius = 0.15
	(_core.mesh as SphereMesh).height = 0.3
	_core.name = "Core"
	_core.position = Vector3(0, 0.35, 0)
	_core.material_override = _core_mat
	add_child(_core)

	# Outer shell (semi-transparent)
	var shell := MeshInstance3D.new()
	shell.mesh = SphereMesh.new()
	(shell.mesh as SphereMesh).radius = 0.2
	(shell.mesh as SphereMesh).height = 0.4
	shell.position = Vector3(0, 0.35, 0)
	shell.material_override = _body_mat
	add_child(shell)

	_head_pivot = Node3D.new()
	_head_pivot.name = "HeadPivot"
	_head_pivot.position = Vector3(0, 0.35, 0)
	add_child(_head_pivot)


func _build_tendrils() -> void:
	# 4 trailing tendrils below the core
	for i in 4:
		var angle := float(i) / 4.0 * TAU
		var offset := Vector3(cos(angle) * 0.08, -0.1, sin(angle) * 0.08)

		var tendril_pivot := Node3D.new()
		tendril_pivot.name = "Tendril%d" % i
		tendril_pivot.position = Vector3(0, 0.25, 0) + offset
		add_child(tendril_pivot)
		_tendrils.append(tendril_pivot)

		# Build 3-segment tendril
		var prev := tendril_pivot
		var seg_len := 0.08
		for j in 3:
			var seg := MeshInstance3D.new()
			var r: float = lerp(0.02, 0.005, float(j) / 3.0)
			seg.mesh = CylinderMesh.new()
			(seg.mesh as CylinderMesh).top_radius = r
			(seg.mesh as CylinderMesh).bottom_radius = r * 0.7
			(seg.mesh as CylinderMesh).height = seg_len
			seg.position = Vector3(0, -seg_len * 0.5, 0)
			seg.material_override = _body_mat
			prev.add_child(seg)
			_tendril_meshes.append(seg)

			var child_pivot := Node3D.new()
			child_pivot.position = Vector3(0, -seg_len, 0)
			seg.add_child(child_pivot)
			prev = child_pivot


func _build_eyes() -> void:
	# 2 eyes on the front of the core
	for side in [-1, 1]:
		var eye := MeshInstance3D.new()
		eye.mesh = SphereMesh.new()
		(eye.mesh as SphereMesh).radius = 0.025
		(eye.mesh as SphereMesh).height = 0.05
		(eye.mesh as SphereMesh).material = _eye_mat
		eye.position = Vector3(side * 0.06, 0.37, -0.13)
		add_child(eye)


# --- Animation ---

func update_animation(delta: float, is_moving: bool, is_attacking: bool,
		is_surprised: bool, speed: float, _target_dir: Vector3 = Vector3.FORWARD) -> void:
	_anim_time += delta

	if _flinch_timer > 0.0:
		_flinch_timer = max(_flinch_timer - delta, 0.0)

	if _flash_timer > 0.0:
		_flash_timer = max(_flash_timer - delta, 0.0)
		if _flash_timer <= 0.0 and _body_mat:
			_body_mat.emission = _original_emission
			_body_mat.emission_energy_multiplier = _original_emission_energy

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
		_animate_float(speed)
	else:
		_surprise_anim_time = 0.0
		_animate_idle()

	# Flinch
	if _flinch_timer > 0.0:
		var flinch_t := _flinch_timer / 0.15
		_core.position.x += 0.05 * flinch_t * sin(_anim_time * 50.0)

	# Tendril sway (always active)
	_animate_tendrils(delta)

	pulse_core(delta)


func _animate_idle() -> void:
	# Gentle hover bob
	var bob := sin(_anim_time * 1.5) * 0.02
	_core.position.y = 0.35 + bob

	# Core pulse
	var pulse_scale := 1.0 + sin(_anim_time * 2.0) * 0.03
	_core.scale = Vector3(pulse_scale, pulse_scale, pulse_scale)

	if _head_pivot:
		_head_pivot.position.y = 0.35 + bob


func _animate_float(speed: float) -> void:
	var cadence_mult := _zombie_type_ref.walk_cadence_mult if _zombie_type_ref else 1.0
	var freq := speed * 2.0 * cadence_mult
	var phase := _anim_time * freq

	# Faster bob when moving
	var bob := sin(phase * 2.0) * 0.03 * speed
	_core.position.y = 0.35 + bob

	# Slight tilt forward
	_core.rotation.x = lerp(_core.rotation.x, -0.1 * speed, 0.1)

	if _head_pivot:
		_head_pivot.position.y = 0.35 + bob

	# Core glows brighter when moving
	if _core_mat:
		_core_mat.emission_energy_multiplier = (_zombie_type_ref.emissive_strength * 1.5 if _zombie_type_ref else 1.0) + speed * 0.3


func _animate_attack() -> void:
	var windup_ratio := _zombie_type_ref.attack_windup_ratio if _zombie_type_ref else 0.3
	var recover_ratio := _zombie_type_ref.attack_recover_ratio if _zombie_type_ref else 0.2
	var strike_start := windup_ratio
	var strike_end := strike_start + (1.0 - windup_ratio - recover_ratio)

	var t := clampf(_attack_anim_timer / ATTACK_COOLDOWN, 0.0, 1.0)

	if t < strike_start:
		# Wind-up: pull back and expand
		var r := t / strike_start
		_core.position.z = lerp(0.0, 0.1, r)
		var expand: float = lerp(1.0, 1.3, r)
		_core.scale = Vector3(expand, expand, expand)
	elif t < strike_end:
		# Strike: thrust forward and shrink
		var r := (t - strike_start) / (strike_end - strike_start)
		_core.position.z = lerp(0.1, -0.15, r)
		var shrink: float = lerp(1.3, 0.8, r)
		_core.scale = Vector3(shrink, shrink, shrink)
	else:
		# Recover
		var r := (t - strike_end) / recover_ratio
		_core.position.z = lerp(-0.15, 0.0, r)
		var recover: float = lerp(0.8, 1.0, r)
		_core.scale = Vector3(recover, recover, recover)


func _animate_surprise() -> void:
	var t := clampf(_surprise_anim_time / 0.2, 0.0, 1.0)
	# Expand suddenly
	var expand: float = lerp(1.0, 1.2, t)
	_core.scale = Vector3(expand, expand, expand)
	_core.position.y = lerp(0.35, 0.4, t)


func _animate_tendrils(delta: float) -> void:
	for i in _tendrils.size():
		var tendril := _tendrils[i]
		var wave_offset := float(i) * PI * 0.5
		# Sine wave sway
		tendril.rotation.x = sin(_anim_time * 2.0 + wave_offset) * 0.3
		tendril.rotation.z = cos(_anim_time * 1.7 + wave_offset) * 0.25


func play_hit_flinch() -> void:
	_flinch_timer = 0.15
	_flash_core()


func _flash_core() -> void:
	if _core_mat:
		_core_mat.emission = Color.WHITE
		_core_mat.emission_energy_multiplier = 5.0
		_flash_timer = 0.12
	if _body_mat:
		_body_mat.emission = Color.WHITE
		_body_mat.emission_energy_multiplier = 4.0


func play_death_animation() -> void:
	_is_dying = true
	var collapse_time := 0.5

	# Core shrinks and fades
	var dt := create_tween().set_parallel(true)
	dt.tween_property(_core, "scale", Vector3(0.0, 0.0, 0.0), collapse_time).set_ease(Tween.EASE_IN)
	dt.tween_property(_core, "position:y", _core.position.y + 0.3, collapse_time).set_ease(Tween.EASE_OUT)

	# Body material fades out
	if _body_mat:
		dt.tween_method(func(a: float): _body_mat.albedo_color.a = a, 0.6, 0.0, collapse_time)

	# Tendrils droop
	for tendril in _tendrils:
		dt.tween_property(tendril, "rotation:x", 1.0, collapse_time * 0.6)
		dt.tween_property(tendril, "scale", Vector3(0.3, 0.3, 0.3), collapse_time)

	var done_tween := create_tween()
	done_tween.tween_interval(collapse_time + 0.05)
	done_tween.tween_callback(func(): death_animation_finished.emit())


func set_attack_timer(val: float) -> void:
	_attack_anim_timer = val


func pulse_core(_delta: float) -> void:
	if _core_mat:
		var pulse := (_zombie_type_ref.emissive_strength * 1.5 if _zombie_type_ref else 1.0) \
				+ sin(_anim_time * 4.0) * 0.5 + sin(_anim_time * 11.0) * 0.3
		_core_mat.emission_energy_multiplier = pulse