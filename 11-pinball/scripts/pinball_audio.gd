class_name PinballAudio
extends Node
## Every note is generated; the project carries no sound files.
##
## Two things shape the design here. One is the rising pitch: hit things in
## quick succession and each ring is a step higher than the last, which is the
## only sign the player gets that a streak is on -- and it changes nothing in
## the score, deliberately (spec 7). The other is that a machine is being
## played: the flippers are solenoids and the plunger is a spring, so their
## sounds are clicks and sweeps rather than notes.

const VOICES := 6
const COMBO_WINDOW_MS := 1200
const COMBO_MAX := 8
## A little over a semitone per step, so eight of them are plainly audible.
const PITCH_STEP := 1.08

var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _combo := 0
var _last_hit_ms := 0
var _cache: Dictionary = {}


func _ready() -> void:
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_voices.append(player)


## Voices rotate, so a fast run of sounds overlaps rather than cutting itself off.
func _play(stream: AudioStreamWAV, pitch: float = 1.0) -> void:
	var player := _voices[_next]
	_next = (_next + 1) % VOICES
	player.stream = stream
	player.pitch_scale = pitch
	player.play()


func play_hit(tone: float) -> void:
	var now := Time.get_ticks_msec()
	_combo = _combo + 1 if now - _last_hit_ms < COMBO_WINDOW_MS else 0
	_combo = mini(_combo, COMBO_MAX)
	_last_hit_ms = now
	_play(_tone(tone), pow(PITCH_STEP, float(_combo)))


## The two flippers sound different on purpose. A player with their eyes on the
## ball should still be able to hear which hand moved.
func play_flipper(raised: bool) -> void:
	_play(_tone(1320.0 if raised else 660.0, 0.055), 1.0)


## The plunger letting go. The pitch it ends on follows how hard it was pulled,
## so a full charge is audibly worth more than a tap.
func play_launch(charge: float) -> void:
	_play(_sweep(220.0, 520.0 + 460.0 * charge, 0.26), 1.0)


func play_drain() -> void:
	_play(_sweep(520.0, 90.0, 0.55), 1.0)


## Three rising notes, one above anything a hit can reach.
func play_record() -> void:
	const NOTES: Array[float] = [660.0, 880.0, 1174.0]
	for i in NOTES.size():
		var player := _voices[_next]
		_next = (_next + 1) % VOICES
		player.stream = _tone(NOTES[i], 0.22)
		player.pitch_scale = 1.0
		player.play()
		await get_tree().create_timer(0.13).timeout


## A short damped sine. The envelope is what makes it read as a strike rather
## than a beep: it decays steeply and never sustains.
func _tone(frequency: float, duration: float = 0.16) -> AudioStreamWAV:
	var key := "t%d_%d" % [int(frequency), int(duration * 1000.0)]
	if _cache.has(key):
		return _cache[key]
	var stream := _render(float(frequency), float(frequency), duration, 3.0)
	_cache[key] = stream
	return stream


## A swept sine -- the spring letting go, the ball falling away. A sound that
## changes pitch is what makes those two read as movement rather than pings.
func _sweep(from_hz: float, to_hz: float, duration: float) -> AudioStreamWAV:
	var key := "s%d_%d_%d" % [int(from_hz), int(to_hz), int(duration * 1000.0)]
	if _cache.has(key):
		return _cache[key]
	var stream := _render(from_hz, to_hz, duration, 1.6)
	_cache[key] = stream
	return stream


## Phase is integrated rather than computed from a changing frequency, because
## `sin(2*pi*f(t)*t)` with a moving f jumps in pitch instead of gliding.
func _render(from_hz: float, to_hz: float, duration: float, decay_power: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / float(rate)
		var progress := t / duration
		var frequency := lerpf(from_hz, to_hz, progress)
		phase += TAU * frequency / float(rate)
		var decay := pow(1.0 - progress, decay_power)
		var sample := sin(phase) * decay * 0.5
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream
