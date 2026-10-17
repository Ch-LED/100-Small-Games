class_name MinesweeperAudio
extends Node

## Every sound is synthesised at startup into AudioStreamWAV -- this project
## ships no audio files. A small pool of voices rotates so a fast cascade does
## not cut itself off.

const SAMPLE_RATE := 22050
const VOICE_COUNT := 6
const ATTACK := 0.005

const OPEN := "open"
const FLAG := "flag"
const UNFLAG := "unflag"
const BOOM := "boom"
const WIN := "win"
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
	_build(MinesweeperSettings.new())


func play(sound: String) -> void:
	var stream: AudioStreamWAV = _streams.get(sound)
	if stream == null:
		return
	var player := _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	player.stream = stream
	player.play()


func _build(settings: MinesweeperSettings) -> void:
	_streams[OPEN] = _tone(settings.open_freq, 0.04, 0.24)
	_streams[FLAG] = _tone(settings.flag_freq, 0.05, 0.26)
	_streams[UNFLAG] = _tone(settings.unflag_freq, 0.05, 0.22)
	_streams[BOOM] = _slide(settings.boom_freq * 3.0, settings.boom_freq, 0.42, 0.38)
	_streams[WIN] = _arpeggio(settings.win_freqs, 0.11, 0.32)
	_streams[RECORD] = _arpeggio(settings.record_freqs, 0.12, 0.32)
	_streams[START] = _tone(settings.start_freq, 0.10, 0.25)


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


## Renders by integrating phase rather than evaluating sin(2 pi f t): with a
## changing frequency the second form jumps between notes instead of sliding.
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
