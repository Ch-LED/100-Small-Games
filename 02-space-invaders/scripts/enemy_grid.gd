class_name EnemyGrid
extends Node2D
## The 5x11 formation. Owns the tick clock that marches the block, steps it
## down at the screen edges, animates every invader in lockstep, and picks
## the front-most invader to fire.

signal enemy_killed(score: int, at: Vector2)
signal fire_requested(at: Vector2, bullet_tag: String)
## One tick elapsed; carries a running counter for the background tone cycle.
signal ticked(count: int)
## Emitted after the formation steps one row down, so shields in the way can
## be crushed.
signal stepped_down

const ENEMY_SCENE := preload("res://02-space-invaders/scenes/enemy.tscn")

const ROW_KINDS: Array[String] = [
	InvaderEnemy.KIND_SQUID,
	InvaderEnemy.KIND_CLAUDE,
	InvaderEnemy.KIND_CLAUDE,
	InvaderEnemy.KIND_JELLY,
	InvaderEnemy.KIND_JELLY,
]

var _cfg := {}
var _sprites: SpaceSprites
var _factor := 4.0
var _score_table := {}
var _enemies: Array[InvaderEnemy] = []
var _dir := 1.0
var _tick := 0.0
var _tick_count := 0
var _anim_frame := 0
var _level := 1
var _initial_count := 1
var _cell := Vector2.ZERO
var _elapsed := 0.0
## Progress the level opens at, before time/attrition are added on top.
var _open_progress := 0.0


func setup(cfg: Dictionary, sprites: SpaceSprites, factor: float, score_table: Dictionary) -> void:
	_cfg = cfg
	_sprites = sprites
	_factor = factor
	_score_table = score_table
	_cell = sprites.cell_size(factor)


func spawn(level: int) -> void:
	_level = level
	_dir = 1.0
	_tick = 0.0
	_tick_count = 0
	_anim_frame = 0
	_elapsed = 0.0
	_clear()

	var grid: Dictionary = _cfg.enemy_grid
	var cols: int = grid.cols
	var step_x: float = _cell.x + grid.col_gap
	var step_y: float = _cell.y + grid.row_gap
	var top: float = _spawn_top(level, step_y)
	_open_progress = _level_open_progress(top, grid)
	var formation_w: float = float(cols - 1) * step_x + _cell.x
	var origin_x: float = SpaceField.PLAY_RECT.position.x \
			+ (SpaceField.PLAY_RECT.size.x - formation_w) * 0.5 + _cell.x * 0.5

	for row in ROW_KINDS.size():
		var kind := ROW_KINDS[row]
		for col in cols:
			var enemy: InvaderEnemy = ENEMY_SCENE.instantiate()
			enemy.position = Vector2(origin_x + col * step_x, top + row * step_y + _cell.y * 0.5)
			enemy.killed.connect(_on_enemy_killed.bind(enemy))
			enemy.tree_exiting.connect(_on_enemy_exiting.bind(enemy))
			# Add before setup: setup() drives @onready children, which only
			# resolve once the instance is in the tree.
			add_child(enemy)
			enemy.setup(kind, int(_score_table.get(kind, 10)), _sprites, _factor)
			_enemies.append(enemy)

	_initial_count = maxi(1, _enemies.size())


func _physics_process(delta: float) -> void:
	if _enemies.is_empty():
		return
	_elapsed += delta
	_tick += delta
	if _tick < tick_period():
		return
	_tick = 0.0
	_step()


## Each cleared level drops the formation `level_shift_rows` lower, but never
## closer than `level_clear_rows` rows to the shield line.
func _spawn_top(level: int, step_y: float) -> float:
	var grid: Dictionary = _cfg.enemy_grid
	var tick: Dictionary = _cfg.tick
	var rows := ROW_KINDS.size()
	var shield_top: float = SpaceField.SIZE.y - float(_cfg.shield.bottom_margin)
	var lowest_allowed: float = shield_top - float(rows - 1) * step_y - _cell.y \
			- float(tick.level_clear_rows) * step_y
	var desired: float = float(grid.top_margin) \
			+ float(level - 1) * float(tick.level_shift_rows) * step_y
	return minf(desired, lowest_allowed)


## Descent spans from the level-1 spawn row down to the shield line. A level
## that starts lower therefore opens further along its speed curve; pushing the
## curve back by `level_open_delay` keeps that opening calmer than the raw
## position implies.
func _level_open_progress(top: float, grid: Dictionary) -> float:
	var shield_top: float = SpaceField.SIZE.y - float(_cfg.shield.bottom_margin)
	var span: float = maxf(1.0, shield_top - float(grid.top_margin))
	var descended: float = top - float(grid.top_margin)
	return clampf(descended / span - float(_cfg.tick.level_open_delay), 0.0, 1.0)


## Speed-up blends attrition with elapsed time. Attrition is deliberately the
## smaller share — see count_share in the cfg for the 30s bound it must respect.
func tick_period() -> float:
	var tick: Dictionary = _cfg.tick
	var slow: float = tick.base_slow
	var fast: float = tick.base_fast
	var count_share: float = tick.count_share
	var time_share: float = tick.time_share
	var threshold := float(tick.fast_at_rows) * float(_cfg.enemy_grid.cols)
	var span := maxf(1.0, float(_initial_count) - threshold)
	var dead := float(_initial_count - _enemies.size())
	var by_count := clampf(dead / span, 0.0, 1.0)
	var by_time := clampf(_elapsed / maxf(1.0, tick.time_to_max), 0.0, 1.0)
	var progress := clampf(_open_progress + count_share * by_count + time_share * by_time, 0.0, 1.0)
	var speedup := pow(tick.per_level_speedup, float(_level - 1))
	return lerpf(slow * speedup, fast * speedup, progress)


func alive_count() -> int:
	return _enemies.size()


## The living invader nearest to `from`, or null when the formation is empty.
## The `]` super cheat's shots aim with it.
func nearest_alive_to(from: Vector2) -> InvaderEnemy:
	var best: InvaderEnemy = null
	var best_distance := INF
	for enemy in _enemies:
		if not is_instance_valid(enemy):
			continue
		var distance := from.distance_squared_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


func lowest_y() -> float:
	var lowest := -INF
	for enemy in _enemies:
		lowest = maxf(lowest, enemy.position.y)
	return lowest


## One animation frame per tick, so the wobble speeds up with the formation.
func _advance_animation() -> void:
	_anim_frame += 1
	for enemy in _enemies:
		enemy.set_frame(_anim_frame)


func _step() -> void:
	_tick_count += 1
	_advance_animation()
	ticked.emit(_tick_count)

	var grid: Dictionary = _cfg.enemy_grid
	var step: float = grid.step_x
	var bounds := _horizontal_bounds()
	var half := _cell.x * 0.5

	var hitting_edge := bounds.y + step > SpaceField.PLAY_RECT.end.x - half \
			if _dir > 0.0 else bounds.x - step < SpaceField.PLAY_RECT.position.x + half
	if hitting_edge:
		_dir = -_dir
		var descend := row_step_y()
		for enemy in _enemies:
			enemy.position.y += descend
		stepped_down.emit()
	else:
		for enemy in _enemies:
			enemy.position.x += _dir * step

	if _tick_count % _fire_interval() == 0:
		_try_fire()


## One full row of the formation — used for the edge descend and for the
## "one row early" invasion check.
func row_step_y() -> float:
	var gap: float = _cfg.enemy_grid.row_gap
	return _cell.y + gap


func _fire_interval() -> int:
	return maxi(1, int(_cfg.enemy_fire.fire_interval))


func _try_fire() -> void:
	var fire: Dictionary = _cfg.enemy_fire
	if randf() < fire.fire_fail_chance:
		return
	var shooter := _front_most()
	if shooter == null:
		return
	var tag := InvaderBullet.KIND_ENERGY if randf() < fire.energy_ratio else InvaderBullet.KIND_DART
	fire_requested.emit(shooter.global_position, tag)


## Front-most invader per column, then one random column.
func _front_most() -> InvaderEnemy:
	var per_column := {}
	for enemy in _enemies:
		var key := int(round(enemy.position.x))
		var current = per_column.get(key)
		if current == null or enemy.position.y > current.position.y:
			per_column[key] = enemy
	if per_column.is_empty():
		return null
	var keys := per_column.keys()
	return per_column[keys[randi() % keys.size()]]


func enemy_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var half := _cell * 0.5
	for enemy in _enemies:
		rects.append(Rect2(enemy.global_position - half, _cell))
	return rects


func _horizontal_bounds() -> Vector2:
	var min_x := INF
	var max_x := -INF
	for enemy in _enemies:
		min_x = minf(min_x, enemy.position.x)
		max_x = maxf(max_x, enemy.position.x)
	return Vector2(min_x, max_x)


## Erase immediately (not on tree_exiting) so alive_count() is correct within
## the same frame the last invader dies — wave-clear depends on it.
func _on_enemy_killed(score: int, at: Vector2, enemy: InvaderEnemy) -> void:
	_enemies.erase(enemy)
	enemy_killed.emit(score, at)


func _on_enemy_exiting(enemy: InvaderEnemy) -> void:
	_enemies.erase(enemy)


## remove_child() fires tree_exiting synchronously, which erases from
## _enemies — so iterate a copy with the array already emptied, otherwise
## half the formation survives a restart.
func _clear() -> void:
	var old := _enemies.duplicate()
	_enemies.clear()
	for enemy in old:
		if is_instance_valid(enemy):
			remove_child(enemy)
			enemy.queue_free()
