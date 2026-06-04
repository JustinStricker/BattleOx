extends CanvasLayer
class_name BiomeOverlay

var visible_overlay := false
var world_gen: WorldGen
var _draw_control: Control

const CHUNK_PX := 12
const GRID := 7
const ORIGIN := Vector2(10, 10)

func _ready() -> void:
	_draw_control = Control.new()
	_draw_control.name = "OverlayControl"
	_draw_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_control.draw.connect(_on_draw)
	add_child(_draw_control)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_B and event.pressed:
		visible_overlay = not visible_overlay
		if _draw_control:
			_draw_control.queue_redraw()

func _on_draw() -> void:
	if not visible_overlay or not world_gen:
		return
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return

	var pcx := floori(player.global_position.x / 64)
	var pcz := floori(player.global_position.z / 64)

	for x in range(-3, 4):
		for z in range(-3, 4):
			var wx := (pcx + x) * 64 + 32
			var wz := (pcz + z) * 64 + 32
			var biome := world_gen.get_biome(wx, wz)
			var color := _biome_debug_color(biome)
			var rect_pos := ORIGIN + Vector2((x + 3) * CHUNK_PX, (z + 3) * CHUNK_PX)
			_draw_control.draw_rect(Rect2(rect_pos, Vector2(CHUNK_PX, CHUNK_PX)), color)

	var legend_y := ORIGIN.y + GRID * CHUNK_PX + 10
	for biome in WorldGen.Biome.values():
		var name_str: String = WorldGen.Biome.keys()[biome]
		var y: float = legend_y + biome * 16
		_draw_control.draw_rect(Rect2(ORIGIN.x, y, 10, 10), _biome_debug_color(biome))
		var font := ThemeDB.fallback_font
		_draw_control.draw_string(font, Vector2(ORIGIN.x + 14, y + 10), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)

static func _biome_debug_color(biome: WorldGen.Biome) -> Color:
	match biome:
		WorldGen.Biome.OCEAN:        return Color(0.0, 0.2, 0.6, 0.7)
		WorldGen.Biome.MEADOWS:      return Color(0.2, 0.8, 0.1, 0.7)
		WorldGen.Biome.BLACK_FOREST: return Color(0.05, 0.3, 0.05, 0.7)
		WorldGen.Biome.SWAMP:        return Color(0.3, 0.2, 0.05, 0.7)
		WorldGen.Biome.MOUNTAIN:     return Color(0.6, 0.6, 0.6, 0.7)
	return Color(1, 0, 0, 0.7)
