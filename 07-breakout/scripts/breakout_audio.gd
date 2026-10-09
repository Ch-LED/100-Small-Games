class_name BreakoutAudio
extends Node
## Procedural chip-tune audio, same approach as games 01-06: every buffer is
## synthesised once at startup. No audio assets.
##
## Voices:
##   brick    one tone per brick layer, the last layer highest — the original's
##            signature, retuned for bricks that take more than one hit
##   paddle   mid blip on the paddle
##   wall     lower blip on the side and top walls
##   lost     descending cadence
##   cleared  rising triad
##   launch   soft low blip
##   swing    fast rising whoosh, cut to the length of the lunge
##   catch    short rising pair when the retract catches the ball

const MIX_RATE := 22050
const POOL_SIZE := 8

var _pool: Array[AudioStreamPlayer] = []
var _next := 0

var _bricks: Array[AudioStreamWAV] = []
var _paddle: AudioStreamWAV
var _wall: AudioStreamWAV
var _lost: AudioStreamWAV
var _cleared: AudioStreamWAV
var _launch: AudioStreamWAV
var _swing: AudioStreamWAV
var _catch: AudioStreamWAV


func _ready() -> void:
	for freq in BreakoutSettings.load_all().field.layer_tones:
		_bricks.append(_tone(float(freq), 0.07, 0.20))
	_paddle = _tone(320.0, 0.06, 0.20)
	_wall = _tone(200.0, 0.05, 0.16)
	_lost = _cadence([392.0, 330.0, 262.0], 0.13, 0.22)
	_cleared = _cadence([523.0, 659.0, 784.0], 0.09, 0.20)
	_launch = _tone(300.0, 0.10, 0.18)
	_swing = _cadence([659.0, 988.0, 1319.0], 0.035, 0.14)
	_catch = _cadence([523.0, 784.0], 0.06, 0.18)

	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)


# --- one-shots --------------------------------------------------------------

## `layer` is the layer that just came off, 0 being the last one. `pitch` climbs
## with a combo, so a long run of bricks plays as a rising line.
func play_brick(layer: int, pitch := 1.0) -> void:
	if _bricks.is_empty():
		return
	_play(_bricks[clampi(layer, 0, _bricks.size() - 1)], pitch)


func play_paddle() -> void:
	_play(_paddle)


func play_wall() -> void:
	_play(_wall)


func play_lost() -> void:
	_play(_lost)


func play_cleared() -> void:
	_play(_cleared)


func play_launch() -> void:
	_play(_launch)


func play_swing() -> void:
	_play(_swing)


func play_catch() -> void:
	_play(_catch)


func _play(stream: AudioStreamWAV, pitch := 1.0) -> void:
	if stream == null or _pool.is_empty():
		return
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.pitch_scale = pitch
	player.play()


## Stop everything on teardown — a still-playing stream keeps its playback
## object alive and leaks it if the process is torn down mid-note.
func _exit_tree() -> void:
	for player in _pool:
		if is_instance_valid(player):
			player.stop()
			player.stream = null


# --- synthesis --------------------------------------------------------------

static func _square(phase: float) -> float:
	return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0


static func _to_stream(mix: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(mix.size() * 2)
	for i in mix.size():
		data.encode_s16(i * 2, int(clampf(mix[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


static func _envelope(i: int, count: int, fade: int) -> float:
	if i < fade:
		return float(i) / float(fade)
	if i > count - fade:
		return maxf(0.0, float(count - i) / float(fade))
	return 1.0


static func _tone(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var count := maxi(1, int(MIX_RATE * duration))
	var mix := PackedFloat32Array()
	mix.resize(count)
	var phase := 0.0
	var fade := maxi(1, int(float(count) * 0.08))
	for i in count:
		phase += freq / float(MIX_RATE)
		mix[i] = _square(phase) * _envelope(i, count, fade) * volume
	return _to_stream(mix)


static func _cadence(freqs: Array, note: float, volume: float) -> AudioStreamWAV:
	var per := maxi(1, int(MIX_RATE * note))
	var mix := PackedFloat32Array()
	mix.resize(per * freqs.size())
	var fade := maxi(1, int(float(per) * 0.12))
	for n in freqs.size():
		var freq := float(freqs[n])
		for i in per:
			mix[n * per + i] = _square(freq * float(i) / float(MIX_RATE)) \
					* _envelope(i, per, fade) * volume
	return _to_stream(mix)
