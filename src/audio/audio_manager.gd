extends Node

var _pool: Array[AudioStreamPlayer] = []
var _sounds: Dictionary = {}

var _bow_draw_player: AudioStreamPlayer = null

const BOW_DRAW_BASE_FREQ := 150.0


func _ready() -> void:
	_generate_all_sounds()


func _generate_all_sounds() -> void:
	_sounds["bow_draw"] = SoundGenerator.triangle_wave_looping(BOW_DRAW_BASE_FREQ, -12.0)
	_sounds["bow_fire"] = SoundGenerator.frequency_sweep(600.0, 1200.0, 0.08, SoundGenerator.Waveform.SINE, -3.0)
	_sounds["sword_slash"] = SoundGenerator.frequency_sweep(300.0, 100.0, 0.12, SoundGenerator.Waveform.TRIANGLE, -6.0)
	_sounds["sword_slash_noise"] = SoundGenerator.noise_burst(0.05, -14.0)
	_sounds["sword_hit"] = SoundGenerator.triangle_wave(120.0, 0.08, -8.0)
	_sounds["enemy_hit"] = SoundGenerator.triangle_wave(180.0, 0.06, -8.0)
	_sounds["enemy_death"] = SoundGenerator.frequency_sweep(120.0, 30.0, 0.15, SoundGenerator.Waveform.TRIANGLE, -10.0)
	_sounds["enemy_attack"] = SoundGenerator.triangle_wave(55.0, 0.15, -10.0)
	_sounds["collect"] = SoundGenerator.arpeggio([523.25, 659.25, 783.99, 1046.5], 0.06, SoundGenerator.Waveform.TRIANGLE, -6.0)
	_sounds["arrow_hit"] = SoundGenerator.arpeggio([659.25, 783.99, 987.77], 0.03, SoundGenerator.Waveform.SINE, -12.0)
	_sounds["player_hit"] = SoundGenerator.triangle_wave(130.0, 0.12, -8.0)
	_sounds["player_death"] = SoundGenerator.arpeggio([523.25, 493.88, 440.0, 392.0, 349.23, 329.63, 293.66, 261.63], 0.06, SoundGenerator.Waveform.TRIANGLE, -6.0)
	_sounds["jump"] = SoundGenerator.layered_sine([600.0, 630.0], 0.15, -12.0)
	_sounds["jump_launch"] = SoundGenerator.layered_sine([600.0, 630.0], 0.25, -10.0)
	_sounds["land"] = SoundGenerator.triangle_wave(60.0, 0.04, -14.0)
	_sounds["roll"] = SoundGenerator.frequency_sweep(300.0, 100.0, 0.1, SoundGenerator.Waveform.SINE, -12.0)
	_sounds["ultimate_fire"] = SoundGenerator.frequency_sweep(200.0, 300.0, 0.18, SoundGenerator.Waveform.TRIANGLE, -6.0)
	_sounds["ultimate_fire_noise"] = SoundGenerator.noise_burst(0.08, -12.0)
	_sounds["beam_tick"] = SoundGenerator.sine_wave(900.0, 0.02, -14.0)
	_sounds["ui_confirm"] = SoundGenerator.arpeggio([880.0, 1100.0], 0.03, SoundGenerator.Waveform.SINE, -10.0)
	_sounds["ui_cancel"] = SoundGenerator.arpeggio([440.0, 330.0], 0.04, SoundGenerator.Waveform.SINE, -10.0)


func _get_player() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing:
			p.volume_db = 0.0
			p.pitch_scale = 1.0
			return p
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	add_child(p)
	_pool.append(p)
	return p


func _play(sound_id: String, pitch_scale: float = 1.0, vol_offset_db: float = 0.0) -> void:
	var stream: AudioStreamWAV = _sounds.get(sound_id)
	if not stream:
		return
	var player := _get_player()
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.volume_db = vol_offset_db
	player.play()


func _play_noise(sound_id: String, noise_id: String, pitch_scale: float = 1.0) -> void:
	_play(sound_id, pitch_scale, 0.0)
	var noise_stream: AudioStreamWAV = _sounds.get(noise_id)
	if noise_stream:
		var nplayer := _get_player()
		nplayer.stream = noise_stream
		nplayer.pitch_scale = pitch_scale
		nplayer.play()


func play_bow_draw() -> void:
	if _bow_draw_player and _bow_draw_player.playing:
		return
	_bow_draw_player = _get_player()
	_bow_draw_player.stream = _sounds["bow_draw"]
	_bow_draw_player.volume_db = -12.0
	_bow_draw_player.play()


func set_bow_draw_pitch(charge_t: float) -> void:
	if _bow_draw_player and _bow_draw_player.playing:
		_bow_draw_player.pitch_scale = 1.0 + charge_t * 1.5


func stop_bow_draw() -> void:
	if _bow_draw_player:
		_bow_draw_player.stop()
		_bow_draw_player = null


func play_bow_fire() -> void:
	_play("bow_fire", 1.0, 0.0)
	stop_bow_draw()


func play_sword_slash() -> void:
	_play_noise("sword_slash", "sword_slash_noise", 1.0)


func play_sword_hit() -> void:
	_play("sword_hit", 1.0, -4.0)


func play_enemy_hit() -> void:
	_play("enemy_hit", randf_range(0.9, 1.1), -4.0)


func play_enemy_death() -> void:
	_play("enemy_death", randf_range(0.85, 1.15), -2.0)


func play_enemy_attack() -> void:
	_play("enemy_attack", randf_range(0.9, 1.1), -4.0)


func play_collect() -> void:
	_play("collect", randf_range(0.95, 1.05), -4.0)


func play_arrow_hit() -> void:
	_play("arrow_hit", 1.0, -6.0)


func play_player_hit() -> void:
	_play("player_hit", 1.0, -4.0)


func play_player_death() -> void:
	_play("player_death", 1.0, -2.0)


func play_jump(charge: float) -> void:
	if charge >= 0.95:
		_play("jump_launch", 1.0, -4.0)
	else:
		_play("jump", 1.0, -6.0)


func play_land() -> void:
	_play("land", 1.0, 0.0)


func play_roll() -> void:
	_play("roll", 1.0, -6.0)


func play_ultimate_fire() -> void:
	_play_noise("ultimate_fire", "ultimate_fire_noise", 1.0)


func play_beam_tick() -> void:
	_play("beam_tick", randf_range(0.9, 1.1), -10.0)


func play_ui_confirm() -> void:
	_play("ui_confirm", 1.0, -6.0)


func play_ui_cancel() -> void:
	_play("ui_cancel", 1.0, -6.0)
