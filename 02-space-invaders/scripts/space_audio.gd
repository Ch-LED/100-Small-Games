class_name SpaceAudio
extends Node
## Procedural chip-tune audio. Every buffer is synthesised once at startup —
## no external assets, no virtual audio device routing.
##
## Voice design (classic arcade flavour):
##   - background : one square tone, 4 pitches, one step per enemy tick
##   - shoot      : fast downward square sweep
##   - enemy hit  : short low blip
##   - player hit : decaying white noise
##   - ufo enter  : alternating two-pitch warble
##   - ufo killed : long downward sweep
##   - game over  : four-note descending cadence

const MIX_RATE := 22050
const POOL_SIZE := 8
const BG_STEPS: Array[float] = [110.0, 138.59, 164.81, 220.0]

var _bg_streams: Array[AudioStreamWAV] = []
var _shoot: AudioStreamWAV
var _enemy_hit: AudioStreamWAV
var _player_hit: AudioStreamWAV
var _ufo_enter: AudioStreamWAV
var _ufo_killed: AudioStreamWAV
var _game_over: AudioStreamWAV

var _pool: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for freq in BG_STEPS:
		_bg_streams.append(_square(freq, 0.11, 0.16))
	_shoot = _sweep(900.0, 220.0, 0.09, 0.22)
	_enemy_hit = _sweep(420.0, 160.0, 0.07, 0.20)
	_player_hit = _noise(0.35, 0.28)
	_ufo_enter = _warble(660.0, 990.0, 0.45, 0.16)
	_ufo_killed = _sweep(1300.0, 180.0, 0.32, 0.24)
	_game_over = _cadence([392.0, 330.0, 262.0, 196.0], 0.22, 0.24)

	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)


# --- playback ---------------------------------------------------------------

## One step of the marching background tone; call once per enemy tick.
func play_tick(count: int) -> void:
	if _bg_streams.is_empty():
		return
	_play(_bg_streams[count % _bg_streams.size()])


func play_shoot() -> void:
	_play(_shoot)


func play_enemy_hit() -> void:
	_play(_enemy_hit)


func play_player_hit() -> void:
	_play(_player_hit)


func play_ufo_enter() -> void:
	_play(_ufo_enter)


func play_ufo_killed() -> void:
	_play(_ufo_killed)


func play_game_over() -> void:
	_play(_game_over)


func _play(stream: AudioStreamWAV) -> void:
	if stream == null or _pool.is_empty():
		return
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
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


static func _sweep(from_freq: float, to_freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / maxf(1.0, float(count))
		phase += lerpf(from_freq, to_freq, t) / MIX_RATE
		var sample := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		data.encode_s16(i * 2, int(sample * (1.0 - t) * volume * 32767.0))
	return _wrap(data)


static func _noise(duration: float, volume: float) -> AudioStreamWAV:
	var count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261007
	for i in count:
		var decay := 1.0 - float(i) / maxf(1.0, float(count))
		data.encode_s16(i * 2, int(rng.randf_range(-1.0, 1.0) * decay * volume * 32767.0))
	return _wrap(data)


static func _warble(low: float, high: float, duration: float, volume: float) -> AudioStreamWAV:
	var count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var switch_every := maxi(1, int(MIX_RATE * 0.06))
	for i in count:
		var freq := low if (i / switch_every) % 2 == 0 else high
		phase += freq / MIX_RATE
		var sample := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		data.encode_s16(i * 2, int(sample * _envelope(i, count, switch_every) * volume * 32767.0))
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
