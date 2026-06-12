class_name StoneGolemSkeleton
extends EnemySkeleton
## Procedural massive blocky bipedal using Skeleton3D + BoneAttachment3D bones.
## Bones: Torso, Head, Brow, UpperArm{L,R}, Forearm{L,R}, Fist{L,R}, Thigh{L,R}, Shin{L,R}, Foot{L,R}

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
var _cracks: Array[MeshInstance3D] = []

var _skel: Skeleton3D

# Bone indices (Root at 0, everything shifted +1)
var _bone_torso: int = 1
var _bone_head: int = 2
var _bone_upper_arm_l: int = 3
var _bone_forearm_l: int = 4
var _bone_upper_arm_r: int = 6
var _bone_forearm_r: int = 7
var _bone_thigh_l: int = 9
var _bone_shin_l: int = 10
var _bone_thigh_r: int = 12
var _bone_shin_r: int = 13


func build(type: EnemyType, scale_val: float) -> void:
	body_scale = scale_val
	_zombie_type_ref = type
	scale = Vector3(scale_val * 0.5, scale_val, scale_val * 0.5)

	_body_mat = _create_body_mat(type)
	_crack_mat = _create_crack_mat(type)
	_eye_mat = _create_eye_mat()
	_original_emission = type.emissive_color
	_original_emission_energy = type.emissive_strength

	_setup_skeleton()
	_build_torso()
	_build_head()
	_build_arms()
	_build_legs()
	_build_cracks()
	_build_eyes()


func _setup_skeleton() -> void:
	_skel = Skeleton3D.new()
	_skel.name = "Skeleton3D"
	add_child(_skel)

	# Bone 0: Root (offset y so feet land at ground level after skeleton scale is applied)
	# Foot global unscaled = Root(0.13) + Torso(0.35) + Thigh(-0.25) + Shin(-0.25) + Foot(-0.1) = 0.0
	_skel.add_bone("Root")
	_skel.set_bone_rest(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.13, 0)))

	# Bone 1: Torso (center of body mass)
	_skel.add_bone("Torso")
	_skel.set_bone_parent(1, 0)
	_skel.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0, 0.35, 0)))

	# Bone 2: Head (on top of torso)
	_skel.add_bone("Head")
	_skel.set_bone_parent(2, 1)
	_skel.set_bone_rest(2, Transform3D(Basis.IDENTITY, Vector3(0, 0.35, 0)))

	# Bones 3-5: Left arm chain (UpperArm -> Forearm -> Fist)
	_skel.add_bone("UpperArmL")
	_skel.set_bone_parent(3, 1)
	_skel.set_bone_rest(3, Transform3D(Basis.IDENTITY, Vector3(-0.32, 0.18, 0)))

	_skel.add_bone("ForearmL")
	_skel.set_bone_parent(4, 3)
	_skel.set_bone_rest(4, Transform3D(Basis.IDENTITY, Vector3(0, -0.3, 0)))

	_skel.add_bone("FistL")
	_skel.set_bone_parent(5, 4)
	_skel.set_bone_rest(5, Transform3D(Basis.IDENTITY, Vector3(0, -0.25, 0)))

	# Bones 6-8: Right arm chain
	_skel.add_bone("UpperArmR")
	_skel.set_bone_parent(6, 1)
	_skel.set_bone_rest(6, Transform3D(Basis.IDENTITY, Vector3(0.32, 0.18, 0)))

	_skel.add_bone("ForearmR")
	_skel.set_bone_parent(7, 6)
	_skel.set_bone_rest(7, Transform3D(Basis.IDENTITY, Vector3(0, -0.3, 0)))

	_skel.add_bone("FistR")
	_skel.set_bone_parent(8, 7)
	_skel.set_bone_rest(8, Transform3D(Basis.IDENTITY, Vector3(0, -0.25, 0)))

	# Bones 9-11: Left leg chain (Thigh -> Shin -> Foot)
	_skel.add_bone("ThighL")
	_skel.set_bone_parent(9, 1)
	_skel.set_bone_rest(9, Transform3D(Basis.IDENTITY, Vector3(-0.13, -0.25, 0)))

	_skel.add_bone("ShinL")
	_skel.set_bone_parent(10, 9)
	_skel.set_bone_rest(10, Transform3D(Basis.IDENTITY, Vector3(0, -0.25, 0)))

	_skel.add_bone("FootL")
	_skel.set_bone_parent(11, 10)
	_skel.set_bone_rest(11, Transform3D(Basis.IDENTITY, Vector3(0, -0.1, 0.035)))

	# Bones 12-14: Right leg chain
	_skel.add_bone("ThighR")
	_skel.set_bone_parent(12, 1)
	_skel.set_bone_rest(12, Transform3D(Basis.IDENTITY, Vector3(0.13, -0.25, 0)))

	_skel.add_bone("ShinR")
	_skel.set_bone_parent(13, 12)
	_skel.set_bone_rest(13, Transform3D(Basis.IDENTITY, Vector3(0, -0.25, 0)))

	_skel.add_bone("FootR")
	_skel.set_bone_parent(14, 13)
	_skel.set_bone_rest(14, Transform3D(Basis.IDENTITY, Vector3(0, -0.1, 0.035)))

	# Initialize all bone poses to identity
	for i in _skel.get_bone_count():
		_skel.set_bone_pose_rotation(i, Quaternion.IDENTITY)
		_skel.set_bone_pose_position(i, _skel.get_bone_rest(i).origin)


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


# --- Mesh Building ---

func _build_torso() -> void:
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = "Torso"
	attachment.name = "TorsoAttachment"
	_skel.add_child(attachment)

	# Large rectangular torso
	var torso_mesh := BoxMesh.new()
	torso_mesh.size = Vector3(0.5, 0.55, 0.35)
	var mi := MeshInstance3D.new()
	mi.mesh = torso_mesh
	mi.material_override = _body_mat
	attachment.add_child(mi)

	# Shoulder plates
	for side in [-1, 1]:
		var plate := MeshInstance3D.new()
		var plate_mesh := BoxMesh.new()
		plate_mesh.size = Vector3(0.15, 0.06, 0.2)
		plate.mesh = plate_mesh
		plate.position = Vector3(side * 0.32, 0.22, 0)
		plate.rotation.z = deg_to_rad(side * -8)
		plate.material_override = _body_mat
		attachment.add_child(plate)


func _build_head() -> void:
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = "Head"
	attachment.name = "HeadAttachment"
	_skel.add_child(attachment)

	# Blocky head set into shoulders
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.25, 0.2, 0.22)
	var head := MeshInstance3D.new()
	head.mesh = head_mesh
	head.position = Vector3(0, 0.05, 0)
	head.material_override = _body_mat
	attachment.add_child(head)

	# Brow ridge
	var brow := MeshInstance3D.new()
	var brow_mesh := BoxMesh.new()
	brow_mesh.size = Vector3(0.28, 0.04, 0.06)
	brow.mesh = brow_mesh
	brow.position = Vector3(0, 0.1, -0.1)
	brow.material_override = _body_mat
	attachment.add_child(brow)


func _build_arms() -> void:
	for side in [-1, 1]:
		var prefix := "L" if side < 0 else "R"
		var upper_bone_name := "UpperArm" + prefix
		var forearm_bone_name := "Forearm" + prefix
		var fist_bone_name := "Fist" + prefix
		var arm_r := 0.06

		# Upper arm
		var upper_attachment := BoneAttachment3D.new()
		upper_attachment.bone_name = upper_bone_name
		upper_attachment.name = upper_bone_name + "Attachment"
		_skel.add_child(upper_attachment)

		var upper_mesh := MeshInstance3D.new()
		var upper_box := BoxMesh.new()
		upper_box.size = Vector3(arm_r * 2, 0.3, arm_r * 2)
		upper_mesh.mesh = upper_box
		upper_mesh.position = Vector3(0, -0.15, 0)
		upper_mesh.material_override = _body_mat
		upper_attachment.add_child(upper_mesh)

		# Forearm
		var forearm_attachment := BoneAttachment3D.new()
		forearm_attachment.bone_name = forearm_bone_name
		forearm_attachment.name = forearm_bone_name + "Attachment"
		_skel.add_child(forearm_attachment)

		var forearm_mesh := MeshInstance3D.new()
		var forearm_box := BoxMesh.new()
		forearm_box.size = Vector3(arm_r * 1.7, 0.25, arm_r * 1.7)
		forearm_mesh.mesh = forearm_box
		forearm_mesh.position = Vector3(0, -0.125, 0)
		forearm_mesh.material_override = _body_mat
		forearm_attachment.add_child(forearm_mesh)

		# Fist
		var fist_attachment := BoneAttachment3D.new()
		fist_attachment.bone_name = fist_bone_name
		fist_attachment.name = fist_bone_name + "Attachment"
		_skel.add_child(fist_attachment)

		var fist := MeshInstance3D.new()
		fist.mesh = BoxMesh.new()
		(fist.mesh as BoxMesh).size = Vector3(arm_r * 2.2, arm_r * 2, arm_r * 2.2)
		fist.position = Vector3(0, -arm_r, 0)
		fist.material_override = _body_mat
		fist_attachment.add_child(fist)


func _build_legs() -> void:
	for side in [-1, 1]:
		var prefix := "L" if side < 0 else "R"
		var thigh_bone_name := "Thigh" + prefix
		var shin_bone_name := "Shin" + prefix
		var foot_bone_name := "Foot" + prefix
		var leg_r := 0.07

		# Thigh
		var thigh_attachment := BoneAttachment3D.new()
		thigh_attachment.bone_name = thigh_bone_name
		thigh_attachment.name = thigh_bone_name + "Attachment"
		_skel.add_child(thigh_attachment)

		var thigh_mesh := MeshInstance3D.new()
		var thigh_box := BoxMesh.new()
		thigh_box.size = Vector3(leg_r * 2, 0.25, leg_r * 2)
		thigh_mesh.mesh = thigh_box
		thigh_mesh.position = Vector3(0, -0.125, 0)
		thigh_mesh.material_override = _body_mat
		thigh_attachment.add_child(thigh_mesh)

		# Shin
		var shin_attachment := BoneAttachment3D.new()
		shin_attachment.bone_name = shin_bone_name
		shin_attachment.name = shin_bone_name + "Attachment"
		_skel.add_child(shin_attachment)

		var shin_mesh := MeshInstance3D.new()
		var shin_box := BoxMesh.new()
		shin_box.size = Vector3(leg_r * 1.7, 0.22, leg_r * 1.7)
		shin_mesh.mesh = shin_box
		shin_mesh.position = Vector3(0, -0.11, 0)
		shin_mesh.material_override = _body_mat
		shin_attachment.add_child(shin_mesh)

		# Foot
		var foot_attachment := BoneAttachment3D.new()
		foot_attachment.bone_name = foot_bone_name
		foot_attachment.name = foot_bone_name + "Attachment"
		_skel.add_child(foot_attachment)

		var foot := MeshInstance3D.new()
		foot.mesh = BoxMesh.new()
		(foot.mesh as BoxMesh).size = Vector3(leg_r * 2, leg_r * 0.8, leg_r * 3)
		foot.position = Vector3(0, -leg_r * 0.4, leg_r * 0.5)
		foot.material_override = _body_mat
		foot_attachment.add_child(foot)


func _build_cracks() -> void:
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

	var torso_attachment := _skel.get_node_or_null("TorsoAttachment")
	if torso_attachment:
		for i in crack_positions.size():
			var crack := MeshInstance3D.new()
			var crack_box := BoxMesh.new()
			crack_box.size = crack_sizes[i]
			crack.mesh = crack_box
			crack.position = crack_positions[i]
			crack.rotation.z = deg_to_rad(randf_range(-20, 20))
			crack.material_override = _crack_mat
			torso_attachment.add_child(crack)
			_cracks.append(crack)

	# Cracks on arms
	for arm_bone_name in ["UpperArmL", "UpperArmR"]:
		var attachment := _skel.get_node_or_null(arm_bone_name + "Attachment")
		if not attachment:
			continue
		var crack := MeshInstance3D.new()
		var crack_box := BoxMesh.new()
		crack_box.size = Vector3(0.015, 0.1, 0.01)
		crack.mesh = crack_box
		crack.position = Vector3(0, -0.1, -0.04)
		crack.material_override = _crack_mat
		attachment.add_child(crack)
		_cracks.append(crack)


func _build_eyes() -> void:
	var attachment := _skel.get_node_or_null("HeadAttachment")
	if not attachment:
		return
	for side in [-1, 1]:
		var eye := MeshInstance3D.new()
		eye.mesh = BoxMesh.new()
		(eye.mesh as BoxMesh).size = Vector3(0.04, 0.025, 0.01)
		(eye.mesh as BoxMesh).material = _eye_mat
		eye.position = Vector3(side * 0.06, 0.06, -0.12)
		attachment.add_child(eye)


# --- Animation (drives Skeleton3D bone poses) ---

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

	# Flinch overlay (barely moves — low flinch_strength)
	if _flinch_timer > 0.0:
		var flinch_t := _flinch_timer / 0.15
		var cur_rot := _skel.get_bone_pose_rotation(_bone_torso)
		var flinch_q := Quaternion(Vector3.RIGHT, 0.08 * flinch_t)
		_skel.set_bone_pose_rotation(_bone_torso, flinch_q * cur_rot)

	pulse_cracks(delta)


func _animate_idle() -> void:
	var breath := sin(_anim_time * 1.5) * 0.003
	_skel.set_bone_pose_position(_bone_torso, Vector3(0, 0.35 + breath, 0))
	_skel.set_bone_pose_rotation(_bone_torso, Quaternion.IDENTITY)

	# Arms hang heavy
	_skel.set_bone_pose_rotation(_bone_upper_arm_l,
		Quaternion(Vector3.RIGHT, 0.15 + sin(_anim_time * 1.0) * 0.01))
	_skel.set_bone_pose_rotation(_bone_upper_arm_r,
		Quaternion(Vector3.RIGHT, 0.15 - sin(_anim_time * 1.2) * 0.01))
	_skel.set_bone_pose_rotation(_bone_forearm_l,
		Quaternion(Vector3.RIGHT, 0.1))
	_skel.set_bone_pose_rotation(_bone_forearm_r,
		Quaternion(Vector3.RIGHT, 0.1))

	# Head slight movement
	_skel.set_bone_pose_rotation(_bone_head,
		Quaternion(Vector3.UP, sin(_anim_time * 0.8) * 0.02))


func _animate_walk(speed: float) -> void:
	var cadence_mult: float = _zombie_type_ref.walk_cadence_mult if _zombie_type_ref else 0.7
	var freq: float = clamp(speed * 2.0 * cadence_mult, 1.5, 6.0)
	var phase: float = _anim_time * freq
	var leg_swing: float = clamp(speed * 0.25, 0.15, 0.4)

	# Heavy bob
	var bob: float = abs(sin(phase * 0.5)) * 0.008 * speed
	_skel.set_bone_pose_position(_bone_torso, Vector3(0, 0.35 + bob, 0))
	_skel.set_bone_pose_rotation(_bone_torso,
		Quaternion(Vector3.RIGHT, sin(phase * 0.5) * 0.015 * speed)
		* Quaternion(Vector3.FORWARD, sin(phase * 0.5) * 0.01 * speed))

	# Legs swing
	_skel.set_bone_pose_rotation(_bone_thigh_l,
		Quaternion(Vector3.RIGHT, sin(phase) * leg_swing))
	_skel.set_bone_pose_rotation(_bone_thigh_r,
		Quaternion(Vector3.RIGHT, sin(phase + PI) * leg_swing))
	_skel.set_bone_pose_rotation(_bone_shin_l,
		Quaternion(Vector3.RIGHT, abs(sin(phase)) * 0.15))
	_skel.set_bone_pose_rotation(_bone_shin_r,
		Quaternion(Vector3.RIGHT, abs(sin(phase + PI)) * 0.15))

	# Arms swing heavily
	_skel.set_bone_pose_rotation(_bone_upper_arm_l,
		Quaternion(Vector3.RIGHT, sin(phase + PI) * leg_swing * 0.6 + 0.15))
	_skel.set_bone_pose_rotation(_bone_upper_arm_r,
		Quaternion(Vector3.RIGHT, sin(phase) * leg_swing * 0.6 + 0.15))
	_skel.set_bone_pose_rotation(_bone_forearm_l,
		Quaternion(Vector3.RIGHT, 0.1))
	_skel.set_bone_pose_rotation(_bone_forearm_r,
		Quaternion(Vector3.RIGHT, 0.1))

	# Head stays relatively stable
	_skel.set_bone_pose_rotation(_bone_head, Quaternion.IDENTITY)


func _animate_attack() -> void:
	var windup_ratio := _zombie_type_ref.attack_windup_ratio if _zombie_type_ref else 0.5
	var recover_ratio := _zombie_type_ref.attack_recover_ratio if _zombie_type_ref else 0.35
	var strike_start := windup_ratio
	var strike_end := strike_start + (1.0 - windup_ratio - recover_ratio)
	var t := clampf(_attack_anim_timer / ATTACK_COOLDOWN, 0.0, 1.0)

	if t < strike_start:
		# Wind-up: arms raise overhead
		var r := t / strike_start
		_skel.set_bone_pose_rotation(_bone_upper_arm_l,
			Quaternion(Vector3.RIGHT, lerp(0.15, -1.2, r)))
		_skel.set_bone_pose_rotation(_bone_upper_arm_r,
			Quaternion(Vector3.RIGHT, lerp(0.15, -1.2, r)))
		_skel.set_bone_pose_rotation(_bone_forearm_l,
			Quaternion(Vector3.RIGHT, lerp(0.1, -0.5, r)))
		_skel.set_bone_pose_rotation(_bone_forearm_r,
			Quaternion(Vector3.RIGHT, lerp(0.1, -0.5, r)))
		_skel.set_bone_pose_rotation(_bone_torso,
			Quaternion(Vector3.RIGHT, lerp(0.0, -0.1, r)))
		# Ground slam warning — cracks glow brighter
		if _crack_mat:
			_crack_mat.emission_energy_multiplier = lerp(
					_original_emission_energy, _original_emission_energy * 3.0, r)
	elif t < strike_end:
		# Strike: overhead slam down
		var r := (t - strike_start) / (strike_end - strike_start)
		_skel.set_bone_pose_rotation(_bone_upper_arm_l,
			Quaternion(Vector3.RIGHT, lerp(-1.2, 0.8, r)))
		_skel.set_bone_pose_rotation(_bone_upper_arm_r,
			Quaternion(Vector3.RIGHT, lerp(-1.2, 0.8, r)))
		_skel.set_bone_pose_rotation(_bone_forearm_l,
			Quaternion(Vector3.RIGHT, lerp(-0.5, 0.3, r)))
		_skel.set_bone_pose_rotation(_bone_forearm_r,
			Quaternion(Vector3.RIGHT, lerp(-0.5, 0.3, r)))
		_skel.set_bone_pose_rotation(_bone_torso,
			Quaternion(Vector3.RIGHT, lerp(-0.1, 0.15, r)))
		# Impact flash at the moment of strike
		if r > 0.3 and r < 0.5 and _crack_mat:
			_crack_mat.emission_energy_multiplier = _original_emission_energy * 5.0
	else:
		# Recover: slow return
		var r := (t - strike_end) / recover_ratio
		_skel.set_bone_pose_rotation(_bone_upper_arm_l,
			Quaternion(Vector3.RIGHT, lerp(0.8, 0.15, r)))
		_skel.set_bone_pose_rotation(_bone_upper_arm_r,
			Quaternion(Vector3.RIGHT, lerp(0.8, 0.15, r)))
		_skel.set_bone_pose_rotation(_bone_forearm_l,
			Quaternion(Vector3.RIGHT, lerp(0.3, 0.1, r)))
		_skel.set_bone_pose_rotation(_bone_forearm_r,
			Quaternion(Vector3.RIGHT, lerp(0.3, 0.1, r)))
		_skel.set_bone_pose_rotation(_bone_torso,
			Quaternion(Vector3.RIGHT, lerp(0.15, 0.0, r)))


func _animate_surprise() -> void:
	var t := clampf(_surprise_anim_time / 0.2, 0.0, 1.0)
	# Slight lean back
	_skel.set_bone_pose_rotation(_bone_torso,
		Quaternion(Vector3.RIGHT, lerp(0.0, -0.05, t)))
	_skel.set_bone_pose_rotation(_bone_upper_arm_l,
		Quaternion(Vector3.RIGHT, lerp(0.15, 0.3, t)))
	_skel.set_bone_pose_rotation(_bone_upper_arm_r,
		Quaternion(Vector3.RIGHT, lerp(0.15, 0.3, t)))


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

	# Ragdoll: activate physics on the PhysicalBoneSimulator
	var sim := _skel.get_node_or_null("PhysicalBoneSimulator") as PhysicalBoneSimulator3D
	if sim:
		sim.physical_bones_start_simulation()

	# Cracks flare bright on death
	if _crack_mat:
		var flare_tween := create_tween()
		flare_tween.tween_property(_crack_mat, "emission_energy_multiplier",
				_original_emission_energy * 4.0, collapse_time * 0.3)
		flare_tween.tween_property(_crack_mat, "emission_energy_multiplier", 0.0, collapse_time * 0.5)

	var done_tween := create_tween()
	done_tween.tween_interval(collapse_time + 0.05)
	done_tween.tween_callback(func(): death_animation_finished.emit())


func set_attack_timer(val: float) -> void:
	_attack_anim_timer = val


func pulse_cracks(_delta: float) -> void:
	if _crack_mat and _flash_timer <= 0.0:
		var pulse := _original_emission_energy \
				+ sin(_anim_time * 1.5) * _original_emission_energy * 0.3 \
				+ sin(_anim_time * 4.0) * _original_emission_energy * 0.1
		_crack_mat.emission_energy_multiplier = pulse
