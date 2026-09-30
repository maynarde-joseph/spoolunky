# Spoolunky

A first-person spider game in Godot 4.6. You start the size of a coin in the
corner of a room, spin webs to catch whatever walks into them, and eat your way
up until the room can't hold you.

The full pitch — the loop, the size tiers, the zones, the trap catalogue — is in
[`docs/DESIGN.md`](docs/DESIGN.md).

## Where things are

```
game/
  data/      web patterns, devices, size tiers, creatures and their bodies (plain
             resources — edit the numbers)
  web/       procedural silk geometry and the webs themselves
  player/    the spider, one node per job: growth, climbing, the camera, the
             builder, the tether, the bag, the traits, eating and stamina, and
             the body you see — a skeleton and the gait that walks it
  prey/      things to catch, and something to spawn them
  rig/       bodies: bones, meshes skinned to them, and the motion that poses them
  ui/        HUD
tests/       four headless suites and screenshot tools
  support/   what the suites share: the verdict, and the arena a web check runs in
addons/character-controller/   the movement template the spider is built on
```

The sandbox is the character-controller example level
(`addons/character-controller/example/main/level.tscn`), which is the project's
main scene. It has the spider, a HUD, a `Webs` container and a prey spawner
dropped into it. A `Devices` container is made on demand the first time you put
something down.

## Controls

| Input | Action |
|-------|--------|
| WASD / Space | move and jump — **jump is also how you let go of silk** |
| **Shift** | **sprint** — it runs out, and it runs out faster the heavier the thing on your line |
| *walk into a wall* | climb it — walls and ceilings are floors to a spider |
| *stand on silk* | it holds you — a thread runs one way, and **jump** is how you come off |
| **F** or **middle mouse** | ride a silk line like a zipline — again to let go |
| **Ctrl** | drop onto a dragline (from a wall or ceiling) |
| **Ctrl** / **Space** | lower / raise yourself on the line |
| **Right Mouse** | let go of the line |
| **Left Mouse** | **go there, trailing silk** — moving and building are the same act |
| **Left Mouse** *on something you've caught* | put a line on it and drag it instead — same click, read the only way that makes sense |
| **Q** *(hold)* | spin a web where you're aiming — hold longer for a bigger one |
| **M** | webs: **placed** where you point / **thrown** as a bolt that opens where it lands |
| **Wheel** or **Z** / **C** | change which web you spin |
| **Right Mouse** | let go of a line |
| **E** | wrap caught prey, then drain it (also re-arms a sprung snare) |
| **Y** | **put a line on a bundle and drag it along** — again to drop what you're carrying |
| **X** | pull down the web you're looking at, for half the silk back — or pick a device back up |
| **G** | wire two things together — web or device, press on each end |
| **N** | open the bag — place a device (wheel to pick, left mouse to put down) |
| **J** | silk: unlimited / costs again (sandbox switch, starts unlimited) |
| **B** | keep the rig you're looking at as a design |
| **V** | place a saved design — wheel to pick, left mouse to spin it |
| **L** | camera: third person or first person |
| **O** | the spider's look: detailed, low poly or minimal |
| **K** | switch weave: stretched or inscribed |
| **;** | pick a tuning dial |
| **[** / **]** | turn that dial down / up |
| **'** | put the dials back to standard |
| **H** | toggle the help overlay |
| **R** | free-fly (from the movement template, handy for scouting) |
| **T** | release the mouse · **Esc** quit |

## Building a web

There is no build mode. **Left mouse grapples you to whatever you're pointing
at, and drags a line behind you** — so getting around and building are the same
act, and the silk ends up being a record of where you went.

To make a web, **aim where you want it and hold Q**, then let go.

Holding sets how far the web is *allowed* to reach — the room decides where it
actually stops. Every corner of the rim runs outward until it hits something,
so the same press gives you a full circle in open air and a web that fills the
angle when you point into a corner. A doorway gets something doorway-shaped
rather than a disc hanging in the middle of it.

The HUD shows the area you're about to cover and how many corners have found
something to hold onto.

**M** switches how the web gets there. *Placed* is the above: it appears under
the crosshair the moment you let go. *Thrown* sends a bolt of silk instead —
it flies, it drops a little on the way, and it opens out to the size you
charged it to wherever it lands. It can miss, and something moving has to be
led rather than pointed at, which is the whole point of having both. Nothing is
paid for until the silk arrives.

How big a web you can spin is what the size tiers gate — and what you can
currently pay for. The web stops growing when your silk runs out rather than
refusing at the end, so the ghost is always something you can actually buy.

**Range is unlimited** — if you can see it, you can grapple to it. The size
tiers gate what your silk can *hold* and how much you can spin, not where you
are allowed to go. A long grapple is flung faster so it still lands in about a
second, because distance should cost you silk rather than patience.

Every line is a road, and **silk is sticky**. Step onto a thread and you're
stuck to it — it keeps hold of you until you **jump off**, the same as the wall
and the ceiling do. A thread only runs one way, so that's the way you walk on
it: pushing across a line does nothing rather than walking you off the side of
it. You still set your own pace and face either way. A *web* is a floor and
gets none of that — walk about on it however you like.

**F** is the zipline, and it's the *only* way into one — nothing puts you on a
ride for landing near silk or for grappling somewhere a line happened to be.
Ask for it and you clip onto the line proper, gravity pulls you down the slope,
and letting go throws you off carrying the speed.

Silk is about half again quicker underfoot than the floor, and you can
**grapple straight onto a line** from a distance to get on it — that joins the
network rather than stringing another line to reach it. You arrive standing on
the line, stuck to it like any other silk; whether you then walk it or ride it
is yours. A route you built once is a route you can take.

Placing an anchor **grapples you to it**, dragging a frame line behind you. So
the frame of a web is the route you took around it, not an outline you drew from
across the room.

Frame lines are real silk that stands on its own, and they're ridable — walk a
triangle into a corner and you've built three ziplines whether or not you ever
weave anything into them. Once the run closes a loop, **F** weaves the enclosed
area in one go, charging only for the silk inside; the frame was paid for as you
dragged it. Pulling a web down later leaves the frame standing.

If the selected pattern is a strand (tripline, bridge), that's what gets dragged
instead of plain frame line, so you can lay a run of triplines the same way.

**Every strand is a zipline** — there's no opt-in. And weaving isn't limited to
a loop you just walked: all your silk is one graph, and lines count as joined
where they *cross in mid-air* as well as where they share an end. Sling three
lines across a shaft and the triangle where they overlap is a ring you can fill.
Look at any ring and press **F**.

## Riding your own silk

Any strand built from a ridable pattern — the silk bridge — can be clipped onto
with **F** or the middle mouse button, and ridden. Gravity does the work on a
downhill line, the movement keys push you along a level one, and letting go
throws you off carrying all the speed you built, plus a kick to clear the edge.
Arrive on a line already moving and you keep it.

The camera opens up as you go faster. Look direction is kept in world terms, so
the mouse means the same thing whatever surface the spider is stuck to, and the
horizon stays level even on a ceiling. **L** switches between third and first
person.

## Living on the web

Finished webs are solid enough to stand on — the spider sticks to one the same
way it sticks to a wall, and deals with caught prey from on top of the silk.

Silk surfaces are on their own collision layer so the spider collides with them
and prey doesn't. That matters: a web firm enough to hold a spider would
otherwise be firm enough to bounce a fly off. It also means a web laid flat on
the ground works as a floor trap with no special handling — things walk onto it
and stick, and you can walk over it.

## Climbing

The spider has no floor — it sticks to whatever it touches, and the body's up
axis becomes the surface normal. Walk into a wall to climb it, keep going to
end up on the ceiling. While you are already on a surface you only transfer to
a new one by pushing into it, so walking beside a wall doesn't throw you up it;
in mid-air the spider grabs the first thing it touches. Keep the key down across
an edge and it keeps meaning the way you were going — into a wall becomes up it,
up a wall becomes on across the ceiling — until you let go or swing the camera
well round. Put a collider in the
`no_climb` group to make it unclimbable.

The body you see is a skeleton posed in code, not a set of animations. Its feet
look for footholds on whatever is underfoot, stay put in the world once planted,
and step in two sets of four so four are always down. Falling, grappling, hanging,
riding, winding up a throw, feeding and being bitten each have a pose of their
own. `SpiderRig` builds the bones and mesh, `SpiderGait` moves them; the reasoning
is in `docs/DESIGN.md` §7, *The body*.

It comes in three looks on that one skeleton: **detailed** (banded legs, markings,
eight eyes), **low poly** (the same parts cut into flat faces) and **minimal** (two
blobs on eight thin legs). **O** switches between them in game; to start in a
different one, set `look` on the spider's `Body` node.

From a wall or ceiling, **Ctrl** drops you onto a dragline. It costs silk by
the metre (half back when you reel in), it's a real pendulum so you can swing
onto things, and right mouse lets go.

## Wiring traps together

**G** on one thing, then **G** on another, runs a signal line between them: when
the first goes off, the second reacts. A snare that gets a signal whips out and
drags in prey within about three times its radius — so a tripline across a
doorway can spring a snare on the far side of the room and catch something that
never touched the silk. Any other web tenses instead, holding roughly twice as
well for a few seconds. Signals chain, and the dashed cold-blue lines show you
your own machine.

Either end can be a **device** rather than a web — they sit on the same graph.

## Two things a web is for

**Throw one at something.** A web spun over a moth wraps it where it stood, the
silk goes with it, and the bundle drops to the floor for you to collect — so
you can deal with something in front of you rather than only setting up for
later. Nothing is left hanging on the wall: the web was the wrap.

Only if your silk is up to it, mind: a web takes something outright just when
it could have out-held the whole fight that thing would have put up. Throw a
sheet web at a wasp and you get a wasp hanging in a sheet web, fighting.

That goes for a bolt square on the creature too, which used to be a guaranteed
catch on anything. What a shot the silk is not up to does instead is **leave some
of the silk on it**: the readout shows how wrapped it is, it has that much less
fight in it, and a web that could never have held it can once it is wrapped
enough. So the two tools work together — soften it with shots, then take it with a
web — and the silk works off again if you leave it alone, so it is a burst of
commitment rather than a slow grind from safety.

**Take one home.** Point at a web you left somewhere and click: it comes down,
and what was in it lands at your feet as **bundles** — silk still on them, going
nowhere, yours to drain whenever. So a larder isn't somewhere you have to go and
stand in the open any more; you cash it in from where you are.

Everything in it comes, including anything still fighting. Taking the web is
taking the catch; a catch that squirmed off because it happened to be mid-struggle
would be a coin flip rather than a decision.

Silk you land also slows the thing down — the same silk that costs it fight costs
it legs. That matters more than it sounds: almost everything outruns you when it
bolts, so a creature you haven't softened is a creature you simply cannot chase.
Half-wrapped, a wasp is slow enough for even a spiderling to walk after.

A catch on the line comes **over** walls rather than being lost against them: a
line that's pulling and getting nowhere starts lifting too, and pays out so it
doesn't part while it works. You can haul a bundle home across broken ground
without having to think about the route.

Silk doesn't pile up for ever. Three grapple lines at a time, and six webs — but
the web rule only ever takes down an **empty** one, because a web you filled is
the thing you came back for.

It costs you the web, mind — the same bargain taking one catch out already makes,
paid for the whole shelf at once. Lines can't be taken down this way: a road is
the floor you walk on, so the click on one stays a grapple.

(This replaced dragging the web home on a rope. The rope was fiddly, and it made
the catch depend on the trip — walk it through a corner and half of it spilled.
What you actually wanted was the contents.)

**Shoot it.** A bolt that lands on a creature puts silk on it and does nothing
else — no web is left where it was standing, so shooting something down by your
feet doesn't paper the floor. Enough silk wraps it where it stands and the bundle
drops for you to put a line on and drag off; short of enough, it's carrying that
silk around and the next shot starts from there. A heavier pattern doesn't catch
better, it just gets there in fewer shots.

It has to actually touch the thing, mind. The bead you watch fly is exactly the
size that counts, against the creature's own body — a near miss is a miss.
Holding right mouse winds up a bigger ball, which is the help on offer.

**Anything moving is led for you.** Put the cross on a creature — brackets close
round it — and the silk is thrown at where it will be when the silk gets there,
marked with a dot out ahead of it. Aimed at where a fly *is*, a shot never catches
one that's moving: the silk takes most of a second to cross a room, and the fly
is a metre on by then. Led, a steady flier is caught nine times in ten; a midge or
a wasp that keeps changing its mind, about six. The silk still flies dead
straight, so anything that turns while it's in the air gets away.

**The camera** sits behind and above you and never rolls — the horizon stays
level however far up a wall you are. The crosshair is truthful: it's cast at the
world, and silk goes from the spider to whatever it lands on, so what's under the
cross is what you hit. That matters more in third person than it sounds, because
firing along the *camera's* direction and firing at what the camera is *looking
at* are two different shots — the first missed a wasp three metres off by 0.45m.

And it says what silk will do. **Bright** when there's something in reach to land
on, **faint** when there isn't; **amber, with brackets**, on a creature a shot would
be thrown at, and a dot where the shot will meet it. The camera sees over things
the spider can't, so when a ledge is in the way a small **red ring** shows where
a grapple would really land. An arc round the cross fills while the next shot is
spun, and while a throw is wound up.

**Shift sprints, and it runs out.** You have a few seconds of it, and they come
back on their own while you walk. What makes it worth a pool rather than a free
button is the second half: **it costs more the heavier the thing on your line**.
Weight already makes a haul slower, but on its own that only makes the slow way
worse than the fast way, with nothing to weigh. Now running a wasp home is
something you spend, and walking it home is a real choice.

It is not the pool a bite takes. That one is **condition** — you can't wait it
back, and emptying it throws you across the room. Running out of wind costs you
nothing but a walk, and the bar under the condition bar only shows up while you
are short.

A click on something still alive deliberately does **nothing special** — the aim
reads straight through it to the wall behind, exactly as it would if the creature
weren't there. There's a second move parked behind `LiveLine.move`, off by
default: *hitch* ties the creature to the ground you're standing on, so it keeps
its legs but only inside a radius, and *where* you tied it is what beats it. It
shares left mouse with the grapple, which is the unsolved part; flip it to `HITCH`
on the Spider scene's LiveLine node if you want to play with it.

What doesn't live here any more is a pounce: for a while, clicking a creature threw
the spider at it and bit on landing, and that turned out to be a second way of doing
exactly what a bolt already does, on an animal whose whole offensive vocabulary is
supposed to be wrapping. **Hunting Fangs** still halve what counts as "much bigger
than me", so a fanged spider can take anything inside its bite where it stands, and
a **Venom Spur** rigged into a web still kills what it catches outright.

**Leave one somewhere to work.** Fit a web to a corner prey walks past, drop a
**Scent Lure** on the far side so traffic comes *through* the web to reach it,
and wire a **Signal Bell** in so you get told when it catches. Then go
somewhere else.

Same object, same rules, either way — including whether it holds what hits it.

## What there is to catch

Creatures are resources in `game/data/prey/`, and one scene serves all of them
— body, size and behaviour all come from the `.tres`, so adding something new
to catch is a file, not a scene and not a line of code.

| | Size | Fight | Where | Worth |
|---|---|---|---|---|
| **Midge** | 1 | nothing | anywhere, high | 3 — but they come in numbers |
| **Mosquito** | 1 | 2 | anywhere, in fits and starts; loves a lure | 4 |
| **Fly** | 1 | 5 | anywhere | 8 |
| **Ant** | 1 | 5.5 | **walks** — ground only | 6 |
| **Moth** | 2 | 12 | high up, loves a lure | 16 |
| **Butterfly** | 2 | 7.5 | high up, drifting; loves a lure | 14 |
| **Bee** | 2 | 18, stings when it outgrows you | anywhere, comes to a lure | 24 |
| **Beetle** | 3 | 19, slow and long | **walks** — ground only | 30 |
| **Wasp** | 3 | 31, ignores lures | anywhere | 34 |

Three things decide where a creature belongs. **Fight** is what a web has to
out-hold to keep it, so it picks the web. **Where** picks the *place* — no web
strung in the air will ever see a beetle, and a moth lives near the ceiling.
And **size** is your bite power, which is why a wasp needs venom or a few more
meals before you can drain one — and it's what a web's **mesh** dial catches
or lets through, so spinning coarse to save silk means small things walk out.

A creature with a **body** is drawn from it: a skeleton, one mesh skinned to it,
and simple motion — wings that beat in flight and fold at rest, six legs that tuck
up to fly or walk three at a time, thrashing in a web, curled up once wrapped, and
always facing where it is going. Bodies are resources too, in `game/data/bodies/`.
An insect's is an `InsectBody`, where every size, colour and part is a number, and
a species points at one with its `body` field. One without is still drawn as the
old placeholder ball.

Some bodies are drawn ahead of anything to wear them: the creatures of the sewer,
the park and the pond, before those have anywhere to live. They wait in
`game/data/bodies/` for a species, and until then the checks and the pictures show
them on a stand-in. So far:

* the **cockroach**, flat and glossy under its pale-rimmed shield, with feelers
  longer than it is;
* the **rat**, the first `BeastBody` — anything furry on four legs: a body, a head
  with a snout, ears and a jaw that opens, four legs and a tail. Big round ears,
  big eyes, buck teeth and whiskers. It trots two legs at a time, shakes its head
  with its mouth open when it is caught, and curls up small once it is wrapped;
* the **bat**, the first `WingedBody` — anything that flies on two wings of two
  bones each, an arm and a hand: skin stretched between its fingers, ears
  bigger than its head, a flat pig's nose and a pair of fangs. Its hands beat a
  moment behind its arms; on the ground its wings pleat up along its sides;
  caught, it flaps in bursts; wrapped, it pulls them round itself like a cloak;
* the **cat**, a ginger tabby on the same body as the rat: pointed ears, big
  green eyes, a white bib and socks, and a striped tail held up in a hook. Caught,
  its ears go flat;
* the **dog**, a third: floppy brown ears, a patch over one eye, a saddle on its
  back and a big black nose. It pants with its tongue out and wags as it trots;
* the **parrot**, the bat's body in feathers: a scarlet macaw, red, with yellow
  coverts over blue flight feathers, a bare white face and a hooked beak. On the
  ground it stands up straight on its perch and folds its wings down its sides;
* the **fish**, the first `FishBody` — anything that swims with its tail: a
  goldfish, with goggling eyes and pouting lips that gulp. It swims in a wave
  that runs down it from nose to tail; out of water it lies on its side and
  gasps, and flops when it tries to go anywhere; wrapped, it is bent double.
  Swimming is flying, as far as a creature is concerned: it keeps itself up in
  water the way a fly does in air, so a swimmer's species will say `flying`;
* the **shark**, on the fish's body: grey over white, a pointed snout, gill
  slits, a tall fin on its back, a tail with a long top lobe, and a grin — a
  row of teeth under the snout and another on its jaw, the mouth hanging a
  little open, snapping when it is caught;
* the **octopus**, an `OctopusBody`, its own kind: a head with goggling eyes and
  a little tube of a mouth, a spotted mantle above it, and eight arms of four
  bones each with pale suckers underneath. Sitting, ripples run down its arms;
  swimming, it tips mantle-first and pulses, its arms opening wide and snapping
  shut; caught, every arm flails on its own; wrapped, each one coils up.

## Leaving a web and coming back

Prey that hits a web fights hard for about five seconds. Survive that and it
tires out and hangs there until you come for it — so a web is somewhere you
*store* things, not a moment you have to be present for. Lose that window and
it tears free and takes a piece of the web with it.

Which web you used decides which way that goes: a sheet web just about keeps a
fly, an orb web keeps a moth, a pressure snare keeps a wasp. Silk quality rises
with your size and multiplies hold, so the same web keeps bigger things later.

Webs also **fill up** — two for a sheet web, four for an orb web — and a full
one catches nothing more. That's the nudge to run several sites rather than one
big web, and a wired-up **Signal Bell** is how you find out a site is full
without walking over to look.

A settled catch still tugs, so a full larder slowly wears the web out. Wrapping
it (**E**) stops that completely — wrapping is preservation, not just securing.

And once something is wrapped you don't have to eat it where it lies. **Point
at it and click** — the same button that grapples you across a room — and the
silk goes out to *it* instead, because hauling yourself over to stand next to a
thing that's already wrapped up and going nowhere isn't what you meant. A long
shot pays out the whole distance and then winds back in, so it harpoons rather
than yanking. It comes with you — over walls, along silk, off the end
of a zipline. It's a rope, not a rod: walk towards it and the line sags and the
bundle sits there; walk away and it swings in behind you and keeps swinging
when you stop. Weight is the cost — dragging a wasp home is slower than
dragging a fly, so *whether* to haul it back is the decision.

## The bag — things that aren't silk

**N** opens the bag. Wheel to pick, left mouse to put one down, **X** to take it
back up. Placing costs no silk at all: devices are finite and found, and running
out is the whole limit on them.

They only ever do things silk *cannot*, which is what stops them being better
webs:

| Device | What it's for |
|--------|---------------|
| **Venom Spur** | Wire it to a trap and whatever that trap catches **dies**. A dead thing can be drained whatever its size, so this is how you take something too big to bite. One shot. |
| **Scent Lure** | **Pulls prey in from much further than a funnel web, with no web at all.** Drop one where you want traffic. |
| **Signal Bell** | Wire it to anything and it **tells you the moment that thing goes off**, from anywhere in the level. |

The bell is what makes leaving a trap behind work: build it, zip off somewhere
else, and get told when to come back rather than having to guess.

Devices land in a `Devices` node next to `Webs`, and a new one is a `.tres` in
`game/data/devices/` — same as adding a web pattern.

## Two ways to weave a web

**K** switches between them, and it applies to webs spun from then on:

* **Stretched** (default) — the web is the shape you drew. The spiral runs out
  to the anchors, so an odd outline makes an odd web.
* **Inscribed** — what a real orb weaver builds: an even round spiral as big as
  fits inside the frame, spokes carrying on past it to the anchors. Here the
  shape of your outline matters, because the catching area is the biggest
  circle that fits — a fat outline beats a long sliver by a mile.

Either way the frame sits on the anchors exactly where you put them, in 3D, so
a web across a room corner tents through the fold instead of floating off the
wall.

## Tuning a web

Three dials, set before you spin, each one a trade rather than an upgrade:

| Dial | Up | Costs you |
|------|----|-----------|
| **Tension** | holds harder | tears sooner |
| **Weight** | stronger all round | more silk per metre |
| **Mesh** (opened out) | cheaper — fewer threads | small prey walks through |

`;` picks a dial, `[` and `]` turn it, `'` resets. Settings are remembered per
pattern and travel inside saved designs. Weight and mesh change the weave
itself, so a tuned web looks different as well as behaving differently.

## Saving a rig as a design

**B** while looking at a web keeps it — and everything wired to it — as a
design. **V** brings your designs up: the wheel picks one, a ghost shows where
it would land, and left mouse spins the whole rig, wiring and all, turned to
face the way you're looking. You're charged at today's silk prices, and nothing
is built or charged unless all of it can be.

Designs are written to `user://designs/*.tres`, which is
`~/.local/share/godot/app_userdata/spoolunky/designs` on Linux. They're plain
resources, so renaming one is a matter of editing `display_name` in the file.

Anchors are replayed exactly as recorded rather than re-fitted to whatever is
under them, so a rig placed in a differently-shaped spot keeps its shape — the
ghost preview is there so you can see that before committing.

## Adding a new kind of web

Duplicate any `.tres` in `game/data/patterns/`, change the numbers, and it turns
up in the build wheel — the library scans that folder. The fields that matter
most are `shape` (strand or net), `trigger` (passive, alert, snare or lure),
`unlock_stage`, the three silk costs, and `hold_strength` / `durability`.

## Levels are scenes, not scripts

`world.tscn` and `testbed.tscn` hold their geometry as real nodes, so anything in
them can be selected and moved in the editor. They did not start that way — both
were assembled in `_ready()` from `world.gd` and `testbed.gd`, which is quick to
write and impossible to tweak, because there is nothing in the editor to tweak.

Those two scripts are still there as the **generator of record**. To throw the
hand-placed version away and build the shape again from scratch:

```sh
godot --headless --script res://tools/bake_level.gd -- testbed world --force
```

Without `--force` it looks at a baked level and leaves it alone, so running it by
accident costs nothing.

One thing to know if you add to a level: **only `@export` properties survive being
saved into a scene.** A value set in code on a plain `var` is there while the
builder runs and gone the moment it is baked — which is how the zones ended up
measuring nothing and the gates stopped opening the first time round.

## The gym

`game/world/testbed.tscn` is a signed practice room — one station per thing the
game does. The **DUMMIES** station is the one for fights: three creatures on
posts with their numbers over their heads, showing how much silk is on them, how
long the venom has left, what that has done to their speed, and what a web would
have to hold to take them. One stands still, one runs at a wasp's pace so you can
watch silk take its legs, and one comes for you. Finish one and the post stands a
fresh one up.

They are ordinary creatures, so silk, venom, webs, hauling and eating all work on
them exactly as they work on anything else — and their species live in
`game/data/training/` rather than `game/data/prey/`, so they never spawn in the
world, fill the larder or pay for traits.

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

A third loads the gym and the tower and checks the level itself — that the gates
open at the sizes the tier table names, that every station is signed, that the
spider lands on the floor rather than through it:

```sh
godot --headless --script res://tests/world_smoke_test.gd
```

A fourth lets every body loose in an empty room — on the species that wears it, or
on a stand-in if nothing does yet — and checks it holds itself the way it should:
facing where it goes, beating what it flies or swims with, feet on the floor,
thrashing when it is caught, curled up and still once it is wrapped:

```sh
godot --headless --script res://tests/creature_smoke_test.gd
```

Each prints a line per check and exits non-zero if any fail. Together they take
about three and a half minutes, most of it the web suite and the creatures.

The web suite puts its sections back to a bare spiderling in an empty room
between each one, so nothing depends on what ran before it. To check that is
still true, run it in a random order — the seed is printed, so a failure can be
run again exactly:

```sh
SPOOLUNKY_SHUFFLE=whatever godot --headless --script res://tests/web_smoke_test.gd
```

They also run on every push: `.github/workflows/tests.yml` fetches the newest
Linux build matching `GODOT_VERSION` and runs all four. Bump that one variable
when the project moves to a new engine version — the workflow finds the build
itself rather than holding a URL that rots.

Waiting on a push to find out is slow, though, and `gdparse` only reads syntax:
an undeclared identifier, a renamed method and a stale test assumption all parse
clean and all fail in the engine. So `.claude/hooks/session-start.sh` fetches the
engine at the start of a cloud session and imports the project, which
puts the suites a second away instead of a CI round. It does nothing on a local
checkout, where you have an engine already.

To look at the silk geometry without opening the editor:

```sh
xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 \
    --script res://tests/screenshot_webs.gd
xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 \
    --script res://tests/screenshot_climb.gd
xvfb-run -a godot --rendering-driver opengl3 --resolution 1100x740 \
    --script res://tests/screenshot_weave.gd
```

And the spider's body, close up, in every state the gait has a pose for and in
every look. Name states or looks after `--` to render only those, for instance
`-- low_poly minimal portrait walk`:

```sh
xvfb-run -a godot --rendering-driver opengl3 --resolution 800x600 \
    --script res://tests/screenshot_body.gd
```

And every body, close up, in each pose it has — flying, swimming or walking, at
rest, caught, wrapped — plus `creatures.png`, a sheet of all of them. Name bodies
or poses after `--` to render only those, for instance `-- fly caught`:

```sh
xvfb-run -a godot --rendering-driver opengl3 --resolution 800x600 \
    --script res://tests/screenshot_creatures.gd
```
