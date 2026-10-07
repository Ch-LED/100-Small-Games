class_name PongAudio
extends Node
## Procedural pong audio: every buffer is synthesised once at startup — no
## external assets. Mirrors 02-space-invaders/scripts/space_audio.gd; those
## synthesis helpers are a good candidate to extract into plugins/ later.
##
## Voices: paddle blip (pitch rises with ball speed), lower wall blip, a
## two-note point jingle, and a soft serve tone.

const MIX_RATE := 22050
const POOL_SIZE := 6

var _paddle: AudioStreamWAV
var _wall: AudioStreamWAV
var _score: AudioStreamWAV
var _serve: AudioStreamWAV

var _pool: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	_paddle = _square(520.0, 0.06, 0.22)
	_wall = _square(240.0, 0.05, 0.16)
	_score = _cadence([660.0, 440.0], 0.10, 0.20)
	_serve = _square(320.0, 0.08, 0.14)

	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)


## `speed_ratio` is the ball's current speed over its base speed; faster
## rallies sound brighter.
func play_paddle(speed_ratio: float) -> void:
	_play(_paddle, clampf(speed_ratio, 0.85, 2.2))


func play_wall() -> void:
	_play(_wall, 1.0)


func play_score() -> void:
	_play(_score, 1.0)


func play_serve() -> void:
	_play(_serve, 1.0)


func _play(stream: AudioStreamWAV, pitch: float) -> void:
	if stream == null or _pool.is_empty():
		return
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.pitch_scale = pitch
	player.play()


# --- synthesis --------------------------------------------------------------

static func _wrap(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


static func _square(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var period := float(MIX_RATE) / freq
	var fade := maxi(1, int(count * 0.12))
	for i in count:
		var high := fmod(float(i), period) / period < 0.5
		var sample := 1.0 if high else -1.0
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


## Short fade in/out so tones don't click at the edges.
static func _envelope(i: int, count: int, fade: int) -> float:
	if i < fade:
		return float(i) / float(fade)
	if i > count - fade:
		return maxf(0.0, float(count - i) / float(fade))
	return 1.0
