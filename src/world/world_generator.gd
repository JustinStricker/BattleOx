extends Node
class_name WorldGen

enum Biome { OCEAN, MEADOWS, BLACK_FOREST, SWAMP, MOUNTAIN }

var world_size: float = 512.0
var water_level: float = 0.0
var seed_value: int

var _height_noise: FastNoiseLite
var _moisture_noise: FastNoiseLite
var _temperature_noise: FastNoiseLite
var _forest_noise: FastNoiseLite

var _vegetation_blockers: Array[Rect2] = []

func _init() -> void:
	seed_value = randi()
	_height_noise = _make_noise(0, 0.008, 5, 2.0, 0.5)
	_moisture_noise = _make_noise(1, 0.012, 3, 1.5, 0.5)
	_temperature_noise = _make_noise(2, 0.01, 3, 1.5, 0.5)
	_forest_noise = _make_noise(3, 0.02, 3, 2.0, 0.5)

func _make_noise(offset: int, freq: float, octaves: int, lacunarity: float, gain: float) -> FastNoiseLite:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = seed_value + offset
	n.noise_type = FastNoiseLite.TYPE_PERLIN
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	n.fractal_lacunarity = lacunarity
	n.fractal_gain = gain
	return n

func get_height(x: float, z: float) -> float:
	var raw := _height_noise.get_noise_2d(x, z)
	var h := raw * 4.5
	if h < -2.0:
		h = -2.0 + (h + 2.0) * 0.3
	if h > 4.0:
		h = 4.0 + (h - 4.0) * 0.5
	return h

func get_terrain_height(x: float, z: float, resolution: int = 200) -> float:
	var half_world: float = world_size * 0.5
	var step: float = world_size / float(resolution)
	var ix: float = floor((x + half_world) / step)
	var iz: float = floor((z + half_world) / step)
	var x0: float = -half_world + ix * step
	var z0: float = -half_world + iz * step

	var u: float = (x - x0) / step
	var v: float = (z - z0) / step

	var h00: float = get_height(x0, z0)
	var h10: float = get_height(x0 + step, z0)
	var h01: float = get_height(x0, z0 + step)
	var h11: float = get_height(x0 + step, z0 + step)

	return lerp(lerp(h00, h10, u), lerp(h01, h11, u), v)

func get_elevation(x: float, z: float) -> float:
	return _height_noise.get_noise_2d(x, z)

func get_moisture(x: float, z: float) -> float:
	return _moisture_noise.get_noise_2d(x, z) * 0.5 + 0.5

func get_temperature(x: float, z: float) -> float:
	return _temperature_noise.get_noise_2d(x, z) * 0.5 + 0.5

func get_forest(x: float, z: float) -> float:
	return _forest_noise.get_noise_2d(x, z) * 0.5 + 0.5

func get_biome(x: float, z: float) -> Biome:
	var elev := get_elevation(x, z)
	var moist := get_moisture(x, z)
	var temp := get_temperature(x, z)

	if elev < -0.15:
		return Biome.OCEAN
	if elev > 0.65:
		return Biome.MOUNTAIN
	if moist > 0.55 and elev < 0.35 and elev > -0.05:
		return Biome.SWAMP
	if moist > 0.25 and elev < 0.5 and elev > 0.0:
		return Biome.BLACK_FOREST
	return Biome.MEADOWS

func get_biome_name(biome: Biome) -> String:
	match biome:
		Biome.OCEAN: return "Ocean"
		Biome.MEADOWS: return "Meadows"
		Biome.BLACK_FOREST: return "BlackForest"
		Biome.SWAMP: return "Swamp"
		Biome.MOUNTAIN: return "Mountain"
	return "Unknown"

func get_terrain_delta(x: float, z: float, radius: float) -> float:
	var count := 12
	var min_h := 1e10
	var max_h := -1e10
	for i in count:
		var angle := float(i) / float(count) * TAU
		var sx := x + cos(angle) * radius
		var sz := z + sin(angle) * radius
		var h := get_height(sx, sz)
		if h < min_h: min_h = h
		if h > max_h: max_h = h
	return max_h - min_h

func add_vegetation_blocker(rect: Rect2) -> void:
	_vegetation_blockers.append(rect)

func is_blocked(x: float, z: float) -> bool:
	for r in _vegetation_blockers:
		if r.has_point(Vector2(x, z)):
			return true
	return false

func get_vegetation_blockers() -> Array[Rect2]:
	return _vegetation_blockers

func biome_color(biome: Biome, x: float, z: float, h: float) -> Color:
	match biome:
		Biome.OCEAN:
			return Color(0.35, 0.45, 0.4)
		Biome.MEADOWS:
			var g := 0.3 + get_moisture(x, z) * 0.25
			return Color(g * 0.25, g * 1.1 + 0.05, g * 0.1)
		Biome.BLACK_FOREST:
			var g := 0.25 + get_moisture(x, z) * 0.2
			return Color(g * 0.2, g * 1.0 + 0.05, g * 0.08)
		Biome.SWAMP:
			return Color(0.25, 0.28, 0.18)
		Biome.MOUNTAIN:
			var bright := 0.35 + (h / 8.0) * 0.4
			bright = clamp(bright, 0.3, 0.75)
			return Color(bright, bright, bright)
	return Color(0.3, 0.5, 0.2)

func sample_biome_color(x: float, z: float) -> Color:
	var h := get_height(x, z)
	var biome := get_biome(x, z)

	if biome == Biome.MEADOWS or biome == Biome.BLACK_FOREST or biome == Biome.MOUNTAIN:
		return biome_color(biome, x, z, h)

	var step := 2.0
	var colors: Array[Color] = []
	var weights: Array[float] = []
	for ox_int in [-1, 1]:
		for oz_int in [-1, 1]:
			var ox := float(ox_int)
			var oz := float(oz_int)
			var sx := x + ox * step
			var sz := z + oz * step
			var sb := get_biome(sx, sz)
			colors.append(biome_color(sb, sx, sz, get_height(sx, sz)))
			var dist := Vector2(x - sx, z - sz).length()
			weights.append(1.0 / max(dist, 0.01))
	var total_w := 0.0
	for w in weights: total_w += w
	var r := 0.0; var g := 0.0; var b := 0.0
	for i in colors.size():
		var w := weights[i] / total_w
		r += colors[i].r * w
		g += colors[i].g * w
		b += colors[i].b * w
	return Color(r, g, b)
