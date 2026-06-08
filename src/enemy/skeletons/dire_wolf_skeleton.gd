class_name DireWolfSkeleton
extends EnemySkeleton
## Procedural quadruped mesh: elongated body, 4 legs, snout, tail.

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

var _torso: MeshInstance3D
var _head_pivot: Node3D
var _tail_pivot: Node3D
var _pivot_fl: Node3D  # front-left leg
var _pivot_fr: Node3D  # front-right leg
var _pivot_bl: Node3D  # back-left leg
var _pivot_br: Node3D  # back-right leg
var _pivot_fl_lower: Node3D
var _pivot_fr_lower: Node3D
var _pivot_bl_lower: Node3D
var _pivot_br_lower: Node3D


func build(type: EnemyType, scale_val: float) -> void:
	body_scale = scale_val
	_zombie_type_ref = type
	scale = Vector3(scale_val * 0.5, scale_val, scale_val * 0.5)

	_body_mat = _create_body_mat(type)
	_eye_mat = _create_eye_mat()
	_original_emission = type.emissive_color
	_original_emission_energy = type.emissive_strength

	_build_torso()
	_build_head()
	_build_legs()
	_build_tail()


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


func _build_torso() -> void:
	# Elongated horizontal capsule body
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

		# Front cap
		var v_tl := Vector3(c0 * radius_x, half_h, length + s0 * radius_z)
		var v_tr := Vector3(c1 * radius_x, half_h, length + s1 * radius_z)
		var v_ml := Vector3(c0 * radius_x, 0, length + s0 * radius_z)
		var v_mr := Vector3(c1 * radius_x, 0, length + s1 * radius_z)
		var v_bl := Vector3(c0 * radius_x, -half_h, length + s0 * radius_z)
		var v_br := Vector3(c1 * radius_x, -half_h, length + s1 * radius_z)

		# Back cap
		var v_tl2 := Vector3(c0 * radius_x, half_h, -length + s0 * radius_z)
		var v_tr2 := Vector3(c1 * radius_x, half_h, -length + s1 * radius_z)
		var v_ml2 := Vector3(c0 * radius_x, 0, -length + s0 * radius_z)
		var v_mr2 := Vector3(c1 * radius_x, 0, -length + s1 * radius_z)
		var v_bl2 := Vector3(c0 * radius_x, -half_h, -length + s0 * radius_z)
		var v_br2 := Vector3(c1 * radius_x, -half_h, -length + s1 * radius_z)

		var n0 := Vector3(c0, 0.3, s0).normalized()
		var n1 := Vector3(c1, 0.3, s1).normalized()

		# Front section
		for data in [[v_tl, n0], [v_tr, n1], [v_bl, n0],
					 [v_tr, n1], [v_br, n1], [v_bl, n0]]:
			st.set_normal(data[1])
			st.set_uv(Vector2(0, 0))
			st.add_vertex(data[0])

		# Middle section (front to back)
		for data in [[v_ml, n0], [v_mr, n1], [v_ml2, n0],
					 [v_mr, n1], [v_mr2, n1], [v_ml2, n0]]:
			st.set_normal(data[1])
			st.set_uv(Vector2(0, 0))
			st.add_vertex(data[0])

	var mesh := st.commit()
	_torso = MeshInstance3D.new()
	_torso.mesh = mesh
	_torso.name = "Torso"
	_torso.position = Vector3(0, 0.22, 0)
	_torso.material_override = _body_mat
	add_child(_torso)

	# Build spine ridges on the back
	_build_spine_ridges()


func _build_spine_ridges() -> void:
	for i in 4:
		var ridge := MeshInstance3D.new()
		ridge.mesh = SphereMesh.new()
		(ridge.mesh as SphereMesh).radius = 0.018
		(ridge.mesh as SphereMesh).height = 0.04
		ridge.position = Vector3(0, 0.06, 0.35 - i * 0.2)
		ridge.scale = Vector3(1, 0.3, 0.6)
		ridge.material_override = _body_mat
		_torso.add_child(ridge)


func _build_head() -> void:
	# Snout/head at the front of the body
	_head_pivot = Node3D.new()
	_head_pivot.name = "HeadPivot"
	_head_pivot.position = Vector3(0, 0.04, 0.55)
	_torso.add_child(_head_pivot)

	# Main head sphere
	var head := MeshInstance3D.new()
	head.mesh = SphereMesh.new()
	(head.mesh as SphereMesh).radius = 0.09
	(head.mesh as SphereMesh).height = 0.16
	head.position = Vector3(0, 0.02, 0)
	head.material_override = _body_mat
	_head_pivot.add_child(head)

	# Snout (elongated cone)
	var snout := MeshInstance3D.new()
	var snout_mesh := CylinderMesh.new()
	(snout_mesh as CylinderMesh).top_radius = 0.0
	(snout_mesh as CylinderMesh).bottom_radius = 0.04
	(snout_mesh as CylinderMesh).height = 0.15
	snout.mesh = snout_mesh
	snout.position = Vector3(0, -0.02, 0.12)
	snout.rotation.x = deg_to_rad(-80)
	snout.material_override = _body_mat
	_head_pivot.add_child(snout)

	# Ears (two triangles/cones)
	for side in [-1, 1]:
		var ear := MeshInstance3D.new()
		var ear_mesh := CylinderMesh.new()
		(ear_mesh as CylinderMesh).top_radius = 0.0
		(ear_mesh as CylinderMesh).bottom_radius = 0.02
		(ear_mesh as CylinderMesh).height = 0.08
		ear.mesh = ear_mesh
		ear.position = Vector3(side * 0.05, 0.1, 0)
		ear.rotation.z = deg_to_rad(side * -15)
		ear.material_override = _body_mat
		_head_pivot.add_child(ear)

	# Eyes
	for side in [-1, 1]:
		var eye := MeshInstance3D.new()
		eye.mesh = SphereMesh.new()
		(eye.mesh as SphereMesh).radius = 0.02
		(eye.mesh as SphereMesh).height = 0.04
		(eye.mesh as SphereMesh).material = _eye_mat
		eye.position = Vector3(side * 0.06, 0.04, 0.06)
		_head_pivot.add_child(eye)

	# Claws on front paws
	for side in [-1, 1]:
		for i in 3:
			var claw := MeshInstance3D.new()
			var claw_mesh := CylinderMesh.new()
			(claw_mesh as CylinderMesh).top_radius = 0.0
			(claw_mesh as CylinderMesh).bottom_radius = 0.008
			(claw_mesh as CylinderMesh).height = 0.04
			claw.mesh = claw_mesh
			claw.position = Vector3(side * 0.03 + (i - 1) * 0.015, -0.05, 0.18)
			claw.material_override = _body_mat
			_head_pivot.add_child(claw)


func _build_legs() -> void:
	var leg_positions := [
		{"name": "FL", "pos": Vector3(0.1, 0, 0.3), "parent_pivot": "_pivot_fl", "lower_pivot": "_pivot_fl_lower"},
		{"name": "FR", "pos": Vector3(-0.1, 0, 0.3), "parent_pivot": "_pivot_fr", "lower_pivot": "_pivot_fr_lower"},
		{"name": "BL", "pos": Vector3(0.1, 0, -0.3), "parent_pivot": "_pivot_bl", "lower_pivot": "_pivot_bl_lower"},
		{"name": "BR", "pos": Vector3(-0.1, 0, -0.3), "parent_pivot": "_pivot_br", "lower_pivot": "_pivot_br_lower"},
	]

	for lp in leg_positions:
		var hip_pos: Vector3 = lp["pos"]
		var upper_len := 0.12
		var lower_len := 0.1
		var leg_r := 0.025

		# Upper leg pivot
		var upper_pivot := Node3D.new()
		upper_pivot.name = "UpperLeg" + lp["name"]
		upper_pivot.position = hip_pos
		_torso.add_child(upper_pivot)

		# Upper leg mesh
		var upper_mesh := _make_limb_mesh(Vector3.ZERO, Vector3(0, -upper_len, 0), leg_r, leg_r * 0.85)
		upper_mesh.material_override = _body_mat
		upper_pivot.add_child(upper_mesh)

		# Lower leg pivot
		var lower_pivot := Node3D.new()
		lower_pivot.name = "LowerLeg" + lp["name"]
		lower_pivot.position = Vector3(0, -upper_len, 0)
		upper_pivot.add_child(lower_pivot)

		# Lower leg mesh
		var lower_mesh := _make_limb_mesh(Vector3.ZERO, Vector3(0, -lower_len, 0), leg_r * 0.85, leg_r * 0.6)
		lower_mesh.material_override = _body_mat
		lower_pivot.add_child(lower_mesh)

		# Paw
		var paw := MeshInstance3D.new()
		paw.mesh = SphereMesh.new()
		(paw.mesh as SphereMesh).radius = 0.025
		(paw.mesh as SphereMesh).height = 0.03
		paw.position = Vector3(0, -lower_len, 0)
		paw.scale = Vector3(1, 0.5, 1.3)
		paw.material_override = _body_mat
		lower_pivot.add_child(paw)

		set(lp["parent_pivot"], upper_pivot)
		set(lp["lower_pivot"], lower_pivot)


func _build_tail() -> void:
	_tail_pivot = Node3D.new()
	_tail_pivot.name = "TailPivot"
	_tail_pivot.position = Vector3(0, 0.05, -0.5)
	_torso.add_child(_tail_pivot)

	# 3-segment tail
	var seg_len := 0.08
	var prev_pivot := _tail_pivot
	for i in 3:
		var seg := MeshInstance3D.new()
		var r: float = lerp(0.02, 0.008, float(i) / 3.0)
		seg.mesh = CylinderMesh.new()
		(seg.mesh as CylinderMesh).top_radius = r * 0.8
		(seg.mesh as CylinderMesh).bottom_radius = r
		(seg.mesh as CylinderMesh).height = seg_len
		seg.position = Vector3(0, 0, -seg_len * 0.5)
		seg.rotation.x = deg_to_rad(30)
		seg.material_override = _body_mat
		prev_pivot.add_child(seg)

		var child_pivot := Node3D.new()
		child_pivot.position = Vector3(0, 0, -seg_len)
		seg.add_child(child_pivot)
		prev_pivot = child_pivot


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
		_animate_walk(speed)
	else:
		_surprise_anim_time = 0.0
		_animate_idle()

	# Flinch
	if _flinch_timer > 0.0:
		var flinch_t := _flinch_timer / 0.15
		_torso.rotation.z += 0.3 * flinch_t

	# Tail sway
	if _tail_pivot:
		_tail_pivot.rotation.y = sin(_anim_time * 3.0) * 0.3

	pulse_eyes(delta)


func _animate_idle() -> void:
	var breath := sin(_anim_time * 2.5) * 0.005
	_torso.position.y = 0.22 + breath

	# Subtle leg sway
	if _pivot_fl:
		_pivot_fl.rotation.x = sin(_anim_time * 1.5) * 0.02
		_pivot_fr.rotation.x = sin(_anim_time * 1.7) * 0.02
		_pivot_bl.rotation.x = sin(_anim_time * 1.9) * 0.02
		_pivot_br.rotation.x = sin(_anim_time * 2.1) * 0.02

	# Head twitch
	if _head_pivot:
		_head_pivot.rotation.y = sin(_anim_time * 3.0) * 0.05


func _animate_walk(speed: float) -> void:
	var cadence_mult := _zombie_type_ref.walk_cadence_mult if _zombie_type_ref else 1.0
	var freq: float = clamp(speed * 2.5 * cadence_mult, 3.0, 10.0)
	var phase: float = _anim_time * freq

	var bob: float = abs(sin(phase * 0.5)) * 0.01 * speed
	_torso.position.y = 0.22 + bob
	_torso.rotation.x = sin(phase * 0.5) * 0.02 * speed

	# Diagonal gait: front-left + back-right move together
	var leg_swing: float = clamp(speed * 0.3, 0.2, 0.5)
	if _pivot_fl:
		_pivot_fl.rotation.x = sin(phase) * leg_swing
		_pivot_fr.rotation.x = sin(phase + PI) * leg_swing
		_pivot_bl.rotation.x = sin(phase + PI) * leg_swing
		_pivot_br.rotation.x = sin(phase) * leg_swing

		if _pivot_fl_lower:
			_pivot_fl_lower.rotation.x = abs(sin(phase)) * 0.2
			_pivot_fr_lower.rotation.x = abs(sin(phase + PI)) * 0.2
			_pivot_bl_lower.rotation.x = abs(sin(phase + PI)) * 0.2
			_pivot_br_lower.rotation.x = abs(sin(phase)) * 0.2

	# Head bob
	if _head_pivot:
		_head_pivot.rotation.x = sin(phase) * 0.03
		_head_pivot.rotation.y = 0.0


func _animate_attack() -> void:
	var windup_ratio := _zombie_type_ref.attack_windup_ratio if _zombie_type_ref else 0.4
	var recover_ratio := _zombie_type_ref.attack_recover_ratio if _zombie_type_ref else 0.3
	var strike_start := windup_ratio
	var strike_end := strike_start + (1.0 - windup_ratio - recover_ratio)

	var t := clampf(_attack_anim_timer / ATTACK_COOLDOWN, 0.0, 1.0)

	if t < strike_start:
		# Wind-up: head pulls back
		var r := t / strike_start
		if _head_pivot:
			_head_pivot.rotation.x = lerp(-0.3, 0.0, r)
		if _pivot_fl:
			_pivot_fl.rotation.x = lerp(0.3, 0.0, r)
			_pivot_fr.rotation.x = lerp(0.3, 0.0, r)
		_torso.rotation.x = lerp(0.1, 0.0, r)
	elif t < strike_end:
		# Strike: lunge forward
		var r := (t - strike_start) / (strike_end - strike_start)
		if _head_pivot:
			_head_pivot.rotation.x = lerp(0.0, 0.4, r)
		_torso.rotation.x = lerp(0.0, -0.15, r)
	else:
		# Recover
		var r := (t - strike_end) / recover_ratio
		if _head_pivot:
			_head_pivot.rotation.x = lerp(0.4, -0.1, r)
		_torso.rotation.x = lerp(-0.15, 0.0, r)


func _animate_surprise() -> void:
	var t := clampf(_surprise_anim_time / 0.2, 0.0, 1.0)
	if _head_pivot:
		_head_pivot.rotation.x = lerp(0.0, -0.2, t)
	if _pivot_fl:
		_pivot_fl.rotation.x = lerp(0.0, 0.15, t)
		_pivot_fr.rotation.x = lerp(0.0, 0.15, t)
	_torso.position.y = 0.22


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

	var dt := create_tween().set_parallel(true)
	dt.tween_property(_torso, "rotation:z", 0.8, collapse_time).set_ease(Tween.EASE_IN)
	dt.tween_property(_torso, "position:y", _torso.position.y - 0.1, collapse_time).set_ease(Tween.EASE_IN)
	if _pivot_fl:
		for pivot in [_pivot_fl, _pivot_fr, _pivot_bl, _pivot_br]:
			dt.tween_property(pivot, "rotation:x", 0.5, collapse_time * 0.8)
	if _head_pivot:
		dt.tween_property(_head_pivot, "rotation:x", 0.5, collapse_time * 0.6)

	var done_tween := create_tween()
	done_tween.tween_interval(collapse_time + 0.05)
	done_tween.tween_callback(func(): death_animation_finished.emit())


func set_attack_timer(val: float) -> void:
	_attack_anim_timer = val


func pulse_eyes(_delta: float) -> void:
	if _eye_mat:
		var pulse := 2.0 + sin(_anim_time * 5.0) * 1.5 + sin(_anim_time * 13.0) * 0.5
		_eye_mat.emission_energy_multiplier = pulse