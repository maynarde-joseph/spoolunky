# Spoolunky — Design Document

> You are a spider. You start the size of a coin in the corner of somebody's
> bedroom. You end the size of a car, hanging a web between two skyscrapers.
> The only way up is to eat.

---

## 1. The pitch

A first-person predator sim about **building traps, not chasing prey**.

You do not fight. You engineer. Your one verb is *silk*: you spend it to build
webs, bridges, triplines and snares, and you get it back by eating whatever
those webs catch. Every meal makes you bigger. Every size makes you a worse fit
for the room you are in — which is exactly how you get out of it.

The fantasy is **scale creep**. The crack under the bedroom door is an exit at
size 1 and a wall at size 4. The rat that was a boss at size 3 is food at
size 5. The world never changes; you do.

---

## 2. The core loop

```
   BUILD              LEAVE                RETURN              FEED
 string a web    →  zip away on your   →  something is     →  secure it, drain
 across a lane       own lines, build      stuck and            it, silk back,
                     somewhere else        fighting the silk    biomass in
        ↑                                                             │
        └────────── bigger body = longer lines = bigger prey ←────────┘
```

**Scout.** Prey moves along readable lanes: flies circle a lightbulb, ants walk
a skirting board, rats hug walls, pigeons land on the same three ledges.
Learning the lane is the puzzle.

**Build.** Webs are placed by anchoring silk to real surfaces. A web is only as
good as its anchors — span too far for your size and it sags, tears and drops
your dinner.

**Leave.** This is the part that makes the game move. Standing next to a web
hoping something wanders in is not gameplay, so the web works *while you are
not there*. You string it, you ride your own silk somewhere else, you build the
next one — and a trap going off is news that reaches you across the level.

Getting back fast is the skill that replaces waiting, which is why the traversal
half of the game is not a side feature: **your webs are both your larder and
your road network.**

**Feed.** Caught prey struggles and damages the web. You have a window to get
there, **wrap** it (cheap silk, stops the struggling, preserves the web) and
then **drain** it (turns it into biomass + silk). Leave it too long and it
tears free and the web with it — so the race back is real.

Securing a catch should ask something of the player rather than being one
keypress. Wrapping is the beat that wants it: something to fight against while
the thing under you thrashes, harder the bigger it is. Not built yet.

**Grow.** Biomass raises your size tier. Size is the single stat that gates
everything: silk capacity, span length, what you can bite, what you can lift,
what gaps you fit through.

---

## 3. Size tiers

Size is the progression system, the difficulty curve and the map key all at
once. Eight tiers, each roughly doubling body length.

| # | Name | Body | Eats | Silk | New capability |
|---|------|------|------|------|----------------|
| 1 | Spiderling | 8 mm | gnats, aphids | tiny | single strands, tripline |
| 2 | House Spider | 2 cm | flies, moths | small | sheet web, wall climbing |
| 3 | Huntsman | 6 cm | roaches, beetles | medium | orb web, silk bridge, pressure snare |
| 4 | Gutter Spider | 18 cm | mice, sparrows | large | funnel lure, silk winch (drag prey) |
| 5 | Sewer Widow | 50 cm | rats, cats, pigeons | big | venom sacs, web tunnels, trapdoors |
| 6 | Park Recluse | 1.5 m | dogs, deer, people | huge | anchored canopy webs, ambush burrows |
| 7 | City Weaver | 4 m | cars, crowds | vast | structural webs across streets |
| 8 | The Architect | 12 m | whatever it wants | — | permanent territory webs |

Growth is **visible and physical**: the camera rises, your stride lengthens,
your webs get coarser and stronger, the level geometry shrinks around you. The
same bedroom you started in becomes a dollhouse.

### Growth is also a lock

Some gates want you **small**, not big — the drain pipe, the vent grille, the
gap under the door. So the player sometimes has to *stop eating*, or find the
big route. Later tiers get a "squeeze" ability that lets a big spider compress
through a gap at the cost of most of its silk, which turns old routes back on.

---

## 4. The world

Five zones, each a handful of hand-built rooms plus connective crawlspace.
It is open-world in the sense that a zone is fully explorable and you choose
your own route through it — but zones unlock in order, by size.

### 4.1 The Room (tier 1–2) — *tutorial*
A child's bedroom, seen from skirting-board height. Dust, a radiator, a
lightbulb with a moth orbiting it, a spilled juice box drawing ants.
Teaches: anchors, strands, first sheet web, feeding.
**Exit:** the wall vent, once you can climb (tier 2).

### 4.2 The Walls & Crawlspace (tier 2–3)
Inside the house's skeleton: joists, pipe runs, insulation, a wasp nest as a
mid-zone threat. Vertical, dark, made for orb webs across pipe gaps.
Teaches: 3D web building, verticality, avoiding a predator (the wasps).
**Exit:** the downpipe into the drain.

### 4.3 The Gutter & Sewer (tier 3–4)
Wet, flowing, hostile. Running water destroys webs, so you build high and dry.
Rats travel in packs — your first prey that fights back and your first real
use of the pressure snare.
**Exit:** a storm grate into daylight.

### 4.4 The Park (tier 4–6)
The first open space. Trees, a pond, bins, a playground, dog walkers at dawn
and dusk. Wind now matters: webs sway and long spans need more anchors.
Day/night cycle begins — birds by day, bats and moths by night.
**Exit:** the storm drain under the road, or simply walking into the street.

### 4.5 The City (tier 6–8) — *endgame*
Alleys, fire escapes, scaffolding, the underground station, and eventually
rooftops. People notice you. Pest control, then police, then something worse.
Territory webs: permanent installations that passively harvest prey while you
are elsewhere.

---

## 5. Silk — the economy

Silk is the only currency and the only meaningful constraint.

* **Capacity** scales with size tier.
* **Regeneration** is slow and passive (a trickle), so you can always
  eventually rebuild — never softlocked, just slowed.
* **Feeding** is the real source: draining prey returns silk proportional to
  its biomass.
* **Demolishing** your own web refunds ~50%, so experimenting is cheap. Pulling
  a web down leaves its frame lines standing — you only get back what you spent
  on the weave.
* **Repairing** a damaged web costs a fraction of the original.

Every buildable thing has a cost in metres of strand and square metres of
sheet, so a big web is expensive both to build and to hold in your head. The
interesting decision is always *"one good web or three cheap ones?"*

### Silk types (unlocked by tier)
| Type | Unlock | Property |
|------|--------|----------|
| Dragline | 1 | structural, non-sticky — bridges, safety lines |
| Capture silk | 1 | sticky, holds prey |
| Sheet silk | 2 | cheap area coverage, weak hold |
| Tension silk | 3 | stores energy — powers snares and trapdoors |
| Cable silk | 5 | heavy structural, long spans, needs deep anchors |

---

## 6. Webs and traps

Webs are **built, not placed**: you anchor silk to surfaces point by point, so
every web is shaped by the room it is in. Two or more anchors make a *strand*,
three or more closed anchors make a *net*.

### The catalogue

| Web | Shape | Unlock | What it does |
|-----|-------|--------|--------------|
| **Trip Line** | 2 anchors | 1 | Doesn't hold. Pings you when something crosses it and briefly slows it. Dirt cheap — the scouting tool. |
| **Sheet Web** | 3+ anchors | 1 | Basic catcher. Cheap per area, weak hold, tears fast. The bread-and-butter web. |
| **Orb Web** | 3+ anchors | 2 | The classic. Expensive, strong hold, high durability, catches fliers well. |
| **Pressure Snare** | 3+ anchors | 3 | Built under tension. Triggers on contact: yanks the prey off the ground and holds it rigid for several seconds — long enough to cross a room. Must be re-armed with silk after each catch. |
| **Funnel Lure** | 3+ anchors | 4 | Emits a scent/vibration field that pulls wandering prey toward it. Turns a dead corner into a lane. |
| **Silk Bridge** | 2 anchors | 3 | Walkable strand. Traversal, not trapping. |
| **Trapdoor** | 3+ anchors | 5 | A camouflaged hatch over a hole; prey walks over it and drops into whatever you built underneath. |
| **Web Sack** | anchored point | 4 | Storage. Park a wrapped kill in it to eat later — keeps biomass fresh, hides it from scavengers. |

### How much control the player gets

**Decided, and it is a three-layer split:**

1. **Shape — complete freedom, and you have to go there.** You choose every
   anchor, and placing one means **grappling to it**, dragging silk behind you.
   The frame of a web is not an outline you drew at arm's length; it is the
   route you took. This is where the skill is, because it is really the skill
   of reading a room and then getting around it.
2. **Weave — preset, in one of two styles.** The pattern decides how the inside
   is filled and how it behaves. Patterns are *techniques*, not blueprints. The
   two styles are a live switch (**K**) while we work out which the game wants:

   * **Stretched** — the web is the shape you drew. The capture spiral runs all
     the way out to the anchors, so a five-sided web across an awkward gap is a
     genuinely five-sided web. Wonky, characterful, and the current default.
   * **Inscribed** — what a real orb weaver builds: an even round spiral as big
     as will fit inside the frame, with the spokes carrying on past it out to
     the anchors. Nothing is ever stretched out of shape.

   Inscribed adds a skill that stretched does not have: the catching area is
   the biggest circle that fits, so a fat outline is worth far more web than a
   long sliver of the same span — about ten times more in a straight test.
   Stretched has the personality; inscribed has the craft.
3. **Combination — where "designing a trap" actually lives.** See below.

Thread-by-thread control over the inside of a web is deliberately **not** on the
table. It is a CAD problem rather than a game verb, it collapses into "more
threads is always better", and it destroys the thing both the player and the
prey AI need most: being able to glance at a web and know what it does.

The exception is single strands — triplines, draglines, bridges. One line *is*
legible, so those stay fully manual. The rule of thumb: **manual at the thread
level for lines, pattern-driven for areas.**

### Webs are placed, not enclosed

The version before this one had you grapple lines around a space until they
crossed and enclosed an area, then look at that area and fill it. It is a
lovely idea and it does not survive contact with a player: making a closed ring
of silk by moving around a room is something that happens *by accident* at
best, and then you have to go and find the ring again to use it.

So webs are placed. **Aim, hold Q, let go.** The plane faces you — what you see
is where it goes — and every corner of the rim runs outward until it meets
something.

The important part is what holding the key actually means: it sets how far a
corner is *allowed* to reach, not how big the web will be. The room decides
where each one stops. So the same press gives a full circle in open air and a
web that fills the angle when you point into a corner, and a doorway produces
something doorway-shaped rather than a disc hanging in the middle of it.

That is the whole of "design your web" in this game now, and it comes out of
moving and looking rather than out of a menu. Where you stand and what you
point at *is* the design.

The ring-filling code is still there and still tested; it just is not how webs
get made any more. If a player *does* happen to enclose something, filling it
remains possible.

**Silk is the other ceiling, and it stops the web growing rather than refusing
it at the end.** The ghost simply stops getting bigger, with the price on
screen. Holding a key down for a second and a half and *then* being told you
cannot afford it is a nasty way to find out you are broke.

**Web size is now what the size tiers gate.** That is a much more legible
reward than the thing it replaced (a longer anchor span): you can see your webs
getting bigger as you grow, and a bigger web is straightforwardly better at the
one job a web has.

### Building has no mode

Playtesting said building was slow, tedious and boring, and it was right. The
old flow was: enter a mode, click an anchor, click another, click another,
press a key to weave, leave the mode. Five decisions for one web, four of them
bookkeeping.

The verb is now one click. **Left mouse grapples you to whatever you point at
and drags a line behind you**, always, with no mode around it. Getting about
*is* building, so the silk is a record of where you went rather than something
you stopped to construct. The only deliberate step left is the one that is
actually a decision: look at a gap your lines enclose and press **Q** to fill
it.

**Range is not a size tier.** Reach was capped at the tier's `anchor_range` —
3.2 m as a spiderling — which meant getting anywhere was a chain of little
hops, and that was most of what made building feel like a chore. Grappling now
reaches as far as you can see. What the tiers still gate is what your silk can
*hold*, how much you can spin and what you can bite; those are the limits that
make growing mean something. Where you may go is not one of them.

The catch is that a long grapple at a spiderling's 6 m/s would be a nine-second
commute, so grapple speed scales with distance and everything lands in about a
second. Distance costs silk, not patience.

That also settles what a mode is *for* in this game. A mode is worth it when it
changes what the mouse means for a while — the bag (**N**) and design placement
(**V**) qualify. Wrapping the main verb in one never did.

### Building is travelling

Clicking an anchor hauls the spider to it and leaves a **frame line** behind —
real silk, standing in the world, that exists whether or not a web ever gets
woven into it. Three consequences, all of them good:

* **All silk is a road.** Every strand in the game can be clipped onto and
  ridden — there is no ridable flag, because there is no kind of line that is
  not also a zipline. Walking a triangle into a corner leaves you three of them
  whether or not you weave anything, so building and traversal are the same act.
* **Silk prices itself.** You pay per metre for the line you dragged, which is
  the most intuitive rule the game could have, and weaving the inside is a
  separate charge. That settles a question we had open for a while: the frame
  costs because you walked it, the fill costs by the thread.
* **The web outlives nothing; the roads outlive everything.** Tearing a web down
  leaves its frame standing. Traps are temporary, the network is not.

### A spider lives on its web

Webs are solid enough to stand on. The spider sticks to a finished web the same
way it sticks to a wall, walks about on it, and deals with whatever is caught
from on top of the silk rather than hovering beside it.

That needs silk to be solid to the spider and not to anything else, so silk
surfaces sit on their own collision layer: the spider collides with it, prey
does not. Otherwise the moment a web is firm enough to hold a spider it is firm
enough to bounce a fly off, and nothing is ever caught. (Silk bridges had
exactly that bug before this — they were quietly blocking prey.)

It also means a web works perfectly well **flat on the ground**. A floor trap is
just a ring whose plane happens to be horizontal: things walk onto it and stick,
and the spider walks over it without falling through. No special kind of object
is needed for it.

### Anything enclosed can be filled

Weaving is not limited to a loop you just walked. Every strand you own is an
edge in one graph, and lines count as joined **where they cross in mid-air as
well as where they share an end** — so sling three lines across a shaft and the
triangle where they overlap is a place you can put a web, even though none of
those lines touches another at a tip.

Look at any ring of silk in the world and press **F** to weave it. The silk
around it is already up, so only the inside is spun and charged for. Rings are
found by walking the graph for the shortest loop through each edge, which finds
the small ones — the gaps you would actually want to fill rather than the huge
outline around everything.

This is what makes silk feel like a material rather than a menu. You string
lines because you want to get somewhere, and the shapes they happen to make
become places worth putting a trap.

You can only build where you can physically get to. With climbing that is
almost everywhere, and it is a far better constraint than an arbitrary reach.

### Trigger links

A web can be **wired** to another web. When the first one goes off, the signal
runs down the line and the second one reacts. This is what turns a pile of webs
into a machine, and it is what makes traps work while you are somewhere else.

* A **snare** that gets a signal *whips out*, dragging in prey within about
  three times its own radius. That reach is the whole point: left alone, a
  snare only catches what blunders into it, so wiring one up lets you catch
  something that was never going to touch your silk.
* **Anything else** that gets a signal **tenses**: it pulls taut and holds
  roughly twice as well for a few seconds. So a tripline at the doorway can
  tighten the orb web across the vent a moment before the moth reaches it.
* Signals **chain**, so A sets off B sets off C, with a depth limit so a pair
  wired into a loop cannot ring forever.
* Firing spends a snare's tension whether or not it caught anything. Wiring a
  line badly wastes the arming, which is what makes placement a craft.

Signal lines are drawn as cold dashed threads, deliberately unlike structural
silk, so a player can read their own machine at a glance — and they flash when
a signal travels down them.

So a build looks like: tripline across the vent → wired to a snare over the
drain → funnel lure at the far end to steer things in. That chain is the game's
version of a loadout.

### The larder — a web is a store, not a moment

A web is somewhere you leave things and come back to. That is the whole reason
the game has ziplines and a signal bell — and it only works if a catch is still
there when you get back.

**A catch is won or lost in the first few seconds.** Prey hits the silk and
fights, hard, for about five seconds. If the web out-holds that whole thrash it
tires itself out and hangs there until you come for it. If it doesn't, the prey
tears loose and takes a bite of the web with it. Nothing escapes on a longer
timer than that: past the thrash, the catch is yours.

That turns hold strength into the tuning spine of the whole prey ladder, because
each web tier is built to keep the prey tier below it:

| Web | Keeps |
|-----|-------|
| Sheet web | a fly, and only just |
| Orb web | a moth |
| Pressure snare | a wasp |

Silk quality climbs with size, and multiplies hold, so every one of those lines
moves up as you grow — a City Weaver's sheet web keeps things a Spiderling's
orb web never could. A wired web that tenses just before the hit holds through a
thrash it would otherwise lose, which is a real reason to run signal lines.

**Webs have a capacity.** A sheet web holds two, an orb web four. A full web
stops catching. This is the pressure that makes you own *sites* rather than one
enormous web: the way to catch more is another web somewhere else, and the way
to know it's full is the bell.

**A settled catch still pulls.** Not much — but a full larder is a web slowly
wearing out, so leaving everything hanging for ever costs you the web and the
lot. Wrapping stops it dead, which is what makes wrapping worth silk: it is not
"secure the kill", it is *preservation*.

So the loop has a shape it didn't before: build a site, leave, get told, come
back to something waiting. That is the part that was missing.

### Devices — the things that aren't silk

Devices are carried, placed and picked back up. They are deliberately **not**
better webs. Silk already catches anything, at any angle, anywhere, for a
renewable price — so the only honest room left for an item is doing something
silk *cannot*. Anything a device does that a web could also do is a device that
should not exist.

They are finite and found rather than spun. That is the whole limit on them:
no silk cost, no cooldown, just "you have two left". And they are
[`SilkNode`](../game/web/silk_node.gd)s, exactly as webs are, so the wiring
already in the game works on them with no special case — a tripline can set off
a device, and a device can set off a web.

| Device | What silk cannot do |
|--------|---------------------|
| **Venom Spur** | *Kills.* A dead thing can be drained whatever its size, so a spur wired to a trap beats the bite-power gate. Silk only ever **holds** something until you get there. One shot. |
| **Scent Lure** | *Pulls, with no web.* Reaches much further than a funnel web and needs no silk around it. Drop one where you want traffic and traffic appears. |
| **Signal Bell** | *Reaches you.* Wire it to anything and it tells you the moment that thing goes off, from anywhere in the level. |

The bell is the one that pays for the whole loop. "Build a web, zip off
somewhere else, come back later to deal with the prey" only works if something
tells you *when* — otherwise coming back is guesswork, and guesswork is
waiting, which is the thing this game is not allowed to be.

The spur is the one that changes a rule. Up to now, prey above your bite power
was a wall you could only pass by growing. A spur turns that wall into a
**problem with a cost**: you can take the thing that is too big for you, but it
costs you the spur, and you had to have already got it into a trap.

Place mode is its own mode (**N**), thinner than build mode on purpose: there
is no shape to draw and no silk to price, so it is pick, look, click. The
interesting part is not the placing, it's the wire you run afterwards — which
is the same **G** it has always been.

### Saved designs

Point at any web and keep it. The whole rig it belongs to goes with it — every
web wired to it, however many hops away — recorded as the shape they sit in
*relative to each other*, not where they happened to be. Put it down again
anywhere and the rig re-spins facing the way you are looking, wiring included,
charged at today's silk prices rather than what it cost the first time.

That is the half of "design your own traps" that the catalogue cannot give you:
the shipped patterns are techniques, but a *rig* — tripline into a snare over
the drain — is the player's, and now they can keep it and use it again.

Designs are plain resources in the user folder, the same as the patterns the
game ships with, which is what made this cheap to build.

**Known limits, both worth fixing:**
* Anchors are replayed exactly as recorded rather than re-fitted, so a rig
  placed in a differently-shaped corner keeps its original shape and can end up
  with anchors in mid-air. The fix is to save each anchor's surface normal too
  and snap it to nearby geometry on placement, falling back to the recorded
  point. The ghost preview means the player can at least see this coming.
* Designs are auto-named from their patterns ("Trip Line + Pressure Snare").
  Renaming needs a text field over a captured mouse, which is real UI work.

### Tuning dials

Three dials, set before you spin. **Every one of them is a trade** — that is
the whole rule. A dial that only makes a web better is not a decision, it is an
upgrade button, and the player would just max it and stop thinking.

| Dial | Turn it up | What it costs you |
|------|-----------|-------------------|
| **Tension** | holds harder | tears sooner — a tight web grabs a rat and shreds |
| **Weight** | stronger in every way | more silk per metre, every time |
| **Mesh** *(opening it out)* | cheaper: fewer threads | small prey walks straight through |

Mesh is the one with teeth. An open mesh is *literally fewer threads*, so it
costs less silk without needing a price multiplier — the geometry does the
pricing — and it raises the smallest thing the web will hold. That protects an
expensive snare from being sprung and shredded by gnats before the rat arrives.
A close mesh catches everything, which is a blessing and a curse.

Two of the three change how the web is woven rather than just what it does, so
a tuned web **looks** different: heavy silk is visibly thicker, an open mesh is
visibly sparser. A dial you can see is a dial the player will actually use.

Dials are remembered per pattern, so an orb web you like spun tight stays that
way, and they travel inside saved designs — a kept rig is spun again exactly as
tuned.

**Under-exercised for now:** the mesh dial only really pays off once there is
prey of several sizes to filter between. With only flies in the sandbox it is a
correct mechanic waiting for the world to catch up with it.

### Next for trap design
Repair, tension silk as a separate unlock, web sacks, and re-fitting a placed
design's anchors to local geometry.

### Web physics rules
* **Anchors must be on real surfaces**, and a strand cannot exceed your
  tier's span limit. The frame is built on the anchors exactly where they are,
  in three dimensions — a web strung across a room corner tents through the
  fold and stays stuck to all three surfaces rather than slicing flat across
  it. Only the inscribed spiral cares about a flat plane.
* **Sag**: a strand near its max length hangs, loses tension and holds worse.
* **Damage**: struggling prey drains durability fast, settled prey drains it
  slowly, wrapped prey not at all. Rain, wind, fire and brooms destroy webs
  outright.
* **Weight**: a web can only hold prey up to a mass limit set by its silk type
  and anchor count. Over that, it tears — and heavy prey tears *through*,
  taking the web with it.

---

## 7. Climbing and the dragline

A spider that obeys the floor is just a short person. So the spider doesn't
have a floor — it has **whatever it is touching**.

### Sticking
Walls and ceilings are the same surface as the ground: the body's up axis
becomes the surface normal, gravity is replaced by a pull into the surface, and
the camera rolls with it. Walk into a wall and you walk *up* it. Keep going and
you carry on across the ceiling, upside down.

Two rules keep that from being annoying:

* **You have to mean it.** While you are already on a surface, the spider only
  changes allegiance to a new one if you are pushing into it — so you can walk
  along a skirting board without being flung onto the wall.
* **In the air, anything will do.** Falling or jumping, the spider grabs the
  first thing it touches. That is what a spider does, and it makes vertical
  space feel safe to explore.

Surfaces can opt out (`no_climb` group) — glass, grease, a hot pipe — which is
the hook for later puzzle geometry.

### The dragline
From a wall or a ceiling, the spider can drop onto a thread and dangle.

* Paying line out costs silk by the metre; reeling it back in recovers half of
  it, so a dragline is a real decision when you are poor, and free movement
  when you are rich.
* Hanging is a proper pendulum — the line is a hard constraint, and you can
  swing yourself sideways onto something you couldn't reach.
* Swing into a wall while pushing towards it and you grab it, line cut. Reel to
  the top and you're back on the ceiling. Or just let go.

This is the traversal answer to a world built vertically: you get *down* fast
and precisely, and back up at the cost of silk. It is also the best place in
the game to build from — hanging under a doorway, spinning a web across it.

### The camera: world-space look, and both distances

**Decided: look direction lives in world yaw and pitch, never in the body's
frame — and the camera defaults to third person, with first person on a key.**

The important half is the first one. Look used to be derived from the body: yaw
turned you around whatever surface you were stuck to. On the floor that is
identical to normal mouse look, so it seemed fine — but the moment you walk onto
a wall it silently remaps the mouse axes, and "left" stops meaning left. That is
why looking around on a wall felt wrong, and it is fixed by keeping the view in
world terms and letting the body follow the camera instead of the reverse.

Movement follows from the same decision: forward is *the way the camera is
looking, flattened onto whatever you are standing on*. Walk at a wall while
looking at it and you climb it, because looking into a surface leaves nothing to
flatten and it falls back to the camera's up.

The second half reverses an earlier call, twice reversed now, so here is the
reasoning rather than a quiet edit. Third person wins because **the size ladder
is the whole progression** and you cannot judge your own size from inside your
own head. A game about being a coin that becomes a car has to let you see the
coin. It also suits a goofy register: eight legs scuttling up a wall is funny to
look at and invisible in first person.

First person stays, on **L**, because it is better for lining up an anchor and
for the sensation of speed on a line.

The world no longer flips upside down on a ceiling, and there is no toggle for
it any more, because under a world-space look model there is nothing to flip —
the camera was never derived from the body in the first place. That sensation is
gone, and it was a real one. It cost less than scrambled controls.

### Ziplines
Any strand marked ridable can be clipped onto and slid along. Gravity does most
of the work — a line strung downhill builds real speed — the movement keys push
you along a level one, and letting go throws you off carrying everything you
had built up, with a small kick to clear the edge. Arriving on a line with
speed keeps it, so dropping onto one from a height flings you along it.

This is the traversal answer to a world built vertically, and the reason to
string silk somewhere you have no intention of catching anything. A line is
cheap, permanent and yours.

### Still to come
The body is a placeholder: primitives, with legs that swing in two alternating
sets when it moves. It is enough to read the spider's size and which way it is
pointing, which is what third person needed. A real one wants eight legs with
IK that reach for the surface and take its angle.

---

## 8. Prey and threats

| Class | Examples | Behaviour |
|-------|----------|-----------|
| **Drifters** | gnats, moths, flies | wander, attracted to light; tiny biomass, easy |
| **Trailers** | ants, roaches, mice | follow fixed routes along edges; predictable, good for triplines |
| **Fliers** | wasps, sparrows, bats | fast, 3D routes; need strong webs and high anchors |
| **Fighters** | rats, cats, dogs | will attack you if you are small; damage webs badly |
| **Hunters** | wasp nests, birds, pest control, people | hunt *you*; your web is your cover, not just your larder |

Everything you can eat can also eat you at the wrong size. The tension curve
is: each new zone opens with you as the smallest thing in it.

---

## 9. Controls (current build)

| Input | Action |
|-------|--------|
| **WASD** | Move — on whatever surface you are stuck to |
| **Mouse** | Look |
| **Space** | Jump off the surface |
| **Shift** | Sprint |
| *walk into a wall* | Climb it. Keep going for the ceiling. |
| **Ctrl** | Drop onto a dragline (from a wall or ceiling) |
| **Ctrl / Space** | Lower / raise yourself on the line |
| **Right Mouse** | Let go of the line |
| **Left Mouse** | **Go there, trailing silk.** No mode. Moving and building are one act |
| **Q** *(hold)* | Spin a web where you are aiming; held longer, it grows |
| **Mouse Wheel / Z / C** | Cycle which web you spin |
| **Right Mouse** | Let go of a line |
| **E** | Interact — wrap prey, then drain it; re-arm a sprung snare |
| **X** | Demolish the web you are looking at (50% silk back) |
| **G** | Wire two things together — web or device, press on each end |
| **N** | Open the bag — place a device (wheel to pick, left mouse to put down) |
| **X** | …and take one back up (a device under the crosshair wins over a web) |
| **B** | Keep the rig you are looking at as a design |
| **V** | Place a saved design — wheel to pick, left mouse to spin it |
| **F** or **middle mouse** | Clip onto a silk line and ride it — again to let go |
| **L** | Camera: third person or first person |
| **K** | Switch weave: stretched or inscribed |
| **;** | Pick which tuning dial the keys point at |
| **[** / **]** | Turn that dial down / up |
| **'** | Put a pattern's dials back to standard |
| **H** | Toggle help |
| **R** | Free-fly (debug, from the character template) |
| **T** | Release mouse · **Esc** Quit |

---

## 10. Build order

**Milestone 1 — Web building** ✅ *(this commit)*
Anchor-based web construction, procedural web meshes, silk economy, size
tiers that rescale the player, snaring prey, wrap/drain feeding, HUD.
Playable in the character-controller example level as a sandbox.

**Milestone 2 — Being a spider** *(half done)*
Done: wall and ceiling climbing with surface-aligned movement, a levelled
horizon, the dragline — drop, pay out, reel in, swing, let go — and ziplines.
Left: eight-legged procedural body with IK, seen from inside — legs reaching
for the surface at the edges of the frame. The camera stays first person and
rolls with the body; that is settled, see section 7.

**Milestone 3 — The Room**
A purpose-built tier-1/2 room at spider scale, real prey lanes, the vent exit,
the first "you are too big for this" moment.

**Milestone 4 — Trap chains** *(started)*
Done: trigger links — wire any web to any other, snares strike at range when
signalled, everything else tenses, signals chain. Saved designs — keep a whole
wired rig and re-place it anywhere.
Also done: tuning dials — tension, weight and mesh, each a trade rather than
an upgrade, remembered per pattern and carried inside saved designs.
Also done: carried devices — venom spur, scent lure and signal bell — placed
from a bag, picked back up, and wired into the same signal graph as webs.
Left: re-fitting a placed design's anchors to local geometry, renaming designs,
tension silk, repair, web sacks, saving built webs with the world, and somewhere
to *find* devices rather than starting with them.

**Milestone 5 — Zone two and the loop at scale**
Crawlspace zone, wasps as a predator, verticality, streaming between zones.

---

## 11. Design guardrails

* **The web is the gameplay — and the road network.** Silk catches things and
  silk carries you. If a feature does not make building, placing, maintaining
  or *travelling on* webs more interesting, it is a later problem.
* **Never wait.** If the player is standing next to a web hoping something
  wanders in, the design has failed. Traps run while you are elsewhere, and
  getting back fast is the skill that replaces patience.
* **Leaving must pay.** The corollary, and the one that is easiest to break by
  accident: if walking away costs you the catch, every other system pushing the
  player outward is wasted. A web holds what it caught.
* **Never chase, either.** Running after prey on foot means the trap did not
  do its job. Riding across the level because a trap went off is not chasing,
  it is answering.
* **Size must be felt, not read.** No stat screen moment should be needed to
  notice you grew — the camera, the geometry and the webs should say it.
* **Cheap to experiment.** Refunds, repairs and passive regen keep the player
  building rather than hoarding.
* **Readable lanes.** Prey movement must be legible from a distance; the player
  should be able to point at a spot and say "that's where it walks".
