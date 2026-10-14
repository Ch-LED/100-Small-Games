class_name PinballKicker
extends StaticBody3D
## Something the ball gets thrown by: a bumper or a kickout.
##
## The two behave identically -- the ball is reflected off them AND thrown, and
## the hit scores -- and differ only in shape, colour and what they are worth.
## They therefore share one script and two scenes rather than being written out
## twice (spec 4.1).
##
## Jolt owns the collision: the shape is a real collider, so the ball can never
## pass through one. The throw on top is added here, because a passive bounce
## can never give back more energy than it was hit with, and a real bumper is
## driven by a solenoid.

@onready var _shape: CollisionShape3D = $Shape
@onready var _mesh: MeshInstance3D = $Mesh

var score := 100
var kick_speed := 7.0
var color := Color("E94560")
## Pitch of the note this one rings at, in Hz. A bumper is a bright ding and a
## kickout is a duller thud, and that difference has to live on the object.
var tone := 880.0

## Falls from 1 to 0 after a hit. Purely cosmetic -- the flash is the only way
## to tell which of three identical-looking bumpers just fired.
var _glow := 0.0


func configure(value: int, kick: float, tint: Color, pitch: float) -> void:
	score = value
	kick_speed = kick
	color = tint
	tone = pitch
	_refresh_material()


## Filled in by the table builder: the shape differs (a cylinder for a bumper, a
## bar for a kickout) but nothing else about the object does.
func set_collision(shape: Shape3D, offset: Vector3) -> void:
	_shape.shape = shape
	_shape.position = offset


func set_mesh(mesh: Mesh, offset: Vector3) -> void:
	_mesh.mesh = mesh
	_mesh.position = offset


## Called from the ball's _integrate_forces. Returns what the hit is worth; the
## ball passes it up to the run.
func on_ball_hit(state: PhysicsDirectBodyState3D, contact_point: Vector3) -> int:
	var plane_up := global_transform.basis.y
	var away := state.transform.origin - contact_point
	away -= plane_up * away.dot(plane_up)
	if away.length_squared() < 0.000001:
		return 0
	state.linear_velocity += away.normalized() * kick_speed
	_glow = 1.0
	_refresh_material()
	return score


func _process(delta: float) -> void:
	if _glow <= 0.0:
		return
	_glow = maxf(0.0, _glow - delta * 4.5)
	_refresh_material()


func _refresh_material() -> void:
	if _mesh == null:
		return
	var material := _mesh.material_override as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		material.roughness = 0.35
		# The wedges are extruded from an arbitrary triangle, and one material
		# for both kinds of kicker is worth more than correct backface culling
		# on a shape the player never sees the inside of.
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mesh.material_override = material
	material.albedo_color = color.lerp(Color.WHITE, _glow * 0.7)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.4 + _glow * 3.0
