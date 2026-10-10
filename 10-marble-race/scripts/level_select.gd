class_name MarbleLevelSelect
extends Control
## The track list: a row per track, its name on the left and the best time on
## the right. One row today, and it is still a list rather than a single button
## because the second track is a foregone conclusion.

signal track_chosen(track_id: String)
signal back_pressed

@onready var _title: Label = $Title
@onready var _rows: VBoxContainer = $Rows
@onready var _footer: Label = $Footer

var _font_size := 16


func configure(index: RaceTrackIndex, save: MarbleSave, settings: Dictionary) -> void:
	_font_size = int(settings.hud.font_size)
	PixelFont.apply(_title, _font_size * 3)
	PixelFont.apply(_footer, _font_size)
	if save.recovered:
		# Say so rather than presenting a blank scoreboard as if it were right.
		_footer.text = "存档无法读取，成绩已重置     ESC BACK"
	else:
		_footer.text = "ESC BACK"
	_build_rows(index, save)


## Rows are built in code because they follow the index, not the scene: the
## container is the structural part and lives in the .tscn, its contents do not.
func _build_rows(index: RaceTrackIndex, save: MarbleSave) -> void:
	for track in index.tracks:
		var row := Button.new()
		row.custom_minimum_size = Vector2(720.0, 56.0)
		row.text = "%s          %s" % [track.display_name, MarbleSave.format(save.best(track.id))]
		row.add_theme_font_override("font", PixelFont.get_font())
		row.add_theme_font_size_override("font_size", _font_size * 2)
		var track_id := track.id
		row.pressed.connect(func() -> void: track_chosen.emit(track_id))
		_rows.add_child(row)
	if _rows.get_child_count() > 0:
		_rows.get_child(0).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back_pressed.emit()
