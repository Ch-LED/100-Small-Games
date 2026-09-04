## Pure scanner: discovers playable game directories under res:// and reads
## their entry metadata. No scene / UI dependencies.

const META_FILENAME := "meta.json"
const DEFAULT_ICON_REL := "assets/icon.svg"
const HUB_PREFIX := "00-"


## Returns an array of GameEntry dicts (fields: num, dir, slug, scene_path,
## display_name, icon_path). Directories without a valid main scene are
## skipped with a warning; a missing/broken meta falls back to the slug.
static func discover() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for dir_name in DirAccess.get_directories_at("res://"):
		if not _is_game_dir(dir_name):
			continue
		var entry := _read_entry(dir_name)
		if not entry.is_empty():
			entries.append(entry)
	entries.sort_custom(func(a, b): return a.num < b.num)
	return entries


static func _is_game_dir(dir_name: String) -> bool:
	if dir_name.begins_with(HUB_PREFIX):
		return false
	if dir_name.length() < 3:
		return false
	return dir_name[0].is_valid_int() \
		and dir_name[1].is_valid_int() \
		and dir_name[2] == "-"


static func _read_entry(dir_name: String) -> Dictionary:
	var scene_path := "res://%s/%s.tscn" % [dir_name, dir_name.substr(3)]
	if not ResourceLoader.exists(scene_path):
		push_warning("GameDiscovery: skip %s, main scene missing (%s)" % [dir_name, scene_path])
		return {}

	var display_name := dir_name.substr(3)
	var icon_path := "res://%s/%s" % [dir_name, DEFAULT_ICON_REL]
	var meta_path := "res://%s/%s" % [dir_name, META_FILENAME]
	if FileAccess.file_exists(meta_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
		if parsed is Dictionary:
			var name_val: Variant = parsed.get("name")
			if name_val is String and not (name_val as String).is_empty():
				display_name = name_val
			var icon_val: Variant = parsed.get("icon")
			if icon_val is String and not (icon_val as String).is_empty():
				icon_path = "res://%s/%s" % [dir_name, icon_val]

	return {
		"num": dir_name.substr(0, 2),
		"dir": dir_name,
		"slug": dir_name.substr(3),
		"scene_path": scene_path,
		"display_name": display_name,
		"icon_path": icon_path,
	}
