class_name PinballTable
extends Node3D
## The playfield: builds itself from data, owns the ball, the flippers and the
## launch lane.
##
## It owns nothing about the run -- not the score, not how many balls are left.
## Those belong to whatever is keeping score, which is the root (pinball_root.gd).
## What happens here is announced with `ball_drained` and decided up there.

## The ball is gone past the drain line and off the bottom of the table.
signal ball_drained

## Tones for the two mechanisms the table scores itself (nothing was hit, so
## there is no object to carry a tone the way a kicker does).
const SINK_TONE := 300.0
const ROLLOVER_TONE := 1240.0

## Something on the table was worth points. Passed straight up: the table does
## not keep score (spec 3.1).
signal scored(amount: int, tone: float)

## Noises the table makes but does not voice: a flipper was asked to move, and
## the plunger was let go. Passed up for the same reason the score is.
signal flipper_clacked(raised: bool)
signal launched(charge: float)

@export var flipper_scene: PackedScene
@export var bumper_scene: PackedScene
@export var target_scene: PackedScene

@onready var _walls: StaticBody3D = $Walls
@onready var _wall_mesh: Node3D = $WallMesh
@onready var _flippers_root: Node3D = $Flippers
@onready var _bumpers_root: Node3D = $Bumpers
@onready var _kickouts_root: Node3D = $Kickouts
@onready var _targets_root: Node3D = $Targets
@onready var _marks_root: Node3D = $Marks
@onready var _ball: PinballBall = $Ball
@onready var _camera: Camera3D = $Camera
@onready var _debug: PinballDebug = $DebugLayer

var _settings: PinballSettings
var _flippers: Array[PinballFlipper] = []
var _targets: Array[PinballTarget] = []

## Which rollovers the ball was standing on last frame, so a tile scores once per
## pass rather than once per tick.
var _rollover_held: Array[bool] = []

## While the ball is inside a sink: how long until it gets spat back out. Zero
## means "not in a sink".
var _sink_hold := 0.0

## The two cheats. Both are reset simply by there being a new table: a fresh run
## builds its own, and nothing carries over (spec 11).
var _cheat := false
var _super := false

## How far the plunger is drawn back, 0 to 1. Held, it climbs; released, it fires.
var _charge := 0.0
var _charging := false

## True while the ball sits in the lane waiting to be fired. The drain check is
## off for the whole of it: a ball at the foot of the lane is already past the
## drain line in z, and only its x keeps it from counting as lost.
var _in_lane := true

## Latched so a drained ball is announced once rather than every frame it keeps
## falling. Cleared when a ball is put back.
var _lost := false


func _ready() -> void:
	_settings = PinballSettings.load_default()
	rotation.x = deg_to_rad(float(_settings.table.tilt_deg))
	PinballTableBuilder.build_walls(_walls, _wall_mesh, _settings)
	_flippers = PinballTableBuilder.build_flippers(_flippers_root, flipper_scene, _settings)
	PinballTableBuilder.build_bumpers(_bumpers_root, bumper_scene, _settings)
	PinballTableBuilder.build_kickouts(_kickouts_root, bumper_scene, _settings)
	_targets = PinballTableBuilder.build_targets(_targets_root, target_scene, _settings)
	PinballTableBuilder.build_sink_marks(_marks_root, _settings)
	PinballTableBuilder.build_rollover_marks(_marks_root, _settings)
	_rollover_held.resize(PinballLayout.rollovers().size())
	_rollover_held.fill(false)
	_ball.configure(_settings.ball)
	_ball.plane_normal = global_transform.basis.y
	_ball.set_flippers(_flippers)
	_ball.scored.connect(_on_ball_scored)
	for flipper in _flippers:
		flipper.clacked.connect(_on_flipper_clacked)
	_debug.setup(self, _ball, _flippers)
	_place_camera()
	reset_ball()


func _physics_process(delta: float) -> void:
	if _in_lane:
		_work_plunger(delta)
		return
	# A ball in a sink is out of play for a moment: nothing else should look at
	# it while it is being swallowed.
	if _sink_hold > 0.0:
		_sink_hold -= delta
		if _sink_hold <= 0.0:
			_ball.freeze = false
			_ball.linear_velocity = Vector3(0.0, 0.0, -float(_settings.score.sink_eject))
		return
	_check_sinks()
	_check_rollovers()
	_check_drain()


## Puts the ball back at the foot of the lane. Called from above, which is the
## only place that knows whether there is another ball coming.
func reset_ball() -> void:
	var spawn := PinballLayout.ball_spawn()
	var place := to_global(Vector3(spawn.x, PinballLayout.BALL_RADIUS, spawn.z))
	# Thawed before the placement is queued, never after: a frozen body does not
	# run _integrate_forces, so the queued placement would never be carried out.
	_ball.freeze = false
	_ball.request_launch(place, place, 0.0)
	for target in _targets:
		target.reset()
	_sink_hold = 0.0
	_rollover_held.fill(false)
	_in_lane = true
	_lost = false
	_charging = false
	_charge = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		_debug.set_enabled(not _debug.is_enabled())
	elif event.is_action_pressed("cheat_toggle"):
		_set_cheat(not _cheat)
	elif event.is_action_pressed("super_cheat_toggle"):
		_set_super(not _super)


func _on_ball_scored(amount: int, tone: float) -> void:
	scored.emit(amount, tone)


func _on_flipper_clacked(raised: bool) -> void:
	flipper_clacked.emit(raised)


## [ -- longer flippers, so less of the drain is reachable.
func _set_cheat(on: bool) -> void:
	_cheat = on
	var scale := float(_settings.cheat.flipper_length_scale) if on else 1.0
	for flipper in _flippers:
		flipper.apply_length_scale(scale)


## ] -- the ball cannot be lost. Caught at the drain line and thrown back up the
## table rather than dropped into the lane, which would only make the player
## fire it again: the run simply never ends.
func _set_super(on: bool) -> void:
	_super = on
	_ball.set_super(on)


func _keep_ball_alive() -> void:
	var here := to_local(_ball.global_position)
	if here.z < PinballLayout.DRAIN_Z:
		return
	_ball.linear_velocity = -global_transform.basis.z * float(_settings.super_cheat.rescue_speed)


func _work_plunger(delta: float) -> void:
	if Input.is_action_pressed("fire"):
		_charging = true
		_charge = minf(1.0, _charge + delta / float(_settings.plunger.charge_time))
	elif _charging:
		_fire()


func _fire() -> void:
	var speed := lerpf(
			float(_settings.plunger.launch_min_speed),
			float(_settings.plunger.launch_max_speed),
			_charge)
	var from := _ball.global_position
	# Up the lane is the table's own -Z: the tilt belongs to the parent, so the
	# aim is expressed here and comes out right in world space for free.
	var aim := from - global_transform.basis.z
	_ball.request_launch(from, aim, speed)
	launched.emit(_charge)
	_charging = false
	_charge = 0.0
	_in_lane = false


## A sink swallows the ball, holds it, then spits it back up the table.
##
## Decided by where the ball is, not by a trigger volume -- same reason as the
## drain below: at 64 units a second the ball covers more than a ball-width per
## tick, and an Area it steps over is a sink that silently did nothing.
func _check_sinks() -> void:
	var here := to_local(_ball.global_position)
	for spot in PinballLayout.sink_spots():
		var flat := Vector2(here.x - spot.pos.x, here.z - spot.pos.y)
		if flat.length() > spot.radius:
			continue
		_sink_hold = float(_settings.score.sink_hold)
		_ball.freeze = true
		_ball.global_position = to_global(Vector3(spot.pos.x, PinballLayout.BALL_RADIUS, spot.pos.y))
		scored.emit(int(_settings.score.sink), SINK_TONE)
		return


## Rollovers are tiles on the table with nothing to hit: the ball is over one or
## it is not. Held-state so a tile scores once per pass, not once per tick.
func _check_rollovers() -> void:
	var here := to_local(_ball.global_position)
	var quads := PinballLayout.rollovers()
	for i in quads.size():
		var over := _point_in_quad(here, quads[i])
		if over and not _rollover_held[i]:
			scored.emit(int(_settings.score.rollover), ROLLOVER_TONE)
		_rollover_held[i] = over


## Winding test against the quad's corners, on the table plane.
static func _point_in_quad(point: Vector3, quad: PackedVector2Array) -> bool:
	var inside := false
	var count := quad.size()
	for i in count:
		var a := quad[i]
		var b := quad[(i + 1) % count]
		if (a.y > point.z) != (b.y > point.z):
			var t := (point.z - a.y) / (b.y - a.y)
			if point.x < a.x + t * (b.x - a.x):
				inside = not inside
	return inside


## Lost is decided by where the ball is, not by a trigger volume. A ball moving
## at speed crosses an Area in a single tick and is never reported -- and a
## missed drain is a ball the player was never told they lost (spec 4.5).
func _check_drain() -> void:
	if _lost:
		return
	if _super:
		_keep_ball_alive()
		return
	var here := to_local(_ball.global_position)
	# Short of the arch the ball rolls back down the lane and settles. The
	# plunger goes live again rather than the ball being stranded there: only
	# the lane lies past the inner wall, so x alone settles where it is.
	if here.x > PinballLayout.LANE_INNER_X and _ball.linear_velocity.length() < 0.6:
		_in_lane = true
		return
	if here.z > PinballLayout.DRAIN_Z:
		_lose_ball()
		return
	# A safety net for a physics blow-up. Nothing legitimate reaches these.
	if here.y < -8.0 or absf(here.x) > 40.0 or absf(here.z) > 40.0:
		_lose_ball()


## Freezing is not an optimisation: a ball left falling runs for as long as the
## run does, and its position stops meaning anything. Nothing above needs it to
## keep moving -- the run has already been told.
func _lose_ball() -> void:
	_lost = true
	_ball.freeze = true
	ball_drained.emit()


## Fixed, and inside the table node so "up the table" in the picture is "up the
## table" in the data. Aimed in the table's own space: the tilt is the parent's
## business and the camera rides along with it.
func _place_camera() -> void:
	var eye := Vector3(0.0, float(_settings.camera.height), float(_settings.camera.pull_back))
	var target := Vector3(0.0, 0.0, float(_settings.camera.look_forward))
	_camera.position = eye
	_camera.basis = Basis.looking_at(target - eye, Vector3.UP)
	_camera.fov = float(_settings.camera.fov)
