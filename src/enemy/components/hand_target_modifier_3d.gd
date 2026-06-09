extends SkeletonModifier3D
class_name HandTargetModifier3D

## Drives fist bones toward an attack target position during combat.
## Used by Stone Golem to make its punches visually align with the hitbox.

## Set by enemy.gd each frame during attacks.
var attack_target_pos: Vector3 = Vector3.ZERO
## 0.0 = idle, 0.0-1.0 = attack progress (0 = wind-up, 0.5 = strike, 1.0 = recover).
var attack_phase: float = 0.0
## Whether currently attacking.
var is_attacking: bool = false

## Fist bone indices (set during initialization).
var fist_bone_left: int = -1
var fist_bone_right: int = -1

var _skel: Skeleton3D
var _initialized: bool = false


func initialize(skel: Skeleton3D, p_fist_left: int, p_fist_right: int) -> void:
	_skel = skel
	fist_bone_left = p_fist_left
	fist_bone_right = p_fist_right
	_initialized = true


func _process_modification() -> void:
	if not _initialized or not _skel:
		return
	if not is_attacking or fist_bone_left < 0:
		return

	# During wind-up phase (0.0 - strike_start), pull fists back
	# During strike phase (strike_start - strike_end), thrust fists forward
	# During recover, return to rest
	var target_local := _skel.to_local(attack_target_pos)

	# Apply positional bias toward target during strike
	var strike_bias := 0.0
	if attack_phase > 0.3 and attack_phase < 0.7:
		# Peak of strike — maximum reach
		strike_bias = clampf((attack_phase - 0.3) / 0.4, 0.0, 1.0)
		strike_bias = sin(strike_bias * PI)  # Bell curve

	if strike_bias > 0.01:
		var rest_pos := _skel.get_bone_rest(fist_bone_left).origin
		# Interpolate toward target direction
		var reach := target_local.normalized() * strike_bias * 0.15
		_skel.set_bone_pose_position(fist_bone_left, rest_pos + reach)
		_skel.set_bone_pose_position(fist_bone_right, rest_pos + reach)