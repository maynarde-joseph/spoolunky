class_name GameLayers
extends RefCounted

## Physics layer bits, so nothing has to remember what "mask 5" meant.
## Layer 4 (water) is the one the character-controller addon already uses.

## The land and everything built on it: what the spider walks and climbs on, and
## what keeps an insect in its pen.
const WORLD := 1 << 0
const PLAYER := 1 << 1
## The farm's insects, alive or wrapped. The spider walks through them; silk and
## the crosshair stop on them.
const INSECT := 1 << 2
const WATER := 1 << 3
