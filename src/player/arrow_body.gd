extends RigidBody3D

func _physics_process(_delta: float) -> void:
	var v := linear_velocity
	if v.length() > 0.1:
		look_at(global_position + v.normalized() * 100, Vector3.UP)