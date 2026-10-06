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

A line to a web you point at, and you're pulled along it onto the web. Pulls are
capped at 0.6 seconds however far they go, and the grapple reaches 24 m.

* **Only silk holds it.** A stuck web, or a web still in the air, which the
  line follows until the spider lands on it. Stone, slick metal, crates and
  platforms give it nothing. Silk makes the anchors, the grapple spends them,
  and the Pullback brings them back to make again, so none of the three verbs
  works without the others. Where a web can stick (stone, not slick) is where
  an anchor can exist, which is the level designer's main lever.
* **One in the air.** It's spent the moment it goes, and it comes back the
  moment you land on the ground or on a web that has stuck. A web still in
  flight gives it back once, and not again until you next land. Grappling
  elsewhere from a ridden web still works, but you can't chain
  throw → grapple on → throw → grapple on forever. On the ground it is
  effectively always there.
* **It always ends on the web.** From there, walk on: up a web on a wall and
  over its top onto the ledge, off a web on a floor onto the floor.
* **Jump mid-pull** lets go, and you fly on with the pull's speed plus a little
  lift.

### Silk (right mouse)

Casting is unchanged from the earlier game: hold to wind a ball of silk up over
the spider's back while the view lifts and widens, then let go to throw. A tap
throws a 1 m web and a full second's wind-up throws a 2.4 m web.

What leaves the spider is a whole web, flying face first at 22 m/s for up to
36 m:

* **Ride it, and commit to it.** Grapple onto it in flight and you're standing
  on it, carried along. Jumping off a web in flight is only a small hop, with
  none of its speed. A ride is a way to wherever the web lands, not a sling.
* **It sticks where its middle lands,** lying flat against the surface, and it
  becomes ground. The spider walks on it at any angle: up a wall, across a
  ceiling. Walking off its rim onto a floor, onto the top of a wall, or onto
  another web carries on; otherwise the rim holds you.
* **It takes flies.** Any fly the disc passes over is wrapped and goes on the
  line behind the spider. A bigger web is a bigger net. Flies are the only thing
  a thrown web takes, and only while it flies.
* **Slick metal** doesn't take it. The web slides off and comes apart, and the
  silk is yours again at once.
* **Moving things** carry it: a web on a platform or a door goes where they go.
  A web on a crate holds the crate.
* **Thrown at nothing,** it comes apart at the end of its reach. If you're
  riding it, it stops dead first and you drop where it stopped, with none of
  its speed. A shot into the open sky only carries you in a straight line,
  and you stall at the end of it.

A level sets how many webs you can have out at once, two by default. That limit
is what makes the Pullback part of the loop.

**Why the riding rules.** Throwing a web and grappling onto it turned out to be the
strongest move in the game: a shot at the sky bought huge airtime and a fall onto
any safe ground, which flattened rooms built around getting somewhere. A
dragline that sprang the rider back to the throw point was tried and felt wrong.
The three rules above work together instead: one refund per landing, no
momentum off a flying web, and a dead stop at the end of reach.

### Pullback (E / middle mouse)

First thrown, first home: each press calls your oldest web (within 60 m), and it
flies home at 44 m/s, through walls. Press again for the next.

* **It comes to you,** not to where it was thrown from. Where you stand when you
  call aims the recall, which is the whole of the "call it back through a fly"
  puzzle, and it's how a crate gets onto a plate (stand on the plate). Calling
  webs back to their throw points would turn both into "throw from the right
  spot", which is a weaker puzzle and harder to read.
* **It takes what it passes.** Every fly along a web's way home is wrapped.
* **It brings what it held.** A web on a crate brings the crate and drops it at
  your feet. This is the only way to move a crate.
* **The web underfoot is skipped.** Standing (or riding) on a web, a call takes
  the oldest of the others. This is how two webs climb a wall that one can't:
  stand on the higher one, call the lower one home, and throw it higher.
* Its silk counts as yours the moment it's called.
* **It catches you if you're in the air.** Ride a web, jump off, call it, and
  when it reaches you it wraps you for a moment: an air-stall of about 0.3 s, no
  falling, your speed mostly gone. It gives you a beat to aim the next throw,
  and no extra height, so it can't be chained into flight. It has still done
  its work on the way: the flies it passed are on your line, and a crate it
  carried is put down beside you. On the ground a web coming home just arrives.

## Surfaces and things

| Thing | Rule |
|-------|------|
| Stone (pale, 2 m panels) | webs stick, so anchors can go there. Walkable as floor |
| Slick (dark striped metal) | webs slide off: no anchors. Still walkable as floor |
| Fly | hovers or flies a path. Taken only by a flying web or a returning one. A burst of speed when caught |
| Crate | webs stick to it. Only the Pullback moves it. Heavy enough for a plate |
| Plate | powers its channel while a crate is on it. A spider is too light |
| Door | slides open by a set offset while its channel is powered |
| Platform | follows its path back and forth or round. Runs only while its channel (if any) is powered |
| Hazard (red) | touch it and the level restarts |
| Exit bag | open from the start unless the level asks for flies first. Walk in to finish |

## Flies

Catching flies on its own felt like a chore, so flies now feed movement: **each
fly you catch is a burst of speed** (+5 m/s in the direction you're moving, up to
16 m/s). In the air nothing bleeds it away, so a fly caught mid-jump carries the
jump further. On the ground it wears off like a skid. When you catch one is
part of the route. A burst earned while you're on a web or a line waits up to
1.5 s for you to be off it.

A stored air jump (eat a fly for a double jump) was tried and dropped. Speed on
pickup rewards catching flies *in* the route rather than stockpiling them.

The bag counts every fly you caught this run. A level's score is its time and
its fly count, and the two records are kept separately, because the fastest
route rarely catches everything.

In First Thread, the last pad is slick and 8 m out: too far for a running jump
(about 6.5 m), with nothing for a web to stick to. A fly hangs just past the
edge; catch it as you jump and the burst carries you across.

## Webs have two faces

Walk off a web's rim and you crawl round onto its other face, wherever there's
room: a web overhanging an edge or spanning a gap has two sides to walk on. A
web flat against a wall or floor only has one, and its rim holds you. Keep the
key held and you carry on round; let go to take the keys back to the new face.

## How the levels use them

Each level has a single lesson and then a twist on it.

1. **First Thread**: jumping, throwing a web across a gap and grappling to it,
   webbing up a ledge, catching flies, and catching one mid-jump so its burst
   clears a slick gap.
2. **Silk Stairs**: you can't climb, but you can climb webs. The wall's top band is
   slick, so the last web has to reach over it. With two webs, the Pullback has
   to leapfrog them.
3. **Ride the Gap**: the gap is too far to grapple and short enough for silk to
   cross, so you ride. The flies are on the ride's path.
4. **Call It Back**: the flies are behind a wall, over a floor you can't touch.
   Throw past them, then stand where the way home runs through them. Then a
   crate goes onto a plate to open the door.
5. **Moving Parts**: a ferry, then a crate that starts a lift.
6. **Put the Flies in the Bag**: ride, leapfrog a tower, call a fly out of a slick
   box through its wall, and use a crate to open the bag.

Every built-in level is played to the end by a scripted route in
`tests/flies/levels_smoke_test.gd`, through the same calls the keys make. Those
routes are the intended solutions written down, and the level can't be broken
without CI noticing. They are not the only solutions, nor the fastest.

## Numbers

| | |
|---|---|
| spider | 0.7 m tall, runs 9 m/s, jumps 1.5 m, falls at 24 m/s² |
| grapple | webs only, 24 m reach, 34 m/s or 0.6 s, one in the air |
| silk | 1 to 2.4 m webs, 22 m/s, 36 m reach, 0.2 s between throws |
| pullback | oldest web first, 60 m reach, 44 m/s home, 0.15 s between calls |
| fly | 0.32 m hit radius, +5 m/s burst on catch (16 m/s at most), drawn about five times life size |
| catch-stall | 0.3 s held up, 15% of your speed kept |

All of these are constants at the top of their scripts in `flies/player/` and
`flies/web/`.
