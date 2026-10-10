class_name MarbleBall
extends RigidBody3D
## Rolling ball. The drive is real torque — Jolt integrates the spin and
## contact friction turns it into motion (DECISION_LOG 055).
##
## Steering axis is the surface normal x the drive direction, which is the axis
## a ball rolling that way would spin about (technical spec 4.3).

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _shape: CollisionShape3D = $Shape

## Yaw-only basis the steering input is resolved in. The race controller
## refreshes it every physics frame; identity means world axes, which is what
## the headless probe relies on.
var steering_basis := Basis()

## Up direction of the surface the ball is on. The race controller refreshes it
## from the track each physics frame. Flat road gives world up, so this only
## diverges from it once the track banks.
var surface_normal := Vector3.UP

## True while the race controller judges the ball to be on the road, which is
## what arms the surface settling below.
var grounded := false

## True while the level is holding the ball on the start line. The drive is
## skipped rather than the body frozen: freeze stops _integrate_forces, and a
## body that does not run that callback cannot be driven at all.
var frozen := false

## Last commanded drive direction, world space, for diagnostics and probes.
var drive_direction := Vector3.ZERO

## How hard the ball is being held back. All three are the same pair of damping
## values, just chosen differently; there is no separate brake force, because
## on a rolling ball the dampers ARE the brake.
enum Resistance { COAST, DRIVE, BRAKE }

var _cfg: Dictionary = {}
var _resistance := Resistance.COAST


func configure(settings: Dictionary) -> void:
	_cfg = settings.ball
	mass = float(_cfg.mass)
	gravity_scale = float(_cfg.gravity_scale)
	# High speed against a thin track tunnels without this; see spec 4.2.
	continuous_cd = true
	# The drive lives in _integrate_forces, which is never called on a sleeping
	# body — so a ball that ever dozed off could never be woken by the player.
	can_sleep = false
	_apply_resistance(Resistance.COAST)
	var material := PhysicsMaterial.new()
	material.friction = float(_cfg.friction)
	material.bounce = float(_cfg.bounce)
	physics_material_override = material
	var radius: float = _cfg.radius
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	_shape.shape = sphere
	var ball_mesh := SphereMesh.new()
	ball_mesh.radius = radius
	ball_mesh.height = radius * 2.0
	_mesh.mesh = ball_mesh
	_mesh.material_override = _patterned_material()


## A plain sphere looks identical at every rotation, and the spin is this
## game's entire input — the pattern is the only way to read it back.
func _patterned_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = _checker_texture(6, Color("F2F5F7"), Color("FF6D00"))
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.55
	return material


static func _checker_texture(cells: int, light: Color, dark: Color) -> ImageTexture:
	var image := Image.create(cells, cells, false, Image.FORMAT_RGB8)
	for y in cells:
		for x in cells:
			image.set_pixel(x, y, light if (x + y) % 2 == 0 else dark)
	return ImageTexture.create_from_image(image)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _cfg.is_empty() or frozen:
		return
	if grounded:
		_settle_on_surface(state)
	var steer := _read_steer()
	# The brake overrides the drive rather than fighting it. Steering IS the
	# throttle in this game, so there is no way to ask for both, and a brake
	# that loses to a held accelerator is not a brake.
	var braking := Input.is_action_pressed("fire")
	_apply_resistance(Resistance.BRAKE if braking
			else (Resistance.DRIVE if steer != Vector2.ZERO else Resistance.COAST))
	if braking or steer == Vector2.ZERO:
		drive_direction = Vector3.ZERO
	else:
		_drive(state, steer)
	_clamp_speed(state)


## The road is a swept polyline, so every ring joint is a crease: the ball's
## velocity lies in one facet and then suddenly does not, and the solver
## answers the mismatch by kicking the ball off the surface. That reads as it
## stumbling.
##
## Only the OUTWARD half of that kick is cancelled. Cancelling both halves was
## the first attempt and it stopped the ball driving altogether — the normal
## impulse the solver would have spent pressing the ball onto the road is also
## the impulse friction is proportional to, so flattening the velocity into the
## road plane removes the grip along with the jolt. Letting the ball keep
## pressing in and refusing to let it leave is what removes the stumble and
## keeps the traction.
##
## It is still deliberately unphysical: no bounce off the road, ever. Jumping
## is not in this game, so that is physics it does not want.
func _settle_on_surface(state: PhysicsDirectBodyState3D) -> void:
	var velocity := state.linear_velocity
	var outward := velocity.dot(surface_normal)
	if outward > 0.0:
		state.linear_velocity = velocity - surface_normal * outward


func _drive(state: PhysicsDirectBodyState3D, steer: Vector2) -> void:
	var aimed := (steering_basis * Vector3(steer.x, 0.0, steer.y)).normalized()
	# Steering arrives in a plane perpendicular to world up, which stops being
	# the road's plane the moment the road banks. Projecting it onto the road
	# is what keeps a banked corner steering where it looks like it should.
	var in_plane := aimed - surface_normal * aimed.dot(surface_normal)
	if in_plane.length_squared() < 0.000001:
		drive_direction = Vector3.ZERO
		return
	drive_direction = in_plane.normalized()
	var axis := surface_normal.cross(drive_direction)
	if axis.length_squared() < 0.000001:
		return
	var torque: float = _cfg.spin_torque * _turn_boost(state.linear_velocity)
	state.apply_torque(axis.normalized() * torque)


## Swinging the spin axis round to a new heading takes (v/r)*2sin(theta/2) of
## angular velocity, so a turn costs far more than holding a line — yet a
## constant torque pushes equally either way, which is what made it corner like
## a stone block. Scaling by the angle to the current motion spends the effort
## where the turn actually is, and on hard corners it surges past the traction
## limit, which is where the drift comes from.
func _turn_boost(velocity: Vector3) -> float:
	var speed := velocity.length()
	if speed < float(_cfg.min_turn_speed):
		return 1.0
	var angle := (velocity / speed).angle_to(drive_direction)
	return 1.0 + float(_cfg.turn_boost) * (angle / PI)


## Resistance is lower while the player is steering than while the ball coasts,
## so the drive feels responsive when you ask for it and the ball still settles
## instead of gliding like ice the moment you let go. The damps — not friction —
## are what stop a rolling ball, since a rolling contact does no work.
func _apply_resistance(level: Resistance) -> void:
	if level == _resistance:
		return
	_resistance = level
	match level:
		Resistance.DRIVE:
			linear_damp = float(_cfg.linear_damp_active)
			angular_damp = float(_cfg.angular_damp_active)
		Resistance.BRAKE:
			linear_damp = float(_cfg.brake_linear_damp)
			angular_damp = float(_cfg.brake_angular_damp)
		_:
			linear_damp = float(_cfg.linear_damp)
			angular_damp = float(_cfg.angular_damp)


func _clamp_speed(state: PhysicsDirectBodyState3D) -> void:
	var cap: float = _cfg.max_speed
	var velocity := state.linear_velocity
	if velocity.length() > cap:
		state.linear_velocity = velocity.normalized() * cap


func _read_steer() -> Vector2:
	var steer := Vector2.ZERO
	if Input.is_action_pressed("wasd_left") or Input.is_action_pressed("arrow_left"):
		steer.x -= 1.0
	if Input.is_action_pressed("wasd_right") or Input.is_action_pressed("arrow_right"):
		steer.x += 1.0
	if Input.is_action_pressed("wasd_up") or Input.is_action_pressed("arrow_up"):
		steer.y -= 1.0
	if Input.is_action_pressed("wasd_down") or Input.is_action_pressed("arrow_down"):
		steer.y += 1.0
	return steer.limit_length(1.0)
