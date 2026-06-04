extends CanvasLayer

@onready var score_label: Label = $ScoreLabel
@onready var crosshair_control: Control = $CrosshairControl
@onready var dash_slash_ability: Control = $AbilityBar/DashSlashAbility
@onready var bow_ability: Control = $AbilityBar/BowAbility
@onready var roll_ability: Control = $AbilityBar/RollAbility
@onready var ultimate_ability: Control = $AbilityBar/UltimateAbility

var player: CharacterBody3D
var sword: Node3D
var bow: Node3D
var ultimate: Node3D

var roll_display_charges: int = 3
var roll_display_recharging: bool = false
var roll_display_progress: float = 0.0

var _needs_ability_redraw: bool = true

const SLOT_SIZE: float = 96.0
const DASH_COOLDOWN_MAX: float = 1.5
const BOW_COOLDOWN_MAX: float = 0.5
const BOW_CHARGE_MAX: float = 2.0
const ICON_COLOR: Color = Color(1.0, 1.0, 1.0, 0.85)
const BG_COLOR: Color = Color(0.0, 0.0, 0.0, 0.5)
const BORDER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.25)
const COOLDOWN_OVERLAY: Color = Color(0.0, 0.0, 0.0, 0.65)
const CHARGE_BAR_COLOR: Color = Color(1.0, 0.8, 0.3, 0.9)
const CHARGE_BG_COLOR: Color = Color(0.3, 0.3, 0.3, 0.5)


func _ready() -> void:
	crosshair_control.draw.connect(_draw_crosshair)
	crosshair_control.resized.connect(crosshair_control.queue_redraw)

	dash_slash_ability.draw.connect(_draw_dash_slash)
	bow_ability.draw.connect(_draw_bow)
	roll_ability.draw.connect(_draw_roll)
	ultimate_ability.draw.connect(_draw_ultimate)

	player = get_tree().get_first_node_in_group("player")
	if player:
		var cam: Node3D = player.get_node("Camera3D")
		if cam:
			sword = cam.get_node("SwordSlash")
			# Find bow by checking for start_charge method
			for child in cam.get_children():
				if child is Node3D and child.has_method("start_charge"):
					bow = child
					break

			# Find ultimate by checking for try_fire method
			for child in cam.get_children():
				if child is Node3D and child.has_method("try_fire"):
					ultimate = child
					if ultimate.has_signal("charge_changed"):
						ultimate.charge_changed.connect(func(_c): _needs_ability_redraw = true)
					break

		player.roll_charges_changed.connect(_on_roll_charges_changed)


func _unhandled_input(_event: InputEvent) -> void:
	_needs_ability_redraw = true

func _process(_delta: float) -> void:
	if _needs_ability_redraw:
		dash_slash_ability.queue_redraw()
		bow_ability.queue_redraw()
		roll_ability.queue_redraw()
		ultimate_ability.queue_redraw()
		_needs_ability_redraw = false


func _draw_ability_slot(target: Control, size: Vector2) -> void:
	# Background
	target.draw_rect(Rect2(0, 0, size.x, size.y), BG_COLOR)
	# Border
	target.draw_rect(Rect2(0, 0, size.x, 1.0), BORDER_COLOR)
	target.draw_rect(Rect2(0, size.y - 1.0, size.x, 1.0), BORDER_COLOR)
	target.draw_rect(Rect2(0, 0, 1.0, size.y), BORDER_COLOR)
	target.draw_rect(Rect2(size.x - 1.0, 0, 1.0, size.y), BORDER_COLOR)


func _draw_keybind(target: Control, size: Vector2, text: String) -> void:
	target.draw_string(ThemeDB.fallback_font, Vector2(0, 11), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, Color(1, 1, 1, 0.55))


func _draw_dash_slash() -> void:
	var target: Control = dash_slash_ability
	var size := target.get_rect().size
	var cx := size.x / 2.0
	var cy := size.y / 2.0

	_draw_ability_slot(target, size)
	_draw_keybind(target, size, "SHIFT")

	# Horizontal swipe icon — curved arc with motion trail
	var segments := 16
	var arc_w := 18.0
	var arc_h := 6.0
	var line_w := 3.0
	var col := ICON_COLOR
	# Draw curved arc from left to right, bowing upward
	for i in segments:
		var t1 := float(i) / float(segments)
		var t2 := float(i + 1) / float(segments)
		var x1 := cx - arc_w * 0.5 + arc_w * t1
		var y1 := cy + sin(t1 * PI) * arc_h
		var x2 := cx - arc_w * 0.5 + arc_w * t2
		var y2 := cy + sin(t2 * PI) * arc_h
		target.draw_line(Vector2(x1, y1), Vector2(x2, y2), col, line_w)
	# Arrowhead at the right end
	var tip_x := cx + arc_w * 0.5
	var tip_y := cy
	target.draw_colored_polygon(PackedVector2Array([
		Vector2(tip_x, tip_y),
		Vector2(tip_x - 6.0, tip_y - 4.0),
		Vector2(tip_x - 6.0, tip_y + 4.0),
	]), col)
	# Subtle motion lines behind
	for j in 3:
		var lx := cx - arc_w * 0.3 + j * 4.0
		var ly := cy + 2.0
		target.draw_rect(Rect2(lx, ly, 3.0, 1.5), Color(1, 1, 1, 0.35))

	# Cooldown overlay (descending curtain from top)
	var player_cd: float = player.dash_cooldown if player else 0.0
	if player_cd > 0.0:
		var cd_progress: float = player_cd / DASH_COOLDOWN_MAX
		var overlay_h: float = size.y * cd_progress
		target.draw_rect(Rect2(0, 0, size.x, overlay_h), COOLDOWN_OVERLAY)
		_draw_cooldown_text(target, player_cd, size)


func _draw_bow() -> void:
	var target: Control = bow_ability
	var size := target.get_rect().size
	var cx := size.x / 2.0
	var cy := size.y / 2.0

	_draw_ability_slot(target, size)
	_draw_keybind(target, size, "LMB")

	# Bow arc (drawn as line segments)
	var bow_color := ICON_COLOR
	var bow_radius := 14.0
	var segments := 12
	for i in segments:
		var t1 := float(i) / float(segments)
		var t2 := float(i + 1) / float(segments)
		var a1 := -PI * 0.4 + PI * 0.8 * t1
		var a2 := -PI * 0.4 + PI * 0.8 * t2
		var p1 := Vector2(cx + cos(a1) * bow_radius, cy + sin(a1) * bow_radius)
		var p2 := Vector2(cx + cos(a2) * bow_radius, cy + sin(a2) * bow_radius)
		target.draw_line(p1, p2, bow_color, 3.0)

	# Bow string
	target.draw_line(
		Vector2(cx - 2.0, cy - 12.0),
		Vector2(cx - 2.0, cy + 12.0),
		Color(0.9, 0.85, 0.6, 0.7),
		1.5
	)

	# Charge bar on right side of slot
	var bar_left := size.x - 6.0
	var bar_w := 4.0
	var bar_h := size.y - 12.0
	var bar_top := 6.0

	var charge_progress: float = 0.0
	if bow and bow.is_charging:
		var elapsed: float = (Time.get_ticks_msec() - bow.charge_start_time) / 1000.0
		charge_progress = clamp(elapsed / BOW_CHARGE_MAX, 0.0, 1.0)

	# Charge bar background
	target.draw_rect(Rect2(bar_left, bar_top, bar_w, bar_h), CHARGE_BG_COLOR)

	# Charge bar fill (grows bottom-to-top)
	if charge_progress > 0.0:
		var fill_h: float = bar_h * charge_progress
		var fill_top: float = bar_top + bar_h - fill_h
		target.draw_rect(Rect2(bar_left, fill_top, bar_w, fill_h), CHARGE_BAR_COLOR)

	# Cooldown overlay
	var cd: float = bow.shoot_cooldown if bow else 0.0
	if cd > 0.0:
		var progress: float = cd / BOW_COOLDOWN_MAX
		var overlay_h: float = size.y * progress
		target.draw_rect(Rect2(0, 0, size.x, overlay_h), COOLDOWN_OVERLAY)

	# Bottom text (cooldown, charge %, or "Ready")
	var font := ThemeDB.fallback_font
	var font_size := 12
	var text: String
	if cd > 0.0:
		text = str(snapped(cd, 0.1)) + "s"
	elif bow and bow.is_charging:
		text = str(int(charge_progress * 100.0)) + "%"
	else:
		text = "Ready"
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	target.draw_string(font, Vector2(cx - ts.x / 2.0, size.y - 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.85))


func _on_roll_charges_changed(charges: int, recharging: bool, progress: float) -> void:
	roll_display_charges = charges
	roll_display_recharging = recharging
	roll_display_progress = progress
	roll_ability.queue_redraw()

func _draw_roll() -> void:
	var target: Control = roll_ability
	var size := target.get_rect().size
	var cx := size.x / 2.0
	var cy := size.y / 2.0

	_draw_ability_slot(target, size)
	_draw_keybind(target, size, "DASH")

	# Dodge roll icon — curved arrow
	var arc_r := 10.0
	var arc_w := 2.5
	var segments := 10
	var col := ICON_COLOR
	# Upper arc (right to left)
	for i in segments:
		var t1 := float(i) / float(segments)
		var t2 := float(i + 1) / float(segments)
		var a1 := PI * 0.1 + PI * 0.6 * t1
		var a2 := PI * 0.1 + PI * 0.6 * t2
		var p1 := Vector2(cx + cos(a1) * arc_r - 4.0, cy - 2.0 + sin(a1) * arc_r)
		var p2 := Vector2(cx + cos(a2) * arc_r - 4.0, cy - 2.0 + sin(a2) * arc_r)
		target.draw_line(p1, p2, col, arc_w)
	# Arrowhead
	var tip := Vector2(cx + cos(PI * 0.7) * arc_r - 4.0, cy - 2.0 + sin(PI * 0.7) * arc_r)
	var tip_l := tip + Vector2(-4.0, -4.0)
	var tip_r := tip + Vector2(-4.0, 4.0)
	target.draw_colored_polygon(PackedVector2Array([tip, tip_l, tip_r]), col)

	# Lower arc (left to right)
	for i in segments:
		var t1 := float(i) / float(segments)
		var t2 := float(i + 1) / float(segments)
		var a1 := -PI * 0.7 + PI * 0.6 * t1
		var a2 := -PI * 0.7 + PI * 0.6 * t2
		var p1 := Vector2(cx + cos(a1) * arc_r - 4.0, cy + 4.0 + sin(a1) * arc_r)
		var p2 := Vector2(cx + cos(a2) * arc_r - 4.0, cy + 4.0 + sin(a2) * arc_r)
		target.draw_line(p1, p2, col, arc_w)
	# Arrowhead
	tip = Vector2(cx + cos(PI * -0.1) * arc_r - 4.0, cy + 4.0 + sin(PI * -0.1) * arc_r)
	tip_l = tip + Vector2(4.0, -4.0)
	tip_r = tip + Vector2(4.0, 4.0)
	target.draw_colored_polygon(PackedVector2Array([tip, tip_l, tip_r]), col)

	# Charge indicators — 3 circles at bottom
	var dot_r := 4.0
	var dot_gap := 14.0
	var dot_y := size.y - 10.0
	var start_x := cx - dot_gap

	for i in range(3):
		var dx := start_x + i * dot_gap
		var avail: bool = i < roll_display_charges
		var recharging_this: bool = i == roll_display_charges and roll_display_recharging

		if avail:
			target.draw_circle(Vector2(dx, dot_y), dot_r, ICON_COLOR)
		elif recharging_this and roll_display_progress > 0.0:
			target.draw_circle(Vector2(dx, dot_y), dot_r, CHARGE_BG_COLOR)
			# Draw progress arc (counterclockwise from top)
			var arc_segs := 12
			var angle_start := -PI * 0.5
			var angle_end := angle_start + PI * 2.0 * roll_display_progress
			for j in arc_segs:
				var t1 := float(j) / float(arc_segs)
				var t2 := float(j + 1) / float(arc_segs)
				var a1 := angle_start + (angle_end - angle_start) * t1
				var a2 := angle_start + (angle_end - angle_start) * t2
				var p1 := Vector2(dx + cos(a1) * (dot_r - 1.0), dot_y + sin(a1) * (dot_r - 1.0))
				var p2 := Vector2(dx + cos(a2) * (dot_r - 1.0), dot_y + sin(a2) * (dot_r - 1.0))
				var p3 := Vector2(dx + cos(a2) * dot_r, dot_y + sin(a2) * dot_r)
				var p4 := Vector2(dx + cos(a1) * dot_r, dot_y + sin(a1) * dot_r)
				target.draw_colored_polygon(PackedVector2Array([p1, p2, p3, p4]), CHARGE_BAR_COLOR)
		else:
			target.draw_circle(Vector2(dx, dot_y), dot_r, CHARGE_BG_COLOR)


func _draw_ultimate() -> void:
	var target := ultimate_ability
	var size := target.get_rect().size
	var cx := size.x / 2.0
	var cy := size.y / 2.0

	_draw_ability_slot(target, size)
	_draw_keybind(target, size, "F")

	# Icon: diamond / energy burst
	var gem_size := 8.0
	var top := Vector2(cx, cy - gem_size)
	var right := Vector2(cx + gem_size, cy)
	var bottom := Vector2(cx, cy + gem_size)
	var left := Vector2(cx - gem_size, cy)
	target.draw_colored_polygon(PackedVector2Array([top, right, bottom]), Color(1.0, 0.85, 0.5, 0.85))
	target.draw_colored_polygon(PackedVector2Array([top, left, bottom]), Color(0.7, 0.85, 1.0, 0.85))

	# Charge bar on left side
	var bar_left := 4.0
	var bar_w := 4.0
	var bar_h := size.y - 12.0
	var bar_top := 6.0

	target.draw_rect(Rect2(bar_left, bar_top, bar_w, bar_h), CHARGE_BG_COLOR)

	var charge_progress: float = ultimate.charge if ultimate else 0.0
	if charge_progress > 0.0:
		var fill_h := bar_h * charge_progress
		var fill_top := bar_top + bar_h - fill_h
		var fill_color := Color(0.3, 0.7, 1.0, 0.9) if charge_progress < 1.0 else Color(1.0, 0.7, 0.3, 0.9)
		target.draw_rect(Rect2(bar_left, fill_top, bar_w, fill_h), fill_color)

	# Pulsing border when fully charged
	if charge_progress >= 1.0:
		var pulse := sin(Time.get_ticks_msec() * 0.008) * 0.3 + 0.7
		var ready_color := Color(1.0, 0.8, 0.3, pulse)
		target.draw_rect(Rect2(0, 0, size.x, 2.0), ready_color)
		target.draw_rect(Rect2(0, size.y - 2.0, size.x, 2.0), ready_color)
		target.draw_rect(Rect2(0, 0, 2.0, size.y), ready_color)
		target.draw_rect(Rect2(size.x - 2.0, 0, 2.0, size.y), ready_color)

	# Text
	var font := ThemeDB.fallback_font
	var font_size := 10
	var text: String
	if charge_progress >= 1.0:
		text = "READY"
		font_size = 12
	else:
		text = str(int(charge_progress * 100.0)) + "%"
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	target.draw_string(font, Vector2(cx - ts.x / 2.0, size.y - 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.85))


func _draw_cooldown_text(target: Control, cd: float, slot_size: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 14
	var text := str(snapped(cd, 0.1)) + "s"
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	target.draw_string(
		font,
		Vector2(slot_size.x / 2.0 - ts.x / 2.0, slot_size.y - 6.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color(1, 1, 1, 0.9)
	)


func _draw_crosshair() -> void:
	var size: Vector2 = crosshair_control.get_rect().size
	var c: Vector2 = size / 2.0
	var gap: float = 5.0
	var len: float = 10.0
	var t: float = 2.0
	var col: Color = Color.WHITE
	crosshair_control.draw_rect(Rect2(c.x - 0.5, c.y - 0.5, 1.0, 1.0), col)
	crosshair_control.draw_rect(Rect2(c.x - t / 2.0, c.y - gap - len, t, len), col)
	crosshair_control.draw_rect(Rect2(c.x - t / 2.0, c.y + gap, t, len), col)
	crosshair_control.draw_rect(Rect2(c.x - gap - len, c.y - t / 2.0, len, t), col)
	crosshair_control.draw_rect(Rect2(c.x + gap, c.y - t / 2.0, len, t), col)


func set_score(value: int) -> void:
	score_label.text = "Score: " + str(value)
	var tween: Tween = create_tween()
	tween.tween_property(score_label, "modulate", Color.YELLOW, 0.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(score_label, "modulate", Color.WHITE, 0.2)
