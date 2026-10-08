class_name Game2048Audio
extends Node
## Procedural chip-tune audio, same approach as games 01-07: every buffer is
## synthesised once at startup. No audio assets.
##
## Voices:
##   slide      short low click, only when a move actually shifted something
##   merge      one tone per doubling; the higher the tile, the higher the note
##   reached    rising motif when 2048 first appears
##   over       descending cadence
##   start      soft low blip

const MIX_RATE := 22050
const POOL_SIZE := 8

var _pool: Array[AudioStreamPlayer] = []
var _next := 0

var _slide: AudioStreamWAV
var _merges: Array[AudioStreamWAV] = []
var _reached: AudioStreamWAV
var _over: AudioStreamWAV
var _start: AudioStreamWAV


func _ready() -> void:
	for freq in Game2048Settings.load_all().audio.merge_tones:
		_merges.append(_tone(float(freq), 0.10, 0.20))
	_slide = _tone(160.0, 0.05, 0.14)
	_reached = _cadence([523.0, 659.0, 784.0, 1047.0], 0.11, 0.22)
	_over = _cadence([392.0, 330.0, 262.0], 0.14, 0.22)
	_start = _tone(300.0, 0.10, 0.18)

	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)


# --- one-shots --------------------------------------------------------------

func play_slide() -> void:
	_play(_slide)


## `value` is the tile the merge produced; index 1 is the value 2.
func play_merge(value: int) -> void:
	if _merges.is_empty() or value < 2:
		return
	var index := int(round(log(float(value)) / log(2.0))) - 1
	_play(_merges[clampi(index, 0, _merges.size() - 1)])


func play_reached() -> void:
	_play(_reached)


func play_over() -> void:
	_play(_over)


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
	var fade := maxi(1, int(float(count) * 0.12))
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
