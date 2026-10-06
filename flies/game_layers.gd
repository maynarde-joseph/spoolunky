class_name GameLayers
extends RefCounted

## Physics layer bits, so nothing has to remember what "mask 20" meant.
## Layer 4 (water) is the one the character-controller addon already uses.

const WORLD := 1 << 0
const PLAYER := 1 << 1
const PREY := 1 << 2
const WATER := 1 << 3
const WEB := 1 << 4

## Surfaces made of silk that the spider can stand on. Deliberately separate
## from WORLD: the spider collides with it, prey does not, so a web you can walk
## about on is still a web things fly into.
const WEB_WALK := 1 << 5
