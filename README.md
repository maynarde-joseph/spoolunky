# Spoolunky

A first-person spider game in Godot 4.6, set in a wild valley that gets on with
its life whether you are in it or not. You start the size of a coin in a hollow
stump at the valley's edge, spin webs to catch whatever walks into them, and eat
your way across it — through the ferns, into the caves under the great tree's
roots, out over the glade and up into the ruins — until the wyvern circling the
crag is something you could eat. Everything out there is eating something too:
hares graze the glade, foxes hunt the hares, wolves come out at dusk for the
foxes, and what is not eaten goes home and breeds.

What you eat changes what you are: every meal is a chance to take something from
it — wings, armour, venom — and the bigger it was next to you, the better the
odds. And what you are decides what you can cast: the thrown web is the first
spell, and a whirl of water, lightning and fire open as you grow, each working
off the others and off your silk.

The project opens somewhere else now, though: **the Hollow Wood**, a prototype of a
second shape for the game. A stretch of old forest floor under the sky with ruins
standing in it — a ring of standing stones where you wake, a ruined court, a walled
graveyard, a chapel with its roof fallen in, a watchtower on a hill, a barrow dug
into a mound, and a mire — each a place you walk up to, scout from outside and go
into. Everything in it is hostile and fights back with attacks you can learn to
read, and the way to beat a thing is the way to catch a monster: wear it down,
then wrap it. The spider is one size the whole way through, with every spell from
the start; there is a miniboss sealed in the barrow and a main boss that flies the
rounds of the whole wood. The structures are greybox on purpose: it is there to
find out whether the shape is fun.

The full pitch — the loop, the size tiers, the world and what lives in it, the
trap catalogue, and the Hollow Wood (§12) — is in [`docs/DESIGN.md`](docs/DESIGN.md).

## Where things are

```
game/
  data/      web patterns, devices, size tiers, traits, spells, creatures and
             their bodies, and the hostiles and their attacks (plain
             resources — edit the numbers)
  web/       procedural silk geometry and the webs themselves
  player/    the spider, one node per job: growth, climbing, the camera, the
             builder, the tether, the bag, the traits, the spells, eating and
             stamina, and the body you see — a skeleton and the gait that walks it
  spells/    what spells leave in the world: a whirl of water, a strike of
             lightning, the bloom where one lands
  prey/      things to catch, and something to spawn them
  combat/    creatures fighting back: carrying out their attacks, and what they spit
  ecosystem/ what makes the valley live: the clock, dens, forage, haunts, and the
             mind every creature in it has
  rig/       bodies: bones, meshes skinned to them, and the motion that poses them
  ui/        HUD
  world/     the Hollow Wood, the hunting ground and the gym, the kit and the
             paints they are built from, the props they are furnished with, day
             and night, gates, and the shrines, marks, shortcuts and lair
tools/       the bakes that turn builders into scenes, and the tab check
tests/       seven headless suites and screenshot tools
  support/   what the suites share: the verdict, and the arena a web check runs in
addons/character-controller/   the movement template the spider is built on
```

The project opens the Hollow Wood, `game/world/hollow_wood.tscn`. The hunting ground,
`game/world/hunting_ground.tscn`, is the other game, and opening it in the editor
and pressing F6 plays it. The sandbox the web, spell and combat suites run in is the
character-controller example level
(`addons/character-controller/example/main/level.tscn`), with the spider, a HUD, a
`Webs` container and a prey spawner dropped into it. A `Devices` container is made
on demand the first time you put something down.

## Controls

Some of the rows below are for features that are parked rather than deleted and
bound to nothing in the current build; the table in `docs/DESIGN.md` (§9) is the
one kept to what the keys do today.

| Input | Action |
|-------|--------|
| WASD / Space | move and jump — **jump is also how you let go of silk** |
| **Shift** | **sprint** — it runs out, and it runs out faster the heavier the thing on your line |
| *walk into a wall* | climb it — walls and ceilings are floors to a spider |
| *stand on silk* | it holds you — a thread runs one way, and **jump** is how you come off |
| **Ctrl** | drop onto a dragline (from a wall or ceiling) |
| **Ctrl** / **Space** | lower / raise yourself on the line |
| **Right Mouse** | let go of the line |
| **Left Mouse** | **go there, trailing silk** — moving and building are the same act |
| **G** | **grapple style** — the **pull** takes you there; the **line** lays a line from your feet to where you point and stands you on it, and walking a line is fast — the same speed up it as down. Jump to step off |
| **Left Mouse** *on something you've caught* | put a line on it and drag it instead — same click, read the only way that makes sense |
| **Right Mouse** | **cast what is in hand** — the web, to start with: tap, or hold to wind it up |
| **Q** | the next spell you have — growing, and what you eat, opens more |
| **E** | evolution — what you are, and your odds on what eating could make you |
| **F** | wrap caught prey, then drain it (also re-arms a sprung snare). In the Hollow Wood a meal mends you, and at a shrine **F** rests |
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

In the hunting ground the insects keep hours: moths, mosquitoes and fireflies come
out at night, and bees, butterflies, flies and wasps by day.

Past the insects are the creatures of the wilds, whose species say so with a
`habitat` of `"wilds"`. The insects turn up anywhere, and a spawner left to choose
its own stock takes only them; a wolf is only put down where a den or a spawner
names it, so a room built to test webs in does not fill with wolves and sharks.
Each is built to the tier it is food for, so a rat is the size of a Glade Widow
and the leviathan is bigger than anything but the Architect, and a big one bites
from the edge of its body rather than from six of its own widths away, which was
a margin for a wasp and was the far bank for a shark.

| | Size | Fight | Eats | Out | Lives |
|---|---|---|---|---|---|
| **Firefly** | 1 | 3 | flowers | night | the fern floor, drifting low |
| **Cockroach** | 3 | 22 | carrion, fungus | night | the Rootways and the ruins |
| **Marsh Frog** | 4 | 27 | insects | always | the banks of the Mere |
| **Moss Lizard** | 4 | 29 | insects | day | the ruins' walls |
| **Bat** | 4 | 32 | insects | night | under the great tree's roots |
| **Songbird** | 4 | 31 | insects, berries | day | the glade's trees |
| **Rat** | 5 | 43 | carrion, berries, fungus, insects | night | the Rootways and the ruins |
| **Hare** | 6 | 53 | grass, flowers | always | burrows in the glade |
| **Raven** | 6 | 55 | carrion, insects, berries | day | the ruined tower and the crag |
| **Fish** | 6 | 50 | weed | always | the Mere |
| **Fox** | 7 | 70 | hares, rats, frogs, lizards, songbirds, berries, carrion | night | an earth in the glade |
| **Mire Kraken** | 7 | 98 | fish, carrion | night | the deep of the Mere |
| **Glade Stag** | 9 | 113 | grass, flowers, moss, berries | day | the glade, and wherever it roams |
| **Bristleback Boar** | 9 | 136 | fungus, berries, grass, carrion | always | the ruins, and wherever it roams |
| **Dusk Wolf** | 9 | 120 | stags, boars, hares, foxes, carrion | night | the foot of the tower, and wherever it roams |
| **Mere Leviathan** | 9 | 126 | fish, the kraken, carrion | always | the Mere, and never out of it |
| **Crag Wyvern** | 12 | 280 | stags, boars, wolves, foxes, hares, carrion | day | its nest on the crag; it hunts the whole valley |

The ones that swim say `swims` as well as `flying`, and keep all of themselves
under the top of the water they are in: steering at a lure on the bank or a
spider on the island, they follow along underneath. Their bodies:

* the **cockroach**, flat and wide under the shield that hides its head, with
  its wings folded flat as its back and feelers longer than it is;
* the **firefly**, a dark beetle with an orange shield over its head and a
  lantern at the tip of its body that glows yellow-green in the dark;
* the **rat**, the first `BeastBody` — anything furry on four legs: a body, a head
  with a snout, ears and a jaw that opens, four legs and a tail, drawn the
  minimal way: grey, with round pink ears and a long bare tail. It trots two legs
  at a time, shakes its head with its mouth open when it is caught, and curls up
  small once it is wrapped;
* the **frog** and the **lizard**, the rat's body with the ears left off and the
  legs splayed out to the sides: the frog squat, green and tailless, with its eyes
  up on top of its head and a wide mouth; the lizard long, low and mossy, with a
  tail longer than it is. Caught, each kicks out with all four legs; wrapped, the
  lizard curls round its own tail;
* the **hare**, long-legged and brown, with long ears standing up and a white
  scut; the **fox**, rust-red, with black ears, a long thin snout and a brush
  tipped in white; the **wolf**, grey and heavy, with its tail held low; the
  **boar**, dark, deep-bodied and short-legged, its head set low with two pale
  tusks curving up out of its jaw; and the **stag**, slender, on long legs, its
  head held up on a long neck under a crown of antlers;
* the **bat**, the first `WingedBody` — anything that flies on two wings of two
  bones each, an arm and a hand, drawn the minimal way: dark brown, with tall
  ears and wings of skin scalloped between thin finger bones. Its hands beat a
  moment behind its arms; on the ground its wings pleat up along its sides;
  caught, it flaps in bursts; wrapped, it pulls them round itself like a cloak;
* the **songbird** and the **raven**, the bat's body in feathers: the songbird
  small and brown, quick-winged, with a short yellow beak; the raven black all
  over, with long fingered wings and a heavy beak. On the ground a bird sits up
  on its perch and folds its wings down its sides;
* the **wyvern**, the bat's body made huge: a long head with pale horns sweeping
  back off it and curling down, vast brown wings of skin on long fingers, orange
  eyes, and a long whip of a tail;
* the **fish**, the first `FishBody` — anything that swims with its tail,
  drawn the minimal way: one smooth orange teardrop with flat fins. It swims in
  a wave that runs down it from nose to tail; out of water it lies on its side
  and flops when it tries to go anywhere; wrapped, it is bent double. Swimming
  is flying, as far as a creature is concerned: it keeps itself up in water the
  way a fly does in air, so a swimmer's species says `flying`;
* the **leviathan**, on the fish's body: one grey, with a pointed snout, a tall
  fin on its back, long fins at its sides and a tail with a long top lobe;
* the **kraken**, an `OctopusBody`, its own kind, drawn the minimal way: a
  head with two small eyes, a smooth mantle above it and eight tapering arms of
  four bones each, all one colour. Sitting, ripples run down its arms; swimming,
  it tips mantle-first and pulses, its arms opening wide and snapping shut;
  caught, every arm flails on its own; wrapped, each one coils up.

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

## The Hollow Wood

`game/world/hollow_wood.tscn` is what the project opens: a stretch of old forest
floor, out under a grey late sky, with ruins standing in it. Ferns, toadstools,
fallen leaves and the old trees fill the ground between the places, and worn paths
run from the clearing to all of them. The spider is a Huntsman the whole way
through — eating here neither grows it nor passes anything on — every spell is
open from the start, and nothing mends it but a shrine and a meal: drink something
you have wrapped and you get some of yourself back.

* **The Shrine Clearing**, in the south: a ring of standing stones round a dais and
  a shrine. You wake here, and nothing hostile comes in.
* **The Ruined Court**, in the middle: old paving, arches and broken walls, columns
  and a dry fountain. Blade rats and charger beetles, and the wyrm likes it here.
* **The Graveyard**, east: a walled yard of stones and dead trees, frogs among the
  stones and mosquitoes over them, and a crypt with a shrine inside.
* **The Chapel**, west: a long hall with its roof fallen in over the south end,
  tall shelves in aisles, bats and wasps, and a gallery with a shrine on it. Its
  great door is open; its side door, towards the clearing, opens only from inside.
* **The Watchtower**, north, on a hill: four floors with a hole in each, open to
  the sky at the top, where there is a shrine. Its door is shut and opens from the
  inside — so the way in is up its outside and down through it.
* **The Barrow**, north-east: a hall dug into a mound at the end of a cutting, with
  a shrine before it. **The Rat King** keeps it: step inside with the king alive
  and a veil drops over the door until one of you is beaten.
* **The Mire**, south-west: a sunken bog of reeds and lily pads, and frogs.

**Shrines.** Touch one and it is lit, and it is where you wake when you are
driven off. Rest at one (**F**) and you are whole again — and every hostile is back
on its feet at its mark. Driven off, the same: you wake at the last shrine you lit
and the place has stirred. Your webs stay. A boss that beat you is back at its
post; one you have beaten stays beaten. A door, once opened, stays open.

**What lives here fights back.** Every attack is told before it lands — the
creature stops, turns to you, and a ring or a line in the attack's colour shows
where it is going — then the strike, then a moment it stands open, which is when
to put silk on it. Each hostile has a bite and one move of its own:

| Hostile | Its move | The answer |
|---|---|---|
| **Drill Mosquito** | dives from up to seven metres; missing, it sticks in whatever is behind you | step aside once it commits |
| **Blade Rat** | a wide slash that cuts every line and web in front of it | do not trust silk between you |
| **Charger Beetle** | a long straight charge that throws you a long way | a web across its path catches it |
| **Spitter Wasp** | spits from range and backs off if you close | step aside, or put silk between you |
| **Tongue Frog** | a tongue that drags you to its mouth | anything between you takes the tongue |
| **Screech Bat** | a ring of sound that throws and dazes you | be outside the ring |

**Catching them is like catching a monster.** Everything has health, shown over a
hostile's head with a thin bar of how much of it is wrapped under it. The lower its
health, the more of the way each hit of silk gets you — at full health a blade rat
takes three orb shots; with nothing left, one. **Firebolt** is what wears it down,
and silk burns: a bolt takes a fifth of its harm off something bare, and all of it
off something wrapped all the way or hanging in a web. So the loop is wrap, burn,
wrap. The silk goes up with it — a web or a line in the burst burns away, and what
the web held drops out — so a web is somewhere to burn a thing once, not a place
to keep it while you do.

And two bosses, named across the foot of the screen with their health and wrap:
**the Rat King**, sealed in the Barrow, which whirls and cuts every thread round
it, calls blade rats and pounces; and **the Hollow Wyrm**, which keeps to no place
but flies the rounds of the whole wood, and dives, spits fire, tears silk down
with a gust and sweeps with its tail. Beating the Rat King gives you what it kept:
Wing Buds, a glide.

**The line grapple** is one key away: **G** switches from the pull to a grapple
that lays a line from your feet to where you point and stands you on it. Walking a
line is fast, the same up it as down, and you stay on until you jump.

## The hunting ground

`game/world/hunting_ground.tscn` is the other game: one wild valley, laid out the way a
hunting ground is in the games it is named for — a camp to set out from, and round
it the places things live, each its own country with its own creatures and its
own danger. It is all to one scale — a metre is about fourteen of its units — and
it is the spider that changes size.

* **The Camp**, at the south edge: a hollow stump open toward the valley, with
  moss on its floor and a glowcap for a lamp. Nothing lives here and nothing comes
  looking. It is where you start, and where you are put back if you fall out of
  the world.
* **The Fern Floor**, between the camp and the glade: ferns overhead, toadstools
  with caps like roofs, pebbles that are boulders, fallen leaves, an anthill and a
  puddle. Midges, flies, ants and beetles by day; moths and fireflies at night,
  and mosquitoes over the puddle.
* **The Rootways**, in the west: the great tree, three and a half metres through,
  its roots arching over the hollow it stands in so that under each is a cave.
  Shelf fungus up the bark to climb by, a hollow log to walk the length of, and
  glowcaps lighting the caves at night. What lives here comes out in the dark:
  roaches, rats, moths and beetles, and bats that hang under the roots by day.
* **The Bloom Glade**, the open middle: a meadow in flower, with tall grass and
  wildflowers to string silk between, brambles of berries, a ring of standing
  stones, a wild hive and a wasps' nest. The busiest place in the valley by day —
  bees and butterflies over the flowers and wasps hunting them, hares in the grass
  and a fox after the hares, songbirds in the trees, and stags grazing all of it.
* **The Old Ruins**, up on a shelf of ground in the north-west: broken walls round
  a courtyard, a gateway, columns standing and fallen, a tower with its top broken
  away, and in the courtyard a statue of a great spider. Lizards on the walls,
  ravens on the tower, boars in the rubble, rats and roaches out of it at night,
  and wolves denned at the tower's foot.
* **The Mere**, in the east: a round lake with an island in it, a birch on the
  island, lily pads and reeds. Fish graze the weed on its bottom, the Mire Kraken lies in the
  deepest part, and the Mere Leviathan, which nothing hunts, goes where it likes in
  all of it. Frogs sit on the banks, and stags and wolves come down to the shore.
  The water is water: a spider in it swims, and nothing that lives in it comes out.
* **Wyrm's Crag**, in the north: a rock tower weathered into ledges, with spires
  standing off it and, in the bowl on top, the wyvern's nest of branches, bones
  and three eggs. Nothing lives up there but ravens. The wyvern hunts the whole
  valley.

Each place is built for a stretch of the spider's sizes, smallest nearest the
camp, so the way across the valley is the way up the sizes. But nothing shuts the
way to any of it: what keeps a spiderling out of the crag is that the crag would
eat it. Walk into a place and the HUD names it, and what size it was built for.

## The valley is alive

The hunting ground has an `Ecosystem` in it, which is what makes the creatures in
it live rather than wander. A day goes round in twelve minutes, with the time in
the corner of the HUD: the sun goes over and sets, the moon comes up after it, and
the sky goes with them (`DayNight`). The colours the level was built with are its
noon, and the rest of the day is worked out from them.

* **Everything gets hungry**, at its own rate, and goes to find what it eats:
  patches of forage — moss, toadstools, flowers, grass, berries — that it eats
  down and that grow back slowly; something smaller, which it hunts down, kills and
  eats where it fell; or anything dead, whoever killed it. Something hungry that
  can see nothing to eat goes looking, further out each time.
* **Everything is afraid** of what would eat it, and runs: from as far off as it
  can see the thing if it is hunting, and only up close if it is not. A wary one
  keeps clear of a spider big enough to eat it, too.
* **Dens** put their creatures out when the valley opens and breed them on what
  they eat: every meal is put by, and a new one is born when enough has been. A
  den whose creatures go hungry dwindles, and one that is hunted out is found again
  in the end by a stray of its kind.
* **Everything keeps hours.** Out of them, a creature goes home and rests — out of
  sight, if its den is a burrow. Moths, bats, rats, foxes and wolves come out at
  night; bees, songbirds, stags and the wyvern by day.
* **The big things roam** between haunts rather than keeping to the country round
  their den, which is how a stag turns up in the ruins and why the wyvern is
  sometimes over the glade. And they hold their ground: two that will not give way
  to each other square up and fight, and the stronger usually wins. Both come out
  of it hurt — slower, and weaker in a web — and anything hurt badly enough limps
  home and rests until it has mended.

None of it is scripted. A glade with too many hares on it is a glade with no grass
on it, and then fewer hares.

## Levels are scenes, not scripts

`hollow_wood.tscn`, `hunting_ground.tscn` and `testbed.tscn` hold their geometry
as real nodes, so anything in them can be selected and moved in the editor. They
did not start that way — each was assembled in `_ready()` from `hollow_wood.gd`,
`hunting_ground.gd` and `testbed.gd`, which is quick to write and impossible to
tweak, because there is nothing in the editor to tweak.

Those scripts are still there as the **generator of record**. To throw the
hand-placed version away and build the shape again from scratch:

```sh
godot --headless --script res://tools/bake_level.gd -- testbed hunting_ground hollow_wood --force
```

What the Hollow Wood holds that is not geometry — shrines, the marks hostiles
stand up at, the doors that open from inside, the lair — is nodes with scripts of
their own, which survive the bake and pick their pieces back up when the scene is
loaded.

Without `--force` it looks at a baked level and leaves it alone, so running it by
accident costs nothing.

The world is built out of `WorldKit` solids — each one a mesh and a collider of
the same shape, so everything you can see you can stand on and stick silk to —
painted from the `Palette`, a few flat matte paints kept one to a file in
`game/world/materials/`. Change a colour there and everything painted with it
follows. The ground is one height map, drawn in pieces and collided as one. The
shapes the builder makes a point at a time — the valley's ground, the hollow log —
are kept by the bake in `game/world/meshes/`, one compressed file each, rather
than written into the scene as numbers.

The things in it — thirty-one of them, from an acorn to a fallen pillar — are
**props**: each built in `game/world/props.gd` and baked into its own scene in
`game/world/props/`, so the world holds instances of them and the editor has them
to drag in. Like the levels, a prop that has a scene is left alone unless you say
otherwise:

```sh
godot --headless --path . --script res://tools/bake_props.gd -- --force fern
```

One thing to know if you add to a level: **only `@export` properties survive being
saved into a scene.** A value set in code on a plain `var` is there while the
builder runs and gone the moment it is baked — which is how the zones ended up
measuring nothing and the gates stopped opening the first time round. And a
change made *inside* an instanced scene is not saved either; what the builder
hangs on a prop after putting it down is the one exception the bake keeps.

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
world, fill the larder or pass on traits.

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

A third loads the hunting ground, the gym and the Hollow Wood and checks the
levels themselves — that the seven places are all there, none inside another, and
every size has one built for it; that there is a sun and a sky, and a day and a
night to drive them; that every species has a den somewhere, every place has
forage, and everything that roams has haunts to roam between; that there is ground
under every place and hills round the edge; that the spider starts in the camp, on
its floor, with the HUD naming it; that the Mere is full of water and nothing in it
comes out; that every prop is something to stand on; in the gym, that every
station is signed and the spider lands on the floor rather than through it; and in
the Hollow Wood, that the spider is held at a Huntsman with every spell open, every
place is there with ground under it and every one but the clearing and the belfry
has something hostile in it, one shrine is lit and the rest are cold, the chapel,
the crypt and the barrow can be walked into while the two doors that open from
inside are shut until their levers are touched, the Rat King keeps the Barrow, the
wyrm's beat can be flown end to end, and being driven off wakes you whole in the
clearing:

```sh
godot --headless --script res://tests/world_smoke_test.gd
```

A fourth lets every body loose in an empty room — on the species that wears it, or
on a stand-in if a body is ever drawn ahead of anything to wear it — and checks it
holds itself the way it should:
facing where it goes, beating what it flies or swims with, feet on the floor,
thrashing when it is caught, curled up and still once it is wrapped:

```sh
godot --headless --script res://tests/creature_smoke_test.gd
```

A fifth casts every spell in the sandbox: the web as the first of them, what
opens the rest, the strip that shows them, and what each does — to what it lands
on, and to the other spells and the silk it meets. Lightning run down a wire to a
wasp across the room, a whirl filling a web, acid water, fire that burns harder
the more silk is on what it hits, and the whole book opened at once:

```sh
godot --headless --script res://tests/spell_smoke_test.gd
```

A sixth puts creatures in a bare arena with an `Ecosystem` and checks that they
live: that they get hungry and graze, and stop when they are full; that a hunter
hunts, kills and eats, and that what it hunts runs; that the dead are eaten by
whatever eats carrion; that something hungry with nothing in sight goes looking;
that swimmers and walkers keep to their own; that dens breed on what is eaten
and are found again when they empty; that creatures keep their hours, roam
between haunts, square up over ground, and limp home when they are hurt:

```sh
godot --headless --script res://tests/ecosystem_smoke_test.gd
```

A seventh puts hostile creatures in a bare arena and checks that they fight the
way they say: that a hostile comes for you whatever its size, but only once it
can see you; that every kind of attack is told before it lands and does what it
says — a lunge goes where you were and a drill sticks in the wall, a web stops a
spit, a tongue drags you in, a burst throws and dazes, a sweep cuts silk, a
summon calls more and no more than it may; that a spitter keeps its distance;
that each of the six hostiles and both bosses does its own thing; that a hurt
thing is an easier catch and wears its health over its head; and that the
machinery holds — a meal mends where waiting does not, a shrine is where
you wake and resting stirs every mark, a gate opens from its far side, a lair
seals until its keeper is beaten, and a boss's name is on the screen while it
fights you:

```sh
godot --headless --script res://tests/combat_smoke_test.gd
```

Each prints a line per check and exits non-zero if any fail — and fails on any
script error printed on the way, even one that did not fail a check. Together
they take about seven minutes, most of it the web suite and the creatures.

The web suite puts its sections back to a bare spiderling in an empty room
between each one, so nothing depends on what ran before it. To check that is
still true, run it in a random order — the seed is printed, so a failure can be
run again exactly:

```sh
SPOOLUNKY_SHUFFLE=whatever godot --headless --script res://tests/web_smoke_test.gd
```

They also run on every push: `.github/workflows/tests.yml` fetches the newest
Linux build matching `GODOT_VERSION` and runs all seven. Bump that one variable
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

And every prop, one at a time and on one sheet, `props.png` — built from the
script, so a change shows before it is baked:

```sh
xvfb-run -a godot --rendering-driver opengl3 --resolution 800x600 \
    --path . --script res://tests/screenshot_props.gd
```

And the hunting ground from a set of named places, each at an hour of its own —
the camp, the fern floor, the caves under the great tree, the glade by day and at
night, the ruins' gate, the Mere's shore, its island and under it, the Mere at
dusk, the wyvern's nest, and the valley from above. Name them after `--` to render
only those, for instance `-- camp glade_at_night`:

```sh
xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 \
    --path . --script res://tests/screenshot_world.gd
```

Put `wood` first to photograph the Hollow Wood instead — the clearing, the court,
the graveyard and its crypt, the chapel outside and in, the watchtower and its
belfry, the barrow outside and in, the mire, and the wood from above:

```sh
xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 \
    --path . --script res://tests/screenshot_world.gd -- wood
```
