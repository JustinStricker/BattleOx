extends Node

signal score_changed(amount: int)

var collectibles: Array[Area3D] = []

func _ready() -> void:
	var positions: Array[Vector3] = [
		Vector3(5, 0.8, 4), Vector3(-3, 0.8, 5), Vector3(2, 0.8, -4),
		Vector3(-5, 0.8, -3), Vector3(0, 0.8, 8), Vector3(6, 0.8, -2),
		Vector3(-6, 0.8, 0), Vector3(4, 0.8, -6), Vector3(-4, 0.8, 7),
		Vector3(8, 0.8, 2), Vector3(-7, 0.8, -4)
	]
	for pos: Vector3 in positions:
		spawn_collectible(pos)

func spawn_collectible(pos: Vector3) -> void:
	var collectible: Area3D = Area3D.new()
	collectible.add_to_group("collectibles")
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	col_shape.shape = SphereShape3D.new()
	col_shape.shape.radius = 0.5
	collectible.add_child(col_shape)

	var sphere: MeshInstance3D = MeshInstance3D.new()
	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = 0.45
	sphere_mesh.height = 0.9
	var material: StandardMaterial3D = StandardMaterial3D.new()
	var hue: float = randf_range(0.0, 1.0)
	material.albedo_color = Color.from_hsv(hue, 0.9, 1.0)
	material.metallic = 0.85
	material.roughness = 0.15
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 0.3
	sphere_mesh.material = material
	sphere.mesh = sphere_mesh
	collectible.add_child(sphere)

	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_energy = 0.8
	glow.light_color = material.albedo_color
	glow.omni_range = 1.8
	collectible.add_child(glow)

	add_child(collectible)
	collectible.position = pos

	collectibles.append(collectible)
	collectible.set_meta("glow", glow)
	collectible.set_meta("start_y", pos.y)
	collectible.set_meta("speed", randf_range(1.0, 2.0))

	collectible.body_entered.connect(_on_collect.bind(collectible))

func _on_collect(body: Node3D, item: Area3D) -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return
	if body.is_in_group("player") or (body is RigidBody3D and body.is_in_group("arrow")):
		AudioManager.play_collect()
		rpc("_on_collect_rpc", item.get_path())
		score_changed.emit(10)
		if body is RigidBody3D and body.is_in_group("arrow"):
			create_impact_particles(body.global_position)
			body.queue_free()
		collectibles.erase(item)
		start_respawn()


@rpc("authority", "call_local", "reliable")
func _on_collect_rpc(item_path: NodePath) -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		return
	var item := get_node_or_null(item_path) as Area3D
	if item:
		AudioManager.play_collect()
		item.queue_free()
	score_changed.emit(10)

func create_impact_particles(pos: Vector3) -> void:
	var particles: GPUParticles3D = GPUParticles3D.new()
	var particle_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.spread = 180.0
	particle_material.scale_min = 0.2
	particle_material.scale_max = 0.2
	particle_material.color = Color.YELLOW
	particles.process_material = particle_material
	particles.amount = 20
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.emitting = true
	add_child(particles)
	particles.global_position = pos
	await get_tree().create_timer(0.6).timeout
	particles.queue_free()

func start_respawn() -> void:
	var delay: float = randf_range(3.0, 6.0)
	await get_tree().create_timer(delay).timeout
	var pos: Vector3 = Vector3(
		randf_range(-20.0, 20.0),
		0.8,
		randf_range(-30.0, 30.0)
	)
	spawn_collectible(pos)

func _process(delta: float) -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return
	for c: Node in collectibles:
		if is_instance_valid(c):
			c.rotate_y(delta * 2.0)
			var glow: OmniLight3D = c.get_meta("glow") as OmniLight3D
			var pulse: float = 0.6 + sin(Time.get_ticks_msec() * 0.005) * 0.3
			glow.light_energy = pulse
			var start_y: float = c.get_meta("start_y") as float
			var speed: float = c.get_meta("speed") as float
			c.position.y = start_y + sin(Time.get_ticks_msec() * 0.003 * speed) * 0.1
