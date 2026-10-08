class_name AsteroidsAudio
extends Node
## Procedural chip-tune audio, same approach as games 01-04: every buffer is
## synthesised once at startup. No audio assets.
##
## Voices:
##   fire        short descending square blip
##   bang        three noise bursts, one per rock size
##   ship_death  long noise burst plus a descending tone, played together
##   extra_life  rising arpeggio
##   beat        two low tones alternating; the heartbeat of the game
##   thrust      looping low rumble while the engine is on
##   saucer      looping two-tone warble while the saucer is alive

const MIX_RATE := 22050
const POOL_SIZE := 8
## Noise is reproducible: the same seed every run, so the mix is stable.
const NOISE_SEED := 0x5EED1234

var _pool: Array[AudioStreamPlayer] = []
var _next := 0

var _fire: AudioStreamWAV
var _bang: Array[AudioStreamWAV] = []
var _ship_death: Array[AudioStreamWAV] = []
var _extra_life: AudioStreamWAV
var _beat: Array[AudioStreamWAV] = []

var _thrust_player: AudioStreamPlayer
var _saucer_player: AudioStreamPlayer


func _ready() -> void:
	_fire = _sweep(880.0, 280.0, 0.07, 0.20)
	_bang.append(_burst(0.42, 0.30, 0.42))
	_bang.append(_burst(0.30, 0.26, 0.34))
	_bang.append(_burst(0.20, 0.22, 0.26))
	_ship_death.append(_burst(0.70, 0.34, 0.5))
	_ship_death.append(_sweep(420.0, 60.0, 0.70, 0.18))
	_extra_life = _cadence([523.0, 659.0, 784.0, 1047.0], 0.09, 0.22)
	_beat.append(_cadence([88.0], 0.09, 0.26))
	_beat.append(_cadence([72.0], 0.09, 0.26))

	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)

	_thrust_player = _make_loop_player(_warble_loop([64.0], 0.25, 0.22, 96.0), -5.0)
	_saucer_player = _make_loop_player(_warble_loop([392.0, 300.0], 0.16, 0.24, 0.0), -4.0)


# --- one-shots --------------------------------------------------------------

func play_fire() -> void:
	_play(_fire)


func play_bang(kind: int) -> void:
	_play(_bang[clampi(kind, 0, _bang.size() - 1)])


func play_ship_death() -> void:
	for stream in _ship_death:
		_play(stream)


func play_extra_life() -> void:
	_play(_extra_life)


## The heartbeat; `alternate` flips between the two tones.
func play_beat(alternate: bool) -> void:
	_play(_beat[1 if alternate else 0])


# --- loops ------------------------------------------------------------------

func set_thrust(on: bool) -> void:
	_set_loop(_thrust_player, on)


func set_saucer(on: bool) -> void:
	_set_loop(_saucer_player, on)


func stop_all_loops() -> void:
	set_thrust(false)
	set_saucer(false)


func _set_loop(player: AudioStreamPlayer, on: bool) -> void:
	if player == null or player.playing == on:
		return
	if on:
		player.play()
	else:
		player.stop()


func _make_loop_player(stream: AudioStreamWAV, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	return player


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
	for player in [_thrust_player, _saucer_player]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null


# --- synthesis --------------------------------------------------------------

static func _square(phase: float) -> float:
	return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0


static func _wrap(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


## Float mix -> 16-bit stream. Looping streams get LOOP_FORWARD over the whole
## buffer, so the caller only has to make the buffer itself seam-free.
static func _to_stream(mix: PackedFloat32Array, looping: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(mix.size() * 2)
	for i in mix.size():
		data.encode_s16(i * 2, int(clampf(mix[i], -1.0, 1.0) * 32767.0))
	var stream := _wrap(data)
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = mix.size()
	return stream


static func _envelope(i: int, count: int, fade: int) -> float:
	if i < fade:
		return float(i) / float(fade)
	if i > count - fade:
		return maxf(0.0, float(count - i) / float(fade))
	return 1.0


static func _sweep(from_freq: float, to_freq: float, duration: float,
		volume: float) -> AudioStreamWAV:
	var count := maxi(1, int(MIX_RATE * duration))
	var mix := PackedFloat32Array()
	mix.resize(count)
	var phase := 0.0
	var fade := maxi(1, int(count * 0.12))
	for i in count:
		var t := float(i) / float(count)
		phase += lerpf(from_freq, to_freq, t) / float(MIX_RATE)
		mix[i] = _square(phase) * _envelope(i, count, fade) * volume
	return _to_stream(mix, false)


static func _cadence(freqs: Array, note: float, volume: float) -> AudioStreamWAV:
	var per := maxi(1, int(MIX_RATE * note))
	var total := per * freqs.size()
	var mix := PackedFloat32Array()
	mix.resize(total)
	var fade := maxi(1, int(per * 0.12))
	for n in freqs.size():
		var freq := float(freqs[n])
		for i in per:
			mix[n * per + i] = _square(freq * float(i) / float(MIX_RATE)) \
					* _envelope(i, per, fade) * volume
	return _to_stream(mix, false)


## White noise through a one-pole low pass: `smooth` near 0 is a bright hiss,
## higher values give the duller thud of a big rock. Normalised first, so the
## perceived level does not collapse as `smooth` rises.
static func _burst(duration: float, volume: float, smooth: float) -> AudioStreamWAV:
	var count := maxi(1, int(MIX_RATE * duration))
	var mix := PackedFloat32Array()
	mix.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED
	var low := 0.0
	var attack := maxi(1, int(count * 0.02))
	var decay := 6.0 / maxf(0.05, duration)
	for i in count:
		low = lerpf(rng.randf_range(-1.0, 1.0), low, clampf(smooth, 0.0, 0.99))
		var env := minf(1.0, float(i) / float(attack)) * exp(-decay * float(i) / float(MIX_RATE))
		mix[i] = low * env
	_normalize(mix)
	var peak := volume
	for i in count:
		mix[i] *= peak
	return _to_stream(mix, false)


static func _normalize(mix: PackedFloat32Array) -> void:
	var peak := 0.0
	for value in mix:
		peak = maxf(peak, absf(value))
	if peak <= 0.0:
		return
	var scale := 1.0 / peak
	for i in mix.size():
		mix[i] *= scale


## Click-free loop. `freqs` are held one per slot; every frequency is snapped to
## a whole number of cycles per slot, and each slot's amplitude rides a raised
## sine, so neither the slot edges nor the loop seam can click. `harmonic`, when
## positive, is mixed in underneath every slot to thicken the tone.
static func _warble_loop(freqs: Array, slot_seconds: float, volume: float,
		harmonic: float) -> AudioStreamWAV:
	var slot := maxi(1, int(round(float(MIX_RATE) * slot_seconds)))
	var mix := PackedFloat32Array()
	mix.resize(slot * freqs.size())
	for s in freqs.size():
		var snapped := _snap(float(freqs[s]), slot_seconds)
		var extra := _snap(harmonic, slot_seconds) if harmonic > 0.0 else 0.0
		for i in slot:
			var index := s * slot + i
			var value := _square(snapped * float(i) / float(MIX_RATE))
			if extra > 0.0:
				value = (value + _square(extra * float(i) / float(MIX_RATE))) * 0.62
			mix[index] = value * (0.22 + 0.78 * sin(PI * float(i) / float(slot))) * volume
	return _to_stream(mix, true)


static func _snap(freq: float, slot_seconds: float) -> float:
	return maxf(1.0, round(freq * slot_seconds)) / slot_seconds
