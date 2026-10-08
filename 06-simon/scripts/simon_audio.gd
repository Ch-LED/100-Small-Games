class_name SimonAudio
extends Node
## Procedural chip-tune audio, same approach as games 01-05: every buffer is
## synthesised once at startup. No audio assets.
##
## Voices:
##   tone    one per pad: a C-major tetrad, square wave
##   error   noise burst plus a descending sweep, played together
##   start   short rising motif

const MIX_RATE := 22050
const POOL_SIZE := 6
const NOISE_SEED := 0x51A0
## One per pad, in PAD_UP / PAD_RIGHT / PAD_DOWN / PAD_LEFT order. A C-major
## tetrad keeps the four pads far apart in pitch; it is not a claim to reproduce
## the original toy's exact notes.
const TONE_HZ: Array[float] = [261.63, 329.63, 392.00, 523.25]

var _pool: Array[AudioStreamPlayer] = []
var _next := 0

var _tones: Array[AudioStreamWAV] = []
var _error: Array[AudioStreamWAV] = []
var _start: AudioStreamWAV


func _ready() -> void:
	for freq in TONE_HZ:
		_tones.append(_tone(freq, 0.22, 0.20))
	_error.append(_burst(0.50, 0.30, 0.45))
	_error.append(_sweep(320.0, 70.0, 0.50, 0.18))
	_start = _cadence([392.0, 523.0, 659.0], 0.09, 0.20)

	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)


# --- one-shots --------------------------------------------------------------

## The tone belonging to one pad.
func play_tone(pad: int) -> void:
	if _tones.is_empty():
		return
	_play(_tones[clampi(pad, 0, _tones.size() - 1)])


func play_error() -> void:
	for stream in _error:
		_play(stream)


func play_start() -> void:
	_play(_start)


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


## Short fade in and out, so notes start and stop without a click.
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
	var fade := maxi(1, int(float(count) * 0.06))
	for i in count:
		phase += freq / float(MIX_RATE)
		mix[i] = _square(phase) * _envelope(i, count, fade) * volume
	return _to_stream(mix)


static func _sweep(from_freq: float, to_freq: float, duration: float,
		volume: float) -> AudioStreamWAV:
	var count := maxi(1, int(MIX_RATE * duration))
	var mix := PackedFloat32Array()
	mix.resize(count)
	var phase := 0.0
	var fade := maxi(1, int(float(count) * 0.12))
	for i in count:
		var t := float(i) / float(count)
		phase += lerpf(from_freq, to_freq, t) / float(MIX_RATE)
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


## White noise through a one-pole low pass, decaying exponentially: the dull
## thud of "wrong". Normalised first so the level does not collapse with smoothing.
static func _burst(duration: float, volume: float, smooth: float) -> AudioStreamWAV:
	var count := maxi(1, int(MIX_RATE * duration))
	var mix := PackedFloat32Array()
	mix.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED
	var low := 0.0
	var attack := maxi(1, int(float(count) * 0.02))
	var decay := 6.0 / maxf(0.05, duration)
	for i in count:
		low = lerpf(rng.randf_range(-1.0, 1.0), low, clampf(smooth, 0.0, 0.99))
		mix[i] = low * minf(1.0, float(i) / float(attack)) \
				* exp(-decay * float(i) / float(MIX_RATE))
	var peak := 0.0
	for value in mix:
		peak = maxf(peak, absf(value))
	if peak > 0.0:
		var scale := volume / peak
		for i in count:
			mix[i] *= scale
	return _to_stream(mix)
