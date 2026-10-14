class_name PinballFlipper
extends Node3D
## One flipper, driven by hand.
##
## It has NO collision shape. Deliberately: if the flipper were also a Jolt
## body, the ball would take the engine's soft push AND this script's impulse,
## in a ratio that drifts frame to frame -- and nothing that happens on the
## table would be traceable to a single cause (spec 4.1).
##
## This node sits AT the pivot, so its own +X axis is the flipper's length.
## rotation.y is kept as the negative of `angle` because a table-plane angle
## (atan2 of z over x) runs the other way round from a Y-axis rotation.

@onready var _mesh: MeshInstance3D = $Mesh

## The flipper was asked to move. Announced on the INPUT, not when the arm
## reaches its stop: on a real machine the solenoid fires the instant the button
## goes down, and the clack is the button, not the arm.
signal clacked(raised: bool)

## Table-plane angle in radians: rest is positive (the free end hangs toward
## the near end), raised is negative. Mirrored flippers negate it on the way in.
var angle := 0.0

## Which project input action raises this flipper.
var input_action: StringName = &"wasd_left"

## True for the right-hand flipper: mirrors the mount across the centre line.
var mirrored := false

var length := 2.0
## What `length` was configured as. The cheat multiplies this rather than the
## current length, so turning it off restores exactly what was set up.
var base_length := 2.0
var radius := 0.35
var rest_angle := deg_to_rad(22.0)
var up_angle := deg_to_rad(-28.0)
var flip_angular_speed := 8.0
var return_angular_speed := 12.0
var restitution := 0.45
var contact_slack := 1.15

## Signed rate of `rotation.y`. This is the number the contact point's speed is
## worked out from, so it is read off the rotation actually applied rather than
## recomputed from the angles -- one fewer sign to get wrong.
var _spin := 0.0

## Last frame's input state, so a change can be announced exactly once.
var _raised := false

## The capsule's axis as a segment. `_axis_prev` is where it was last frame:
## real machines sweep, and a test that only ever looks at the current pose
## would miss a ball the flipper swept through.
var _axis_prev: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _axis_cur: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]


## Where a flipper sits, how long it is and how far it swings are all things
## the TABLE says -- they came out of the original's data with everything else.
## Only the feel (speed, restitution) belongs in the config: a geometric copy
## there would just be a second place to change one number.
func configure(settings: Dictionary, mount: Dictionary) -> void:
	length = float(mount.length)
	base_length = length
	rest_angle = deg_to_rad(float(mount.rest_angle_deg))
	up_angle = deg_to_rad(float(mount.up_angle_deg))
	radius = float(settings.radius)
	flip_angular_speed = float(settings.flip_angular_speed)
	return_angular_speed = float(settings.return_angular_speed)
	restitution = float(settings.restitution)
	contact_slack = float(settings.contact_slack)
	input_action = mount.input_action
	mirrored = bool(mount.mirrored)
	if mirrored:
		# Mirroring is PI - angle, not -angle: negating gives the right-hand
		# flipper the left one's angles reflected through the TABLE's centre
		# line rather than through the pivot, which points its free end at the
		# wall instead of at the drain. The two differ by exactly 180 degrees.
		rest_angle = PI - rest_angle
		up_angle = PI - up_angle
	angle = rest_angle
	rotation.y = -angle
	_resize_mesh()
	if is_inside_tree():
		_axis_cur = _axis_now()
		_axis_prev = _axis_cur


func _ready() -> void:
	rotation.y = -angle
	_resize_mesh()
	_axis_cur = _axis_now()
	_axis_prev = _axis_cur


## Runs before the ball's _integrate_forces in the same physics tick: Godot
## calls _physics_process before it steps the physics server, so the ball
## always reads this frame's flipper pose and never last frame's (spec 4.3).
func _physics_process(delta: float) -> void:
	var raised := Input.is_action_pressed(input_action)
	if raised != _raised:
		_raised = raised
		clacked.emit(raised)
	var target := up_angle if raised else rest_angle
	var speed := flip_angular_speed if raised else return_angular_speed
	angle = move_toward(angle, target, speed * delta)
	var previous_rotation := rotation.y
	rotation.y = -angle
	_spin = (rotation.y - previous_rotation) / delta if delta > 0.0 else 0.0
	_axis_prev = _axis_cur
	_axis_cur = _axis_now()


## Returns an empty dictionary when the ball is out of reach, otherwise the
## geometry of the closest approach.
##
## The test is per frame rather than swept, and at this game's numbers that is
## sound: the ball covers 0.44 units per tick at the speed cap, while the reach
## below is 0.80 plus slack -- far too little travel to clear the flipper in one
## step. A swept test would only start earning its keep above roughly 90 m/s.
func test_contact(ball_position: Vector3, ball_radius: float) -> Dictionary:
	var reach := ball_radius + radius
	var closest: Vector3 = Geometry3D.get_closest_point_to_segment(
			ball_position, _axis_cur[0], _axis_cur[1])
	var up := global_transform.basis.y
	var offset := ball_position - closest
	offset -= up * offset.dot(up)          # the ball and the flipper share a plane
	var distance := offset.length()
	if distance > reach * contact_slack:
		return {}
	var normal := up.cross(_axis_cur[1] - _axis_cur[0]).normalized()
	if distance > 0.0001:
		normal = offset / distance
	return {
		"point": closest,
		"normal": normal,
		"distance": distance,
		"reach": reach,
	}


## Speed of the flipper's surface at `point`, in world space. This is what the
## ball gets hit by, and it is why a lever hits harder out at the free end.
func surface_velocity_at(point: Vector3) -> Vector3:
	var arm := point - global_position
	return global_transform.basis.y.cross(arm) * _spin


## Report only; the debug overlay draws both poses to show the swept band.
func axis_segment(previous: bool = false) -> Array[Vector3]:
	return _axis_prev if previous else _axis_cur


func apply_length_scale(scale: float) -> void:
	length = base_length * scale
	_resize_mesh()
	_axis_cur = _axis_now()
	_axis_prev = _axis_cur


func _axis_now() -> Array[Vector3]:
	var base := global_position
	var tip := base + global_transform.basis.x * length
	var axis: Array[Vector3] = [base, tip]
	return axis


func _resize_mesh() -> void:
	# Only reachable once the node is in the tree, since @onready fills _mesh.
	if _mesh == null:
		return
	# Resize the mesh the scene already carries rather than replacing it: the
	# scene's material lives on that resource, and a fresh mesh would drop it.
	var capsule := _mesh.mesh as CapsuleMesh
	if capsule == null:
		capsule = CapsuleMesh.new()
		_mesh.mesh = capsule
	capsule.radius = radius
	capsule.height = length + radius * 2.0
	# The capsule mesh runs along Y and sits centred; stand it on the pivot's X
	# axis and push it out so it spans pivot to free end.
	_mesh.position = Vector3(length * 0.5, 0.0, 0.0)
	_mesh.rotation = Vector3(0.0, 0.0, -PI * 0.5)
