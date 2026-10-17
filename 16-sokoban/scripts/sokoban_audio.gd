class_name SokobanAudio
extends Node

## Every sound is synthesised at startup into AudioStreamWAV -- this project
## ships no audio files.

const SAMPLE_RATE := 22050
const VOICE_COUNT := 6
const ATTACK := 0.005

const STEP := "step"
const PUSH := "push"
const BLOCKED := "blocked"
const UNDO := "undo"
const PLACED := "placed"
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
	_build(SokobanSettings.new())


func play(sound: String) -> void:
	var stream: AudioStreamWAV = _streams.get(sound)
	if stream == null:
		return
	var player := _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	player.stream = stream
	player.play()


func _build(settings: SokobanSettings) -> void:
	_streams[STEP] = _tone(settings.step_freq, 0.04, 0.22)
	_streams[PUSH] = _tone(settings.push_freq, 0.07, 0.28)
	_streams[BLOCKED] = _tone(settings.blocked_freq, 0.10, 0.26)
	_streams[UNDO] = _tone(settings.undo_freq, 0.05, 0.22)
	_streams[PLACED] = _tone(settings.placed_freq, 0.09, 0.28)
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
