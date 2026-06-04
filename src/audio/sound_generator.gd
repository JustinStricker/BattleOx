extends Node
class_name SoundGenerator

enum Waveform { SINE, SQUARE, TRIANGLE, SAWTOOTH, NOISE }

const SAMPLE_RATE := 22050


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
	var attack_samples := int(SAMPLE_RATE * 0.003)
	var release_samples := int(SAMPLE_RATE * 0.006)
	if i < attack_samples:
		return float(i) / attack_samples
	elif i > num_samples - release_samples:
		return float(num_samples - i) / release_samples
	return 1.0
