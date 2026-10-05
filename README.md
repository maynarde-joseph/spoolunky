# Spoolunky

A spider game in Godot 4.6. You climb anything — walls and ceilings are floors
to a spider — swing and zip on your own silk, spin webs to catch what walks into
them, and fight with what you can cast.

You are a spider wizard. The thrown web is the first spell, and what you catch and
eat earns the rest: experience makes rank — Apprentice Spooder up to Grand
Spooder — and every rank opens a row of the **spell tree** and two points to
spend in it. A call that brings your webs flying back, a spit of water, a gust
of wind, lightning, a breath of fire and a pillar of clay, the first five with a
second tier; the ways they
work off your silk and each other — webs that will not burn, webs left live,
lightning run along your lines, wind over a puddle lifting a whirl; and shorter
waits. Five spells ride in your loadout beside the web.

The project opens in **the Colosseum**, where the game will start: a great oval
arena of stacked arches, long abandoned, built from the kit of pieces in `Pieces/`.
Five more places are built from the same kit, each a scene of its own to open and
walk about in — a roofless **cathedral**, the courtyard of a burned **castle**, a
broken **aqueduct** over a river, a **watchtower** on a hill with its top broken
off, and a square walled **temple**. All of them are ruins, open to the sky, with
room to move and things to climb and string silk between. Nothing lives in any of
them yet. The levels that came before — the hunting ground, the Hollow Wood and
the gym — are gone, and what the game around these places is going to be is still
being decided. The spider is one size, a Huntsman, with every spell from the start.

The design notes — the loop, the spells and how they work off each other, the trap
catalogue, the creatures and what fights back — are in
[`docs/DESIGN.md`](docs/DESIGN.md).

## Where things are

```
game/
  data/      web patterns, devices, size tiers, traits, spells and the spell
             tree's skills, creatures and their bodies, and the hostiles and
             their attacks (plain resources — edit the numbers)
  web/       procedural silk geometry and the webs themselves
  player/    the spider, one node per job: growth, climbing, the camera, the
             builder, the tether, the bag, the traits, the spells and the spell
             tree, eating and stamina, and the body you see — a skeleton and the
             gait that walks it
  spells/    what spells leave in the world: the magic circle each is drawn
             in, a spit of water and the puddles it leaves, wet silk, a gust,
             the whirl wind lifts out of a puddle, a breath of fire, a pillar of
             stone, a strike of
             lightning and the charge it leaves in a web, a web called back, the
             bloom where one lands
  prey/      things to catch, and something to spawn them
  combat/    creatures fighting back: carrying out their attacks, and what they spit
  ecosystem/ what makes the valley live: the clock, dens, forage, haunts, and the
             mind every creature in it has
  rig/       bodies: bones, meshes skinned to them, and the motion that poses them
  ui/        HUD
  world/     the places built from the kit and what they share, the kit's
             pieces placed by name and stretched into blocks, the paints, day and
             night, zones, and the shrines, marks, shortcuts, lair and training
             posts
    dungeon/ the dungeon's rooms, the floor plan that lays them out, and the
             run that puts each floor down
Pieces/      the kit: walls, pillars, stairs and the rest, as .fbx
tools/       the import that makes each piece solid, the bake that turns each
             place and each of the dungeon's rooms into a scene, and the tab
             check
tests/       seven headless suites and screenshot tools
  support/   what the suites share: the verdict, and the arena a web check runs in
addons/character-controller/   the movement template the spider is built on
```

The project opens the colosseum, `game/world/colosseum.tscn`, with the dungeon
under it. Each of the other places is a scene beside it in `game/world/` — open one
in the editor and press **F6** to play it — and so is `game/world/dungeon.tscn`,
the dungeon on its own, which starts you on its first floor. The sandbox the
web, spell and combat suites run in is the character-controller example level
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
| *stand on a web* | it holds you — **jump** is how you come off. A line isn't a floor: you hang from it |
| **Ctrl** | drop onto a dragline (from a wall or ceiling) |
| **Ctrl** / **Space** | lower / raise yourself on the line |
| **Left Mouse** | **go there, trailing silk** — hold a direction and you land running, or let go and you stop there. Moving and building are the same act. It goes through lines; **Q** is what takes hold of one. No wait: the next goes the moment you land |
| **G** | **grapple style** — the **pull** takes you there; the **line** lays a line from your feet to where you point and hangs you from it, ready to zip along |
| **Q** | take hold of the nearest line with room to hang from — hang from it and zip along it with **W**/**S**, toward or away from where you look. **Q** or **Space** lets go |
| **Left Mouse** *on something you've caught* | put a line on it and drag it instead — same click, read the only way that makes sense |
| **Right Mouse** | **cast what is in hand** — the web, to start with: tap, or hold to wind it up |
| **Tab** *(hold)* | **the spell disc** — the web and the five spells in your loadout in a ring round the cross, with the world slowed to a quarter while it is up. Flick the mouse toward one and let go to take it in hand |
| **Tab** *(tap)* | back to the spell you had before |
| **Wheel** | turn through the spells in hand. (The number keys used to take them; they are parked, bound to nothing) |
| **E** | the **spell tree** — your rank, the points to spend, every skill and where it stands. Click a skill to learn it; click a spell you know to put it in the loadout or take it out |
| **F** | wrap caught prey, then drain it (also re-arms a sprung snare). At a shrine **F** rests |
| **Y** | **put a line on a bundle and drag it along** — again to drop what you're carrying |
| **X** | pull down the web you're looking at, for half the silk back — or pick a device back up |
| **G** | wire two things together — web or device, press on each end |
| **N** | open the bag — place a device (wheel to pick, left mouse to put down). The bag's bar is hidden for now and its keys are free |
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

**A landing springs.** Hold a direction as you arrive and you land running: what
the grapple carried along the surface stays (up to a quarter over a walk), and for
the next moment the spider is faster and much quicker off the mark, fading back to
a walk over most of a second. Let go of the keys and it brakes to a stop a step on
from the point. The same goes for any speed above a walk — off a line, out of a
fall: hold the way it's going and it coasts, let go and you stop.

**A line is a rail, not a floor.** You can't stand on one — a thread a couple
of centimetres across was the most finicky thing in the game to walk — so the
spider **hangs from it and zips along it** instead. **W** zips you towards where
you're looking along the line and **S** away, as fast up it as down it, because
gravity has no say: the line is a rail you pull yourself along. Let go of the
keys and you brake to a stop. Run off either end and you come off carrying the
speed, onto whatever the end is tied to. **Q** takes hold of the nearest line in
reach, or lets go; **Space** lets go too.

The **grapple goes straight through lines** to whatever is behind them: it takes
you to a place and stops you there, and **Q** is how you get onto a line. The
readout under the cross says **Q to hang from it** when the line you're looking at
is one Q would take. The cross still picks out the line you see it on, whatever is
behind it — that's what spells aim at, and what the line grapple ties its line to.

A *web* is still a floor: **silk is sticky**, a web keeps hold of you the way a
wall does until you **jump off**, and it's about half again quicker underfoot
than the floor.

Placing an anchor **grapples you to it**, dragging a frame line behind you. So
the frame of a web is the route you took around it, not an outline you drew from
across the room.

Frame lines are real silk that stands on its own, and you can zip along them —
walk a triangle into a corner and you've built three zip lines whether or not you
ever weave anything into them. Once the run closes a loop, **F** weaves the enclosed
area in one go, charging only for the silk inside; the frame was paid for as you
dragged it. Pulling a web down later leaves the frame standing.

If the selected pattern is a strand (tripline, bridge), that's what gets dragged
instead of plain frame line, so you can lay a run of triplines the same way.

**Every strand is a zip line** — there's no opt-in. And weaving isn't limited to
a loop you just walked: all your silk is one graph, and lines count as joined
where they *cross in mid-air* as well as where they share an end. Sling three
lines across a shaft and the triangle where they overlap is a ring you can fill.
Look at any ring and press **F**.

## Zipping along your own silk

Any line — a grapple's, a frame's, a bridge — can be hung from and zipped along,
as long as there's room under it for you: a stretch of at least three body heights
where the spider fits hanging. A line laid along the floor, run tight into a wall
or only a step long isn't offered as a ride at all — **Q** passes it over, and the line
grapple lays it without hanging you from it. You take hold where there's room, so a line that
starts at your feet catches you just up it, not inside the floor.
Arrive on a line already moving and you keep it. Letting go on purpose gives a
kick to clear the edge; running off the end doesn't, so the wall the line is tied
to takes you straight away.

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
end up on the ceiling. On a floor or a ceiling W goes where the camera looks. On a
wall it goes by which way you face the wall, never by how far the camera is tipped:
facing it W climbs, looking along it W goes along and the key on the wall's side
climbs, and facing away W comes back down. While you are already on a surface
you only transfer to a new one by pushing into it, so walking beside a wall
doesn't throw you up it; in mid-air the spider grabs the first thing it touches.
Keep the key down across an edge and it keeps meaning the way you were going —
into a wall becomes up it, up a wall becomes on across the ceiling — until you let
go or swing the camera well round. Put a collider in the `no_climb` group to make
it unclimbable.

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
onto things. (Parked, like the release it once had on right mouse, which casts
now.)

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

**Call them home.** The **Pullback** spell brings every web you have in reach
flying back to you, and what was in each lands at your feet as **bundles** —
silk still on them, going nowhere, yours to drain whenever. So a larder isn't
somewhere you have to go and stand in the open; you cash it in from where you
are. A click on a web doesn't do that: a web is a surface like any other, and
left mouse on it is a grapple to it.

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
paid for the whole shelf at once.

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
a grapple would really land. An arc round the cross fills while the spell in hand
waits to be cast again, and while a throw is wound up.

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

## Spells, ranks and the spell tree

Right mouse casts what is in hand — the web, to start with — and holding winds it
up. The grapple is not a spell: it is left mouse, always, and waits for nothing.
Everything else is learned:

* **Catching and eating earn rank.** Anything taken for keeps — bundled, wrapped,
  or held in a web until it has fought itself out — is experience, more the bigger
  it was and more again for something that fights back; drinking it to the end is
  worth half as much again. A practice target is worth nothing. Apprentice Spooder,
  Adept, Journeyman, Master, Grand Spooder.
* **Each rank opens its row of the tree and two points.** **E** opens the tree. A
  point buys a skill in a row you have reached: a **spell** (Douse, Gust and the
  Pullback for an Apprentice; Summon Lightning and the Clay Pillar for an Adept;
  Fire Breath for a Journeyman), a spell's **second tier** (Deluge, Gale,
  Thunderhead, Inferno, Long Recall), an **interaction**, or a **shorter wait**.
  There are twenty-two points
  of it and ten to earn, so what you learn is the kind of spider you are.
* **The interactions are where it gets interesting.** **Wet Silk**: spit Douse
  through your webs and they are wet — blue, and a little thicker — and a wet web
  stands in fire — breathe on what it holds and only that burns — and keeps
  lightning twice as long. **Sodden Silk**: a wet web
  holds half as hard again. **Waterspout**: wind over a puddle lifts a whirl that
  holds the first thing it reaches — and wind over lava, a spiral of fire that
  holds it and burns it. **Live Silk**: lightning stays in a web, and
  the web strikes whatever touches it. **Live Lines**: lightning runs along your
  lines to every web they tie together.
* **Some come with the spells**, nothing to learn once you know both. **A wet web
  soaks**: called back or flung, a web Douse left wet soaks what it passes, ready
  for lightning. **Fire turns water to lava**: breathe on a puddle and it turns to
  lava where it lies, burning whatever stands in it for a few seconds. **A puddle is
  a lightning rod**: strike one and the strike breaks into six little bolts that
  race out across the water, twice as wide, wet or dry. **Lightning erupts lava**: strike a pool of it and it goes up in a
  column of fire, the strike running out round it as fire, stunning and burning.
  Which comes first decides: each is the second spell acting on what the first
  left behind — and some pairs have nothing, rather than a bigger number.
* **Five in the loadout.** The web is always in hand and five spells ride with it,
  on the disc. A spell learned goes into the loadout if there is room; the tree
  takes one out or puts one in.
* **The disc.** Hold **Tab** and the spells in hand come up in a ring round the
  cross while the world slows to a quarter; flick the mouse toward one and let go
  to take it in hand. The slow is for choosing — the mouse moves the disc's
  pointer, not the view — so every cast is still aimed by you. A **tap** of Tab
  swaps back to the spell you had before.

Every spell but the web and the Pullback hurts, and what it takes is health,
which is how hard a creature fights silk — so a spell is always a way of making
a catch easier. The level switch `all_spells_open` hands over every spell and
interaction at once with no limit on the loadout, for trying them out; tiers and
shorter waits are still earned.

Evolving by chance from what you eat is parked: the traits and their screen are
kept in the code, and a boss still gives you what it kept.

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

In a level with an `Ecosystem` the insects keep hours: moths, mosquitoes and fireflies come
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

## The places

Each place is built by a class of its own in `game/world/` and saved as a scene
beside it. They are all ruins under open sky, and all the same kit, much of it
stretched: an arch is the kit's doorway at the size of a storey, a seat row its
stairs the length of a wall, a pier its column three times as tall. Everything in
them is solid. You start somewhere with a view in, at one size with every spell,
and the HUD names the place as you arrive. Fall out of the world and you are put
back where you started.

* **The Colosseum** (`colosseum.tscn`, a hot late afternoon) — what the game
  opens. An oval of sand forty-eight metres by thirty-two, walled four high with a
  gate at each end and in each side; two tiers of seats behind the wall, cut
  through at every gate; a walk all the way round behind them, open to the sky now
  its vaults are gone; and the outside wall, three storeys of arches and an attic,
  twenty-two metres up, a column between every two arches. Along the south the
  outside wall has fallen the way Rome's did, storey by storey to nothing, with the
  stone in heaps. And the floor has given way in the middle: four metres down are
  the passages the beasts were kept in, their walls standing up to where the floor
  was. At the east end of the middle passage a stair goes on down under the arena,
  to a landing and the shaft into the dungeon (below). You start on the sand at the
  west end, looking down the arena.
* **The Cathedral** (`cathedral.tscn`, a grey sky about to rain) — a nave twelve
  metres wide between two rows of piers twelve high, an aisle behind each row, and
  the upper walls going on to twenty-two metres, every bay a window, held up from
  outside by flying buttresses with pinnacles on their piers. The transept crosses
  it, and the choir ends in a rounded apse. The west front is a great door, a rose
  window and a gable between two towers: the south one stands to its belfry and
  spire, the north one broke off halfway. The roof is gone, some piers lie across
  the nave, and a stretch of the north aisle wall has fallen outward. You start
  just inside the great door.
* **The Castle** (`castle.tscn`, dusk) — a courtyard forty-four by thirty-six
  inside curtain walls nine high with a walk along the top behind battlements, a
  round tower at each corner — two roofed, two broken off — and the gatehouse in
  the south wall with its portcullis stuck partway down. The keep is three hollow
  storeys with most of its floors gone and its south-west corner fallen away. The
  west wall is breached, with rubble sloping up into the gap from both sides; stairs
  climb to the wall-walk. You start just inside the gate.
* **The Aqueduct** (`aqueduct.tscn`, a bright morning) — eighty metres of arches
  fourteen high with smaller arches on them and the channel on top, twenty-two
  metres up and walled low either side: a path along the sky. Two spans have fallen
  into the river, leaving a gap of sixteen metres over the water — inside a
  grapple's reach. Further west the upper arches of one span are gone, a drop to the
  lower arch and a climb back up. A long ramp runs down to the grass at the east
  end; the ruined tower the water was gathered in stands at the west. You start on
  the grass by the river.
* **The Watchtower** (`watchtower.tscn`, high and windy) — three terraces stepped
  up a hill with stairs up each, broken walls along their edges and a ring of
  columns round the middle one, and on top a hollow round tower thirty-six metres
  high, ragged where its top came off. Inside, what is left of each floor clings to
  one side or the other. Two thirds of the way up, a stone bridge ran north to a
  lone pillar and broke in the middle. You start on the grass below the stairs.
* **The Temple** (`temple.tscn`, a clear afternoon) — the first thing built from
  the kit, kept for a dungeon of its own: a square court of sand walled four high,
  columns along the wall, a gate in each side, three tiers of stands with stairs up
  each, and a rim of open windows. Each gate leads through a cut in the stands to a
  shut door.

It is all white for now, and will be until the kit's colours are in: every piece's
material points at `Pieces/aap color palette.png`, which did not come with the
pieces. Put that file in `Pieces/` and the kit takes its colours — the stretched
blocks with it, because they are the kit's own pieces. The ground, sand, paving and
water are the project's own paints.

## The dungeon

The dungeon lies under the colosseum: floor after floor of rooms made by hand and
laid out at random. Get down into the passages under the arena, go east along the
middle one, and take the stair down. At its foot is a landing, walled and roofed,
and in the middle of its floor a shaft: the one in the roof of the first floor's
entrance, thirty-five metres under the sand. Drop down it, or climb down.
Somewhere on each floor is a room with a pit in it, and dropping down the pit
takes you to the next floor, laid out afresh and put down in the last one's place
— its entrance under the same shaft, so the stair always leads to the floor you
are on, and the way back up to the colosseum is always open. The HUD names the
stair and the floor you are on. Nothing lives down there yet.

`game/world/dungeon.tscn` is the dungeon on its own, with no colosseum over it: open
it and press **F6** and you start in the first floor's entrance, which is quicker for
trying floors out.

**Rooms.** Every room is the same square, twenty-four metres across, walled all
round and roofed — a spider climbs anything, so a room open to the sky is a room it
leaves. A side can have a doorway in its middle, four metres wide and six high and
the same in every room, so any two rooms meet; a doorway that leads nowhere stays
bricked up. There are seven, each a class of its own in `game/world/dungeon/` baked
to a scene beside it:

* **Entrance** (the way in) — the shaft you come down with the daylight, broken
  columns round where you land, and two braziers.
* **Hall** — four great columns round a dais in the middle, braziers on the dais,
  crates and barrels against the walls.
* **Gallery** — fourteen metres high, with a balcony all the way round at seven,
  stairs up to it from two corners, and a fallen chandelier in the middle.
* **Crypt** — low, the roof no higher than a doorway's frame, with thick columns,
  stone coffins between them and two candles.
* **Chasm** (a crossing) — a trench right across the room with spikes at the
  bottom, and the bridge over it broken in the middle: jump the gap, swing it from
  the pillars standing up out of the trench, or climb down and up. Its doorways are
  at the two ends only, so the way through is always over it.
* **Vault** (a dead end) — one doorway, two rows of columns, and a key and coins
  on a dais at the far end.
* **Pit** (the way down) — a shaft through the middle of the floor, glowing at the
  bottom, where the drop to the next floor is.

Open one in the editor to change it: floors are put down from the rooms' scenes,
so a change shows on every floor the room turns up on. Each room has marks where
creatures will stand (`Marks/Spawns`), and the vault one where loot will be left.

**Floors.** `FloorPlan` lays a floor out on a grid of four squares by four, the way
Spelunky lays its levels out. First a way through: from a room in the top row,
along the row and dropping to the next at random, down to a room in the bottom row
— so whatever else the floor holds, there is a way from where you come in to the
way down. Then rooms off the side of it, some of them dead ends, and now and then a
second doorway between two rooms already side by side, so a floor is not always a
tree. Squares left over are rock; a floor has eight rooms at least, and thirteen or
so as a rule. Each square then gets a room that fits its doorways, turned to line
them up, picked by what the room says it is for (its `ROLE`): a way in at the
start, a way down at the end, a dead-end room at most dead ends, a crossing now and
then where the way runs straight, and a room for anywhere for the rest.

The same seed lays out the same floor. Each floor's seed comes from the run's and
how deep the floor is, so a run is the same dungeon all the way down: set **Run
Seed** on the run — the `Dungeon` node in the colosseum, `Run` in `dungeon.tscn` —
to walk one twice, or leave it at nought for a new dungeon every time.

To add a room, write a class like the others — the scene it is baked to (`SCENE`),
the sides it has doorways on (`DOORS`), what it is for (`ROLE`), and a `build` that
puts its shell up with `Rooms.shell` and furnishes it — add it to `Rooms.ROOMS` and
bake it. The floor plan finds it there.

## The kit

`Pieces/` holds the kit: seventy-five pieces as `.fbx` — walls plain, with a door,
with a window and round a corner; pillars and columns; door frames; stairs and
ramps; fences and railings; floor tiles; blocks; and odds like a key, a coin and a
lever. They are built on a two-metre grid, and to the spider's scale as they are:
a wall is four metres long and four high, a door three high, and the spider seven
tenths of a metre.

Each comes in through `tools/kit_import.gd`, which every piece's import names. The
pieces came out of their files wherever they sat in the scene they were made in;
the import centres each one's footprint on its origin with its base on the ground,
and makes it a body on the world layer with a collider the shape of its mesh —
solid from both sides where the mesh is a sheet. So a piece dragged from `Pieces/`
into a scene stands where you drop it, and is something the spider can walk on and
stick silk to. The project's default for scenes names the same script, so a piece
added later comes in the same way. Godot does not reimport when only the script
changes, so after changing it, select the pieces and **Reimport**.

`Kit` puts a piece down by name from code. `KitBlock` is any of the pieces at any
size: its mesh stretched to fit, and a collider built from the same stretched faces
— so a doorway made three times as tall is still a doorway you can walk through,
and a wall forty metres long is one node. It is never scaled, because physics does
not like a stretched body. Most of every place is blocks; change one's `size` or
`piece` in the inspector and it follows.

`Site` (`game/world/site.gd`) is what every place shares: its sky — a few moods, all
holding the light down so the white kit shows its shape — ground out to where the
haze takes it, the spider with its HUD, the place's name for the HUD, and the
shapes places are laid out on and the rubble they are strewn with.

## What fights back

Nothing in the colosseum fights yet, but everything that did in the Hollow Wood is
still in the game, ready to put in a level.

Every attack is told before it lands — the creature stops, turns to you, and a ring
or a line in the attack's colour shows where it is going — then the strike, then a
moment it stands open, which is when to put silk on it. Each hostile has a bite and one move of its own:

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
takes three orb shots; with nothing left, one. **Fire Breath** is what wears it
down — a jet of fire out of your jaws that you sweep across what you look at —
and silk burns: it takes a fifth of its harm off something bare, and all of it off
something wrapped all the way or hanging in a web. So the loop is wrap, burn,
wrap. The silk goes up with it — a web or a line the flame touches burns away, and
what the web held drops out — so a web is somewhere to burn a thing once, not a
place to keep it while you do. Unless it is wet: a web you have doused stands in
the flame while what it holds burns.

And two bosses, named across the foot of the screen with their health and wrap:
**the Rat King**, which whirls and cuts every thread round it, calls blade rats and
pounces, and seals its lair until one of you is beaten; and **the Hollow Wyrm**,
which flies a round of its own, and dives, spits fire, tears silk down with a gust
and sweeps with its tail. Beating the Rat King gives you what it kept: Wing Buds,
a glide.

**Shrines.** Touch one and it is lit, and it is where you wake when you are
driven off. Rest at one (**F**) and you are whole again — and every hostile is back
on its feet at its mark. Driven off, the same: you wake at the last shrine you lit
and the place has stirred. Your webs stay. A boss that beat you is back at its
post; one you have beaten stays beaten. A door, once opened, stays open.

## A level can be alive

Put an `Ecosystem` in a level and the creatures in it live rather than wander. None
has one now — the hunting ground that did is gone — but it is all still there. A
day goes round in twelve minutes, with the time in the corner of the HUD: the sun
goes over and sets, the moon comes up after it, and the sky goes with them
(`DayNight`).

* **Everything gets hungry**, at its own rate, and goes to find what it eats:
  patches of forage — moss, toadstools, flowers, grass, berries — that it eats
  down and that grow back slowly; something smaller, which it hunts down, kills and
  eats where it fell; or anything dead, whoever killed it. Something hungry that
  can see nothing to eat goes looking, further out each time.
* **Everything is afraid** of what would eat it, and runs: from as far off as it
  can see the thing if it is hunting, and only up close if it is not. A wary one
  keeps clear of a spider big enough to eat it, too.
* **Dens** put their creatures out when the level opens and breed them on what
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

Every place's scene holds its pieces as real nodes, so anything in it can be
selected and moved in the editor. Its class — `Colosseum`, `Cathedral`, `Castle`,
`Aqueduct`, `Watchtower`, `Temple` — is the generator of record, saying where every
piece goes, and `tools/bake_level.gd` runs it and saves the scene. The dungeon's
rooms are baked the same way, each from its class in `game/world/dungeon/`, and so
is the dungeon's own scene, which holds only the sky, the spider and the run. The
colosseum's scene holds a run too, under the arena; either way the floors are put
down from the rooms' scenes as you play. Name places, rooms or
`dungeon` to bake only those:

```sh
godot --headless --path . --script res://tools/bake_level.gd -- --force castle aqueduct
```

Without `--force` it leaves a scene that is already there alone, because building
it again throws away anything moved by hand. Nothing is added to the tree while it
builds, so nothing in the level runs on the way: what is saved is what the
generator said and no more. The ruins are laid out with a fixed seed, so building
one again puts every fallen stone back where it was.

One thing to know if you add to a level: **only `@export` properties survive being
saved into a scene.** A value set in code on a plain `var` is there while the
builder runs and gone the moment it is baked — which is how the zones ended up
measuring nothing and the gates stopped opening the first time round. And a
change made *inside* an instanced scene — a piece, the spider — is not saved
either.

## Training posts

`TrainingDummy` is a creature on a post with its combat numbers over its head — how
much silk is on it, how long the venom has left, what that has done to its speed,
and what a web would have to hold to take it — and a fresh one stood up when you
finish the last. There are three in `game/data/training/`: one that stands still,
one that runs at a wasp's pace, and one that comes for you. They lived in the gym,
which is gone, and none is placed anywhere now. They are ordinary creatures, so
silk, venom, webs, hauling and eating all work on them as on anything else, and
their species live outside `game/data/prey/`, so they never spawn, fill the larder
or pass on traits.

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

A third checks the kit and every place built from it: that every piece comes in
as a body on the world layer, centred on its origin with its base on the ground,
and that a sheet is solid from both sides; that a block is the size it says, to
look at and to stand on, and a doorway made bigger is still a way through; that
the game opens in the colosseum; that in every place the spider stands where it
was put, a Huntsman with every spell open, under open sky, in a place the HUD
names, among stone that is all solid; and then that each place is the shape it
says — the colosseum walled with a gate at each end and side, its floor fallen
into the passages and its outside wall fallen on the south, with the spider walking
on the sand and standing in the passages, and a stair from the passages down to a
landing over the shaft into the dungeon, which the spider walks down to the landing
and drops down the shaft into Floor 1; the cathedral roofless with its great
door open and one tower broken; the castle's portcullis low enough to go under,
its breach open and stairs to its walls; the aqueduct's channel high and walkable
and broken by a gap a grapple can cross; the watchtower ragged at the top, its
floors inside and its bridge broken; the temple's gates, tiers, stairs and rim —
then that every room of the dungeon has its doorways where it says, bricked up
until they are opened and a way through once they are, solid wall everywhere else
and a roof over it, and what its job needs: a way in under a shaft, a way down that
knows the spider, a broken bridge over a drop, somewhere to leave the loot; that
two hundred floors each run from a way in on the top row to a way down on the
bottom, never fewer than eight rooms, every room reachable, every doorway open from
both sides into a room with a doorway there, and every room only where it is for,
the same seed laying out the same floor; and that the dungeon puts a floor down as
its plan says, with the spider at the way in, and dropping down the pit puts the
next floor down in its place, one floor and no further — in the colosseum, under
the same shaft, taking up the silk left on the floor above and none of what was
left up top — and that the training posts each stand a creature up, one that
stands, one that runs and one that bites, none seeing past its leash, with a
readout that says what a web would need:

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

A fifth casts every spell in the sandbox: the web as the first of them, the rest
learned in the tree — rank from catching and eating, points, rows, the loadout of
five and the tree on **E** — the strip that shows the hand, and what each spell does
— to what it lands on, and to the other spells and the silk it meets, before and
after the interaction that lets it. Lightning run down a wire to a
wasp across the room and left live in the web, a spit that leaves puddles where it
lands and the silk it goes through wet, a gust that blows a beetle into a web, the
whirl wind lifts out of a puddle holding the first thing it reaches, acid water, a
square pillar of clay that throws what stands on it — the spider included — and flings
the web it comes up under, a breath of fire swept from
one creature to the next that burns harder the more silk is on what it touches and
burns the silk with it — but not a wet web — and turns a puddle to lava, a strike
sent out round a puddle, lava erupting into a fire rod and lifted by the wind into
a spiral of fire, webs called back through what is in their way, the magic circles
each spell is drawn in, the number keys parked, the disc and the world slowing under
it, and the whole book opened at once:

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

And every place from a set of named views. Name a place after `--` to render only
its views, and views after it to render only those, for instance `-- castle gate
yard`; name nothing and every view of every place is rendered, which takes a while:

```sh
xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 \
    --path . --script res://tests/screenshot_world.gd
```

    --path . --script res://tests/screenshot_world.gd -- wood
```
