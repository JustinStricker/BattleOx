extends Node
class_name SoundGenerator

enum Waveform { SINE, SQUARE, TRIANGLE, SAWTOOTH, NOISE }

const SAMPLE_RATE := 44100


static func square_wave(freq: float, duration: float, vol_db: float = -3.0) -> AudioStreamWAV:
	return _generate(Waveform.SQUARE, freq, duration, vol_db, 0.5)


static func square_wave_looping(freq: float, vol_db: float = -6.0) -> AudioStreamWAV:
	var period_samples := maxi(int(SAMPLE_RATE / freq), 1)
	var data := PackedByteArray()
	data.resize(period_samples * 2)
	var amp := db_to_linear(vol_db)
	for i in period_samples:
		var phase := float(i) / period_samples
		var sample := 1.0 if phase < 0.5 else -1.0
		var val := int(clamp(sample * amp * 0.5 * 32767.0, -32768.0, 32767.0))
		data.encode_s16(i * 2, val)

	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = period_samples
	return wav


static func triangle_wave(freq: float, duration: float, vol_db: float = -3.0) -> AudioStreamWAV:
	return _generate(Waveform.TRIANGLE, freq, duration, vol_db)


static func triangle_wave_looping(freq: float, vol_db: float = -6.0) -> AudioStreamWAV:
	var period_samples := maxi(int(SAMPLE_RATE / freq), 1)
	var data := PackedByteArray()
	data.resize(period_samples * 2)
	var amp := db_to_linear(vol_db)
	for i in period_samples:
		var phase := float(i) / period_samples
		var sample: float = 2.0 * abs(2.0 * phase - 1.0) - 1.0
		var val := int(clamp(sample * amp * 0.5 * 32767.0, -32768.0, 32767.0))
		data.encode_s16(i * 2, val)

	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = period_samples
	return wav


static func sine_wave(freq: float, duration: float, vol_db: float = -3.0) -> AudioStreamWAV:
	return _generate(Waveform.SINE, freq, duration, vol_db)


static func noise_burst(duration: float, vol_db: float = -3.0) -> AudioStreamWAV:
	var num_samples := maxi(int(SAMPLE_RATE * duration), 1)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	var amp := db_to_linear(vol_db)
	for i in num_samples:
		var sample := randf_range(-1.0, 1.0)
		var env := _envelope(i, num_samples)
		var val := int(clamp(sample * amp * env * 32767.0, -32768.0, 32767.0))
		data.encode_s16(i * 2, val)

	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	return wav


static func frequency_sweep(start_freq: float, end_freq: float, duration: float, waveform: Waveform = Waveform.SQUARE, vol_db: float = -3.0) -> AudioStreamWAV:
	var num_samples := maxi(int(SAMPLE_RATE * duration), 1)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	var amp := db_to_linear(vol_db)
	for i in num_samples:
		var t := float(i) / SAMPLE_RATE
		var progress := float(i) / num_samples
		var freq: float = lerp(start_freq, end_freq, progress)
		var phase := fmod(t * freq, 1.0)
		var sample := _waveform_sample(waveform, phase, 0.5)
		var env := _envelope(i, num_samples)
		var val := int(clamp(sample * amp * env * 32767.0, -32768.0, 32767.0))
		data.encode_s16(i * 2, val)

	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	return wav


static func arpeggio(notes: Array[float], duration_per_note: float, waveform: Waveform = Waveform.SQUARE, vol_db: float = -3.0) -> AudioStreamWAV:
	var total_duration := duration_per_note * notes.size()
	var num_samples := maxi(int(SAMPLE_RATE * total_duration), 1)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	var amp := db_to_linear(vol_db)
	for i in num_samples:
		var t := float(i) / SAMPLE_RATE
		var note_idx := mini(int(t / duration_per_note), notes.size() - 1)
		var note_t := t - note_idx * duration_per_note
		var freq := notes[note_idx]
		var phase := fmod(note_t * freq, 1.0)
		var sample := _waveform_sample(waveform, phase, 0.5)
		var env := _envelope(i, num_samples)
		var val := int(clamp(sample * amp * env * 32767.0, -32768.0, 32767.0))
		data.encode_s16(i * 2, val)

	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	return wav


static func layered_square(freqs: Array[float], duration: float, vol_db: float = -6.0) -> AudioStreamWAV:
	var num_samples := maxi(int(SAMPLE_RATE * duration), 1)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	var amp := db_to_linear(vol_db)
	for i in num_samples:
		var t := float(i) / SAMPLE_RATE
		var sample := 0.0
		for freq in freqs:
			var phase := fmod(t * freq, 1.0)
			sample += 1.0 if phase < 0.5 else -1.0
		sample /= freqs.size()
		var env := _envelope(i, num_samples)
		var val := int(clamp(sample * amp * env * 32767.0, -32768.0, 32767.0))
		data.encode_s16(i * 2, val)

	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	return wav


static func layered_sine(freqs: Array[float], duration: float, vol_db: float = -6.0) -> AudioStreamWAV:
	var num_samples := maxi(int(SAMPLE_RATE * duration), 1)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	var amp := db_to_linear(vol_db)
	for i in num_samples:
		var t := float(i) / SAMPLE_RATE
		var sample := 0.0
		for freq in freqs:
			sample += sin(fmod(t * freq, 1.0) * TAU)
		sample /= freqs.size()
		var env := _envelope(i, num_samples)
		var val := int(clamp(sample * amp * env * 32767.0, -32768.0, 32767.0))
		data.encode_s16(i * 2, val)

	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	return wav


static func _generate(waveform: Waveform, freq: float, duration: float, vol_db: float, pulse_width: float = 0.5) -> AudioStreamWAV:
	var num_samples := maxi(int(SAMPLE_RATE * duration), 1)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	var amp := db_to_linear(vol_db)
	for i in num_samples:
		var t := float(i) / SAMPLE_RATE
		var phase := fmod(t * freq, 1.0)
		var sample := _waveform_sample(waveform, phase, pulse_width)
		var env := _envelope(i, num_samples)
		var val := int(clamp(sample * amp * env * 32767.0, -32768.0, 32767.0))
		data.encode_s16(i * 2, val)

	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	return wav


static func _waveform_sample(waveform: Waveform, phase: float, pulse_width: float) -> float:
	match waveform:
		Waveform.SINE:
			return sin(phase * TAU)
		Waveform.SQUARE:
			return 1.0 if phase < pulse_width else -1.0
		Waveform.TRIANGLE:
			return 2.0 * abs(2.0 * phase - 1.0) - 1.0
		Waveform.SAWTOOTH:
			return 2.0 * phase - 1.0
		Waveform.NOISE:
			return randf_range(-1.0, 1.0)
	return 0.0


static func _envelope(i: int, num_samples: int) -> float:
	return _adsr_envelope(i, num_samples, 0.003, 0.02, 1.0, 0.006)


static func _adsr_envelope(i: int, num_samples: int, attack_s: float, decay_s: float, sustain_level: float, release_s: float) -> float:
	var attack_samples := int(SAMPLE_RATE * attack_s)
	var decay_samples := int(SAMPLE_RATE * decay_s)
	var release_samples := int(SAMPLE_RATE * release_s)
	var sustain_start := attack_samples + decay_samples
	var release_start := num_samples - release_samples

	if i < attack_samples and attack_samples > 0:
		return float(i) / attack_samples
	elif i < sustain_start and decay_samples > 0:
		var decay_progress := float(i - attack_samples) / decay_samples
		return 1.0 - (1.0 - sustain_level) * decay_progress
	elif i >= release_start and release_samples > 0:
		var release_progress := float(i - release_start) / release_samples
		return sustain_level * (1.0 - release_progress)
	return sustain_level


static func _note_envelope(i: int, dur_samples: int) -> float:
	return _adsr_envelope(i, dur_samples, 0.005, 0.03, 0.75, 0.01)


static func apply_low_pass(data: PackedByteArray, cutoff_hz: float) -> PackedByteArray:
	if cutoff_hz <= 0.0 or cutoff_hz >= SAMPLE_RATE * 0.5:
		return data
	var rc := 1.0 / (TAU * cutoff_hz)
	var dt := 1.0 / SAMPLE_RATE
	var alpha := dt / (rc + dt)
	var out := PackedByteArray()
	out.resize(data.size())
	var prev_l := 0.0
	var prev_r := 0.0
	var num_frames := data.size() / 4
	for i in num_frames:
		var idx := i * 4
		var xl := data.decode_s16(idx) / 32767.0
		var xr := data.decode_s16(idx + 2) / 32767.0
		prev_l += alpha * (xl - prev_l)
		prev_r += alpha * (xr - prev_r)
		out.encode_s16(idx, int(clamp(prev_l * 32767.0, -32768.0, 32767.0)))
		out.encode_s16(idx + 2, int(clamp(prev_r * 32767.0, -32768.0, 32767.0)))
		out.encode_s16(idx + 1, 0)
		out.encode_s16(idx + 3, 0)
	return out


static func apply_high_pass(data: PackedByteArray, cutoff_hz: float) -> PackedByteArray:
	if cutoff_hz <= 0.0 or cutoff_hz >= SAMPLE_RATE * 0.5:
		return data
	var rc := 1.0 / (TAU * cutoff_hz)
	var dt := 1.0 / SAMPLE_RATE
	var alpha := rc / (rc + dt)
	var out := PackedByteArray()
	out.resize(data.size())
	var prev_xl := 0.0
	var prev_xr := 0.0
	var prev_yl := 0.0
	var prev_yr := 0.0
	var num_frames := data.size() / 4
	for i in num_frames:
		var idx := i * 4
		var xl := data.decode_s16(idx) / 32767.0
		var xr := data.decode_s16(idx + 2) / 32767.0
		var yl := alpha * (prev_yl + xl - prev_xl)
		var yr := alpha * (prev_yr + xr - prev_xr)
		prev_xl = xl
		prev_xr = xr
		prev_yl = yl
		prev_yr = yr
		out.encode_s16(idx, int(clamp(yl * 32767.0, -32768.0, 32767.0)))
		out.encode_s16(idx + 2, int(clamp(yr * 32767.0, -32768.0, 32767.0)))
		out.encode_s16(idx + 1, 0)
		out.encode_s16(idx + 3, 0)
	return out


static func find_zero_crossing_forward(data: PackedByteArray, start_frame: int, search_frames: int) -> int:
	var num_frames := data.size() / 4
	var end := mini(start_frame + search_frames, num_frames)
	if start_frame >= num_frames:
		return num_frames - 1
	var prev := data.decode_s16(start_frame * 4) / 32767.0
	for i in range(start_frame + 1, end):
		var cur := data.decode_s16(i * 4) / 32767.0
		if (prev >= 0.0 and cur < 0.0) or (prev <= 0.0 and cur > 0.0):
			return i
		prev = cur
	return end - 1
