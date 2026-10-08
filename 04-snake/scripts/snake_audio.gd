class_name SnakeAudio
extends Node
## Procedural chip-tune audio, same approach as space-invaders / pacman: every
## buffer is synthesised once at startup. No audio assets.
##
## Voices:
##   eat       two-tone chirp alternating on each food
##   level_up  rising triad
##   death     descending cadence
##   start     soft low blip on a new run
##   music     looping cheerful chiptune bed (square melody over a triangle bass)

const MIX_RATE := 22050
const POOL_SIZE := 6

## --- background loop -------------------------------------------------------
## C major, 4/4, 128 BPM, 4 bars = 32 eighth notes, ~7.5 s. The chord walk is
## I - IV - V - I so the last bar lands back on C and the loop point is inaudible.
const MUSIC_BPM := 128.0
## Single knob to tune by ear: the mix peaks around 0.52, so this lands the bed
## clearly under the one-shot effects.
const MUSIC_VOLUME_DB := -10.0
const MELODY_GAIN := 0.30
const TRIANGLE_GAIN := 0.22

## Each entry is [midi note (0 = rest), length in eighth notes].
## Bars: C / F / G / C
const MELODY := [
	[72, 1], [76, 1], [79, 1], [76, 1], [72, 1], [76, 1], [79, 1], [81, 1],
	[81, 1], [79, 1], [77, 1], [76, 1], [74, 1], [76, 1], [77, 1], [74, 1],
	[79, 1], [77, 1], [76, 1], [74, 1], [76, 1], [74, 1], [72, 1], [71, 1],
	[72, 1], [76, 1], [79, 1], [84, 1], [79, 1], [76, 1], [72, 2],
]
## Root on the beat, octave up off the beat — a bouncy "oom-pah".
const BASS := [
	[48, 1], [0, 1], [60, 1], [0, 1], [48, 1], [0, 1], [60, 1], [0, 1],
	[53, 1], [0, 1], [65, 1], [0, 1], [53, 1], [0, 1], [65, 1], [0, 1],
	[55, 1], [0, 1], [67, 1], [0, 1], [55, 1], [0, 1], [67, 1], [0, 1],
	[48, 1], [0, 1], [60, 1], [0, 1], [48, 1], [0, 1], [60, 1], [0, 1],
]

var _pool: Array[AudioStreamPlayer] = []
var _next := 0

var _eat: Array[AudioStreamWAV] = []
var _level_up: AudioStreamWAV
var _death: AudioStreamWAV
var _start: AudioStreamWAV
var _eat_flip := false

var _music: AudioStreamWAV
var _music_player: AudioStreamPlayer


func _ready() -> void:
	_eat.append(_cadence([620.0], 0.055, 0.18))
	_eat.append(_cadence([880.0], 0.055, 0.18))
	_level_up = _cadence([523.0, 659.0, 784.0], 0.09, 0.20)
	_death = _cadence([520.0, 400.0, 300.0, 200.0], 0.14, 0.24)
	_start = _sweep(300.0, 220.0, 0.10, 0.16)

	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)

	_music = _build_music()
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = _music
	_music_player.volume_db = MUSIC_VOLUME_DB
	add_child(_music_player)


# --- one-shots --------------------------------------------------------------

func play_eat() -> void:
	_play(_eat[1 if _eat_flip else 0])
	_eat_flip = not _eat_flip


func play_level_up() -> void:
	_play(_level_up)


func play_death() -> void:
	_play(_death)


func play_start() -> void:
	_play(_start)


# --- music ------------------------------------------------------------------

func play_music() -> void:
	if _music_player != null and not _music_player.playing:
		_music_player.play()


func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()


func _play(stream: AudioStreamWAV) -> void:
	if stream == null or _pool.is_empty():
		return
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.play()


## Stop everything on teardown — a still-playing stream keeps its playback
## object alive and leaks it if the process is torn down mid-note.
func _exit_tree() -> void:
	for player in _pool:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	if is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.stream = null


# --- synthesis --------------------------------------------------------------

static func _wrap(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


static func _sweep(from_freq: float, to_freq: float, duration: float,
		volume: float) -> AudioStreamWAV:
	var count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var fade := maxi(1, int(count * 0.12))
	for i in count:
		var t := float(i) / maxf(1.0, float(count))
		phase += lerpf(from_freq, to_freq, t) / MIX_RATE
		var sample := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		data.encode_s16(i * 2, int(sample * _envelope(i, count, fade) * volume * 32767.0))
	return _wrap(data)


static func _cadence(freqs: Array[float], note: float, volume: float) -> AudioStreamWAV:
	var per_note := int(MIX_RATE * note)
	var total := per_note * freqs.size()
	var data := PackedByteArray()
	data.resize(total * 2)
	var fade := maxi(1, int(per_note * 0.1))
	for n in freqs.size():
		var period := float(MIX_RATE) / freqs[n]
		for i in per_note:
			var high := fmod(float(i), period) / period < 0.5
			var sample := 1.0 if high else -1.0
			var index := n * per_note + i
			data.encode_s16(index * 2,
					int(sample * _envelope(i, per_note, fade) * volume * 32767.0))
	return _wrap(data)


static func _envelope(i: int, count: int, fade: int) -> float:
	if i < fade:
		return float(i) / float(fade)
	if i > count - fade:
		return maxf(0.0, float(count - i) / float(fade))
	return 1.0


# --- music synthesis --------------------------------------------------------

## Renders both note tracks into one looping buffer. The buffer starts and ends
## near silence (every note's envelope opens and closes at zero), so the loop
## seam does not click.
static func _build_music() -> AudioStreamWAV:
	var eighth := 60.0 / (MUSIC_BPM * 2.0)
	var eighths := 0
	for note in MELODY:
		eighths += int(note[1])

	var frames := int(round(float(eighths) * eighth * float(MIX_RATE)))
	var mix := PackedFloat32Array()
	mix.resize(frames)
	_layer(mix, MELODY, eighth, MELODY_GAIN, false)
	_layer(mix, BASS, eighth, TRIANGLE_GAIN, true)
	return _wrap_loop(mix)


static func _layer(mix: PackedFloat32Array, notes: Array, eighth: float,
		gain: float, triangle: bool) -> void:
	var cursor := 0
	for note in notes:
		var midi: int = note[0]
		var length: int = note[1]
		var count := int(round(float(length) * eighth * float(MIX_RATE)))
		if midi > 0:
			var freq := 440.0 * pow(2.0, (float(midi) - 69.0) / 12.0)
			_render_note(mix, cursor, count, freq, gain, triangle)
		cursor += count


static func _render_note(mix: PackedFloat32Array, offset: int, count: int,
		freq: float, gain: float, triangle: bool) -> void:
	var phase := 0.0
	for i in count:
		var index := offset + i
		if index >= mix.size():
			return
		phase += freq / float(MIX_RATE)
		var cycle := fmod(phase, 1.0)
		var wave := 1.0 if cycle < 0.5 else -1.0
		if triangle:
			wave = 4.0 * absf(cycle - 0.5) - 1.0
		mix[index] += wave * _note_envelope(i, count) * gain


## Plucked shape: quick attack, decay to a sustain, ramp out at the tail.
static func _note_envelope(i: int, count: int) -> float:
	var attack := maxi(1, int(float(count) * 0.04))
	var release := maxi(1, int(float(count) * 0.25))
	if i < attack:
		return float(i) / float(attack)
	var level := lerpf(1.0, 0.55, minf(1.0, float(i - attack) / float(maxi(1, count - attack)) * 2.0))
	if i > count - release:
		level *= float(count - i) / float(release)
	return level


static func _wrap_loop(mix: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(mix.size() * 2)
	for i in mix.size():
		var sample := clampf(mix[i], -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32767.0))
	var stream := _wrap(data)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = mix.size()
	return stream
