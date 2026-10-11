# Put the Flies in the Bag

A fast third-person spider game in Godot 4.6, built on three verbs.
Each level is a test chamber: take every fly and get to the bag as fast as you
can.

The spider moves the way the old spider did, at what was its sprint, but it
can't climb walls any more. What it has instead is silk, on three buttons, and
all three work at the same time:

| Input | Verb |
|-------|------|
| **Left mouse** | **Grapple**: a line to a web you point at (any web in plain sight, however far), and you're pulled along it in a straight line to the web's centre, wherever on it you aimed. **A web that has stuck: you land on it. A web still in flight: you ride it, all the way** to wherever it sticks: no jumping or walking off, and the grapple stays spent until it lands you. One that runs out of reach, hits slick metal or flies into a silk cutter stops dead and drops you. Press Space mid-pull to let go and drop where you are. **Only silk holds the grapple**: stuck webs, webs still in the air (the line follows them), and webs holding a caught fly. Your webs are your anchors. You get one grapple in the air, and it comes back when you land on the ground or on a web that has stuck. |
| **Right mouse** | **Silk**: hold to wind a ball of silk up over the spider's back, then let go to throw. This is cast exactly as before. What leaves the spider now is a whole web, flying face first for up to 22 m; the longer the wind-up, the bigger the web. Grapple onto it in flight and ride it. Throwing in the air holds you up for 0.4 s (once per time in the air). Where its middle meets something it sticks flat against that surface and becomes ground: you can walk on a web on a wall or a ceiling. |
| **E / middle mouse** | **Pullback**: your oldest web flies back to you (first thrown, first home), one web per press. It comes straight through walls, and what it was on feels the pull: a crate comes with it to your feet, a loose board is ripped away, a block on a rail slides to the other end of it. The web you're standing on is skipped, so two webs can leapfrog up a wall. A web reaching you in the air doesn't hold you up: you keep falling. |
| WASD / Space | move / jump |
| R | restart the level (instant) |
| Esc | pause: resume, restart, edit this level, menu |
| L | first / third person |

Holding silk doesn't block anything: you can grapple and pull back while the
ball is still winding.

**A web you've stood on is used up when you leave it**: jump off, walk off, grapple
away or drop, and it comes apart behind you with its silk back at once. Moving on
never runs your silk out, and E is for pulling things. Webs you never stood on
(holding a crate, a board, a fly, or set up for later) stay until you call them.
**Webs are springy**: a jump off one goes 30% harder than off the ground, about
1.7 m up off a floor web.

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
* **Silk cutters** (violet laser grids in a metal frame, laid out like a tile map in 1.5 m cells, so a field can have holes, notches and windows in it): any web that flies through one is cut (a ride stops dead there and drops you), and a grapple line won't cross one. They don't touch the spider, which walks straight through, and webs called home pass through them.
* **Flies** (low poly, dark grey, about 1.5 m long, with long pale wings; most glow yellow): hit one with a
  web and it's **caught**, held still in mid-air by your web, which stays one of
  your webs out. A caught fly is a **grapple point**: grapple to it, or ride a web
  into it, and you **take** it. You get your web and grapple back, and you hang
  **strung up** in a frame of silk for 2 s to aim the next throw (Space drops you
  early). Or call the web home and the fly comes with it. Each fly is a
  one-use stepping stone, and taking every fly is how you open the bag, so a level
  with flies is a route to plan. Flies keep still, fly back and forth along a
  line, or orbit, all on the level's clock: the same fly is in the same place at
  the same time on every try.
* **Hazards** (red) and falling out of the level both restart you.
* **The exit**: a silk bag in a ring. It stays shut (red) until every fly in the
  level is taken; the count is under the clock. Walk in to finish. Your score is
  the time, which starts when you first move, and the menu keeps your best.

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
9. **Fly Paper**: a void walled and roofed in slick metal, with nothing to hold silk but the flies hanging over it. Hop from fly to fly, call home the one out of reach, then rip the boards off the hut.
10. **Clockwork Flies**: the same hall, with a fly going back and forth, one orbiting and one bobbing up and down. Lead your throws.
11. **The Larder**: a whole level. The bag is sealed in a vault in the middle of an atrium, its door on a plate that wants a crate, with three wings off it and a fly in each. The long way goes room by room: boards off the Gallery, through its laser curtain for the fly and a crate that opens the Pantry, the Well's fly, up the Pantry's shelf past a slick band for its fly and the crate, then the crate home onto the vault's plate. The quick way stays in the atrium: hang from the fly over the vault, climb a pillar, snipe the Pantry's crate and fly through a high window, ride to the other pillar and lead a throw over the Gallery's wall at its fly, then pull everything home through the walls.
12. **The Granary**: three big chambers in a row, each a chain of moves. **The Sieve**: a deep shaft floored three times with silk cutters, each with one hole under a metal hood, so the only line through is a shallow one from a fly bobbing under the floor. Catch it high, hang, thread a web through the hole onto the perch beyond in the two seconds you hang, and climb. A second fly on each floor wheels up through the lasers, your spare if you miss. **The Ferry**: ride a block on a rail to a laser curtain, jump through it and catch the fly beyond in mid-air (nothing past the curtain can be webbed from this side), drop onto the block under it and ride that one on. **The Safe**: the vault's crate sits in a strongbox behind cutters with one hole high up; catch a fly wheeling over the room where the line through the hole runs, hang, web the crate, and call it home onto the plate.

## The level editor

**New level** on the menu, or **Edit** on any level, or *Edit this level* from the
pause menu. The first time it opens it shows every key; **F1** (or **Help**) brings
that back.

**Getting round.** The **mouse wheel** zooms toward whatever is under the mouse.
**Middle drag** (or **Alt + left drag** on a laptop) orbits round the selection,
and with **Shift** it pans. **WASD** flies, **Q/E** go down and up (Shift is
faster), and holding the **right mouse** button looks round. **F** frames the
selection and **Home** shows the whole level. The level's ceiling hides while
you're above it, so you can see into its rooms.

**Building.** The palette on the left has ready-made **stone and slick blocks and
walls**, every **gameplay** piece by a name you'd use (Spider start, Exit bag,
Pressure plate, Rail block, Silk cutter…) with a tooltip saying what it does, and
the whole kit under **Kit pieces**, with a search box. Pick one and a see-through
copy follows the mouse, sitting on the floor or up against a wall under it, with
the grid drawn round it and its coordinates at the bottom. Click to put it down;
**R** turns it, **T** tips it, and **Esc** or a right click stops placing.

**Changing things.** Click a thing to select it.

* **Drag** it to slide it across the floor, or **Shift + drag** for up and down.
* Drag one of its **red, green or blue arrows** to move it along **x, y or z only**.
* Drag the **coloured squares** on its faces to stretch it from that face. The
  opposite face stays put.
* Drag the **yellow balls** to move a platform's stops, the **aqua ball** to set
  where a door opens to, and the **orange ball** to set where a rail block's rail
  ends.
* Everything snaps to the grid. Change the grid size in the top bar or with **[ ]**.
  The arrow keys and PgUp/PgDn nudge by one grid step.
* **Ctrl+D** copies, **Delete** deletes, **Ctrl+Z** undoes and **Ctrl+Y** redoes
  (there are buttons for these too).

The panel on the right shows everything about the selected thing in plain words:
its position, turn and size (x, y and z in the arrows' colours), its surface
(*stone: silk sticks* or *slick: silk slides off*), and its **link**. A link is a
named wire between plates and the doors and platforms they work. Pick one from the
list or make a new one; everything on the same link is joined by a coloured line
in the level. A silk cutter's lasers are **painted** on a grid of its cells: click
or drag across cells to switch them between lasers and open space. A fly's panel
sets how it moves (still, back and forth with an orange ball for its far end, or
an orbit), how long a trip takes, where in a trip it starts, and its glow. Flies
are put down 2 m up, and the line they fly is drawn in the level.

With nothing selected, the right panel holds the level's own settings (name, webs
out at once, par time, fall height, ceiling) and a **Checks** list of anything that
looks wrong, such as a door with no plate, a plate that works nothing, more plates
than crates, or no exit. Click one to jump to it. **Ctrl+S** saves, **▶ Play** (F5)
plays the level, and Esc in play comes back. The title shows *unsaved* while there
are changes, and New, Open and Menu ask before throwing them away.

Levels are plain JSON in `levels/`. When the project folder can't be written to,
they're saved in `user://levels/` instead. The format is documented at the top of
`flies/level/level_data.gd`.

## Where things are

```
flies/
  main.tscn, game_root.gd   the menu, play and the editor, one at a time
  player/    the spider (weaver.gd: walking, jumping, the web it's on, the pull,
             the throw-stall, strung up on flies), and one node per verb: grapple, silk_caster,
             pullback. The camera rig, the
             skeleton, the minimal mesh and the eight-legged gait come from the
             earlier game unchanged
  web/       the thrown web, and the silk geometry it's drawn with
  rig/       the mesh-building kit the spider's body is made with
  level/     the level format, the builder, the run (clock, channels, exit), the
             surfaces, the kit loader, and crates, plates, doors, platforms,
             loose boards, blocks on rails, hazards and the exit bag
  editor/    the level editor, its drag handles and its laser painter
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
silk alone, and that the editor works (`-- editor` runs just those). It
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
