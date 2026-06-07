extends Node3D

signal charge_changed(charge: float)
signal ultimate_fired()

var charge: float = 0.0
var cooldown: float = 0.0

const MAX_CHARGE: float = 1.0
const CHARGE_PER_DAMAGE: float = 0.02
const COOLDOWN_DURATION: float = 1.0

const ProjectileScript = preload("res://src/player/ultimate_projectile.gd")


func _ready() -> void:
	EventBus.damage_dealt.connect(_on_damage_dealt)


func _process(delta: float) -> void:
	cooldown = max(cooldown - delta, 0.0)


func _on_damage_dealt(amount: int) -> void:
	if charge >= MAX_CHARGE:
		return
	charge = min(charge + amount * CHARGE_PER_DAMAGE, MAX_CHARGE)
	charge_changed.emit(charge)
	if multiplayer.multiplayer_peer != null:
		var owner_id := get_multiplayer_authority()
		if owner_id != multiplayer.get_unique_id():
			rpc_id(owner_id, "_sync_charge", charge)


func can_fire() -> bool:
	return charge >= MAX_CHARGE and cooldown <= 0.0


func try_fire() -> bool:
	if not can_fire():
		return false

	charge = 0.0
	cooldown = COOLDOWN_DURATION
	charge_changed.emit(charge)

	var camera := get_parent() as Camera3D
	var origin := camera.global_position
	var direction := -camera.global_transform.basis.z

	if multiplayer.multiplayer_peer == null:
		_spawn_projectile_at(origin, direction.normalized())
	elif multiplayer.is_server():
		rpc("_spawn_ultimate_projectile", origin, direction.normalized())
	else:
		rpc_id(NetworkManager.SERVER_ID, "_request_ultimate", origin, direction.normalized())

	var bow := camera.get_node_or_null("Bow") as Node3D
	if bow:
		bow.cancel_charge()
		bow.visible = false

	AudioManager.play_ultimate_fire()
	_shake_camera(0.025, 0.3)
	_flash_camera(5.0, 0.1)
	ultimate_fired.emit()

	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(func():
		if is_instance_valid(bow):
			bow.visible = true
	)

	return true


@rpc("any_peer", "call_remote", "reliable")
func _request_ultimate(origin: Vector3, direction: Vector3) -> void:
	if not multiplayer.is_server():
		return
	charge = 0.0
	charge_changed.emit(charge)
	var owner_id := get_multiplayer_authority()
	if owner_id != multiplayer.get_unique_id():
		rpc_id(owner_id, "_sync_charge", charge)
	rpc("_spawn_ultimate_projectile", origin, direction)


@rpc("any_peer", "call_remote", "unreliable")
func _sync_charge(val: float) -> void:
	charge = val
	charge_changed.emit(charge)


@rpc("any_peer", "call_local", "reliable")
func _spawn_ultimate_projectile(origin: Vector3, direction: Vector3) -> void:
	_spawn_projectile_at(origin, direction)


func _spawn_projectile_at(origin: Vector3, direction: Vector3) -> void:
	var projectile := Node3D.new()
	projectile.set_script(ProjectileScript)
	var auth := multiplayer.multiplayer_peer == null or multiplayer.is_server()
	get_tree().current_scene.add_child(projectile)
	projectile.setup(origin, direction, auth)


func _shake_camera(amount: float, duration: float) -> void:
	var camera := get_parent() as Camera3D
	if not camera:
		return
	var orig_rot_x := camera.rotation.x
	var orig_rot_y := camera.rotation.y
	var tween := create_tween()
	tween.tween_method(func(progress: float):
		if not is_instance_valid(camera):
			tween.kill()
			return
		var decay: float = max(1.0 - progress, 0.0)
		camera.rotation.x = orig_rot_x + randf_range(-amount, amount) * decay
		camera.rotation.y = orig_rot_y + randf_range(-amount, amount) * decay
	, 0.0, 1.0, duration)
	tween.tween_callback(func():
		if is_instance_valid(camera):
			camera.rotation.x = orig_rot_x
			camera.rotation.y = orig_rot_y
	)


func _flash_camera(fov_increase: float, duration: float) -> void:
	var camera := get_parent() as Camera3D
	if not camera:
		return
	var orig_fov := camera.fov
	var tween := create_tween()
	tween.tween_property(camera, "fov", orig_fov + fov_increase, 0.05).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "fov", orig_fov, duration).set_ease(Tween.EASE_IN)
