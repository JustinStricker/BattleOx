class_name ZombieSkeleton
extends Node3D

const ATTACK_COOLDOWN: float = 1.2

var _torso: MeshInstance3D
var _head_pivot: Node3D
var _eye_mat: StandardMaterial3D
var _body_mat: StandardMaterial3D
var _pivot_arm_l: Node3D
var _pivot_arm_r: Node3D
var _pivot_forearm_l: Node3D
var _pivot_forearm_r: Node3D
var _pivot_leg_l: Node3D
var _pivot_leg_r: Node3D
var _pivot_shin_l: Node3D
var _pivot_shin_r: Node3D

var body_scale: float = 1.0
var _anim_time: float = 0.0
var _attack_anim_timer: float = 0.0
var _hunch_offset: float = 0.0
var _arm_length_mult: float = 1.0
var _leg_style: ZombieType.LegStyle = ZombieType.LegStyle.HUMANOID

var _flinch_timer: float = 0.0
var _flinch_intensity: float = 0.0
var _flash_timer: float = 0.0
var _original_emission: Color = Color.BLACK
var _original_emission_energy: float = 0.0
var _target_direction: Vector3 = Vector3.FORWARD
var _is_dying: bool = false
var _zombie_type_ref: ZombieType = null
var _surprise_anim_time: float = 0.0
signal death_animation_finished

static var _mesh_cache: Dictionary = {}


func build(type: ZombieType, scale_val: float) -> void:
	body_scale = scale_val
	_hunch_offset = type.hunch * 0.15
	_arm_length_mult = type.arm_length_mult
	_leg_style = type.leg_style
	position.y = 0.31 * scale_val - _hunch_offset * scale_val
	scale = Vector3(scale_val * 0.5, scale_val, scale_val * 0.5)

	_body_mat = _create_body_mat(type)
	_eye_mat = _create_eye_mat()
	_original_emission = type.emissive_color
	_original_emission_energy = type.emissive_strength
	_zombie_type_ref = type

	if _mesh_cache.has(type.resource_path):
		var cached: Node3D = _mesh_cache[type.resource_path] as Node3D
		for child in cached.get_children():
			var dup: Node = child.duplicate()
			add_child(dup)
		_find_limb_refs()
		_apply_materials_to_limbs()
	else:
		_build_from_scratch(type)
		var cache: Node3D = Node3D.new()
		for child in get_children():
			cache.add_child(child.duplicate())
		_mesh_cache[type.resource_path] = cache


func _find_limb_refs() -> void:
	_torso = get_node("Torso") as MeshInstance3D
	_head_pivot = get_node("Torso/HeadPivot") as Node3D
	_pivot_arm_l = get_node("Torso/UpperArmL") as Node3D
	_pivot_arm_r = get_node("Torso/UpperArmR") as Node3D
	_pivot_forearm_l = get_node("Torso/UpperArmL/ForearmL") as Node3D
	_pivot_forearm_r = get_node("Torso/UpperArmR/ForearmR") as Node3D
	_pivot_leg_l = get_node("Torso/ThighL") as Node3D
	_pivot_leg_r = get_node("Torso/ThighR") as Node3D
	_pivot_shin_l = get_node("Torso/ThighL/ShinL") as Node3D
	_pivot_shin_r = get_node("Torso/ThighR/ShinR") as Node3D


func _create_body_mat(type: ZombieType) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	var hue: float = randf_range(type.color_hue_min, type.color_hue_max)
	mat.albedo_color = Color.from_hsv(hue, type.color_saturation, type.color_value)
	mat.roughness = type.roughness
	mat.metallic = type.metallic
	mat.emission_enabled = type.emissive_strength > 0.1
	mat.emission = type.emissive_color
	mat.emission_energy_multiplier = type.emissive_strength
	return mat


func _create_eye_mat() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.08, 0.02)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.05, 0.01)
	mat.emission_energy_multiplier = 2.0
	return mat


func _build_from_scratch(type: ZombieType) -> void:
	_build_torso(type)
	_build_head(type)
	_build_arms(type)
	_build_legs(type)
	_build_eyes()
	if type.extra_eyes > 0:
		_build_extra_eyes(type)
	if type.jaw_style != ZombieType.JawStyle.NONE:
		_build_jaw(type)
	if type.neck_ring:
		_build_neck_ring(type)
	if type.spike_size > 0.001:
		_build_spikes(type)
	if type.claw_length > 0.001:
		_build_claws(type)
	if type.horn_length > 0.001 and type.head_style == ZombieType.HeadStyle.HORNED:
		_build_horns(type)
	if type.armor_plates:
		_build_armor_plates(type)
	if type.spine_extension > 0.001:
		_build_spine_extension(type)


func _apply_materials_to_limbs() -> void:
	if _torso:
		_torso.material_override = _body_mat
	if _head_pivot:
		var head_mesh: MeshInstance3D = _head_pivot.get_node_or_null("Head") as MeshInstance3D
		if head_mesh:
			head_mesh.material_override = _body_mat
	for pivot in [_pivot_arm_l, _pivot_arm_r, _pivot_forearm_l, _pivot_forearm_r,
				   _pivot_leg_l, _pivot_leg_r, _pivot_shin_l, _pivot_shin_r]:
		if not pivot:
			continue
		for child in pivot.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).material_override = _body_mat
	_eye_mat = _create_eye_mat()
	if _torso:
		for child in _torso.get_children():
			if child is MeshInstance3D and (child as MeshInstance3D).mesh is SphereMesh:
				(child as MeshInstance3D).material_override = _eye_mat


func _build_torso(_type: ZombieType) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var segs: int = 8
	var h: float = 0.45
	var width_mult: float = _type.torso_width_mult
	var w_top: float = 0.35 * width_mult
	var w_bot: float = 0.18 * width_mult
	var d_top: float = 0.2 * width_mult
	var d_bot: float = 0.14 * width_mult

	for i in segs:
		var a0: float = float(i) / segs * TAU
		var a1: float = float(i + 1) / segs * TAU
		var c0: float = cos(a0)
		var s0: float = sin(a0)
		var c1: float = cos(a1)
		var s1: float = sin(a1)

		var v_tl: Vector3 = Vector3(c0 * w_top, h * 0.5, s0 * d_top)
		var v_tr: Vector3 = Vector3(c1 * w_top, h * 0.5, s1 * d_top)
		var v_bl: Vector3 = Vector3(c0 * w_bot, -h * 0.5, s0 * d_bot)
		var v_br: Vector3 = Vector3(c1 * w_bot, -h * 0.5, s1 * d_bot)

		var n0: Vector3 = Vector3(c0, 0.3, s0).normalized()
		var n1: Vector3 = Vector3(c1, 0.3, s1).normalized()

		for data in [[v_tl, n0], [v_tr, n1], [v_bl, n0],
					 [v_tr, n1], [v_br, n1], [v_bl, n0]]:
			st.set_normal(data[1])
			st.set_uv(Vector2(0, 0))
			st.add_vertex(data[0])

	var mesh: Mesh = st.commit()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "Torso"
	mi.position = Vector3(0, 0.2, 0)
	mi.material_override = _body_mat
	add_child(mi)
	_torso = mi

	_build_ribs(mi, h)
	_build_spine_ridges(mi, h)


func _build_ribs(torso_mi: MeshInstance3D, torso_h: float) -> void:
	for i in 3:
		var rib: MeshInstance3D = MeshInstance3D.new()
		rib.mesh = CylinderMesh.new()
		(rib.mesh as CylinderMesh).top_radius = 0.018
		(rib.mesh as CylinderMesh).bottom_radius = 0.022
		(rib.mesh as CylinderMesh).height = 0.35
		rib.position = Vector3(0, torso_h * 0.5 - i * 0.09 - 0.05, -0.1)
		rib.rotation.x = deg_to_rad(15 + i * 5)
		rib.scale = Vector3(1, 1, 0.15)
		rib.material_override = _body_mat
		torso_mi.add_child(rib)


func _build_spine_ridges(torso_mi: MeshInstance3D, torso_h: float) -> void:
	for i in 4:
		var ridge: MeshInstance3D = MeshInstance3D.new()
		ridge.mesh = SphereMesh.new()
		(ridge.mesh as SphereMesh).radius = 0.025
		(ridge.mesh as SphereMesh).height = 0.05
		ridge.position = Vector3(0, torso_h * 0.5 - i * 0.08 - 0.03, 0.18 + i * 0.005)
		ridge.scale = Vector3(1, 0.3, 0.6)
		ridge.material_override = _body_mat
		torso_mi.add_child(ridge)


func _build_head(type: ZombieType) -> void:
	var torso_h: float = 0.4
	var head_cy: float = torso_h + 0.1
	var pivot: Node3D = Node3D.new()
	pivot.name = "HeadPivot"
	pivot.position = Vector3(0, head_cy, 0)
	_torso.add_child(pivot)
	_head_pivot = pivot

	match type.head_style:
		ZombieType.HeadStyle.SKULL:
			_build_skull_head(pivot)
		ZombieType.HeadStyle.ROUND:
			_build_round_head(pivot)
		ZombieType.HeadStyle.HORNED:
			_build_skull_head(pivot)


func _build_round_head(pivot: Node3D) -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	var head_mesh: MeshInstance3D = MeshInstance3D.new()
	head_mesh.mesh = sphere
	head_mesh.name = "Head"
	head_mesh.material_override = _body_mat
	pivot.add_child(head_mesh)


func _build_skull_head(pivot: Node3D) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var segs: int = 6
	var h: float = 0.14
	var r_top: float = 0.1
	var r_mid: float = 0.09
	var r_bot: float = 0.04

	for i in segs:
		var a0: float = float(i) / segs * TAU
		var a1: float = float(i + 1) / segs * TAU
		var c0: float = cos(a0)
		var s0: float = sin(a0)
		var c1: float = cos(a1)
		var s1: float = sin(a1)

		var face_flat: float = 0.7 + abs(s0) * 0.3

		var v_tl: Vector3 = Vector3(c0 * r_top * face_flat, h * 0.5, s0 * r_top * 0.8)
		var v_tr: Vector3 = Vector3(c1 * r_top * face_flat, h * 0.5, s1 * r_top * 0.8)
		var v_ml: Vector3 = Vector3(c0 * r_mid * face_flat, 0, s0 * r_mid * 0.8)
		var v_mr: Vector3 = Vector3(c1 * r_mid * face_flat, 0, s1 * r_mid * 0.8)
		var v_bl: Vector3 = Vector3(c0 * r_bot * face_flat, -h * 0.5, s0 * r_bot * 0.6)
		var v_br: Vector3 = Vector3(c1 * r_bot * face_flat, -h * 0.5, s1 * r_bot * 0.6)

		var n_top: Vector3 = Vector3(c0, 0.5, s0).normalized()
		var n_mid: Vector3 = Vector3(c0, 0.0, s0).normalized()
		var n_bot: Vector3 = Vector3(c0, -0.5, s0).normalized()
		var n_top_r: Vector3 = Vector3(c1, 0.5, s1).normalized()
		var n_mid_r: Vector3 = Vector3(c1, 0.0, s1).normalized()
		var n_bot_r: Vector3 = Vector3(c1, -0.5, s1).normalized()

		for data in [[v_tl, n_top], [v_tr, n_top_r], [v_ml, n_mid],
					 [v_tr, n_top_r], [v_mr, n_mid_r], [v_ml, n_mid]]:
			st.set_normal(data[1])
			st.set_uv(Vector2(0, 0))
			st.add_vertex(data[0])
		for data in [[v_ml, n_mid], [v_mr, n_mid_r], [v_bl, n_bot],
					 [v_mr, n_mid_r], [v_br, n_bot_r], [v_bl, n_bot]]:
			st.set_normal(data[1])
			st.set_uv(Vector2(0, 0))
			st.add_vertex(data[0])

	var mesh: Mesh = st.commit()
	var head_mesh: MeshInstance3D = MeshInstance3D.new()
	head_mesh.mesh = mesh
	head_mesh.name = "Head"
	head_mesh.material_override = _body_mat
	pivot.add_child(head_mesh)

	_build_brow_ridge(pivot)


func _build_brow_ridge(pivot: Node3D) -> void:
	var brow: MeshInstance3D = MeshInstance3D.new()
	brow.mesh = CylinderMesh.new()
	(brow.mesh as CylinderMesh).top_radius = 0.015
	(brow.mesh as CylinderMesh).bottom_radius = 0.025
	(brow.mesh as CylinderMesh).height = 0.14
	brow.position = Vector3(0, 0.05, -0.08)
	brow.rotation.x = deg_to_rad(-10)
	brow.scale = Vector3(1, 1, 0.3)
	brow.material_override = _body_mat
	pivot.add_child(brow)


func _build_horns(type: ZombieType) -> void:
	var horn_r: float = 0.02
	var horn_h: float = type.horn_length
	var positions: Array[Vector3] = [
		Vector3(0.06, 0.09, 0.02),
		Vector3(-0.06, 0.09, 0.02),
	]
	for pos in positions:
		var horn: MeshInstance3D = MeshInstance3D.new()
		horn.mesh = CylinderMesh.new()
		(horn.mesh as CylinderMesh).top_radius = 0.0
		(horn.mesh as CylinderMesh).bottom_radius = horn_r
		(horn.mesh as CylinderMesh).height = horn_h
		horn.position = pos
		horn.rotation.x = deg_to_rad(-25)
		horn.rotation.z += deg_to_rad(15) if pos.x > 0 else deg_to_rad(-15)
		horn.material_override = _body_mat
		_head_pivot.add_child(horn)


func _build_claws(type: ZombieType) -> void:
	var claw_r: float = 0.012
	var claw_h: float = type.claw_length
	for pivot in [_pivot_forearm_l, _pivot_forearm_r]:
		if not pivot:
			continue
		var arm_dir: float = -0.1 if pivot == _pivot_forearm_l else 0.1
		for i in 3:
			var claw: MeshInstance3D = MeshInstance3D.new()
			claw.mesh = CylinderMesh.new()
			(claw.mesh as CylinderMesh).top_radius = 0.0
			(claw.mesh as CylinderMesh).bottom_radius = claw_r
			(claw.mesh as CylinderMesh).height = claw_h
			var spread: float = (i - 1) * 0.025
			claw.position = Vector3(spread + arm_dir * 0.02, -claw_h * 0.4, 0)
			claw.rotation.x = deg_to_rad(10)
			claw.rotation.z = spread * 8.0
			claw.material_override = _body_mat
			pivot.add_child(claw)


func _build_spikes(type: ZombieType) -> void:
	var spike_r: float = 0.015
	var spike_h: float = type.spike_size
	var shoulder_positions: Array[Vector3] = [
		Vector3(0.3, 0.15, 0),
		Vector3(-0.3, 0.15, 0),
		Vector3(0.25, 0.25, 0.1),
		Vector3(-0.25, 0.25, 0.1),
	]
	for pos in shoulder_positions:
		var spike: MeshInstance3D = MeshInstance3D.new()
		spike.mesh = CylinderMesh.new()
		(spike.mesh as CylinderMesh).top_radius = 0.0
		(spike.mesh as CylinderMesh).bottom_radius = spike_r
		(spike.mesh as CylinderMesh).height = spike_h
		spike.position = pos
		var tilt_x: float = -20.0 if abs(pos.z) < 0.01 else -35.0
		spike.rotation.x = deg_to_rad(tilt_x)
		spike.rotation.z = deg_to_rad(pos.x * 10.0)
		spike.material_override = _body_mat
		_torso.add_child(spike)

	var back_positions: Array[Vector3] = [
		Vector3(0, 0.2, 0.2),
		Vector3(0, 0.1, 0.22),
		Vector3(0, 0.0, 0.2),
	]
	for pos in back_positions:
		var spike: MeshInstance3D = MeshInstance3D.new()
		spike.mesh = CylinderMesh.new()
		(spike.mesh as CylinderMesh).top_radius = 0.0
		(spike.mesh as CylinderMesh).bottom_radius = spike_r * 0.8
		(spike.mesh as CylinderMesh).height = spike_h * 0.8
		spike.position = pos
		spike.rotation.x = deg_to_rad(40)
		spike.material_override = _body_mat
		_torso.add_child(spike)


func _build_arms(type: ZombieType) -> void:
	var torso_w: float = 0.3
	var torso_h: float = 0.4
	var arm_r: float = type.arm_radius

	for side in [-1, 1]:
		# Support asymmetric arm lengths (-1 = use default arm_length_mult)
		var len_mult: float = type.arm_length_mult
		if side > 0 and type.arm_length_mult_right >= 0.0:
			len_mult = type.arm_length_mult_right
		elif side < 0 and type.arm_length_mult_right >= 0.0:
			# Left arm uses the primary mult when asymmetric is set
			len_mult = type.arm_length_mult
		var arm_len: float = 0.3 * len_mult

		var shoulder: Vector3 = Vector3(side * torso_w * 1.1, torso_h * 0.8, 0)
		var elbow: Vector3 = shoulder + Vector3(side * 0.05, -arm_len * 0.5, 0)
		var hand: Vector3 = elbow + Vector3(side * 0.05, -arm_len * 0.5, 0)

		var upper_pivot: Node3D = Node3D.new()
		upper_pivot.name = "UpperArm" + ("L" if side < 0 else "R")
		upper_pivot.position = shoulder
		_torso.add_child(upper_pivot)

		var upper_mesh: MeshInstance3D = _make_limb_mesh_instance(Vector3.ZERO, elbow - shoulder, arm_r, arm_r * 0.8)
		upper_mesh.name = "UpperArmMesh" + ("L" if side < 0 else "R")
		upper_mesh.material_override = _body_mat
		upper_pivot.add_child(upper_mesh)

		var forearm_pivot: Node3D = Node3D.new()
		forearm_pivot.name = "Forearm" + ("L" if side < 0 else "R")
		forearm_pivot.position = elbow - shoulder
		upper_pivot.add_child(forearm_pivot)

		var forearm_mesh: MeshInstance3D = _make_limb_mesh_instance(Vector3.ZERO, hand - elbow, arm_r * 0.8, arm_r * 0.5)
		forearm_mesh.name = "ForearmMesh" + ("L" if side < 0 else "R")
		forearm_mesh.material_override = _body_mat
		forearm_pivot.add_child(forearm_mesh)

		if side < 0:
			_pivot_arm_l = upper_pivot
			_pivot_forearm_l = forearm_pivot
		else:
			_pivot_arm_r = upper_pivot
			_pivot_forearm_r = forearm_pivot


func _build_legs(type: ZombieType) -> void:
	var torso_w: float = 0.3
	var torso_h: float = 0.4
	var leg_len: float = 0.35
	var leg_r: float = type.leg_radius
	var is_digi: bool = type.leg_style == ZombieType.LegStyle.DIGITIGRADE

	for side in [-1, 1]:
		var hip: Vector3 = Vector3(side * torso_w * 0.5, torso_h * 0.1, 0)
		var knee: Vector3
		var foot: Vector3
		if is_digi:
			knee = hip + Vector3(0, -leg_len * 0.3, side * 0.04)
			foot = knee + Vector3(0, -leg_len * 0.7, side * 0.06)
		else:
			knee = hip + Vector3(0, -leg_len * 0.5, side * 0.02)
			foot = knee + Vector3(0, -leg_len * 0.5, 0)

		var thigh_pivot: Node3D = Node3D.new()
		thigh_pivot.name = "Thigh" + ("L" if side < 0 else "R")
		thigh_pivot.position = hip
		_torso.add_child(thigh_pivot)

		var thigh_mesh: MeshInstance3D = _make_limb_mesh_instance(Vector3.ZERO, knee - hip, leg_r, leg_r * 0.8)
		thigh_mesh.name = "ThighMesh" + ("L" if side < 0 else "R")
		thigh_mesh.material_override = _body_mat
		thigh_pivot.add_child(thigh_mesh)

		var shin_pivot: Node3D = Node3D.new()
		shin_pivot.name = "Shin" + ("L" if side < 0 else "R")
		shin_pivot.position = knee - hip
		thigh_pivot.add_child(shin_pivot)

		var shin_mesh: MeshInstance3D = _make_limb_mesh_instance(Vector3.ZERO, foot - knee, leg_r * 0.8, leg_r * 0.5)
		shin_mesh.name = "ShinMesh" + ("L" if side < 0 else "R")
		shin_mesh.material_override = _body_mat
		shin_pivot.add_child(shin_mesh)

		if side < 0:
			_pivot_leg_l = thigh_pivot
			_pivot_shin_l = shin_pivot
		else:
			_pivot_leg_r = thigh_pivot
			_pivot_shin_r = shin_pivot


func _build_eyes() -> void:
	var torso_h: float = 0.4
	var head_r: float = 0.12
	var head_cy: float = torso_h + head_r * 0.8

	for side in [-1, 1]:
		var eye: MeshInstance3D = MeshInstance3D.new()
		eye.mesh = SphereMesh.new()
		(eye.mesh as SphereMesh).radius = 0.04
		(eye.mesh as SphereMesh).height = 0.08
		(eye.mesh as SphereMesh).material = _eye_mat
		eye.position = Vector3(side * -0.07, head_cy + head_r * 0.25, -head_r * 0.85)
		_torso.add_child(eye)


func _make_limb_mesh_instance(p0: Vector3, p1: Vector3, r0: float, r1: float) -> MeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_make_limb_segment(st, p0, p1, r0, r1, 4)
	var mesh: Mesh = st.commit()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	return mi


func _make_limb_segment(st: SurfaceTool, p0: Vector3, p1: Vector3, r0: float, r1: float, segs: int) -> void:
	var dir: Vector3 = (p1 - p0).normalized()
	var up: Vector3 = Vector3.UP if abs(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var right: Vector3 = dir.cross(up).normalized()
	up = right.cross(dir).normalized()

	for i in segs:
		var a0: float = float(i) / segs * TAU
		var a1: float = float(i + 1) / segs * TAU
		var c0: float = cos(a0)
		var s0: float = sin(a0)
		var c1: float = cos(a1)
		var s1: float = sin(a1)
		var v0: Vector3 = p0 + c0 * right * r0 + s0 * up * r0
		var v1: Vector3 = p0 + c1 * right * r0 + s1 * up * r0
		var v2: Vector3 = p1 + c0 * right * r1 + s0 * up * r1
		var v3: Vector3 = p1 + c1 * right * r1 + s1 * up * r1
		var n0: Vector3 = Vector3(c0, 0, s0).normalized()
		var n1: Vector3 = Vector3(c1, 0, s1).normalized()
		for data in [[v0, n0], [v1, n1], [v2, n0],
					 [v1, n1], [v3, n1], [v2, n0]]:
			st.set_normal(data[1] as Vector3)
			st.set_uv(Vector2(0, 0))
			st.add_vertex(data[0] as Vector3)


func update_animation(delta: float, is_moving: bool, is_attacking: bool, is_surprised: bool, speed: float, target_dir: Vector3 = Vector3.FORWARD) -> void:
	_anim_time += delta
	_target_direction = target_dir

	# Decay flinch recoil
	if _flinch_timer > 0.0:
		_flinch_timer = max(_flinch_timer - delta, 0.0)

	# Decay hit flash emission
	if _flash_timer > 0.0:
		_flash_timer = max(_flash_timer - delta, 0.0)
		if _flash_timer <= 0.0 and _body_mat:
			_body_mat.emission = _original_emission
			_body_mat.emission_energy_multiplier = _original_emission_energy

	if _is_dying:
		return

	if is_surprised:
		_surprise_anim_time += delta
		_animate_surprise(delta)
	elif is_attacking:
		_attack_anim_timer += delta
		_animate_attack()
	elif is_moving:
		_surprise_anim_time = 0.0
		_animate_walk(delta, speed)
	else:
		_surprise_anim_time = 0.0
		_animate_idle(delta)

	# Apply flinch recoil lean on top of current animation
	if _flinch_timer > 0.0:
		var flinch_t := _flinch_timer / 0.15
		_torso.rotation.x += _flinch_intensity * 0.4 * flinch_t

	pulse_eyes(delta)


func _set_limb_rotation(arm_x: float, forearm_x: float, leg_x: float, shin_x: float) -> void:
	if _pivot_arm_l:
		_pivot_arm_l.rotation.x = arm_x
		_pivot_arm_r.rotation.x = arm_x
		_pivot_forearm_l.rotation.x = forearm_x
		_pivot_forearm_r.rotation.x = forearm_x
	if _pivot_leg_l:
		_pivot_leg_l.rotation.x = leg_x
		_pivot_leg_r.rotation.x = leg_x
		_pivot_shin_l.rotation.x = shin_x
		_pivot_shin_r.rotation.x = shin_x


func _animate_idle(_delta: float) -> void:
	var breath: float = sin(_anim_time * 2.5) * 0.015
	var base_y: float = 0.2 - _hunch_offset
	_torso.position.y = base_y + breath
	_torso.position.x = 0.0
	_torso.rotation.x = 0.0

	var twitch: float = sin(_anim_time * 7.3) * 0.015 + sin(_anim_time * 11.7) * 0.01
	var sway: float = sin(_anim_time * 0.6) * 0.04
	if _pivot_arm_l:
		_pivot_arm_l.rotation.x = 0.1 + sway + twitch
		_pivot_arm_r.rotation.x = 0.1 - sway - twitch
		_pivot_forearm_l.rotation.x = 0.1 + sin(_anim_time * 9.1) * 0.02
		_pivot_forearm_r.rotation.x = 0.1 + sin(_anim_time * 8.3) * 0.02

	if _pivot_leg_l:
		_pivot_leg_l.rotation.x = sin(_anim_time * 4.1) * 0.005
		_pivot_leg_r.rotation.x = sin(_anim_time * 4.7) * 0.005

	var head_twitch: float = sin(_anim_time * 5.3) * 0.08 + sin(_anim_time * 13.1) * 0.04
	_head_pivot.rotation.y = head_twitch
	_head_pivot.rotation.x = sin(_anim_time * 6.7) * 0.03


func _animate_walk(delta: float, speed: float) -> void:
	var cadence_mult: float = _zombie_type_ref.walk_cadence_mult if _zombie_type_ref else 1.0
	var freq: float = clamp(speed * 2.5 * cadence_mult, 3.0, 10.0)
	var phase: float = _anim_time * freq

	var arm_swing: float = clamp(speed * 0.3, 0.35, 0.8)
	var leg_swing: float = clamp(speed * 0.22, 0.22, 0.55)

	var base_y: float = 0.2 - _hunch_offset
	# Boosted body bob for more visible movement
	var bob: float = abs(sin(phase * 0.5)) * 0.02 * speed
	# Lateral sway side-to-side
	var lateral_sway: float = sin(phase * 0.5) * 0.005 * speed
	_torso.position.y = base_y + bob
	_torso.position.x = lateral_sway

	var is_digi: bool = _leg_style == ZombieType.LegStyle.DIGITIGRADE

	if _pivot_arm_l:
		var arm_reach: float = 0.15 * (_arm_length_mult - 1.0)
		_pivot_arm_l.rotation.x = sin(phase) * arm_swing - arm_reach
		_pivot_arm_r.rotation.x = sin(phase + PI) * arm_swing - arm_reach
		_pivot_forearm_l.rotation.x = abs(sin(phase)) * 0.15 + 0.05
		_pivot_forearm_r.rotation.x = abs(sin(phase + PI)) * 0.15 + 0.05

	if _pivot_leg_l:
		var leg_sign: float = -1.0 if is_digi else 1.0
		_pivot_leg_l.rotation.x = sin(phase + PI) * leg_swing * leg_sign
		_pivot_leg_r.rotation.x = sin(phase) * leg_swing * leg_sign
		if is_digi:
			_pivot_shin_l.rotation.x = abs(sin(phase + PI)) * 0.15 + 0.3
			_pivot_shin_r.rotation.x = abs(sin(phase)) * 0.15 + 0.3
		else:
			_pivot_shin_l.rotation.x = abs(sin(phase + PI)) * 0.2
			_pivot_shin_r.rotation.x = abs(sin(phase)) * 0.2

	if is_digi:
		_torso.rotation.x = sin(phase) * 0.03
	else:
		_torso.rotation.x = 0.0

	# Forward lean from zombie type (Brute leans slightly, Runner leans more)
	var lean: float = _zombie_type_ref.torso_lean_forward if _zombie_type_ref else 0.0
	_torso.rotation.x += lean

	_head_pivot.rotation.y = 0.0


func set_attack_timer(val: float) -> void:
	_attack_anim_timer = val


func _animate_attack() -> void:
	var windup_ratio: float = _zombie_type_ref.attack_windup_ratio if _zombie_type_ref else 0.4
	var recover_ratio: float = _zombie_type_ref.attack_recover_ratio if _zombie_type_ref else 0.3
	var strike_start: float = windup_ratio
	var strike_end: float = strike_start + (1.0 - windup_ratio - recover_ratio)

	var t: float = _attack_anim_timer / ATTACK_COOLDOWN
	t = clamp(t, 0.0, 1.0)

	if t < strike_start:
		# Wind-up: arms pull back, torso leans back
		var r: float = t / strike_start
		_set_limb_rotation(lerp(0.8, 0.05, r), lerp(0.6, 0.05, r), 0.0, 0.0)
		_torso.rotation.x = lerp(-0.2, 0.0, r)
		_head_pivot.rotation.x = lerp(0.15, 0.0, r)
	elif t < strike_end:
		# Strike: arms swing forward, torso lunges
		var r: float = (t - strike_start) / (strike_end - strike_start)
		_set_limb_rotation(lerp(0.05, -0.8, r), lerp(0.05, -0.5, r), 0.0, 0.0)
		_torso.rotation.x = lerp(0.0, 0.15, r)
		_head_pivot.rotation.x = lerp(0.0, -0.2, r)
	else:
		# Recover: arms and torso return to ready
		var r: float = (t - strike_end) / recover_ratio
		_set_limb_rotation(lerp(-0.8, 0.6, r), lerp(-0.5, 0.4, r), 0.0, 0.0)
		_torso.rotation.x = lerp(0.15, -0.1, r)
		_head_pivot.rotation.x = lerp(-0.2, 0.1, r)


func play_hit_flinch() -> void:
	_flinch_timer = 0.15
	_flinch_intensity = 1.0
	if _zombie_type_ref:
		_flinch_intensity = _zombie_type_ref.flinch_strength
	_flash_body()


func _flash_body() -> void:
	if _body_mat:
		_body_mat.emission_enabled = true
		_body_mat.emission = Color.WHITE
		_body_mat.emission_energy_multiplier = 3.0
		_flash_timer = 0.12


func _animate_surprise(_delta: float) -> void:
	var t: float = clamp(_surprise_anim_time / 0.2, 0.0, 1.0)
	# Arms raise up in alert pose
	if _pivot_arm_l:
		_pivot_arm_l.rotation.x = lerp(0.3, -0.5, t)
		_pivot_arm_r.rotation.x = lerp(0.3, -0.5, t)
		_pivot_forearm_l.rotation.x = lerp(0.1, -0.3, t)
		_pivot_forearm_r.rotation.x = lerp(0.1, -0.3, t)
	# Head snaps forward/down
	_head_pivot.rotation.x = lerp(0.0, -0.15, t)
	_head_pivot.rotation.y = 0.0
	# Slight torso recoil (startled lean back)
	_torso.position.y = 0.2 - _hunch_offset
	_torso.rotation.x = lerp(0.0, 0.1, t)
	# Legs stay planted
	if _pivot_leg_l:
		_pivot_leg_l.rotation.x = 0.0
		_pivot_leg_r.rotation.x = 0.0


func play_death_animation() -> void:
	_is_dying = true
	var collapse_time: float = 0.4
	if _zombie_type_ref:
		collapse_time = _zombie_type_ref.death_collapse_time

	# Torso collapses forward and drops
	var dt: Tween = create_tween().set_parallel(true)
	dt.tween_property(_torso, "rotation:x", 0.8, collapse_time).set_ease(Tween.EASE_IN)
	dt.tween_property(_torso, "position:y", _torso.position.y - 0.15, collapse_time).set_ease(Tween.EASE_IN)
	# Arms go limp (drop forward/down)
	if _pivot_arm_l:
		dt.tween_property(_pivot_arm_l, "rotation:x", 0.5, collapse_time * 0.8)
		dt.tween_property(_pivot_arm_r, "rotation:x", 0.5, collapse_time * 0.8)
		dt.tween_property(_pivot_forearm_l, "rotation:x", 0.3, collapse_time * 0.8)
		dt.tween_property(_pivot_forearm_r, "rotation:x", 0.3, collapse_time * 0.8)
	# Head drops
	if _head_pivot:
		dt.tween_property(_head_pivot, "rotation:x", 0.4, collapse_time * 0.6)

	# Emit signal after collapse completes
	var done_tween: Tween = create_tween()
	done_tween.tween_interval(collapse_time + 0.05)
	done_tween.tween_callback(func(): death_animation_finished.emit())


func _build_jaw(type: ZombieType) -> void:
	if not _head_pivot:
		return
	match type.jaw_style:
		ZombieType.JawStyle.HANGING:
			# Dangling jaw — thin cylinder hanging down from skull base
			var jaw: MeshInstance3D = MeshInstance3D.new()
			jaw.mesh = CylinderMesh.new()
			(jaw.mesh as CylinderMesh).top_radius = 0.022
			(jaw.mesh as CylinderMesh).bottom_radius = 0.012
			(jaw.mesh as CylinderMesh).height = 0.08
			jaw.position = Vector3(0, -0.1, -0.04)
			jaw.rotation.x = deg_to_rad(25)
			jaw.scale = Vector3(0.7, 1, 0.35)
			jaw.material_override = _body_mat
			_head_pivot.add_child(jaw)
			# Small lower teeth row
			for ti in 3:
				var tooth: MeshInstance3D = MeshInstance3D.new()
				tooth.mesh = CylinderMesh.new()
				(tooth.mesh as CylinderMesh).top_radius = 0.005
				(tooth.mesh as CylinderMesh).bottom_radius = 0.003
				(tooth.mesh as CylinderMesh).height = 0.025
				tooth.position = Vector3((ti - 1) * 0.015, -0.14, -0.05)
				tooth.rotation.x = deg_to_rad(25)
				tooth.material_override = _body_mat
				_head_pivot.add_child(tooth)
		ZombieType.JawStyle.TUSK:
			# Two large downward-curving tusks
			for side in [-1, 1]:
				var tusk: MeshInstance3D = MeshInstance3D.new()
				tusk.mesh = CylinderMesh.new()
				(tusk.mesh as CylinderMesh).top_radius = 0.018
				(tusk.mesh as CylinderMesh).bottom_radius = 0.0
				(tusk.mesh as CylinderMesh).height = 0.15
				tusk.position = Vector3(side * 0.06, -0.08, -0.03)
				tusk.rotation.x = deg_to_rad(-15)
				tusk.rotation.z = deg_to_rad(side * 20)
				tusk.material_override = _body_mat
				_head_pivot.add_child(tusk)


func _build_extra_eyes(type: ZombieType) -> void:
	var torso_h: float = 0.4
	var head_r: float = 0.12
	var head_cy: float = torso_h + head_r * 0.8
	# Place extra eyes flanking the main pair, slightly higher and wider
	for i in type.extra_eyes:
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var row: float = floori(float(i) / 2.0)
		var eye: MeshInstance3D = MeshInstance3D.new()
		eye.mesh = SphereMesh.new()
		(eye.mesh as SphereMesh).radius = 0.025
		(eye.mesh as SphereMesh).height = 0.05
		(eye.mesh as SphereMesh).material = _eye_mat
		eye.position = Vector3(
			side * -0.1,
			head_cy + head_r * 0.35 + row * 0.03,
			-head_r * 0.82
		)
		_torso.add_child(eye)


func _build_neck_ring(type: ZombieType) -> void:
	# Thick collar/neck geometry around the base of the head
	var torso_h: float = 0.4
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.mesh = TorusMesh.new()
	(ring.mesh as TorusMesh).inner_radius = 0.06
	(ring.mesh as TorusMesh).outer_radius = 0.1
	ring.mesh = CylinderMesh.new()
	(ring.mesh as CylinderMesh).top_radius = 0.12
	(ring.mesh as CylinderMesh).bottom_radius = 0.14
	(ring.mesh as CylinderMesh).height = 0.06
	ring.position = Vector3(0, torso_h + 0.05, 0)
	ring.scale = Vector3(1, 1, 0.8)
	ring.material_override = _body_mat
	_torso.add_child(ring)


func _build_armor_plates(type: ZombieType) -> void:
	# Shoulder pauldron-like plates
	var torso_w: float = 0.3
	var torso_h: float = 0.4
	for side in [-1, 1]:
		var plate: MeshInstance3D = MeshInstance3D.new()
		plate.mesh = BoxMesh.new()
		(plate.mesh as BoxMesh).size = Vector3(0.12, 0.04, 0.15)
		plate.position = Vector3(side * torso_w * 1.05, torso_h * 0.9, 0)
		plate.rotation.z = deg_to_rad(side * -12)
		plate.rotation.x = deg_to_rad(-5)
		plate.material_override = _body_mat
		_torso.add_child(plate)

	# Back armor plates (2-3 stacked)
	for i in 3:
		var bplate: MeshInstance3D = MeshInstance3D.new()
		bplate.mesh = BoxMesh.new()
		(bplate.mesh as BoxMesh).size = Vector3(0.22 - i * 0.03, 0.035, 0.1)
		bplate.position = Vector3(0, torso_h * 0.85 - i * 0.06, 0.18 + i * 0.02)
		bplate.rotation.x = deg_to_rad(8 + i * 3)
		bplate.material_override = _body_mat
		_torso.add_child(bplate)


func _build_spine_extension(type: ZombieType) -> void:
	# Extends spine past the torso base — tail-like vertebrae
	var torso_h: float = 0.4
	var ext_len: float = type.spine_extension
	var vert_count: int = maxi(3, int(ext_len * 15.0))
	for i in vert_count:
		var t: float = float(i) / float(vert_count)
		var ridge: MeshInstance3D = MeshInstance3D.new()
		ridge.mesh = SphereMesh.new()
		var r: float = lerp(0.025, 0.01, t)
		(ridge.mesh as SphereMesh).radius = r
		(ridge.mesh as SphereMesh).height = r * 2.0
		var z_off: float = 0.2 + t * ext_len * 0.8
		var y_off: float = -torso_h * 0.45 - t * ext_len * 0.3
		ridge.position = Vector3(0, y_off, z_off)
		ridge.scale = Vector3(1, 0.3, 0.6)
		ridge.material_override = _body_mat
		_torso.add_child(ridge)


func pulse_eyes(_delta: float) -> void:
	if _eye_mat:
		var pulse: float = 2.0 + sin(_anim_time * 5.0) * 1.5 + sin(_anim_time * 13.0) * 0.5
		_eye_mat.emission_energy_multiplier = pulse
