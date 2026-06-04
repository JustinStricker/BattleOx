class_name PerceptionComponent
extends Node

@export var target_group: String = "player"
@export var range: float = 18.0
@export var raycast_height_offset: float = 1.0

var target: Node3D = null
var _checked_frame: int = -1
var _cached_result: bool = false


func _ready() -> void:
	target = get_tree().get_first_node_in_group(target_group) as Node3D


func has_line_of_sight() -> bool:
	var frame := Engine.get_process_frames()
	if frame == _checked_frame:
		return _cached_result
	_checked_frame = frame

	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(target_group) as Node3D
		_cached_result = false
		return false

	var space := (owner as Node3D).get_world_3d().direct_space_state
	if not space:
		_cached_result = false
		return false

	var query := PhysicsRayQueryParameters3D.new()
	query.from = owner.global_position + Vector3.UP * raycast_height_offset
	query.to = target.global_position + Vector3.UP * raycast_height_offset
	query.exclude = [owner]
	var result := space.intersect_ray(query)
	_cached_result = result.is_empty() or result.collider == target
	return _cached_result


func distance_to_target() -> float:
	if not is_instance_valid(target):
		return INF
	return owner.global_position.distance_to(target.global_position)
