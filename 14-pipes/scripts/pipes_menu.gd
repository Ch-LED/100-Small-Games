class_name PipesMenu
extends Control

## Four modes, each with how far it has got and what the mouse does in it.
##
## The way out goes back to the hub, never out of the application: quitting
## belongs to the hub's own title screen, and a game's job is to hand the
## player back (CONSTITUTION 一, DECISION_LOG 029).

signal mode_chosen(mode: int, level_index: int)
signal back_requested

@onready var _backdrop: ColorRect = $Backdrop
@onready var _title: Label = $Center/Column/Title
@onready var _link: Button = $Center/Column/Link
@onready var _link_info: Label = $Center/Column/LinkInfo
@onready var _turn: Button = $Center/Column/Turn
@onready var _turn_info: Label = $Center/Column/TurnInfo
@onready var _shift: Button = $Center/Column/Shift
@onready var _shift_info: Label = $Center/Column/ShiftInfo
@onready var _slide: Button = $Center/Column/Slide
@onready var _slide_info: Label = $Center/Column/SlideInfo
@onready var _back: Button = $Center/Column/Back
@onready var _hint: Label = $Center/Column/Hint

var _buttons: Array[Button] = []
var _infos: Array[Label] = []
var _next: Array[int] = []
var _settings: PipesSettings


func _ready() -> void:
	_buttons = [_link, _turn, _shift, _slide]
	_infos = [_link_info, _turn_info, _shift_info, _slide_info]
	for mode in _buttons.size():
		_buttons[mode].pressed.connect(_on_mode.bind(mode))
	_back.pressed.connect(_on_back)
	_link.grab_focus()


## `save.loaded` false means the file was there and could not be trusted -- said
## out loud rather than quietly starting over, which would read as "you never
## got anywhere" (spec 11).
func configure(settings: PipesSettings, save: PipesSave) -> void:
	_settings = settings
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
	_title.text = "PIPES"
	_next = []
	for mode in _buttons.size():
		_buttons[mode].text = PipesModes.name_of(mode)
		_next.append(save.next_level(mode) if save.loaded else 0)
		_infos[mode].text = "%s   %s" % [PipesModes.blurb_of(mode), _progress_text(mode, save)]
	_hint.text = "ESC for the hub"


func _progress_text(mode: int, save: PipesSave) -> String:
	if not save.loaded:
		return "PROGRESS UNREADABLE"
	if _next[mode] <= 0:
		return "NOT STARTED"
	return "LEVEL %d" % (_next[mode] + 1)


func _on_mode(mode: int) -> void:
	mode_chosen.emit(mode, _next[mode])


func _on_back() -> void:
	back_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()
