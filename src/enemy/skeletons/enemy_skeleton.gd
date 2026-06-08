class_name EnemySkeleton
extends Node3D
## Abstract base class for all enemy skeletons.
## Subclasses must implement build(), update_animation(), play_hit_flinch(),
## play_death_animation(), and set_attack_timer().

var body_scale: float = 1.0
signal death_animation_finished


func build(_type: EnemyType, _scale_val: float) -> void:
	push_error("EnemySkeleton.build() not implemented by subclass")


func update_animation(_delta: float, _is_moving: bool, _is_attacking: bool,
		_is_surprised: bool, _speed: float, _target_dir: Vector3 = Vector3.FORWARD) -> void:
	pass


func play_hit_flinch() -> void:
	pass


func play_death_animation() -> void:
	pass


func set_attack_timer(_val: float) -> void:
	pass