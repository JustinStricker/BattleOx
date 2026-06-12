extends Node3D
class_name InteractableTree

const OAK := 0
const PINE := 1
const SWAMP := 2
const BANYAN := 3

var tree_type: int = OAK
var health: int = 100
var max_health: int = 100
var is_alive: bool = true

var _mesh_instance: MeshInstance3D
var _collision_body: StaticBody3D


func _init() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	add_child(_mesh_instance)

	_collision_body = StaticBody3D.new()
	_collision_body.collision_layer = 4
	_collision_body.collision_mask = 0
	add_child(_collision_body)


func _ready() -> void:
	add_to_group("interactable")


func setup(p_mesh: ArrayMesh, p_collision_data: Array, tree_transform: Transform3D, p_type: int) -> void:
	tree_type = p_type
	global_transform = tree_transform
	_mesh_instance.mesh = p_mesh

	for entry in p_collision_data:
		var shape: Shape3D = entry["shape"]
		var local_t: Transform3D = entry["local_transform"]
		var col_shape := CollisionShape3D.new()
		col_shape.shape = shape
		col_shape.transform = local_t
		_collision_body.add_child(col_shape)

	match tree_type:
		OAK:
			max_health = 100
		PINE:
			max_health = 80
		SWAMP:
			max_health = 60
		BANYAN:
			max_health = 120
	health = max_health


func take_damage(_amount: int) -> void:
	if not is_alive:
		return
	health -= _amount
	if health <= 0:
		_destroy()


func _destroy() -> void:
	is_alive = false
	_collision_body.queue_free()
	_mesh_instance.visible = false
	# Future: spawn particles, sound, wood resource drop
