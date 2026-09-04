extends Button
## One desktop app tile: rounded icon area + display name. Built from a
## GameEntry dict. Children ignore mouse so the whole tile is clickable.

signal cell_activated(entry: Dictionary)

const ICON_HEIGHT := 136.0
const NAME_HEIGHT := 28.0


func setup(entry: Dictionary) -> void:
	_build_icon(entry)
	_build_label(entry.display_name)
	pressed.connect(func(): cell_activated.emit(entry))


func _build_icon(entry: Dictionary) -> void:
	var icon_slot := _make_icon_slot(entry)
	icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon_slot)


func _make_icon_slot(entry: Dictionary) -> Control:
	var slot: Control = null
	if ResourceLoader.exists(entry.icon_path):
		var texture = load(entry.icon_path)
		if texture is Texture2D:
			slot = _texture_icon(texture)
	if slot == null:
		slot = _placeholder(entry)
	slot.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	slot.offset_bottom = ICON_HEIGHT
	return slot


func _texture_icon(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


func _placeholder(entry: Dictionary) -> Control:
	var slug := entry.slug as String
	var tint := Color.from_hsv(fposmod(float(slug.hash()), 1.0), 0.42, 0.55)
	var tile := ColorRect.new()
	tile.color = tint

	var letter := Label.new()
	letter.text = slug.substr(0, 1).to_upper() if not slug.is_empty() else "?"
	letter.add_theme_font_size_override("font_size", 64)
	letter.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tile.add_child(letter)
	return tile


func _build_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 1.0))
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -NAME_HEIGHT
	add_child(label)

	_hover_style()


func _hover_style() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.0)
	normal.set_corner_radius_all(16)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1, 1, 1, 0.07)
	hover.set_corner_radius_all(16)

	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", hover)
	add_theme_stylebox_override("focus", hover)
