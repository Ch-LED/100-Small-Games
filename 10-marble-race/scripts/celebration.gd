class_name MarbleCelebration
extends Node
## What happens when the ball crosses the line: confetti in from the sides of
## the screen, and cold fountains up off the ground on either side of the finish
## — a pair on the line, and a pair lining the run-out past it.
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
	for entry in [["Left", cfg.spark_amount], ["Right", cfg.spark_amount],
			["LeftRun", cfg.spark_run_amount], ["RightRun", cfg.spark_run_amount]]:
		var spark: CPUParticles3D = _sparks.get_node(String(entry[0]))
		spark.amount = int(entry[1]) / 2
		spark.lifetime = float(cfg.spark_lifetime)
		spark.initial_velocity_min = float(cfg.spark_speed) * 0.6
		spark.initial_velocity_max = float(cfg.spark_speed)
		_emitters.append(spark)
	stop()


## Puts the cold fountains where the finish is: a pair on the line itself, and a
## pair lining the run-out past it. Both are placed from the road's own frames
## rather than from coordinates, so they follow the line if the track is
## reshaped.
func place_at_finish(track: RaceTrackPath) -> void:
	var line := track.finish_line.global_transform
	var width := track.half_width()
	for side in [[-1.0, "Left"], [1.0, "Right"]]:
		var spark: CPUParticles3D = _sparks.get_node(String(side[1]))
		spark.global_position = line.origin + line.basis.x * (width * float(side[0]))
	# The run-out is lined the whole way down. One emitter per edge rather than a
	# station every few metres: a box emission covers the length exactly, and the
	# length belongs to the track, not to a number kept in step here by hand.
	var length := track.runoff_length()
	var run := track.runoff_frame().translated_local(Vector3(0.0, 0.0, -length * 0.5))
	for side in [[-1.0, "LeftRun"], [1.0, "RightRun"]]:
		var spark: CPUParticles3D = _sparks.get_node(String(side[1]))
		spark.emission_box_extents = Vector3(0.4, 0.15, length * 0.5)
		spark.global_transform = run.translated_local(
				Vector3(width * float(side[0]), 0.0, 0.0))


func fire() -> void:
	for emitter in _emitters:
		emitter.restart()
		emitter.emitting = true


func stop() -> void:
	for emitter in _emitters:
		emitter.emitting = false
