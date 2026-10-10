class_name TrackWall
extends Resource
## A barrier rising out of one edge of the road over a stretch of it.
##
## Walls are attributes of the route rather than shapes of their own: there is
## nothing to drag in the viewport, only a side, a stretch and a height. That
## is why they are data on the track node instead of nodes beside it — the same
## reason the start and finish are vertex colours rather than marker meshes.

## -1 for the road's left edge, +1 for its right.
@export var side := 1
## Where along the curve the wall runs: 0 at the start, 1 at the end.
@export var from_t := 0.0
@export var to_t := 1.0
@export var height := 1.4
