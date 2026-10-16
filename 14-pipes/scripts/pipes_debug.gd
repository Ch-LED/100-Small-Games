class_name PipesDebug
extends Control

## The `P` readout. Read-only in the strict sense: it reports, it never changes
## the board -- nothing it shows is drawn from the puzzle's answer unless the
## `[` key is already showing it (CONSTITUTION 一).
##
## It draws into the empty band beside the board, which is dead space
## otherwise, so switching it on never covers a cell.

## A bright magenta that appears nowhere in the palette, so a pixel count can
## prove the overlay is off (spec 8).
const INK := Color("FF3FA4")

var enabled := false:
	set(value):
		enabled = value
		queue_redraw()

var _settings: PipesSettings
var _font: FontFile
var _lines: PackedStringArray = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = PixelFont.get_font()


func setup(settings: PipesSettings) -> void:
	_settings = settings
	_font = PixelFont.get_font()
	queue_redraw()


func set_lines(lines: PackedStringArray) -> void:
	_lines = lines
	if enabled:
		queue_redraw()


func _draw() -> void:
	if not enabled or _settings == null:
		return
	var font_size := _settings.font_size
	var line_height := float(font_size) * 1.6
	var y := PipesSettings.FIELD.y * 0.22
	for line in _lines:
		draw_string(_font, Vector2(_settings.margin, y), line,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)
		y += line_height
