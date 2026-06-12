extends Node
class_name AmbientDrone

var _player: AudioStreamPlayer
var _generator: AudioStreamGenerator

# Drone layers: A1, E2, A2, E3, A3 (open fifth harmony)
var _layer_freqs := [55.0, 82.5, 110.0, 165.0, 220.0]
var _layer_amps := [0.15, 0.1, 0.2, 0.1, 0.05]
var _layer_phases := [0.0, 0.0, 0.0, 0.0, 0.0]

# LFO state
var _lfo_phase := 0.0
var _lfo2_phase := 0.0

# Noise filter state
var _noise_phase := 0.0
var _noise_filter_state := 0.0

# Intensity (0.0 = sparse/dark, 1.0 = fuller/drone)
var intensity := 0.5


func _ready() -> void:
	set_process(false)
	_player = AudioStreamPlayer.new()
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = SoundGenerator.SAMPLE_RATE
	_generator.buffer_length = 0.2
	_player.stream = _generator
	_player.bus = "Music"
	add_child(_player)


func play() -> void:
	_player.play()
	set_process(true)


func stop() -> void:
	set_process(false)
	_player.stop()


func is_playing() -> bool:
	return _player.playing


func set_intensity(value: float) -> void:
	intensity = clampf(value, 0.0, 1.0)
	for i in _layer_amps.size():
		_layer_amps[i] = [0.15, 0.1, 0.2, 0.1, 0.05][i] * (0.3 + intensity * 0.7)


func _process(delta: float) -> void:
	if not _player.playing:
		return
	var playback: AudioStreamGeneratorPlayback = _player.get_stream_playback()
	if not playback:
		return

	var frames := playback.get_frames_available()
	if frames <= 0:
		return

	var mix_rate: float = _generator.mix_rate

	# Update LFOs (very slow modulation)
	_lfo_phase = fmod(_lfo_phase + delta * 0.1, 1.0)
	_lfo2_phase = fmod(_lfo2_phase + delta * 0.037, 1.0)

	for i in frames:
		var sample := 0.0

		# Drone layers — additive synthesis with slow pitch drift
		for l in _layer_freqs.size():
			var pitch_lfo: float = sin(_lfo_phase * TAU) * 0.5 + sin(_lfo2_phase * TAU) * 0.3
			var modulated_freq: float = float(_layer_freqs[l]) * (1.0 + pitch_lfo * 0.02)
			var phase_inc: float = modulated_freq / float(mix_rate)
			_layer_phases[l] = fmod(_layer_phases[l] + phase_inc, 1.0)
			var swell: float = 0.7 + 0.3 * sin(_lfo_phase * TAU * 0.5)
			sample += sin(_layer_phases[l] * TAU) * float(_layer_amps[l]) * swell

		# Filtered noise layer (wind)
		var noise: float = randf_range(-1.0, 1.0)
		var cutoff: float = 0.05 + intensity * 0.2
		_noise_filter_state = _noise_filter_state * (1.0 - cutoff) + noise * cutoff
		sample += _noise_filter_state * 0.08 * intensity

		# Sub-bass rumble (25 Hz, felt more than heard)
		_noise_phase = fmod(_noise_phase + 25.0 / mix_rate, 1.0)
		sample += sin(_noise_phase * TAU) * 0.04 * intensity

		# Soft clipping
		sample = tanh(sample * 0.8)

		playback.push_frame(Vector2(sample, sample))
