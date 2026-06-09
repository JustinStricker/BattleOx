class_name WraithSkeleton
extends EnemySkeleton
## Procedural floating entity using Skeleton3D + BoneAttachment3D bones.
## Bones: Core, Head, EyeL, EyeR, Tendril{0,1,2,3}, TendrilSeg{0,1,2,3}

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

var _skel: Skeleton3D

# Bone indices (used in animation code)
var _bone_core: int = 0
var _bone_head: int = 1


func build(type: EnemyType, scale_val: float) -> void:
	body_scale = scale_val
	_zombie_type_ref = type
	scale = Vector3(scale_val * 0.5, scale_val, scale_val * 0.5)

	_body_mat = _create_body_mat(type)
	_core_mat = _create_core_mat(type)
	_eye_mat = _create_eye_mat()
	_original_emission = type.emissive_color
	_original_emission_energy = type.emissive_strength

	_setup_skeleton()
	_build_core()
	_build_tendrils()
	_build_eyes()


func _setup_skeleton() -> void:
	_skel = Skeleton3D.new()
	_skel.name = "Skeleton3D"
	add_child(_skel)

	# Bone 0: Core (floating center)
	_skel.add_bone("Core")
	_skel.set_bone_rest(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.35, 0)))

	# Bone 1: Head (at core center for wraith, eyes attach here)
	_skel.add_bone("Head")
	_skel.set_bone_parent(1, 0)
	_skel.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)))

	# Bones 2-3: Eyes (attached to head, not driven by animation code)
	_skel.add_bone("EyeL")
	_skel.set_bone_parent(2, 1)
	_skel.set_bone_rest(2, Transform3D(Basis.IDENTITY, Vector3(-0.06, 0.02, -0.13)))

	_skel.add_bone("EyeR")
	_skel.set_bone_parent(3, 1)
	_skel.set_bone_rest(3, Transform3D(Basis.IDENTITY, Vector3(0.06, 0.02, -0.13)))

	# Bones 4-11: Tendrils (4 tendrils, each with root + segment)
	var tendril_configs := [
		{"angle": 0.0},
		{"angle": TAU * 0.25},
		{"angle": TAU * 0.5},
		{"angle": TAU * 0.75},
	]
	var bone_idx := 4
	for config in tendril_configs:
		var tendril_angle: float = config["angle"]
		var offset := Vector3(cos(tendril_angle) * 0.08, -0.1, sin(tendril_angle) * 0.08)

		_skel.add_bone("Tendril%d" % (bone_idx - 4))
		_skel.set_bone_parent(bone_idx, 0)
		_skel.set_bone_rest(bone_idx, Transform3D(Basis.IDENTITY, Vector3(0, -0.1, 0) + offset))

		_skel.add_bone("TendrilSeg%d" % (bone_idx - 4))
		_skel.set_bone_parent(bone_idx + 1, bone_idx)
		_skel.set_bone_rest(bone_idx + 1, Transform3D(Basis.IDENTITY, Vector3(0, -0.08, 0)))

		bone_idx += 2

	# Initialize all bone poses to identity
	for i in _skel.get_bone_count():
		_skel.set_bone_pose_rotation(i, Quaternion.IDENTITY)
		_skel.set_bone_pose_position(i, _skel.get_bone_rest(i).origin)


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


# --- Mesh Building ---

func _build_core() -> void:
	var core_attachment := BoneAttachment3D.new()
	core_attachment.bone_name = "Core"
	core_attachment.name = "CoreAttachment"
	_skel.add_child(core_attachment)

	# Central glowing orb
	var core := MeshInstance3D.new()
	core.mesh = SphereMesh.new()
	(core.mesh as SphereMesh).radius = 0.15
	(core.mesh as SphereMesh).height = 0.3
	core.material_override = _core_mat
	core_attachment.add_child(core)

	# Outer shell (semi-transparent)
	var shell := MeshInstance3D.new()
	shell.mesh = SphereMesh.new()
	(shell.mesh as SphereMesh).radius = 0.2
	(shell.mesh as SphereMesh).height = 0.4
	shell.material_override = _body_mat
	core_attachment.add_child(shell)


func _build_tendrils() -> void:
	for i in 4:
		var _tendril_bone_idx := 4 + i * 2

		# Tendril root
		var tendril_attachment := BoneAttachment3D.new()
		tendril_attachment.bone_name = "Tendril%d" % i
		tendril_attachment.name = "Tendril%dAttachment" % i
		_skel.add_child(tendril_attachment)

		# 3-segment tendril mesh (built as child chain of BoneAttachment3D)
		var seg_len := 0.08
		var prev: Node3D = tendril_attachment
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

			var child_pivot := Node3D.new()
			child_pivot.position = Vector3(0, -seg_len, 0)
			seg.add_child(child_pivot)
			prev = child_pivot

		# Create bone attachment for the second tendril segment
		var seg_attachment := BoneAttachment3D.new()
		seg_attachment.bone_name = "TendrilSeg%d" % i
		seg_attachment.name = "TendrilSeg%dAttachment" % i
		_skel.add_child(seg_attachment)

		# One more segment on the second bone
		var final_seg := MeshInstance3D.new()
		var final_r := 0.003
		final_seg.mesh = CylinderMesh.new()
		(final_seg.mesh as CylinderMesh).top_radius = final_r
		(final_seg.mesh as CylinderMesh).bottom_radius = final_r * 0.7
		(final_seg.mesh as CylinderMesh).height = seg_len
		final_seg.position = Vector3(0, -seg_len * 0.5, 0)
		final_seg.material_override = _body_mat
		seg_attachment.add_child(final_seg)


func _build_eyes() -> void:
	for side in [-1, 1]:
		var bone_name := "EyeL" if side < 0 else "EyeR"
		var attachment := BoneAttachment3D.new()
		attachment.bone_name = bone_name
		attachment.name = bone_name + "Attachment"
		_skel.add_child(attachment)

		var eye := MeshInstance3D.new()
		eye.mesh = SphereMesh.new()
		(eye.mesh as SphereMesh).radius = 0.025
		(eye.mesh as SphereMesh).height = 0.05
		(eye.mesh as SphereMesh).material = _eye_mat
		attachment.add_child(eye)


# --- Animation (drives Skeleton3D bone poses) ---

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

	# Flinch overlay
	if _flinch_timer > 0.0:
		var flinch_t := _flinch_timer / 0.15
		_skel.set_bone_pose_position(_bone_core,
			_skel.get_bone_rest(_bone_core).origin
			+ Vector3(sin(_anim_time * 50.0) * 0.05 * flinch_t, 0, 0))

	# Tendril sway (always)
	_animate_tendrils(delta)

	pulse_core(delta)


func _animate_idle() -> void:
	# Gentle hover bob
	var bob := sin(_anim_time * 1.5) * 0.02
	_skel.set_bone_pose_position(_bone_core, Vector3(0, 0.35 + bob, 0))
	_skel.set_bone_pose_rotation(_bone_core, Quaternion.IDENTITY)

	# Head follows core
	_skel.set_bone_pose_position(_bone_head, Vector3(0, bob, 0))
	_skel.set_bone_pose_rotation(_bone_head, Quaternion.IDENTITY)


func _animate_float(speed: float) -> void:
	var cadence_mult := _zombie_type_ref.walk_cadence_mult if _zombie_type_ref else 1.0
	var freq := speed * 2.0 * cadence_mult
	var phase := _anim_time * freq

	# Faster bob when moving
	var bob := sin(phase * 2.0) * 0.03 * speed
	_skel.set_bone_pose_position(_bone_core, Vector3(0, 0.35 + bob, 0))

	# Slight tilt forward
	var tilt := Quaternion(Vector3.RIGHT, -0.1 * speed)
	_skel.set_bone_pose_rotation(_bone_core, tilt)

	# Head follows
	_skel.set_bone_pose_position(_bone_head, Vector3(0, bob, 0))


func _animate_attack() -> void:
	var windup_ratio := _zombie_type_ref.attack_windup_ratio if _zombie_type_ref else 0.3
	var recover_ratio := _zombie_type_ref.attack_recover_ratio if _zombie_type_ref else 0.2
	var strike_start := windup_ratio
	var strike_end := strike_start + (1.0 - windup_ratio - recover_ratio)
	var t := clampf(_attack_anim_timer / ATTACK_COOLDOWN, 0.0, 1.0)

	if t < strike_start:
		# Wind-up: pull back and expand
		var r: float = t / strike_start
		var z_pos: float = lerp(0.0, 0.1, r)
		_skel.set_bone_pose_position(_bone_core, Vector3(0, 0.35, z_pos))
		var expand: float = lerp(1.0, 1.3, r)
		_skel.set_bone_pose_scale(_bone_core, Vector3(expand, expand, expand))
	elif t < strike_end:
		# Strike: thrust forward and shrink
		var r: float = (t - strike_start) / (strike_end - strike_start)
		var z_pos: float = lerp(0.1, -0.15, r)
		_skel.set_bone_pose_position(_bone_core, Vector3(0, 0.35, z_pos))
		var shrink: float = lerp(1.3, 0.8, r)
		_skel.set_bone_pose_scale(_bone_core, Vector3(shrink, shrink, shrink))
	else:
		# Recover
		var r: float = (t - strike_end) / recover_ratio
		var z_pos: float = lerp(-0.15, 0.0, r)
		_skel.set_bone_pose_position(_bone_core, Vector3(0, 0.35, z_pos))
		var recover: float = lerp(0.8, 1.0, r)
		_skel.set_bone_pose_scale(_bone_core, Vector3(recover, recover, recover))


func _animate_surprise() -> void:
	var t: float = clampf(_surprise_anim_time / 0.2, 0.0, 1.0)
	# Expand suddenly
	var expand: float = lerp(1.0, 1.2, t)
	_skel.set_bone_pose_scale(_bone_core, Vector3(expand, expand, expand))
	var y_pos: float = lerp(0.35, 0.4, t)
	_skel.set_bone_pose_position(_bone_core, Vector3(0, y_pos, 0))


func _animate_tendrils(_delta: float) -> void:
	for i in 4:
		var bone_idx := 4 + i * 2
		var wave_offset := float(i) * PI * 0.5
		# Sine wave sway
		_skel.set_bone_pose_rotation(bone_idx,
			Quaternion(Vector3.RIGHT, sin(_anim_time * 2.0 + wave_offset) * 0.3)
			* Quaternion(Vector3.FORWARD, cos(_anim_time * 1.7 + wave_offset) * 0.25))


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

	# Ragdoll: activate physics on the PhysicalBoneSimulator
	var sim := _skel.get_node_or_null("PhysicalBoneSimulator") as PhysicalBoneSimulator3D
	if sim:
		sim.physical_bones_start_simulation()

	# Core shrinks and fades
	var dt := create_tween().set_parallel(true)
	var core_rest_pos := _skel.get_bone_rest(_bone_core).origin
	dt.tween_method(func(v: float):
		_skel.set_bone_pose_scale(_bone_core, Vector3(v, v, v))
	, 1.0, 0.0, collapse_time).set_ease(Tween.EASE_IN)
	dt.tween_method(func(v: float):
		_skel.set_bone_pose_position(_bone_core, Vector3(core_rest_pos.x, core_rest_pos.y + v, core_rest_pos.z))
	, 0.0, 0.3, collapse_time).set_ease(Tween.EASE_OUT)

	# Body material fades out
	if _body_mat:
		dt.tween_method(func(a: float): _body_mat.albedo_color.a = a, 0.6, 0.0, collapse_time)

	# Tendrils droop
	for i in 4:
		var bone_idx := 4 + i * 2
		dt.tween_method(func(v: float, bidx: int = bone_idx):
			_skel.set_bone_pose_rotation(bidx, Quaternion(Vector3.RIGHT, v))
		, 0.0, 1.0, collapse_time * 0.6)
		dt.tween_method(func(v: float, bidx: int = bone_idx):
			_skel.set_bone_pose_scale(bidx, Vector3(v, v, v))
		, 1.0, 0.3, collapse_time)

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