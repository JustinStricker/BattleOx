extends Node3D
class_name TerrainChunk

const CHUNK_SIZE := 64
const VERTS := 65

var chunk_key: Vector2i
var mesh_instance: MeshInstance3D
var collision_body: StaticBody3D
var collision_shape: CollisionShape3D

static var _terrain_shader: Shader = preload("res://shaders/terrain.gdshader")

func _init() -> void:
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	add_child(mesh_instance)

	collision_body = StaticBody3D.new()
	collision_body.name = "Collision"
	collision_shape = CollisionShape3D.new()
	collision_body.add_child(collision_shape)
	add_child(collision_body)

func build_from_arrays(key: Vector2i, arrays: Array) -> void:
	chunk_key = key
	position = Vector3(key.x * CHUNK_SIZE, 0, key.y * CHUNK_SIZE)
	name = "Chunk_%d_%d" % [key.x, key.y]

	var st := SurfaceTool.new()
	st.create_from_arrays(arrays, Mesh.PRIMITIVE_TRIANGLES)
	var mesh := st.commit()

	mesh_instance.mesh = mesh
	if not mesh_instance.material_override:
		mesh_instance.material_override = ShaderMaterial.new()
	mesh_instance.material_override.shader = _terrain_shader

	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idxs: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var faces := PackedVector3Array()
	faces.resize(idxs.size())
	for i in idxs.size():
		faces[i] = verts[idxs[i]]
	var col_mesh := ConcavePolygonShape3D.new()
	col_mesh.set_faces(faces)
	collision_shape.shape = col_mesh

static func generate_arrays(world_gen: WorldGen, key: Vector2i) -> Array:
	var ox := key.x * CHUNK_SIZE
	var oz := key.y * CHUNK_SIZE

	var verts := PackedVector3Array()
	verts.resize(VERTS * VERTS)
	var heights := PackedFloat32Array()
	heights.resize(VERTS * VERTS)

	for iz in VERTS:
		for ix in VERTS:
			var wx := ox + ix
			var wz := oz + iz
			var idx := iz * VERTS + ix
			var h := world_gen.get_height(wx, wz)
			heights[idx] = h
			verts[idx] = Vector3(ix, h, iz)

	var normals := PackedVector3Array()
	normals.resize(VERTS * VERTS)
	for iz in VERTS:
		for ix in VERTS:
			var idx := iz * VERTS + ix
			var h_l := heights[iz * VERTS + max(ix - 1, 0)]
			var h_r := heights[iz * VERTS + min(ix + 1, VERTS - 1)]
			var h_d := heights[max(iz - 1, 0) * VERTS + ix]
			var h_u := heights[min(iz + 1, VERTS - 1) * VERTS + ix]
			normals[idx] = Vector3(h_l - h_r, 2.0, h_d - h_u).normalized()

	var colors := PackedColorArray()
	colors.resize(VERTS * VERTS)
	for iz in VERTS:
		for ix in VERTS:
			var wx := ox + ix
			var wz := oz + iz
			var idx := iz * VERTS + ix
			var color := world_gen.sample_biome_color(wx, wz)
			colors[idx] = color

	var indices := PackedInt32Array()
	indices.resize((VERTS - 1) * (VERTS - 1) * 6)
	var ii := 0
	for iz in VERTS - 1:
		for ix in VERTS - 1:
			var i00 := iz * VERTS + ix
			var i10 := iz * VERTS + ix + 1
			var i01 := (iz + 1) * VERTS + ix
			var i11 := (iz + 1) * VERTS + ix + 1
			indices[ii] = i00; ii += 1
			indices[ii] = i10; ii += 1
			indices[ii] = i01; ii += 1
			indices[ii] = i10; ii += 1
			indices[ii] = i11; ii += 1
			indices[ii] = i01; ii += 1

	var result := []
	result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX] = verts
	result[Mesh.ARRAY_NORMAL] = normals
	result[Mesh.ARRAY_COLOR] = colors
	result[Mesh.ARRAY_INDEX] = indices
	return result
