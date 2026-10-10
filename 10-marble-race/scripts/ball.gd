class_name MarbleBall
extends RigidBody3D
## Rolling ball. The drive is real torque — Jolt integrates the spin and
## contact friction turns it into motion (DECISION_LOG 055).
##
## Steering axis is up x direction, which is the axis a ball rolling that way
## would spin about (technical spec 4.3).

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _shape: CollisionShape3D = $Shape

## Yaw-only basis the steering input is resolved in. The race controller
## refreshes it every physics frame; identity means world axes, which is what
## the headless probe relies on.
var steering_basis := Basis()

## Last commanded drive direction, world space, for diagnostics and probes.
var drive_direction := Vector3.ZERO

var _cfg: Dictionary = {}
var _driving := false


func configure(settings: Dictionary) -> void:
	_cfg = settings.ball
	mass = float(_cfg.mass)
	gravity_scale = float(_cfg.gravity_scale)
	# High speed against a thin track tunnels without this; see spec 4.2.
	continuous_cd = true
	# The drive lives in _integrate_forces, which is never called on a sleeping
	# body — so a ball that ever dozed off could never be woken by the player.
	can_sleep = false
	_set_resistance(false)
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
	if _cfg.is_empty():
		return
	var steer := _read_steer()
	_set_resistance(steer != Vector2.ZERO)
	if steer == Vector2.ZERO:
		drive_direction = Vector3.ZERO
	else:
		_drive(state, steer)
	_clamp_speed(state)


func _drive(state: PhysicsDirectBodyState3D, steer: Vector2) -> void:
	drive_direction = (steering_basis * Vector3(steer.x, 0.0, steer.y)).normalized()
	var axis := Vector3.UP.cross(drive_direction)
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
func _set_resistance(driving: bool) -> void:
	if driving == _driving:
		return
	_driving = driving
	linear_damp = float(_cfg.linear_damp_active if driving else _cfg.linear_damp)
	angular_damp = float(_cfg.angular_damp_active if driving else _cfg.angular_damp)


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
