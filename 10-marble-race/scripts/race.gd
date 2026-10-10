class_name MarbleRace
extends Node3D
## One level: the ball, the camera and the road, and the run around them.
## Phase 3 puts the menu and the save on top; the level loop itself is here.

## A run reached the finish, with the time it took. The root owns the save,
## so the level reports rather than writes.
signal finished(track_id: String, seconds: float)
## Esc. Phase 3's next step turns this into the pause menu; until then it steps
## back out to the track list, the same place the pause menu would offer.
signal back_pressed

enum State { READY, RUNNING, FALLEN, FINISHED }

@onready var _ball: MarbleBall = $Ball
@onready var _camera_rig: MarbleCameraRig = $CameraRig
@onready var _track: RaceTrackPath = $Track
@onready var _hud: MarbleHud = $Hud

## Set by the root before this node enters the tree.
var track_id := ""
var best_time := 0.0

var _cfg: Dictionary = {}
var _start_point := Vector3.ZERO
var _fall_y := -1000.0
var _align_distance := 8.0
var _finish_t := 1.0
var _restart_delay := 1.1
var _finish_pause := 2.2
var _state := State.READY
var _base_message := ""
var _cheat := false
var _super := false
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
	_ball.road_half_width = float(_cfg.track.half_width)
	_ball.cheat = _cfg.cheat
	_finish_t = float(_cfg.track.finish_t)
	_restart_delay = float(_cfg.play.restart_delay)
	_finish_pause = float(_cfg.play.finish_pause)
	_enter_ready()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	# The mouse is captured while a level is on screen and the menus are
	# mouse-driven, so letting go of it here is what stops the player being
	# stranded with an invisible cursor in the track list.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	# One lookup of the road, feeding the two things that need its plane: the
	# ball's roll axis, and the camera's pitch clamp.
	var road := _track.frame_near(_ball.global_position)
	var up: Vector3 = road.basis.y
	_ball.surface_normal = up
	_ball.road_point = road.origin
	_ball.has_road = true
	_ball.steering_basis = _camera_rig.get_steering_basis()
	_ball.look_basis = _camera_rig.get_look_basis()
	var to_road := _ball.global_position.distance_to(road.origin)
	_camera_rig.aim_up(up if to_road < _align_distance else Vector3.UP)
	_advance(delta)


## One line carrying whatever the player needs: what the level is doing, and
## which cheats are on. Composed in one place so a state change and a cheat
## toggle cannot end up disagreeing about what is on screen.
func _update_message() -> void:
	var marks := PackedStringArray()
	if _cheat:
		marks.append("AIR WALL")
	if _super:
		marks.append("FLYING")
	var suffix := ("   " + "  ".join(marks)) if marks.size() > 0 else ""
	_hud.set_message(_base_message + suffix)


func _apply_cheats() -> void:
	# [ turns on the air wall the analytic ground adds at the road's edge.
	_ball.edge_field = _cheat
	_ball.set_super(_super)
	# Flight needs the camera unlocked: its pitch limit is what stops the view
	# pointing up, and without it there is no way to aim a climb.
	_camera_rig.set_free_look(_super)
	_update_message()


func _advance(delta: float) -> void:
	match _state:
		State.READY:
			_hold_on_the_line()
			if _start_requested():
				_enter_running()
		State.RUNNING:
			_clock += delta
			_hud.set_time(_clock)
			# Flight is the one mode where going under the road is not the end
			# of the run: the ball is meant to be able to leave it.
			if _ball.global_position.y < _fall_y and not _super:
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
	# Cheats reset with the run, the way they do in every other game here.
	_cheat = false
	_super = false
	_apply_cheats()
	_ball.frozen = true
	_clock = 0.0
	_waited = 0.0
	_hold_on_the_line()
	_hud.set_time(0.0)
	_base_message = "SPACE TO START   BEST %s" % MarbleSave.format(best_time)
	_update_message()


func _enter_running() -> void:
	_state = State.RUNNING
	_ball.frozen = false
	_base_message = ""
	_update_message()


func _enter_fallen() -> void:
	_state = State.FALLEN
	_ball.frozen = true
	_waited = 0.0
	_base_message = "FELL  -  RESTARTING"
	_update_message()


func _enter_finished() -> void:
	_state = State.FINISHED
	_ball.frozen = true
	_waited = 0.0
	_base_message = "FINISHED  %s" % MarbleHud.format_time(_clock)
	_update_message()
	finished.emit(track_id, _clock)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		_track.toggle_debug()
	if event.is_action_pressed("cheat_toggle"):
		_cheat = not _cheat
		_apply_cheats()
	if event.is_action_pressed("super_cheat_toggle"):
		_super = not _super
		_apply_cheats()
	if event.is_action_pressed("ui_cancel"):
		back_pressed.emit()
