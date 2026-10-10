class_name RaceTrackIndex
extends Resource
## The list of tracks, held explicitly rather than found by scanning
## resources/tracks/.
##
## The scan is the tempting version and the wrong one: a directory listing that
## works in the editor can come back empty in an exported build, because a
## resource nothing references is not necessarily packed. This repo has already
## paid for that lesson twice, with .txt level files and with every game's .cfg.
## Referencing the tracks from here is what guarantees they travel with the
## build.

@export var tracks: Array[RaceTrackInfo] = []


## Never null: an index that failed to list anything should read as "no
## tracks", not crash the screen that was about to show them.
static func load_index() -> RaceTrackIndex:
	var path := "res://10-marble-race/resources/tracks/track_index.tres"
	if not ResourceLoader.exists(path):
		push_error("RaceTrackIndex: missing %s" % path)
		return RaceTrackIndex.new()
	var index: RaceTrackIndex = load(path)
	if index.tracks.is_empty():
		push_error("RaceTrackIndex: %s lists no tracks" % path)
	return index
