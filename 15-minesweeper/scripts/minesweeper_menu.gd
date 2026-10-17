class_name MinesweeperMenu
extends Control

## Difficulty, the fastest clear for each, and the way out.
##
## The way out goes back to the hub, never out of the application: quitting
## belongs to the hub's own title screen, and a game's job is to hand the
## player back (CONSTITUTION 一, DECISION_LOG 029).

signal level_chosen(level: int)
signal back_requested

@onready var _backdrop: ColorRect = $Backdrop
@onready var _title: Label = $Center/Column/Title
@onready var _buttons: Array[Button] = [
	$Center/Column/Beginner as Button,
	$Center/Column/Intermediate as Button,
	$Center/Column/Expert as Button,
]
@onready var _infos: Array[Label] = [
	$Center/Column/BeginnerInfo as Label,
	$Center/Column/IntermediateInfo as Label,
	$Center/Column/ExpertInfo as Label,
]
@onready var _back: Button = $Center/Column/Back
@onready var _hint: Label = $Center/Column/Hint


func _ready() -> void:
	for level in _buttons.size():
		_buttons[level].pressed.connect(_on_level.bind(level))
	_back.pressed.connect(_on_back)
	_buttons[0].grab_focus()


## `save.loaded` false means the file was there and could not be trusted -- said
## out loud rather than quietly showing a dash, which would read as "nobody has
## ever cleared this" (spec 11).
func configure(settings: MinesweeperSettings, save: MinesweeperSave) -> void:
	var font_size := settings.font_size
	_backdrop.color = settings.bg_color
	PixelFont.apply(_title, font_size * 3)
	PixelFont.apply(_hint, font_size)
	for info in _infos:
		PixelFont.apply(info, font_size)
	for button in _buttons:
		button.add_theme_font_override("font", PixelFont.get_font())
		button.add_theme_font_size_override("font_size", font_size)
	_back.add_theme_font_override("font", PixelFont.get_font())
	_back.add_theme_font_size_override("font_size", font_size)
	_title.text = "MINESWEEPER"
	for level in _buttons.size():
		_buttons[level].text = settings.level_name(level)
		if level >= settings.level_count():
			_buttons[level].visible = false
			_infos[level].visible = false
			continue
		var shape := "%dx%d  %d MINES" % [settings.cols_for(level),
				settings.rows_for(level), settings.mines_for(level)]
		if not save.loaded:
			_infos[level].text = "%s   BEST --  (SAVE UNREADABLE)" % shape
		else:
			_infos[level].text = "%s   BEST %s" % [shape,
					MinesweeperSave.format_time(save.best_for(level))]
	_hint.text = "ESC for the hub"


func _on_level(level: int) -> void:
	level_chosen.emit(level)


func _on_back() -> void:
	back_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()
