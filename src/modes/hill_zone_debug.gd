extends MeshInstance3D
class_name HillZoneDebug

## Debug visualization for the King of the Hill zone.
## Draws a glowing ring and height beam using ImmediateMesh.
## Attach as a child of the scene, or instantiate directly.

@export var zone_radius: float = 15.0
@export var ring_height: float = 0.3
@export var beam_height: float = 8.0
@export var ring_segments: int = 64
@export var ring_color: Color = Color(0.0, 0.8, 1.0, 0.6)
@export var beam_color: Color = Color(0.0, 0.5, 0.8, 0.3)

var _ring_mesh: MeshInstance3D
var _beam_mesh: MeshInstance3D
var _pulse_time: float = 0.0


func _ready() -> void:
	# Ring mesh (horizontal circle on ground)
	_ring_mesh = MeshInstance3D.new()
	_ring_mesh.name = "HillRing"
	_ring_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring_mesh)

	# Beam mesh (vertical glow pillar)
	_beam_mesh = MeshInstance3D.new()
	_beam_mesh.name = "HillBeam"
	_beam_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam_mesh)


func _process(delta: float) -> void:
	_pulse_time += delta
	_draw_ring()
	_draw_beam()


func _draw_ring() -> void:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)

	var pulse := 0.7 + sin(_pulse_time * 2.0) * 0.3
	var color := ring_color
	color.a *= pulse
	im.surface_set_color(color)

	for i in ring_segments:
		var a0 := float(i) / ring_segments * TAU
		var a1 := float(i + 1) / ring_segments * TAU
		var p0 := Vector3(cos(a0) * zone_radius, ring_height, sin(a0) * zone_radius)
		var p1 := Vector3(cos(a1) * zone_radius, ring_height, sin(a1) * zone_radius)
		im.surface_add_vertex(p0)
		im.surface_add_vertex(p1)

	im.surface_end()
	_ring_mesh.mesh = im


func _draw_beam() -> void:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)

	var pulse := 0.5 + sin(_pulse_time * 1.5) * 0.3
	var color := beam_color
	color.a *= pulse
	im.surface_set_color(color)

	# Vertical beam lines from ground to sky
	var beam_count := 8
	for i in beam_count:
		var angle := float(i) / beam_count * TAU
		var x := cos(angle) * zone_radius * 0.8
		var z := sin(angle) * zone_radius * 0.8
		im.surface_add_vertex(Vector3(x, ring_height, z))
		im.surface_add_vertex(Vector3(x, ring_height + beam_height, z))

	im.surface_end()
	_beam_mesh.mesh = im