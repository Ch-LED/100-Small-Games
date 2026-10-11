class_name RaceTrackInfo
extends Resource
## One row in the level select, and the whole of what makes one track different
## from another: its route and the barriers along it.
##
## Those live here rather than in a scene per track because they are content,
## not structure — the ball, the camera, the HUD and the finish are the same on
## every track, and only the road is not. One scene runs them all.

## Key this track's best time is filed under in the save. Treat it as
## permanent: changing it silently loses every record set on that track.
@export var id := ""
## What the player reads. Shown in Chinese like every other game's name.
@export var display_name := ""
## The route, baked from a waypoint list by make_track.gd. A track without one
## has no road to sweep and the level will refuse to build.
@export var curve: Curve3D = null
## Barriers along this route's edges. Level data rather than tuning, which is
## why they travel with the route instead of sitting in the cfg.
@export var walls: Array[TrackWall] = []
## Which scene runs this track. Every track points at the same one today, and a
## track that ever needs different furniture can point somewhere else.
@export var scene_path := "res://10-marble-race/scenes/race.tscn"
