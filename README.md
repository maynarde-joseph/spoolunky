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
| WASD / Space / Shift | move, jump, sprint — **jump is also how you let go of silk** |
| *walk into a wall* | climb it — walls and ceilings are floors to a spider |
| *stand on silk* | it holds you — a thread runs one way, and **jump** is how you come off |
| **F** or **middle mouse** | ride a silk line like a zipline — again to let go |
| **Ctrl** | drop onto a dragline (from a wall or ceiling) |
| **Ctrl** / **Space** | lower / raise yourself on the line |
| **Right Mouse** | let go of the line |
| **Left Mouse** | **go there, trailing silk** — moving and building are the same act |
| **Q** *(hold)* | spin a web where you're aiming — hold longer for a bigger one |
| **M** | webs: **placed** where you point / **thrown** as a bolt that opens where it lands |
| **Wheel** or **Z** / **C** | change which web you spin |
| **Right Mouse** | let go of a line |
| **E** | wrap caught prey, then drain it (also re-arms a sprung snare) |
| **X** | pull down the web you're looking at, for half the silk back — or pick a device back up |
| **G** | wire two things together — web or device, press on each end |
| **N** | open the bag — place a device (wheel to pick, left mouse to put down) |
| **J** | silk: unlimited / costs again (sandbox switch, starts unlimited) |
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

There is no build mode. **Left mouse grapples you to whatever you're pointing
at, and drags a line behind you** — so getting around and building are the same
act, and the silk ends up being a record of where you went.

To make a web, **aim where you want it and hold Q**, then let go.

Holding sets how far the web is *allowed* to reach — the room decides where it
actually stops. Every corner of the rim runs outward until it hits something,
so the same press gives you a full circle in open air and a web that fills the
angle when you point into a corner. A doorway gets something doorway-shaped
rather than a disc hanging in the middle of it.

The HUD shows the area you're about to cover and how many corners have found
something to hold onto.

**M** switches how the web gets there. *Placed* is the above: it appears under
the crosshair the moment you let go. *Thrown* sends a bolt of silk instead —
it flies, it drops a little on the way, and it opens out to the size you
charged it to wherever it lands. It can miss, and something moving has to be
led rather than pointed at, which is the whole point of having both. Nothing is
paid for until the silk arrives.

How big a web you can spin is what the size tiers gate — and what you can
currently pay for. The web stops growing when your silk runs out rather than
refusing at the end, so the ghost is always something you can actually buy.

**Range is unlimited** — if you can see it, you can grapple to it. The size
tiers gate what your silk can *hold* and how much you can spin, not where you
are allowed to go. A long grapple is flung faster so it still lands in about a
second, because distance should cost you silk rather than patience.

Every line is a road, and **silk is sticky**. Step onto a thread and you're
stuck to it — it keeps hold of you until you **jump off**, the same as the wall
and the ceiling do. A thread only runs one way, so that's the way you walk on
it: pushing across a line does nothing rather than walking you off the side of
it. You still set your own pace and face either way. A *web* is a floor and
gets none of that — walk about on it however you like.

**F** is the zipline, and it's something you ask for rather than something that
happens to you: clip onto the line proper, let gravity pull you down the slope,
and let go to be thrown off carrying the speed.

Silk is about half again quicker underfoot than the floor, and you can
**grapple straight onto a line** from a distance to get on it — that joins the
network rather than stringing another line to reach it. A route you built once
is a route you can take.

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

## Two things a web is for

**Throw one at something.** A web spun over a moth wraps it where it stood, the
silk goes with it, and the bundle drops to the floor for you to collect — so
you can deal with something in front of you rather than only setting up for
later. Nothing is left hanging on the wall: the web was the wrap.

Only if your silk is up to it, mind: a web takes something outright just when
it could have out-held the whole fight that thing would have put up. Throw a
sheet web at a wasp and you get a wasp hanging in a sheet web, fighting.

**Leave one somewhere to work.** Fit a web to a corner prey walks past, drop a
**Scent Lure** on the far side so traffic comes *through* the web to reach it,
and wire a **Signal Bell** in so you get told when it catches. Then go
somewhere else.

Same object, same rules, either way — including whether it holds what hits it.

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

They also run on every push: `.github/workflows/tests.yml` fetches the Linux
build matching `GODOT_VERSION` and runs both suites, so you do not need Godot
on PATH to find out whether a change broke something. Bump that one variable
when the project moves to a new engine version — the workflow finds the build
itself rather than holding a URL that rots.

To look at the silk geometry without opening the editor:

```sh
xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 \
    --script res://tests/screenshot_webs.gd
xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 \
    --script res://tests/screenshot_climb.gd
xvfb-run -a godot --rendering-driver opengl3 --resolution 1100x740 \
    --script res://tests/screenshot_weave.gd
```
