class_name MarbleCelebration
extends Node
## What happens when the ball crosses the line: confetti in from the sides of
## the screen, and a pair of cold fountains up off the ground on either side of
## the finish.
##
## Two halves in two different spaces, which is why this is a plain Node rather
## than an overlay: the sparks happen where the finish line is, in the world,
## and the confetti happens where the player is looking, on the screen. One is
## not a projection of the other and neither should have to pretend to be.

@onready var _sparks: Node3D = $Sparks
@onready var _confetti: CanvasLayer = $Confetti

var _emitters: Array = []


func configure(settings: Dictionary) -> void:
	var cfg: Dictionary = settings.celebration
	for side in ["Left", "Right"]:
		for slot in ["A", "B"]:
			var emitter: CPUParticles2D = _confetti.get_node("%s%s" % [side, slot])
			emitter.amount = int(cfg.confetti_amount) / 2
			emitter.lifetime = float(cfg.confetti_lifetime)
			emitter.initial_velocity_min = float(cfg.confetti_speed) * 0.7
			emitter.initial_velocity_max = float(cfg.confetti_speed)
			_emitters.append(emitter)
	for side in ["Left", "Right"]:
		var spark: CPUParticles3D = _sparks.get_node(side)
		spark.amount = int(cfg.spark_amount) / 2
		spark.lifetime = float(cfg.spark_lifetime)
		spark.initial_velocity_min = float(cfg.spark_speed) * 0.6
		spark.initial_velocity_max = float(cfg.spark_speed)
		_emitters.append(spark)
	stop()


## Puts the fountains on the ground either side of the finish line. They are
## placed from the road's own frame there rather than from coordinates, so they
## follow the line if the track is reshaped.
func place_at_finish(track: RaceTrackPath) -> void:
	var centre := track.finish_line.global_position
	var lateral := track.finish_line.global_transform.basis.x
	var width := track.half_width()
	for side in [[-1.0, "Left"], [1.0, "Right"]]:
		var spark: CPUParticles3D = _sparks.get_node(String(side[1]))
		spark.global_position = centre + lateral * (width * float(side[0]))


func fire() -> void:
	for emitter in _emitters:
		emitter.restart()
		emitter.emitting = true


func stop() -> void:
	for emitter in _emitters:
		emitter.emitting = false
