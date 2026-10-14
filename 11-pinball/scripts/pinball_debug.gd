class_name PinballDebug
extends Node3D
## The P overlay: read-only, and it never changes play.
##
## It draws the two physics in two colours on purpose. With Jolt handling the
## static geometry and this script handling the flippers, "what just hit the
## ball" is the first question every bug here will start with -- and the answer
## should be a glance at the colour, not an argument (spec 13.3).

@onready var _surface: MeshInstance3D = $Surface

## Jolt's geometry, in the project's debug yellow.
const JOLT_COLOR := Color("FFE94A")
## The flipper's reach, this frame. Same teal as the flipper itself.
const HAND_COLOR := Color("4ECDC4")
## The flipper's reach last frame: the two together are the swept band.
const PREV_COLOR := Color("7A5CFF")
const VELOCITY_COLOR := Color("FF6B6B")

## Corner pairs of a box, indexed by the bit pattern in _draw_box.
const BOX_EDGES: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(1, 3), Vector2i(3, 2), Vector2i(2, 0),
	Vector2i(4, 5), Vector2i(5, 7), Vector2i(7, 6), Vector2i(6, 4),
	Vector2i(0, 4), Vector2i(1, 5), Vector2i(2, 6), Vector2i(3, 7),
]

var _enabled := false
var _table: Node3D
var _ball: PinballBall
var _flippers: Array[PinballFlipper] = []
var _material: StandardMaterial3D
## Everything below is worked out in world space and has to come back into the
## mesh's own space before it is handed to the vertex buffer: ImmediateMesh
## vertices are local to the MeshInstance3D they are drawn on, and that node
## sits under the tilted table. Skipping this step draws the whole overlay
## rotated by the table's tilt (spec 3.2).
var _to_local := Transform3D.IDENTITY


func setup(table: Node3D, ball: PinballBall, flippers: Array[PinballFlipper]) -> void:
	_table = table
	_ball = ball
	_flippers = flippers


func set_enabled(on: bool) -> void:
	_enabled = on
	if not on:
		# Clearing the mesh, not just stopping the redraw: _draw output is
		# cached, and "stopped updating" looks identical to "still there".
		_surface.mesh = null


func is_enabled() -> bool:
	return _enabled


func _process(_delta: float) -> void:
	if not _enabled or _table == null:
		return
	_to_local = _surface.global_transform.affine_inverse()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, _line_material())
	_walk_shapes(mesh, _table)
	for flipper in _flippers:
		_draw_flipper(mesh, flipper)
	_draw_ball(mesh)
	mesh.surface_end()
	_surface.mesh = mesh


func _walk_shapes(mesh: ImmediateMesh, node: Node) -> void:
	for child in node.get_children():
		if child is CollisionShape3D:
			_draw_shape(mesh, child)
		_walk_shapes(mesh, child)


func _draw_shape(mesh: ImmediateMesh, collider: CollisionShape3D) -> void:
	var shape := collider.shape
	if shape is BoxShape3D:
		_draw_box(mesh, collider.global_transform, (shape as BoxShape3D).size)
	elif shape is SphereShape3D:
		_draw_sphere(mesh, collider.global_transform, (shape as SphereShape3D).radius)
	elif shape is CylinderShape3D:
		_draw_cylinder(mesh, collider.global_transform, shape as CylinderShape3D)


func _draw_flipper(mesh: ImmediateMesh, flipper: PinballFlipper) -> void:
	var up := flipper.global_transform.basis.y
	var previous := flipper.axis_segment(true)
	_draw_capsule(mesh, previous[0], previous[1], flipper.radius, PREV_COLOR, up)
	var current := flipper.axis_segment(false)
	_draw_capsule(mesh, current[0], current[1], flipper.radius, HAND_COLOR, up)


func _draw_ball(mesh: ImmediateMesh) -> void:
	var velocity := _ball.linear_velocity
	if velocity.length() < 0.05:
		return
	_line(mesh, _ball.global_position, _ball.global_position + velocity * 0.15, VELOCITY_COLOR)


func _draw_box(mesh: ImmediateMesh, xform: Transform3D, size: Vector3) -> void:
	var half := size * 0.5
	var corners: Array[Vector3] = []
	for i in 8:
		corners.append(xform * Vector3(
				half.x if (i & 1) else -half.x,
				half.y if (i & 2) else -half.y,
				half.z if (i & 4) else -half.z))
	for edge in BOX_EDGES:
		_line(mesh, corners[edge.x], corners[edge.y], JOLT_COLOR)


## A cylinder drawn as its two end rings plus four uprights. Enough to read the
## radius and where it stands, which is all a bumper's shape is asked to say.
func _draw_cylinder(mesh: ImmediateMesh, xform: Transform3D, shape: CylinderShape3D) -> void:
	var up := xform.basis.y.normalized() * (shape.height * 0.5)
	var top := xform.origin + up
	var bottom := xform.origin - up
	_draw_sphere(mesh, Transform3D(xform.basis, top), shape.radius)
	_draw_sphere(mesh, Transform3D(xform.basis, bottom), shape.radius)
	var axes: Array[Vector3] = [xform.basis.x, xform.basis.z]
	for axis in axes:
		var side := axis.normalized() * shape.radius
		_line(mesh, top + side, bottom + side, JOLT_COLOR)
		_line(mesh, top - side, bottom - side, JOLT_COLOR)


func _draw_sphere(mesh: ImmediateMesh, xform: Transform3D, radius: float) -> void:
	var segments := 16
	for axis in 3:
		var previous := Vector3.ZERO
		for i in segments + 1:
			var t := TAU * float(i) / float(segments)
			var point := Vector3.ZERO
			match axis:
				0: point = Vector3(0.0, cos(t), sin(t))
				1: point = Vector3(cos(t), 0.0, sin(t))
				_: point = Vector3(cos(t), sin(t), 0.0)
			point = xform * (point * radius)
			if i > 0:
				_line(mesh, previous, point, JOLT_COLOR)
			previous = point


func _draw_capsule(mesh: ImmediateMesh, a: Vector3, b: Vector3, radius: float, color: Color, up: Vector3) -> void:
	_line(mesh, a, b, color)
	var side := (b - a).normalized().cross(up)
	if side.length_squared() < 0.000001:
		return
	side = side.normalized()
	_draw_capsule_end(mesh, a, side, up, radius, color)
	_draw_capsule_end(mesh, b, side, up, radius, color)


## A half circle across one end of the capsule, drawn in the plane the flipper
## swings in so the reach reads at a glance.
func _draw_capsule_end(mesh: ImmediateMesh, center: Vector3, side: Vector3, up: Vector3, radius: float, color: Color) -> void:
	var segments := 10
	var previous := center + side * radius
	for i in range(1, segments + 1):
		var t := PI * float(i) / float(segments)
		var point := center + side * (cos(t) * radius) + up * (sin(t) * radius)
		_line(mesh, previous, point, color)
		previous = point


func _line(mesh: ImmediateMesh, a: Vector3, b: Vector3, color: Color) -> void:
	_vertex(mesh, a, color)
	_vertex(mesh, b, color)


func _vertex(mesh: ImmediateMesh, position: Vector3, color: Color) -> void:
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(_to_local * position)


func _line_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.vertex_color_use_as_albedo = true
	return _material
