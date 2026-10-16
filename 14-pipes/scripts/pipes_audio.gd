class_name PipesAudio
extends Node

## Every sound is synthesised at startup into AudioStreamWAV -- this project
## ships no audio files. A small pool of voices rotates so a fast drag does not
## cut itself off.
##
## Frequencies come from the .cfg: they are taste, not rules.

const SAMPLE_RATE := 22050
const VOICE_COUNT := 8
const ATTACK := 0.005

const DRAW := "draw"
const JOIN := "join"
const CLEAR := "clear"
const BLOCKED := "blocked"
const SOLVED := "solved"
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
	_build(PipesSettings.new())


func play(sound: String) -> void:
	_play_stream(_streams.get(sound))


## Laying a cell down steps up a note, so a long drag reads as a rising run
## rather than the same click twenty times. The run is capped: past the top of
## the scale it just holds, which is what a very long drag should sound like.
func play_draw(step: int) -> void:
	_play_stream(_streams.get("draw_%d" % mini(step, 11)))


func _play_stream(stream: AudioStreamWAV) -> void:
	if stream == null:
		return
	var player := _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	player.stream = stream
	player.play()


func _build(settings: PipesSettings) -> void:
	_streams[JOIN] = _arpeggio([settings.join_freq, settings.join_freq * 1.5], 0.07, 0.30)
	_streams[CLEAR] = _slide(settings.clear_freq, settings.clear_freq * 0.5, 0.16, 0.26)
	_streams[BLOCKED] = _tone(settings.blocked_freq, 0.12, 0.28)
	_streams[SOLVED] = _arpeggio(settings.solved_freqs, 0.11, 0.32)
	_streams[RECORD] = _arpeggio(settings.record_freqs, 0.12, 0.32)
	_streams[START] = _tone(settings.start_freq, 0.10, 0.25)
	for step in 12:
		_streams["draw_%d" % step] = _tone(
				settings.draw_freq * pow(2.0, float(step) / 12.0), 0.035, 0.20)


func _tone(frequency: float, duration: float, volume: float) -> AudioStreamWAV:
	return _render(duration, func(_t: float) -> float: return frequency, volume)


func _arpeggio(frequencies: Array, note_duration: float, volume: float) -> AudioStreamWAV:
	if frequencies.is_empty():
		return _tone(440.0, note_duration, volume)
	var total := note_duration * frequencies.size()
	return _render(total, func(t: float) -> float:
		var index := mini(int(t / note_duration), frequencies.size() - 1)
		return float(frequencies[index])
	, volume)


func _slide(from_hz: float, to_hz: float, duration: float, volume: float) -> AudioStreamWAV:
	return _render(duration, func(t: float) -> float:
		return lerpf(from_hz, to_hz, t / duration)
	, volume)


## Renders by integrating phase rather than evaluating sin(2 pi f t): with a
## changing frequency the second form jumps between notes instead of sliding.
## 11-pinball learned this the hard way.
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
