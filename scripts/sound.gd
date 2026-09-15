class_name MazeSound
extends Node

var effects: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var cursor: int = 0
var muted = false
var ambience: AudioStreamPlayer

func _ready() -> void:
	# Automated headless runs have no output device or audio mixing thread.
	if DisplayServer.get_name() == "headless":
		muted = true
		return
	var specs = {
		"coin": [880.0, 1320.0, 0.22, 0.03],
		"swing": [180.0, 65.0, 0.2, 0.75],
		"hit": [150.0, 48.0, 0.16, 0.7],
		"hurt": [120.0, 48.0, 0.3, 0.4],
		"block": [460.0, 200.0, 0.3, 0.3],
		"step": [100.0, 40.0, 0.07, 0.8],
		"buy": [520.0, 1040.0, 0.5, 0.0],
		"heal": [400.0, 800.0, 0.55, 0.0],
		"growl": [65.0, 38.0, 0.65, 0.35],
		"defeat": [110.0, 24.0, 0.5, 0.45],
		"win": [440.0, 880.0, 1.4, 0.0]
	}
	for key in specs:
		effects[key] = synth(specs[key])
	for i in range(10):
		var voice = AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	ambience = AudioStreamPlayer.new()
	add_child(ambience)
	ambience.stream = drone()
	ambience.volume_db = -24
	ambience.play()

func synth(spec: Array) -> AudioStreamWAV:
	var rate = 22050
	var frames = int(spec[2] * rate)
	var bytes = PackedByteArray()
	bytes.resize(frames * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 41
	var phase: float = 0
	for i in range(frames):
		var t = float(i) / frames
		phase += lerpf(spec[0], spec[1], t) * TAU / rate
		var tone = sin(phase) * 0.65 + sin(phase * 2.003) * 0.2
		var value = lerpf(tone, rng.randf_range(-1, 1), spec[3])
		value *= pow(1.0 - t, 2) * minf(1.0, t * 45) * 0.65
		bytes.encode_s16(i * 2, int(value * 32767))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	return stream

func drone() -> AudioStreamWAV:
	var rate = 22050
	var duration = 8
	var bytes = PackedByteArray()
	bytes.resize(rate * duration * 2)
	for i in range(rate * duration):
		var t = float(i) / rate
		var value = sin(t * TAU * 55) * 0.24 + sin(t * TAU * 82.5) * 0.12 + sin(t * TAU * 110) * 0.05
		value *= 0.6 + 0.2 * sin(t * TAU / duration)
		bytes.encode_s16(i * 2, int(value * 32767))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = rate * duration
	return stream

func play(effect: String, volume: float = 1.0) -> void:
	if muted or not effects.has(effect):
		return
	var voice = voices[cursor % voices.size()]
	cursor += 1
	voice.stream = effects[effect]
	voice.volume_db = linear_to_db(maxf(volume, 0.001)) - 8
	voice.pitch_scale = randf_range(0.94, 1.05)
	voice.play()

func toggle_mute() -> void:
	if not is_instance_valid(ambience):
		return
	muted = not muted
	ambience.volume_db = -80 if muted else -24

func _exit_tree() -> void:
	# Explicitly release active sample playbacks before the audio server exits.
	for voice in voices:
		voice.stop()
		voice.stream = null
	if is_instance_valid(ambience):
		ambience.stop()
		ambience.stream = null
	effects.clear()
