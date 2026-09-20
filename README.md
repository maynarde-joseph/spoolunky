# Spoolunky

A first-person spider game in Godot 4.6. You start the size of a coin in the
corner of a room, spin webs to catch whatever walks into them, and eat your way
up until the room can't hold you.

The full pitch — the loop, the size tiers, the zones, the trap catalogue — is in
[`docs/DESIGN.md`](docs/DESIGN.md).

## Where things are

```
game/
  data/      web patterns and size tiers (plain resources — edit the numbers)
  web/       procedural silk geometry and the webs themselves
  player/    the spider: silk supply, growth, build mode, climbing
  prey/      things to catch, and something to spawn them
  ui/        HUD
tests/       headless smoke test and a screenshot tool
addons/character-controller/   the movement template the spider is built on
```

The sandbox is the character-controller example level
(`addons/character-controller/example/main/level.tscn`), which is the project's
main scene. It has the spider, a HUD, a `Webs` container and a prey spawner
dropped into it.

## Controls

| Input | Action |
|-------|--------|
| WASD / Space / Shift | move, jump, sprint |
| *walk into a wall* | climb it — walls and ceilings are floors to a spider |
| **Ctrl** | drop onto a dragline (from a wall or ceiling) |
| **Ctrl** / **Space** | lower / raise yourself on the line |
| **Right Mouse** | let go of the line |
| **Q** | web build mode |
| **Left Mouse** | place an anchor |
| **Right Mouse** | undo the last anchor, or leave build mode |
| **F** | spin the web |
| **Wheel** or **Z** / **C** | change web pattern |
| **E** | wrap caught prey, then drain it (also re-arms a sprung snare) |
| **X** | pull down the web you're looking at, for half the silk back |
| **H** | toggle the help overlay |
| **R** | free-fly (from the movement template, handy for scouting) |
| **T** | release the mouse · **Esc** quit |

## Building a web

Anchors are shot at real surfaces, so webs take the shape of the gap you string
them across. Two anchors make a strand (tripline, bridge); three or more make a
net, which is filled in with spokes and a spiral and will catch things.

You are charged silk only when the web actually goes up, and the HUD shows a
running estimate plus the reason a spot won't take an anchor — out of reach, too
far to span, not enough silk, or a pattern your size can't spin yet.

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
```
