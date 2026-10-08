class_name AsteroidsGame
extends Control
## Asteroids controller: state machine, input, entity spawning, the wave loop,
## the heartbeat, and the two overlay keys.

enum State { TITLE, PLAYING, DYING, RESPAWN, OVER }

const BULLET_SCENE := preload("res://05-asteroids/scenes/bullet.tscn")
const ROCK_SCENE := preload("res://05-asteroids/scenes/rock.tscn")
const SAUCER_SCENE := preload("res://05-asteroids/scenes/saucer.tscn")
const EXPLOSION_SCENE := preload("res://05-asteroids/scenes/explosion.tscn")

const SHIP_START_FACING := -PI * 0.5
const OVERLAY_FONT_SIZE := 24
const NOTICE_SECONDS := 1.2
## How many more breaks a rock costs before the wave is clear: a large one needs
## 1 + 2 + 4 = 7 (itself, its two mediums, their four smalls), a medium 1 + 2 = 3,
## a small 1. Strictly decreasing as rocks break, which a plain rock count is
## not: one large shatters into two mediums, so counting rocks goes UP.
const SHATTER_WEIGHT: Array[int] = [7, 3, 1]
## Rocks spawn on a ring this far from the ship, so no wave starts on top of it.
const WAVE_RING_MIN := 250.0
const WAVE_RING_MAX := 620.0
## Freshly split rocks come off a little faster than a spawned one.
const SPLIT_SPEED_BONUS := 1.15

@onready var _background: ColorRect = $Background
@onready var _stars: Node2D = $Stars
@onready var _playfield: Node2D = $Playfield
@onready var _rocks: Node2D = $Playfield/Rocks
@onready var _bullets: Node2D = $Playfield/Bullets
@onready var _ship: AsteroidsShip = $Playfield/Ship
@onready var _saucer_slot: Node2D = $Playfield/SaucerSlot
@onready var _debug: AsteroidsDebug = $DebugDraw
@onready var _hud: AsteroidsHud = $Hud
@onready var _overlay_label: Label = $Overlay/Message
@onready var _audio: AsteroidsAudio = $Audio

var _cfg := {}

var _state: int = State.TITLE
var _score := 0
var _high := 0
var _lives := 3
var _level := 1
var _next_extra := 10000

var _saucer: AsteroidsSaucer = null
var _saucer_timer := 0.0

var _state_timer := 0.0
var _notice_timer := 0.0
var _beat_timer := 0.0
var _beat_flip := false

## Split depth left in the wave: a large rock is worth 3, a medium 2, a small 1.
## It drives both the heartbeat tempo and the wave-clear test.
var _wave_weight := 0.0
var _wave_weight_start := 1.0
var _wave_pending := false

var _cheat_invincible := false
var _debug_on := false


func _ready() -> void:
	_cfg = AsteroidsSettings.load_all()
	_lives = int(_cfg.ship.lives)
	_background.color = _cfg.field.bg_color
	_build_stars()

	_ship.setup(_cfg.ship, _cfg.field)
	_ship.area_entered.connect(_on_ship_touched)
	_hud.build(_cfg)

	PixelFont.apply(_overlay_label, OVERLAY_FONT_SIZE)
	_overlay_label.add_theme_color_override("font_color", _cfg.field.ship_color)
	_enter_title()


# --- build ------------------------------------------------------------------

## Decorative starfield: static dots, they never scroll and never interact.
func _build_stars() -> void:
	for i in int(_cfg.field.star_count):
		var radius := randf_range(float(_cfg.field.star_min), float(_cfg.field.star_max))
		var star := Polygon2D.new()
		star.color = _cfg.field.star_color
		star.polygon = PackedVector2Array([
			Vector2(0.0, -radius), Vector2(radius, 0.0),
			Vector2(0.0, radius), Vector2(-radius, 0.0),
		])
		star.position = AsteroidsField.random_point(10.0)
		_stars.add_child(star)


# --- states -----------------------------------------------------------------

func _enter_title() -> void:
	_state = State.TITLE
	_clear_entities()
	_ship.set_invincible(false)
	_ship.respawn(_centre(), SHIP_START_FACING)
	_ship.set_controls(0.0, false)
	_hud.set_score(0, _high)
	_hud.set_wave(1)
	_hud.set_lives(_lives)
	_audio.stop_all_loops()
	_overlay_label.text = _title_text()


func _title_text() -> String:
	return "ASTEROIDS\n\nPRESS SPACE TO START\n\nLARGE %d   MEDIUM %d   SMALL %d   SAUCER %d" % [
		int(_cfg.rock.score[AsteroidsSettings.LARGE]),
		int(_cfg.rock.score[AsteroidsSettings.MEDIUM]),
		int(_cfg.rock.score[AsteroidsSettings.SMALL]),
		int(_cfg.saucer.score),
	]


func _start_game() -> void:
	_score = 0
	_lives = int(_cfg.ship.lives)
	_level = 1
	_next_extra = int(_cfg.score.extra_life)
	_cheat_invincible = false
	_wave_pending = false
	_notice_timer = 0.0
	_beat_timer = 0.0

	_clear_entities()
	_ship.set_invincible(false)
	_ship.respawn(_centre(), SHIP_START_FACING)
	_hud.set_score(_score, _high)
	_hud.set_lives(_lives)
	_hud.set_wave(_level)
	_overlay_label.text = ""

	_spawn_wave()
	_saucer_timer = float(_cfg.saucer.first_delay)
	_state = State.PLAYING


func _end_game() -> void:
	_state = State.OVER
	_audio.stop_all_loops()
	_overlay_label.text = "GAME OVER\n\nSCORE %d\n\nPRESS SPACE" % _score


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		GameRouter.back_to_hub()
		return
	if Input.is_action_just_pressed("debug_toggle"):
		_debug_on = not _debug_on
		_debug.enabled = _debug_on
	if Input.is_action_just_pressed("cheat_toggle"):
		_toggle_cheat()

	match _state:
		State.TITLE:
			if Input.is_action_just_pressed("fire"):
				_start_game()
		State.PLAYING:
			_update_playing(delta)
		State.DYING:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_after_death()
		State.RESPAWN:
			if _respawn_clear():
				_do_respawn()
		State.OVER:
			if Input.is_action_just_pressed("fire"):
				_start_game()

	_refresh_debug()


func _update_playing(delta: float) -> void:
	_read_ship_input()
	_tick_saucer(delta)
	_tick_beat(delta)
	_tick_notice(delta)


# --- input ------------------------------------------------------------------

func _read_ship_input() -> void:
	var steer := 0.0
	if Input.is_action_pressed("wasd_left") or Input.is_action_pressed("arrow_left"):
		steer -= 1.0
	if Input.is_action_pressed("wasd_right") or Input.is_action_pressed("arrow_right"):
		steer += 1.0
	var thrusting := Input.is_action_pressed("wasd_up") or Input.is_action_pressed("arrow_up")
	_ship.set_controls(steer, thrusting)
	_audio.set_thrust(thrusting)

	if Input.is_action_pressed("fire") \
			and _bullets.get_child_count() < int(_cfg.ship.max_bullets) \
			and _ship.try_fire():
		_fire_ship_bullet()


func _toggle_cheat() -> void:
	_cheat_invincible = not _cheat_invincible
	_ship.set_invincible(_cheat_invincible)
	_show_notice("INVINCIBLE ON" if _cheat_invincible else "INVINCIBLE OFF")


# --- waves ------------------------------------------------------------------

func _spawn_wave() -> void:
	var count: int = mini(
			int(_cfg.wave.start_count) + (_level - 1) * int(_cfg.wave.count_step),
			int(_cfg.wave.count_cap))
	var scale := _level_speed_scale()
	for i in count:
		var angle := TAU * float(i) / float(count) + randf_range(-0.28, 0.28)
		var distance := randf_range(WAVE_RING_MIN, WAVE_RING_MAX)
		var at := AsteroidsField.wrap_point(_centre() + Vector2.RIGHT.rotated(angle) * distance)
		_spawn_rock(AsteroidsSettings.LARGE, at, _random_rock_velocity(AsteroidsSettings.LARGE, scale))

	_wave_weight_start = float(count * SHATTER_WEIGHT[AsteroidsSettings.LARGE])
	_wave_weight = _wave_weight_start


func _spawn_rock(kind: int, at: Vector2, velocity: Vector2) -> AsteroidsRock:
	var rock: AsteroidsRock = ROCK_SCENE.instantiate()
	rock.shattered.connect(_on_rock_shattered)
	# Add before setup: setup() drives @onready children, which only resolve for
	# a node that is already in the tree.
	_rocks.add_child(rock)
	var spin := randf_range(
			float(_cfg.rock.spin_min[kind]), float(_cfg.rock.spin_max[kind]))
	rock.setup(kind, at, velocity, spin, _cfg.rock, _cfg.field.rock_color)
	return rock


func _random_rock_velocity(kind: int, scale: float) -> Vector2:
	var speed := randf_range(
			float(_cfg.rock.speed_min[kind]), float(_cfg.rock.speed_max[kind])) * scale
	return Vector2.RIGHT.rotated(randf() * TAU) * speed


func _on_rock_shattered(kind: int, at: Vector2) -> void:
	# Runs inside a physics callback (a bullet or the ship touched the rock).
	# Defer so that spawning the replacement areas cannot touch the physics
	# server while its queries are being flushed.
	_split_rock.call_deferred(kind, at)


func _split_rock(kind: int, at: Vector2) -> void:
	_add_score(int(_cfg.rock.score[kind]))
	_audio.play_bang(kind)
	_spawn_explosion(at, float(_cfg.fx.size_scale[kind]))

	if kind < AsteroidsSettings.SMALL:
		var child := kind + 1
		var scale := _level_speed_scale() * SPLIT_SPEED_BONUS
		for i in 2:
			_spawn_rock(child, at, _random_rock_velocity(child, scale))

	_wave_weight = _live_weight()
	_check_wave_clear()


func _check_wave_clear() -> void:
	if _wave_pending or _wave_weight > 0.0:
		return
	_wave_pending = true
	_next_wave.call_deferred()


func _next_wave() -> void:
	_wave_pending = false
	_level += 1
	_hud.set_wave(_level)
	_clear_bullets()
	_remove_saucer()
	_spawn_wave()
	_saucer_timer = randf_range(
			float(_cfg.saucer.interval_min), float(_cfg.saucer.interval_max))
	_show_notice("WAVE %d" % _level)


## Breaks still owed on the field. Rocks already queued for deletion are left
## out, so a wave can still clear while their frees are pending.
func _live_weight() -> float:
	var total := 0.0
	for child in _rocks.get_children():
		var rock := child as AsteroidsRock
		if rock == null or rock.is_shattered() or rock.is_queued_for_deletion():
			continue
		total += float(SHATTER_WEIGHT[rock.kind])
	return total


func _level_speed_scale() -> float:
	var effective: int = maxi(0, mini(_level, int(_cfg.rock.level_speedup_cap)) - 1)
	return pow(float(_cfg.rock.level_speedup), float(effective))


# --- combat -----------------------------------------------------------------

func _fire_ship_bullet() -> void:
	var bullet: AsteroidsBullet = BULLET_SCENE.instantiate()
	_bullets.add_child(bullet)
	bullet.setup(_ship.nose(), _ship.forward(), float(_cfg.bullet.speed), true,
			float(_cfg.bullet.radius), float(_cfg.bullet.length),
			float(_cfg.bullet.lifetime), _cfg.field.bullet_color)
	_audio.play_fire()


func _on_ship_touched(area: Area2D) -> void:
	if _state != State.PLAYING or _ship.is_protected():
		return
	if area is AsteroidsRock:
		# False means a bullet already claimed this rock this frame: a ship that
		# shot it a moment ago should not still die to it.
		if not (area as AsteroidsRock).shatter():
			return
	elif area is AsteroidsSaucer:
		if not (area as AsteroidsSaucer).kill():
			return
	elif area is AsteroidsBullet:
		(area as AsteroidsBullet).queue_free()
	else:
		return
	_destroy_ship()


func _destroy_ship() -> void:
	_state = State.DYING
	_state_timer = float(_cfg.ship.death_pause)
	_notice_timer = 0.0
	_overlay_label.text = ""
	_audio.set_thrust(false)
	_audio.play_ship_death()
	_spawn_explosion(_ship.position, float(_cfg.fx.ship_scale), float(_cfg.fx.ship_duration))
	_ship.hide_wreck()
	_clear_bullets()


func _after_death() -> void:
	_lives -= 1
	_hud.set_lives(_lives)
	if _lives <= 0:
		_end_game()
		return
	_state = State.RESPAWN


## A respawn waits until nothing big is sitting on the centre.
func _respawn_clear() -> bool:
	var safe: float = float(_cfg.ship.safe_spawn_radius)
	for child in _rocks.get_children():
		var rock := child as AsteroidsRock
		if rock == null or rock.is_shattered() or rock.is_queued_for_deletion():
			continue
		if AsteroidsField.wrapped_distance(_centre(), rock.position) < safe + rock.radius:
			return false
	return true


func _do_respawn() -> void:
	_ship.respawn(_centre(), SHIP_START_FACING)
	_ship.make_invulnerable(float(_cfg.ship.invuln_time))
	_state = State.PLAYING


func _add_score(value: int) -> void:
	_score += value
	if _score > _high:
		_high = _score
	_hud.set_score(_score, _high)

	var step := int(_cfg.score.extra_life)
	if step > 0 and _score >= _next_extra:
		_next_extra += step
		_lives += 1
		_hud.set_lives(_lives)
		_audio.play_extra_life()


# --- saucer -----------------------------------------------------------------

func _tick_saucer(delta: float) -> void:
	if is_instance_valid(_saucer):
		return
	_saucer_timer -= delta
	if _saucer_timer > 0.0:
		return
	_spawn_saucer()


func _spawn_saucer() -> void:
	var from_left := randf() < 0.5
	_saucer = SAUCER_SCENE.instantiate()
	_saucer_slot.add_child(_saucer)
	_saucer.setup(from_left,
			randf_range(float(_cfg.saucer.y_min), float(_cfg.saucer.y_max)), _cfg.saucer,
			_cfg.field.saucer_color)
	_saucer.target_provider = _ship_point
	_saucer.destroyed.connect(_on_saucer_destroyed)
	_saucer.fired.connect(_on_saucer_fired)
	_saucer.tree_exited.connect(_on_saucer_exited)
	_saucer_timer = randf_range(
			float(_cfg.saucer.interval_min), float(_cfg.saucer.interval_max))
	_audio.set_saucer(true)


func _ship_point() -> Vector2:
	return _ship.position


func _on_saucer_fired(at: Vector2, direction: Vector2) -> void:
	var bullet: AsteroidsBullet = BULLET_SCENE.instantiate()
	_bullets.add_child(bullet)
	bullet.setup(at, direction, float(_cfg.saucer.bullet_speed), false,
			float(_cfg.bullet.radius), float(_cfg.bullet.length),
			float(_cfg.bullet.lifetime), _cfg.field.bullet_color)


func _on_saucer_destroyed(score: int, at: Vector2) -> void:
	_add_score(score)
	_audio.set_saucer(false)
	_spawn_explosion(at, float(_cfg.fx.size_scale[AsteroidsSettings.MEDIUM]))


func _on_saucer_exited() -> void:
	_saucer = null
	_audio.set_saucer(false)


func _remove_saucer() -> void:
	if is_instance_valid(_saucer):
		_saucer.queue_free()
	_saucer = null
	_audio.set_saucer(false)


# --- heartbeat --------------------------------------------------------------

## Two low tones, speeding up as the wave is broken apart.
func _tick_beat(delta: float) -> void:
	_beat_timer -= delta
	if _beat_timer > 0.0:
		return
	_beat_timer = _beat_interval()
	_beat_flip = not _beat_flip
	_audio.play_beat(_beat_flip)


func _beat_interval() -> float:
	var progress := 1.0 - clampf(_wave_weight / maxf(1.0, _wave_weight_start), 0.0, 1.0)
	return lerpf(float(_cfg.beat.slow), float(_cfg.beat.fast), progress)


# --- notices ----------------------------------------------------------------

func _show_notice(text: String) -> void:
	_overlay_label.text = text
	_notice_timer = NOTICE_SECONDS


func _tick_notice(delta: float) -> void:
	if _notice_timer <= 0.0:
		return
	_notice_timer -= delta
	if _notice_timer <= 0.0:
		_overlay_label.text = ""


# --- debug overlay ----------------------------------------------------------

## Read-only: the real collision radii, plus each rock's velocity. What is drawn
## is exactly what the physics sees.
func _refresh_debug() -> void:
	if not _debug_on:
		return
	var shapes: Array[Dictionary] = []
	for child in _rocks.get_children():
		var rock := child as AsteroidsRock
		if rock == null or rock.is_shattered() or rock.is_queued_for_deletion():
			continue
		shapes.append({
			"position": rock.position,
			"radius": rock.radius,
			"color": _cfg.field.rock_color,
			"velocity": rock.velocity(),
		})
	for child in _bullets.get_children():
		var bullet := child as AsteroidsBullet
		if bullet == null:
			continue
		shapes.append({
			"position": bullet.position,
			"radius": float(_cfg.bullet.radius),
			"color": _cfg.field.bullet_color,
			"velocity": bullet.velocity(),
		})
	if is_instance_valid(_saucer):
		shapes.append({
			"position": _saucer.position,
			"radius": float(_cfg.saucer.radius),
			"color": _cfg.field.saucer_color,
			"velocity": Vector2.ZERO,
		})
	if _ship.is_alive():
		shapes.append({
			"position": _ship.position,
			"radius": _ship.radius,
			"color": _cfg.field.ship_color,
			"velocity": _ship.velocity,
		})
	_debug.shapes = shapes


# --- helpers ----------------------------------------------------------------

func _centre() -> Vector2:
	return AsteroidsField.SIZE * 0.5


## `scale` sizes the burst for the thing that broke; `duration_multiplier` is
## only used to stretch the ship's blast out a little longer.
func _spawn_explosion(at: Vector2, scale: float, duration_multiplier := 1.0) -> void:
	var explosion: AsteroidsExplosion = EXPLOSION_SCENE.instantiate()
	_playfield.add_child(explosion)
	explosion.setup(at,
			int(round(float(_cfg.fx.shards) * scale)),
			float(_cfg.fx.length) * scale,
			_cfg.field.ship_color,
			float(_cfg.fx.duration) * scale * duration_multiplier,
			float(_cfg.fx.spread) * scale)


func _clear_bullets() -> void:
	for child in _bullets.get_children():
		child.queue_free()


func _clear_entities() -> void:
	for child in _rocks.get_children():
		child.queue_free()
	_clear_bullets()
	_remove_saucer()
	_wave_weight = 0.0
	_wave_weight_start = 1.0
