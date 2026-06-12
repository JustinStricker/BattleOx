extends Node

var _sfx_player: AudioStreamPlayer
var _sfx_playback: AudioStreamPlaybackPolyphonic
var _sounds: Dictionary = {}

var _bow_draw_stream_idx: int = -1
const BOW_DRAW_BASE_FREQ := 150.0

var _last_play_times: Dictionary = {}
const DEFAULT_COOLDOWN := 0.05
const RAPID_FIRE_COOLDOWN := 0.1
var _cooldowns: Dictionary = {
	"beam_tick": RAPID_FIRE_COOLDOWN,
	"enemy_hit": RAPID_FIRE_COOLDOWN,
	"enemy_attack": RAPID_FIRE_COOLDOWN,
}


func _ready() -> void:
	_setup_buses()
	_generate_all_sounds()
	_setup_sfx_player()


func _exit_tree() -> void:
	if _sfx_player:
		_sfx_player.stop()
		_sfx_playback = null
		remove_child(_sfx_player)
		_sfx_player.free()


func _setup_buses() -> void:
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")


func _setup_sfx_player() -> void:
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX"
	var poly := AudioStreamPolyphonic.new()
	poly.polyphony = 32
	_sfx_player.stream = poly
	add_child(_sfx_player)
	_sfx_player.play()
	_sfx_playback = _sfx_player.get_stream_playback()


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


func _play(sound_id: String, pitch_scale: float = 1.0, vol_offset_db: float = 0.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var cooldown: float = _cooldowns.get(sound_id, DEFAULT_COOLDOWN)
	var last_time: float = _last_play_times.get(sound_id, -1.0)
	if now - last_time < cooldown:
		return
	_last_play_times[sound_id] = now

	var stream: AudioStreamWAV = _sounds.get(sound_id)
	if not stream:
		return
	if not _sfx_playback:
		return
	_sfx_playback.play_stream(stream, 0.0, vol_offset_db, pitch_scale)


func _play_noise(sound_id: String, noise_id: String, pitch_scale: float = 1.0) -> void:
	_play(sound_id, pitch_scale, 0.0)
	var noise_stream: AudioStreamWAV = _sounds.get(noise_id)
	if noise_stream and _sfx_playback:
		_sfx_playback.play_stream(noise_stream, 0.0, 0.0, pitch_scale)


func play_bow_draw() -> void:
	if _bow_draw_stream_idx >= 0 and _sfx_playback:
		_sfx_playback.set_stream_volume(_bow_draw_stream_idx, -12.0)
		return
	if not _sfx_playback:
		return
	_bow_draw_stream_idx = _sfx_playback.play_stream(_sounds["bow_draw"], 0.0, -12.0, 1.0)


func set_bow_draw_pitch(charge_t: float) -> void:
	if _bow_draw_stream_idx >= 0 and _sfx_playback:
		_sfx_playback.set_stream_pitch_scale(_bow_draw_stream_idx, 1.0 + charge_t * 1.5)


func stop_bow_draw() -> void:
	if _bow_draw_stream_idx >= 0 and _sfx_playback:
		_sfx_playback.stop_stream(_bow_draw_stream_idx)
	_bow_draw_stream_idx = -1


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
