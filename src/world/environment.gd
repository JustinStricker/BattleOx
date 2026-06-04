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

func _poisson_disk_sample(half_size: float, min_dist: float, seed: int, max_attempts: int = 30) -> Array[Vector2]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
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
	var h := world_gen.get_height(x, z)
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

func _build_tree_branched(st: SurfaceTool, origin: Vector3, dir: Vector3, length: float, thickness: float, depth: int, wood_col: Color, leaf_col: Color, rng: Array) -> void:
	var end := origin + dir * length
	_make_cylinder_segment(st, origin, end, thickness, thickness * 0.6, 5, wood_col)

	if depth <= 0:
		_add_leaf_cluster(st, end, length * 0.5, 3, leaf_col)
		return

	var rng_seed: int = rng[0]
	var num_branches: int = rng_seed % 2 + 2
	rng_seed = (rng_seed * 1103515245 + 12345) & 0x7fffffff

	for i in num_branches:
		var b_angle: float = float(i) / num_branches * TAU + (rng_seed % 1000) * 0.001
		rng_seed = (rng_seed * 1103515245 + 12345) & 0x7fffffff
		var b_pitch: float = 0.4 + (rng_seed % 1000) * 0.0006
		rng_seed = (rng_seed * 1103515245 + 12345) & 0x7fffffff
		var b_len: float = length * (0.5 + (rng_seed % 1000) * 0.0003)
		rng_seed = (rng_seed * 1103515245 + 12345) & 0x7fffffff
		var b_thick: float = thickness * (0.35 + (rng_seed % 1000) * 0.00025)

		var up_ref := Vector3.UP if abs(dir.y) < 0.9 else Vector3.RIGHT
		var right := dir.cross(up_ref).normalized()
		var forward := right.cross(dir).normalized()

		var new_dir: Vector3 = (dir * 0.6 + right * sin(b_angle) * b_pitch + forward * cos(b_angle) * b_pitch).normalized()
		_build_tree_branched(st, end, new_dir, b_len, b_thick, depth - 1, wood_col, leaf_col, rng)
	rng[0] = rng_seed

func _make_tree_mesh_oak(wood_mat: StandardMaterial3D, leaf_mat: StandardMaterial3D, seed_offset: int) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng: Array = [seed_offset]
	_build_tree_branched(st, Vector3.ZERO, Vector3.UP, 4.0 + (seed_offset % 100) * 0.01, 0.25 + (seed_offset % 50) * 0.002, 3, wood_mat.albedo_color, leaf_mat.albedo_color, rng)
	var mesh := st.commit()
	wood_mat.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, wood_mat)
	return mesh

func _make_tree_mesh_pine(wood_mat: StandardMaterial3D, leaf_mat: StandardMaterial3D) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk_h := 6.0
	var trunk_r := 0.15
	var segs := 6
	var trunk_col := wood_mat.albedo_color
	var leaf_col := leaf_mat.albedo_color

	for i in segs:
		var a0 := float(i) / segs * TAU
		var a1 := float(i + 1) / segs * TAU
		var c0 := cos(a0); var s0 := sin(a0)
		var c1 := cos(a1); var s1 := sin(a1)
		var bot := Vector3(c0 * trunk_r, 0, s0 * trunk_r)
		var bot2 := Vector3(c1 * trunk_r, 0, s1 * trunk_r)
		var top := Vector3(c0 * trunk_r * 0.3, trunk_h, s0 * trunk_r * 0.3)
		var top2 := Vector3(c1 * trunk_r * 0.3, trunk_h, s1 * trunk_r * 0.3)
		var n := Vector3(c0, 0, s0).normalized()
		var n2 := Vector3(c1, 0, s1).normalized()
		for data in [[bot, n], [bot2, n2], [top, n],
					 [bot2, n2], [top2, n2], [top, n]]:
			st.set_color(trunk_col); st.set_normal(data[1]); st.set_uv(Vector2(0, 0)); st.add_vertex(data[0])

	var tiers := 4
	for ti in tiers:
		var ty := 1.0 + float(ti) / tiers * (trunk_h - 1.5)
		var t_radius := 0.8 + (1.0 - float(ti) / tiers) * 0.6
		var bottom_r := t_radius * 0.6
		var top_r := t_radius * 0.05
		var cone_h := 0.8 + (1.0 - float(ti) / tiers) * 0.4

		var sub_segs: int = mini(6 + ti * 2, 10)
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

	var mesh := st.commit()
	wood_mat.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, wood_mat)
	return mesh

func _make_tree_mesh_swamp(wood_mat: StandardMaterial3D, leaf_mat: StandardMaterial3D, seed_offset: int) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng: Array = [seed_offset + 999]

	var trunk_h: float = 3.0 + (rng[0] % 200) * 0.01
	var trunk_r := 0.12
	var bend_x: float = 0.0
	var bend_z: float = 0.0
	for i in 5:
		bend_x = sin(float(i) * 1.3) * 0.3
		bend_z = cos(float(i) * 1.3) * 0.3
		_make_cylinder_segment(st,
			Vector3(0, float(i) / 5 * trunk_h, 0),
			Vector3(bend_x * 0.1, float(i + 1) / 5 * trunk_h, bend_z * 0.1),
			trunk_r * (1.0 - float(i) / 5 * 0.5),
			trunk_r * (1.0 - float(i + 1) / 5 * 0.5),
			5, wood_mat.albedo_color)

	var top_pos := Vector3(bend_x * 0.1, trunk_h, bend_z * 0.1)
	_add_leaf_cluster(st, top_pos, 0.8, 4, leaf_mat.albedo_color)
	_add_leaf_cluster(st, top_pos + Vector3(0.3, -0.2, 0.3), 0.5, 3, leaf_mat.albedo_color)

	var mesh := st.commit()
	wood_mat.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, wood_mat)
	return mesh

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

	var seed_base := world_gen.seed_value

	var oak_key := "oak_%d" % seed_base
	var oak_mesh: ArrayMesh
	if _tree_mesh_cache.has(oak_key):
		oak_mesh = _tree_mesh_cache[oak_key]
	else:
		oak_mesh = _make_tree_mesh_oak(wood_oak, leaf_oak_mat, seed_base)
		_tree_mesh_cache[oak_key] = oak_mesh

	var pine_key := "pine_%d" % seed_base
	var pine_mesh: ArrayMesh
	if _tree_mesh_cache.has(pine_key):
		pine_mesh = _tree_mesh_cache[pine_key]
	else:
		pine_mesh = _make_tree_mesh_pine(wood_pine, leaf_pine_mat)
		_tree_mesh_cache[pine_key] = pine_mesh

	var swamp_key := "swamp_%d" % (seed_base + 2000)
	var swamp_mesh: ArrayMesh
	if _tree_mesh_cache.has(swamp_key):
		swamp_mesh = _tree_mesh_cache[swamp_key]
	else:
		swamp_mesh = _make_tree_mesh_swamp(wood_swamp, leaf_swamp_mat, seed_base + 2000)
		_tree_mesh_cache[swamp_key] = swamp_mesh

	var max_slope := 0.5
	var half := HALF_WORLD - 2.0
	var all_points := _poisson_disk_sample(half, 9.0, world_gen.seed_value + 999)

	var tree_rng := RandomNumberGenerator.new()
	tree_rng.seed = world_gen.seed_value + 1000

	var tree_buckets: Array[Array] = [[], [], []]
	var tree_biomes: Array[Array] = [
		[world_gen.Biome.MEADOWS],
		[world_gen.Biome.BLACK_FOREST, world_gen.Biome.MOUNTAIN],
		[world_gen.Biome.SWAMP],
	]
	var tree_scales: Array[Vector2] = [
		Vector2(3.0, 6.0),
		Vector2(2.5, 5.5),
		Vector2(2.5, 5.0),
	]

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

		for ti in 3:
			if biome in tree_biomes[ti]:
				var threshold := 0.25 if biome == world_gen.Biome.SWAMP else 0.3
				if forest > threshold and tree_rng.randf() < 0.35:
					var sh := world_gen.get_height(px, pz)
					var t := Transform3D.IDENTITY
					var s := tree_scales[ti].x + tree_rng.randf() * (tree_scales[ti].y - tree_scales[ti].x)
					t.origin = Vector3(px, sh, pz)
					t.basis = t.basis.scaled(Vector3(s, s, s))
					t.basis = t.basis.rotated(Vector3.UP, tree_rng.randf() * TAU)
					tree_buckets[ti].append(t)
				break

	var tree_meshes := [oak_mesh, pine_mesh, swamp_mesh]
	for ti in 3:
		var positions := tree_buckets[ti]
		if positions.size() == 0:
			continue
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = tree_meshes[ti]
		mm.instance_count = positions.size()
		for i in positions.size():
			mm.set_instance_transform(i, positions[i])
			var tint := Color(1.0, tree_rng.randf_range(0.85, 1.0), tree_rng.randf_range(0.85, 1.0))
			mm.set_instance_color(i, tint)
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.roughness = 0.9
		material.vertex_color_use_as_albedo = true
		mmi.material_override = material
		add_child(mmi)

func _make_grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w_bot := 0.04
	var w_top := 0.01
	var h := 0.3
	for i in 3:
		var angle := float(i) / 3.0 * TAU
		var perp := Vector3(-cos(angle), 0.0, sin(angle))
		var v0 := -perp * w_bot * 0.5
		var v1 := perp * w_bot * 0.5
		var v2 := -perp * w_top * 0.5 + Vector3(0.0, h, 0.0)
		var v3 := perp * w_top * 0.5 + Vector3(0.0, h, 0.0)
		var n := Vector3(sin(angle), 0.0, cos(angle))
		for v in [v0, v1, v2, v1, v3, v2]:
			st.set_normal(n)
			st.add_vertex(v)
	return st.commit()

func _make_bush_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centers: Array[Vector3] = [Vector3.ZERO, Vector3(0.08, 0.04, 0.08)]
	for center in centers:
		var r := 0.18
		for ri in 3:
			var lat0 := float(ri) / 3.0 * PI
			var lat1 := float(ri + 1) / 3.0 * PI
			for j in 6:
				var lon0 := float(j) / 6.0 * TAU
				var lon1 := float(j + 1) / 6.0 * TAU
				var face_a: Array[float] = [lat0, lon0, lat0, lon1, lat1, lon0]
				var face_b: Array[float] = [lat0, lon1, lat1, lon1, lat1, lon0]
				for face in [face_a, face_b]:
					var px0 := sin(face[0]) * cos(face[1]) * r
					var py0 := cos(face[0]) * r
					var pz0 := sin(face[0]) * sin(face[1]) * r
					var p0: Vector3 = Vector3(px0, py0, pz0) + center
					var n0: Vector3 = (p0 - center).normalized()
					var px1 := sin(face[2]) * cos(face[3]) * r
					var py1 := cos(face[2]) * r
					var pz1 := sin(face[2]) * sin(face[3]) * r
					var p1: Vector3 = Vector3(px1, py1, pz1) + center
					var n1: Vector3 = (p1 - center).normalized()
					var px2 := sin(face[4]) * cos(face[5]) * r
					var py2 := cos(face[4]) * r
					var pz2 := sin(face[4]) * sin(face[5]) * r
					var p2: Vector3 = Vector3(px2, py2, pz2) + center
					var n2: Vector3 = (p2 - center).normalized()
					st.set_normal(n0)
					st.add_vertex(p0)
					st.set_normal(n1)
					st.add_vertex(p1)
					st.set_normal(n2)
					st.add_vertex(p2)
	return st.commit()

func _make_flower_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stem_w := 0.006
	var stem_h := 0.12
	var n_stem := Vector3(0.0, 0.0, 1.0)
	for v in [Vector3(-stem_w, 0.0, 0.0), Vector3(stem_w, 0.0, 0.0), Vector3(-stem_w, stem_h, 0.0),
			Vector3(stem_w, 0.0, 0.0), Vector3(stem_w, stem_h, 0.0), Vector3(-stem_w, stem_h, 0.0)]:
		st.set_normal(n_stem)
		st.add_vertex(v)
	var hw := 0.03
	var hh := 0.03
	for i in 3:
		var a := float(i) / 3.0 * TAU
		var perp := Vector3(-cos(a), 0.0, sin(a))
		var v0 := -perp * hw * 0.5 + Vector3(0.0, stem_h, 0.0)
		var v1 := perp * hw * 0.5 + Vector3(0.0, stem_h, 0.0)
		var v2 := -perp * hw * 0.5 + Vector3(0.0, stem_h + hh, 0.0)
		var v3 := perp * hw * 0.5 + Vector3(0.0, stem_h + hh, 0.0)
		var n := Vector3(sin(a), 0.0, cos(a))
		for v in [v0, v1, v2, v1, v3, v2]:
			st.set_normal(n)
			st.add_vertex(v)
	return st.commit()

func _scatter_foliage() -> void:
	var fol_mat: ShaderMaterial = ShaderMaterial.new()
	fol_mat.shader = preload("res://shaders/wind_foliage.gdshader")
	fol_mat.set_shader_parameter("color_tint", Color.WHITE)
	fol_mat.set_shader_parameter("turbulence", 0.6)

	var grass_mesh := _make_grass_mesh()
	var bush_mesh := _make_bush_mesh()
	var flower_mesh := _make_flower_mesh()

	var rng := RandomNumberGenerator.new()
	rng.seed = world_gen.seed_value + 5000

	var grass_transforms: Array[Transform3D] = []
	var grass_colors: Array[Color] = []
	var bush_transforms: Array[Transform3D] = []
	var bush_colors: Array[Color] = []
	var flower_transforms: Array[Transform3D] = []
	var flower_colors: Array[Color] = []

	var half := HALF_WORLD - 2.0
	for _attempt in 12000:
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
				if r < 0.45:
					var col := Color(bc.r * rng.randf_range(0.7, 1.3), bc.g * rng.randf_range(0.7, 1.3), bc.b * rng.randf_range(0.7, 1.3), 1.0)
					_add_foliage_point(grass_transforms, grass_colors, x, h, z, rng, col)
				elif r < 0.50:
					var brights := [Color(1.0, 0.9, 0.2), Color(1.0, 0.3, 0.3), Color(0.4, 0.5, 1.0), Color(1.0, 0.5, 0.8), Color(1.0, 1.0, 1.0)]
					_add_foliage_point(flower_transforms, flower_colors, x, h, z, rng, brights[rng.randi() % brights.size()])

			world_gen.Biome.BLACK_FOREST:
				if forest > 0.3 and r < 0.25:
					var col := Color(bc.r * rng.randf_range(0.8, 1.2), bc.g * rng.randf_range(0.8, 1.2), bc.b * rng.randf_range(0.8, 1.2), 1.0)
					_add_foliage_point(grass_transforms, grass_colors, x, h, z, rng, col)
				elif r < 0.35:
					var col := Color(bc.r * rng.randf_range(0.8, 1.2), bc.g * rng.randf_range(0.8, 1.2), bc.b * rng.randf_range(0.8, 1.2), 1.0)
					_add_foliage_point(bush_transforms, bush_colors, x, h, z, rng, col)

			world_gen.Biome.SWAMP:
				if r < 0.12:
					var col := Color(bc.r * rng.randf_range(0.8, 1.2), bc.g * rng.randf_range(0.8, 1.2), bc.b * rng.randf_range(0.8, 1.2), 1.0)
					_add_foliage_point(bush_transforms, bush_colors, x, h, z, rng, col)

			world_gen.Biome.MOUNTAIN:
				if r < 0.05 and h < 3.0:
					var col := Color(bc.r * rng.randf_range(0.7, 1.3), bc.g * rng.randf_range(0.7, 1.3), bc.b * rng.randf_range(0.7, 1.3), 1.0)
					_add_foliage_point(grass_transforms, grass_colors, x, h, z, rng, col)

	_build_foliage_multimesh(grass_mesh, fol_mat, grass_transforms, grass_colors, "Grass")
	_build_foliage_multimesh(bush_mesh, fol_mat, bush_transforms, bush_colors, "Bushes")
	_build_foliage_multimesh(flower_mesh, fol_mat, flower_transforms, flower_colors, "Flowers")

func _add_foliage_point(transforms: Array[Transform3D], colors: Array[Color], x: float, h: float, z: float, rng: RandomNumberGenerator, col: Color) -> void:
	var t := Transform3D.IDENTITY
	t.origin = Vector3(x, h, z)
	t.basis = t.basis.scaled(Vector3(rng.randf_range(0.6, 1.4), rng.randf_range(0.6, 1.4), rng.randf_range(0.6, 1.4)))
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
