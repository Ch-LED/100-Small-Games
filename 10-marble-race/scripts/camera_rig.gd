class_name MarbleCameraRig
extends Node3D
## Third-person follow camera driven by the mouse (technical spec 6). Its pitch
## is clamped against a plane rather than against the world: the race
## controller hands it the road's normal while the ball is on the road, so a
## banked corner does not roll the horizon out from under the player.

var _cfg: Dictionary = {}
var _target: Node3D = null
var _yaw := 0.0
var _pitch := 0.0
var _up := Vector3.UP
var _wanted_up := Vector3.UP


func configure(settings: Dictionary, target: Node3D) -> void:
	_cfg = settings.camera
	_target = target
	_pitch = deg_to_rad(float(_cfg.pitch_max) * 0.35)


## The plane the camera works in: the road's normal while the ball is on the
## road, world up otherwise. Refreshed by the race controller every frame.
func aim_up(up: Vector3) -> void:
	_wanted_up = up


## Steering resolves in a yaw-only basis so that where the camera happens to be
## pitched never changes which way the ball goes (spec 6).
func get_steering_basis() -> Basis:
	return Basis(_up, _yaw)


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion == null or _cfg.is_empty():
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var sensitivity: float = _cfg.mouse_sensitivity
	_yaw -= motion.relative.x * sensitivity
	_pitch += motion.relative.y * sensitivity
	_pitch = clampf(_pitch,
			deg_to_rad(float(_cfg.pitch_min)),
			deg_to_rad(float(_cfg.pitch_max)))


func _physics_process(delta: float) -> void:
	if _target == null or _cfg.is_empty():
		return
	_up = _up.slerp(_wanted_up, 1.0 - exp(-float(_cfg.align_damp) * delta)).normalized()
	var distance: float = _cfg.distance
	# Pitch rotates the offset about the yawed lateral axis, so the clamp is
	# measured from the plane rather than from the horizon.
	var pitched := Basis(Vector3.RIGHT, -_pitch) * Vector3(0.0, 0.0, distance)
	var focus := _target.global_position + _up * float(_cfg.look_height)
	var desired := focus + _up * float(_cfg.height) + Basis(_up, _yaw) * pitched
	global_position = global_position.lerp(desired, 1.0 - exp(-float(_cfg.follow_damp) * delta))
	if global_position.distance_squared_to(focus) > 0.0001:
		look_at(focus, _up)
