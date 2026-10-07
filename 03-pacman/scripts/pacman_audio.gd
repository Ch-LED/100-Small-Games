class_name PacmanAudio
extends Node
## Procedural chip-tune audio, same approach as space-invaders: every buffer
## is synthesised once at startup. No audio assets, no virtual audio device.
##
## Voices:
##   waka      two-tone chirp alternating on each pellet
##   power     low pulse when a power pellet is taken
##   eat_ghost rising arpeggio
##   fruit     bright pickup blip
##   siren     looping low pulse while ghosts hunt (pitch shifts with danger)
##   death     descending cadence
##   intro     short original opening motif

const MIX_RATE := 22050
const POOL_SIZE := 10

var _pool: Array[AudioStreamPlayer] = []
var _next := 0

var _waka: Array[AudioStreamWAV] = []
var _power: AudioStreamWAV
var _eat_ghost: AudioStreamWAV
var _fruit: AudioStreamWAV
var _death: AudioStreamWAV
var _intro: AudioStreamWAV
var _siren: Array[AudioStreamWAV] = []

var _siren_player: AudioStreamPlayer
var _siren_step := -1
var _waka_flip := false


func _ready() -> void:
	_waka.append(_sweep(520.0, 300.0, 0.055, 0.18))
	_waka.append(_sweep(300.0, 520.0, 0.055, 0.18))
	_power = _sweep(180.0, 90.0, 0.30, 0.22)
	_eat_ghost = _cadence([330.0, 440.0, 550.0], 0.07, 0.24)
	_fruit = _cadence([880.0, 1320.0], 0.09, 0.22)
	_death = _cadence([520.0, 440.0, 350.0, 260.0, 180.0], 0.16, 0.24)
	_intro = _cadence([392.0, 523.0, 659.0, 784.0, 659.0, 523.0], 0.14, 0.20)
	for i in 4:
		_siren.append(_sweep(120.0 + i * 26.0, 96.0 + i * 26.0, 0.34, 0.10))

	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)
	_siren_player = AudioStreamPlayer.new()
	_siren_player.volume_db = -6.0
	add_child(_siren_player)


# --- one-shots --------------------------------------------------------------

## Alternating two-tone chirp; call once per pellet eaten.
func play_waka() -> void:
	_play(_waka[1 if _waka_flip else 0])
	_waka_flip = not _waka_flip


func play_power() -> void:
	_play(_power)


func play_eat_ghost() -> void:
	_play(_eat_ghost)


func play_fruit() -> void:
	_play(_fruit)


func play_death() -> void:
	stop_siren()
	_play(_death)


func play_intro() -> void:
	_play(_intro)


func _play(stream: AudioStreamWAV) -> void:
	if stream == null or _pool.is_empty():
		return
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.play()


# --- siren ------------------------------------------------------------------

## `step` rises as the level gets more dangerous (more ghosts hunting, or an
## active power pellet); -1 silences it.
func set_siren(step: int) -> void:
	if step == _siren_step:
		return
	_siren_step = step
	if step < 0 or step >= _siren.size():
		stop_siren()
		return
	_siren_player.stream = _siren[step]
	_siren_player.play()


func stop_siren() -> void:
	_siren_step = -1
	_siren_player.stop()


## Stop everything on teardown — a still-playing stream keeps its playback
## object alive and leaks it if the process is torn down mid-note.
func _exit_tree() -> void:
	for player in _pool:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	if is_instance_valid(_siren_player):
		_siren_player.stop()
		_siren_player.stream = null


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
