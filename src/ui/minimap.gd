extends Control

const MINIMAP_SIZE: float = 150.0
const VIEW_RADIUS: float = 128.0
const DOT_RADIUS: float = 4.0
const LOCAL_DOT_RADIUS: float = 5.0
const PADDING: float = 8.0

const BG_COLOR: Color = Color(0.0, 0.0, 0.0, 0.5)
const BORDER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.25)
const LOCAL_DOT_COLOR: Color = Color(0.3, 1.0, 0.3, 0.9)
const REMOTE_DOT_COLOR: Color = Color(0.3, 0.7, 1.0, 0.9)
const GRID_LINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.06)

var local_player: Node3D
var _players_cache: Array[Node]


func _ready() -> void:
	custom_minimum_size = Vector2(MINIMAP_SIZE, MINIMAP_SIZE)
	size = Vector2(MINIMAP_SIZE, MINIMAP_SIZE)


func _process(_delta: float) -> void:
	_players_cache = get_tree().get_nodes_in_group("player")
	if _players_cache.is_empty():
		return

	var found: Node3D = null
	var my_id := multiplayer.get_unique_id()
	for p in _players_cache:
		if is_instance_valid(p) and p.get_multiplayer_authority() == my_id:
			found = p
			break
	if found != local_player:
		local_player = found

	queue_redraw()


func _draw() -> void:
	var size_rect := Rect2(0, 0, MINIMAP_SIZE, MINIMAP_SIZE)

	draw_rect(size_rect, BG_COLOR)
	draw_rect(size_rect, BORDER_COLOR, false, 1.0)

	if not is_instance_valid(local_player):
		return

	var half := MINIMAP_SIZE * 0.5
	var scale_px := half / VIEW_RADIUS

	_draw_grid(half, scale_px)

	var lpos := local_player.global_position

	for p in _players_cache:
		if not is_instance_valid(p):
			continue
		if p == local_player:
			draw_circle(Vector2(half, half), LOCAL_DOT_RADIUS, LOCAL_DOT_COLOR)
			continue

		var dx: float = (p.global_position.x - lpos.x) * scale_px
		var dz: float = (p.global_position.z - lpos.z) * scale_px
		var px: float = clamp(half + dx, PADDING, MINIMAP_SIZE - PADDING)
		var py: float = clamp(half + dz, PADDING, MINIMAP_SIZE - PADDING)
		draw_circle(Vector2(px, py), DOT_RADIUS, REMOTE_DOT_COLOR)


func _draw_grid(half: float, scale_px: float) -> void:
	var grid_step := 32.0 * scale_px
	if grid_step < 8.0:
		grid_step = 8.0
	var x := half + fmod(-(half + 0.0), grid_step)
	while x < MINIMAP_SIZE:
		draw_line(Vector2(x, 0), Vector2(x, MINIMAP_SIZE), GRID_LINE_COLOR, 0.5)
		x += grid_step
	var y := half + fmod(-(half + 0.0), grid_step)
	while y < MINIMAP_SIZE:
		draw_line(Vector2(0, y), Vector2(MINIMAP_SIZE, y), GRID_LINE_COLOR, 0.5)
		y += grid_step
