extends Node
class_name ChunkManager

const CHUNK_SIZE := 64
const LOAD_RADIUS := 3

var world_gen: WorldGen
var player: Node3D

var _active_chunks: Dictionary = {}    # Vector2i -> TerrainChunk
var _chunk_pool: Array[TerrainChunk] = []
var _pending_keys: Dictionary = {}     # Vector2i -> true

var _thread_mutex: Mutex = Mutex.new()
var _completed_queue: Array[Dictionary] = []  # [{key, arrays}]

const MAX_BUILDS_PER_FRAME := 2
const MAX_REMOVALS_PER_FRAME := 4

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

func generate_initial_chunks() -> void:
	for x in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for z in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var key := Vector2i(x, z)
			var arrays := TerrainChunk.generate_arrays(world_gen, key)
			_finish_chunk(key, arrays)

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return

	var pcx := floori(player.global_position.x / CHUNK_SIZE)
	var pcz := floori(player.global_position.z / CHUNK_SIZE)
	var center := Vector2i(pcx, pcz)

	var needed: Array[Vector2i] = []
	for x in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for z in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			needed.append(center + Vector2i(x, z))

	var to_remove: Array[Vector2i] = []
	for key in _active_chunks:
		if key not in needed:
			to_remove.append(key)
	to_remove.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return a.distance_squared_to(center) > b.distance_squared_to(center)
	)

	var removed := 0
	for key in to_remove:
		if removed >= MAX_REMOVALS_PER_FRAME:
			break
		var chunk: TerrainChunk = _active_chunks.get(key)
		if chunk:
			_active_chunks.erase(key)
			_recycle_chunk(chunk)
			removed += 1

	for key in needed:
		if _active_chunks.has(key) or _pending_keys.has(key):
			continue
		_pending_keys[key] = true
		WorkerThreadPool.add_task(_generate_on_thread.bind(key))

	_thread_mutex.lock()
	var queue := _completed_queue.duplicate()
	_completed_queue.clear()
	_thread_mutex.unlock()

	var built := 0
	var carry: Array[Dictionary] = []
	for item in queue:
		_pending_keys.erase(item.key)
		if built < MAX_BUILDS_PER_FRAME and not _active_chunks.has(item.key):
			_finish_chunk(item.key, item.arrays)
			built += 1
		else:
			carry.append(item)

	if carry.size() > 0:
		_thread_mutex.lock()
		_completed_queue = carry + _completed_queue
		_thread_mutex.unlock()

func _generate_on_thread(key: Vector2i) -> void:
	var arrays := TerrainChunk.generate_arrays(world_gen, key)
	_thread_mutex.lock()
	_completed_queue.append({key = key, arrays = arrays})
	_thread_mutex.unlock()

func _finish_chunk(key: Vector2i, arrays: Array) -> void:
	if _active_chunks.has(key):
		return
	var chunk := _get_chunk_from_pool()
	chunk.build_from_arrays(key, arrays)
	chunk.visible = true
	_active_chunks[key] = chunk

func _get_chunk_from_pool() -> TerrainChunk:
	if _chunk_pool.is_empty():
		var new_chunk := TerrainChunk.new()
		add_child(new_chunk)
		return new_chunk
	return _chunk_pool.pop_back()

func _recycle_chunk(chunk: TerrainChunk) -> void:
	chunk.visible = false
	chunk.mesh_instance.mesh = null
	chunk.collision_shape.shape = null
	_chunk_pool.append(chunk)

func get_active_biome_at(wx: float, wz: float) -> int:
	var cx := floori(wx / CHUNK_SIZE)
	var cz := floori(wz / CHUNK_SIZE)
	var key := Vector2i(cx, cz)
	if _active_chunks.has(key):
		return int(world_gen.get_biome(wx, wz))
	return -1
