extends Node

var score: int = 0

const LoadingScreenScene = preload("res://src/ui/loading_screen.tscn")
const EnvironmentNode = preload("res://src/world/environment.gd")
const PlayerScene = preload("res://src/player/player.tscn")
const UIScene = preload("res://src/ui/ui.tscn")
const ArrowScript = preload("res://src/player/arrow.gd")
const ZombieManager = preload("res://src/enemies/zombie_manager.gd")
const BiomeOverlayScene = preload("res://src/world/biome_overlay.gd")

func _ready() -> void:
	var loading: CanvasLayer = LoadingScreenScene.instantiate()
	add_child(loading)

	loading.update("Generating heightmap...", 0.0)
	var world_gen: WorldGen = WorldGen.new()
	add_child(world_gen)
	await get_tree().process_frame

	loading.update("Building terrain and scattering foliage...", 0.15)
	var env: Node3D = EnvironmentNode.new()
	env.world_gen = world_gen
	add_child(env)
	await get_tree().process_frame
	
	var overlay := BiomeOverlayScene.new()
	overlay.world_gen = world_gen
	overlay.name = "BiomeOverlay"
	add_child(overlay)

	loading.update("Spawning entities...", 0.55)
	var player: CharacterBody3D = PlayerScene.instantiate()
	add_child(player)

	var spawn_pos: Vector3 = Vector3(0, 2.0, 0)
	for attempt in 20:
		var angle := randf() * TAU
		var dist := randf_range(0.0, 8.0)
		var sx := cos(angle) * dist
		var sz := sin(angle) * dist
		var h := world_gen.get_terrain_height(sx, sz)
		if h < world_gen.water_level - 0.5:
			continue
		var delta := world_gen.get_terrain_delta(sx, sz, 2.0)
		if delta > 0.3:
			continue
		spawn_pos = Vector3(sx, h + 1.5, sz)
		break
	player.position = spawn_pos

	var bow = player.get_node_or_null("Camera3D/Bow")
	if bow:
		bow.arrow_fired.connect(_on_arrow_fired)

	var ui: CanvasLayer = UIScene.instantiate()
	add_child(ui)

	var arrow_container: Node3D = Node3D.new()
	arrow_container.name = "Arrows"
	add_child(arrow_container)

	var zombie_mgr: Node = ZombieManager.new()
	zombie_mgr.world_gen = world_gen
	add_child(zombie_mgr)
	zombie_mgr.zombie_killed.connect(_on_zombie_killed.bind(ui))

	loading.update("Ready!", 1.0)
	await get_tree().create_timer(0.2).timeout

	var tween := create_tween()
	tween.tween_property(loading.get_node("ColorRect"), "modulate", Color(1, 1, 1, 0), 0.15)
	tween.parallel().tween_property(loading.get_node("VBoxContainer"), "modulate", Color(1, 1, 1, 0), 0.15)
	await tween.finished
	loading.queue_free()

	MusicManager.play_song(MusicManager.Song.OVERWORLD)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_arrow_fired(origin: Vector3, direction: Vector3, speed: float) -> void:
	var arrow_container: Node3D = get_node("Arrows")
	ArrowScript.spawn(arrow_container, origin, direction, speed)

func _on_zombie_killed(pts: int, ui: CanvasLayer) -> void:
	score += pts
	ui.set_score(score)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
