class_name PinballBall
extends RigidBody3D
## The ball. Jolt owns everything about it except the flippers.
##
## The flippers have no collision shape, so nothing the engine knows about can
## stop the ball from passing straight through one. This script closes that gap:
## each physics tick it asks every flipper how close the ball came, and applies
## the impulse the swept surface would have given it (spec 4.1, 4.3).

@onready var _shape: CollisionShape3D = $Shape
@onready var _mesh: MeshInstance3D = $Mesh

## Something was hit that is worth points. Carries what it was worth and the
## note it rings at, so whoever keeps score does not need to know what a bumper
## is (spec 3.1).
signal scored(amount: int, tone: float)

## The one colour every game in this project marks the super cheat with. A
## constant rather than a config value, so it cannot drift game to game.
const SUPER_COLOR := Color("00E676")
const PLAIN_COLOR := Color("FF6D00")

var _cfg: Dictionary = {}
var _flippers: Array[PinballFlipper] = []
var _radius := 0.45
var _max_speed := 32.0
var _super := false

## The table's surface normal, in world space. Handed over by the table because
## the ball's own basis spins and cannot be trusted for "which way is up here".
var plane_normal := Vector3.UP

## A launch queued from ordinary code, carried out inside the physics step.
## Teleporting a rigid body from outside _integrate_forces races the solver.
var _pending_launch: Dictionary = {}

## What the ball was touching last frame, as a set. See _report_hits.
var _touching: Dictionary = {}


func configure(settings: Dictionary) -> void:
	_cfg = settings
	mass = float(_cfg.mass)
	# The speed lever. Raising the table's tilt instead would run it out of
	# angles; a heavier ball under the same tilt accelerates harder.
	gravity_scale = float(_cfg.gravity_scale)
	# From the table data, like every other measurement on it.
	_radius = PinballLayout.BALL_RADIUS
	_max_speed = float(_cfg.max_speed)
	# High speed against thin walls tunnels without this.
	continuous_cd = true
	# _integrate_forces is never called on a sleeping body, and the flipper
	# impulse lives there -- a ball that ever dozed off could never be woken.
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = 8
	# The ball ROLLS. Damping the spin is what decides that, not friction: at
	# 4.0 the ball's rotation was killed as fast as friction built it, so it
	# read as a puck sliding down the table. Friction needs to be high enough
	# to keep a rolling contact from slipping, and the spin has to be left
	# alone for it to ever get there.
	linear_damp = float(_cfg.linear_damp)
	angular_damp = float(_cfg.angular_damp)
	var material := PhysicsMaterial.new()
	material.friction = float(_cfg.friction)
	material.bounce = float(_cfg.bounce)
	physics_material_override = material
	var sphere := SphereShape3D.new()
	sphere.radius = _radius
	_shape.shape = sphere
	var ball_mesh := SphereMesh.new()
	ball_mesh.radius = _radius
	ball_mesh.height = _radius * 2.0
	_mesh.mesh = ball_mesh
	_mesh.material_override = _patterned_material()


func set_flippers(flippers: Array[PinballFlipper]) -> void:
	_flippers = flippers


## Place the ball and send it toward `aim`, both in world space. Nothing
## happens here; it happens in the physics step.
func request_launch(from: Vector3, aim: Vector3, speed: float) -> void:
	_pending_launch = {"from": from, "aim": aim, "speed": speed}
	# The ball is being moved, so whatever it was touching it is no longer
	# touching. Without this the first hit after a reset is swallowed: the
	# kicker is still in the set from before the ball was taken away.
	_touching = {}


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _cfg.is_empty():
		return
	if not _pending_launch.is_empty():
		_do_launch(state)
		return
	var position := state.transform.origin
	for flipper in _flippers:
		var contact := flipper.test_contact(position, _radius)
		if contact.is_empty():
			continue
		_resolve_flipper(state, flipper, contact)
		position = state.transform.origin
	_report_hits(state)
	_clamp_speed(state)


## A hit is announced the first frame the contact shows up and never again while
## it lasts. contact_monitor reports the pairs touching THIS frame, so a ball
## resting against a bumper would otherwise score on every one of them.
##
## Nothing needs to check whether a kicker is a bumper or a kickout here: each
## one knows what it is worth and what it rings at.
func _report_hits(state: PhysicsDirectBodyState3D) -> void:
	var touching := {}
	for i in state.get_contact_count():
		var other := state.get_contact_collider_object(i)
		if other == null:
			continue
		touching[other] = true
		if _touching.has(other):
			continue
		var point := state.get_contact_local_position(i)
		var value := 0
		var tone := 0.0
		if other is PinballKicker:
			var kicker := other as PinballKicker
			value = kicker.on_ball_hit(state, point)
			tone = kicker.tone
		elif other is PinballTarget:
			var target := other as PinballTarget
			value = target.on_ball_hit(state, point)
			tone = target.tone
		if value > 0:
			scored.emit(value, tone)
	_touching = touching


## The impulse a moving surface gives a ball it has just run into. The flipper
## counts as infinitely heavy -- it is driven by a solenoid, not by the ball --
## so only the ball's velocity changes.
##
## Deciding there IS a contact and applying force are kept apart: the force only
## lands when the two are closing, so the conservative reach used in the test
## can over-report contacts without ever over-hitting the ball.
func _resolve_flipper(state: PhysicsDirectBodyState3D, flipper: PinballFlipper, contact: Dictionary) -> void:
	var normal: Vector3 = contact.normal
	var point: Vector3 = contact.point
	var closing := (state.linear_velocity - flipper.surface_velocity_at(point)).dot(normal)
	if closing < 0.0:
		state.linear_velocity -= normal * (1.0 + flipper.restitution) * closing
	var depth: float = float(contact.reach) - float(contact.distance)
	if depth > 0.0:
		state.transform.origin += normal * depth


## Places the ball and optionally sends it off. A speed of zero is the plain
## placement used to return the ball to the lane -- there is no direction to
## read from `aim` in that case, so the two are handled separately rather than
## letting a zero vector fall through.
func _do_launch(state: PhysicsDirectBodyState3D) -> void:
	var from: Vector3 = _pending_launch["from"]
	var aim: Vector3 = _pending_launch["aim"]
	var speed: float = _pending_launch["speed"]
	_pending_launch = {}
	state.transform.origin = from
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	if speed <= 0.0:
		return
	var direction := aim - from
	direction -= plane_normal * direction.dot(plane_normal)
	if direction.length_squared() < 0.000001:
		return
	state.linear_velocity = direction.normalized() * speed


func _clamp_speed(state: PhysicsDirectBodyState3D) -> void:
	var speed := state.linear_velocity.length()
	if speed > _max_speed:
		state.linear_velocity *= _max_speed / speed


func set_super(on: bool) -> void:
	if on == _super:
		return
	_super = on
	_mesh.material_override = _patterned_material()


## A plain sphere looks identical at every rotation, and a ball that reads as
## gliding when it is rolling (or the reverse) is a ball whose state the player
## cannot see. The pattern is the only window onto it.
func _patterned_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = _checker_texture(6, Color("F2F5F7"), SUPER_COLOR if _super else PLAIN_COLOR)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.35
	return material


static func _checker_texture(cells: int, light: Color, dark: Color) -> ImageTexture:
	var image := Image.create(cells, cells, false, Image.FORMAT_RGB8)
	for y in cells:
		for x in cells:
			image.set_pixel(x, y, light if (x + y) % 2 == 0 else dark)
	return ImageTexture.create_from_image(image)
