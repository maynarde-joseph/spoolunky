# Put the Flies in the Bag

A fast third-person spider game in Godot 4.6, built on three verbs.
Each level is a test chamber: get to the exit as fast as you can. (The flies the
game is named for are out for now, while the web is the whole focus.)

The spider moves the way the old spider did, at what was its sprint, but it
can't climb walls any more. What it has instead is silk, on three buttons, and
all three work at the same time:

| Input | Verb |
|-------|------|
| **Left mouse** | **Grapple**: a line to a web you point at (any web in plain sight, however far), and you're pulled along it in a straight line. **A web that has stuck: you land on it. A web still in flight: you ride it, all the way** to wherever it sticks: no jumping or walking off, and the grapple stays spent until it lands you. One that runs out of reach, hits slick metal or flies into a silk cutter stops dead and drops you. Press Space mid-pull to let go and drop where you are. **Only silk holds the grapple**: stuck webs, and webs still in the air (the line follows them). Your webs are your anchors. You get one grapple in the air, and it comes back when you land on the ground or on a web that has stuck. |
| **Right mouse** | **Silk**: hold to wind a ball of silk up over the spider's back, then let go to throw. This is cast exactly as before. What leaves the spider now is a whole web, flying face first for up to 22 m; the longer the wind-up, the bigger the web. Grapple onto it in flight and ride it. Throwing in the air holds you up for 0.4 s (once per time in the air). Where its middle meets something it sticks flat against that surface and becomes ground: you can walk on a web on a wall or a ceiling. |
| **E / middle mouse** | **Pullback**: your oldest web flies back to you (first thrown, first home), one web per press. It comes straight through walls, and what it was on feels the pull: a crate comes with it to your feet, a loose board is ripped away, a block on a rail slides to the other end of it. The web you're standing on is skipped, so two webs can leapfrog up a wall. If it reaches you in the air, it catches you: an air-stall of 1 s with your speed mostly gone, which gives you a moment to aim the next throw (once per time in the air). |
| WASD / Space | move / jump |
| R | restart the level (instant) |
| Esc | pause: resume, restart, edit this level, menu |
| L | first / third person |

Holding silk doesn't block anything: you can grapple and pull back while the
ball is still winding.

A web is walked on one face: the one you landed on (on a web flat against a
wall or floor, the side facing the room). Its rim holds you, unless there's a
floor or another web just past it to step onto.

## What levels are made of

* **Stone** (pale, panelled): webs stick to it.
* **Slick** (dark striped metal): nothing sticks. A web thrown at it slides off and
  its silk comes back to you, so you can't put an anchor there. You can still
  walk on a slick floor.
* **The ceiling**: a slick lid over every level, drawn as a faint grid. A web
  thrown at the sky slides off it, so nothing gets you over the top.
* **Crates**: silk sticks to them, and the Pullback is the only way to move one.
* **Pressure plates** are pressed by a crate (a spider is too light) and power a
  channel.
* **Doors** slide open while their channel is powered.
* **Moving platforms** follow a path back and forth or in a loop. With a channel
  set, they only run while it's powered. Webs stuck to them ride along.
* **Loose boards** (weathered wood): silk sticks to them, but they won't hold you, so you can't grapple to or walk onto a web on one. Call that web home and the board rips away, leaving whatever it covered.
* **Blocks on rails** (stone with orange trim, and orange arrows on their sides): call a web on one home and the block slides the way its arrows point, to the other end of its rail; then the arrows turn round, and the next call slides it back. Rails run any way, up and down too, and blocks don't fall.
* **Silk cutters** (violet laser grids in a metal frame): any web that flies through one is cut (a ride stops dead there and drops you), and a grapple line won't cross one. They don't touch the spider, which walks straight through, and webs called home pass through them.
* **Hazards** (red) and falling out of the level both restart you.
* **The exit**: a silk bag in a ring. Walk in to finish. Your score is the time,
  and the menu keeps your best.

A level also sets how many webs you can have out at once (two by default).

## The levels

Every level is made of rooms sealed to the ceiling, joined by gates that silk alone
can't open: a loose board over a doorway, a block on a rail plugging one, or a
door on a plate. Inside a room, move however you like. CI checks that no level
can be finished with web, grapple, drop, repeat (see `tests/flies/silk_reach.gd`).

1. **First Thread**: jump a gap, web a stone face and climb it, and rip the boards off the way out.
2. **Silk Stairs**: leapfrog two webs up a wall, then call a block on an upright rail up out of the doorway.
3. **Drop In**: ride a web out over a slick island until it stops dead and drops you, then rip the boards off the hut with the exit in it.
4. **Cut Lines**: ride through the one window in a silk cutter curtain, then walk through the cutters boxing in the way out and rip its boards off from inside.
5. **Call It Back**: web a crate behind a wall from the pulpit, stand on the plate, and call it home to open the door.
6. **Moving Parts**: a ferry, then a crate whose plate starts a lift and opens the door at the top.
7. **Pull the Room**: slide one block out of a doorway, then bring another down out of a high doorway to be the step up into it.
8. **All Together**: a web across the drop, a leapfrogged tower, boards off a window, and a crate for the door.

## The level editor

**New level** on the menu, or **Edit** on any level, or *Edit this level* from the
pause menu.

* Hold **right mouse** to look around. Fly with **WASD**, and **Q/E** for down and up (Shift goes faster).
* Pick a gameplay piece or any kit piece from `Pieces/` in the palette on the left,
  and **click** to put it down, snapped to the grid. **R** turns it 90° (Shift+R
  15°) and **T** tips it.
* **Click** a thing to select it. The panel on the right shows everything about
  it: position, turn, size, piece, surface (stone/slick), channel, speed, wait,
  loop, and its path. **Add points** then clicking lays out a platform's
  path; PgUp/PgDn change the height you're placing points at.
* **G** moves the selection, **Ctrl+D** copies it, **Delete** removes it,
  **arrows/PgUp/PgDn** nudge it, **[ ]** change the grid, **Ctrl+Z** undoes,
  **Ctrl+S** saves, and **F5** plays the level. Esc in play brings you back.
* The bar along the top holds the level's name, its web count, the fall height, the ceiling height (0 = 6 m over the top) and par time, plus Open, New, Save and Save as new.

Levels are plain JSON in `levels/`. When the project folder can't be written to,
they're saved in `user://levels/` instead. The format is documented at the top of
`flies/level/level_data.gd`.

## Where things are

```
flies/
  main.tscn, game_root.gd   the menu, play and the editor, one at a time
  player/    the spider (weaver.gd: walking, jumping, the web it's on, the pull,
             the catch-stall), and one node per verb: grapple, silk_caster,
             pullback. The camera rig, the
             skeleton, the minimal mesh and the eight-legged gait come from the
             earlier game unchanged
  web/       the thrown web, and the silk geometry it's drawn with
  rig/       the mesh-building kit the spider's body is made with
  level/     the level format, the builder, the run (clock, channels, exit), the
             surfaces, the kit loader, and crates, plates, doors, platforms,
             loose boards, blocks on rails, hazards and the exit bag
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
levels suite checks that every level is complete, that none can be finished with
silk alone, and that the editor works. It
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
geometry and the kit loader were carried over. The flies, and the body they were
drawn with, were in this game until they were taken out to focus on the web;
they're in the history.
