extends SkeletonModifier3D
class_name FootPlacementModifier3D

## Procedural foot IK that places feet on terrain surfaces.
## Attach as a child of Skeleton3D. Configure foot_bones/parent_bones arrays
## before the skeleton enters the scene tree.

## How far below the bone to raycast for ground.
@export var raycast_length: float = 2.0
## Maximum foot tilt angle in radians (prevents unnatural angles).
@export var max_foot_tilt: float = deg_to_rad(25.0)
## Ground offset — feet hover slightly above surface.
@export var ground_offset: float = 0.05
## Layer mask for ground raycasts (1 = terrain layer).
@export var ground_mask: int = 1

## Bone indices for each foot (set by skeleton build method).
var foot_bone_indices: PackedInt32Array = []
## Parent bone indices (upper legs) for IK solve.
var parent_bone_indices: PackedInt32Array = []

var _skel: Skeleton3D
var _initialized: bool = false


func initialize(skel: Skeleton3D, p_foot_bones: PackedInt32Array, p_parent_bones: PackedInt32Array) -> void:
	_skel = skel
	foot_bone_indices = p_foot_bones
	parent_bone_indices = p_parent_bones
	_initialized = true


func _process_modification() -> void:
	if not _initialized or not _skel or foot_bone_indices.is_empty():
		return

	var space_state := _skel.get_world_3d().direct_space_state
	if not space_state:
		return

	for i in foot_bone_indices.size():
		var foot_bone_idx: int = foot_bone_indices[i]
		var parent_bone_idx: int = parent_bone_indices[i]

		# Get bone global position
		var bone_global_pose := _skel.get_bone_global_pose(foot_bone_idx)
		var foot_global_pos := _skel.global_transform * bone_global_pose.origin

		# Raycast down to find ground
		var from := foot_global_pos + Vector3.UP * 0.5
		var to := foot_global_pos + Vector3.DOWN * raycast_length
		var query := PhysicsRayQueryParameters3D.new()
		query.from = from
		query.to = to
		query.collision_mask = ground_mask
		var hit := space_state.intersect_ray(query)

		if hit:
			var ground_normal: Vector3 = hit.normal

			# Calculate desired foot rotation to align with surface normal
			var up := ground_normal
			var forward := (foot_global_pos - _skel.global_position).normalized()
			forward = forward.cross(up).normalized()
			if forward.length_squared() < 0.001:
				forward = Vector3.FORWARD
			var right := up.cross(forward).normalized()
			var desired_rot := Quaternion(Basis(right, up, forward))

			# Convert to local bone space using basis multiplication
			var parent_global_pose := _skel.get_bone_global_pose(parent_bone_idx)
			var parent_inv_basis := parent_global_pose.orthonormalized().basis.inverse()
			var local_rot := Quaternion(parent_inv_basis) * desired_rot

			# Clamp to prevent weird angles
			var euler := local_rot.get_euler()
			euler.x = clampf(euler.x, -max_foot_tilt, max_foot_tilt)
			euler.z = clampf(euler.z, -max_foot_tilt, max_foot_tilt)
			local_rot = Quaternion.from_euler(euler)

			# Apply to skeleton
			_skel.set_bone_pose_rotation(foot_bone_idx, local_rot)
		else:
			# No ground hit — reset to default pose
			_skel.set_bone_pose_position(foot_bone_idx,
				_skel.get_bone_rest(foot_bone_idx).origin)
			_skel.set_bone_pose_rotation(foot_bone_idx, Quaternion.IDENTITY)
