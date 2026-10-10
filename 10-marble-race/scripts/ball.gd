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

## A point on the road's surface directly "under" the ball, and how far the road
## reaches either side of it. Together with surface_normal this is the whole of
## the ball's ground: nothing in the physics world holds it up.
var road_point := Vector3.ZERO
var road_half_width := 0.0
var has_road := false

## True while the level is holding the ball on the start line. The drive is
## skipped rather than the body frozen: freeze stops _integrate_forces, and a
## body that does not run that callback cannot be driven at all.
var frozen := false

## Last commanded drive direction, world space, for diagnostics and probes.
var drive_direction := Vector3.ZERO

## The one colour every game in this project marks the super cheat with. A
## constant rather than a config value, so it cannot drift game to game.
const SUPER_COLOR := Color("00E676")

## The [cheat] section, handed over by the level. The cheat numbers do not
## live in this script's own config dictionary, and duplicating them would mean
## two places to change one value.
var cheat: Dictionary = {}
## [ -- the air wall along the road's edge.
var edge_field := false
## The camera's own axes, for ] flight to push along.
var look_basis := Basis()

var _super := false

## How hard the ball is being held back. All three are the same pair of damping
## values, just chosen differently; there is no separate brake force, because
## on a rolling ball the dampers ARE the brake.
enum Resistance { COAST, DRIVE, BRAKE, FLIGHT }

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
## Takeover is marked on the ball, because the ball is what is being taken
## over. The pattern stays: a solid green sphere would hide the spin, and the
## spin is still how the ball is being driven.
func set_super(on: bool) -> void:
	if on == _super:
		return
	_super = on
	_mesh.material_override = _patterned_material()
	# Weightless while flying. Without this the ball only glides: every push
	# forward is spending itself holding altitude.
	gravity_scale = 0.0 if on else float(_cfg.gravity_scale)


func _patterned_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = _checker_texture(6, Color("F2F5F7"),
			SUPER_COLOR if _super else Color("FF6D00"))
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
	var steer := _read_steer()
	if _super:
		_fly(state, steer)
		return
	if has_road:
		_ride_road(state)
	var braking := Input.is_action_pressed("fire")
	# The brake overrides the drive rather than fighting it: steering IS the
	# throttle here, so both cannot be asked for at once, and a brake that
	# loses to a held accelerator is not a brake.
	_apply_resistance(Resistance.BRAKE if braking
			else (Resistance.DRIVE if steer != Vector2.ZERO else Resistance.COAST))
	if braking:
		_brake(state)
	if braking or steer == Vector2.ZERO:
		drive_direction = Vector3.ZERO
	else:
		_drive(state, steer)
	_clamp_speed(state)


## ] -- flight. The arrow keys push the ball rather than spinning it, and the
## dampers go right up, so it drifts to a stop instead of accelerating away.
##
## Direction comes from the camera's own axes, pitch included, so aiming the
## camera up and pressing forward climbs. A yaw-only plane can only ever push
## the ball sideways, and flight that cannot climb is not flight.
##
## The road lets go entirely while this is on: this is the one cheat here that
## is allowed to simply remove the problem rather than help with it.
func _fly(state: PhysicsDirectBodyState3D, steer: Vector2) -> void:
	_apply_resistance(Resistance.FLIGHT)
	if Input.is_action_pressed("fire"):
		# Space in flight cancels the momentum outright. Braking the spin is
		# what a rolling ball does, and it cannot stop one quickly: friction is
		# what couples the two, and friction is capped. Flying there is nothing
		# to couple through, so the velocity is taken directly.
		state.linear_velocity *= exp(-float(cheat.flight_brake_bleed) * state.step)
		drive_direction = Vector3.ZERO
		return
	if steer == Vector2.ZERO:
		drive_direction = Vector3.ZERO
		return
	# steer.y is -1 for forward, and a camera looks down its own -Z, so forward
	# is +steer.y along the basis' z. Getting this sign wrong sends the ball
	# backwards, off the start of the track.
	var aimed := steer.x * look_basis.x + steer.y * look_basis.z
	if aimed.length_squared() < 0.000001:
		drive_direction = Vector3.ZERO
		return
	drive_direction = aimed.normalized()
	state.apply_central_force(drive_direction * float(cheat.flight_thrust))
	# Flight gets its own, much higher ceiling. The ground's cap is tuned to
	# what a rolling ball can hold on a corner; a flying one has no corner to
	# hold, and sharing the number would make flight the slow way to travel.
	var cap: float = cheat.flight_max_speed
	var velocity := state.linear_velocity
	if velocity.length() > cap:
		state.linear_velocity = velocity.normalized() * cap


## The road is a reference, not a floor. Nothing in the physics world holds the
## ball up — the constraint is worked out here, every step, from where the road
## says its surface is. That is the only way to ride a swept ribbon smoothly:
## any real collider under the ball has to travel with it, and a collider that
## travels under a body hands that body either its motion or its penetration.
## Both were tried against the road, and both read as the ball stumbling.
##
## Taking the ground over means taking friction over with it. Contact friction
## IS the contact, so with no collider the drive's torque would spin the ball
## on the spot. The rule is the one Jolt was applying anyway: slip at the
## contact point is opposed, and no harder than mu * m * g. That cap is the
## traction limit the whole feel was tuned against, so it is reproduced here
## rather than reinvented.
func _ride_road(state: PhysicsDirectBodyState3D) -> void:
	var offset := state.transform.origin - road_point
	var above := offset.dot(surface_normal)
	var in_plane := offset - surface_normal * above
	var lateral := in_plane.length()
	if above > _cfg.radius:
		return                       # clear of the road altogether
	if not edge_field and lateral > road_half_width:
		return                       # off the edge, and nothing there to stop it
	if edge_field and lateral > 0.0001:
		# [ -- the air wall. A push back toward the centreline that grows the
		# closer the ball gets to the edge. The support below also continues
		# past the edge while this is on, because a wall with a way around it
		# is not a wall.
		var depth: float = cheat.edge_field_depth
		var gap := road_half_width - lateral
		if gap < depth:
			var force: float = cheat.edge_field_strength * (1.0 - maxf(gap, 0.0) / depth)
			state.apply_central_force(-in_plane.normalized() * force)
	# Back onto the surface, one radius up.
	state.transform.origin = road_point + in_plane + surface_normal * float(_cfg.radius)
	# It may not travel into the road.
	var sinking := state.linear_velocity.dot(surface_normal)
	if sinking < 0.0:
		state.linear_velocity -= surface_normal * sinking
	_apply_contact_friction(state)


func _apply_contact_friction(state: PhysicsDirectBodyState3D) -> void:
	var radius: float = _cfg.radius
	var contact := state.transform.origin - surface_normal * radius
	var arm := contact - state.transform.origin
	var slip := state.linear_velocity + state.angular_velocity.cross(arm)
	var tangent := slip - surface_normal * slip.dot(surface_normal)
	var speed := tangent.length()
	if speed < 0.0001:
		return
	var inertia := 0.4 * mass * radius * radius
	var grip := 1.0 / (1.0 / mass + radius * radius / inertia)
	var limit: float = _cfg.friction * mass * state.total_gravity.length() * state.step
	var impulse := minf(speed * grip, limit)
	var push := -tangent / speed * impulse
	state.linear_velocity += push / mass
	state.angular_velocity += arm.cross(push) / inertia


## A constant retarding torque on top of the coasting dampers.
##
## Damping alone takes away a fixed FRACTION of the spin every second, so it
## bites hardest the instant you press and hardly at all by the end — the
## opposite of what a brake should feel like. A constant torque takes away a
## fixed AMOUNT, so the same effort becomes a larger share of what is left as
## the ball slows, and the last of the speed goes quickly.
func _brake(state: PhysicsDirectBodyState3D) -> void:
	var spin := state.angular_velocity
	var rate := spin.length()
	if rate < float(_cfg.brake_min_spin):
		return
	# Never more than it takes to stop it dead this step. Without the clamp a
	# brake strong enough to stop the ball quickly would turn the spin around
	# inside a single step and leave it rocking instead.
	var inertia := 0.4 * mass * float(_cfg.radius) * float(_cfg.radius)
	var stopping := rate * inertia / state.step
	var torque: float = minf(float(_cfg.brake_torque), stopping)
	state.apply_torque(-spin.normalized() * torque)


func _drive(state: PhysicsDirectBodyState3D, steer: Vector2) -> void:
	_apply_drive(state, (steering_basis * Vector3(steer.x, 0.0, steer.y)).normalized())


func _apply_drive(state: PhysicsDirectBodyState3D, aimed: Vector3) -> void:
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
			# The brake's own work is the torque; the dampers stay at their
			# coasting values so the two do not stack into a wall.
			linear_damp = float(_cfg.linear_damp)
			angular_damp = float(_cfg.angular_damp)
		Resistance.FLIGHT:
			linear_damp = float(cheat.flight_linear_damp)
			angular_damp = float(cheat.flight_angular_damp)
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
