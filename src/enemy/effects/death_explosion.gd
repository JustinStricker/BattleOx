class_name DeathExplosion
extends Node3D

static var _debris_mat: StandardMaterial3D
static var _flesh_mat: StandardMaterial3D
static var _bone_mat: StandardMaterial3D


static func _init_static() -> void:
	if _debris_mat:
		return

	_debris_mat = StandardMaterial3D.new()
	_debris_mat.albedo_color = Color(0.08, 0.06, 0.04)
	_debris_mat.roughness = 1.0
	_debris_mat.metallic = 0.3

	_flesh_mat = StandardMaterial3D.new()
	_flesh_mat.albedo_color = Color(0.35, 0.05, 0.03)
	_flesh_mat.roughness = 0.9
	_flesh_mat.metallic = 0.0

	_bone_mat = StandardMaterial3D.new()
	_bone_mat.albedo_color = Color(0.8, 0.75, 0.65)
	_bone_mat.roughness = 0.8


var _scale_mult: float = 1.0
var _emissive_color: Color = Color(1.0, 0.3, 0.1)


func set_enemy_type(type: EnemyType) -> void:
	if type:
		_scale_mult = max(0.5, type.health / 20.0)
		_emissive_color = type.emissive_color


func _ready() -> void:
	_init_static()

	var pos := global_position
	var s := _scale_mult

	# --- Smoke Cloud ---
	var smoke_particles: CPUParticles3D = CPUParticles3D.new()
	smoke_particles.amount = int(800 * s)
	smoke_particles.lifetime = 5.0
	smoke_particles.one_shot = true
	smoke_particles.emitting = true
	smoke_particles.explosiveness = 0.7
	smoke_particles.position = pos
	smoke_particles.direction = Vector3.UP
	smoke_particles.spread = 60.0
	smoke_particles.initial_velocity_min = 1.0 * s
	smoke_particles.initial_velocity_max = 5.0 * s
	smoke_particles.gravity = Vector3(0, -0.3, 0)
	smoke_particles.scale_amount_min = 3.0 * s
	smoke_particles.scale_amount_max = 8.0 * s
	smoke_particles.color = Color(0.3, 0.28, 0.25)
	add_child(smoke_particles)

	# --- Blood Spatter ---
	var blood_particles: CPUParticles3D = CPUParticles3D.new()
	blood_particles.amount = int(200 * s)
	blood_particles.lifetime = 2.0
	blood_particles.one_shot = true
	blood_particles.emitting = true
	blood_particles.explosiveness = 0.5
	blood_particles.position = pos
	blood_particles.direction = Vector3.UP
	blood_particles.spread = 90.0
	blood_particles.initial_velocity_min = 4.0 * s
	blood_particles.initial_velocity_max = 10.0 * s
	blood_particles.scale_amount_min = 0.08 * s
	blood_particles.scale_amount_max = 0.25 * s
	blood_particles.color = Color(0.6, 0.02, 0.02)
	blood_particles.gravity = Vector3(0, -2.0, 0)
	add_child(blood_particles)

	# --- Fine Blood Mist ---
	var mist_particles: CPUParticles3D = CPUParticles3D.new()
	mist_particles.amount = int(100 * s)
	mist_particles.lifetime = 1.5
	mist_particles.one_shot = true
	mist_particles.emitting = true
	mist_particles.explosiveness = 0.8
	mist_particles.position = pos
	mist_particles.direction = Vector3.UP
	mist_particles.spread = 120.0
	mist_particles.initial_velocity_min = 3.0 * s
	mist_particles.initial_velocity_max = 8.0 * s
	mist_particles.scale_amount_min = 0.02 * s
	mist_particles.scale_amount_max = 0.06 * s
	mist_particles.color = Color(0.7, 0.05, 0.05, 0.6)
	mist_particles.gravity = Vector3(0, -0.5, 0)
	add_child(mist_particles)

	# --- Fire Explosion Core ---
	var fire_mat := ParticleProcessMaterial.new()
	fire_mat.direction = Vector3.UP
	fire_mat.spread = 45.0
	fire_mat.initial_velocity_min = 5.0 * s
	fire_mat.initial_velocity_max = 15.0 * s
	fire_mat.scale_min = 0.1 * s
	fire_mat.scale_max = 0.3 * s
	var fire_grad := Gradient.new()
	fire_grad.set_color(0, Color(1.0, 0.9, 0.5, 1.0))
	fire_grad.add_point(0.4, Color(1.0, 0.5, 0.1, 0.9))
	fire_grad.add_point(0.7, Color(0.8, 0.2, 0.05, 0.5))
	fire_grad.set_color(fire_grad.get_point_count() - 1, Color(0.3, 0.05, 0.0, 0.0))
	var fire_grad_tex := GradientTexture1D.new()
	fire_grad_tex.gradient = fire_grad
	fire_mat.color_ramp = fire_grad_tex

	var fire_particles: GPUParticles3D = GPUParticles3D.new()
	fire_particles.process_material = fire_mat
	fire_particles.amount = int(80 * s)
	fire_particles.lifetime = 0.6
	fire_particles.one_shot = true
	fire_particles.emitting = true
	fire_particles.explosiveness = 1.0
	fire_particles.position = pos
	fire_particles.draw_pass_1 = _make_particle_mesh(Color(1.0, 0.6, 0.2), 0.08 * s)
	add_child(fire_particles)

	# --- Ember/Sparks Trail ---
	var ember_mat := ParticleProcessMaterial.new()
	ember_mat.direction = Vector3.UP
	ember_mat.spread = 60.0
	ember_mat.initial_velocity_min = 2.0 * s
	ember_mat.initial_velocity_max = 6.0 * s
	ember_mat.scale_min = 0.02 * s
	ember_mat.scale_max = 0.05 * s
	ember_mat.gravity = Vector3(0, -0.5, 0)
	var ember_grad := Gradient.new()
	ember_grad.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	ember_grad.add_point(0.5, Color(1.0, 0.7, 0.3, 0.8))
	ember_grad.set_color(ember_grad.get_point_count() - 1, Color(0.8, 0.3, 0.0, 0.0))
	var ember_grad_tex := GradientTexture1D.new()
	ember_grad_tex.gradient = ember_grad
	ember_mat.color_ramp = ember_grad_tex

	var ember_particles: GPUParticles3D = GPUParticles3D.new()
	ember_particles.process_material = ember_mat
	ember_particles.amount = int(60 * s)
	ember_particles.lifetime = 1.5
	ember_particles.one_shot = true
	ember_particles.emitting = true
	ember_particles.explosiveness = 0.6
	ember_particles.position = pos
	ember_particles.draw_pass_1 = _make_particle_mesh(Color(1.0, 0.8, 0.4), 0.04 * s)
	add_child(ember_particles)

	# --- Light Flash ---
	var flash: OmniLight3D = OmniLight3D.new()
	flash.light_color = _emissive_color
	flash.light_energy = 40.0 * s
	flash.omni_range = 18.0 * s
	flash.position = pos + Vector3.UP * 0.5
	add_child(flash)

	var flash_tween: Tween = flash.create_tween().bind_node(self)
	flash_tween.tween_property(flash, "light_energy", 0.0, 0.6)
	flash_tween.tween_callback(flash.queue_free)

	# --- Flesh Chunks ---
	for i in int(10 * s):
		_spawn_chunk(pos, _flesh_mat, s)

	# --- Debris Chunks ---
	for i in int(6 * s):
		_spawn_chunk(pos, _debris_mat, s)

	# --- Bone Fragments ---
	for i in int(4 * s):
		_spawn_chunk(pos, _bone_mat, s)

	# --- Shockwave Ring ---
	_spawn_shockwave_ring(pos, s)

	# --- Cleanup Timers ---
	var smoke_tween: Tween = smoke_particles.create_tween().bind_node(self)
	smoke_tween.tween_interval(6.0)
	smoke_tween.tween_callback(smoke_particles.queue_free)

	var blood_tween: Tween = blood_particles.create_tween().bind_node(self)
	blood_tween.tween_interval(3.0)
	blood_tween.tween_callback(blood_particles.queue_free)

	var mist_tween: Tween = mist_particles.create_tween().bind_node(self)
	mist_tween.tween_interval(2.5)
	mist_tween.tween_callback(mist_particles.queue_free)

	var fire_tween: Tween = fire_particles.create_tween().bind_node(self)
	fire_tween.tween_interval(1.5)
	fire_tween.tween_callback(fire_particles.queue_free)

	var ember_tween: Tween = ember_particles.create_tween().bind_node(self)
	ember_tween.tween_interval(2.5)
	ember_tween.tween_callback(ember_particles.queue_free)

	var cleanup_tween: Tween = create_tween().bind_node(self)
	cleanup_tween.tween_interval(7.0)
	cleanup_tween.tween_callback(queue_free)


func _make_particle_mesh(color: Color, size: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	mesh.material = mat
	return mesh


func _spawn_chunk(pos: Vector3, mat: StandardMaterial3D, s: float) -> void:
	var chunk: RigidBody3D = RigidBody3D.new()
	var chunk_col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	var chunk_size := randf_range(0.06, 0.18) * s
	box.size = Vector3(chunk_size, chunk_size, chunk_size)
	chunk_col.shape = box
	chunk.add_child(chunk_col)
	var chunk_mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var chunk_box_mesh: BoxMesh = BoxMesh.new()
	chunk_box_mesh.size = box.size
	chunk_box_mesh.material = mat
	chunk_mesh_inst.mesh = chunk_box_mesh
	chunk.add_child(chunk_mesh_inst)
	chunk.position = pos + Vector3(randf_range(-0.4, 0.4), randf_range(0.1, 0.4), randf_range(-0.4, 0.4)) * s
	chunk.gravity_scale = 1.5
	chunk.linear_damp = 0.8
	chunk.angular_damp = 1.5
	add_child(chunk)
	var impulse_dir: Vector3 = Vector3(randf_range(-1, 1), randf_range(0.5, 1.5), randf_range(-1, 1)).normalized()
	var impulse_force: float = randf_range(4.0, 10.0) * s
	chunk.apply_central_impulse(impulse_dir * impulse_force)
	chunk.apply_torque_impulse(Vector3(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)))
	var chunk_tween: Tween = chunk.create_tween().bind_node(self)
	chunk_tween.tween_interval(randf_range(2.0, 4.0))
	chunk_tween.tween_callback(chunk.queue_free)


func _spawn_shockwave_ring(pos: Vector3, s: float) -> void:
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.7, 0.85, 1.0, 1.0)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.4, 0.6, 1.0)
	ring_mat.emission_energy_multiplier = 10.0
	ring_mat.no_depth_test = true
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var segs := 24
	var inner_r := 0.3 * s
	var outer_r := 0.8 * s
	for i in range(segs + 1):
		var a := float(i) / float(segs) * TAU
		st.set_uv(Vector2(float(i) / float(segs), 0.0))
		st.add_vertex(Vector3(cos(a) * inner_r, 0.0, sin(a) * inner_r))
		st.set_uv(Vector2(float(i) / float(segs), 1.0))
		st.add_vertex(Vector3(cos(a) * outer_r, 0.0, sin(a) * outer_r))
	var ring_mesh: ArrayMesh = st.commit()

	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.mesh = ring_mesh
	ring.material_override = ring_mat
	ring.position = pos + Vector3.UP * 0.15
	add_child(ring)

	var ring_tween: Tween = create_tween().bind_node(self)
	ring_tween.tween_property(ring, "scale", Vector3(4.0, 1.0, 4.0), 0.4).set_ease(Tween.EASE_OUT)
	ring_tween.parallel().tween_method(func(a: float):
		ring_mat.albedo_color.a = a
	, 1.0, 0.0, 0.4)
	ring_tween.tween_callback(ring.queue_free)
