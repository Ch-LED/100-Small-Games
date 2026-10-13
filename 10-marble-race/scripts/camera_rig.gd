class_name MarbleCameraRig
extends Node3D
## Third-person follow camera driven by the mouse (technical spec 6).
##
## Its frame follows the ball's DIRECTION OF TRAVEL: forward means forward for
## the ball, up means the road's normal. The mouse then works in that frame, so
## "steer left" stays screen-left wherever the road goes. Two planes still hold
## this together — the road's, which the race controller hands over, and the
## ball's heading, which is worked out here from its motion.
##
## The reason it has to follow travel rather than a fixed world axis: the
## steering basis is built from this frame, and on a vertical stretch of road a
## world-forward input projects onto the road plane as nothing at all. A loop
## used to be a pure coast because of it.
##
## Note this follows the ball's LINEAR motion only. Following its spin is a
## different thing, and spec 6 rules it out.

## How far the camera backs off from something it has run into, in metres.
const PROBE_MARGIN := 0.4
## The least the camera may sit above the plane through the ball. The road has
## no collider to ray against, so this is the only thing stopping the view from
## dropping through the surface when the road rises behind the ball.
const MIN_ABOVE := 0.6

var _cfg: Dictionary = {}
var _target: Node3D = null
var _yaw := 0.0
var _pitch := 0.0
var _up := Vector3.UP
var _wanted_up := Vector3.UP
var _aligned := false
## The ball's heading, a world unit vector lying in the road plane. ZERO until
## it has ever been seeded.
var _heading := Vector3.ZERO
## Where the road itself points at the ball. Handed over every physics frame;
## the frame is followed along it in _follow_to().
var _tangent := Vector3.FORWARD
## While the ] flight mode is on the pitch limit comes off, so the view — and
## with it the direction the ball is pushed — can point anywhere.
var _free_look := false
var _orbit_remaining := 0.0
var _orbit_rate := 0.0


func configure(settings: Dictionary, target: Node3D) -> void:
	_cfg = settings.camera
	_target = target
	_pitch = deg_to_rad(float(_cfg.pitch_max) * 0.35)


## Everything the frame needs, once per physics frame: the plane the camera
## works in, and which way the road runs there.
func aim_frame(up: Vector3, tangent: Vector3) -> void:
	_wanted_up = up.normalized()
	# The very first frame snaps rather than eases. Damping is for a plane that
	# changes while you watch; starting from world-up on a track whose first
	# stretch is vertical means seeding the heading against the wrong plane, and
	# a heading that is edge-on to it flattens to nothing.
	if not _aligned:
		_up = _wanted_up
		_aligned = true
	_tangent = tangent.normalized()


## Steering resolves in the same frame the camera uses, so where the camera
## happens to be pitched never changes which way the ball goes (spec 6), and
## screen-left always means the ball's left.
func get_steering_basis() -> Basis:
	if _heading == Vector3.ZERO:
		# Never seeded: identity at yaw 0, which is the world axes the headless
		# probes drive the ball against.
		return Basis(_up, _yaw)
	return _frame_of(_heading, _up, _yaw)


## One slow lap around the ball when a run ends. It takes the yaw over
## entirely while it lasts: the mouse is not in charge of a victory lap.
func celebrate(seconds: float) -> void:
	_orbit_remaining = TAU
	_orbit_rate = TAU / maxf(seconds, 0.01)


func set_free_look(on: bool) -> void:
	_free_look = on


## The follow frame as it truly is, before the plane has been eased for
## display. The ball's box is drawn from this: a box sitting off the road would
## be showing the wrong thing, and on a corkscrew the display plane lags the
## ball's by ten degrees or more.
func get_frame() -> Basis:
	if _heading == Vector3.ZERO:
		return Basis(_wanted_up, 0.0)
	return _frame_of(_heading, _wanted_up, 0.0)


## The camera's own axes, pitch and all. The ] flight mode steers with these
## rather than with get_steering_basis(): a frame that follows travel cannot
## climb, and flight that cannot climb is not flight.
func get_look_basis() -> Basis:
	return global_transform.basis


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion == null or _cfg.is_empty():
		return
	if _orbit_remaining > 0.0:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var sensitivity: float = _cfg.mouse_sensitivity
	# Both are offsets within the follow frame now, not world angles. At yaw 0
	# on a straight, heading is the road's forward, so this reproduces the old
	# behaviour exactly.
	_yaw -= motion.relative.x * sensitivity
	_pitch += motion.relative.y * sensitivity
	if _free_look:
		var limit := deg_to_rad(89.0)
		_pitch = clampf(_pitch, -limit, limit)
	else:
		_pitch = clampf(_pitch,
				deg_to_rad(float(_cfg.pitch_min)),
				deg_to_rad(float(_cfg.pitch_max)))


func _physics_process(delta: float) -> void:
	if _target == null or _cfg.is_empty():
		return
	if _orbit_remaining > 0.0:
		var step := minf(_orbit_rate * delta, _orbit_remaining)
		_yaw += step
		_orbit_remaining -= step
	_up = _up.slerp(_wanted_up, 1.0 - exp(-float(_cfg.align_damp) * delta)).normalized()
	# The frame follows travel only while the ball is being driven. Flight is a
	# camera-absolute cheat by design — following travel there would feed the
	# camera's own yaw back into the axes flight steers by, and it would steer
	# itself — and the victory lap has taken the yaw over.
	if not _free_look and _orbit_remaining <= 0.0:
		_follow_to(delta)
	var focus := _focus()
	var desired := _keep_clear(_ideal_position(), focus)
	global_position = global_position.lerp(desired, 1.0 - exp(-float(_cfg.follow_damp) * delta))
	# Cleared a second time, after the easing. The damped position is only on
	# its way to the safe one, and being on its way still puts it through the
	# road on a corkscrew, where the plane it has to clear swings right round
	# between frames.
	global_position = _keep_clear(global_position, focus)
	_aim_at(focus)


## Drops the camera straight onto the ideal spot without easing. Used when a run
## restarts: an eased camera spends the first second of every attempt sliding in
## from wherever the last one ended, and a distance that is only arrived at by
## luck is not a distance.
func snap_to_target() -> void:
	if _target == null or _cfg.is_empty():
		return
	var focus := _focus()
	global_position = _keep_clear(_ideal_position(), focus)
	_aim_at(focus)


func _focus() -> Vector3:
	return _target.global_position + _up * float(_cfg.look_height)


func _ideal_position() -> Vector3:
	var distance: float = _cfg.distance
	# Pitch rotates the offset about the frame's lateral axis, so the clamp is
	# measured from the road's plane rather than from the horizon.
	var pitched := Basis(Vector3.RIGHT, -_pitch) * Vector3(0.0, 0.0, distance)
	return _focus() + _up * float(_cfg.height) + get_steering_basis() * pitched


## Keeps the camera out of whatever it would otherwise end up inside. Two
## different things can be in the way and only one of them can be probed: the
## barriers are real bodies with collision, and the road is not — it is an
## analytic constraint with no collider anywhere (spec 4.4). So the barriers get
## a ray and the road gets a floor on how far below the ball the camera may sit,
## along the road's own normal.
func _keep_clear(desired: Vector3, focus: Vector3) -> Vector3:
	var trimmed := desired
	var space := get_world_3d().direct_space_state
	if space != null:
		var query := PhysicsRayQueryParameters3D.create(focus, desired)
		query.exclude = [_target.get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var hit_position: Vector3 = hit["position"]
			trimmed = hit_position - (hit_position - focus).normalized() * PROBE_MARGIN
	# Measured against the plane the BALL is on, not the one the camera has
	# eased its way to. On a corkscrew the ball's plane swings right the way
	# round while the camera's lags behind it, and a floor measured against the
	# lagging plane lets the camera sit under the road it is meant to clear.
	var along := (trimmed - focus).dot(_wanted_up)
	if along < MIN_ABOVE:
		trimmed += _wanted_up * (MIN_ABOVE - along)
	return trimmed


## Holds the frame's heading on the road's own direction, damped and
## rate-limited.
##
## Deliberately NOT the ball's velocity. What the view follows is which way the
## ROAD runs, not which way the ball happens to be sliding — and on a vertical
## stretch those come apart badly, because gravity owns the velocity there. The
## earlier version followed the velocity and had to keep rescuing itself from
## that: it held the heading when the ball was slow, and threw the velocity away
## when it swung more than 60 degrees off the road. Taking the road directly
## removes the whole problem, and the accelerator keeps working up a loop
## because "forward" is the road's forward.
##
## The road's direction is still not trusted blindly: where a track passes near
## itself, the nearest-point lookup can hand back the other stretch, pointing
## the opposite way, so the sign is taken from where the frame already points.
func _follow_to(delta: float) -> void:
	var road := _flatten(_tangent)
	if road == Vector3.ZERO:
		# Nothing to steer by yet — the plane has not settled. Coming back next
		# frame beats picking an arbitrary direction and being stuck with it.
		return
	# The sign is taken from where the frame already points, but only when the
	# road is pointing clearly the other way — better than a half turn apart.
	# Testing for merely "more than a right angle" was wrong: the heading chases
	# the road under a rate limit, so on a fast tight corner it legitimately
	# falls a long way behind, crosses 90 degrees, and gets flipped a half turn
	# by its own safety check. That is the camera spinning round on the third
	# bend of track_04.
	if _heading != Vector3.ZERO and road.dot(_heading) < -0.5:
		road = -road
	if _heading == Vector3.ZERO:
		_heading = road
		return
	var angle := _heading.signed_angle_to(road, _up)
	var step := angle * (1.0 - exp(-float(_cfg.heading_damp) * delta))
	var limit: float = float(_cfg.heading_max_turn) * delta
	_heading = _heading.rotated(_up, clampf(step, -limit, limit)).normalized()


## A world vector laid flat in the road's plane, or ZERO if it is edge-on to it.
func _flatten(v: Vector3) -> Vector3:
	var flat := v - _up * v.dot(_up)
	if flat.length_squared() < 0.000001:
		return Vector3.ZERO
	return flat.normalized()


## A basis whose forward is `forward`, whose up is `up`, with `yaw` applied on
## top. Built rather than derived so the handedness is explicit: the columns are
## [right, up, back], right = up x back, which is the same convention _aim_at
## uses and the same one a fresh Basis(UP, 0) gives.
##
## The forward is flattened against the up FIRST, and that is not tidiness. The
## heading is projected onto whichever plane was current when it was last
## updated, and the plane eases from one to the next, so by the time the two are
## used together they can be a few degrees out of square. A basis built from
## near-perpendicular-but-not-quite axes is not orthonormal, and a
## non-orthonormal basis does not just rotate what it is applied to — it SCALES
## it. That is what squashed the ball's frame box.
func _frame_of(forward: Vector3, up: Vector3, yaw: float) -> Basis:
	var flat := forward - up * forward.dot(up)
	if flat.length_squared() < 0.000001:
		return Basis(up, yaw)
	var back := -flat.normalized()
	var right := up.cross(back)
	if right.length_squared() < 0.000001:
		return Basis(up, yaw)
	return Basis(up, yaw) * Basis(right.normalized(), up, back)


## Built rather than delegated to look_at().
##
## When the view direction comes out nearly parallel to the up vector,
## look_at() rotates the up vector about the view direction — and it hands that
## vector over unnormalised, which Godot warns about once a frame. It is not a
## rare corner: ] flight lets the player pitch the camera almost straight up or
## down, which is exactly that case, and looking up is how the ball climbs.
##
## Here both vectors used are normalised before they go anywhere, and the
## degenerate case simply leaves the camera pointing where it was.
func _aim_at(focus: Vector3) -> void:
	var back := global_position - focus
	if back.length_squared() < 0.0001:
		return
	var z := back.normalized()
	var x := _up.cross(z)
	if x.length_squared() < 0.000001:
		return
	var x_unit := x.normalized()
	global_transform.basis = Basis(x_unit, z.cross(x_unit), z)
