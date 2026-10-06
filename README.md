# Put the Flies in the Bag

A fast third-person spider game in Godot 4.6, built on three verbs.
Each level is a test chamber: get to the exit as fast as you can, and catch the
flies on the way. Every fly you catch is an extra jump in the air, and counts
toward your score whether you eat it or not.

The spider runs and jumps, but it can't climb walls any more. What it has instead
is silk, on three buttons, and all three work at the same time:

| Input | Verb |
|-------|------|
| **Left mouse** | **Grapple**: a line to where you point, and you're pulled along it. Anything that isn't slick holds it, and so does a web, including one still in the air. You get one grapple in the air, and it comes back when you land on the ground or on a web that has stuck. Landing on a web that is still flying gives it back once per landing. A pull that ends just under a ledge's lip carries you over it. A pull that ends on a wall holds you there for a moment, and jumping from there kicks you off the wall. |
| **Right mouse** | **Silk**: hold to wind a ball of silk up over the spider's back, then let go to throw. This is cast exactly as before. What leaves the spider now is a whole web, flying face first; the longer the wind-up, the bigger the web. Grapple onto it and ride it, but a ride is a commitment: jumping off a flying web is only a hop, and a web that reaches the end of its range without hitting anything stops dead and drops you. Where its middle meets something it sticks flat against that surface and becomes ground: you can walk on a web on a wall or a ceiling. Every fly it passes over is wrapped and goes on your line. |
| **E / middle mouse** | **Pullback**: your oldest web flies back to you (first thrown, first home), one web per press. It comes straight through walls, wraps every fly it passes, and drops whatever it was stuck to (a crate) at your feet. The web you're standing on is skipped, so two webs can leapfrog up a wall. |
| WASD / Space | run / jump. **Space in the air eats the newest fly on your line for another jump** |
| R | restart the level (instant) |
| Esc | pause: resume, restart, edit this level, menu |
| L | first / third person |

Holding silk doesn't block anything: you can grapple and pull back while the
ball is still winding.

## What levels are made of

* **Stone** (pale, panelled): webs stick to it and grapples hold on it.
* **Slick** (dark striped metal): nothing sticks. A web thrown at it slides off and
  its silk comes back to you, and a grapple line won't bite. You can still
  walk on a slick floor.
* **Flies** hover in place or fly a set path. Only silk takes them: a thrown web
  that touches one, or a web called home through one. A web sitting on a wall
  doesn't catch flies that wander into it. Caught flies trail behind you on a
  line, and each one is an extra jump in the air (the gold beads under the
  silk beads on the HUD).
* **Crates**: silk sticks to them, and the Pullback is the only way to move one.
* **Pressure plates** are pressed by a crate (a spider is too light) and power a
  channel.
* **Doors** slide open while their channel is powered.
* **Moving platforms** follow a path back and forth or in a loop. With a channel
  set, they only run while it's powered. Webs stuck to them ride along.
* **Hazards** (red) and falling out of the level both restart you.
* **The exit**: a silk bag in a ring. Walk in to finish. Your score is the time
  plus the number of flies you caught, and eating flies for jumps doesn't lower
  it. The menu keeps your best time and your most flies separately.

A level also sets how many webs you can have out at once (two by default). It
can also make the bag wait for a number of flies before it opens (none by
default); while it's waiting, the ring is red.

## The levels

1. **First Thread**: jump, grapple across a gap, catch flies, get up a ledge, and
   then clear a slick gap that's too far to jump by eating a fly in mid-air.
2. **Silk Stairs**: a wall you can't climb and two webs. Leapfrog them up the wall with the Pullback.
3. **Ride the Gap**: the gap is farther than a grapple reaches but not as far as silk flies. Ride a web across, through the flies.
4. **Call It Back**: two flies behind a wall over a red floor. Throw webs past them, stand where the way home runs through them, and call. Then fetch a crate for the plate.
5. **Moving Parts**: a ferry, a crate on a post, and a lift the crate starts.
6. **Put the Flies in the Bag**: all of it at once.

## The level editor

**New level** on the menu, or **Edit** on any level, or *Edit this level* from the
pause menu.

* Hold **right mouse** to look around. Fly with **WASD**, and **Q/E** for down and up (Shift goes faster).
* Pick a gameplay piece or any kit piece from `Pieces/` in the palette on the left,
  and **click** to put it down, snapped to the grid. **R** turns it 90° (Shift+R
  15°) and **T** tips it.
* **Click** a thing to select it. The panel on the right shows everything about
  it: position, turn, size, piece, surface (stone/slick), channel, speed, wait,
  loop, and its path. **Add points** then clicking lays out a fly's or platform's
  path; PgUp/PgDn change the height you're placing points at.
* **G** moves the selection, **Ctrl+D** copies it, **Delete** removes it,
  **arrows/PgUp/PgDn** nudge it, **[ ]** change the grid, **Ctrl+Z** undoes,
  **Ctrl+S** saves, and **F5** plays the level. Esc in play brings you back.
* The bar along the top holds the level's name, its web count, how many flies
  the bag wants (0 = none), the fall height and par time, plus Open, New, Save and Save as new.

Levels are plain JSON in `levels/`. When the project folder can't be written to,
they're saved in `user://levels/` instead. The format is documented at the top of
`flies/level/level_data.gd`.

## Where things are

```
flies/
  main.tscn, game_root.gd   the menu, play and the editor, one at a time
  player/    the spider (weaver.gd: running, jumping, the web it's on, the pull,
             the cling), and one node per verb: grapple, silk_caster, pullback,
             fly_line (the caught flies trailing behind). The camera rig, the
             skeleton, the mesh and the eight-legged gait come from the earlier
             game unchanged
  web/       the thrown web, and the silk geometry it's drawn with
  fly/       the fly, drawn with the body it was first given
  rig/       bones and meshes for the fly
  level/     the level format, the builder, the run (clock, channels, exit), the
             surfaces, the kit loader, and crates, plates, doors, platforms,
             hazards and the exit bag
  editor/    the level editor
  ui/        HUD, menu, pause menu
levels/      the built-in levels
Pieces/      the kit, as .fbx
tests/flies/ the suites, and a screenshot tool for the levels
tools/       the import that makes each piece solid, and the tab check
```

## Checks

```
python3 tools/check_tabs.py
godot --headless --path . --script res://tests/flies/mechanics_smoke_test.gd
godot --headless --path . --script res://tests/flies/levels_smoke_test.gd
```

The mechanics suite checks each verb and each level object in a test arena. The
levels suite checks that every level is complete and that the editor works. It
then plays every built-in level from start to finish with a scripted route
through the real controls (no teleporting), so a level that can't be finished
fails CI.

```
xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 \
    --path . --script res://tests/flies/screenshot_levels.gd -- 03
```

That command renders a level from the spider's start and from above.

## History

This branch started from the spider game on `claude/eager-gauss-g1mosx`, which
is left as it was. Only the camera, the spider's body and gait, the web
geometry, the kit loader and the fly's original body were carried over.
