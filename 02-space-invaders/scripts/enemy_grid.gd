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
	var top: float = grid.top_margin + float(level - 1) * _cfg.tick.level_step_y
	var formation_w: float = float(cols - 1) * step_x + _cell.x
	var origin_x: float = SpaceField.PLAY_RECT.position.x \
			+ (SpaceField.PLAY_RECT.size.x - formation_w) * 0.5 + _cell.x * 0.5

	for row in ROW_KINDS.size():
		var kind := ROW_KINDS[row]
		for col in cols:
			var enemy := InvaderEnemy.new()
			enemy.setup(kind, int(_score_table.get(kind, 10)), _sprites, _factor)
			enemy.position = Vector2(origin_x + col * step_x, top + row * step_y + _cell.y * 0.5)
			enemy.killed.connect(_on_enemy_killed.bind(enemy))
			enemy.tree_exiting.connect(_on_enemy_exiting.bind(enemy))
			add_child(enemy)
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
	var progress := count_share * by_count + time_share * by_time
	var speedup := pow(tick.per_level_speedup, float(_level - 1))
	return lerpf(slow * speedup, fast * speedup, progress)


func alive_count() -> int:
	return _enemies.size()


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
