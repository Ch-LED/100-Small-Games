class_name AsteroidsLayers
## Collision layer bits. Engine-native integer masks do the broad-phase
## filtering; the actual target identity is still resolved by type.
##
## Only the ship, player bullets and saucer bullets monitor. Everything else is
## monitorable-only, so a single contact is never resolved twice.

const SHIP := 1
const ROCK := 2
const BULLET := 4
const SAUCER := 8
const SAUCER_BULLET := 16
