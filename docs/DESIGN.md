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

A line to a web you point at, and you're pulled along it in a straight line to
the web's centre, wherever on it you aimed: where a pull ends is never a matter
of a few pixels. It's
a grapple, not a swing. Pulls go at 18.2 m/s, capped at 1.1 seconds however far
they go, and the grapple reaches as far as you can see: any web in plain sight
is somewhere to go. Line of sight is the only limit, so where a web can be put
(silk only goes 22 m from where it's thrown) is the puzzle, Portal-style: set a
web up from one place, use it from another.

* **A web that has stuck: you land on it.** From there, walk on: up a web on a
  wall and over its top onto the ledge, off a web on a floor onto the floor.
  Landing gives the grapple back.
* **A web still in flight: you ride it, all the way.** You land on it and it
  carries you until it sticks, and then you're standing on it wherever it
  landed. A ride is a commitment: there's no jumping off and no walking off its
  rim, and getting on gives nothing back, so the grapple stays spent until the
  web lands you. A web that reaches the end of its reach, slides off slick
  metal or flies into a silk cutter stops dead under you, and you drop where it
  stopped. That makes a ride one-dimensional on purpose: it ends at a handful of
  predictable points, not anywhere along a 22 m line, which keeps it fun and
  keeps open spaces designable.
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
  moment you land on the ground or on a web that has stuck. A ride doesn't give
  it back until it lands you. On the ground it is effectively always there.

### Silk (right mouse)

Casting is unchanged from the earlier game: hold to wind a ball of silk up over
the spider's back while the view lifts and widens, then let go to throw. A tap
throws a 1 m web and a full second's wind-up throws a 2.4 m web.

**Throwing in the air holds you up** for 0.4 s, your speed mostly gone: a beat to
see where the web goes and grapple onto it. Once per time in the air, like the
Pullback's catch, so throw, call home, throw, call home can't be used to hover.

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
replaced riding for a while. Riding came back, first with one grapple refund per
landing and a hop off, then committed: no refund, no getting off. Silk cutters
were added so levels can say where rides and throws can't go without walling
everything in.

### Used webs, and springy ones

**A web you've stood on is used up when you leave it,** however you leave: a
jump, a step off its rim, a grapple to the next one, a drop. It comes apart
behind you and its silk is back at once. That keeps the flow going: a climb or a
crossing is throw, grapple, throw, grapple, with no stop to call webs home, and
the Pullback is left to do what only it does, pulling things. Webs you never stood
on are untouched: one holding a crate, a board or a fly, and one set up to use
later. A web you rode onto a loose board and fell off stays too, since that's the
one that rips the board away. Like a fly, a web is a one-use stepping stone once
you use it.

**Webs are springy.** A jump off one goes 1.3 times as hard as a jump off the
ground: about 1.7 m up off a web on a floor, and a harder push away from one on a
wall. It's the web's last push as it lets go. The silk-alone check knows: from a
web it reaches any floor within 6 m across and 1.7 m up that's in sight.

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
* **Mostly for things, not silk.** Webs you stand on come back on their own when
  you leave them, so a call is for the ones you haven't: a web on a crate, a
  board, a rail block or a fly, or a setup you no longer want.
* **It doesn't catch you.** A web reaching you in the air just arrives, and you
  keep falling. (It used to hold you up for a second; that slowed the game down
  for no decision.) A crate it carried is still put down beside you.

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
| Silk cutter (violet laser grid in a metal frame, laid out like a tile map: a mask of 1.5 m cells says which hold lasers, the beams run on one lattice across them all, and the frame runs only where lasers meet open space, so a hole reads as a window) | cuts any web that flies through it (a ride stops dead there and drops you) and any grapple line across it. Harmless to the spider, which walks through; Pullback webs come home through it |
| Loose board (weathered wood) | silk sticks, but it won't hold the spider. The Pullback rips it away |
| Block on a rail (orange trim and arrows) | stone. The Pullback slides it the way its arrows point, to the other end of its rail; then the arrows turn round |
| Fly (low poly: faceted dark grey body, thin black legs, long pale wings; a yellow glow you can switch off per fly) | caught by a web that flies into it, then held still in mid-air: a grapple point, and one of your webs out. Grapple to it or ride into it and you take it, get your web and grapple back, and hang strung up for 2 s (Space drops you). Called home, the web brings it to you. Still, back and forth, or orbiting, on the level's clock |
| Exit bag | shut until every fly in the level is taken (open at once in a level with none). Walk in to finish |
| Ceiling | a slick lid over every level, set by its `ceiling` height or 6 m over the top of everything. Thrown silk slides off it |

## Flies: the goal, and the stepping stones

Flies were in the game once before as a second thing to do on the way: first a
chore, then a burst of speed, then banked jumps and grapple anchors with a Shift
lock-on. None of it made a player think about them while going through a level,
so they came out. They're back with one job each way:

* **They're the goal.** The bag opens once every fly in the level is taken, the
  way every demon has to die in *Neon White*. So where the flies are says where
  you have to go.
* **They're anchors where silk has none.** Hit a fly with a web and it's caught,
  held still in mid-air by that web. A caught fly is a grapple point in empty
  space, over a void or under a slick ceiling, where nothing else holds silk.
* **Using one takes it.** Reach it (grapple to it, or ride a web into it) and the
  fly is yours, the web and grapple come back, and you hang strung up in a frame
  of silk for 2 s to aim the next throw; Space drops you early. Or call the web
  home and the fly comes to you, but you don't move. Each fly is a one-use
  stepping stone, so the order you take them in is the route, and the route is
  what a speedrun optimises.

This also brings back the payoff that committed rides lost when the grapple refund
went: a ride that ends in a fly gives the grapple back, but only where a level
puts one.

A caught fly holds one of your webs until you reach it or call it home, so a
level's web count matters more with flies in it. Flies keep still, go back and
forth along a line, or orbit about an axis, always on the level's clock, which
starts on your first move: the same fly is in the same place at the same time on
every try, so timing is something you learn. Flies don't attack.

They're drawn low poly like everything else: a faceted dark grey head, thorax
and tapering abdomen, six thin black legs bent under the body, and two long pale
see-through wings that lie back over the abdomen in a V. They're about 1.5 m long,
so they read from across a room, and face the way they fly. They have a skeleton
(see `flies/level/fly_body.gd`): the wings spread and beat and the legs hang and
twitch while a fly flies, and everything folds still once a web has it. Most glow
yellow, a soft haze behind them; a level can switch that off per fly.

## Webs have one face

You walk on the face of a web you landed on, and its rim holds you unless a floor
or another web is just past it. Crawling round the rim onto the other face was
tried and dropped: it caused more bugs than routes. Where a web is flat against a
wall or floor, the face you're put on is always the one with room, the side facing
the room, whichever side of the web you reached it from.

## Gates: what silk alone can't do

The grapple reaches anything in sight, and a ride drops you where its web stops
dead, so silk alone goes a long way within 22 m. A gap doesn't hold you back
for long, and neither does a wall that stops short of the ceiling. A level built
only of those is solved by web, grapple, ride, repeat.

So every level is built of rooms sealed by walls that meet the ceiling, and the
way from one room to the next is a **gate**: something solid, that blocks sight
as well as the way, and that only the other tools open.

* A **loose board** over a doorway: web it and call the web home.
* A **block on a rail** plugging a doorway: call it home and it slides to the
  other end of its rail, out of the way. On an upright rail it's a portcullis
  that slides up, or a plug that slides down out of a high doorway to become
  the step up into it.
* A **door** on a plate: bring a crate home onto the plate.

Inside a room, silk is free movement: webs, grapples and rides however you
like. The gates are the puzzles. **Silk cutters** shape that freedom without
walls: a cutter curtain with one window says "ride through here or not at all",
and cutters round a board say "walk in close before you throw".

`tests/flies/silk_reach.gd` checks it. It maps everywhere the spider can get to
in a level by walking, jumping, throwing webs (as many as it likes), grappling
to them and dropping from webs caught anywhere along a throw, and catching and
hanging from flies (any point a moving fly passes, every fly as often as it likes),
with every gate left shut, and it's generous to the spider throughout. If that reaches the exit,
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
4. **Cut Lines**: a void too wide for anything but a ride, and a silk cutter
   curtain across the hall with one window in it: find the line through. Then
   the boards on the way out are boxed in by cutters, so walk through them and
   throw from inside.
5. **Call It Back**: a crate sits on a post in the red, behind a wall. Web it
   from the pulpit, then stand on the plate and call it home through the wall
   to open the exit's door.
6. **Moving Parts**: a ferry, then a crate whose plate starts a lift and opens
   the door at the top.
7. **Pull the Room**: a doorway plugged by a block that slides off to the side
   when called, then a doorway high in the wall plugged by a block on an upright
   rail: called home, it slides down out of the doorway and becomes the step up
   into it.
8. **All Together**: a web across the drop, a tower on two leapfrogged webs,
   boards off a window to reach a crate, and the crate onto the plate that
   opens the way out.
9. **Fly Paper**: flies taught. A void walled and roofed in slick metal, too wide
   for any web or ride, with three flies hanging over it: hop from one to the
   next, strung up at each. A fourth hangs high off to the side over nothing:
   catch it and call it home. The far side is stone, so from the last fly a web
   gets you down; then rip the boards off the hut. Skipping a fly is allowed,
   and costs you calling it home later.
10. **Clockwork Flies**: the same hall, with a fly going back and forth, one
    orbiting and one bobbing. Lead the throws; the clock makes it the same every
    try.
11. **The Larder**: a whole level rather than a room, built so the way you'd find
    and the way you'd master are minutes apart. An atrium with the bag in a sealed
    vault in the middle, its door on a plate, and three wings with a fly each:
    the Gallery (boarded up, a laser curtain, a fly patrolling behind it, and a
    crate whose plate opens the Pantry), the Well (a fly circling down a pit) and
    the Pantry (a shelf with a slick band across its face, a fly circling over it
    and the crate for the vault). The long way visits every room in turn, and the
    Pantry's door only opens from the far end of the Gallery. The quick way never
    leaves the atrium: ride into the fly over the vault and hang there, climb a
    pillar from the hang, snipe the Pantry's crate and fly through a high window,
    ride to the other pillar and lead a throw over the Gallery's wall (it stops
    short of the ceiling) at its fly, then stand by the plate and call everything
    home through the walls; the crate lands on the plate. Then the Well's fly from
    its rim. Both are scripted in CI: the long way runs about 50 s and the quick
    way about 35 s at a script's perfect aim; by hand, figuring it out, the long
    way is minutes.

Every built-in level is played to the end by a scripted route in
`tests/flies/levels_smoke_test.gd`, through the same calls the keys make. Those
routes are the intended solutions written down, and the level can't be broken
without CI noticing. They are not the only solutions, nor the fastest.

## Numbers

| | |
|---|---|
| spider | 0.7 m tall, moves 6.08 m/s (7.36 on a web: the old spider's sprint), jumps 7.8 m/s (about 1 m up, about 3.5 m across at a run; 1.3 times that off a web), falls at 29.4 m/s² |
| grapple | webs only, as far as you can see, 18.2 m/s or 1.1 s, one in the air; always to the web's centre; lands on a stuck web, rides a flying one (no refund, no getting off) |
| silk | 1 to 2.4 m webs, 22 m/s, 22 m reach, 0.2 s between throws |
| pullback | oldest web first, 60 m reach, 44 m/s home, 0.15 s between calls |
| throw-stall | 0.4 s held up when you throw in the air, 15% of your speed kept; once per time in the air |
| fly | 0.45 m body radius, caught by a web passing within 0.9 m plus half the web's radius; strung up 2 s |

All of these are constants at the top of their scripts in `flies/player/` and
`flies/web/`.
