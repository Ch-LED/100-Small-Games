class_name BejeweledAudio
extends Node

## Every sound is synthesised at startup into AudioStreamWAV.

const SAMPLE_RATE := 22050
const VOICE_COUNT := 8
const ATTACK := 0.005

const SWAP := "swap"
const REJECT := "reject"
const CLEAR := "clear"
const CASCADE := "cascade"
const OVER := "over"
const RECORD := "record"
const START := "start"

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _next_voice := 0


func _ready() -> void:
	for _index in VOICE_COUNT:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_build(BejeweledSettings.new())


func play(sound: String) -> void:
	var stream: AudioStreamWAV = _streams.get(sound)
	if stream == null:
		return
	var player := _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	player.stream = stream
	player.play()


## A clear steps up with each cascade, so hearing the chain climb tells the
## player how deep it went without looking at the counter.
func play_clear(cascade: int) -> void:
	var tones: Array[float] = _clear_tones
	if tones.is_empty():
		return
	var index := clampi(cascade - 1, 0, tones.size() - 1)
	var player := _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	var stream: AudioStreamWAV = _streams.get("clear_%d" % index)
	if stream == null:
		return
	player.stream = stream
	player.play()


var _clear_tones: Array[float] = []


func _build(settings: BejeweledSettings) -> void:
	_streams[SWAP] = _tone(settings.swap_freq, 0.05, 0.22)
	_streams[REJECT] = _tone(settings.reject_freq, 0.08, 0.24)
	_streams[CASCADE] = _tone(settings.cascade_freq * 1.25, 0.10, 0.28)
	_streams[OVER] = _slide(settings.over_freq * 2.0, settings.over_freq, 0.45, 0.34)
	_streams[RECORD] = _arpeggio(settings.record_freqs, 0.12, 0.32)
	_streams[START] = _tone(settings.start_freq, 0.10, 0.25)
	_clear_tones = settings.clear_freqs.duplicate()
	for index in _clear_tones.size():
		_streams["clear_%d" % index] = _tone(_clear_tones[index], 0.08, 0.28)


func _tone(frequency: float, duration: float, volume: float) -> AudioStreamWAV:
	return _render(duration, func(_t: float) -> float: return frequency, volume)


func _arpeggio(frequencies: Array[float], note_duration: float, volume: float) -> AudioStreamWAV:
	if frequencies.is_empty():
		return _tone(440.0, note_duration, volume)
	var total := note_duration * frequencies.size()
	return _render(total, func(t: float) -> float:
		var index := mini(int(t / note_duration), frequencies.size() - 1)
		return frequencies[index]
	, volume)


func _slide(from_hz: float, to_hz: float, duration: float, volume: float) -> AudioStreamWAV:
	return _render(duration, func(t: float) -> float:
		return lerpf(from_hz, to_hz, t / duration)
	, volume)


func _render(duration: float, frequency_at: Callable, volume: float) -> AudioStreamWAV:
	var frames := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var phase := 0.0
	for index in frames:
		var t := float(index) / SAMPLE_RATE
		phase += TAU * float(frequency_at.call(t)) / SAMPLE_RATE
		var sample := sin(phase) * _envelope(t, duration) * volume
		data.encode_s16(index * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream


func _envelope(t: float, duration: float) -> float:
	if t < ATTACK:
		return t / ATTACK
	return 1.0 - (t - ATTACK) / maxf(duration - ATTACK, 0.001)
