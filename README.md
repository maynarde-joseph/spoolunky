# Spoolunky

A first-person spider game in Godot 4.6. You start the size of a coin in the
corner of a room, spin webs to catch whatever walks into them, and eat your way
up until the room can't hold you.

The full pitch — the loop, the size tiers, the zones, the trap catalogue — is in
[`docs/DESIGN.md`](docs/DESIGN.md).

## Where things are

```
game/
  data/      web patterns, devices and size tiers (plain resources — edit the numbers)
  web/       procedural silk geometry and the webs themselves
  player/    the spider: silk supply, growth, build mode, the bag, climbing
  prey/      things to catch, and something to spawn them
  ui/        HUD
tests/       headless smoke test and a screenshot tool
addons/character-controller/   the movement template the spider is built on
```

The sandbox is the character-controller example level
(`addons/character-controller/example/main/level.tscn`), which is the project's
main scene. It has the spider, a HUD, a `Webs` container and a prey spawner
dropped into it. A `Devices` container is made on demand the first time you put
something down.

## Controls

| Input | Action |
|-------|--------|
| WASD / Space / Shift | move, jump, sprint |
| *walk into a wall* | climb it — walls and ceilings are floors to a spider |
| **F** or **middle mouse** | clip onto a silk line and ride it — again to let go |
| **Ctrl** | drop onto a dragline (from a wall or ceiling) |
| **Ctrl** / **Space** | lower / raise yourself on the line |
| **Right Mouse** | let go of the line |
| **Q** | web build mode |
| **Left Mouse** | grapple to the next anchor, dragging silk behind you |
| **Right Mouse** | undo the last anchor, or leave build mode |
| **F** | weave a ring of silk — the one you walked, or the one you're looking at |
| **Wheel** or **Z** / **C** | change web pattern |
| **E** | wrap caught prey, then drain it (also re-arms a sprung snare) |
| **X** | pull down the web you're looking at, for half the silk back — or pick a device back up |
| **G** | wire two things together — web or device, press on each end |
| **N** | open the bag — place a device (wheel to pick, left mouse to put down) |
| **B** | keep the rig you're looking at as a design |
| **V** | place a saved design — wheel to pick, left mouse to spin it |
| **L** | camera: third person or first person |
| **K** | switch weave: stretched or inscribed |
| **;** | pick a tuning dial |
| **[** / **]** | turn that dial down / up |
| **'** | put the dials back to standard |
| **H** | toggle the help overlay |
| **R** | free-fly (from the movement template, handy for scouting) |
| **T** | release the mouse · **Esc** quit |

## Building a web

Placing an anchor **grapples you to it**, dragging a frame line behind you. So
the frame of a web is the route you took around it, not an outline you drew from
across the room.

Frame lines are real silk that stands on its own, and they're ridable — walk a
triangle into a corner and you've built three ziplines whether or not you ever
weave anything into them. Once the run closes a loop, **F** weaves the enclosed
area in one go, charging only for the silk inside; the frame was paid for as you
dragged it. Pulling a web down later leaves the frame standing.

If the selected pattern is a strand (tripline, bridge), that's what gets dragged
instead of plain frame line, so you can lay a run of triplines the same way.

**Every strand is a zipline** — there's no opt-in. And weaving isn't limited to
a loop you just walked: all your silk is one graph, and lines count as joined
where they *cross in mid-air* as well as where they share an end. Sling three
lines across a shaft and the triangle where they overlap is a ring you can fill.
Look at any ring and press **F**.

## Riding your own silk

Any strand built from a ridable pattern — the silk bridge — can be clipped onto
with **F** or the middle mouse button, and ridden. Gravity does the work on a
downhill line, the movement keys push you along a level one, and letting go
throws you off carrying all the speed you built, plus a kick to clear the edge.
Arrive on a line already moving and you keep it.

The camera opens up as you go faster. Look direction is kept in world terms, so
the mouse means the same thing whatever surface the spider is stuck to, and the
horizon stays level even on a ceiling. **L** switches between third and first
person.

## Living on the web

Finished webs are solid enough to stand on — the spider sticks to one the same
way it sticks to a wall, and deals with caught prey from on top of the silk.

Silk surfaces are on their own collision layer so the spider collides with them
and prey doesn't. That matters: a web firm enough to hold a spider would
otherwise be firm enough to bounce a fly off. It also means a web laid flat on
the ground works as a floor trap with no special handling — things walk onto it
and stick, and you can walk over it.

## Climbing

The spider has no floor — it sticks to whatever it touches, and the body's up
axis becomes the surface normal. Walk into a wall to climb it, keep going to
end up on the ceiling. While you are already on a surface you only transfer to
a new one by pushing into it, so walking beside a wall doesn't throw you up it;
in mid-air the spider grabs the first thing it touches. Put a collider in the
`no_climb` group to make it unclimbable.

From a wall or ceiling, **Ctrl** drops you onto a dragline. It costs silk by
the metre (half back when you reel in), it's a real pendulum so you can swing
onto things, and right mouse lets go.

## Wiring traps together

**G** on one thing, then **G** on another, runs a signal line between them: when
the first goes off, the second reacts. A snare that gets a signal whips out and
drags in prey within about three times its radius — so a tripline across a
doorway can spring a snare on the far side of the room and catch something that
never touched the silk. Any other web tenses instead, holding roughly twice as
well for a few seconds. Signals chain, and the dashed cold-blue lines show you
your own machine.

Either end can be a **device** rather than a web — they sit on the same graph.

## Leaving a web and coming back

Prey that hits a web fights hard for about five seconds. Survive that and it
tires out and hangs there until you come for it — so a web is somewhere you
*store* things, not a moment you have to be present for. Lose that window and
it tears free and takes a piece of the web with it.

Which web you used decides which way that goes: a sheet web just about keeps a
fly, an orb web keeps a moth, a pressure snare keeps a wasp. Silk quality rises
with your size and multiplies hold, so the same web keeps bigger things later.

Webs also **fill up** — two for a sheet web, four for an orb web — and a full
one catches nothing more. That's the nudge to run several sites rather than one
big web, and a wired-up **Signal Bell** is how you find out a site is full
without walking over to look.

A settled catch still tugs, so a full larder slowly wears the web out. Wrapping
it (**E**) stops that completely — wrapping is preservation, not just securing.

## The bag — things that aren't silk

**N** opens the bag. Wheel to pick, left mouse to put one down, **X** to take it
back up. Placing costs no silk at all: devices are finite and found, and running
out is the whole limit on them.

They only ever do things silk *cannot*, which is what stops them being better
webs:

| Device | What it's for |
|--------|---------------|
| **Venom Spur** | Wire it to a trap and whatever that trap catches **dies**. A dead thing can be drained whatever its size, so this is how you take something too big to bite. One shot. |
| **Scent Lure** | **Pulls prey in from much further than a funnel web, with no web at all.** Drop one where you want traffic. |
| **Signal Bell** | Wire it to anything and it **tells you the moment that thing goes off**, from anywhere in the level. |

The bell is what makes leaving a trap behind work: build it, zip off somewhere
else, and get told when to come back rather than having to guess.

Devices land in a `Devices` node next to `Webs`, and a new one is a `.tres` in
`game/data/devices/` — same as adding a web pattern.

## Two ways to weave a web

**K** switches between them, and it applies to webs spun from then on:

* **Stretched** (default) — the web is the shape you drew. The spiral runs out
  to the anchors, so an odd outline makes an odd web.
* **Inscribed** — what a real orb weaver builds: an even round spiral as big as
  fits inside the frame, spokes carrying on past it to the anchors. Here the
  shape of your outline matters, because the catching area is the biggest
  circle that fits — a fat outline beats a long sliver by a mile.

Either way the frame sits on the anchors exactly where you put them, in 3D, so
a web across a room corner tents through the fold instead of floating off the
wall.

## Tuning a web

Three dials, set before you spin, each one a trade rather than an upgrade:

| Dial | Up | Costs you |
|------|----|-----------|
| **Tension** | holds harder | tears sooner |
| **Weight** | stronger all round | more silk per metre |
| **Mesh** (opened out) | cheaper — fewer threads | small prey walks through |

`;` picks a dial, `[` and `]` turn it, `'` resets. Settings are remembered per
pattern and travel inside saved designs. Weight and mesh change the weave
itself, so a tuned web looks different as well as behaving differently.

## Saving a rig as a design

**B** while looking at a web keeps it — and everything wired to it — as a
design. **V** brings your designs up: the wheel picks one, a ghost shows where
it would land, and left mouse spins the whole rig, wiring and all, turned to
face the way you're looking. You're charged at today's silk prices, and nothing
is built or charged unless all of it can be.

Designs are written to `user://designs/*.tres`, which is
`~/.local/share/godot/app_userdata/spoolunky/designs` on Linux. They're plain
resources, so renaming one is a matter of editing `display_name` in the file.

Anchors are replayed exactly as recorded rather than re-fitted to whatever is
under them, so a rig placed in a differently-shaped spot keeps its shape — the
ghost preview is there so you can see that before committing.

## Adding a new kind of web

Duplicate any `.tres` in `game/data/patterns/`, change the numbers, and it turns
up in the build wheel — the library scans that folder. The fields that matter
most are `shape` (strand or net), `trigger` (passive, alert, snare or lure),
`unlock_stage`, the three silk costs, and `hold_strength` / `durability`.

## Running the tests

The smoke test loads the sandbox and drives the whole loop — building each
pattern, catching a fly in one, wrapping and draining it, growing a size tier,
springing and re-arming a snare, and pulling a web back down:

```sh
godot --headless --script res://tests/web_smoke_test.gd
```

A second one walks a spider up a wall, across a ceiling, down on a thread and
back, in a plain box room:

```sh
godot --headless --script res://tests/climb_smoke_test.gd
```

Both print a line per check and exit non-zero if any fail.

To look at the silk geometry without opening the editor:

```sh
xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 \
    --script res://tests/screenshot_webs.gd
xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 \
    --script res://tests/screenshot_climb.gd
xvfb-run -a godot --rendering-driver opengl3 --resolution 1100x740 \
    --script res://tests/screenshot_weave.gd
```
