class_name MovementComponent
extends Node

@export var gravity: float = 9.8
@export var rotation_speed: float = 6.0


func apply_gravity_and_slide(delta: float) -> void:
	var body: CharacterBody3D = owner
	if not body.is_inside_tree():
		return
	body.velocity.y -= gravity * delta
	body.move_and_slide()


func move_toward(target_pos: Vector3, speed: float, delta: float) -> void:
	var body: CharacterBody3D = owner
	var dir := Vector3(target_pos.x - body.global_position.x, 0, target_pos.z - body.global_position.z)
	if dir.length() < 0.1:
		body.velocity.x = 0.0
		body.velocity.z = 0.0
		return
	dir = dir.normalized()
	face_target(target_pos, delta * rotation_speed)
	body.velocity.x = dir.x * speed
	body.velocity.z = dir.z * speed


func face_target(target_pos: Vector3, weight: float) -> void:
	var body: CharacterBody3D = owner
	var dir := Vector3(target_pos.x - body.global_position.x, 0, target_pos.z - body.global_position.z)
	if dir.length() < 0.01:
		return
	var target_basis := Basis.looking_at(dir.normalized(), Vector3.UP)
	body.transform.basis = body.transform.basis.slerp(target_basis, weight)


func ground_height(pos: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = (owner as Node3D).get_world_3d().direct_space_state
	if not space:
		return pos.y
	var query := PhysicsRayQueryParameters3D.new()
	query.from = pos + Vector3.UP * 20.0
	query.to = pos + Vector3.DOWN * 20.0
	query.collision_mask = 1
	var result: Dictionary = space.intersect_ray(query)
	if result.is_empty():
		return pos.y
	return result.position.y
