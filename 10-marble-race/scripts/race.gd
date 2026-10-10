class_name MarbleRace
extends Node3D
## One level: the ball, the camera and the road, and the run around them.
## Phase 3 puts the menu and the save on top; the level loop itself is here.

enum State { READY, RUNNING, FALLEN, FINISHED }

@onready var _ball: MarbleBall = $Ball
@onready var _camera_rig: MarbleCameraRig = $CameraRig
@onready var _track: RaceTrackPath = $Track
@onready var _hud: MarbleHud = $Hud

var _cfg: Dictionary = {}
var _start_point := Vector3.ZERO
var _fall_y := -1000.0
var _align_distance := 8.0
var _glue_distance := 1.2
var _finish_t := 1.0
var _restart_delay := 1.1
var _finish_pause := 2.2
var _state := State.READY
var _clock := 0.0
var _waited := 0.0


func _ready() -> void:
	_cfg = RaceSettings.load_all()
	if _cfg.is_empty():
		return
	_track.configure(_cfg)
	_camera_rig.configure(_cfg, _ball)
	_ball.configure(_cfg)
	_hud.configure(_cfg)
	_start_point = _track.start_point() \
			+ Vector3(0.0, float(_cfg.ball.radius) + 0.6, 0.0)
	_fall_y = _track.lowest_point() - float(_cfg.play.fall_margin)
	_align_distance = float(_cfg.camera.align_distance)
	_glue_distance = float(_cfg.ball.ground_glue_distance)
	_finish_t = float(_cfg.track.finish_t)
	_restart_delay = float(_cfg.play.restart_delay)
	_finish_pause = float(_cfg.play.finish_pause)
	_enter_ready()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	# One lookup of the road, feeding the two things that need its plane: the
	# ball's roll axis, and the camera's pitch clamp.
	var road := _track.frame_near(_ball.global_position)
	var up: Vector3 = road.basis.y
	_ball.surface_normal = up
	_ball.steering_basis = _camera_rig.get_steering_basis()
	var to_road := _ball.global_position.distance_to(road.origin)
	_camera_rig.aim_up(up if to_road < _align_distance else Vector3.UP)
	_ball.grounded = bool(_cfg.ball.ground_glue) and to_road < _glue_distance
	_advance(delta)


func _advance(delta: float) -> void:
	match _state:
		State.READY:
			_hold_on_the_line()
			if _start_requested():
				_enter_running()
		State.RUNNING:
			_clock += delta
			_hud.set_time(_clock)
			if _ball.global_position.y < _fall_y:
				_enter_fallen()
			elif _track.progress_at(_ball.global_position) >= _finish_t:
				_enter_finished()
		State.FALLEN:
			_waited += delta
			if _waited >= _restart_delay:
				_enter_ready()
		State.FINISHED:
			_waited += delta
			if _waited >= _finish_pause:
				_enter_ready()


## Holding the ball still is done by pinning it rather than by freezing the
## body: freeze stops _integrate_forces, and a body that does not run that
## callback is a body the drive cannot reach — the same trap that made the ball
## unresponsive the first time it was ever played.
func _hold_on_the_line() -> void:
	_ball.linear_velocity = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO
	_ball.global_position = _start_point


## Space starts the run, and so does simply driving: the point of a racing game
## is that the accelerator works, and asking for a separate key to be told that
## is a formality the player has to learn.
func _start_requested() -> bool:
	if Input.is_action_just_pressed("fire"):
		return true
	for action in ["wasd_up", "wasd_down", "wasd_left", "wasd_right",
			"arrow_up", "arrow_down", "arrow_left", "arrow_right"]:
		if Input.is_action_just_pressed(action):
			return true
	return false


func _enter_ready() -> void:
	_state = State.READY
	_ball.frozen = true
	_clock = 0.0
	_waited = 0.0
	_hold_on_the_line()
	_hud.set_time(0.0)
	_hud.set_message("SPACE TO START")


func _enter_running() -> void:
	_state = State.RUNNING
	_ball.frozen = false
	_hud.set_message("")


func _enter_fallen() -> void:
	_state = State.FALLEN
	_ball.frozen = true
	_waited = 0.0
	_hud.set_message("FELL  -  RESTARTING")


func _enter_finished() -> void:
	_state = State.FINISHED
	_ball.frozen = true
	_waited = 0.0
	_hud.set_message("FINISHED  %s" % MarbleHud.format_time(_clock))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Sandbox-only: there is no menu to go back to yet. Phase 3 replaces
		# this with the pause menu (spec 11).
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
