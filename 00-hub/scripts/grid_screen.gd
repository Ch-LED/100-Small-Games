extends Control
## Grid desktop: header + scrollable app grid built from GameDiscovery.
## Reports back-to-title to hub_root. Scroll is stored in GameRouter before
## entering a game and restored after returning.

signal request_back_to_title

const CELL_SCENE := preload("res://00-hub/scenes/app_cell.tscn")
const GAME_DISCOVERY := preload("res://00-hub/scripts/game_discovery.gd")

const CELL_W := 150.0
const CELL_GAP := 24.0
const CELL_V_GAP := 18

@onready var _back_button: Button = $Root/Header/BackButton
@onready var _refresh_button: Button = $Root/Header/RefreshButton
@onready var _count_number: Label = $Root/Header/CountNumber
@onready var _scroll: ScrollContainer = $Root/Scroll
@onready var _grid: GridContainer = $Root/Scroll/Grid


func _ready() -> void:
	_back_button.pressed.connect(func(): request_back_to_title.emit())
	_refresh_button.pressed.connect(_populate)
	_grid.add_theme_constant_override("h_separation", int(CELL_GAP))
	_grid.add_theme_constant_override("v_separation", CELL_V_GAP)
	_scroll.resized.connect(_recompute_columns)
	_populate()
	_recompute_columns()


func _populate() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()

	var entries := GAME_DISCOVERY.discover()
	_count_number.text = str(entries.size())

	for entry in entries:
		var cell = CELL_SCENE.instantiate()
		cell.setup(entry)
		cell.cell_activated.connect(_on_cell_activated)
		_grid.add_child(cell)

	_restore_scroll()


func _recompute_columns() -> void:
	if _scroll == null:
		return
	var avail := _scroll.size.x
	var columns := maxi(1, int(floor((avail + CELL_GAP) / (CELL_W + CELL_GAP))))
	_grid.columns = columns


func _restore_scroll() -> void:
	if GameRouter.grid_scroll <= 0:
		return
	await get_tree().process_frame
	_scroll.scroll_vertical = GameRouter.grid_scroll
	GameRouter.grid_scroll = 0


func _on_cell_activated(entry: Dictionary) -> void:
	GameRouter.grid_scroll = _scroll.scroll_vertical
	GameRouter.enter_game(entry.dir)
