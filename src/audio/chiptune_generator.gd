extends Node
class_name ChiptuneGenerator

const C3 := 130.81
const D3 := 146.83
const E3 := 164.81
const F3 := 174.61
const G3 := 196.00
const A3 := 220.00
const B3 := 246.94
const C4 := 261.63
const D4 := 293.66
const E4 := 329.63
const F4 := 349.23
const G4 := 392.00
const A4 := 440.00
const B4 := 493.88
const C5 := 523.25
const D5 := 587.33
const E5 := 659.25
const F5 := 698.46
const G5 := 783.99
const A5 := 880.00


static func overworld_theme() -> AudioStreamWAV:
	var melody := {
		notes = [
			[C4, 1.0], [E4, 1.0], [G4, 1.0], [C5, 1.0],
			[B3, 1.0], [D4, 1.0], [G4, 1.0], [B4, 1.0],
			[A3, 1.0], [C4, 1.0], [E4, 1.0], [A4, 1.0],
			[F3, 0.5], [G3, 0.5], [A3, 0.5], [C4, 0.5],
			[F4, 0.5], [E4, 0.5], [C4, 0.5], [G3, 0.5],
		],
		waveform = SoundGenerator.Waveform.SQUARE,
		vol_db = -10.0,
		pulse_width = 0.25,
	}

	var bass := {
		notes = [
			[C2(), 2.0], [C2(), 2.0],
			[G2(), 2.0], [G2(), 2.0],
			[A2(), 2.0], [A2(), 2.0],
			[F2(), 2.0], [G2(), 1.0], [C2(), 1.0],
		],
		waveform = SoundGenerator.Waveform.TRIANGLE,
		vol_db = -14.0,
	}

	var total_beats := 16.0
	var kick := {
		notes = _percussion_pattern(total_beats, func(b: int) -> Array: return [[80.0, 0.15], [0.0, 0.85]] if b % 2 == 0 else [[0.0, 1.0]]),
		waveform = SoundGenerator.Waveform.TRIANGLE,
		vol_db = -12.0,
	}

	var snare := {
		notes = _percussion_pattern(total_beats, func(b: int) -> Array: return [[200.0, 0.1], [0.0, 0.9]] if b % 2 == 1 else [[0.0, 1.0]]),
		waveform = SoundGenerator.Waveform.NOISE,
		vol_db = -16.0,
	}

	return compose_song([melody, bass, kick, snare], 110)

static func _percussion_pattern(beats: float, note_fn: Callable) -> Array:
	var notes: Array = []
	for b in range(int(beats)):
		for n in note_fn.call(b):
			notes.append(n)
	return notes


static func compose_song(voices: Array, bpm: float = 120.0) -> AudioStreamWAV:
	var sr := SoundGenerator.SAMPLE_RATE
	var spb := 60.0 / bpm

	var total_beats := 0.0
	for voice in voices:
		var voice_beats := 0.0
		for note in voice.notes:
			voice_beats += note[1]
		total_beats = max(total_beats, voice_beats)

	var num_samples := maxi(int(sr * total_beats * spb), 1)
	var accum := PackedFloat32Array()
	accum.resize(num_samples)
	accum.fill(0.0)

	for voice in voices:
		var notes: Array = voice.notes
		var waveform: int = voice.get("waveform", SoundGenerator.Waveform.SQUARE)
		var vol_db: float = voice.get("vol_db", -6.0)
		var pulse_width: float = voice.get("pulse_width", 0.5)
		var amp := db_to_linear(vol_db)
		var beat_cursor := 0.0

		for note in notes:
			var freq: float = note[0]
			var dur_beats: float = note[1]
			var start_sample := int(beat_cursor * spb * sr)
			var dur_samples := int(dur_beats * spb * sr)

			if freq > 0.0 and dur_samples > 0:
				for i in dur_samples:
					var idx := start_sample + i
					if idx >= num_samples:
						break
					var t := float(i) / sr
					var phase := fmod(t * freq, 1.0)
					var s := SoundGenerator._waveform_sample(waveform, phase, pulse_width)
					var env := SoundGenerator._envelope(i, dur_samples)
					accum[idx] += s * amp * env

			beat_cursor += dur_beats

	var max_val := 0.0
	for i in num_samples:
		var av := absf(accum[i])
		if av > max_val:
			max_val = av

	var scale := 1.0
	if max_val > 1.0:
		scale = 1.0 / max_val

	var fade_samples := mini(int(sr * 0.008), num_samples)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in num_samples:
		var s := accum[i] * scale * 0.5
		var fade := 1.0
		if i > num_samples - fade_samples:
			fade = float(num_samples - i) / fade_samples
		var val := int(clamp(s * fade * 32767.0, -32768.0, 32767.0))
		data.encode_s16(i * 2, val)

	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sr
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = num_samples
	return wav


static func C2() -> float: return C3 / 2.0
static func G2() -> float: return G3 / 2.0
static func A2() -> float: return A3 / 2.0
static func F2() -> float: return F3 / 2.0
