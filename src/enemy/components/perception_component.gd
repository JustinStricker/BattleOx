class_name PerceptionComponent
extends Node

@export var target_group: String = "player"
@export var detect_range: float = 18.0
@export var raycast_height_offset: float = 1.0

var target: Node3D = null
var _checked_frame: int = -1
var _cached_result: bool = false


func _ready() -> void:
	_find_nearest_target()


func _find_nearest_target() -> void:
	var players := get_tree().get_nodes_in_group(target_group)
	var nearest: Node3D = null
	var nearest_dist := INF
	var owner_pos := (owner as Node3D).global_position
	for p in players:
		var p3 := p as Node3D
		if not is_instance_valid(p3):
			continue
		var d := owner_pos.distance_squared_to(p3.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = p3
	target = nearest


func has_line_of_sight() -> bool:
	var frame := Engine.get_process_frames()
	if frame == _checked_frame:
		return _cached_result
	_checked_frame = frame

	if not is_instance_valid(target):
		_find_nearest_target()
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
