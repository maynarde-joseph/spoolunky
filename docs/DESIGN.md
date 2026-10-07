# Design notes

## The idea

The game is a test-chamber puzzle game played at a run. *Portal* supplies the
chambers: each one is a small, readable space with a goal, a short list of
surfaces, and a solution that uses every tool you have in a way the room
suggests. *Neon White* and *Ghostrunner* supply the pace: a clock, instant
restarts, momentum carried from one move into the next, and levels short enough
to replay for time.

The spider can't climb. That rule makes silk into terrain. Walls are what you
can't get past until you put a web on them.

## The three verbs

All three are on their own buttons, and none of them waits on another.

### Grapple (left mouse)

A line to a web you point at, and you're pulled along it in a straight line. It's
a grapple, not a swing. Pulls go at 18.2 m/s, capped at 1.1 seconds however far
they go, and the grapple reaches as far as you can see: any web in plain sight
is somewhere to go. Line of sight is the only limit, so where a web can be put
(silk only goes 22 m from where it's thrown) is the puzzle, Portal-style: set a
web up from one place, use it from another.

* **A web that has stuck: you land on it.** From there, walk on: up a web on a
  wall and over its top onto the ledge, off a web on a floor onto the floor.
  Landing gives the grapple back.
* **A web still in flight: you ride it.** You land on it and it carries you,
  until it sticks, and then you're standing on it wherever it landed. A ride
  is a commitment: jumping off a web in flight is only a hop with none of its
  speed, and a web that reaches the end of its reach, or slides off slick
  metal, stops dead under you and you drop where it stopped. Getting onto one
  gives the grapple back once, and not again until you next land.
* **Space mid-pull** lets go of the line, and you drop where you are.
* **Why riding.** A hold-to-land button, momentum launches off flying webs, a
  timed jump boost, a short ride into a launch and a drop where you meet the
  web were all tried. They were finicky: where you ended up depended on a chase
  you couldn't see. Riding is consistent: you go where the web goes.
* **Only silk holds it.** A stuck web, or a web still in the air, which the line
  follows until the spider lands on it. Stone, slick metal, crates and platforms
  give it nothing. Silk makes the anchors, the grapple spends them, and the
  Pullback brings them back to make again, so none of the three verbs works
  without the others. Where a web can stick (stone, not slick) is where an
  anchor can exist, which is the level designer's main lever.
* **One in the air.** It's spent the moment it goes, and it comes back the
  moment you land on the ground or on a web that has stuck, or once when you
  get onto a web in flight. You can't chain throw → ride → throw → ride
  forever. On the ground it is effectively always there.

### Silk (right mouse)

Casting is unchanged from the earlier game: hold to wind a ball of silk up over
the spider's back while the view lifts and widens, then let go to throw. A tap
throws a 1 m web and a full second's wind-up throws a 2.4 m web.

What leaves the spider is a whole web, flying face first at 22 m/s for up to
22 m, short enough that where you can throw from decides where an anchor can
go:

* **It sticks where its middle lands,** lying flat against the surface, and it
  becomes ground. The spider walks on it at any angle: up a wall, across a
  ceiling. Walking off its rim onto a floor, onto the top of a wall, or onto
  another web carries on; otherwise the rim holds you.
* **Slick metal** doesn't take it. The web slides off and comes apart, and the
  silk is yours again at once.
* **Moving things** carry it: a web on a platform or a door goes where they go.
  A web on a crate holds the crate.
* **Thrown at nothing,** it comes apart at the end of its reach.

A level sets how many webs you can have out at once, two by default. That limit
is what makes the Pullback part of the loop.

**History.** Grappling onto a web in flight used to put you on it, riding it to
wherever it stuck. A shot at the sky bought huge airtime, which flattened rooms
built around getting somewhere; a dragline back to the throw point, then a dead
stop at the end of reach, were tried to rein it in. Then launches and drops
replaced riding for a while; riding came back, with one refund per landing, a
hop with none of its speed when you jump off, and a dead stop at the end of
reach. The ceiling over every level keeps the room's top in the room.

### Pullback (E / middle mouse)

First thrown, first home: each press calls your oldest web (within 60 m), and it
flies home at 44 m/s, through walls. Press again for the next.

The grapple moves you; the Pullback moves the level. Whatever a web is on feels
the pull when it's called:

* **It comes to you,** not to where it was thrown from. Where you stand when you
  call aims the recall, and it's how a crate gets onto a plate (stand on the
  plate). Calling
  webs back to their throw points would turn both into "throw from the right
  spot", which is a weaker puzzle and harder to read.
* **It brings what it held.** A web on a crate brings the crate and drops it at
  your feet. This is the only way to move a crate.
* **It rips off loose boards.** Silk sticks to a loose board, but a board won't
  take your weight: no grapple to a web on one, no walking onto it. Call that web
  home and the board tears away and tumbles off, leaving what it covered: stone
  to web, a way through, a line of sight. Any other silk on the board goes with
  it.
* **It slides blocks along rails.** A stone block with orange trim sits on a
  rail. Call a web on it home and it slides to the other end of its rail; call
  one home again and it slides back. Where you stand doesn't matter. Orange
  arrows on its sides point the way it will go next, and turn round when it
  gets there. (Outlining both ends of the rail was tried first; arrows on the
  block read better.) Rails run any way, up and down too, and
  blocks don't fall: only the Pullback moves them. (Dragging a block to the
  point nearest where you stood was tried first; a block that just goes to the
  other end reads better.)
* **The web underfoot is skipped.** Standing on a web, a call takes
  the oldest of the others. This is how two webs climb a wall that one can't:
  stand on the higher one, call the lower one home, and throw it higher.
* Its silk counts as yours the moment it's called.
* **It catches you if you're in the air.** Drop off a web in flight, call it, and
  when it reaches you it wraps you for a moment: an air-stall of about 0.6 s, no
  falling, your speed mostly gone. It gives you a beat to aim the next throw,
  and no extra height, so it can't be chained into flight. A crate it carried
  is still put down beside you. On the ground a web coming home just arrives.

## Surfaces and things

| Thing | Rule |
|-------|------|
| Stone (pale, 2 m panels) | webs stick, so anchors can go there. Walkable as floor |
| Slick (dark striped metal) | webs slide off: no anchors. Still walkable as floor |
| Crate | webs stick to it. Only the Pullback moves it. Heavy enough for a plate |
| Plate | powers its channel while a crate is on it. A spider is too light |
| Door | slides open by a set offset while its channel is powered |
| Platform | follows its path back and forth or round. Runs only while its channel (if any) is powered |
| Hazard (red) | touch it and the level restarts |
| Loose board (weathered wood) | silk sticks, but it won't hold the spider. The Pullback rips it away |
| Block on a rail (orange trim and arrows) | stone. The Pullback slides it the way its arrows point, to the other end of its rail; then the arrows turn round |
| Exit bag | open from the start. Walk in to finish |
| Ceiling | a slick lid over every level, set by its `ceiling` height or 6 m over the top of everything. Thrown silk slides off it |

## Flies, for now out

Flies were in the game as a second thing to do on the way: first a chore, then a
burst of speed, then banked jumps and grapple anchors with a Shift lock-on. None
of it made a player think about them while going through a level: the web was
the game. So they're out for now, and the levels are about the web alone. The
time is the only score. If they come back, the likeliest shape is as the goal (the
exit opens once every fly is caught, the way every demon has to die in *Neon
White*), with each fly placed where one verb reaches it.

## Webs have one face

You walk on the face of a web you landed on, and its rim holds you unless a floor
or another web is just past it. Crawling round the rim onto the other face was
tried and dropped: it caused more bugs than routes. Where a web is flat against a
wall or floor, the face you're put on is always the one with room, the side facing
the room, whichever side of the web you reached it from.

## Gates: what silk alone can't do

The grapple reaches anything in sight, and a web you ride can drop you anywhere
along a throw (hop off, or let it stop dead), so silk alone goes almost anywhere within 22 m. A gap
doesn't hold you back, and neither does a wall that stops short of the ceiling:
you drop onto its top. A level built of those is solved by web, grapple, drop,
repeat.

So every level is built of rooms sealed by walls that meet the ceiling, and the
way from one room to the next is a **gate**: something solid, that blocks sight
as well as the way, and that only the other tools open.

* A **loose board** over a doorway: web it and call the web home.
* A **block on a rail** plugging a doorway: call it home and it slides to the
  other end of its rail, out of the way. On an upright rail it's a portcullis
  that slides up, or a plug that slides down out of a high doorway to become
  the step up into it.
* A **door** on a plate: bring a crate home onto the plate.

Inside a room, silk is free movement: webs, grapples and drops however you
like. The gates are the puzzles.

`tests/flies/silk_reach.gd` checks it. It maps everywhere the spider can get to
in a level by walking, jumping, throwing webs (as many as it likes), grappling
to them and dropping from webs caught anywhere along a throw, with every gate
left shut, and it's generous to the spider throughout. If that reaches the exit,
the level fails CI. With its gates taken out, every built-in level is reached,
so the check is doing the work.

## How the levels use them

1. **First Thread**: jump a gap, web a stone face and climb it, and rip the
   boards off the way out with the Pullback.
2. **Silk Stairs**: climb a stone wall on two leapfrogged webs, past its slick
   top band. Up top the way out is plugged by a block on an upright rail: web
   it and call it home, and it slides up out of the way.
3. **Drop In**: the exit is in a hut on a slick island out in the open. Throw a
   web out over it, ride it until it stops dead on the hut's slick wall and
   drops you, then rip the boards off the hut's door.
4. **Call It Back**: a crate sits on a post in the red, behind a wall. Web it
   from the pulpit, then stand on the plate and call it home through the wall
   to open the exit's door.
5. **Moving Parts**: a ferry, then a crate whose plate starts a lift and opens
   the door at the top.
6. **Pull the Room**: a doorway plugged by a block that slides off to the side
   when called, then a doorway high in the wall plugged by a block on an upright
   rail: called home, it slides down out of the doorway and becomes the step up
   into it.
7. **All Together**: a web across the drop, a tower on two leapfrogged webs,
   boards off a window to reach a crate, and the crate onto the plate that
   opens the way out.

Every built-in level is played to the end by a scripted route in
`tests/flies/levels_smoke_test.gd`, through the same calls the keys make. Those
routes are the intended solutions written down, and the level can't be broken
without CI noticing. They are not the only solutions, nor the fastest.

## Numbers

| | |
|---|---|
| spider | 0.7 m tall, moves 6.08 m/s (7.36 on a web: the old spider's sprint), jumps 7.8 m/s (about 1 m up, about 3.5 m across at a run), falls at 29.4 m/s² |
| grapple | webs only, as far as you can see, 18.2 m/s or 1.1 s, one in the air; lands on a stuck web, rides a flying one |
| silk | 1 to 2.4 m webs, 22 m/s, 22 m reach, 0.2 s between throws |
| pullback | oldest web first, 60 m reach, 44 m/s home, 0.15 s between calls |
| catch-stall | 0.6 s held up, 15% of your speed kept |

All of these are constants at the top of their scripts in `flies/player/` and
`flies/web/`.
