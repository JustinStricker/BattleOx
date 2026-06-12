extends Node3D

const NUM_SHARDS := 9
const SHARD_HEIGHT_MAX := 0.35
const SHARD_HEIGHT_MIN := 0.08
const SHARD_WIDTH_MAX := 0.08
const SHARD_WIDTH_MIN := 0.03
const SPREAD_ANGLE := 1.4

const WING_X := 0.28
const WING_Y := -0.1
const WING_Z := -0.25

const SPRING_STIFFNESS := 35.0
const SPRING_DAMPING := 10.0

var _left_wing: Node3D
var _right_wing: Node3D
var _shard_materials: Array[StandardMaterial3D] = []
var _left_particles: GPUParticles3D
var _right_particles: GPUParticles3D
var _shard_nodes: Array[MeshInstance3D] = []
var _shard_phases: Array[float] = []
var _shard_base_rotations: Array[Vector3] = []

var _charge: float = 0.0
var _target_scale: float = 0.0
var _current_scale: float = 0.0
var _scale_velocity: float = 0.0
var _time: float = 0.0
var _launch_sweep: float = 0.0
var _flight_alpha: float = 1.0

var _jump_trail_particles: GPUParticles3D

var _launch_pmat: ParticleProcessMaterial
var _launch_pmesh: SphereMesh
var _launch_pm_mat: StandardMaterial3D


func _ready() -> void:
	_build_wings()
	_build_jump_trail()
	_cache_launch_burst()


func _cache_launch_burst() -> void:
	_launch_pmat = ParticleProcessMaterial.new()
	_launch_pmat.direction = Vector3(0, 1, 0)
	_launch_pmat.spread = 50.0
	_launch_pmat.initial_velocity_min = 1.0
	_launch_pmat.initial_velocity_max = 2.0
	_launch_pmat.gravity = Vector3.ZERO
	_launch_pmat.scale_min = 0.01
	_launch_pmat.scale_max = 0.05
	_launch_pmat.lifetime_randomness = 0.2

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.6, 0.9, 1.0, 1.0))
	gradient.add_point(0.4, Color(0.3, 0.7, 1.0, 0.6))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.1, 0.2, 0.6, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	_launch_pmat.color_ramp = grad_tex

	_launch_pmesh = SphereMesh.new()
	_launch_pmesh.radius = 0.018
	_launch_pmesh.height = 0.036

	_launch_pm_mat = StandardMaterial3D.new()
	_launch_pm_mat.albedo_color = Color(0.6, 0.9, 1.0)
	_launch_pm_mat.emission_enabled = true
	_launch_pm_mat.emission = Color(0.3, 0.6, 1.0)
	_launch_pm_mat.emission_energy_multiplier = 8.0
	_launch_pmesh.material = _launch_pm_mat


func _build_wings() -> void:
	for i in NUM_SHARDS:
		var mat := StandardMaterial3D.new()
		var t: float = float(i) / float(NUM_SHARDS - 1)
		var hue_shift := t * 0.15
		mat.albedo_color = Color(0.2 + hue_shift, 0.65 + hue_shift * 0.5, 1.0, 0.0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.emission_enabled = true
		mat.emission = Color(0.15 + hue_shift * 0.3, 0.5 + hue_shift * 0.3, 1.0)
		mat.emission_energy_multiplier = 0.0
		mat.no_depth_test = true
		_shard_materials.append(mat)

	_left_wing = Node3D.new()
	_left_wing.position = Vector3(-WING_X, WING_Y, WING_Z)
	_left_wing.rotation.x = -0.3
	add_child(_left_wing)

	_right_wing = Node3D.new()
	_right_wing.position = Vector3(WING_X, WING_Y, WING_Z)
	_right_wing.rotation.x = -0.3
	add_child(_right_wing)

	_build_wing(_left_wing, -1)
	_build_wing(_right_wing, 1)

	_setup_particles()


func _build_wing(wing: Node3D, sign_mult: int) -> void:
	for i in NUM_SHARDS:
		var shard := MeshInstance3D.new()
		var t: float = float(i) / float(NUM_SHARDS - 1)
		var angle: float = lerp(-SPREAD_ANGLE * 0.5, SPREAD_ANGLE * 0.5, t) * float(sign_mult * -1)

		var hh: float = lerp(SHARD_HEIGHT_MAX, SHARD_HEIGHT_MIN, t)
		var hw: float = lerp(SHARD_WIDTH_MIN, SHARD_WIDTH_MAX, t)

		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

		var z_bend := hw * 0.3
		var mid := Vector3(0, hh * 0.4, z_bend * 0.5)
		var top := Vector3(0, hh, z_bend)
		var bot := Vector3(0, -hh * 0.2, -z_bend * 0.3)
		var left := Vector3(-hw, 0, -z_bend * 0.2)
		var right := Vector3(hw, 0, -z_bend * 0.2)

		st.set_uv(Vector2(0.5, 1.0))
		st.add_vertex(top)
		st.set_uv(Vector2(1.0, 0.5))
		st.add_vertex(right)
		st.set_uv(Vector2(0.5, 0.0))
		st.add_vertex(mid)

		st.set_uv(Vector2(0.5, 1.0))
		st.add_vertex(top)
		st.set_uv(Vector2(0.5, 0.0))
		st.add_vertex(mid)
		st.set_uv(Vector2(0.0, 0.5))
		st.add_vertex(left)

		st.set_uv(Vector2(0.5, 0.0))
		st.add_vertex(mid)
		st.set_uv(Vector2(1.0, 0.5))
		st.add_vertex(right)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(bot)

		st.set_uv(Vector2(0.5, 0.0))
		st.add_vertex(mid)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(bot)
		st.set_uv(Vector2(0.0, 0.5))
		st.add_vertex(left)

		shard.mesh = st.commit()
		shard.material_override = _shard_materials[i]

		shard.rotation.z = angle
		shard.rotation.x = lerp(-0.3, 0.3, t) * float(sign_mult)

		var offset_dist: float = lerp(0.0, 0.08, t)
		var offset_vec: Vector2 = Vector2(0, offset_dist).rotated(angle)
		shard.position = Vector3(
			offset_vec.x,
			offset_vec.y + t * 0.02,
			lerp(0.0, 0.04, t) * float(sign_mult)
		)

		_shard_base_rotations.append(shard.rotation)

		wing.add_child(shard)
		_shard_nodes.append(shard)
		_shard_phases.append(randf() * TAU)


func _setup_particles() -> void:
	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, -1, 0)
	pmat.spread = 40.0
	pmat.initial_velocity_min = 0.3
	pmat.initial_velocity_max = 0.8
	pmat.gravity = Vector3(0, -0.2, 0)
	pmat.scale_min = 0.006
	pmat.scale_max = 0.018

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.5, 0.85, 1.0, 1.0))
	gradient.add_point(0.4, Color(0.3, 0.6, 1.0, 0.6))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.1, 0.2, 0.6, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	pmat.color_ramp = grad_tex

	var pmesh := SphereMesh.new()
	pmesh.radius = 0.01
	pmesh.height = 0.02
	var pm_mat := StandardMaterial3D.new()
	pm_mat.albedo_color = Color(0.5, 0.85, 1.0)
	pm_mat.emission_enabled = true
	pm_mat.emission = Color(0.3, 0.6, 1.0)
	pm_mat.emission_energy_multiplier = 4.0
	pmesh.material = pm_mat

	for wing in [_left_wing, _right_wing]:
		var particles := GPUParticles3D.new()
		particles.amount = 12
		particles.lifetime = 1.0
		particles.one_shot = false
		particles.emitting = false
		particles.explosiveness = 0.3
		particles.position = Vector3(0, -SHARD_HEIGHT_MIN * 0.4, 0)
		particles.process_material = pmat
		particles.draw_pass_1 = pmesh
		wing.add_child(particles)

		if wing == _left_wing:
			_left_particles = particles
		else:
			_right_particles = particles


func _build_jump_trail() -> void:
	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, -1, 0)
	pmat.spread = 30.0
	pmat.initial_velocity_min = 0.5
	pmat.initial_velocity_max = 1.5
	pmat.gravity = Vector3(0, -0.5, 0)
	pmat.scale_min = 0.008
	pmat.scale_max = 0.025
	pmat.lifetime_randomness = 0.3

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.5, 0.9, 1.0, 1.0))
	gradient.add_point(0.3, Color(0.3, 0.7, 1.0, 0.7))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.1, 0.2, 0.6, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	pmat.color_ramp = grad_tex

	var pmesh := SphereMesh.new()
	pmesh.radius = 0.012
	pmesh.height = 0.024
	var pm_mat := StandardMaterial3D.new()
	pm_mat.albedo_color = Color(0.5, 0.85, 1.0)
	pm_mat.emission_enabled = true
	pm_mat.emission = Color(0.3, 0.6, 1.0)
	pm_mat.emission_energy_multiplier = 6.0
	pmesh.material = pm_mat

	_jump_trail_particles = GPUParticles3D.new()
	_jump_trail_particles.amount = 30
	_jump_trail_particles.lifetime = 0.6
	_jump_trail_particles.one_shot = false
	_jump_trail_particles.emitting = false
	_jump_trail_particles.explosiveness = 0.0
	_jump_trail_particles.position = Vector3(0, -0.8, 0)
	_jump_trail_particles.process_material = pmat
	_jump_trail_particles.draw_pass_1 = pmesh
	add_child(_jump_trail_particles)


func set_charge(t: float) -> void:
	_charge = clamp(t, 0.0, 1.0)
	var show_t: float = max((_charge - 0.08) / 0.92, 0.0)
	_target_scale = show_t

	if show_t <= 0.0:
		_left_particles.emitting = false
		_right_particles.emitting = false
	else:
		_left_particles.emitting = true
		_right_particles.emitting = true


func launch(charge: float) -> void:
	var burst_t: float = clamp(charge, 0.0, 1.0)

	_launch_pmat.initial_velocity_min = 1.0 + burst_t * 4.0
	_launch_pmat.initial_velocity_max = 2.0 + burst_t * 6.0

	for wing in [_left_wing, _right_wing]:
		var burst := GPUParticles3D.new()
		burst.amount = 8 + int(burst_t * 14)
		burst.lifetime = 0.6
		burst.one_shot = true
		burst.explosiveness = 1.0
		burst.position = Vector3(0, -SHARD_HEIGHT_MIN * 0.4, 0)
		burst.process_material = _launch_pmat
		burst.draw_pass_1 = _launch_pmesh
		wing.add_child(burst)
		burst.restart()

		var tween := create_tween()
		tween.tween_interval(2.0)
		tween.tween_callback(burst.queue_free)

	# Launch sweep animation
	_launch_sweep = 1.0
	var sweep_tween := create_tween()
	sweep_tween.set_trans(Tween.TRANS_SPRING)
	sweep_tween.set_ease(Tween.EASE_OUT)
	sweep_tween.tween_property(self, "_launch_sweep", 0.0, 0.6)

	# Start jump trail
	_jump_trail_particles.emitting = true

	# Fade wings during flight
	_flight_alpha = 1.0
	var fade_tween := create_tween()
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(self, "_flight_alpha", 0.25, 0.5)


func land() -> void:
	_left_particles.emitting = false
	_right_particles.emitting = false

	_jump_trail_particles.emitting = false

	# Wing flourish on landing — pulse target scale then spring to 0
	_flight_alpha = 1.0
	_target_scale = 1.15
	var pulse_tween := create_tween()
	pulse_tween.tween_property(self, "_target_scale", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


func _process(delta: float) -> void:
	_time += delta

	# Spring-based scale transition
	var force: float = (_target_scale - _current_scale) * SPRING_STIFFNESS
	_scale_velocity += force * delta
	_scale_velocity *= max(1.0 - SPRING_DAMPING * delta, 0.0)
	_current_scale += _scale_velocity * delta

	var pulse: float = 0.85 + sin(_time * 2.5) * 0.15
	var full_charge_pulse: float = 0.0
	if _charge >= 0.95:
		full_charge_pulse = 0.3 + sin(_time * 4.0) * 0.3

	var scale_alpha := _current_scale * _flight_alpha

	for i in NUM_SHARDS:
		var t: float = float(i) / float(NUM_SHARDS - 1)
		var mat := _shard_materials[i]
		var alpha_var: float = lerp(0.4, 1.0, t)
		var charge_alpha = scale_alpha * 0.35 * alpha_var
		var charge_emission = scale_alpha * 2.0 * pulse * alpha_var

		if full_charge_pulse > 0.0:
			charge_emission += full_charge_pulse * 3.0 * alpha_var
			mat.emission = Color(
				0.4 + full_charge_pulse * 0.6,
				0.7 + full_charge_pulse * 0.3,
				1.0
			)
		else:
			mat.emission = Color(0.15 + t * 0.15, 0.5 + t * 0.15, 1.0)

		mat.albedo_color.a = charge_alpha
		mat.emission_energy_multiplier = charge_emission

	if _current_scale > 0.01:
		var time_offset: float = 0.3
		var flap_left: float = sin(_time * 3.0) * 0.025 * _current_scale
		var flap_right: float = sin(_time * 3.0 + time_offset) * 0.025 * _current_scale
		var hover: float = sin(_time * 1.2) * 0.004 * _current_scale
		var sweep: float = _launch_sweep * 0.5
		_left_wing.rotation.x = -0.3 + flap_left + hover - sweep
		_right_wing.rotation.x = -0.3 - flap_right + hover - sweep

		for si in _shard_nodes.size():
			var shard: MeshInstance3D = _shard_nodes[si]
			if not shard.get_parent() == _left_wing and not shard.get_parent() == _right_wing:
				continue
			var base: Vector3 = _shard_base_rotations[si] if si < _shard_base_rotations.size() else shard.rotation
			var phase: float = _shard_phases[si] if si < _shard_phases.size() else 0.0
			var side_offset: float = 0.0
			if shard.get_parent() == _right_wing:
				side_offset = 0.5
			var ripple := sin(_time * 4.0 + phase + float(si) * 0.8 + side_offset) * 0.04 * _current_scale
			var flutter := sin(_time * 6.0 + phase * 2.0 + side_offset * 1.5) * 0.02 * _current_scale
			shard.rotation.z = base.z + ripple
			shard.rotation.x = base.x + flutter

	_left_wing.scale = Vector3(_current_scale, _current_scale, _current_scale)
	_right_wing.scale = Vector3(_current_scale, _current_scale, _current_scale)

	# Update jump trail position to follow player feet
	if _jump_trail_particles and _jump_trail_particles.emitting:
		var player := get_parent().get_parent() as CharacterBody3D
		if player:
			_jump_trail_particles.global_position = player.global_position + Vector3(0, -0.2, 0)
