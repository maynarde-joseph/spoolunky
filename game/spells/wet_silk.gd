class_name WetSilk
extends Node

## Water standing in a web: silk the spider has doused.
##
## A wet web does not burn — fire passes it by and burns what it holds without
## taking the web — and lightning stays in it twice as long. So water is how you
## keep a web through fire of your own, and how you make a live web last. It dries
## off in a few seconds.

const NAME := "Wet"

## How long lightning stays in a wet web, as so many times as long as in a dry one.
const LIVE_LONGER := 2.0

## How much darker the silk looks while it is wet.
const DARKER := 0.35

## The web it is in.
var web: WebStructure

## Seconds left before it dries.
var left := 8.0

var _albedo := Color.WHITE


## Soaks [param in_web] for [param seconds]: longer if it is already wet and this
## is the longer soak. Null if there is no web.
static func soak(in_web: WebStructure, seconds: float) -> WetSilk:
	if in_web == null or not is_instance_valid(in_web) or in_web.is_queued_for_deletion() \
			or seconds <= 0.0:
		return null
	var wet := of(in_web)
	if wet != null:
		wet.left = maxf(wet.left, seconds)
		return wet
	wet = WetSilk.new()
	wet.name = NAME
	wet.web = in_web
	wet.left = seconds
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


func _ready() -> void:
	if web == null:
		web = get_parent() as WebStructure
	if web == null:
		queue_free()
		return
	if web.material != null:
		_albedo = web.material.albedo_color
		web.material.albedo_color = _albedo.darkened(DARKER)


func _physics_process(delta: float) -> void:
	left -= delta
	if left <= 0.0:
		if is_instance_valid(web) and web.material != null:
			web.material.albedo_color = _albedo
		queue_free()
