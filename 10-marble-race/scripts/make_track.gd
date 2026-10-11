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

## One entry per track, keyed by the curve's file name (without the extension)
## and then referenced from track_index.tres. A route must never come back near
## itself: the nearest point on the curve is how the ball finds its road, and
## that lookup has no answer where the road runs alongside itself.
const ROUTES := {
	# A gentle S: straight run-up, a wide left sweep, a wide right sweep,
	# run-out. The one the physics and the feel were tuned on.
	"track_01": [
		Vector3(0.0, 3.0, 0.0),
		Vector3(0.0, 3.0, -50.0),
		Vector3(-20.0, 3.0, -95.0),
		Vector3(-20.0, 3.0, -150.0),
		Vector3(5.0, 3.0, -195.0),
		Vector3(5.0, 3.0, -240.0),
	],
	# One wide hairpin: a long run-up, a 180 the ball has to hold a banked line
	# through, and a straight back out — long enough to reach top speed on.
	"track_02": [
		Vector3(0.0, 3.0, 0.0),
		Vector3(0.0, 3.0, -70.0),
		Vector3(-20.0, 3.0, -120.0),
		Vector3(-65.0, 3.0, -145.0),
		Vector3(-110.0, 3.0, -120.0),
		Vector3(-130.0, 3.0, -70.0),
		Vector3(-130.0, 3.0, 0.0),
	],
	# Chicanes: four alternating sweeps with almost no straight between them,
	# so the ball is always being asked to change its heading. The shared
	# tangent at each joint swings the heading hard, so a route like this comes
	# out far tighter than its waypoints look: 26 m of swing over 58 m of run-up
	# measures 28.5 m, against the 38 m the ball's grip was tuned on. It is the
	# one track that cannot be taken flat.
	"track_03": [
		Vector3(0.0, 3.0, 0.0),
		Vector3(0.0, 3.0, -62.0),
		Vector3(-14.0, 3.0, -113.0),
		Vector3(12.0, 3.0, -171.0),
		Vector3(-14.0, 3.0, -229.0),
		Vector3(12.0, 3.0, -287.0),
		Vector3(12.0, 3.0, -335.0),
	],
	# The one with a gradient: down off the start, through the low corner, and
	# back up a long climb. Flat again by the finish, because the run-out past
	# the line is built level with whatever the route ends on.
	"track_04": [
		Vector3(0.0, 6.0, 0.0),
		Vector3(0.0, 6.0, -60.0),
		Vector3(-15.0, 3.0, -120.0),
		Vector3(-60.0, 2.0, -155.0),
		Vector3(-110.0, 5.0, -135.0),
		Vector3(-135.0, 9.0, -90.0),
		Vector3(-140.0, 12.0, -30.0),
		Vector3(-140.0, 12.0, 30.0),
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
	quit()


func _build_curve(points: Array) -> Curve3D:
	var curve := Curve3D.new()
	for i in points.size():
		# One direction per joint, shared by both handles. Taking the chord to
		# each neighbour separately leaves a corner wherever the two chords
		# disagree, and a corner is a turn radius far tighter than the road is
		# wide — which is exactly how the swept surface folds over itself.
		var direction := _direction(points, i)
		curve.add_point(points[i],
				-direction * _before(points, i) * HANDLE_FRACTION,
				direction * _after(points, i) * HANDLE_FRACTION)
	return curve


func _direction(points: Array, index: int) -> Vector3:
	var previous: Vector3 = points[maxi(index - 1, 0)]
	var next: Vector3 = points[mini(index + 1, points.size() - 1)]
	return (next - previous).normalized()


func _before(points: Array, index: int) -> float:
	if index == 0:
		return _after(points, 0)
	return points[index].distance_to(points[index - 1])


func _after(points: Array, index: int) -> float:
	if index == points.size() - 1:
		return _before(points, points.size() - 1)
	return points[index].distance_to(points[index + 1])


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
	print("  min turn radius %.1f m at t=%.2f  (road half width is 3.0)" % [smallest, where])


func _circumradius(a: Vector3, b: Vector3, c: Vector3) -> float:
	var side_a := b.distance_to(c)
	var side_b := a.distance_to(c)
	var side_c := a.distance_to(b)
	var area := (b - a).cross(c - a).length() * 0.5
	if area < 0.000001:
		return INF
	return side_a * side_b * side_c / (4.0 * area)
