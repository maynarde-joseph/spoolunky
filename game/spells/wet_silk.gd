class_name WetSilk
extends Node

## Water standing in a web: silk the spider has doused, once it has learned to —
## see the Wet Silk skill.
##
## A wet web does not burn — fire passes it by and burns what it holds without
## taking the web — and lightning stays in it twice as long. So water is how you
## keep a web through fire of your own, and how you make a live web last. Soaked
## by a spider that has learned Sodden Silk it is [member heavy] too, and holds
## half as hard again. It shows — the silk blue, and its threads a little thicker
## (see [method WebStructure.show_wet]) — and it dries off in a few seconds.

const NAME := "Wet"

## How long lightning stays in a wet web, as so many times as long as in a dry one.
const LIVE_LONGER := 2.0

## How much harder a heavy wet web holds: Sodden Silk's.
const HEAVY_HOLD := 1.5


## The web it is in.
var web: WebStructure

## Seconds left before it dries.
var left := 8.0

## Whether the water weighs the silk down and makes it hold harder. See
## [constant HEAVY_HOLD].
var heavy := false



## Soaks [param in_web] for [param seconds]: longer if it is already wet and this
## is the longer soak, and [param weighs] heavy if either soak was. Null if there
## is no web.
static func soak(in_web: WebStructure, seconds: float, weighs := false) -> WetSilk:
	if in_web == null or not is_instance_valid(in_web) or in_web.is_queued_for_deletion() \
			or seconds <= 0.0:
		return null
	var wet := of(in_web)
	if wet != null:
		wet.left = maxf(wet.left, seconds)
		wet.heavy = wet.heavy or weighs
		return wet
	wet = WetSilk.new()
	wet.name = NAME
	wet.web = in_web
	wet.left = seconds
	wet.heavy = weighs
	in_web.add_child(wet)
	return wet


## The water standing in [param in_web], or null if it is dry.
static func of(in_web: WebStructure) -> WetSilk:
	if in_web == null or not is_instance_valid(in_web):
		return null
	for child in in_web.get_children():
		var wet := child as WetSilk
		if wet != null and not wet.is_queued_for_deletion() and wet.left > 0.0:
			return wet
	return null


## Whether [param in_web] is wet.
static func is_wet(in_web: WebStructure) -> bool:
	return of(in_web) != null


## What the water in [param in_web] does to how hard it holds: [constant HEAVY_HOLD]
## while it is heavy, otherwise nothing.
static func hold_scale(in_web: WebStructure) -> float:
	var wet := of(in_web)
	return HEAVY_HOLD if wet != null and wet.heavy else 1.0


func _ready() -> void:
	if web == null:
		web = get_parent() as WebStructure
	if web == null:
		queue_free()
		return
	# Blue, and a little thicker, while the water stands in it.
	web.show_wet(true)


func _physics_process(delta: float) -> void:
	left -= delta
	if left <= 0.0:
		if is_instance_valid(web):
			web.show_wet(false)
		queue_free()
