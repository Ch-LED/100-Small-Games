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
@onready var _pause: MarblePauseMenu = $PauseMenu
@onready var _celebration: MarbleCelebration = $Celebration

## Set by the root before this node enters the tree. The route and its barriers
## come in with it rather than out of the scene, because one scene runs every
## track and the only thing that differs between them is the road.
var track_id := ""
var track_info: RaceTrackInfo = null
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
## False until the ball has crossed the start line. The clock does not run
## before that, so the run is timed from the line and not from the keypress.
var _clock_armed := false
## The see-through box drawn around the ball, showing the frame the camera and
## the steering share. Purely a view of a calculation; nothing collides with it.
var _frame_box: MeshInstance3D = null
var _cheat := false
var _super := false
var _clock := 0.0
var _waited := 0.0


func _ready() -> void:
	_cfg = RaceSettings.load_all()
	if _cfg.is_empty():
		return
	# Before configure(), which is what builds the road: the sweep has to be
	# handed the route it is sweeping.
	if track_info != null:
		_track.curve = track_info.curve
		_track.walls = track_info.walls
	_track.configure(_cfg)
	_camera_rig.configure(_cfg, _ball)
	_ball.configure(_cfg)
	_hud.configure(_cfg)
	_track.start_line.body_entered.connect(_on_start_line)
	_track.finish_line.body_entered.connect(_on_finish_line)
	_celebration.configure(_cfg)
	_celebration.place_at_finish(_track)
	_pause.configure(_cfg)
	_pause.resume_pressed.connect(_close_pause)
	_pause.restart_pressed.connect(_restart_from_pause)
	_pause.levels_pressed.connect(_leave_for_levels)
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
	_build_frame_box()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## A faint box around the ball showing the frame the camera — and the steering —
## work in. It exists because a sphere has no "forward": every orientation of a
## ball looks the same, so the direction the view follows cannot come from the
## ball and has to be worked out from the road (see camera_rig). That makes it an
## invisible thing deciding how the whole game looks, which is exactly the sort
## of thing worth drawing. The box lies on the road like a little car: its up is
## the road's normal, its forward is the way the ball is going, and it rolls
## right round with the surface on a corkscrew.
##
## No collision of any kind — it is a picture of a calculation, not a thing.
func _build_frame_box() -> void:
	# A slab rather than a cube: flatter than it is wide. From behind, a cube's
	# faces all look alike and it is hard to read which way it is pointing; a
	# slab lying on the road shows its attitude at a glance.
	var size: float = float(_cfg.ball.radius) * 2.0
	var box := BoxMesh.new()
	box.size = Vector3(size * 1.7, size * 0.8, size * 1.7)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.85, 1.0, 0.22)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_frame_box = MeshInstance3D.new()
	_frame_box.name = "BallFrame"
	_frame_box.mesh = box
	_frame_box.material_override = material
	_frame_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Off until asked for, on the P overlay. It is a reading, not scenery.
	_frame_box.visible = false
	add_child(_frame_box)


func _exit_tree() -> void:
	# The mouse is captured while a level is on screen and the menus are
	# mouse-driven, so letting go of it here is what stops the player being
	# stranded with an invisible cursor in the track list.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Leaving a level is always a way out of a pause: a tree left paused with
	# nothing on screen to unpause it is a hung game.
	get_tree().paused = false


func _physics_process(delta: float) -> void:
	# One lookup of the road, feeding everything that needs it: the ball's roll
	# axis, which way the road runs here, and the frame the camera and the
	# steering are both built in. The frame is handed over before either basis is
	# read, so the two cannot disagree within a frame.
	var road := _track.frame_near(_ball.global_position)
	var up: Vector3 = road.basis.y
	_ball.surface_normal = up
	_ball.road_point = road.origin
	_ball.has_road = true
	# Airborne is measured as CLEARANCE from the surface: how far the ball is off
	# the road, not how far it is from the centreline. Distance to the centreline
	# reads one ball radius while the ball is sitting on the road, so a threshold
	# on that number is a threshold on nothing — which is why the old value was
	# 8 m and why 8 m was never reached.
	var clearance := _ball.global_position.distance_to(road.origin) \
			- float(_cfg.ball.radius)
	_camera_rig.aim_frame(up if clearance < _align_distance else Vector3.UP,
			_track.forward_near(_ball.global_position))
	_ball.steering_basis = _camera_rig.get_steering_basis()
	_ball.look_basis = _camera_rig.get_look_basis()
	if _frame_box != null:
		_frame_box.global_transform = Transform3D(
				_camera_rig.get_frame(), _ball.global_position)
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
			if _clock_armed:
				_clock += delta
				_hud.set_time(_clock)
			# Flight is the one mode where going under the road is not the end
			# of the run: the ball is meant to be able to leave it.
			if _ball.global_position.y < _fall_y and not _super:
				_enter_fallen()

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


## Esc opens the pause menu while a run is on. Before the run starts there is
## nothing to pause, so it steps back out to the track list instead — the same
## place the pause menu's own third option goes.
func _open_pause() -> void:
	if _state != State.RUNNING or _pause.visible:
		back_pressed.emit()
		return
	_pause.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_pause() -> void:
	_pause.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _restart_from_pause() -> void:
	_close_pause()
	_enter_ready()


func _leave_for_levels() -> void:
	_close_pause()
	back_pressed.emit()


func _on_start_line(body: Node3D) -> void:
	if body != _ball or _state != State.RUNNING or _clock_armed:
		return
	_clock_armed = true
	_clock = 0.0
	_hud.set_time(0.0)


func _on_finish_line(body: Node3D) -> void:
	if body == _ball and _state == State.RUNNING:
		_enter_finished()


func _enter_ready() -> void:
	_state = State.READY
	# Cheats reset with the run, the way they do in every other game here.
	_cheat = false
	_super = false
	_apply_cheats()
	_ball.frozen = true
	_ball.coasting = false
	_clock = 0.0
	_waited = 0.0
	_hold_on_the_line()
	# Put the camera where it belongs rather than letting it ease in from
	# wherever the last run left it. Every restart is a fresh run and should
	# frame the ball the same way the first one did.
	_camera_rig.snap_to_target()
	_hud.set_time(0.0)
	_celebration.stop()
	_clock_armed = false
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
	_ball.coasting = false
	_waited = 0.0
	_base_message = "FELL  -  RESTARTING"
	_update_message()


func _enter_finished() -> void:
	_state = State.FINISHED
	# Cheats come off with the run. Flight is the one that matters here: it has
	# no road under it by design, and the ball is being handed back to the road
	# for the run-out, so leaving it on would leave the ball hanging in the air
	# for the whole victory lap.
	_cheat = false
	_super = false
	_apply_cheats()
	# Coasting rather than frozen: the ball keeps rolling to a stop on the
	# run-out with the road still holding it up, it just cannot be driven.
	_ball.frozen = false
	_ball.coasting = true
	_waited = 0.0
	_celebration.fire()
	_camera_rig.celebrate(float(_cfg.celebration.orbit_seconds))
	_base_message = "FINISHED  %s" % MarbleHud.format_time(_clock)
	_update_message()
	finished.emit(track_id, _clock)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		# Both are readings of the same kind: what the collision geometry looks
		# like, and what the camera's frame looks like. Neither changes play.
		_track.toggle_debug()
		if _frame_box != null:
			_frame_box.visible = not _frame_box.visible
	if event.is_action_pressed("cheat_toggle"):
		_cheat = not _cheat
		_apply_cheats()
	if event.is_action_pressed("super_cheat_toggle"):
		_super = not _super
		_apply_cheats()
	if event.is_action_pressed("ui_cancel"):
		_open_pause()
