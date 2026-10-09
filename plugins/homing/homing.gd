class_name Homing
extends RefCounted
## Steering: bends a moving thing's heading toward a target, and never touches its
## speed. Extracted 2026-10-09 from 01-pingpong, 02-space-invaders, 05-asteroids
## and 07-breakout, where four copies of the same slerp had grown — one per game,
## each with its own idea of what to aim at and how fast to turn.
##
## It deliberately does NOT decide what to aim at. The owner hands over a
## provider: a Callable answering "what should something at this point aim at?"
## with a Vector2, or null when there is nothing to aim at. The fleet, the rock
## field, the paddle and the invader formation therefore stay where they belong —
## in the game that owns them — and this stays a piece of arithmetic.
##
## The turn rate can rise as the target gets close. That is not a flourish: the
## sharpest turn is always the one needed at the end, and a rate that felt fine
## at range is exactly what makes a chase overshoot and miss.

## What the ramp measures on the way in.
## `CLOSING` is the distance still to cover ALONG THE CURRENT HEADING — how far
## the target is in front of you. That is the measure a paddle wants: the turn
## that fails is the last one, and it fails because there is no longer room to
## make it. For a ball coming down at a paddle this reads as the vertical gap;
## for one crossing the field it reads as the horizontal one; neither the game
## nor this file has to know which is which.
enum Ramp { DISTANCE, CLOSING }

## Below this the target counts as reached and the heading is left alone.
const ARRIVED := 1.0

var _provider := Callable()
var _rate := 0.0
var _boost := 0.0
var _span := 0.0
var _ramp: int = Ramp.CLOSING


## `rate` is turns per second at range; `boost` is how much faster it gets at
## point blank, reached over the last `span` pixels. `boost` of 0 means a
## constant rate.
func _init(provider: Callable, rate: float, boost := 0.0, span := 0.0,
		ramp: int = Ramp.CLOSING) -> void:
	_provider = provider
	_rate = maxf(0.0, rate)
	_boost = maxf(0.0, boost)
	_span = maxf(0.0, span)
	_ramp = ramp


func is_active() -> bool:
	return _provider.is_valid()


## Turns per second at this distance from the target.
func rate_at(measure: float) -> float:
	if _span <= 0.0:
		return _rate
	return _rate + _boost * clampf(1.0 - measure / _span, 0.0, 1.0)


## The heading to travel with this step: `heading` bent toward the target by
## however much the turn rate allows. Magnitude in, magnitude out, so a caller
## that carries its speed inside the vector gets it back unchanged.
##
## Safe to call every frame: with no provider, no target or a target already
## reached, it returns `heading` and nothing happens.
func steer(from: Vector2, heading: Vector2, delta: float) -> Vector2:
	var speed := heading.length()
	if speed <= 0.0 or not _provider.is_valid():
		return heading
	var target: Variant = _provider.call(from)
	if target == null:
		return heading

	var to_target: Vector2 = (target as Vector2) - from
	var distance := to_target.length()
	if distance <= ARRIVED:
		return heading

	var measure := maxf(0.0, to_target.dot(heading / speed)) \
			if _ramp == Ramp.CLOSING else distance
	var weight := clampf(rate_at(measure) * delta, 0.0, 1.0)
	return (heading / speed).slerp(to_target / distance, weight).normalized() * speed
