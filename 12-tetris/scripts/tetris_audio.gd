class_name TetrisAudio
extends Node

## Every sound is synthesised at startup into AudioStreamWAV -- this project
## ships no audio files. A small pool of voices rotates so a fast burst does
## not cut itself off.
##
## Frequencies come from the .cfg: they are taste, not rules.

const SAMPLE_RATE := 22050
const VOICE_COUNT := 6
const ATTACK := 0.005

const MOVE := "move"
const ROTATE := "rotate"
const LOCK := "lock"
const TSPIN := "tspin"
const LEVEL := "level"
const RECORD := "record"
const TOPOUT := "topout"

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _next_voice: int = 0


func _ready() -> void:
	for _index in VOICE_COUNT:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_build(TetrisSettings.new())


func play(sound: String) -> void:
	var stream: AudioStreamWAV = _streams.get(sound)
	if stream == null:
		return
	var player := _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	player.stream = stream
	player.play()


## One rising note per row cleared, so a Tetris plays four of them. That run of
## notes is the player's readout of what the clear was worth.
func play_clear(lines: int) -> void:
	if lines <= 0:
		return
	play("line_%d" % mini(lines, 4))


func _build(settings: TetrisSettings) -> void:
	_streams[MOVE] = _tone(settings.audio_move_freq, 0.03, 0.25)
	_streams[ROTATE] = _tone(settings.audio_rotate_freq, 0.04, 0.30)
	_streams[LOCK] = _tone(settings.audio_lock_freq, 0.08, 0.35)
	_streams[TSPIN] = _arpeggio(settings.audio_tspin_freqs, 0.07, 0.35)
	_streams[LEVEL] = _arpeggio(settings.audio_level_freqs, 0.08, 0.30)
	_streams[RECORD] = _arpeggio(settings.audio_record_freqs, 0.12, 0.35)
	_streams[TOPOUT] = _slide(settings.audio_rotate_freq, 80.0, 0.5, 0.35)
	for count in 4:
		var notes: Array = settings.audio_line_freqs.slice(0, count + 1)
		_streams["line_%d" % (count + 1)] = _arpeggio(notes, 0.06, 0.30)


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
