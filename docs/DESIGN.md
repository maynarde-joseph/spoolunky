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
they go, and the grapple reaches 16 m.

* **A web that has stuck: you land on it.** From there, walk on: up a web on a
  wall and over its top onto the ledge, off a web on a floor onto the floor.
  Landing gives the grapple back.
* **A web still in flight: you drop where you meet it.** The pull takes you to
  the web and lets go there; you fall straight down with none of the pull's
  speed, and the web flies on. A web in flight is a point in the air to get to,
  not a ride. Meeting one gives the grapple back once, and not again until you
  next land, which is exactly enough to catch that same web where it sticks:
  throw, grapple, drop, grapple. The pull is faster than the web, so it meets
  it about three times as far out as it was when the line went. When you fire
  decides where you drop.
* **Space mid-pull** lets go of the line, and you drop where you are.
* **Why.** Throw-and-grapple was point and click: anything you could see was a
  target, and every pull delivered you safely onto the web. A hold-to-land
  button, momentum launches, a timed jump boost and a short ride into a launch
  were all tried. Splitting it by the web is what stuck: a stuck web is
  somewhere to stand, a flying web is a place in the air to drop from.
* **Only silk holds it.** A stuck web, or a web still in the air, which the line
  follows until the spider reaches it. Stone, slick metal, crates and platforms
  give it nothing. Silk makes the anchors, the grapple spends them, and the
  Pullback brings them back to make again, so none of the three verbs works
  without the others. Where a web can stick (stone, not slick) is where an
  anchor can exist, which is the level designer's main lever.
* **One in the air.** It's spent the moment it goes, and it comes back the
  moment you land on the ground or on a web that has stuck, or once when you
  meet a web in flight. You can't chain throw → grapple → throw → grapple
  forever. On the ground it is effectively always there.

### Silk (right mouse)

Casting is unchanged from the earlier game: hold to wind a ball of silk up over
the spider's back while the view lifts and widens, then let go to throw. A tap
throws a 1 m web and a full second's wind-up throws a 2.4 m web.

What leaves the spider is a whole web, flying face first at 22 m/s for up to
22 m. That's further than the grapple's 16 m, which is what catching a
web in flight is for, but short enough that a level has to put anchors within
reach rather than anywhere in sight:

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
stop at the end of reach, were tried to rein it in. Then launches off flying
webs, with and without a short ride first. Now meeting a flying web just drops
you there, and the ceiling over every level keeps the room's top in the room.

### Pullback (E / middle mouse)

First thrown, first home: each press calls your oldest web (within 60 m), and it
flies home at 44 m/s, through walls. Press again for the next.

* **It comes to you,** not to where it was thrown from. Where you stand when you
  call aims the recall, and it's how a crate gets onto a plate (stand on the
  plate). Calling
  webs back to their throw points would turn both into "throw from the right
  spot", which is a weaker puzzle and harder to read.
* **It brings what it held.** A web on a crate brings the crate and drops it at
  your feet. This is the only way to move a crate.
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

## How the levels use them

Each level has a single lesson and then a twist on it.

1. **First Thread**: jumping, throwing a web across a gap and grappling to it,
   webbing up a ledge, and a last jump onto slick, where silk can't help.
2. **Silk Stairs**: you can't climb, but you can climb webs. The wall's top band is
   slick, so the last web has to reach over it. With two webs, the Pullback has
   to leapfrog them.
3. **Ride the Gap**: the 18 m gap is too far to grapple and short enough for
   silk to cross, so you grapple to a web in flight, drop out over the gap, and
   catch the same web again where it sticks to the far side.
4. **Call It Back**: a crate sits on a post in the red, behind a wall. Web it
   from the pulpit, then stand on the plate and call it home through the wall
   to open the door.
5. **Moving Parts**: a ferry, then a crate that starts a lift.
6. **All Together**: cross the drop on a web caught twice, leapfrog a tower, and use a crate to
   open the exit.

Every built-in level is played to the end by a scripted route in
`tests/flies/levels_smoke_test.gd`, through the same calls the keys make. Those
routes are the intended solutions written down, and the level can't be broken
without CI noticing. They are not the only solutions, nor the fastest.

## Numbers

| | |
|---|---|
| spider | 0.7 m tall, moves 6.08 m/s (7.36 on a web: the old spider's sprint), jumps 7.8 m/s (about 1 m up, about 3.5 m across at a run), falls at 29.4 m/s² |
| grapple | webs only, 16 m reach, 18.2 m/s or 1.1 s, one in the air; lands on a stuck web, drops you where it meets a flying one |
| silk | 1 to 2.4 m webs, 22 m/s, 22 m reach, 0.2 s between throws |
| pullback | oldest web first, 60 m reach, 44 m/s home, 0.15 s between calls |
| catch-stall | 0.6 s held up, 15% of your speed kept |

All of these are constants at the top of their scripts in `flies/player/` and
`flies/web/`.
