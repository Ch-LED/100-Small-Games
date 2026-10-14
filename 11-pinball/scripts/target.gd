class_name PinballTarget
extends StaticBody3D
## A drop target: a thin blade that gets knocked flat.
##
## It goes DOWN rather than disappearing. The collision body sinks with the
## blade, so once it has been hit the ball rolls straight over where it used to
## stand -- which is the entire point of hitting it, and the reason this is its
## own object rather than another kicker.

@onready var _shape: CollisionShape3D = $Shape
@onready var _mesh: MeshInstance3D = $Mesh

## How far it sinks when knocked down. Just short of its own height, so the top
## of the blade ends up flush with the table and nothing is left to trip on.
const SINK_RATIO := 0.8
const DOWN_COLOR := Color("3A3F58")

var score := 25
var tone := 700.0
var color := Color("FFD24A")

var _height := 1.0
var _down := false
var _rest_y := 0.0


func configure(value: int, pitch: float, tint: Color, height: float) -> void:
	score = value
	tone = pitch
	color = tint
	_height = height
	_rest_y = _shape.position.y
	_refresh()


## Filled in by the table builder: the blade is an arbitrary quad on the table
## (the originals are not all axis-aligned), so the shape and the mesh both come
## from the same four corners.
func set_geometry(shape: Shape3D, mesh: Mesh, offset: Vector3) -> void:
	_shape.shape = shape
	_mesh.mesh = mesh
	_shape.position = offset
	_mesh.position = offset
	_rest_y = offset.y
	_refresh()


## Called from the ball's _integrate_forces, same contract as a kicker. Returns
## what the hit is worth -- nothing if it was already down.
func on_ball_hit(_state: PhysicsDirectBodyState3D, _contact_point: Vector3) -> int:
	if _down:
		return 0
	_down = true
	var sink := _height * SINK_RATIO
	_shape.position.y = _rest_y - sink
	_mesh.position.y = _rest_y - sink
	_refresh()
	return score


## Back up, ready for the next ball.
func reset() -> void:
	if not _down:
		return
	_down = false
	_shape.position.y = _rest_y
	_mesh.position.y = _rest_y
	_refresh()


func _refresh() -> void:
	if _mesh == null:
		return
	var material := _mesh.material_override as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		material.roughness = 0.4
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mesh.material_override = material
	material.albedo_color = DOWN_COLOR if _down else color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.0 if _down else 0.9
