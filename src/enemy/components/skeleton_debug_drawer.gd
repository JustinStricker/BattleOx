extends MeshInstance3D
class_name SkeletonDebugDrawer

## Debug visualizer for Skeleton3D bone hierarchies.
## Attach as a child of any Skeleton3D to draw bone connections.
## Only active in debug builds or editor.

var _skeleton: Skeleton3D
var _draw_color: Color = Color(1.0, 0.3, 0.3, 0.4)
var _joint_color: Color = Color(0.3, 1.0, 0.3, 0.6)
var _active: bool = false


func _ready() -> void:
	# Only enable in debug builds
	if OS.is_debug_build() or Engine.is_editor_hint():
		_active = true
		_skeleton = get_parent() as Skeleton3D
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(_delta: float) -> void:
	if not _active or not _skeleton:
		return
	_draw_bones()


func _draw_bones() -> void:
	var im := ImmediateMesh.new()

	# Draw bone connections (lines from parent to child)
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_set_color(_draw_color)

	for i in _skeleton.get_bone_count():
		var parent_idx := _skeleton.get_bone_parent(i)
		if parent_idx >= 0:
			var bone_pose := _skeleton.get_bone_global_pose(i)
			var parent_pose := _skeleton.get_bone_global_pose(parent_idx)
			var p0 := _skeleton.global_transform * bone_pose.origin
			var p1 := _skeleton.global_transform * parent_pose.origin
			im.surface_add_vertex(p0)
			im.surface_add_vertex(p1)

	im.surface_end()

	# Draw joint points (small spheres at each bone position)
	im.surface_begin(Mesh.PRIMITIVE_POINTS)
	im.surface_set_color(_joint_color)

	for i in _skeleton.get_bone_count():
		var bone_pose := _skeleton.get_bone_global_pose(i)
		var pos := _skeleton.global_transform * bone_pose.origin
		im.surface_add_vertex(pos)

	im.surface_end()

	mesh = im
