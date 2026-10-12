extends SceneTree
## Track authoring tool. Bakes each waypoint list below into a Curve3D for the
## track to sweep — Catmull-Rom tangent handles so the road has no creases —
## and prints the minimum turn radius so a route can be checked against the
## sweep width before anything is built from it.
##
## A curve can also be edited by dragging its points in the 3D viewport, and
## for a one-off tweak that is the right way. This exists for rebuilding a
## curve from a readable list, and it is the only record of why the waypoints
## are where they are.
##
## Run: godot --headless --path . --script res://10-marble-race/scripts/make_track.gd

const OUT_DIR := "res://10-marble-race/resources/tracks/"

## Kept in step with [track] half_width in marble-race.cfg by hand. The tool
## does not read the cfg — it is run standalone and reports against the width
## the road is actually swept at. A route that narrows below this reports
## against the default, which is the conservative direction.
const DEFAULT_HALF_WIDTH := 3.0

## One entry per track, keyed by the curve's file name (without the extension)
## and then referenced from track_index.tres.
##
## Two numbers decide whether a route can be built at all, and the tool prints
## both: the tightest turn radius (below the road's half width the swept inner
## edge folds over itself) and the closest the road comes to a DIFFERENT part
## of itself. The ball finds its road by asking for the nearest point on the
## curve, and that question has no answer where two stretches of road run
## alongside each other. Keep the self-approach well past twice the half width
## — a spiral lap and the lap beside it are only a few metres apart.
const ROUTES := {
	# A gentle S: straight run-up, a wide left sweep, a wide right sweep,
	# run-out. The one the physics and the feel were tuned on.
	#
	# The two bends bank themselves now. ⚠️ The sign here is set from what the
	# track LOOKS like in play, not from the probe that was written to measure
	# it: the probe and the sweep read the same frame and still disagreed with
	# the screen, so the probe is the thing that is wrong and it has not been
	# found yet. Until it is, the user's eye wins — do not "fix" these back.
	"track_01": [
		Vector3(0.0, 3.0, 0.0),
		Vector3(0.0, 3.0, -50.0),
		{"p": Vector3(-20.0, 3.0, -95.0), "tilt": 15.0},
		Vector3(-20.0, 3.0, -150.0),
		{"p": Vector3(5.0, 3.0, -195.0), "tilt": -15.0},
		Vector3(5.0, 3.0, -240.0),
	],
	# A corkscrew: the road runs on the OUTSIDE of a cylinder whose axis lies
	# along the route, winding two full turns (720 degrees) as it goes. The turn
	# is the point — the surface rolls right the way round under the ball, which
	# is what a spiral is and what a flat one can never be.
	#
	# Axis at (0, 10, z), radius 6, advancing 8 m per radian. The cylinder is
	# 12 m across and the two turns take 189 m of road. The radius has been round
	# the houses: 10 first (called too small), then 16 (called too big), then 8,
	# and now 6. Width is what reads as "a spring"; the advance stays at 8 either
	# way. Radius 6 puts the bend at 15 m, comfortably clear of the width taper in
	# track.gd starting to bite.
	#
	# Aimed at the axis rather than tilted by hand, so the surface faces the
	# middle of the cylinder the whole way round. The run-in meets the first turn
	# at the bottom of the bore along the same tangent, so there is no kink to
	# enter on — and the exit leaves on that tangent too.
	"track_02": [
		{"p": Vector3(-28.8000, 4.0000, 38.4000), "aim": Vector3(0.0000, 1.0000, 0.0000)},
		{"p": Vector3(-21.6000, 4.0000, 28.8000), "aim": Vector3(0.0000, 1.0000, 0.0000)},
		{"p": Vector3(-14.4000, 4.0000, 19.2000), "aim": Vector3(0.0000, 1.0000, 0.0000)},
		{"p": Vector3(-7.2000, 4.0000, 9.6000), "aim": Vector3(0.0000, 1.0000, 0.0000)},
		{"p": Vector3(0.0000, 4.0000, -0.0000), "aim": Vector3(-0.0000, 1.0000, 0.0000)},
		{"p": Vector3(2.2961, 4.4567, -3.1416), "aim": Vector3(-0.3827, 0.9239, 0.0000)},
		{"p": Vector3(4.2426, 5.7574, -6.2832), "aim": Vector3(-0.7071, 0.7071, 0.0000)},
		{"p": Vector3(5.5433, 7.7039, -9.4248), "aim": Vector3(-0.9239, 0.3827, 0.0000)},
		{"p": Vector3(6.0000, 10.0000, -12.5664), "aim": Vector3(-1.0000, -0.0000, 0.0000)},
		{"p": Vector3(5.5433, 12.2961, -15.7080), "aim": Vector3(-0.9239, -0.3827, 0.0000)},
		{"p": Vector3(4.2426, 14.2426, -18.8496), "aim": Vector3(-0.7071, -0.7071, 0.0000)},
		{"p": Vector3(2.2961, 15.5433, -21.9911), "aim": Vector3(-0.3827, -0.9239, 0.0000)},
		{"p": Vector3(0.0000, 16.0000, -25.1327), "aim": Vector3(-0.0000, -1.0000, 0.0000)},
		{"p": Vector3(-2.2961, 15.5433, -28.2743), "aim": Vector3(0.3827, -0.9239, 0.0000)},
		{"p": Vector3(-4.2426, 14.2426, -31.4159), "aim": Vector3(0.7071, -0.7071, 0.0000)},
		{"p": Vector3(-5.5433, 12.2961, -34.5575), "aim": Vector3(0.9239, -0.3827, 0.0000)},
		{"p": Vector3(-6.0000, 10.0000, -37.6991), "aim": Vector3(1.0000, -0.0000, 0.0000)},
		{"p": Vector3(-5.5433, 7.7039, -40.8407), "aim": Vector3(0.9239, 0.3827, 0.0000)},
		{"p": Vector3(-4.2426, 5.7574, -43.9823), "aim": Vector3(0.7071, 0.7071, 0.0000)},
		{"p": Vector3(-2.2961, 4.4567, -47.1239), "aim": Vector3(0.3827, 0.9239, 0.0000)},
		{"p": Vector3(-0.0000, 4.0000, -50.2655), "aim": Vector3(0.0000, 1.0000, 0.0000)},
		{"p": Vector3(2.2961, 4.4567, -53.4071), "aim": Vector3(-0.3827, 0.9239, 0.0000)},
		{"p": Vector3(4.2426, 5.7574, -56.5487), "aim": Vector3(-0.7071, 0.7071, 0.0000)},
		{"p": Vector3(5.5433, 7.7039, -59.6903), "aim": Vector3(-0.9239, 0.3827, 0.0000)},
		{"p": Vector3(6.0000, 10.0000, -62.8319), "aim": Vector3(-1.0000, 0.0000, 0.0000)},
		{"p": Vector3(5.5433, 12.2961, -65.9734), "aim": Vector3(-0.9239, -0.3827, 0.0000)},
		{"p": Vector3(4.2426, 14.2426, -69.1150), "aim": Vector3(-0.7071, -0.7071, 0.0000)},
		{"p": Vector3(2.2961, 15.5433, -72.2566), "aim": Vector3(-0.3827, -0.9239, 0.0000)},
		{"p": Vector3(0.0000, 16.0000, -75.3982), "aim": Vector3(-0.0000, -1.0000, 0.0000)},
		{"p": Vector3(-2.2961, 15.5433, -78.5398), "aim": Vector3(0.3827, -0.9239, 0.0000)},
		{"p": Vector3(-4.2426, 14.2426, -81.6814), "aim": Vector3(0.7071, -0.7071, 0.0000)},
		{"p": Vector3(-5.5433, 12.2961, -84.8230), "aim": Vector3(0.9239, -0.3827, 0.0000)},
		{"p": Vector3(-6.0000, 10.0000, -87.9646), "aim": Vector3(1.0000, -0.0000, 0.0000)},
		{"p": Vector3(-5.5433, 7.7039, -91.1062), "aim": Vector3(0.9239, 0.3827, 0.0000)},
		{"p": Vector3(-4.2426, 5.7574, -94.2478), "aim": Vector3(0.7071, 0.7071, 0.0000)},
		{"p": Vector3(-2.2961, 4.4567, -97.3894), "aim": Vector3(0.3827, 0.9239, 0.0000)},
		{"p": Vector3(-0.0000, 4.0000, -100.5310), "aim": Vector3(0.0000, 1.0000, 0.0000)},
		{"p": Vector3(7.2000, 4.0000, -110.1310), "aim": Vector3(0.0000, 1.0000, 0.0000)},
		{"p": Vector3(14.4000, 4.0000, -119.7310), "aim": Vector3(0.0000, 1.0000, 0.0000)},
		{"p": Vector3(21.6000, 4.0000, -129.3310), "aim": Vector3(0.0000, 1.0000, 0.0000)},
	],
	# Two coaster loops back to back, each 20 m tall off a 10 m radius, with the
	# ball upside down over the top of each one.
	#
	# A loop's two legs stand 7 m apart SIDEWAYS rather than meeting at a point.
	# A loop drawn as one closed curve has no other option that works: bring the
	# legs together and the curve folds back through itself at the bottom, and
	# drift them apart ALONG the route instead and the two halves of the loop
	# land on top of each other — the two points at the same height come out at
	# the same distance down the route and 0.4 m apart. Sideways is also how the
	# real thing is built. Watch the self-approach: 7 m is barely past the 6 m
	# two roadways need, and widening the drift twists the surface harder.
	#
	# The height is set by the run-up, not by taste. Steering is a yaw-only
	# plane, so on a vertical stretch the player's forward input projects to
	# nothing and a loop has to be coasted on the speed the ball arrives with.
	# The ball tops out at 23.4 m/s on the flat, which is 28 m of climb — so a
	# 20 m loop clears with room to spare and the 32 m one it started as did not,
	# even off a 160 m run-up. A loop is the one place on a track where "hold the
	# accelerator down" cannot substitute for carrying speed in.
	#
	# Every point around a loop carries "aim" rather than "tilt": the surface is
	# told to face the loop's centre, and the angle needed is solved for. Hand
	# writing it does not work — the gap it has to close runs past 80 degrees and
	# the sign is opposite to intuition, which cost two wrong passes. Aiming is
	# also the honest description: the road is round a circle, so it should look
	# at the middle of it.
	# Each loop aims 8 points, one every 45 degrees. Tried 16: the tighter
	# spacing made Catmull-Rom's automatic tangents jitter, and the tightest turn
	# radius fell from 9.1 m to 6.0 m — exactly the road width, where the swept
	# edge folds. Do not add loop waypoints without re-reading that number.
	"track_03": [
		{"p": Vector3(0.0, 3.0, 0.0), "aim": Vector3(0.0, 1.0, 0.0)},
		{"p": Vector3(-3.5, 3.0, -120.0), "aim": Vector3(0.0, 1.0, 0.0)},
		{"p": Vector3(-2.625, 5.9289, -127.0711), "aim": Vector3(0.0, 0.707, 0.707)},
		{"p": Vector3(-1.75, 13.0, -130.0), "aim": Vector3(0.0, 0.0, 1.0)},
		{"p": Vector3(-0.875, 20.0711, -127.0711), "aim": Vector3(0.0, -0.707, 0.707)},
		{"p": Vector3(0.0, 23.0, -120.0), "aim": Vector3(0.0, -1.0, 0.0)},
		{"p": Vector3(0.875, 20.0711, -112.9289), "aim": Vector3(0.0, -0.707, -0.707)},
		{"p": Vector3(1.75, 13.0, -110.0), "aim": Vector3(0.0, 0.0, -1.0)},
		{"p": Vector3(2.625, 5.9289, -112.9289), "aim": Vector3(0.0, 0.707, -0.707)},
		{"p": Vector3(3.5, 3.0, -120.0), "aim": Vector3(0.0, 1.0, 0.0)},
		{"p": Vector3(-3.5, 3.0, -190.0), "aim": Vector3(0.0, 1.0, 0.0)},
		{"p": Vector3(-2.625, 5.9289, -197.0711), "aim": Vector3(0.0, 0.707, 0.707)},
		{"p": Vector3(-1.75, 13.0, -200.0), "aim": Vector3(0.0, 0.0, 1.0)},
		{"p": Vector3(-0.875, 20.0711, -197.0711), "aim": Vector3(0.0, -0.707, 0.707)},
		{"p": Vector3(0.0, 23.0, -190.0), "aim": Vector3(0.0, -1.0, 0.0)},
		{"p": Vector3(0.875, 20.0711, -182.9289), "aim": Vector3(0.0, -0.707, -0.707)},
		{"p": Vector3(1.75, 13.0, -180.0), "aim": Vector3(0.0, 0.0, -1.0)},
		{"p": Vector3(2.625, 5.9289, -182.9289), "aim": Vector3(0.0, 0.707, -0.707)},
		{"p": Vector3(3.5, 3.0, -190.0), "aim": Vector3(0.0, 1.0, 0.0)},
		{"p": Vector3(0.0, 3.0, -240.0), "aim": Vector3(0.0, 1.0, 0.0)},
	],
	# Hairpins: five tight alternating bends with the ground stepping 9 m up and
	# down between them. At 11.9 m the tightest of the five is the smallest turn
	# in the project — the ball has to be slowed to about 12 m/s to make it,
	# against the 23 m/s it tops out at on the flat.
	#
	# The bends are banked harder than the gentle S is (16 deg against 11): this
	# is the one track whose whole difficulty is cornering, so the road does as
	# much of the work as it can. Sign is by eye, same as track_01. Note each of
	# these is a TURNING POINT with a bend on either side, so its tilt is shared
	# by both — which is why the sign matters more here than anywhere.
	"track_04": [
		Vector3(0.0, 3.0, 0.0),
		{"p": Vector3(21.0, 3.0, -48.0), "tilt": -22.0},
		{"p": Vector3(-21.0, 12.0, -86.0), "tilt": 22.0},
		{"p": Vector3(21.0, 3.0, -124.0), "tilt": -22.0},
		{"p": Vector3(-21.0, 12.0, -162.0), "tilt": 22.0},
		{"p": Vector3(21.0, 3.0, -200.0), "tilt": -22.0},
		Vector3(0.0, 3.0, -264.0),
	],
}

const HANDLE_FRACTION := 0.35


func _initialize() -> void:
	for key: String in ROUTES:
		var points: Array = ROUTES[key]
		var curve := _build_curve(points)
		var path := OUT_DIR + key + ".tres"
		ResourceSaver.save(curve, path)
		print("saved %s  (%d points, %.1f m long)"
				% [path, curve.point_count, curve.get_baked_length()])
		_report_radius(curve)
		_report_self_gap(curve)
		_report_roll(curve)
	quit()


func _build_curve(points: Array) -> Curve3D:
	var curve := Curve3D.new()
	for i in points.size():
		# One direction per joint, shared by both handles. Taking the chord to
		# each neighbour separately leaves a corner wherever the two chords
		# disagree, and a corner is a turn radius far tighter than the road is
		# wide — which is exactly how the swept surface folds over itself.
		var direction := _direction(points, i)
		var here := _position(points, i)
		curve.add_point(here,
				-direction * _before(points, i) * HANDLE_FRACTION,
				direction * _after(points, i) * HANDLE_FRACTION)
		# The road's roll about its own forward axis, authored per waypoint.
		# Zero everywhere unless a route asks for a twist.
		curve.set_point_tilt(i, deg_to_rad(_tilt_of(points, i)))
	_solve_aims(curve, points)
	return curve


## A waypoint is either a bare Vector3 — position only, the old form, still
## valid — or a Dictionary carrying "p" plus any of:
##
##   "tilt"        degrees of roll about the road's forward axis. This is the
##                 road's bank/corkscrew, and it is the ONLY thing that rolls
##                 the surface now that the curvature-derived bank is gone.
##   "half_width"  metres, overriding the cfg default at this waypoint.
##
## The curve's own frame also rolls wherever the path twists in 3D, and nobody
## chooses that: on a corkscrew it is the whole point, on a loop's staggered
## legs it is an artefact to cancel. Print the roll report and check.
func _position(points: Array, index: int) -> Vector3:
	var point: Variant = points[index]
	if point is Vector3:
		return point
	return (point as Dictionary)["p"]


func _tilt_of(points: Array, index: int) -> float:
	var point: Variant = points[index]
	if point is Dictionary:
		return float((point as Dictionary).get("tilt", 0.0))
	return 0.0


## "aim": a world direction the road's surface normal should face at this
## waypoint — the centre of a loop, say. Where it is given the tilt is solved
## for instead of written, which is the difference between "turn the road 47
## degrees here" and "point the road there". Zero means no aim was given.
func _aim_of(points: Array, index: int) -> Vector3:
	var point: Variant = points[index]
	if point is Dictionary:
		var aim: Variant = (point as Dictionary).get("aim", null)
		if aim is Vector3 and (aim as Vector3).length_squared() > 0.5:
			return (aim as Vector3).normalized()
	return Vector3.ZERO


## Solves each "aim" waypoint's tilt by repeated correction: set the tilt,
## sample the frame there, measure how far the normal still is from the target,
## subtract. A neighbour's tilt bleeds into this point's sample, so a single
## pass does not land it — a handful converges, and the residual after the last
## pass is what the roll report shows.
func _solve_aims(curve: Curve3D, points: Array) -> void:
	var aimed: Array = []
	for i in points.size():
		aimed.append(_aim_of(points, i) != Vector3.ZERO)
	var any := false
	for flag in aimed:
		any = any or flag
	if not any:
		return
	var offsets: Array = []
	for i in points.size():
		offsets.append(curve.get_closest_offset(_position(points, i)) if aimed[i] else 0.0)
	for pass_index in 8:
		for i in points.size():
			if not aimed[i]:
				continue
			var frame: Transform3D = curve.sample_baked_with_rotation(
					offsets[i], true, true)
			var aim: Vector3 = _aim_of(points, i)
			var gap := frame.basis.y.signed_angle_to(aim, frame.basis.z)
			curve.set_point_tilt(i, curve.get_point_tilt(i) - gap)
	_unwrap_tilts(curve)


## Tilt is stored as a raw angle and interpolated linearly between waypoints, so
## a solved series that steps from -3.02 rad to +2.97 is not a 0.3 rad turn — it
## is told to wind the road 343 degrees one way and then back again, twice per
## corkscrew, and it shows. The two angles are the same angle; they only need to
## be told which way round to travel, which means keeping every one within half a
## turn of its neighbour. Adding or subtracting a whole turn leaves the frame
## exactly where it was, so this is safe after the fact.
func _unwrap_tilts(curve: Curve3D) -> void:
	for i in range(1, curve.point_count):
		var previous := curve.get_point_tilt(i - 1)
		var adjusted := curve.get_point_tilt(i)
		while adjusted - previous > PI:
			adjusted -= TAU
		while adjusted - previous < -PI:
			adjusted += TAU
		curve.set_point_tilt(i, adjusted)


func _half_width_of(points: Array, index: int) -> float:
	var point: Variant = points[index]
	if point is Dictionary:
		return float((point as Dictionary).get("half_width", 0.0))
	return 0.0


## The tangent at a joint, taken from the two neighbours. A repeated waypoint
## gives a zero direction, which hands Catmull-Rom a zero-length handle and
## folds the curve back on itself — the turn radius collapses to a fraction of
## a metre and the road is unusable while still looking plausible in the route
## table. Refused rather than papered over, because the route is the only place
## the mistake is visible.
func _direction(points: Array, index: int) -> Vector3:
	var previous: Vector3 = _position(points, maxi(index - 1, 0))
	var next: Vector3 = _position(points, mini(index + 1, points.size() - 1))
	var heading: Vector3 = next - previous
	if heading.length_squared() < 0.000001:
		push_error("route has a repeated or collinear waypoint at index %d" % index)
		return Vector3.FORWARD
	return heading.normalized()


func _before(points: Array, index: int) -> float:
	if index == 0:
		return _after(points, 0)
	return _position(points, index).distance_to(_position(points, index - 1))


func _after(points: Array, index: int) -> float:
	if index == points.size() - 1:
		return _before(points, points.size() - 1)
	return _position(points, index).distance_to(_position(points, index + 1))


## Smallest circumradius over three consecutive samples. If that drops below
## the road's half width, the swept inner edge folds over itself.
func _report_radius(curve: Curve3D) -> void:
	var length := curve.get_baked_length()
	var steps := 400
	var smallest := INF
	var where := 0.0
	var previous := curve.sample_baked(0.0)
	var current := curve.sample_baked(length / float(steps))
	for i in range(2, steps + 1):
		var next := curve.sample_baked(length * float(i) / float(steps))
		var radius := _circumradius(previous, current, next)
		if radius < smallest:
			smallest = radius
			where = float(i) / float(steps)
		previous = current
		current = next
	print("  min turn radius %.1f m at t=%.2f  (road half width is %.1f)"
			% [smallest, where, DEFAULT_HALF_WIDTH])


func _circumradius(a: Vector3, b: Vector3, c: Vector3) -> float:
	var side_a := b.distance_to(c)
	var side_b := a.distance_to(c)
	var side_c := a.distance_to(b)
	var area := (b - a).cross(c - a).length() * 0.5
	if area < 0.000001:
		return INF
	return side_a * side_b * side_c / (4.0 * area)


## Closest two points that are far apart ALONG the curve. This is the number
## that says whether the ball can still tell which piece of road it is on: it
## finds its road by nearest point, and a hairpin's two sides or a spiral's two
## laps are only as far apart as this. Samples within 15% of the length are
## skipped, since those are just neighbours on the same stretch.
func _report_self_gap(curve: Curve3D) -> void:
	var length := curve.get_baked_length()
	var count := 300
	var samples: Array = []
	for i in count:
		samples.append(curve.sample_baked(length * float(i) / float(count)))
	var smallest := INF
	var where := 0.0
	var at_a := Vector3.ZERO
	var at_b := Vector3.ZERO
	for i in count:
		for j in range(i + 1, count):
			var apart := float(j - i) / float(count)
			if apart < 0.15:
				continue
			var gap := (samples[i] as Vector3).distance_to(samples[j])
			if gap < smallest:
				smallest = gap
				where = float(i) / float(count)
				at_a = samples[i]
				at_b = samples[j]
	print("  closest self-approach %.1f m at t=%.2f  (road half width is %.1f)"
			% [smallest, where, DEFAULT_HALF_WIDTH])
	if smallest < 2.0 * DEFAULT_HALF_WIDTH:
		print("    between %s and %s" % [at_a, at_b])


## How far the road's own frame rolls about its forward axis from one end of
## the route to the other. Two things put roll in: the waypoint "tilt" values,
## and the curve's own frame, which rolls wherever the path twists in 3D — on a
## corkscrew that is the effect being asked for, on the staggered legs of a loop
## it is an artefact nobody chose. A loop that reports a couple of hundred
## degrees has a surface rolling out from under the ball; that is the number
## worth eyeballing, and it is not visible in the route table.
func _report_roll(curve: Curve3D) -> void:
	var length := curve.get_baked_length()
	var steps := 600
	var previous: Transform3D = curve.sample_baked_with_rotation(0.0, true, true)
	var carried := 0.0
	for i in range(1, steps + 1):
		var frame: Transform3D = curve.sample_baked_with_rotation(
				length * float(i) / float(steps), true, true)
		# Measured on the NORMAL, not the lateral axis. Around a flat corner the
		# lateral axis swings to stay perpendicular to the new tangent, and on a
		# straight it lines up with the tangent itself — in both cases the
		# projected angle is meaningless. The normal only leaves world-up when
		# the surface genuinely rolls about its own forward axis, which is the
		# thing being reported.
		carried += rad_to_deg(
				previous.basis.y.signed_angle_to(frame.basis.y, frame.basis.z))
		previous = frame
	print("  road rolls %+.1f deg end to end" % carried)
