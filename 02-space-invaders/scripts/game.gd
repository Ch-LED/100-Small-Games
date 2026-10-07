class_name SpaceInvadersGame
extends Control
## Space Invaders controller: state machine (title -> playing -> over),
## input aggregation, entity spawning and the wave/level loop.
## All layout uses the fixed logical SpaceField.SIZE (canvas_items stretch scales it).

enum State { TITLE, PLAYING, DYING, OVER }

const INVADER_LINE_MARGIN := 8.0

const BULLET_SCENE := preload("res://02-space-invaders/scenes/bullet.tscn")
const UFO_SCENE := preload("res://02-space-invaders/scenes/ufo.tscn")
## Background tile mix. space_4 is the flat fill and should dominate; the star
## tiles are accents. Weights are renormalised over whichever tags exist.
const BACKGROUND_WEIGHTS := {
	"space_4": 0.70,
	"space_3": 0.20,
	"space_1": 0.06,
	"space_2": 0.04,
}

@onready var _background: Control = $Background
@onready var _playfield: Node2D = $Playfield
@onready var _hud: InvaderHud = $Hud
@onready var _overlay: Control = $Overlay
@onready var _overlay_message: Label = %Message
@onready var _player: InvaderPlayer = %Player
@onready var _grid: EnemyGrid = %EnemyGrid
@onready var _shield_root: Node2D = %Shields
@onready var _bullet_root: Node2D = %Bullets
@onready var _ufo_slot: Node2D = %UfoSlot
@onready var _audio: SpaceAudio = %Audio

var _cfg := {}
var _sprites: SpaceSprites
var _factor := 4.0
var _state: int = State.TITLE
var _score := 0
var _lives := 3
var _level := 1

var _player_bullet: InvaderBullet = null
var _enemy_bullets: Array[InvaderBullet] = []
var _ufo: InvaderUfo = null
var _ufo_countdown := 0.0
var _shields: Array[InvaderShield] = []
var _wave_pending := false
var _fire_lock := 0.0
## Debug cheat (P): lifts the single-bullet rule so fire is unrestricted.
var _fire_cheat := false


func _ready() -> void:
	_cfg = SpaceSettings.load_all()
	_sprites = SpaceSprites.new()
	_factor = _cfg.scale.factor
	_build_background()
	_build_playfield()
	_build_side_masks()
	_build_hud()
	_build_overlay()
	await get_tree().process_frame
	_enter_title()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		GameRouter.back_to_hub()
		return
	if Input.is_action_just_pressed("debug_toggle"):
		_fire_cheat = not _fire_cheat
	match _state:
		State.TITLE:
			if Input.is_action_just_pressed("fire"):
				_start_game()
		State.OVER:
			if Input.is_action_just_pressed("fire"):
				_start_game()
		State.PLAYING:
			_update_playing(delta)
		State.DYING:
			pass


# --- build ------------------------------------------------------------------

## The background frame (base colour + tile holder) is scene structure; only the
## star tiles themselves are data, so they are filled in here.
func _build_background() -> void:
	var holder: Control = %Tiles
	var tile := _sprites.content_size("space_3", 0, _factor)
	var cols := int(ceil(SpaceField.SIZE.x / tile.x))
	var rows := int(ceil(SpaceField.SIZE.y / tile.y))
	for row in rows:
		for col in cols:
			var sprite := _sprites.make_sprite(_pick_background_tag(), 0, _factor)
			sprite.position = Vector2((float(col) + 0.5) * tile.x, (float(row) + 0.5) * tile.y)
			sprite.rotation = deg_to_rad(90.0 * float(randi() % 4))
			holder.add_child(sprite)


func _pick_background_tag() -> String:
	var total := 0.0
	for tag in BACKGROUND_WEIGHTS:
		if _sprites.has_tag(tag):
			total += BACKGROUND_WEIGHTS[tag]
	if total <= 0.0:
		return "space_3"
	var roll := randf() * total
	var acc := 0.0
	var last := "space_3"
	for tag in BACKGROUND_WEIGHTS:
		if not _sprites.has_tag(tag):
			continue
		last = tag
		acc += BACKGROUND_WEIGHTS[tag]
		if roll < acc:
			return tag
	return last


## Blacks out the outer fifth on each side. Added after the playfield so it
## covers the background but not the entities (which stay inside PLAY_RECT).
func _build_side_masks() -> void:
	var width := SpaceField.PLAY_RECT.position.x
	if width <= 0.0:
		return
	for i in 2:
		var mask := ColorRect.new()
		mask.color = Color.BLACK
		mask.size = Vector2(width, SpaceField.SIZE.y)
		mask.position = Vector2(0.0 if i == 0 else SpaceField.SIZE.x - width, 0.0)
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(mask)


## Player and grid are scene nodes now; this only parameterises and wires them.
func _build_playfield() -> void:
	_player.setup(_cfg.player.speed, _sprites, _factor)
	_player.position = Vector2(SpaceField.SIZE.x * 0.5, SpaceField.SIZE.y - _cfg.player.bottom_margin)
	_player.hit_taken.connect(_on_player_hit)

	_grid.setup(_cfg, _sprites, _factor, _cfg.score)
	_grid.enemy_killed.connect(_on_enemy_killed)
	_grid.fire_requested.connect(_on_enemy_fire)
	_grid.stepped_down.connect(_crush_shields)
	_grid.ticked.connect(_on_grid_ticked)

	_build_shields()


func _build_shields() -> void:
	var count: int = _cfg.shield.count
	var tile: float = _cfg.shield.tile_size * _factor
	var shield_w := float(InvaderShield.LAYOUT[0].length()) * tile
	var play := SpaceField.PLAY_RECT
	var gap := (play.size.x - float(count) * shield_w) / float(count + 1)
	var y: float = SpaceField.SIZE.y - _cfg.shield.bottom_margin
	for i in count:
		var shield := InvaderShield.new()
		shield.position = Vector2(play.position.x + gap * float(i + 1) + shield_w * float(i), y)
		# Add before building: the tiles it creates rely on @onready children,
		# which only resolve for nodes that are already in the tree.
		_shield_root.add_child(shield)
		shield.build(_cfg.shield.tile_size, _factor, _cfg.shield.tile_hp, _sprites)
		_shields.append(shield)


func _build_hud() -> void:
	_hud.build(_cfg, _sprites, _factor)


## Only the per-enemy score rows are dynamic; the frame around them is scene.
func _build_overlay() -> void:
	var title: Label = %Title
	PixelFont.apply(title, 40)
	title.text = "SPACE INVADERS"

	var rows: VBoxContainer = %Rows
	rows.add_child(_make_score_row("squid", _cfg.score.squid))
	rows.add_child(_make_score_row("claude", _cfg.score.claude))
	rows.add_child(_make_score_row("jelly", _cfg.score.jelly))

	PixelFont.apply(_overlay_message, 16)


func _make_score_row(tag: String, value: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)

	var icon := TextureRect.new()
	icon.texture = _sprites.make_atlas(tag, 0)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = _sprites.cell_size(_factor)
	row.add_child(icon)

	var label := Label.new()
	PixelFont.apply(label, 16)
	label.text = "= %d PTS" % value
	row.add_child(label)
	return row


# --- states -----------------------------------------------------------------

func _enter_title() -> void:
	_state = State.TITLE
	_playfield.process_mode = Node.PROCESS_MODE_DISABLED
	_overlay.visible = true
	_overlay_message.text = "PRESS SPACE TO START"
	_hud.set_score(0)
	_hud.set_lives(_cfg.player.lives)


func _start_game() -> void:
	_score = 0
	_lives = _cfg.player.lives
	_level = 1
	_state = State.PLAYING
	_playfield.process_mode = Node.PROCESS_MODE_INHERIT
	_overlay.visible = false
	_hud.set_score(_score)
	_hud.set_lives(_lives)
	_reset_transient_entities()
	_player.position = Vector2(SpaceField.SIZE.x * 0.5, SpaceField.SIZE.y - _cfg.player.bottom_margin)
	_player.set_direction(0.0)
	_wave_pending = false
	_fire_lock = _cfg.player.fire_lock
	_grid.spawn(_level)
	_ufo_countdown = randf_range(_cfg.ufo.interval_min, _cfg.ufo.interval_max)


func _end_game(reason: String) -> void:
	if _state == State.OVER:
		return
	_state = State.OVER
	# May be reached from a physics callback (bullet hit); defer the switch.
	_playfield.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	_audio.play_game_over()
	_overlay.visible = true
	_overlay_message.text = "%s\nPRESS SPACE TO RESTART" % reason


func _update_playing(delta: float) -> void:
	_player.set_direction(_read_move_axis())
	_fire_lock = maxf(0.0, _fire_lock - delta)
	# Held fire keeps trying; the single-bullet rule limits the actual rate.
	if _fire_lock <= 0.0 and Input.is_action_pressed("fire"):
		_try_player_fire()
	_tick_ufo(delta)
	_check_invasion()


# --- input ------------------------------------------------------------------

## Left/right intent is the fallthrough of the wasd and arrow actions.
func _read_move_axis() -> float:
	var dir := 0.0
	if Input.is_action_pressed("wasd_left") or Input.is_action_pressed("arrow_left"):
		dir -= 1.0
	if Input.is_action_pressed("wasd_right") or Input.is_action_pressed("arrow_right"):
		dir += 1.0
	return dir


func _try_player_fire() -> void:
	if not _fire_cheat and is_instance_valid(_player_bullet):
		return
	var bullet: InvaderBullet = BULLET_SCENE.instantiate()
	bullet.position = _player.position + Vector2(0.0, -_sprites.content_size("player", 0, _factor).y * 0.5)
	bullet.tree_exited.connect(_on_player_bullet_exited.bind(bullet))
	# Add before setup: setup() drives @onready children, which only resolve
	# once the instance is in the tree.
	_bullet_root.add_child(bullet)
	bullet.setup(InvaderBullet.KIND_LAZER, _cfg.player.bullet_speed, true, _sprites, _factor,
			_bullet_min_size())
	_player_bullet = bullet
	_audio.play_shoot()


# --- combat -----------------------------------------------------------------

func _on_player_bullet_exited(bullet: InvaderBullet) -> void:
	if _player_bullet == bullet:
		_player_bullet = null


func _on_enemy_fire(at: Vector2, bullet_tag: String) -> void:
	var fire: Dictionary = _cfg.enemy_fire
	var speed: float = fire.energy_bullet_speed if bullet_tag == InvaderBullet.KIND_ENERGY else fire.dart_bullet_speed
	var bullet: InvaderBullet = BULLET_SCENE.instantiate()
	bullet.position = at
	bullet.tree_exited.connect(_on_enemy_bullet_exited.bind(bullet))
	_bullet_root.add_child(bullet)
	bullet.setup(bullet_tag, speed, false, _sprites, _factor, _bullet_min_size())
	_enemy_bullets.append(bullet)


func _on_enemy_bullet_exited(bullet: InvaderBullet) -> void:
	_enemy_bullets.erase(bullet)


func _on_grid_ticked(count: int) -> void:
	_audio.play_tick(count)


func _on_enemy_killed(score: int, at: Vector2) -> void:
	_add_score(score)
	_spawn_explosion(at)
	_audio.play_enemy_hit()
	# Reached from a bullet's physics callback: rebuilding the formation here
	# would touch the physics server while queries are being flushed. Also
	# guard against several bullets clearing the last row in the same frame.
	if _grid.alive_count() == 0 and not _wave_pending:
		_wave_pending = true
		_advance_wave.call_deferred()


func _on_ufo_destroyed(score: int, at: Vector2) -> void:
	_ufo = null
	_add_score(score)
	_spawn_score_popup(at, score)
	_audio.play_ufo_killed()


func _on_player_hit() -> void:
	_lives -= 1
	_hud.set_lives(_lives)
	_audio.play_player_hit()
	if _lives <= 0:
		_begin_death()
		return
	_clear_enemy_bullets()
	_player.set_invulnerable(_cfg.player.invuln_time)


## Last life lost: swap the ship for the explosion, freeze the field, hold for
## a beat, then show the result screen.
func _begin_death() -> void:
	_state = State.DYING
	_player.explode()
	_clear_enemy_bullets()
	_playfield.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	var pause: float = _cfg.player.death_pause
	await get_tree().create_timer(pause).timeout
	_end_game("GAME OVER")


func _add_score(value: int) -> void:
	_score += value
	_hud.set_score(_score)


func _spawn_explosion(at: Vector2) -> void:
	var sprite := _sprites.make_sprite("explode", 0, _factor)
	sprite.position = at
	_playfield.add_child(sprite)
	var tween := create_tween()
	tween.tween_interval(0.25)
	tween.tween_callback(sprite.queue_free)


## Floating score readout (used when a UFO is shot down).
func _spawn_score_popup(at: Vector2, score: int) -> void:
	var label := Label.new()
	PixelFont.apply(label, 16)
	label.text = str(score)
	label.size = Vector2(96.0, 24.0)
	label.position = at - Vector2(48.0, 12.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playfield.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 40.0, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(label.queue_free)


# --- wave / level -----------------------------------------------------------

func _advance_wave() -> void:
	_wave_pending = false
	_lives += 1
	_hud.set_lives(_lives)
	_level += 1
	_clear_enemy_bullets()
	_grid.spawn(_level)
	_player.set_direction(0.0)
	_fire_lock = _cfg.player.fire_lock


## The formation stepping down consumes any shield tile it lands on.
func _crush_shields() -> void:
	var invaders := _grid.enemy_rects()
	if invaders.is_empty():
		return
	for shield in _shields:
		for tile in shield.tiles():
			var rect := tile.global_rect()
			for invader in invaders:
				if rect.intersects(invader):
					tile.queue_free()
					break


func _check_invasion() -> void:
	if _grid.alive_count() == 0:
		return
	# Trigger one full row early, so the loss registers before the sprites
	# actually overlap the ship.
	var line := _player.position.y - _sprites.content_size("player", 0, _factor).y * 0.5 \
			+ INVADER_LINE_MARGIN - _grid.row_step_y()
	if _grid.lowest_y() >= line:
		_end_game("INVADED")


# --- ufo --------------------------------------------------------------------

func _tick_ufo(delta: float) -> void:
	if is_instance_valid(_ufo):
		return
	_ufo_countdown -= delta
	if _ufo_countdown > 0.0:
		return
	_ufo_countdown = randf_range(_cfg.ufo.interval_min, _cfg.ufo.interval_max)
	_spawn_ufo()


func _spawn_ufo() -> void:
	var from_left := randf() < 0.5
	var ufo: InvaderUfo = UFO_SCENE.instantiate()
	var play := SpaceField.PLAY_RECT
	ufo.position = Vector2(
			play.position.x - 32.0 if from_left else play.end.x + 32.0, _cfg.ufo.y)
	ufo.escaped.connect(_clear_ufo)
	ufo.destroyed.connect(_on_ufo_destroyed)
	_ufo_slot.add_child(ufo)
	ufo.setup(_cfg.ufo.speed, _roll_ufo_score(), from_left, _sprites, _factor)
	_ufo = ufo
	_audio.play_ufo_enter()


func _bullet_min_size() -> Vector2:
	var width: float = _cfg.bullet.min_width
	var height: float = _cfg.bullet.min_height
	return Vector2(width, height)


func _clear_ufo() -> void:
	_ufo = null


## UFO score is always a multiple of score_step (default 50).
func _roll_ufo_score() -> int:
	var step: int = maxi(1, _cfg.ufo.score_step)
	var low := int(ceil(float(_cfg.ufo.score_min) / float(step)))
	var high := int(floor(float(_cfg.ufo.score_max) / float(step)))
	return randi_range(low, maxi(low, high)) * step


# --- cleanup ----------------------------------------------------------------

func _clear_enemy_bullets() -> void:
	for bullet in _enemy_bullets:
		if is_instance_valid(bullet):
			bullet.queue_free()
	_enemy_bullets.clear()


func _reset_transient_entities() -> void:
	_player_bullet = null
	_enemy_bullets.clear()
	for child in _bullet_root.get_children():
		child.queue_free()
	if is_instance_valid(_ufo):
		_ufo.queue_free()
	_ufo = null
