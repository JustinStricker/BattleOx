extends Node

static var _shaft_mat: StandardMaterial3D
static var _tip_mat: StandardMaterial3D
static var _fletch_mat: StandardMaterial3D
static var _nock_mat: StandardMaterial3D

static func _init_materials() -> void:
	if _shaft_mat:
		return
	_shaft_mat = StandardMaterial3D.new()
	_shaft_mat.albedo_color = Color(0.6, 0.4, 0.2)
	_shaft_mat.roughness = 0.7

	_tip_mat = StandardMaterial3D.new()
	_tip_mat.albedo_color = Color(0.75, 0.8, 0.85)
	_tip_mat.metallic = 0.9
	_tip_mat.roughness = 0.2

	_fletch_mat = StandardMaterial3D.new()
	_fletch_mat.albedo_color = Color(0.8, 0.15, 0.1)
	_fletch_mat.roughness = 0.6

	_nock_mat = StandardMaterial3D.new()
	_nock_mat.albedo_color = Color(0.2, 0.15, 0.1)
	_nock_mat.roughness = 0.8

static func spawn(parent: Node, origin: Vector3, direction: Vector3, speed: float) -> void:
	_init_materials()
	var arrow: RigidBody3D = RigidBody3D.new()
	arrow.set_script(preload("res://src/player/arrow_body.gd"))
	arrow.add_to_group("arrow")
	arrow.contact_monitor = true
	arrow.max_contacts_reported = 1

	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = CapsuleShape3D.new()
	col.shape.height = 0.6
	col.shape.radius = 0.05
	col.rotation = Vector3(deg_to_rad(90), 0, 0)
	arrow.add_child(col)
	arrow.collision_mask = 1 | 2

	# Glowing shaft material — bright self-illumination, no light casting on ground
	var glow_shaft_mat: StandardMaterial3D = StandardMaterial3D.new()
	glow_shaft_mat.albedo_color = Color(0.6, 0.4, 0.2)
	glow_shaft_mat.roughness = 0.7
	glow_shaft_mat.emission_enabled = true
	glow_shaft_mat.emission = Color(0.4, 0.7, 1.0)
	glow_shaft_mat.emission_energy_multiplier = 3.0

	var shaft: MeshInstance3D = MeshInstance3D.new()
	shaft.mesh = CylinderMesh.new()
	shaft.mesh.top_radius = 0.035
	shaft.mesh.bottom_radius = 0.035
	shaft.mesh.height = 0.55
	shaft.mesh.material = glow_shaft_mat
	shaft.rotation = Vector3(deg_to_rad(90), 0, 0)
	arrow.add_child(shaft)

	# Glowing tip — bright self-illumination
	var glow_tip_mat: StandardMaterial3D = StandardMaterial3D.new()
	glow_tip_mat.albedo_color = Color(0.75, 0.8, 0.85)
	glow_tip_mat.metallic = 0.9
	glow_tip_mat.roughness = 0.2
	glow_tip_mat.emission_enabled = true
	glow_tip_mat.emission = Color(0.5, 0.8, 1.0)
	glow_tip_mat.emission_energy_multiplier = 4.0

	var tip: MeshInstance3D = MeshInstance3D.new()
	tip.mesh = CylinderMesh.new()
	tip.mesh.top_radius = 0.0
	tip.mesh.bottom_radius = 0.055
	tip.mesh.height = 0.15
	tip.mesh.material = glow_tip_mat
	tip.rotation = Vector3(deg_to_rad(90), 0, 0)
	tip.position = Vector3(0, 0, -0.35)
	arrow.add_child(tip)

	for i: int in 3:
		var holder: Node3D = Node3D.new()
		holder.rotation = Vector3(0, 0, deg_to_rad(i * 120))
		holder.position = Vector3(0, 0, 0.22)
		arrow.add_child(holder)

		var f: MeshInstance3D = MeshInstance3D.new()
		f.mesh = BoxMesh.new()
		(f.mesh as BoxMesh).size = Vector3(0.07, 0.01, 0.1)
		f.mesh.material = _fletch_mat
		f.position = Vector3(0.04, 0, 0)
		holder.add_child(f)

	var nock: MeshInstance3D = MeshInstance3D.new()
	nock.mesh = CylinderMesh.new()
	nock.mesh.top_radius = 0.05
	nock.mesh.bottom_radius = 0.05
	nock.mesh.height = 0.025
	nock.mesh.material = _nock_mat
	nock.rotation = Vector3(deg_to_rad(90), 0, 0)
	nock.position = Vector3(0, 0, 0.29)
	arrow.add_child(nock)

	parent.add_child(arrow)
	arrow.global_position = origin
	arrow.look_at(origin + direction, Vector3.UP)
	arrow.linear_velocity = direction * speed

	# Glowing trail — a smooth fading ribbon behind the arrow
	var trail: GPUParticles3D = GPUParticles3D.new()
	trail.amount = 50
	trail.lifetime = 0.8
	trail.emitting = true
	trail.explosiveness = 0.0
	trail.local_coords = false

	var trail_mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	trail_mat.direction = -direction
	trail_mat.spread = 2.0
	trail_mat.initial_velocity_min = 0.1
	trail_mat.initial_velocity_max = 0.5
	trail_mat.gravity = Vector3.ZERO
	trail_mat.scale_min = 0.11
	trail_mat.scale_max = 0.16
	trail_mat.angular_velocity_min = 0.0
	trail_mat.angular_velocity_max = 0.0

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.6, 0.85, 1.0, 1.0))
	gradient.add_point(0.15, Color(0.45, 0.7, 1.0, 0.95))
	gradient.add_point(0.35, Color(0.3, 0.5, 1.0, 0.75))
	gradient.add_point(0.6, Color(0.15, 0.25, 0.7, 0.4))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.05, 0.1, 0.3, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	trail_mat.color_ramp = grad_tex

	trail.process_material = trail_mat

	# Billboard quads make a smooth ribbon — wider than tall for a streak look
	var trail_qmesh := QuadMesh.new()
	trail_qmesh.size = Vector2(0.18, 0.04)
	trail_qmesh.material = null
	var trail_qm_mat := StandardMaterial3D.new()
	trail_qm_mat.albedo_color = Color(0.6, 0.85, 1.0, 1.0)
	trail_qm_mat.emission_enabled = true
	trail_qm_mat.emission = Color(0.4, 0.6, 1.0)
	trail_qm_mat.emission_energy_multiplier = 8.0
	trail_qm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_qm_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	trail_qm_mat.no_depth_test = true
	trail_qm_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	trail_qm_mat.billboard_keep_scale = true
	trail.draw_pass_1 = trail_qmesh
	trail.material_override = trail_qm_mat

	arrow.add_child(trail)

	var z_damage := 25
	arrow.body_entered.connect(func(body: Node):
		if body.is_in_group("zombie"):
			if body.has_method("take_damage"):
				body.take_damage(z_damage, true)
				EventBus.damage_dealt.emit(z_damage)
			AudioManager.play_arrow_hit()
			trail.emitting = false
			arrow.queue_free()
	)

	var timer: Timer = Timer.new()
	timer.wait_time = 5.0
	timer.one_shot = true
	timer.timeout.connect(func(): if is_instance_valid(arrow): arrow.queue_free())
	arrow.add_child(timer)
	timer.start()
