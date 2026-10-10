class_name RaceTrackInfo
extends Resource
## One row in the level select.

## Key this track's best time is filed under in the save. Treat it as
## permanent: changing it silently loses every record set on that track.
@export var id := ""
## What the player reads. Shown in Chinese like every other game's name.
@export var display_name := ""
@export var scene_path := "res://10-marble-race/scenes/race.tscn"
