extends Node3D

const HALF_WORLD: float = 256.0

@export var world_gen: WorldGen

var _sun: DirectionalLight3D
var _day_time: float = 0.4

static var _tree_mesh_cache: Dictionary = {}

func _ready() -> void:
	_setup_atmosphere()
	_add_water()
	_add_chunk_manager()
	_scatter_trees()
	_scatter_foliage()

func _poisson_disk_sample(half_size: float, min_dist: float, rng_seed: int, max_attempts: int = 30) -> Array[Vector2]:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var radius := min_dist
	var cell_size := radius / sqrt(2.0)
	var grid_width := ceili(half_size * 2.0 / cell_size)
	var grid: Dictionary = {}
	var first := Vector2(rng.randf_range(-half_size, half_size), rng.randf_range(-half_size, half_size))
	var active: Array[Vector2] = [first]
	var points: Array[Vector2] = [first]
	var gx := floori((first.x + half_size) / cell_size)
	var gy := floori((first.y + half_size) / cell_size)
	grid[gx + gy * grid_width] = first
	while active.size() > 0:
		var idx := rng.randi_range(0, active.size() - 1)
		var pt := active[idx]
		var found := false
		for _attempt in max_attempts:
			var angle := rng.randf() * TAU
			var dist := rng.randf_range(radius, radius * 2.0)
			var cand := pt + Vector2(cos(angle), sin(angle)) * dist
			if abs(cand.x) > half_size or abs(cand.y) > half_size:
				continue
			var cx := floori((cand.x + half_size) / cell_size)
			var cy := floori((cand.y + half_size) / cell_size)
			var ok := true
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var key := (cx + dx) + (cy + dy) * grid_width
					if grid.has(key):
						if cand.distance_squared_to(grid[key]) < radius * radius:
							ok = false
							break
				if not ok:
					break
			if ok:
				grid[cx + cy * grid_width] = cand
				active.append(cand)
				points.append(cand)
				found = true
				break
		if not found:
			active.remove_at(idx)
	return points

func _terrain_slope(x: float, z: float) -> float:
	var step := 1.0
	var hx1 := world_gen.get_height(x + step, z)
	var hx2 := world_gen.get_height(x - step, z)
	var hz1 := world_gen.get_height(x, z + step)
	var hz2 := world_gen.get_height(x, z - step)
	var dx := (hx1 - hx2) / (step * 2.0)
	var dz := (hz1 - hz2) / (step * 2.0)
	return Vector2(dx, dz).length()

func _process(delta: float) -> void:
	_day_time += delta * 0.008
	if _day_time > 1.0:
		_day_time -= 1.0
	_update_sun()

func _update_sun() -> void:
	var weight: float = _day_time * 2.0 if _day_time < 0.5 else (1.0 - _day_time) * 2.0
	var angle: float = lerp(-15.0, 50.0, weight)
	_sun.rotation.x = deg_to_rad(angle)
	var intensity: float = clamp(sin(deg_to_rad(angle)) * 1.5, 0.15, 1.2)
	_sun.light_energy = intensity

func _setup_atmosphere() -> void:
	var env_node: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.3
	env.set_glow_level(0, 1.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 1.0)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0

	env.fog_enabled = false
	env.volumetric_fog_enabled = false

	env.tonemap_white = 2.0
	env.ambient_light_color = Color(0.5, 0.55, 0.7)
	env.ambient_light_energy = 0.4
	env.ambient_light_sky_contribution = 0.3

	env_node.environment = env
	add_child(env_node)

	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.05, 0.1, 0.25)
	sky_mat.sky_horizon_color = Color(0.25, 0.4, 0.7)
	sky_mat.ground_horizon_color = Color(0.4, 0.35, 0.25)
	sky_mat.ground_bottom_color = Color(0.2, 0.15, 0.1)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env_node.environment.background_mode = Environment.BG_SKY
	env_node.environment.background_sky = sky

	_sun = DirectionalLight3D.new()
	_sun.light_color = Color(1.0, 0.95, 0.85)
	_sun.light_energy = 1.0
	_sun.rotation = Vector3(deg_to_rad(30), deg_to_rad(45), 0)
	_sun.shadow_enabled = true
	_sun.shadow_bias = 0.05
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_blend_splits = true
	_sun.directional_shadow_max_distance = 80.0
	add_child(_sun)

	var amb: DirectionalLight3D = DirectionalLight3D.new()
	amb.light_color = Color(0.5, 0.55, 0.7)
	amb.light_energy = 0.25
	amb.rotation = Vector3(deg_to_rad(60), deg_to_rad(-30), 0)
	amb.shadow_enabled = false
	add_child(amb)

	_add_clouds()

func _add_clouds() -> void:
	var cloud_mat: ShaderMaterial = ShaderMaterial.new()
	cloud_mat.shader = preload("res://shaders/clouds.gdshader")
	cloud_mat.set_shader_parameter("cloud_density", 0.55)
	cloud_mat.set_shader_parameter("cloud_softness", 0.28)
	cloud_mat.set_shader_parameter("drift_speed", 0.04)

	var qm := QuadMesh.new()
	qm.size = Vector2(100.0, 50.0)
	qm.material = cloud_mat

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = qm
	mm.instance_count = 120

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 120:
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(30.0, HALF_WORLD * 1.8)
		var pos := Vector3(cos(angle) * dist, rng.randf_range(20.0, 60.0), sin(angle) * dist)
		var s := rng.randf_range(0.8, 2.0)
		var t := Transform3D.IDENTITY
		t.origin = pos
		t.basis = t.basis.scaled(Vector3(s, s, s))
		t.basis = t.basis.rotated(Vector3.UP, rng.randf() * TAU)
		t.basis = t.basis.rotated(t.basis.x.normalized(), rng.randf_range(-0.6, 0.6))
		t.basis = t.basis.rotated(t.basis.z.normalized(), rng.randf_range(-0.6, 0.6))
		mm.set_instance_transform(i, t)

	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "Clouds"
	add_child(mmi)

func _add_water() -> void:
	var water_mat := ShaderMaterial.new()
	water_mat.shader = preload("res://shaders/water.gdshader")

	var water: MeshInstance3D = MeshInstance3D.new()
	water.name = "Water"
	var water_mesh: PlaneMesh = PlaneMesh.new()
	water_mesh.size = Vector2(world_gen.world_size, world_gen.world_size)
	water_mesh.subdivide_width = 200
	water_mesh.subdivide_depth = 200
	water_mesh.material = water_mat
	water.mesh = water_mesh
	water.position.y = world_gen.water_level
	add_child(water)

func _add_chunk_manager() -> void:
	var cm := ChunkManager.new()
	cm.world_gen = world_gen
	add_child(cm)
	cm.generate_initial_chunks()

func _make_cylinder_segment(st: SurfaceTool, p0: Vector3, p1: Vector3, r0: float, r1: float, segments: int, col: Color) -> void:
	var dir := (p1 - p0).normalized()
	var up := Vector3.UP if abs(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var right := dir.cross(up).normalized()
	up = right.cross(dir).normalized()

	for i in segments:
		var a0 := float(i) / segments * TAU
		var a1 := float(i + 1) / segments * TAU
		var c0 := cos(a0); var s0 := sin(a0)
		var c1 := cos(a1); var s1 := sin(a1)

		var r0r := right * r0; var u0r := up * r0
		var r1r := right * r1; var u1r := up * r1

		var v0 := p0 + c0 * r0r + s0 * u0r
		var v1 := p0 + c1 * r0r + s1 * u0r
		var v2 := p1 + c0 * r1r + s0 * u1r
		var v3 := p1 + c1 * r1r + s1 * u1r

		var n := Vector3(c0, 0, s0)
		var n2 := Vector3(c1, 0, s1)

		for data in [
			[v0, n], [v1, n2], [v2, n],
			[v1, n2], [v3, n2], [v2, n],
		]:
			st.set_color(col)
			st.set_normal(data[1].normalized())
			st.set_uv(Vector2(0, 0))
			st.add_vertex(data[0])

func _add_leaf_cluster(st: SurfaceTool, center: Vector3, radius: float, count: int, leaf_col: Color) -> void:
	for ci in count:
		var angle := float(ci) / count * TAU + randf() * 0.2
		var pitch := randf_range(0.3, 1.5)
		var r := radius * randf_range(0.3, 1.0)
		var pos := center + Vector3(
			sin(angle) * pitch * r * 0.5,
			randf_range(-radius * 0.3, radius * 0.5),
			cos(angle) * pitch * r * 0.5
		)
		var sphere_r := radius * randf_range(0.15, 0.4)
		var rings := 3
		var segs := 6
		for ri in rings:
			var lat0 := float(ri) / rings * PI
			var lat1 := float(ri + 1) / rings * PI
			for j in segs:
				var lon0 := float(j) / segs * TAU
				var lon1 := float(j + 1) / segs * TAU
				for face in [
					[lat0, lon0, lat0, lon1, lat1, lon0],
					[lat0, lon1, lat1, lon1, lat1, lon0],
				]:
					var p := Vector3(
						sin(face[0]) * cos(face[1]) * sphere_r,
						cos(face[0]) * sphere_r,
						sin(face[0]) * sin(face[1]) * sphere_r
					) + pos
					var n := (p - pos).normalized()
					var p2 := Vector3(
						sin(face[2]) * cos(face[3]) * sphere_r,
						cos(face[2]) * sphere_r,
						sin(face[2]) * sin(face[3]) * sphere_r
					) + pos
					var n2 := (p2 - pos).normalized()
					var p3 := Vector3(
						sin(face[4]) * cos(face[5]) * sphere_r,
						cos(face[4]) * sphere_r,
						sin(face[4]) * sin(face[5]) * sphere_r
					) + pos
					var n3 := (p3 - pos).normalized()
					st.set_color(leaf_col); st.set_normal(n); st.set_uv(Vector2(0, 0)); st.add_vertex(p)
					st.set_color(leaf_col); st.set_normal(n2); st.set_uv(Vector2(0, 0)); st.add_vertex(p2)
					st.set_color(leaf_col); st.set_normal(n3); st.set_uv(Vector2(0, 0)); st.add_vertex(p3)

func _make_platform_branch_mesh(st: SurfaceTool, p0: Vector3, p1: Vector3, radius_h: float, radius_v: float, segments: int, col: Color) -> void:
	var dir := (p1 - p0).normalized()
	var up := Vector3.UP if abs(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var right := dir.cross(up).normalized()
	up = right.cross(dir).normalized()

	for i in segments:
		var a0 := float(i) / segments * TAU
		var a1 := float(i + 1) / segments * TAU
		var c0 := cos(a0); var s0 := sin(a0)
		var c1 := cos(a1); var s1 := sin(a1)

		var v0 := p0 + c0 * right * radius_h + s0 * up * radius_v
		var v1 := p0 + c1 * right * radius_h + s1 * up * radius_v
		var v2 := p1 + c0 * right * radius_h + s0 * up * radius_v
		var v3 := p1 + c1 * right * radius_h + s1 * up * radius_v

		var n0 := (c0 * right + s0 * up).normalized()
		var n1 := (c1 * right + s1 * up).normalized()

		for data in [
			[v0, n0], [v1, n1], [v2, n0],
			[v1, n1], [v3, n1], [v2, n0],
		]:
			st.set_color(col)
			st.set_normal(data[1])
			st.set_uv(Vector2(0, 0))
			st.add_vertex(data[0])

func _make_branch_platform_collision(origin: Vector3, direction: Vector3, length: float, width: float, height: float) -> Dictionary:
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, length)
	var t := Transform3D.IDENTITY
	t.origin = origin + direction * (length * 0.5)
	var up_hint := Vector3.UP
	if abs(direction.dot(Vector3.UP)) > 0.99:
		up_hint = Vector3.RIGHT
	t.basis = Basis.looking_at(direction, up_hint)
	return {"shape": box, "local_transform": t}

func _build_tree_platforms(st: SurfaceTool, trunk_origin: Vector3, tiers: Array, wood_col: Color, leaf_col: Color, rng_seed: int, collision_out: Array) -> int:
	for tier in tiers:
		var tier_y: float = tier["y"]
		var branch_count: int = tier["count"]
		var branch_length: float = tier["length"]
		var branch_width: float = tier["width"]

		for i in branch_count:
			var angle: float = float(i) / branch_count * TAU + (rng_seed % 1000) * 0.001
			rng_seed = (rng_seed * 1103515245 + 12345) & 0x7fffffff

			var horizontal_dir := Vector3(cos(angle), 0, sin(angle)).normalized()
			var branch_dir := (horizontal_dir + Vector3.UP * 0.12).normalized()

			var branch_origin := trunk_origin + Vector3(0, tier_y, 0)
			var branch_tip := branch_origin + branch_dir * branch_length

			_make_platform_branch_mesh(st, branch_origin, branch_tip, branch_width * 0.5, 0.3, 8, wood_col)
			collision_out.append(_make_branch_platform_collision(branch_origin, branch_dir, branch_length, branch_width, 0.5))

			_add_leaf_cluster(st, branch_tip, 1.5, 3, leaf_col)
	return rng_seed

func _make_tree_mesh_oak(wood_mat: StandardMaterial3D, leaf_mat: StandardMaterial3D, seed_offset: int) -> Dictionary:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var collision_data: Array = []
	var trunk_h := 16.0 + (seed_offset % 100) * 0.04
	var trunk_r := 1.2 + (seed_offset % 50) * 0.004
	var wood_col := wood_mat.albedo_color
	var leaf_col := leaf_mat.albedo_color

	_make_cylinder_segment(st, Vector3.ZERO, Vector3.UP * trunk_h, trunk_r, trunk_r * 0.7, 10, wood_col)

	var tiers: Array[Dictionary] = [
		{"y": 6.0, "count": 3, "length": 7.0, "width": 2.8},
		{"y": 10.0, "count": 3, "length": 6.0, "width": 2.5},
		{"y": 14.0, "count": 3, "length": 5.0, "width": 2.2},
	]
	_build_tree_platforms(st, Vector3.ZERO, tiers, wood_col, leaf_col, seed_offset, collision_data)

	_add_leaf_cluster(st, Vector3.UP * trunk_h, 4.0, 6, leaf_col)

	var trunk := CylinderShape3D.new()
	trunk.radius = trunk_r
	trunk.height = trunk_h
	collision_data.append({"shape": trunk, "local_transform": Transform3D.IDENTITY})

	var mesh := st.commit()
	wood_mat.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, wood_mat)
	return {"mesh": mesh, "collision": collision_data}

func _make_tree_mesh_pine(wood_mat: StandardMaterial3D, leaf_mat: StandardMaterial3D) -> Dictionary:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk_h := 25.0
	var trunk_r := 0.7
	var wood_col := wood_mat.albedo_color
	var leaf_col := leaf_mat.albedo_color
	var collision_data: Array = []

	_make_cylinder_segment(st, Vector3.ZERO, Vector3.UP * trunk_h, trunk_r, trunk_r * 0.3, 8, wood_col)

	var tiers: Array[Dictionary] = [
		{"y": 4.0, "count": 2, "length": 5.0, "width": 2.0},
		{"y": 9.0, "count": 3, "length": 5.0, "width": 2.0},
		{"y": 14.0, "count": 3, "length": 4.5, "width": 1.8},
		{"y": 19.0, "count": 2, "length": 4.0, "width": 1.6},
	]
	_build_tree_platforms(st, Vector3.ZERO, tiers, wood_col, leaf_col, 42, collision_data)

	var tiers_foliage := 6
	for ti in tiers_foliage:
		var ty := 3.0 + float(ti) / tiers_foliage * (trunk_h - 5.0)
		var t_radius := 2.0 + (1.0 - float(ti) / tiers_foliage) * 1.5
		var bottom_r := t_radius * 0.6
		var top_r := t_radius * 0.05
		var cone_h := 2.0 + (1.0 - float(ti) / tiers_foliage) * 1.0
		var sub_segs: int = mini(8 + ti * 2, 14)
		for j in sub_segs:
			var a0 := float(j) / sub_segs * TAU
			var a1 := float(j + 1) / sub_segs * TAU
			var c0 := cos(a0); var s0 := sin(a0)
			var c1 := cos(a1); var s1 := sin(a1)
			var p0 := Vector3(c0 * bottom_r, ty, s0 * bottom_r)
			var p1 := Vector3(c1 * bottom_r, ty, s1 * bottom_r)
			var p2 := Vector3(c0 * top_r, ty + cone_h, s0 * top_r)
			var p3 := Vector3(c1 * top_r, ty + cone_h, s1 * top_r)
			var n0 := Vector3(c0, 0.3, s0).normalized()
			var n1 := Vector3(c1, 0.3, s1).normalized()
			for data in [[p0, n0], [p1, n1], [p2, n0],
						 [p1, n1], [p3, n1], [p2, n0]]:
				st.set_color(leaf_col); st.set_normal(data[1]); st.set_uv(Vector2(0, 0)); st.add_vertex(data[0])

	var trunk := CylinderShape3D.new()
	trunk.radius = trunk_r
	trunk.height = trunk_h
	collision_data.append({"shape": trunk, "local_transform": Transform3D.IDENTITY})

	var mesh := st.commit()
	wood_mat.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, wood_mat)
	return {"mesh": mesh, "collision": collision_data}

func _make_tree_mesh_swamp(wood_mat: StandardMaterial3D, leaf_mat: StandardMaterial3D, seed_offset: int) -> Dictionary:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng: Array = [seed_offset + 999]
	var trunk_h: float = 12.0 + (rng[0] % 200) * 0.03
	var trunk_r := 0.8
	var collision_data: Array = []
	var wood_col := wood_mat.albedo_color
	var leaf_col := leaf_mat.albedo_color
	var num_segs := 7
	var bend_x := 0.0
	var bend_z := 0.0

	for i in num_segs:
		bend_x = sin(float(i) * 1.3) * 0.6
		bend_z = cos(float(i) * 1.3) * 0.6
		var seg_start := Vector3(0, float(i) / num_segs * trunk_h, 0)
		var seg_end := Vector3(bend_x * 0.15, float(i + 1) / num_segs * trunk_h, bend_z * 0.15)
		_make_cylinder_segment(st, seg_start, seg_end,
			trunk_r * (1.0 - float(i) / num_segs * 0.4),
			trunk_r * (1.0 - float(i + 1) / num_segs * 0.4),
			7, wood_col)

		var seg_len := seg_start.distance_to(seg_end)
		var seg_radius := trunk_r * (1.0 - float(i) / num_segs * 0.4)
		var seg := CylinderShape3D.new()
		seg.radius = seg_radius
		seg.height = seg_len
		var seg_center := (seg_start + seg_end) * 0.5
		var seg_dir := (seg_end - seg_start).normalized()
		var seg_t := Transform3D.IDENTITY
		seg_t.origin = seg_center
		var look_target := seg_center + seg_dir
		var up_hint := Vector3.UP
		if abs(seg_dir.dot(Vector3.UP)) > 0.99:
			up_hint = Vector3.RIGHT
		seg_t.basis = Basis.looking_at(look_target - seg_center, up_hint)
		collision_data.append({"shape": seg, "local_transform": seg_t})

	var top_pos := Vector3(bend_x * 0.15, trunk_h, bend_z * 0.15)

	var tiers: Array[Dictionary] = [
		{"y": 4.0, "count": 2, "length": 5.0, "width": 2.0},
		{"y": 8.0, "count": 2, "length": 4.5, "width": 2.0},
	]
	_build_tree_platforms(st, Vector3.ZERO, tiers, wood_col, leaf_col, rng[0], collision_data)

	_add_leaf_cluster(st, top_pos, 2.5, 5, leaf_col)
	_add_leaf_cluster(st, top_pos + Vector3(0.8, -0.5, 0.8), 1.8, 4, leaf_col)

	var mesh := st.commit()
	wood_mat.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, wood_mat)
	return {"mesh": mesh, "collision": collision_data}

func _make_tree_mesh_banyan(wood_mat: StandardMaterial3D, leaf_mat: StandardMaterial3D, seed_offset: int) -> Dictionary:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var collision_data: Array = []
	var trunk_h := 8.0 + (seed_offset % 100) * 0.02
	var trunk_r := 1.0 + (seed_offset % 50) * 0.004
	var wood_col := wood_mat.albedo_color
	var leaf_col := leaf_mat.albedo_color

	_make_cylinder_segment(st, Vector3.ZERO, Vector3.UP * trunk_h, trunk_r, trunk_r * 0.8, 10, wood_col)

	var root_cols := 4
	for i in root_cols:
		var angle := float(i) / root_cols * TAU
		var root_pos := Vector3(cos(angle) * trunk_r * 2.5, 0, sin(angle) * trunk_r * 2.5)
		var root_top := Vector3(cos(angle) * trunk_r * 1.5, trunk_h * 0.6, sin(angle) * trunk_r * 1.5)
		_make_cylinder_segment(st, root_pos, root_top, 0.15, 0.1, 5, wood_col)
		var root_len := root_pos.distance_to(root_top)
		var root_seg := CylinderShape3D.new()
		root_seg.radius = 0.12
		root_seg.height = root_len
		var root_center := (root_pos + root_top) * 0.5
		var root_dir := (root_top - root_pos).normalized()
		var root_t := Transform3D.IDENTITY
		root_t.origin = root_center
		var root_look := root_center + root_dir
		var root_up := Vector3.UP
		if abs(root_dir.dot(Vector3.UP)) > 0.99:
			root_up = Vector3.RIGHT
		root_t.basis = Basis.looking_at(root_look - root_center, root_up)
		collision_data.append({"shape": root_seg, "local_transform": root_t})

	var tiers: Array[Dictionary] = [
		{"y": 3.0, "count": 3, "length": 8.0, "width": 3.0},
		{"y": 6.0, "count": 3, "length": 7.0, "width": 2.8},
	]
	_build_tree_platforms(st, Vector3.ZERO, tiers, wood_col, leaf_col, seed_offset, collision_data)

	_add_leaf_cluster(st, Vector3.UP * trunk_h, 5.0, 7, leaf_col)

	var trunk := CylinderShape3D.new()
	trunk.radius = trunk_r
	trunk.height = trunk_h
	collision_data.append({"shape": trunk, "local_transform": Transform3D.IDENTITY})

	var mesh := st.commit()
	wood_mat.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, wood_mat)
	return {"mesh": mesh, "collision": collision_data}

func _scatter_trees() -> void:
	var wood_oak: StandardMaterial3D = StandardMaterial3D.new()
	wood_oak.albedo_color = Color(0.4, 0.25, 0.12)
	wood_oak.roughness = 0.8
	var leaf_oak_mat: StandardMaterial3D = StandardMaterial3D.new()
	leaf_oak_mat.albedo_color = Color(0.12, 0.38, 0.1)
	leaf_oak_mat.roughness = 0.9

	var wood_pine: StandardMaterial3D = StandardMaterial3D.new()
	wood_pine.albedo_color = Color(0.35, 0.2, 0.08)
	wood_pine.roughness = 0.85
	var leaf_pine_mat: StandardMaterial3D = StandardMaterial3D.new()
	leaf_pine_mat.albedo_color = Color(0.08, 0.25, 0.06)
	leaf_pine_mat.roughness = 0.9

	var wood_swamp: StandardMaterial3D = StandardMaterial3D.new()
	wood_swamp.albedo_color = Color(0.2, 0.15, 0.08)
	wood_swamp.roughness = 0.85
	var leaf_swamp_mat: StandardMaterial3D = StandardMaterial3D.new()
	leaf_swamp_mat.albedo_color = Color(0.08, 0.2, 0.06)
	leaf_swamp_mat.roughness = 0.95

	var wood_banyan: StandardMaterial3D = StandardMaterial3D.new()
	wood_banyan.albedo_color = Color(0.3, 0.22, 0.1)
	wood_banyan.roughness = 0.85
	var leaf_banyan_mat: StandardMaterial3D = StandardMaterial3D.new()
	leaf_banyan_mat.albedo_color = Color(0.1, 0.35, 0.08)
	leaf_banyan_mat.roughness = 0.9

	var seed_base := world_gen.seed_value

	var oak_key := "oak_%d" % seed_base
	var oak_data: Dictionary
	if _tree_mesh_cache.has(oak_key):
		oak_data = _tree_mesh_cache[oak_key]
	else:
		oak_data = _make_tree_mesh_oak(wood_oak, leaf_oak_mat, seed_base)
		_tree_mesh_cache[oak_key] = oak_data

	var pine_key := "pine_%d" % seed_base
	var pine_data: Dictionary
	if _tree_mesh_cache.has(pine_key):
		pine_data = _tree_mesh_cache[pine_key]
	else:
		pine_data = _make_tree_mesh_pine(wood_pine, leaf_pine_mat)
		_tree_mesh_cache[pine_key] = pine_data

	var swamp_key := "swamp_%d" % (seed_base + 2000)
	var swamp_data: Dictionary
	if _tree_mesh_cache.has(swamp_key):
		swamp_data = _tree_mesh_cache[swamp_key]
	else:
		swamp_data = _make_tree_mesh_swamp(wood_swamp, leaf_swamp_mat, seed_base + 2000)
		_tree_mesh_cache[swamp_key] = swamp_data

	var banyan_key := "banyan_%d" % (seed_base + 3000)
	var banyan_data: Dictionary
	if _tree_mesh_cache.has(banyan_key):
		banyan_data = _tree_mesh_cache[banyan_key]
	else:
		banyan_data = _make_tree_mesh_banyan(wood_banyan, leaf_banyan_mat, seed_base + 3000)
		_tree_mesh_cache[banyan_key] = banyan_data

	var max_slope := 0.5
	var half := HALF_WORLD - 2.0
	var all_points := _poisson_disk_sample(half, 22.0, world_gen.seed_value + 999)

	var tree_rng := RandomNumberGenerator.new()
	tree_rng.seed = world_gen.seed_value + 1000

	var tree_buckets: Array[Array] = [[], [], [], []]
	var tree_biomes: Array[Array] = [
		[world_gen.Biome.MEADOWS],
		[world_gen.Biome.BLACK_FOREST, world_gen.Biome.MOUNTAIN],
		[world_gen.Biome.SWAMP],
		[world_gen.Biome.MEADOWS],
	]
	var tree_scales: Array[Vector2] = [
		Vector2(1.0, 1.8),
		Vector2(0.8, 1.4),
		Vector2(1.0, 1.6),
		Vector2(1.0, 1.5),
	]
	var tree_spawn_chances: Array[float] = [0.35, 0.35, 0.35, 0.15]

	for p in all_points:
		var px := p.x
		var pz := p.y
		var h := world_gen.get_height(px, pz)
		if h < 0.1:
			continue
		if _terrain_slope(px, pz) > max_slope:
			continue
		var biome := world_gen.get_biome(px, pz)
		var forest := world_gen.get_forest(px, pz)

		for ti in 4:
			if biome in tree_biomes[ti]:
				var threshold := 0.25 if biome == world_gen.Biome.SWAMP else 0.3
				if forest > threshold and tree_rng.randf() < tree_spawn_chances[ti]:
					var sh := world_gen.get_height(px, pz)
					var t := Transform3D.IDENTITY
					var s := tree_scales[ti].x + tree_rng.randf() * (tree_scales[ti].y - tree_scales[ti].x)
					t.origin = Vector3(px, sh, pz)
					t.basis = t.basis.scaled(Vector3(s, s, s))
					t.basis = t.basis.rotated(Vector3.UP, tree_rng.randf() * TAU)
					tree_buckets[ti].append(t)
				break

	var tree_datas := [oak_data, pine_data, swamp_data, banyan_data]
	for ti in 4:
		var positions := tree_buckets[ti]
		if positions.size() == 0:
			continue
		var data: Dictionary = tree_datas[ti]
		var mesh: ArrayMesh = data["mesh"]
		var collision: Array = data["collision"]
		for pos in positions:
			var tree := InteractableTree.new()
			tree.setup(mesh, collision, pos, ti)
			add_child(tree)

func _make_grass_mesh() -> ArrayMesh:
	# 3 intersecting blades with vertex color gradient (dark base -> light tip)
	# and a slight curve via an intermediate row
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w_bot := 0.08
	var w_mid := 0.045
	var w_top := 0.012
	var h := 0.6
	var lean := 0.06  # horizontal offset for curve
	var dark_base := Color(0.15, 0.45, 0.08)
	var dark_mid := Color(0.2, 0.55, 0.1)
	var light_tip := Color(0.35, 0.7, 0.15)
	for i in 3:
		var angle := float(i) / 3.0 * TAU
		var perp := Vector3(-cos(angle), 0.0, sin(angle))
		var lean_dir := Vector3(cos(angle + 1.0), 0.0, sin(angle + 1.0)).normalized() * lean
		# Bottom row
		var b0 := -perp * w_bot * 0.5
		var b1 := perp * w_bot * 0.5
		# Middle row (slightly offset for curve)
		var m0 := -perp * w_mid * 0.5 + lean_dir * 0.5 + Vector3(0.0, h * 0.5, 0.0)
		var m1 := perp * w_mid * 0.5 + lean_dir * 0.5 + Vector3(0.0, h * 0.5, 0.0)
		# Top row
		var t0 := -perp * w_top * 0.5 + lean_dir + Vector3(0.0, h, 0.0)
		var t1 := perp * w_top * 0.5 + lean_dir + Vector3(0.0, h, 0.0)
		var n := Vector3(sin(angle), 0.0, cos(angle))
		# Bottom quad (base -> mid)
		for data in [[b0, dark_base, n], [b1, dark_base, n], [m0, dark_mid, n],
					 [b1, dark_base, n], [m1, dark_mid, n], [m0, dark_mid, n]]:
			st.set_color(data[1])
			st.set_normal(data[2])
			st.set_uv(Vector2(0, 0))
			st.add_vertex(data[0])
		# Top quad (mid -> tip)
		for data in [[m0, dark_mid, n], [m1, dark_mid, n], [t0, light_tip, n],
					 [m1, dark_mid, n], [t1, light_tip, n], [t0, light_tip, n]]:
			st.set_color(data[1])
			st.set_normal(data[2])
			st.set_uv(Vector2(0, 0))
			st.add_vertex(data[0])
	return st.commit()

func _add_sphere_cluster(st: SurfaceTool, center: Vector3, r: float, col_base: Color, col_top: Color) -> void:
	for ri in 3:
		var lat0 := float(ri) / 3.0 * PI
		var lat1 := float(ri + 1) / 3.0 * PI
		for j in 6:
			var lon0 := float(j) / 6.0 * TAU
			var lon1 := float(j + 1) / 6.0 * TAU
			for face in [
				[lat0, lon0, lat0, lon1, lat1, lon0],
				[lat0, lon1, lat1, lon1, lat1, lon0],
			]:
				var v0 := Vector3(sin(face[0]) * cos(face[1]), cos(face[0]), sin(face[0]) * sin(face[1])) * r + center
				var v1 := Vector3(sin(face[2]) * cos(face[3]), cos(face[2]), sin(face[2]) * sin(face[3])) * r + center
				var v2 := Vector3(sin(face[4]) * cos(face[5]), cos(face[4]), sin(face[4]) * sin(face[5])) * r + center
				var n0 := (v0 - center).normalized()
				var n1 := (v1 - center).normalized()
				var n2 := (v2 - center).normalized()
				var avg_y := (v0.y + v1.y + v2.y) / 3.0
				var t: float = clamp((avg_y - (center.y - r)) / (r * 2.0), 0.0, 1.0)
				var col := col_base.lerp(col_top, t)
				st.set_color(col); st.set_normal(n0); st.set_uv(Vector2(0, 0)); st.add_vertex(v0)
				st.set_color(col); st.set_normal(n1); st.set_uv(Vector2(0, 0)); st.add_vertex(v1)
				st.set_color(col); st.set_normal(n2); st.set_uv(Vector2(0, 0)); st.add_vertex(v2)

func _make_bush_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 5 leaf cluster spheres at varied positions for organic shape
	var cluster_data: Array[Array] = [
		[Vector3(0.0, 0.40, 0.0), 0.35],       # main center
		[Vector3(0.20, 0.48, 0.10), 0.26],      # upper right
		[Vector3(-0.14, 0.44, -0.16), 0.24],    # upper left-back
		[Vector3(0.08, 0.36, -0.14), 0.20],     # lower back
		[Vector3(-0.10, 0.50, 0.14), 0.22],     # upper left-front
	]
	var col_base := Color(0.12, 0.32, 0.08)
	var col_top := Color(0.22, 0.48, 0.14)
	for cd in cluster_data:
		_add_sphere_cluster(st, cd[0], cd[1], col_base, col_top)

	# Small trunk/stem at base
	var trunk_col := Color(0.3, 0.2, 0.1)
	var trunk_top := Color(0.25, 0.18, 0.09)
	_make_cylinder_segment(st, Vector3(0.0, 0.0, 0.0), Vector3(0.03, 0.20, 0.02), 0.05, 0.035, 4, trunk_col)
	_make_cylinder_segment(st, Vector3(0.03, 0.20, 0.02), Vector3(-0.02, 0.34, -0.03), 0.035, 0.025, 4, trunk_top)

	return st.commit()

func _make_flower_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stem_h := 0.38
	var stem_col := Color(0.15, 0.4, 0.1)
	var stem_top_col := Color(0.2, 0.5, 0.12)

	# Stem (2 segments for slight curve)
	_make_cylinder_segment(st, Vector3(0.0, 0.0, 0.0), Vector3(0.015, stem_h * 0.5, 0.008), 0.014, 0.012, 4, stem_col)
	_make_cylinder_segment(st, Vector3(0.015, stem_h * 0.5, 0.008), Vector3(0.0, stem_h, 0.0), 0.012, 0.008, 4, stem_top_col)

	# Small leaf on stem (one side)
	var leaf_col := Color(0.18, 0.45, 0.1)
	var leaf_n := Vector3(0.0, 0.0, 1.0)
	var leaf_y := stem_h * 0.4
	var leaf_hw := 0.04
	var leaf_hh := 0.05
	for v in [
		Vector3(0.0, leaf_y, 0.0),
		Vector3(leaf_hw * 2, leaf_y, 0.0),
		Vector3(leaf_hw, leaf_y + leaf_hh, 0.0),
	]:
		st.set_color(leaf_col); st.set_normal(leaf_n); st.set_uv(Vector2(0, 0)); st.add_vertex(v)

	# 5 petals arranged in a ring, angled outward
	var petal_col := Color(0.85, 0.25, 0.35)
	var petal_tip := Color(0.95, 0.4, 0.5)
	var petal_len := 0.09
	var petal_w := 0.04
	var petal_spread := 0.3  # outward tilt
	for i in 5:
		var a := float(i) / 5.0 * TAU
		var dir := Vector3(cos(a), 0.0, sin(a))
		var tip_pos := Vector3(cos(a) * petal_len, stem_h + 0.02, sin(a) * petal_len) + dir * petal_spread * 0.3
		var center_pos := Vector3(0.0, stem_h, 0.0)
		var side := Vector3(-sin(a), 0.0, cos(a))
		var v0 := center_pos - side * petal_w * 0.5
		var v1 := center_pos + side * petal_w * 0.5
		var v2 := tip_pos
		var n := Vector3(cos(a), 0.5, sin(a)).normalized()
		for data in [[v0, petal_col], [v1, petal_col], [v2, petal_tip]]:
			st.set_color(data[1]); st.set_normal(n); st.set_uv(Vector2(0, 0)); st.add_vertex(data[0])

	# Center disk (2 triangles forming a small quad)
	var center_col := Color(0.95, 0.85, 0.15)
	var c0 := Vector3(0.0, stem_h + 0.008, 0.0)
	var ch := 0.02
	for i in 4:
		var a0 := float(i) / 4.0 * TAU
		var a1 := float(i + 1) / 4.0 * TAU
		var p0 := c0 + Vector3(cos(a0), 0.0, sin(a0)) * ch
		var p1 := c0 + Vector3(cos(a1), 0.0, sin(a1)) * ch
		st.set_color(center_col); st.set_normal(Vector3.UP); st.set_uv(Vector2(0, 0)); st.add_vertex(c0)
		st.set_color(center_col); st.set_normal(Vector3.UP); st.set_uv(Vector2(0, 0)); st.add_vertex(p0)
		st.set_color(center_col); st.set_normal(Vector3.UP); st.set_uv(Vector2(0, 0)); st.add_vertex(p1)

	return st.commit()

func _make_mushroom_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Stem - short thick cylinder
	var stem_col := Color(0.85, 0.8, 0.7)
	var stem_top := Color(0.8, 0.75, 0.65)
	_make_cylinder_segment(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.14, 0.0), 0.035, 0.025, 5, stem_col)
	_make_cylinder_segment(st, Vector3(0.0, 0.14, 0.0), Vector3(0.008, 0.22, 0.0), 0.025, 0.020, 5, stem_top)

	# Cap - hemisphere (top half of sphere)
	var cap_col := Color(0.55, 0.15, 0.1)
	var cap_light := Color(0.65, 0.2, 0.12)
	var cap_center := Vector3(0.008, 0.22, 0.0)
	var cap_r := 0.10
	for ri in 4:
		var lat0 := float(ri) / 8.0 * PI  # only top half
		var lat1 := float(ri + 1) / 8.0 * PI
		for j in 6:
			var lon0 := float(j) / 6.0 * TAU
			var lon1 := float(j + 1) / 6.0 * TAU
			for face in [
				[lat0, lon0, lat0, lon1, lat1, lon0],
				[lat0, lon1, lat1, lon1, lat1, lon0],
			]:
				var v0 := Vector3(sin(face[0]) * cos(face[1]), cos(face[0]), sin(face[0]) * sin(face[1])) * cap_r + cap_center
				var v1 := Vector3(sin(face[2]) * cos(face[3]), cos(face[2]), sin(face[2]) * sin(face[3])) * cap_r + cap_center
				var v2 := Vector3(sin(face[4]) * cos(face[5]), cos(face[4]), sin(face[4]) * sin(face[5])) * cap_r + cap_center
				var n0 := (v0 - cap_center).normalized()
				var n1 := (v1 - cap_center).normalized()
				var n2 := (v2 - cap_center).normalized()
				# Brighter on top
				var avg_y := (v0.y + v1.y + v2.y) / 3.0
				var t: float = clamp((avg_y - cap_center.y) / cap_r, 0.0, 1.0)
				var col := cap_col.lerp(cap_light, t)
				st.set_color(col); st.set_normal(n0); st.set_uv(Vector2(0, 0)); st.add_vertex(v0)
				st.set_color(col); st.set_normal(n1); st.set_uv(Vector2(0, 0)); st.add_vertex(v1)
				st.set_color(col); st.set_normal(n2); st.set_uv(Vector2(0, 0)); st.add_vertex(v2)

	# Bottom cap disk (flat underside)
	var underside := Color(0.8, 0.75, 0.65)
	for i in 6:
		var a0 := float(i) / 6.0 * TAU
		var a1 := float(i + 1) / 6.0 * TAU
		var p0 := cap_center + Vector3(cos(a0), 0.0, sin(a0)) * cap_r
		var p1 := cap_center + Vector3(cos(a1), 0.0, sin(a1)) * cap_r
		st.set_color(underside); st.set_normal(Vector3.DOWN); st.set_uv(Vector2(0, 0)); st.add_vertex(cap_center)
		st.set_color(underside); st.set_normal(Vector3.DOWN); st.set_uv(Vector2(0, 0)); st.add_vertex(p0)
		st.set_color(underside); st.set_normal(Vector3.DOWN); st.set_uv(Vector2(0, 0)); st.add_vertex(p1)

	return st.commit()

func _scatter_foliage() -> void:
	var fol_mat: ShaderMaterial = ShaderMaterial.new()
	fol_mat.shader = preload("res://shaders/wind_foliage.gdshader")
	fol_mat.set_shader_parameter("color_tint", Color.WHITE)
	fol_mat.set_shader_parameter("turbulence", 0.6)

	var grass_mesh := _make_grass_mesh()
	var bush_mesh := _make_bush_mesh()
	var flower_mesh := _make_flower_mesh()
	var mushroom_mesh := _make_mushroom_mesh()

	var rng := RandomNumberGenerator.new()
	rng.seed = world_gen.seed_value + 5000

	var grass_transforms: Array[Transform3D] = []
	var grass_colors: Array[Color] = []
	var bush_transforms: Array[Transform3D] = []
	var bush_colors: Array[Color] = []
	var flower_transforms: Array[Transform3D] = []
	var flower_colors: Array[Color] = []
	var mushroom_transforms: Array[Transform3D] = []
	var mushroom_colors: Array[Color] = []

	var half := HALF_WORLD - 2.0
	for _attempt in 18000:
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		var h := world_gen.get_height(x, z)
		if h < 0.1:
			continue
		if _terrain_slope(x, z) > 0.6:
			continue
		var biome := world_gen.get_biome(x, z)
		if biome == world_gen.Biome.OCEAN:
			continue
		var forest := world_gen.get_forest(x, z)
		var r := rng.randf()
		var bc := world_gen.biome_color(biome, x, z, h)

		match biome:
			world_gen.Biome.MEADOWS:
				if r < 0.40:
					var col := Color(bc.r * rng.randf_range(0.7, 1.3), bc.g * rng.randf_range(0.7, 1.3), bc.b * rng.randf_range(0.7, 1.3), 1.0)
					_add_foliage_point(grass_transforms, grass_colors, x, h, z, rng, col)
				elif r < 0.46:
					var brights := [Color(1.0, 0.9, 0.2), Color(1.0, 0.3, 0.3), Color(0.4, 0.5, 1.0), Color(1.0, 0.5, 0.8), Color(1.0, 1.0, 1.0)]
					_add_foliage_point(flower_transforms, flower_colors, x, h, z, rng, brights[rng.randi() % brights.size()])
				elif r < 0.49:
					_add_foliage_point(mushroom_transforms, mushroom_colors, x, h, z, rng, Color.WHITE)

			world_gen.Biome.BLACK_FOREST:
				if forest > 0.3 and r < 0.22:
					var col := Color(bc.r * rng.randf_range(0.8, 1.2), bc.g * rng.randf_range(0.8, 1.2), bc.b * rng.randf_range(0.8, 1.2), 1.0)
					_add_foliage_point(grass_transforms, grass_colors, x, h, z, rng, col)
				elif r < 0.30:
					var col := Color(bc.r * rng.randf_range(0.8, 1.2), bc.g * rng.randf_range(0.8, 1.2), bc.b * rng.randf_range(0.8, 1.2), 1.0)
					_add_foliage_point(bush_transforms, bush_colors, x, h, z, rng, col)
				elif r < 0.34:
					_add_foliage_point(mushroom_transforms, mushroom_colors, x, h, z, rng, Color.WHITE)

			world_gen.Biome.SWAMP:
				if r < 0.10:
					var col := Color(bc.r * rng.randf_range(0.8, 1.2), bc.g * rng.randf_range(0.8, 1.2), bc.b * rng.randf_range(0.8, 1.2), 1.0)
					_add_foliage_point(bush_transforms, bush_colors, x, h, z, rng, col)
				elif r < 0.14:
					_add_foliage_point(mushroom_transforms, mushroom_colors, x, h, z, rng, Color(0.7, 0.9, 0.7))

			world_gen.Biome.MOUNTAIN:
				if r < 0.05 and h < 3.0:
					var col := Color(bc.r * rng.randf_range(0.7, 1.3), bc.g * rng.randf_range(0.7, 1.3), bc.b * rng.randf_range(0.7, 1.3), 1.0)
					_add_foliage_point(grass_transforms, grass_colors, x, h, z, rng, col)

	_build_foliage_multimesh(grass_mesh, fol_mat, grass_transforms, grass_colors, "Grass")
	_build_foliage_multimesh(bush_mesh, fol_mat, bush_transforms, bush_colors, "Bushes")
	_build_foliage_multimesh(flower_mesh, fol_mat, flower_transforms, flower_colors, "Flowers")
	_build_foliage_multimesh(mushroom_mesh, fol_mat, mushroom_transforms, mushroom_colors, "Mushrooms")

func _add_foliage_point(transforms: Array[Transform3D], colors: Array[Color], x: float, h: float, z: float, rng: RandomNumberGenerator, col: Color) -> void:
	var t := Transform3D.IDENTITY
	t.origin = Vector3(x, h, z)
	t.basis = t.basis.scaled(Vector3(rng.randf_range(0.8, 1.8), rng.randf_range(0.8, 1.8), rng.randf_range(0.8, 1.8)))
	t.basis = t.basis.rotated(Vector3.UP, rng.randf() * TAU)
	transforms.append(t)
	colors.append(col)

func _build_foliage_multimesh(mesh: ArrayMesh, material: ShaderMaterial, transforms: Array[Transform3D], colors: Array[Color], label: String) -> void:
	if transforms.is_empty():
		return
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = label
	mmi.material_override = material
	add_child(mmi)
