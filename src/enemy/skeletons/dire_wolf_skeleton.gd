class_name DireWolfSkeleton
extends EnemySkeleton
## Procedural quadruped mesh using Skeleton3D + BoneAttachment3D bones.
## Bones: Torso, Head, Snout, EarL, EarR, UpperLeg{FL,FR,BL,BR}, LowerLeg{FL,FR,BL,BR}, Tail{1,2}

const ATTACK_COOLDOWN: float = 1.0

var _body_mat: StandardMaterial3D
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
var _bone_torso: int = 0
var _bone_head: int = 1
var _bone_upper_fl: int = 5
var _bone_lower_fl: int = 6
var _bone_upper_fr: int = 7
var _bone_lower_fr: int = 8
var _bone_upper_bl: int = 9
var _bone_lower_bl: int = 10
var _bone_upper_br: int = 11
var _bone_lower_br: int = 12
var _bone_tail1: int = 13


func build(type: EnemyType, scale_val: float) -> void:
	body_scale = scale_val
	_zombie_type_ref = type
	scale = Vector3(scale_val * 0.5, scale_val, scale_val * 0.5)

	_body_mat = _create_body_mat(type)
	_eye_mat = _create_eye_mat()
	_original_emission = type.emissive_color
	_original_emission_energy = type.emissive_strength

	_setup_skeleton()
	_build_torso()
	_build_head()
	_build_legs()
	_build_tail()


func _setup_skeleton() -> void:
	_skel = Skeleton3D.new()
	_skel.name = "Skeleton3D"
	add_child(_skel)

	# Bone 0: Torso (root, at torso center height)
	_skel.add_bone("Torso")
	_skel.set_bone_rest(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.22, 0)))

	# Bone 1: Head (front of torso)
	_skel.add_bone("Head")
	_skel.set_bone_parent(1, 0)
	_skel.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0, 0.04, 0.55)))

	# Bone 2: Snout (extends from head)
	_skel.add_bone("Snout")
	_skel.set_bone_parent(2, 1)
	_skel.set_bone_rest(2, Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0.12)))

	# Bone 3-4: Ears
	_skel.add_bone("EarL")
	_skel.set_bone_parent(3, 1)
	_skel.set_bone_rest(3, Transform3D(Basis.IDENTITY, Vector3(-0.05, 0.1, 0)))

	_skel.add_bone("EarR")
	_skel.set_bone_parent(4, 1)
	_skel.set_bone_rest(4, Transform3D(Basis.IDENTITY, Vector3(0.05, 0.1, 0)))

	# Bones 5-12: Legs (upper + lower for each)
	var leg_configs := [
		{"name": "UpperLegFL", "parent": 0, "rest": Vector3(0.1, 0, 0.3)},
		{"name": "LowerLegFL", "parent": 5, "rest": Vector3(0, -0.12, 0)},
		{"name": "UpperLegFR", "parent": 0, "rest": Vector3(-0.1, 0, 0.3)},
		{"name": "LowerLegFR", "parent": 7, "rest": Vector3(0, -0.12, 0)},
		{"name": "UpperLegBL", "parent": 0, "rest": Vector3(0.1, 0, -0.3)},
		{"name": "LowerLegBL", "parent": 9, "rest": Vector3(0, -0.12, 0)},
		{"name": "UpperLegBR", "parent": 0, "rest": Vector3(-0.1, 0, -0.3)},
		{"name": "LowerLegBR", "parent": 11, "rest": Vector3(0, -0.12, 0)},
	]
	var bone_idx := 5
	for config in leg_configs:
		_skel.add_bone(config["name"])
		_skel.set_bone_parent(bone_idx, config["parent"])
		_skel.set_bone_rest(bone_idx, Transform3D(Basis.IDENTITY, config["rest"]))
		bone_idx += 1

	# Bone 13-14: Tail segments
	_skel.add_bone("Tail1")
	_skel.set_bone_parent(13, 0)
	_skel.set_bone_rest(13, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -0.5)))

	_skel.add_bone("Tail2")
	_skel.set_bone_parent(14, 13)
	_skel.set_bone_rest(14, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.08)))

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
	mat.emission_enabled = type.emissive_strength > 0.1
	mat.emission = type.emissive_color
	mat.emission_energy_multiplier = type.emissive_strength
	return mat


func _create_eye_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.08, 0.02)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.05, 0.01)
	mat.emission_energy_multiplier = 2.0
	return mat


# --- Mesh Building (procedural SurfaceTool geometry attached to bones) ---

func _make_torso_bone_attachment() -> BoneAttachment3D:
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = "Torso"
	attachment.name = "TorsoAttachment"
	_skel.add_child(attachment)
	return attachment


func _build_torso() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 8
	var half_h := 0.12
	var length := 0.5
	var radius_x := 0.14
	var radius_z := 0.1
	for i in segs:
		var a0 := float(i) / segs * TAU
		var a1 := float(i + 1) / segs * TAU
		var c0 := cos(a0)
		var s0 := sin(a0)
		var c1 := cos(a1)
		var s1 := sin(a1)
		var v_tl := Vector3(c0 * radius_x, half_h, length + s0 * radius_z)
		var v_tr := Vector3(c1 * radius_x, half_h, length + s1 * radius_z)
		var v_ml := Vector3(c0 * radius_x, 0, length + s0 * radius_z)
		var v_mr := Vector3(c1 * radius_x, 0, length + s1 * radius_z)
		var v_bl := Vector3(c0 * radius_x, -half_h, length + s0 * radius_z)
		var v_br := Vector3(c1 * radius_x, -half_h, length + s1 * radius_z)
		var _v_tl2 := Vector3(c0 * radius_x, half_h, -length + s0 * radius_z)
		var _v_tr2 := Vector3(c1 * radius_x, half_h, -length + s1 * radius_z)
		var v_ml2 := Vector3(c0 * radius_x, 0, -length + s0 * radius_z)
		var v_mr2 := Vector3(c1 * radius_x, 0, -length + s1 * radius_z)
		var _v_bl2 := Vector3(c0 * radius_x, -half_h, -length + s0 * radius_z)
		var _v_br2 := Vector3(c1 * radius_x, -half_h, -length + s1 * radius_z)
		var n0 := Vector3(c0, 0.3, s0).normalized()
		var n1 := Vector3(c1, 0.3, s1).normalized()
		for data in [[v_tl, n0], [v_tr, n1], [v_bl, n0],
					 [v_tr, n1], [v_br, n1], [v_bl, n0]]:
			st.set_normal(data[1])
			st.set_uv(Vector2(0, 0))
			st.add_vertex(data[0])
		for data in [[v_ml, n0], [v_mr, n1], [v_ml2, n0],
					 [v_mr, n1], [v_mr2, n1], [v_ml2, n0]]:
			st.set_normal(data[1])
			st.set_uv(Vector2(0, 0))
			st.add_vertex(data[0])
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _body_mat
	var attachment := _make_torso_bone_attachment()
	attachment.add_child(mi)
	_build_spine_ridges(attachment)


func _build_spine_ridges(parent: Node3D) -> void:
	for i in 4:
		var ridge := MeshInstance3D.new()
		ridge.mesh = SphereMesh.new()
		(ridge.mesh as SphereMesh).radius = 0.018
		(ridge.mesh as SphereMesh).height = 0.04
		ridge.position = Vector3(0, 0.06, 0.35 - i * 0.2)
		ridge.scale = Vector3(1, 0.3, 0.6)
		ridge.material_override = _body_mat
		parent.add_child(ridge)


func _build_head() -> void:
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = "Head"
	attachment.name = "HeadAttachment"
	_skel.add_child(attachment)

	# Main head sphere
	var head := MeshInstance3D.new()
	head.mesh = SphereMesh.new()
	(head.mesh as SphereMesh).radius = 0.09
	(head.mesh as SphereMesh).height = 0.16
	head.material_override = _body_mat
	attachment.add_child(head)

	# Eyes
	for side in [-1, 1]:
		var eye := MeshInstance3D.new()
		eye.mesh = SphereMesh.new()
		(eye.mesh as SphereMesh).radius = 0.02
		(eye.mesh as SphereMesh).height = 0.04
		(eye.mesh as SphereMesh).material = _eye_mat
		eye.position = Vector3(side * 0.06, 0.04, 0.06)
		attachment.add_child(eye)

	# Snout
	var snout_attachment := BoneAttachment3D.new()
	snout_attachment.bone_name = "Snout"
	snout_attachment.name = "SnoutAttachment"
	_skel.add_child(snout_attachment)

	var snout := MeshInstance3D.new()
	var snout_mesh := CylinderMesh.new()
	(snout_mesh as CylinderMesh).top_radius = 0.0
	(snout_mesh as CylinderMesh).bottom_radius = 0.04
	(snout_mesh as CylinderMesh).height = 0.15
	snout.mesh = snout_mesh
	snout.rotation.x = deg_to_rad(-80)
	snout.material_override = _body_mat
	snout_attachment.add_child(snout)

	# Ears
	for side in [-1, 1]:
		var ear_attachment := BoneAttachment3D.new()
		ear_attachment.bone_name = "EarL" if side < 0 else "EarR"
		ear_attachment.name = ear_attachment.bone_name + "Attachment"
		_skel.add_child(ear_attachment)

		var ear := MeshInstance3D.new()
		var ear_mesh := CylinderMesh.new()
		(ear_mesh as CylinderMesh).top_radius = 0.0
		(ear_mesh as CylinderMesh).bottom_radius = 0.02
		(ear_mesh as CylinderMesh).height = 0.08
		ear.mesh = ear_mesh
		ear.rotation.z = deg_to_rad(side * -15)
		ear.material_override = _body_mat
		ear_attachment.add_child(ear)

	# Claws on front paws (attached to lower legs)
	for side in [-1, 1]:
		var claw_bone_name := "LowerLegFL" if side < 0 else "LowerLegFR"
		for i in 3:
			var claw_attachment := BoneAttachment3D.new()
			claw_attachment.bone_name = claw_bone_name
			claw_attachment.name = claw_bone_name + "_claw%d" % i
			_skel.add_child(claw_attachment)

			var claw := MeshInstance3D.new()
			var claw_mesh := CylinderMesh.new()
			(claw_mesh as CylinderMesh).top_radius = 0.0
			(claw_mesh as CylinderMesh).bottom_radius = 0.008
			(claw_mesh as CylinderMesh).height = 0.04
			claw.mesh = claw_mesh
			claw.position = Vector3(side * 0.015 + (i - 1) * 0.015, 0, 0.06)
			claw.material_override = _body_mat
			claw_attachment.add_child(claw)


func _build_legs() -> void:
	var leg_configs := [
		{"upper": "UpperLegFL", "lower": "LowerLegFL"},
		{"upper": "UpperLegFR", "lower": "LowerLegFR"},
		{"upper": "UpperLegBL", "lower": "LowerLegBL"},
		{"upper": "UpperLegBR", "lower": "LowerLegBR"},
	]
	var leg_r := 0.025
	var upper_len := 0.12
	var lower_len := 0.1

	for config in leg_configs:
		# Upper leg
		var upper_attachment := BoneAttachment3D.new()
		upper_attachment.bone_name = config["upper"]
		upper_attachment.name = config["upper"] + "Attachment"
		_skel.add_child(upper_attachment)

		var upper_mesh := _make_limb_mesh(Vector3.ZERO, Vector3(0, -upper_len, 0), leg_r, leg_r * 0.85)
		upper_mesh.material_override = _body_mat
		upper_attachment.add_child(upper_mesh)

		# Lower leg
		var lower_attachment := BoneAttachment3D.new()
		lower_attachment.bone_name = config["lower"]
		lower_attachment.name = config["lower"] + "Attachment"
		_skel.add_child(lower_attachment)

		var lower_mesh := _make_limb_mesh(Vector3.ZERO, Vector3(0, -lower_len, 0), leg_r * 0.85, leg_r * 0.6)
		lower_mesh.material_override = _body_mat
		lower_attachment.add_child(lower_mesh)

		# Paw
		var paw := MeshInstance3D.new()
		paw.mesh = SphereMesh.new()
		(paw.mesh as SphereMesh).radius = 0.025
		(paw.mesh as SphereMesh).height = 0.03
		paw.position = Vector3(0, -lower_len, 0)
		paw.scale = Vector3(1, 0.5, 1.3)
		paw.material_override = _body_mat
		lower_attachment.add_child(paw)


func _build_tail() -> void:
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = "Tail1"
	attachment.name = "Tail1Attachment"
	_skel.add_child(attachment)

	var tail_seg := MeshInstance3D.new()
	var r := 0.02
	tail_seg.mesh = CylinderMesh.new()
	(tail_seg.mesh as CylinderMesh).top_radius = r * 0.8
	(tail_seg.mesh as CylinderMesh).bottom_radius = r
	(tail_seg.mesh as CylinderMesh).height = 0.08
	tail_seg.rotation.x = deg_to_rad(30)
	tail_seg.material_override = _body_mat
	attachment.add_child(tail_seg)

	var attachment2 := BoneAttachment3D.new()
	attachment2.bone_name = "Tail2"
	attachment2.name = "Tail2Attachment"
	_skel.add_child(attachment2)

	var tail_seg2 := MeshInstance3D.new()
	var r2 := 0.012
	tail_seg2.mesh = CylinderMesh.new()
	(tail_seg2.mesh as CylinderMesh).top_radius = r2 * 0.8
	(tail_seg2.mesh as CylinderMesh).bottom_radius = r2
	(tail_seg2.mesh as CylinderMesh).height = 0.08
	tail_seg2.rotation.x = deg_to_rad(30)
	tail_seg2.material_override = _body_mat
	attachment2.add_child(tail_seg2)


func _make_limb_mesh(p0: Vector3, p1: Vector3, r0: float, r1: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dir := (p1 - p0).normalized()
	var up := Vector3.UP if abs(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var right := dir.cross(up).normalized()
	up = right.cross(dir).normalized()
	var segs := 4
	for i in segs:
		var a0 := float(i) / segs * TAU
		var a1 := float(i + 1) / segs * TAU
		var c0 := cos(a0)
		var s0 := sin(a0)
		var c1 := cos(a1)
		var s1 := sin(a1)
		var v0 := p0 + c0 * right * r0 + s0 * up * r0
		var v1 := p0 + c1 * right * r0 + s1 * up * r0
		var v2 := p1 + c0 * right * r1 + s0 * up * r1
		var v3 := p1 + c1 * right * r1 + s1 * up * r1
		var n0 := Vector3(c0, 0, s0).normalized()
		var n1 := Vector3(c1, 0, s1).normalized()
		for data in [[v0, n0], [v1, n1], [v2, n0],
					 [v1, n1], [v3, n1], [v2, n0]]:
			st.set_normal(data[1] as Vector3)
			st.set_uv(Vector2(0, 0))
			st.add_vertex(data[0] as Vector3)
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


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
		_animate_walk(speed)
	else:
		_surprise_anim_time = 0.0
		_animate_idle()

	# Flinch overlay
	if _flinch_timer > 0.0:
		var flinch_t := _flinch_timer / 0.15
		var cur_rot := _skel.get_bone_pose_rotation(_bone_torso)
		var flinch_q := Quaternion(Vector3.FORWARD, 0.3 * flinch_t)
		_skel.set_bone_pose_rotation(_bone_torso, flinch_q * cur_rot)

	# Tail sway (always)
	_skel.set_bone_pose_rotation(_bone_tail1,
		Quaternion(Vector3.UP, sin(_anim_time * 3.0) * 0.3))

	pulse_eyes(delta)


func _animate_idle() -> void:
	var breath := sin(_anim_time * 2.5) * 0.005
	_skel.set_bone_pose_position(_bone_torso, Vector3(0, 0.22 + breath, 0))
	_skel.set_bone_pose_rotation(_bone_torso, Quaternion.IDENTITY)

	# Subtle leg sway
	_skel.set_bone_pose_rotation(_bone_upper_fl,
		Quaternion(Vector3.RIGHT, sin(_anim_time * 1.5) * 0.02))
	_skel.set_bone_pose_rotation(_bone_upper_fr,
		Quaternion(Vector3.RIGHT, sin(_anim_time * 1.7) * 0.02))
	_skel.set_bone_pose_rotation(_bone_upper_bl,
		Quaternion(Vector3.RIGHT, sin(_anim_time * 1.9) * 0.02))
	_skel.set_bone_pose_rotation(_bone_upper_br,
		Quaternion(Vector3.RIGHT, sin(_anim_time * 2.1) * 0.02))

	# Head twitch
	_skel.set_bone_pose_rotation(_bone_head,
		Quaternion(Vector3.UP, sin(_anim_time * 3.0) * 0.05))


func _animate_walk(speed: float) -> void:
	var cadence_mult := _zombie_type_ref.walk_cadence_mult if _zombie_type_ref else 1.0
	var freq: float = clamp(speed * 2.5 * cadence_mult, 3.0, 10.0)
	var phase: float = _anim_time * freq
	var bob: float = abs(sin(phase * 0.5)) * 0.01 * speed
	var leg_swing: float = clamp(speed * 0.3, 0.2, 0.5)

	# Torso bob and rock
	_skel.set_bone_pose_position(_bone_torso, Vector3(0, 0.22 + bob, 0))
	_skel.set_bone_pose_rotation(_bone_torso,
		Quaternion(Vector3.RIGHT, sin(phase * 0.5) * 0.02 * speed))

	# Diagonal gait: front-left + back-right move together
	_skel.set_bone_pose_rotation(_bone_upper_fl,
		Quaternion(Vector3.RIGHT, sin(phase) * leg_swing))
	_skel.set_bone_pose_rotation(_bone_upper_fr,
		Quaternion(Vector3.RIGHT, sin(phase + PI) * leg_swing))
	_skel.set_bone_pose_rotation(_bone_upper_bl,
		Quaternion(Vector3.RIGHT, sin(phase + PI) * leg_swing))
	_skel.set_bone_pose_rotation(_bone_upper_br,
		Quaternion(Vector3.RIGHT, sin(phase) * leg_swing))

	# Lower legs
	_skel.set_bone_pose_rotation(_bone_lower_fl,
		Quaternion(Vector3.RIGHT, abs(sin(phase)) * 0.2))
	_skel.set_bone_pose_rotation(_bone_lower_fr,
		Quaternion(Vector3.RIGHT, abs(sin(phase + PI)) * 0.2))
	_skel.set_bone_pose_rotation(_bone_lower_bl,
		Quaternion(Vector3.RIGHT, abs(sin(phase + PI)) * 0.2))
	_skel.set_bone_pose_rotation(_bone_lower_br,
		Quaternion(Vector3.RIGHT, abs(sin(phase)) * 0.2))

	# Head bob
	_skel.set_bone_pose_rotation(_bone_head,
		Quaternion(Vector3.RIGHT, sin(phase) * 0.03))


func _animate_attack() -> void:
	var windup_ratio := _zombie_type_ref.attack_windup_ratio if _zombie_type_ref else 0.4
	var recover_ratio := _zombie_type_ref.attack_recover_ratio if _zombie_type_ref else 0.3
	var strike_start := windup_ratio
	var strike_end := strike_start + (1.0 - windup_ratio - recover_ratio)
	var t := clampf(_attack_anim_timer / ATTACK_COOLDOWN, 0.0, 1.0)

	if t < strike_start:
		# Wind-up: head pulls back
		var r := t / strike_start
		_skel.set_bone_pose_rotation(_bone_head,
			Quaternion(Vector3.RIGHT, lerp(-0.3, 0.0, r)))
		_skel.set_bone_pose_rotation(_bone_upper_fl,
			Quaternion(Vector3.RIGHT, lerp(0.3, 0.0, r)))
		_skel.set_bone_pose_rotation(_bone_upper_fr,
			Quaternion(Vector3.RIGHT, lerp(0.3, 0.0, r)))
		_skel.set_bone_pose_rotation(_bone_torso,
			Quaternion(Vector3.RIGHT, lerp(0.1, 0.0, r)))
	elif t < strike_end:
		# Strike: lunge forward
		var r := (t - strike_start) / (strike_end - strike_start)
		_skel.set_bone_pose_rotation(_bone_head,
			Quaternion(Vector3.RIGHT, lerp(0.0, 0.4, r)))
		_skel.set_bone_pose_rotation(_bone_torso,
			Quaternion(Vector3.RIGHT, lerp(0.0, -0.15, r)))
	else:
		# Recover
		var r := (t - strike_end) / recover_ratio
		_skel.set_bone_pose_rotation(_bone_head,
			Quaternion(Vector3.RIGHT, lerp(0.4, -0.1, r)))
		_skel.set_bone_pose_rotation(_bone_torso,
			Quaternion(Vector3.RIGHT, lerp(-0.15, 0.0, r)))


func _animate_surprise() -> void:
	var t := clampf(_surprise_anim_time / 0.2, 0.0, 1.0)
	_skel.set_bone_pose_rotation(_bone_head,
		Quaternion(Vector3.RIGHT, lerp(0.0, -0.2, t)))
	_skel.set_bone_pose_rotation(_bone_upper_fl,
		Quaternion(Vector3.RIGHT, lerp(0.0, 0.15, t)))
	_skel.set_bone_pose_rotation(_bone_upper_fr,
		Quaternion(Vector3.RIGHT, lerp(0.0, 0.15, t)))
	_skel.set_bone_pose_position(_bone_torso, Vector3(0, 0.22, 0))


func play_hit_flinch() -> void:
	_flinch_timer = 0.15
	_flash_body()


func _flash_body() -> void:
	if _body_mat:
		_body_mat.emission_enabled = true
		_body_mat.emission = Color.WHITE
		_body_mat.emission_energy_multiplier = 3.0
		_flash_timer = 0.12


func play_death_animation() -> void:
	_is_dying = true
	var collapse_time := 0.4
	if _zombie_type_ref:
		collapse_time = _zombie_type_ref.death_collapse_time

	# Ragdoll: activate physics on the PhysicalBoneSimulator
	var sim := _skel.get_node_or_null("PhysicalBoneSimulator") as PhysicalBoneSimulator3D
	if sim:
		sim.physical_bones_start_simulation()

	var done_tween := create_tween()
	done_tween.tween_interval(collapse_time + 0.05)
	done_tween.tween_callback(func(): death_animation_finished.emit())


func set_attack_timer(val: float) -> void:
	_attack_anim_timer = val


func pulse_eyes(_delta: float) -> void:
	if _eye_mat:
		var pulse := 2.0 + sin(_anim_time * 5.0) * 1.5 + sin(_anim_time * 13.0) * 0.5
		_eye_mat.emission_energy_multiplier = pulse
