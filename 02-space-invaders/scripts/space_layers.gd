class_name SpaceLayers
## Collision layer bits for space-invaders. Engine-native integer masks are
## used for broad-phase filtering; target identity is still resolved by type.

const PLAYER := 1
const ENEMY := 2
const PLAYER_BULLET := 4
const ENEMY_BULLET := 8
const SHIELD := 16
const UFO := 32
