class_name HitFX
extends Node3D

static var _particle_mat: ParticleProcessMaterial
static var _spark_mat: ParticleProcessMaterial


static func _init_mat() -> void:
	if _particle_mat:
		return

	_particle_mat = ParticleProcessMaterial.new()
	_particle_mat.direction = Vector3.UP
	_particle_mat.spread = 180.0
	_particle_mat.initial_velocity_min = 1.0
	_particle_mat.initial_velocity_max = 4.0
	_particle_mat.scale_min = 0.03
	_particle_mat.scale_max = 0.1
	_particle_mat.color = Color(0.85, 0.1, 0.02)

	_spark_mat = ParticleProcessMaterial.new()
	_spark_mat.direction = Vector3.UP
	_spark_mat.spread = 30.0
	_spark_mat.initial_velocity_min = 2.0
	_spark_mat.initial_velocity_max = 5.0
	_spark_mat.scale_min = 0.02
	_spark_mat.scale_max = 0.04
	_spark_mat.color = Color(1.0, 0.5, 0.05)


func _ready() -> void:
	_init_mat()
	var pos: Vector3 = global_position + Vector3.UP * 0.5

	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.process_material = _particle_mat
	particles.amount = 15
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.emitting = true
	add_child(particles)
	particles.global_position = pos

	var sparks: GPUParticles3D = GPUParticles3D.new()
	sparks.process_material = _spark_mat
	sparks.amount = 8
	sparks.lifetime = 0.25
	sparks.one_shot = true
	sparks.emitting = true
	add_child(sparks)
	sparks.global_position = pos

	var tween: Tween = create_tween().bind_node(self)
	tween.tween_interval(0.5)
	tween.tween_callback(queue_free)
