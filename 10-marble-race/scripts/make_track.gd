extends SceneTree
## Track authoring tool. Bakes the waypoint list below into the Curve3D that
## the track sweeps — Catmull-Rom tangent handles so the road has no creases —
## and prints the minimum turn radius so the curve can be checked against the
## sweep width before anything is built from it.
##
## A curve can also be edited by dragging its points in the 3D viewport, and
## for a one-off tweak that is the right way. This exists for rebuilding a
## curve from a readable list, and it is the only record of why the waypoints
## are where they are.
##
## Run: godot --headless --path . --script res://10-marble-race/scripts/make_track.gd

const OUT_PATH := "res://10-marble-race/resources/tracks/track_01.tres"

## A gentle S: straight run-up, a wide left sweep, a wide right sweep, run-out.
const WAYPOINTS: Array[Vector3] = [
	Vector3(0.0, 3.0, 0.0),
	Vector3(0.0, 3.0, -50.0),
	Vector3(-20.0, 3.0, -95.0),
	Vector3(-20.0, 3.0, -150.0),
	Vector3(5.0, 3.0, -195.0),
	Vector3(5.0, 3.0, -240.0),
]

const HANDLE_FRACTION := 0.35


func _initialize() -> void:
	var curve := Curve3D.new()
	for i in WAYPOINTS.size():
		# One direction per joint, shared by both handles. Taking the chord to
		# each neighbour separately leaves a corner wherever the two chords
		# disagree, and a corner is a turn radius far tighter than the road is
		# wide — which is exactly how the swept surface folds over itself.
		var direction := _direction(i)
		curve.add_point(WAYPOINTS[i],
				-direction * _before(i) * HANDLE_FRACTION,
				direction * _after(i) * HANDLE_FRACTION)
	ResourceSaver.save(curve, OUT_PATH)
	print("saved %s  (%d points, %.1f m long)"
			% [OUT_PATH, curve.point_count, curve.get_baked_length()])
	_report_radius(curve)
	quit()


func _direction(index: int) -> Vector3:
	var previous := WAYPOINTS[maxi(index - 1, 0)]
	var next := WAYPOINTS[mini(index + 1, WAYPOINTS.size() - 1)]
	return (next - previous).normalized()


func _before(index: int) -> float:
	if index == 0:
		return _after(0)
	return WAYPOINTS[index].distance_to(WAYPOINTS[index - 1])


func _after(index: int) -> float:
	if index == WAYPOINTS.size() - 1:
		return _before(index)
	return WAYPOINTS[index].distance_to(WAYPOINTS[index + 1])


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
