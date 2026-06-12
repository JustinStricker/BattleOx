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
	# Twinkle Twinkle Little Star — 120 BPM, 6 bars, C major.
	# Square wave lead, triangle bass, noise percussion.

	var melody := {
		notes = [
			[C4, 0.5, 0.9], [C4, 0.5, 0.9],
			[G4, 0.5, 0.9], [G4, 0.5, 0.9],
			[A4, 0.5, 0.9], [A4, 0.5, 0.9],
			[G4, 1.0, 0.9],
			[F4, 0.5, 0.85], [F4, 0.5, 0.85],
			[E4, 0.5, 0.85], [E4, 0.5, 0.85],
			[D4, 0.5, 0.85], [D4, 0.5, 0.85],
			[C4, 1.0, 0.9],
			[G4, 0.5, 0.85], [G4, 0.5, 0.85],
			[F4, 0.5, 0.85], [F4, 0.5, 0.85],
			[E4, 0.5, 0.85], [E4, 0.5, 0.85],
			[D4, 1.0, 0.85],
			[G4, 0.5, 0.85], [G4, 0.5, 0.85],
			[F4, 0.5, 0.85], [F4, 0.5, 0.85],
			[E4, 0.5, 0.85], [E4, 0.5, 0.85],
			[C4, 1.0, 0.9],
		],
		waveform = SoundGenerator.Waveform.SQUARE,
		vol_db = -6.0,
		vibrato_depth = 1.5,
		vibrato_rate = 5.0,
	}

	var bass := {
		notes = [
			[C2(), 2.0, 0.8], [C2(), 2.0, 0.7],
			[F2(), 2.0, 0.8], [F2(), 2.0, 0.7],
			[C2(), 2.0, 0.8], [C2(), 2.0, 0.7],
			[G2(), 2.0, 0.8], [G2(), 2.0, 0.7],
			[C2(), 2.0, 0.8], [C2(), 2.0, 0.7],
			[F2(), 2.0, 0.8], [F2(), 2.0, 0.7],
		],
		waveform = SoundGenerator.Waveform.TRIANGLE,
		vol_db = -14.0,
	}

	var drums := {
		notes = [
			[C4, 0.15, 0.9], [0.0, 0.35, 0.0],
			[C4, 0.15, 0.7], [0.0, 0.35, 0.0],
			[C4, 0.15, 0.9], [0.0, 0.35, 0.0],
			[C4, 0.15, 0.7], [0.0, 0.35, 0.0],
			[C4, 0.15, 0.9], [0.0, 0.35, 0.0],
			[C4, 0.15, 0.7], [0.0, 0.35, 0.0],
			[C4, 0.15, 0.9], [0.0, 0.35, 0.0],
			[C4, 0.15, 0.7], [0.0, 0.35, 0.0],
			[C4, 0.15, 0.9], [0.0, 0.35, 0.0],
			[C4, 0.15, 0.7], [0.0, 0.35, 0.0],
			[C4, 0.15, 0.9], [0.0, 0.35, 0.0],
			[C4, 0.15, 0.7], [0.0, 0.35, 0.0],
			[C4, 0.15, 0.9], [0.0, 0.35, 0.0],
			[C4, 0.15, 0.7], [0.0, 0.35, 0.0],
			[C4, 0.15, 0.9], [0.0, 0.35, 0.0],
			[C4, 0.15, 0.7], [0.0, 0.35, 0.0],
			[C4, 0.15, 0.9], [0.0, 0.35, 0.0],
			[C4, 0.15, 0.7], [0.0, 0.35, 0.0],
			[C4, 0.15, 0.9], [0.0, 0.35, 0.0],
			[C4, 0.15, 0.7], [0.0, 0.35, 0.0],
			[C4, 0.15, 0.9], [0.0, 0.35, 0.0],
			[C4, 0.15, 0.7], [0.0, 0.35, 0.0],
			[C4, 0.15, 0.9], [0.0, 0.35, 0.0],
			[C4, 0.15, 0.7], [0.0, 0.35, 0.0],
		],
		waveform = SoundGenerator.Waveform.NOISE,
		vol_db = -10.0,
	}

	return compose_song([melody, bass, drums], 120)


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
		var vibrato_depth: float = voice.get("vibrato_depth", 0.0)
		var vibrato_rate: float = voice.get("vibrato_rate", 5.0)
		var amp := db_to_linear(vol_db)
		var beat_cursor := 0.0

		for note in notes:
			var freq: float = note[0]
			var dur_beats: float = note[1]
			var velocity: float = note[2] if note.size() > 2 else 1.0
			var start_sample := int(beat_cursor * spb * sr)
			var dur_samples := int(dur_beats * spb * sr)

			if freq > 0.0 and dur_samples > 0:
				for i in dur_samples:
					var idx := start_sample + i
					if idx >= num_samples:
						break
					var t := float(i) / sr
					var note_progress := float(i) / dur_samples
					var note_freq := freq
					if vibrato_depth > 0.0 and note_progress > 0.1 and note_progress < 0.85:
						note_freq += _vibrato(t, vibrato_depth, vibrato_rate)
					var phase := fmod(t * note_freq, 1.0)
					var s := SoundGenerator._waveform_sample(waveform, phase, pulse_width)
					var env := SoundGenerator._note_envelope(i, dur_samples)
					accum[idx] += s * amp * env * velocity

			beat_cursor += dur_beats

	var max_val := 0.0
	for i in num_samples:
		var av := absf(accum[i])
		if av > max_val:
			max_val = av

	var scale := 1.0
	if max_val > 1.0:
		scale = 1.0 / max_val

	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in num_samples:
		var s := accum[i] * scale * 0.5
		var val := int(clamp(s * 32767.0, -32768.0, 32767.0))
		data.encode_s16(i * 2, val)

	var loop_end := SoundGenerator.find_zero_crossing_forward(data, num_samples - 128, 128)
	loop_end = maxi(loop_end, 1)

	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sr
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = loop_end
	return wav


static func _vibrato(t: float, depth: float, rate: float) -> float:
	return depth * sin(TAU * rate * t)


static func midi_to_freq(midi_note: int) -> float:
	return 440.0 * pow(2.0, (midi_note - 69) / 12.0)


static func C2() -> float: return C3 / 2.0
static func D2() -> float: return D3 / 2.0
static func E2() -> float: return E3 / 2.0
static func G2() -> float: return G3 / 2.0
static func A2() -> float: return A3 / 2.0
static func F2() -> float: return F3 / 2.0
