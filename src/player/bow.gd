extends Node3D

signal arrow_fired(origin: Vector3, direction: Vector3, speed: float)

var is_charging: bool = false
var charge_start_time: float = 0.0
var shoot_cooldown: float = 0.0
var _pending_charge: bool = false

# String segments (connect tip → nock → tip)
var _string_upper: MeshInstance3D
var _string_lower: MeshInstance3D

# Limb pivot groups
var _upper_pivot: Node3D
var _lower_pivot: Node3D

# Tip markers (child of pivots, moved by flex)
var _upper_tip: Node3D
var _lower_tip: Node3D

# Nock point (where arrow sits, direct child of bow)
var _nock_point: Node3D

# Visual effect nodes
var _rune_strips: Array[MeshInstance3D] = []
var _charge_orb: MeshInstance3D
var _flash_light: OmniLight3D
var _muzzle_particles: GPUParticles3D

# Materials
var _rune_mat: StandardMaterial3D
var _string_mat: StandardMaterial3D
var _orb_mat: StandardMaterial3D
var _dark: StandardMaterial3D

# String positions at rest
var _string_upper_rest_len: float
var _string_lower_rest_len: float

const SHOOT_DELAY: float = 0.3
const MIN_CHARGE_TIME: float = 0.15
const MAX_CHARGE_TIME: float = 1.0
const MIN_ARROW_SPEED: float = 30.0
const MAX_ARROW_SPEED: float = 90.0

# Limb flex angle at full draw (radians)
const MAX_FLEX_ANGLE: float = 0.35  # ~20 degrees

# Recurve limb shape — each segment is a dictionary with position, radii, height, rotation
# Positions are relative to the limb pivot (base of limb)
# Rotation X controls the curve — positive bends forward (toward Z+), negative curls back (recurve)
const UPPER_LIMB: Array[Dictionary] = [
	{"pos": Vector3(0, 0.06, -0.01), "top_r": 0.045, "bot_r": 0.055, "h": 0.12, "rot": Vector3(0.04, 0, 0)},
	{"pos": Vector3(0, 0.16, -0.005), "top_r": 0.030, "bot_r": 0.045, "h": 0.10, "rot": Vector3(0.10, 0, 0)},
	{"pos": Vector3(0, 0.25, 0.010), "top_r": 0.020, "bot_r": 0.030, "h": 0.09, "rot": Vector3(0.05, 0, 0)},
	{"pos": Vector3(0, 0.33, 0.015), "top_r": 0.012, "bot_r": 0.020, "h": 0.07, "rot": Vector3(-0.08, 0, 0)},
	{"pos": Vector3(0, 0.39, 0.008), "top_r": 0.005, "bot_r": 0.012, "h": 0.05, "rot": Vector3(-0.22, 0, 0)},
]

const LOWER_LIMB: Array[Dictionary] = [
	{"pos": Vector3(0, -0.06, -0.01), "top_r": 0.055, "bot_r": 0.045, "h": 0.12, "rot": Vector3(-0.04, 0, 0)},
	{"pos": Vector3(0, -0.16, -0.005), "top_r": 0.045, "bot_r": 0.030, "h": 0.10, "rot": Vector3(-0.10, 0, 0)},
	{"pos": Vector3(0, -0.25, 0.010), "top_r": 0.030, "bot_r": 0.020, "h": 0.09, "rot": Vector3(-0.05, 0, 0)},
	{"pos": Vector3(0, -0.33, 0.015), "top_r": 0.020, "bot_r": 0.012, "h": 0.07, "rot": Vector3(0.08, 0, 0)},
	{"pos": Vector3(0, -0.39, 0.008), "top_r": 0.012, "bot_r": 0.005, "h": 0.05, "rot": Vector3(0.22, 0, 0)},
]


func _ready() -> void:
	position = Vector3(0.35, -0.25, -0.5)

	# --- Materials ---
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.5, 0.3, 0.15)
	wood.roughness = 0.75
	_dark = StandardMaterial3D.new()
	_dark.albedo_color = Color(0.35, 0.2, 0.08)
	_dark.roughness = 0.85
	var wrap_mat: StandardMaterial3D = StandardMaterial3D.new()
	wrap_mat.albedo_color = Color(0.15, 0.1, 0.08)
	wrap_mat.roughness = 0.9

	# Glowing rune material
	_rune_mat = StandardMaterial3D.new()
	_rune_mat.albedo_color = Color(0.3, 0.6, 1.0)
	_rune_mat.emission_enabled = true
	_rune_mat.emission = Color(0.2, 0.5, 1.0)
	_rune_mat.emission_energy_multiplier = 0.0
	_rune_mat.roughness = 0.3
	_rune_mat.metallic = 0.2

	# --- Riser (handle) ---
	var riser: MeshInstance3D = MeshInstance3D.new()
	riser.mesh = BoxMesh.new()
	riser.mesh.size = Vector3(0.09, 0.14, 0.07)
	riser.mesh.material = _dark
	add_child(riser)

	# Riser decoration — small metallic guards
	var guard_top: MeshInstance3D = MeshInstance3D.new()
	guard_top.mesh = BoxMesh.new()
	guard_top.mesh.size = Vector3(0.07, 0.02, 0.05)
	var guard_mat: StandardMaterial3D = StandardMaterial3D.new()
	guard_mat.albedo_color = Color(0.5, 0.45, 0.35)
	guard_mat.metallic = 0.6
	guard_mat.roughness = 0.4
	guard_top.mesh.material = guard_mat
	guard_top.position = Vector3(0, 0.08, 0)
	add_child(guard_top)

	var guard_bot: MeshInstance3D = guard_top.duplicate()
	guard_bot.position = Vector3(0, -0.08, 0)
	add_child(guard_bot)

	var grip: MeshInstance3D = MeshInstance3D.new()
	grip.mesh = CylinderMesh.new()
	grip.mesh.top_radius = 0.065
	grip.mesh.bottom_radius = 0.065
	grip.mesh.height = 0.12
	grip.mesh.material = wrap_mat
	grip.position = Vector3(0, -0.02, 0)
	add_child(grip)

	# --- Upper limb pivot + segments ---
	_upper_pivot = Node3D.new()
	_upper_pivot.position = Vector3(0, 0.08, 0)  # top of riser
	add_child(_upper_pivot)
	_build_limb(_upper_pivot, UPPER_LIMB)

	# Upper tip marker (placed beyond last segment)
	_upper_tip = Node3D.new()
	var last_up: Dictionary = UPPER_LIMB[UPPER_LIMB.size() - 1]
	_upper_tip.position = last_up.pos + Vector3(0, last_up.h * 0.5 + 0.01, 0)
	_upper_pivot.add_child(_upper_tip)

	# --- Lower limb pivot + segments ---
	_lower_pivot = Node3D.new()
	_lower_pivot.position = Vector3(0, -0.08, 0)  # bottom of riser
	add_child(_lower_pivot)
	_build_limb(_lower_pivot, LOWER_LIMB)

	# Lower tip marker
	_lower_tip = Node3D.new()
	var last_lo: Dictionary = LOWER_LIMB[LOWER_LIMB.size() - 1]
	_lower_tip.position = last_lo.pos + Vector3(0, -last_lo.h * 0.5 - 0.01, 0)
	_lower_pivot.add_child(_lower_tip)

	# --- Nock point (where arrow nocks, center of string) ---
	_nock_point = Node3D.new()
	_nock_point.position = Vector3(0.07, 0, -0.08)
	add_child(_nock_point)

	# --- String material ---
	_string_mat = StandardMaterial3D.new()
	_string_mat.albedo_color = Color(0.9, 0.85, 0.6)
	_string_mat.roughness = 0.4
	_string_mat.emission_enabled = true
	_string_mat.emission = Color(0.6, 0.7, 1.0)
	_string_mat.emission_energy_multiplier = 0.0

	# --- String segments (upper and lower) ---
	_string_upper = _make_string_segment()
	add_child(_string_upper)
	_string_lower = _make_string_segment()
	add_child(_string_lower)

	# Store rest lengths (straight line from tip to nock at rest)
	var rest_up_tip: Vector3 = _get_tip_local(_upper_tip)
	var rest_lo_tip: Vector3 = _get_tip_local(_lower_tip)
	var rest_nock: Vector3 = _nock_point.position
	_string_upper_rest_len = rest_up_tip.distance_to(rest_nock)
	_string_lower_rest_len = rest_lo_tip.distance_to(rest_nock)

	# Position strings for the first time
	_update_string(0.0)

	# --- Charge orb ---
	_orb_mat = StandardMaterial3D.new()
	_orb_mat.albedo_color = Color(0.3, 0.6, 1.0, 0.3)
	_orb_mat.emission_enabled = true
	_orb_mat.emission = Color(0.2, 0.5, 1.0)
	_orb_mat.emission_energy_multiplier = 0.0
	_orb_mat.roughness = 0.1
	_orb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_charge_orb = MeshInstance3D.new()
	_charge_orb.mesh = SphereMesh.new()
	_charge_orb.mesh.radius = 0.03
	_charge_orb.mesh.height = 0.06
	_charge_orb.mesh.material = _orb_mat
	_charge_orb.position = _nock_point.position
	_charge_orb.visible = false
	add_child(_charge_orb)

	# --- Muzzle flash light ---
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(0.4, 0.7, 1.0)
	_flash_light.light_energy = 0.0
	_flash_light.omni_range = 3.0
	_flash_light.position = _nock_point.position
	add_child(_flash_light)

	# Muzzle flash particles
	_setup_muzzle_particles()


func _make_string_segment() -> MeshInstance3D:
	var seg: MeshInstance3D = MeshInstance3D.new()
	# Use a thin box that's 1 unit long along Z; we'll scale it
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.006, 0.006, 1.0)
	box.material = _string_mat
	seg.mesh = box
	return seg


func _build_limb(pivot: Node3D, segments: Array[Dictionary]) -> void:
	for s in segments:
		var seg: MeshInstance3D = MeshInstance3D.new()
		seg.mesh = CylinderMesh.new()
		seg.mesh.top_radius = s.top_r
		seg.mesh.bottom_radius = s.bot_r
		seg.mesh.height = s.h

		var is_tip: bool = s.top_r < 0.015
		var mat: StandardMaterial3D
		if is_tip:
			mat = _dark
		else:
			mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.5, 0.3, 0.15)
			mat.roughness = 0.75
		seg.mesh.material = mat

		seg.position = s.pos
		seg.rotation = s.rot
		pivot.add_child(seg)

		# Add rune strip to this segment (skip very thin tips)
		if s.top_r >= 0.015:
			var avg_r: float = (s.top_r + s.bot_r) * 0.5
			var rune: MeshInstance3D = MeshInstance3D.new()
			rune.mesh = BoxMesh.new()
			rune.mesh.size = Vector3(avg_r * 2.2, s.h * 0.6, 0.005)
			rune.mesh.material = _rune_mat
			rune.position = Vector3(0, 0, 0.015)
			seg.add_child(rune)
			_rune_strips.append(rune)


func _get_tip_local(tip: Node3D) -> Vector3:
	# Convert tip's global position to bow's local space
	return to_local(tip.global_position)


func _update_string(charge_t: float) -> void:
	# Get tip positions in bow's local space
	var up_tip: Vector3 = _get_tip_local(_upper_tip)
	var lo_tip: Vector3 = _get_tip_local(_lower_tip)
	var nock: Vector3 = _nock_point.position

	# As charge increases, the nock pulls backward (toward the archer = positive Z)
	var pull: float = charge_t * 0.35
	var drawn_nock: Vector3 = nock + Vector3(0, 0, pull)

	# Position string segments between tip and drawn nock
	_position_string_segment(_string_upper, up_tip, drawn_nock)
	_position_string_segment(_string_lower, lo_tip, drawn_nock)


func _position_string_segment(seg: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var mid: Vector3 = (from + to) * 0.5
	var dir: Vector3 = to - from
	var length: float = dir.length()
	if length < 0.001:
		seg.visible = false
		return
	seg.visible = true
	seg.position = mid
	# Construct a proper basis: Z points along the string direction
	var z: Vector3 = dir.normalized()
	var up: Vector3 = Vector3.UP
	if abs(z.dot(up)) > 0.99:
		up = Vector3.RIGHT
	var x: Vector3 = up.cross(z).normalized()
	var y: Vector3 = z.cross(x).normalized()
	seg.transform.basis = Basis(x, y, z)
	# Scale Z to match the distance (box is 1 unit long in Z)
	seg.scale.z = length


func _setup_muzzle_particles() -> void:
	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 0, -1)
	pmat.spread = 50.0
	pmat.initial_velocity_min = 2.0
	pmat.initial_velocity_max = 7.0
	pmat.gravity = Vector3.ZERO
	pmat.scale_min = 0.02
	pmat.scale_max = 0.05

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.6, 0.85, 1.0, 1.0))
	gradient.add_point(0.3, Color(0.3, 0.6, 1.0, 0.8))
	gradient.add_point(0.6, Color(0.15, 0.3, 0.7, 0.4))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.05, 0.1, 0.3, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	pmat.color_ramp = grad_tex

	var pmesh := SphereMesh.new()
	pmesh.radius = 0.02
	pmesh.height = 0.04
	var pm_mat := StandardMaterial3D.new()
	pm_mat.albedo_color = Color(0.6, 0.85, 1.0)
	pm_mat.emission_enabled = true
	pm_mat.emission = Color(0.3, 0.6, 1.0)
	pm_mat.emission_energy_multiplier = 4.0
	pmesh.material = pm_mat

	_muzzle_particles = GPUParticles3D.new()
	_muzzle_particles.amount = 14
	_muzzle_particles.lifetime = 0.3
	_muzzle_particles.one_shot = true
	_muzzle_particles.emitting = false
	_muzzle_particles.explosiveness = 1.0
	_muzzle_particles.position = _nock_point.position
	_muzzle_particles.process_material = pmat
	_muzzle_particles.draw_pass_1 = pmesh
	add_child(_muzzle_particles)


func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			start_charge()
		else:
			release_arrow()


func start_charge() -> void:
	if is_charging:
		return
	if shoot_cooldown > 0:
		_pending_charge = true
		return
	_pending_charge = false
	is_charging = true
	charge_start_time = Time.get_ticks_msec()
	_charge_orb.visible = true
	AudioManager.play_bow_draw()


func cancel_charge() -> void:
	_pending_charge = false
	if not is_charging:
		return
	is_charging = false
	_reset_glow()
	_charge_orb.visible = false
	AudioManager.stop_bow_draw()
	# Reset limb flex, string, and bow position
	var snap_tween: Tween = create_tween()
	snap_tween.tween_method(_update_string, 0.0, 0.0, 0.1)
	snap_tween.parallel().tween_property(_upper_pivot, "rotation:x", 0.0, 0.1).set_ease(Tween.EASE_OUT)
	snap_tween.parallel().tween_property(_lower_pivot, "rotation:x", 0.0, 0.1).set_ease(Tween.EASE_OUT)
	snap_tween.parallel().tween_property(self, "position:z", -0.5, 0.1).set_ease(Tween.EASE_OUT)


func release_arrow() -> void:
	if not is_charging:
		return
	is_charging = false

	position = Vector3(0.35, -0.25, -0.5)

	var elapsed: float = (Time.get_ticks_msec() - charge_start_time) / 1000.0
	var charge_t: float = clamp(elapsed / MAX_CHARGE_TIME, 0.0, 1.0)
	var effective_t: float = 0.0 if elapsed < MIN_CHARGE_TIME else clamp((elapsed - MIN_CHARGE_TIME) / (MAX_CHARGE_TIME - MIN_CHARGE_TIME), 0.0, 1.0)
	var speed: float = lerp(MIN_ARROW_SPEED, MAX_ARROW_SPEED, effective_t)

	shoot_cooldown = SHOOT_DELAY

	var cam: Camera3D = get_parent() as Camera3D
	if cam:
		var origin: Vector3 = cam.global_position
		var direction: Vector3 = -cam.global_transform.basis.z
		arrow_fired.emit(origin, direction.normalized(), speed)

	AudioManager.play_bow_fire()

	# --- Release burst visual effects ---
	_muzzle_particles.restart()
	_muzzle_particles.emitting = true
	var burst_energy: float = 3.0 + charge_t * 5.0
	_flash_light.light_energy = burst_energy
	var flash_tween: Tween = create_tween()
	flash_tween.tween_property(_flash_light, "light_energy", 0.0, 0.15).set_ease(Tween.EASE_IN)

	_reset_glow()
	_charge_orb.visible = false

	# --- Limb snap-back + string vibration ---
	# Limbs spring back to rest
	var snap_tween: Tween = create_tween()
	snap_tween.parallel().tween_property(_upper_pivot, "rotation:x", 0.0, 0.08).set_ease(Tween.EASE_OUT)
	snap_tween.parallel().tween_property(_lower_pivot, "rotation:x", 0.0, 0.08).set_ease(Tween.EASE_OUT)

	# String snaps back with a tiny oscillation
	snap_tween.tween_method(func(v: float): _update_string(v), 0.0, 0.0, 0.06)

	# Recoil squash/stretch
	snap_tween.parallel().tween_property(self, "scale", Vector3(0.82, 0.82, 1.25), 0.04)
	snap_tween.tween_property(self, "scale", Vector3.ONE, 0.12)


func _reset_glow() -> void:
	_rune_mat.emission_energy_multiplier = 0.0
	_string_mat.emission_energy_multiplier = 0.0
	_orb_mat.emission_energy_multiplier = 0.0


func _process(delta: float) -> void:
	shoot_cooldown = max(shoot_cooldown - delta, 0.0)

	if _pending_charge and shoot_cooldown <= 0 and not is_charging:
		start_charge()

	# Idle sway — subtle breathing motion
	var idle_sway: float = sin(Time.get_ticks_msec() * 0.002) * 0.0015
	var idle_bob: float = sin(Time.get_ticks_msec() * 0.0015) * 0.001

	if not is_charging:
		# Keep string at rest
		_update_string(0.0)
		_upper_pivot.rotation.x = 0.0
		_lower_pivot.rotation.x = 0.0
		# Subtle idle sway
		position.x = 0.35 + idle_sway
		position.y = -0.25 + idle_bob
		position.z = -0.5
		return

	# --- Charging ---
	var elapsed: float = (Time.get_ticks_msec() - charge_start_time) / 1000.0
	var charge_t: float = clamp(elapsed / MAX_CHARGE_TIME, 0.0, 1.0)

	AudioManager.set_bow_draw_pitch(charge_t)

	# Whole bow pulls backward with the draw
	var bow_pull: float = charge_t * 0.12

	# Limb flex: rotate limb tips backward (away from the archer)
	# Positive rotation.x tilts top backward in Godot's camera-relative coordinates
	var flex: float = charge_t * MAX_FLEX_ANGLE
	_upper_pivot.rotation.x = flex
	_lower_pivot.rotation.x = -flex

	# String pulls back with charge
	_update_string(charge_t)

	# Charge glow ramps up quadratically
	var glow: float = charge_t * charge_t * 3.5
	_rune_mat.emission_energy_multiplier = glow
	_string_mat.emission_energy_multiplier = glow * 0.6
	_orb_mat.emission_energy_multiplier = glow * 2.5

	# Orb grows and brightens with charge
	var orb_scale: float = 1.0 + charge_t * 2.5
	_charge_orb.scale = Vector3(orb_scale, orb_scale, orb_scale)
	_orb_mat.albedo_color.a = 0.3 + charge_t * 0.7

	# Idle sway while charging (with bow pull backward from rest)
	position.x = 0.35 + idle_sway * 0.5
	position.y = -0.25 + idle_bob * 0.5
	position.z = -0.5 + bow_pull

	# Fully charged shake
	if charge_t >= 1.0:
		var shake: float = sin(Time.get_ticks_msec() * 0.05) * 0.003
		position.x = 0.35 + shake
		position.y = -0.25 + shake * 0.5