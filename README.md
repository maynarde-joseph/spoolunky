# Put the Flies in the Bag

A fast third-person spider game in Godot 4.6, built on three verbs.
Each level is a test chamber: get to the exit as fast as you can. (The flies the
game is named for are out for now, while the web is the whole focus.)

The spider moves the way the old spider did, at what was its sprint, but it
can't climb walls any more. What it has instead is silk, on three buttons, and
all three work at the same time:

| Input | Verb |
|-------|------|
| **Left mouse** | **Grapple**: a line to a web you point at (any web in plain sight, however far), and you're pulled along it in a straight line. **A web that has stuck: you land on it. A web still in flight: you're pulled to where you meet it and drop from there**, with none of the pull's speed, and that web is used up: it comes apart and its silk is yours again. Press Space mid-pull to let go and drop where you are. **Only silk holds the grapple**: stuck webs, and webs still in the air (the line follows them). Your webs are your anchors. You get one grapple in the air, and it comes back when you land on the ground or on a web that has stuck. Meeting a web in flight gives it back once per landing. |
| **Right mouse** | **Silk**: hold to wind a ball of silk up over the spider's back, then let go to throw. This is cast exactly as before. What leaves the spider now is a whole web, flying face first for up to 22 m; the longer the wind-up, the bigger the web. Grapple to it in flight and you drop where you meet it. Where its middle meets something it sticks flat against that surface and becomes ground: you can walk on a web on a wall or a ceiling. |
| **E / middle mouse** | **Pullback**: your oldest web flies back to you (first thrown, first home), one web per press. It comes straight through walls, and what it was on feels the pull: a crate comes with it to your feet, a loose board is ripped away, a block on a rail is dragged along it toward you. The web you're standing on is skipped, so two webs can leapfrog up a wall. If it reaches you in the air, it catches you: a short air-stall (about 0.6 s) with your speed mostly gone, which gives you a moment to aim the next throw. |
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
* **Blocks on rails** (stone, with an orange bar under them): call a web on one home and the block is dragged along its rail to where its top is nearest your feet. Rails can run any way, up and down too, and blocks don't fall: stand on a ledge and call a block on an upright rail, and it rises level with you.
* **Hazards** (red) and falling out of the level both restart you.
* **The exit**: a silk bag in a ring. Walk in to finish. Your score is the time,
  and the menu keeps your best.

A level also sets how many webs you can have out at once (two by default).

## The levels

1. **First Thread**: jump a gap, throw a web across a long one and grapple to it,
   web up a ledge, then jump to the slick pad with the exit on it.
2. **Silk Stairs**: a wall you can't climb and two webs. Leapfrog them up the wall with the Pullback.
3. **Drop In**: the exit is on a slick island out in the open. Throw a web out over it, catch it in flight, and drop.
4. **Call It Back**: a crate on a post in the red, behind a wall. Web it from the pulpit, stand on the plate, and call it home to open the door.
5. **Moving Parts**: a ferry, a crate on a post, and a lift the crate starts.
6. **Pull the Room**: rip the boards off a ledge's only stone face, then drag a block on a rail into a gap to cross it.
7. **All Together**: a web across the drop, a tower to leapfrog, and a crate for the door.

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
geometry and the kit loader were carried over. The flies, and the body they were
drawn with, were in this game until they were taken out to focus on the web;
they're in the history.
