extends Node3D

const SPEED := 25.0
const BEAM_WIDTH := 6.0
const BEAM_HEIGHT := 0.7
const RANGE := 60.0
const DAMAGE_PER_TICK := 60
const TICK_INTERVAL := 0.2
const HIT_BOX_DEPTH := 6.0

var direction: Vector3
var traveled: float = 0.0
var tick_timer: float = 0.0
var hit_enemies: Array[Node] = []
var authoritative: bool = true

var _beam_mat: ShaderMaterial


func setup(origin: Vector3, dir: Vector3, auth: bool = true) -> void:
	authoritative = auth
	global_position = origin
	direction = dir
	var up := Vector3.UP
	if abs(dir.dot(up)) > 0.99:
		up = Vector3.RIGHT
	transform.basis = Basis.looking_at(dir, up)


func _ready() -> void:
	_build_beam()
	_build_flash()
	_build_trail_particles()


func _build_beam() -> void:
	var shader := preload("res://shaders/beam.gdshader")
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = shader
	_beam_mat.set_shader_parameter("core_color", Color(0.5, 0.85, 1.0, 1.0))
	_beam_mat.set_shader_parameter("edge_color", Color(0.15, 0.35, 0.75, 0.3))
	_beam_mat.set_shader_parameter("emission_strength", 6.0)
	_beam_mat.set_shader_parameter("pulse_speed", 2.5)
	_beam_mat.set_shader_parameter("scroll_speed", 2.0)
	_beam_mat.set_shader_parameter("distortion", 0.05)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var half_w := BEAM_WIDTH * 0.5
	var half_h := BEAM_HEIGHT * 0.5
	st.set_uv(Vector2(0, 0))
	st.add_vertex(Vector3(-half_w, half_h, 0))
	st.set_uv(Vector2(1, 0))
	st.add_vertex(Vector3(half_w, half_h, 0))
	st.set_uv(Vector2(0, 1))
	st.add_vertex(Vector3(-half_w, -half_h, 0))
	st.set_uv(Vector2(1, 1))
	st.add_vertex(Vector3(half_w, -half_h, 0))
	var mesh: ArrayMesh = st.commit()

	var beam := MeshInstance3D.new()
	beam.mesh = mesh
	beam.material_override = _beam_mat
	add_child(beam)


func _build_flash() -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 0.7, 1.0)
	light.light_energy = 25.0
	light.omni_range = 20.0
	add_child(light)


func _build_trail_particles() -> void:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 80.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.2
	mat.scale_max = 0.5

	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(0.3, Color(0.6, 0.85, 1.0, 0.9))
	gradient.add_point(0.6, Color(0.3, 0.5, 0.9, 0.5))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.2, 0.2, 0.5, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex

	var pmesh := SphereMesh.new()
	pmesh.radius = 0.1
	pmesh.height = 0.2
	var pm_mat := StandardMaterial3D.new()
	pm_mat.albedo_color = Color(0.6, 0.85, 1.0, 0.8)
	pm_mat.emission_enabled = true
	pm_mat.emission = Color(0.3, 0.6, 1.0)
	pm_mat.emission_energy_multiplier = 6.0
	pm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmesh.material = pm_mat

	var particles := GPUParticles3D.new()
	particles.amount = 60
	particles.lifetime = 1.0
	particles.emitting = true
	particles.explosiveness = 0.0
	particles.process_material = mat
	particles.draw_pass_1 = pmesh
	add_child(particles)


func _physics_process(delta: float) -> void:
	var move := direction * SPEED * delta
	global_position += move
	traveled += move.length()

	if traveled >= RANGE:
		queue_free()
		return

	tick_timer += delta
	if tick_timer >= TICK_INTERVAL:
		tick_timer = 0.0
		AudioManager.play_beam_tick()
		if authoritative:
			_hit_enemies()


func _hit_enemies() -> void:
	var space_state := get_world_3d().direct_space_state
	if not space_state:
		return

	var box := BoxShape3D.new()
	box.size = Vector3(BEAM_WIDTH, BEAM_HEIGHT, HIT_BOX_DEPTH)

	var box_center := global_position + direction * HIT_BOX_DEPTH * 0.5
	var up := Vector3.UP
	if abs(direction.dot(up)) > 0.99:
		up = Vector3.RIGHT
	var box_transform := Transform3D.IDENTITY
	box_transform.origin = box_center
	box_transform.basis = Basis.looking_at(direction, up)

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = box_transform
	query.collision_mask = 2

	var results: Array[Dictionary] = space_state.intersect_shape(query)
	for result in results:
		var collider: Node = result.collider
		if not collider or not collider.is_in_group("enemy"):
			continue
		if collider in hit_enemies:
			continue
		hit_enemies.append(collider)
		if collider.has_method("take_damage"):
			collider.take_damage(DAMAGE_PER_TICK, true)
