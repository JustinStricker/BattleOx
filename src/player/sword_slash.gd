extends Node3D

signal slash_started()
signal slash_completed()

var slash_cooldown: float = 0.0
var is_slashing: bool = false
var sword_meshes: Node3D
var _hit_enemies_this_slash: Array[Node] = []

var _flash_light: OmniLight3D
var _particles: GPUParticles3D
var _sparks: GPUParticles3D
var _particle_mesh: SphereMesh

const SLASH_COOLDOWN: float = 1.5
const SLASH_DAMAGE: int = 25
const DASH_PATH_WIDTH: float = 3.0
const DASH_PATH_HEIGHT: float = 3.0
const DASH_PATH_DEPTH: float = 24.0


func _ready() -> void:
	position = Vector3(0.4, -0.3, -0.5)
	_build_sword_mesh()
	_cache_slash_objects()

func _process(delta: float) -> void:
	slash_cooldown = max(slash_cooldown - delta, 0.0)

func start_slash() -> bool:
	if slash_cooldown > 0.0 or is_slashing:
		return false

	slash_cooldown = SLASH_COOLDOWN
	is_slashing = true
	_play_slash_animation()
	if not multiplayer.is_server():
		var player := _get_player()
		if player:
			var cam := player.get_node_or_null("Camera3D") as Camera3D
			if cam:
				var origin := cam.global_position
				var forward := -cam.global_transform.basis.z
				rpc("_request_slash_rpc", origin, forward.normalized())
	return true


@rpc("any_peer", "call_local", "reliable")
func _request_slash_rpc(origin: Vector3, forward: Vector3) -> void:
	if not multiplayer.is_server():
		return
	_perform_slash_hit_at(origin, forward.normalized())


func _get_player() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("local_player") as CharacterBody3D

func can_slash() -> bool:
	return slash_cooldown <= 0.0 and not is_slashing

# Katana iaijutsu-style poses — horizontal sweep
const SHEATHE_POS: Vector3 = Vector3(0.0, -0.2, 0.4)
const SHEATHE_ROT: Vector3 = Vector3(0.0, 0.0, 0.1)

# Drawn back to right side, blade horizontal, edge facing forward
const READY_POS: Vector3 = Vector3(0.35, 0.05, -0.05)
const READY_ROT: Vector3 = Vector3(0.0, 0.0, -0.4)

# Horizontal follow-through ends at left — full arc
const END_POS: Vector3 = Vector3(-0.5, 0.05, 0.05)
const END_ROT: Vector3 = Vector3(0.0, 0.0, 0.4)

const DRAW_DURATION: float = 0.25
const SLASH_DURATION: float = 0.25
const SHEATHE_DURATION: float = 0.5

var _blade_glow_mat: StandardMaterial3D
var _blade_glow_instance: MeshInstance3D
var _sword_pivot: Node3D

func _build_sword_mesh() -> void:
	sword_meshes = Node3D.new()
	sword_meshes.name = "SwordMeshes"
	sword_meshes.position = SHEATHE_POS
	sword_meshes.rotation = SHEATHE_ROT
	sword_meshes.visible = false
	add_child(sword_meshes)

	# Sword pivot — at the pommel so the whole sword rotates from the handle end
	_sword_pivot = Node3D.new()
	_sword_pivot.name = "SwordPivot"
	_sword_pivot.position = Vector3(0.12, 0, 0)  # at the hilt/pommel
	sword_meshes.add_child(_sword_pivot)

	var hilt_mat: StandardMaterial3D = StandardMaterial3D.new()
	hilt_mat.albedo_color = Color(0.35, 0.2, 0.08)
	hilt_mat.roughness = 0.85

	var grip_mat: StandardMaterial3D = StandardMaterial3D.new()
	grip_mat.albedo_color = Color(0.15, 0.1, 0.08)
	grip_mat.roughness = 0.9

	var crossguard_mat: StandardMaterial3D = StandardMaterial3D.new()
	crossguard_mat.albedo_color = Color(0.5, 0.45, 0.35)
	crossguard_mat.metallic = 0.6
	crossguard_mat.roughness = 0.4

	var blade_mat: StandardMaterial3D = StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.85, 0.85, 0.9)
	blade_mat.metallic = 0.9
	blade_mat.roughness = 0.12
	blade_mat.emission_enabled = true
	blade_mat.emission = Color(0.4, 0.45, 0.55)
	blade_mat.emission_energy_multiplier = 0.3

	# Energy glow material on the blade — ramps up during slash
	_blade_glow_mat = StandardMaterial3D.new()
	_blade_glow_mat.albedo_color = Color(0.3, 0.7, 1.0, 0.0)
	_blade_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_blade_glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_blade_glow_mat.emission_enabled = true
	_blade_glow_mat.emission = Color(0.2, 0.5, 1.0)
	_blade_glow_mat.emission_energy_multiplier = 0.0
	_blade_glow_mat.no_depth_test = true

	# Hilt/pommel at right end of grip
	var hilt: MeshInstance3D = MeshInstance3D.new()
	hilt.mesh = SphereMesh.new()
	hilt.mesh.radius = 0.03
	hilt.mesh.height = 0.06
	hilt.mesh.material = hilt_mat
	hilt.position = Vector3(0, 0, 0)
	_sword_pivot.add_child(hilt)

	# Grip runs horizontally from pommel toward crossguard
	var grip: MeshInstance3D = MeshInstance3D.new()
	grip.mesh = CylinderMesh.new()
	grip.mesh.top_radius = 0.025
	grip.mesh.bottom_radius = 0.03
	grip.mesh.height = 0.12
	grip.mesh.material = grip_mat
	grip.position = Vector3(-0.06, 0, 0)
	grip.rotation = Vector3(0, 0, PI / 2)
	_sword_pivot.add_child(grip)

	# Crossguard — vertical rectangle between grip and blade
	var crossguard: MeshInstance3D = MeshInstance3D.new()
	crossguard.mesh = BoxMesh.new()
	crossguard.mesh.size = Vector3(0.02, 0.14, 0.04)
	crossguard.mesh.material = crossguard_mat
	crossguard.position = Vector3(-0.12, 0, 0)
	_sword_pivot.add_child(crossguard)

	# Curved katana blade — runs horizontally to the left (-X) from pivot
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var segs := 16
	var blade_len := 0.5
	var base_w := 0.03   # width at habaki (base)
	var tip_w := 0.003   # width at kissaki (tip)
	var max_curve := 0.035  # max sagitta of the curve (sori)
	for i in range(segs + 1):
		var t := float(i) / float(segs)
		var x := -(t * blade_len)  # extends left from crossguard
		# Curve: bow outward along Z (the sori)
		var curve_parabola := 4.0 * max_curve * t * (1.0 - t)
		var z := curve_parabola
		# Width tapers from base to tip
		var w: float = lerp(base_w, tip_w, t)
		# Spine (back) at +Y, edge at -Y
		var spine_y: float = w * 0.5
		var edge_y: float = -w * 0.5
		# Two vertices per segment (spine and edge)
		st.set_uv(Vector2(t, 0.0))
		st.add_vertex(Vector3(x, spine_y, z))
		st.set_uv(Vector2(t, 1.0))
		st.add_vertex(Vector3(x, edge_y, z))
	var blade_mesh: ArrayMesh = st.commit()
	var blade: MeshInstance3D = MeshInstance3D.new()
	blade.mesh = blade_mesh
	blade.material_override = blade_mat
	blade.position = Vector3(-0.12, 0, 0)  # offset back so blade starts at crossguard
	_sword_pivot.add_child(blade)

	# Energy glow overlay — same shape, slightly larger, with emission
	var glow_st := SurfaceTool.new()
	glow_st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var glow_mult := 1.4
	for i in range(segs + 1):
		var t := float(i) / float(segs)
		var x := -(t * blade_len)
		var curve_parabola := 4.0 * max_curve * t * (1.0 - t)
		var z := curve_parabola
		var w: float = lerp(base_w, tip_w, t) * glow_mult
		glow_st.set_uv(Vector2(t, 0.0))
		glow_st.add_vertex(Vector3(x, w * 0.5, z))
		glow_st.set_uv(Vector2(t, 1.0))
		glow_st.add_vertex(Vector3(x, -w * 0.5, z))
	var glow_blade_mesh: ArrayMesh = glow_st.commit()
	_blade_glow_instance = MeshInstance3D.new()
	_blade_glow_instance.mesh = glow_blade_mesh
	_blade_glow_instance.material_override = _blade_glow_mat
	_blade_glow_instance.position = Vector3(-0.12, 0, 0)
	_sword_pivot.add_child(_blade_glow_instance)


func _perform_slash_hit() -> void:
	if not multiplayer.is_server():
		return
	var player: CharacterBody3D = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player:
		return
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	if not cam:
		return
	var forward := -cam.global_transform.basis.z
	_perform_slash_hit_at(cam.global_position, forward.normalized())


func _perform_slash_hit_at(origin: Vector3, forward: Vector3) -> void:
	var player: CharacterBody3D = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player:
		return

	var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	if not space_state:
		return

	var up := Vector3.UP
	if abs(forward.dot(up)) > 0.99:
		up = Vector3.RIGHT

	var box := BoxShape3D.new()
	box.size = Vector3(DASH_PATH_WIDTH, DASH_PATH_HEIGHT, DASH_PATH_DEPTH)

	var box_center: Vector3 = origin + forward * DASH_PATH_DEPTH * 0.5
	box_center += up * DASH_PATH_HEIGHT * 0.5

	var box_transform := Transform3D.IDENTITY
	box_transform.origin = box_center
	box_transform.basis = Basis.looking_at(forward, up)

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = box_transform
	query.collision_mask = 2

	var results: Array[Dictionary] = space_state.intersect_shape(query)

	var hit_any := false
	for result in results:
		var collider: Node = result.collider
		if not collider or not collider.is_in_group("enemy"):
			continue
		if collider in _hit_enemies_this_slash:
			continue
		_hit_enemies_this_slash.append(collider)
		if collider.has_method("take_damage"):
			collider.take_damage(SLASH_DAMAGE, true)
			EventBus.damage_dealt.emit(SLASH_DAMAGE)
			hit_any = true

	if hit_any:
		AudioManager.play_sword_hit()
		_shake_camera(0.015, 0.12)


func check_hit() -> void:
	_perform_slash_hit()

func _shake_camera(amount: float, duration: float) -> void:
	var camera: Camera3D = get_parent() as Camera3D
	if not camera:
		return
	var orig_rot_x: float = camera.rotation.x
	var orig_rot_y: float = camera.rotation.y
	var tween: Tween = create_tween()
	var elapsed: float = 0.0
	tween.tween_method(func(_v: Variant):
		elapsed += get_process_delta_time()
		if not is_instance_valid(camera):
			tween.kill()
			return
		var decay: float = max(1.0 - elapsed / duration, 0.0)
		camera.rotation.x = orig_rot_x + randf_range(-amount, amount) * decay
		camera.rotation.y = orig_rot_y + randf_range(-amount, amount) * decay
	, 0.0, 1.0, duration)
	tween.tween_callback(func():
		if is_instance_valid(camera):
			camera.rotation.x = orig_rot_x
			camera.rotation.y = orig_rot_y
	)







func _cache_slash_objects() -> void:
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(0.7, 0.85, 1.0)
	_flash_light.light_energy = 12.0
	_flash_light.omni_range = 4.0
	_flash_light.position = Vector3(0, 0.1, -0.5)
	_flash_light.visible = false
	add_child(_flash_light)

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, -1)
	mat.spread = 60.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 8.0
	mat.gravity = Vector3(0, -1, 0)
	mat.scale_min = 0.015
	mat.scale_max = 0.04
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(0.3, Color(0.7, 0.85, 1.0, 0.9))
	gradient.add_point(0.7, Color(0.4, 0.5, 0.9, 0.5))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.2, 0.2, 0.5, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex

	var spark_mat := ParticleProcessMaterial.new()
	spark_mat.direction = Vector3(0, 0, -1)
	spark_mat.spread = 30.0
	spark_mat.initial_velocity_min = 6.0
	spark_mat.initial_velocity_max = 12.0
	spark_mat.gravity = Vector3(0, -1, 0)
	spark_mat.scale_min = 0.03
	spark_mat.scale_max = 0.06
	var spark_gradient := Gradient.new()
	spark_gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	spark_gradient.add_point(0.5, Color(1.0, 0.9, 0.7, 0.8))
	spark_gradient.set_color(spark_gradient.get_point_count() - 1, Color(0.8, 0.6, 0.3, 0.0))
	var spark_grad_tex := GradientTexture1D.new()
	spark_grad_tex.gradient = spark_gradient
	spark_mat.color_ramp = spark_grad_tex

	_particle_mesh = SphereMesh.new()
	_particle_mesh.radius = 0.02
	_particle_mesh.height = 0.04
	var pm_mat := StandardMaterial3D.new()
	pm_mat.albedo_color = Color(1.0, 0.95, 0.8)
	pm_mat.emission_enabled = true
	pm_mat.emission = Color(0.8, 0.85, 1.0)
	pm_mat.emission_energy_multiplier = 3.0
	_particle_mesh.material = pm_mat

	_particles = GPUParticles3D.new()
	_particles.amount = 40
	_particles.lifetime = 0.5
	_particles.one_shot = true
	_particles.emitting = false
	_particles.explosiveness = 1.0
	_particles.position = Vector3(0, 0.1, -0.5)
	_particles.process_material = mat
	_particles.draw_pass_1 = _particle_mesh
	add_child(_particles)

	_sparks = GPUParticles3D.new()
	_sparks.amount = 14
	_sparks.lifetime = 0.3
	_sparks.one_shot = true
	_sparks.emitting = false
	_sparks.explosiveness = 1.0
	_sparks.position = Vector3(0, 0.1, -0.5)
	_sparks.process_material = spark_mat
	_sparks.draw_pass_1 = _particle_mesh
	add_child(_sparks)


func _play_slash_animation() -> void:
	_hit_enemies_this_slash = []

	_flash_light.light_energy = 8.0
	_flash_light.visible = false
	_particles.restart()
	_particles.emitting = false
	_sparks.restart()
	_sparks.emitting = false

	slash_started.emit()
	AudioManager.play_sword_slash()
	sword_meshes.position = SHEATHE_POS
	sword_meshes.rotation = SHEATHE_ROT
	sword_meshes.scale = Vector3.ONE
	_sword_pivot.rotation = Vector3.ZERO
	sword_meshes.visible = true

	_perform_slash_hit()

	_blade_glow_mat.emission_energy_multiplier = 12.0
	_blade_glow_mat.albedo_color.a = 0.55

	var tween: Tween = create_tween()
	tween.tween_property(sword_meshes, "position", READY_POS, DRAW_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(sword_meshes, "rotation:x", READY_ROT.x, DRAW_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(_sword_pivot, "rotation:z", READY_ROT.z, DRAW_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_particles.emitting = true
	_sparks.emitting = true
	_flash_light.visible = true

	var total_sweep := SLASH_DURATION + SHEATHE_DURATION

	tween.tween_property(sword_meshes, "position", END_POS, SLASH_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(sword_meshes, "rotation:x", END_ROT.x, SLASH_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(_sword_pivot, "rotation:z", END_ROT.z, SLASH_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(sword_meshes, "scale", Vector3(0.9, 0.9, 0.9), SLASH_DURATION * 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	tween.parallel().tween_property(_flash_light, "light_energy", 0.0, 0.18).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_blade_glow_mat, "emission_energy_multiplier", 0.0, 0.2).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_blade_glow_mat, "albedo_color:a", 0.0, 0.2).set_ease(Tween.EASE_IN)

	tween.tween_property(sword_meshes, "position", SHEATHE_POS, SHEATHE_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(sword_meshes, "rotation", SHEATHE_ROT, SHEATHE_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(_sword_pivot, "rotation:z", SHEATHE_ROT.z, SHEATHE_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	tween.tween_callback(func():
		sword_meshes.visible = false
		sword_meshes.scale = Vector3.ONE
		_flash_light.visible = false
		_blade_glow_mat.emission_energy_multiplier = 0.0
		_blade_glow_mat.albedo_color.a = 0.0
		is_slashing = false
		slash_completed.emit()
	)
