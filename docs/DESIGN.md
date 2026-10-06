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

A line to where you point, and you're pulled along it fast. Pulls are capped at
0.6 seconds however far they go, and the grapple reaches 24 m.

* **Holds on** stone, crates, platforms, doors, and webs, including a web still in
  the air. The line follows a moving web until the spider lands on it.
* **Won't hold on** slick metal. The line flickers red and you stay put.
* **One in the air.** It's spent the moment it goes, and it comes back the
  moment you land on the ground or on a web. On the ground it is effectively
  always there.
* **Where it ends**: on a floor you land running, keeping the pull's speed
  along it. On a wall just under a ledge (within 1.4 m of the lip) you go over
  the lip. On any other wall you cling for a moment, and jump kicks you off the
  wall. Under a ceiling you drop.
* **Jump mid-pull** lets go, and you fly on with the pull's speed plus a little
  lift.

### Silk (right mouse)

Casting is unchanged from the earlier game: hold to wind a ball of silk up over
the spider's back while the view lifts and widens, then let go to throw. A tap
throws a 1 m web and a full second's wind-up throws a 2.4 m web.

What leaves the spider is a whole web, flying face first at 22 m/s for up to
36 m:

* **Ride it.** Grapple onto it in flight and you're standing on it, carried
  along. Landing on it gives the grapple back. Jumping off keeps its speed.
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
  riding it, you fall with its speed.

A level sets how many webs you can have out at once, usually two. That limit is
what makes the Pullback part of the loop.

### Pullback (E / middle mouse)

Every web in reach (60 m) flies home at 44 m/s, through walls.

* **It takes what it passes.** Every fly along a web's way home is wrapped. Each
  web comes straight back to where you are standing, so where you stand when you
  call aims the recall. A faint line from each web to the spider shows the path.
* **It brings what it held.** A web on a crate brings the crate and drops it at
  your feet. This is the only way to move a crate.
* **The web underfoot stays.** Standing (or riding) on a web, you call home all
  the others. This is how two webs climb a wall that one can't: stand on the
  higher one, call the lower one home, and throw it higher.
* Its silk counts as yours the moment it's called.

## Surfaces and things

| Thing | Rule |
|-------|------|
| Stone (pale, 2 m panels) | webs stick, grapples hold, walkable as floor |
| Slick (dark striped metal) | webs slide off, grapples slip, still walkable as floor |
| Fly | hovers or flies a path. Taken only by a flying web or a returning one |
| Crate | webs stick to it. Only the Pullback moves it. Heavy enough for a plate |
| Plate | powers its channel while a crate is on it. A spider is too light |
| Door | slides open by a set offset while its channel is powered |
| Platform | follows its path back and forth or round. Runs only while its channel (if any) is powered |
| Hazard (red) | touch it and the level restarts |
| Exit bag | red ring while shut, gold once the level's flies are caught. Walk in to finish |

## How the levels use them

Each level has a single lesson and then a twist on it.

1. **First Thread**: jumping, grappling across a gap, grappling over a lip, and
   catching flies with silk.
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
without CI noticing. Faster routes exist on purpose. For example, grapple high
on a wall, then in the moment you cling there, throw a web where you are and
take hold of it.

## Numbers

| | |
|---|---|
| spider | 0.7 m tall, runs 9 m/s, jumps 1.5 m, falls at 24 m/s² |
| grapple | 24 m reach, 34 m/s or 0.6 s, one in the air |
| silk | 1 to 2.4 m webs, 22 m/s, 36 m reach, 0.2 s between throws |
| pullback | 60 m reach, 44 m/s home, 0.35 s between calls |
| fly | 0.32 m hit radius, drawn about five times life size |

All of these are constants at the top of their scripts in `flies/player/` and
`flies/web/`.
