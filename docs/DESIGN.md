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
   SCOUT            BUILD             WAIT              FEED             GROW
 read a space →  spend silk on  →  prey blunders  →  wrap it, drain  →  biomass →
 find the traffic   a web that      into the web      it, refill silk    next size
 lane (vent,        fits that       (or you herd it                      tier
 gutter, doorway)   lane            into it)
        ↑                                                                  │
        └──────────── bigger body = bigger webs = bigger prey ←────────────┘
```

**Scout.** Prey moves along readable lanes: flies circle a lightbulb, ants walk
a skirting board, rats hug walls, pigeons land on the same three ledges.
Learning the lane is the puzzle.

**Build.** Webs are placed by anchoring silk to real surfaces. A web is only as
good as its anchors — span too far for your size and it sags, tears and drops
your dinner.

**Wait.** Dead time is designed out: while a web works you are building the
next one, repairing, or laying a lure. You can also actively herd prey by
dropping on it, so patient play and aggressive play both work.

**Feed.** Caught prey struggles and damages the web. You have a window to get
there, **wrap** it (cheap silk, stops the struggling, preserves the web) and
then **drain** it (turns it into biomass + silk). Leave it too long and it
tears free and the web with it.

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
* **Demolishing** your own web refunds ~50%, so experimenting is cheap.
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

1. **Shape — complete freedom.** You choose every anchor: where the web hangs,
   how big it is, what angle it sits at, what gap it spans. This is where the
   skill is, because it is really the skill of reading a room.
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
* **Damage**: struggling prey drains durability. Rain, wind, fire and brooms
  destroy webs outright.
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

### The camera stays welded to the spider
**Decided: first person, always, rolling with the body.** No third-person
option, and no comfort mode that keeps the horizon upright on a ceiling.

The whole point of the game is that you stop reading the world the way a person
does. If the camera quietly stays upright while you walk across a ceiling, the
ceiling is just a differently-textured floor and the fantasy evaporates. The
disorientation *is* the feature — it is the moment the player stops being a
tourist in the room.

It also settles a lot of downstream questions cheaply: no third-person rig, no
second set of animations to read at distance, no camera collision, and the
spider's body only ever has to look right from the inside.

### Still to come
The body itself is the missing half: eight legs with IK that actually reach for
the surface and take its angle. From first person that means legs working at
the edges of your vision — the Mirror's Edge trick — which sells the climb far
better than a third-person view of a model would.

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
| **Q** | Toggle web build mode |
| **Left Mouse** | Place anchor |
| **Right Mouse** | Undo last anchor (or leave build mode) |
| **F** | Finish and spin the web |
| **Mouse Wheel / Z / C** | Cycle web pattern |
| **E** | Interact — wrap prey, then drain it; re-arm a sprung snare |
| **X** | Demolish the web you are looking at (50% silk back) |
| **G** | Wire one web to another — press on each end |
| **B** | Keep the rig you are looking at as a design |
| **V** | Place a saved design — wheel to pick, left mouse to spin it |
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
Done: wall and ceiling climbing with surface-aligned movement and camera, and
the dragline — drop, pay out, reel in, swing, let go.
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
Left: re-fitting a placed design's anchors to local geometry, renaming designs,
tension silk, repair, web sacks, and saving built webs with the world.

**Milestone 5 — Zone two and the loop at scale**
Crawlspace zone, wasps as a predator, verticality, streaming between zones.

---

## 11. Design guardrails

* **The web is the gameplay.** If a feature does not make building, placing or
  maintaining webs more interesting, it is a later problem.
* **Never chase.** If the player is running after prey more than they are
  building for it, the trap design has failed.
* **Size must be felt, not read.** No stat screen moment should be needed to
  notice you grew — the camera, the geometry and the webs should say it.
* **Cheap to experiment.** Refunds, repairs and passive regen keep the player
  building rather than hoarding.
* **Readable lanes.** Prey movement must be legible from a distance; the player
  should be able to point at a spot and say "that's where it walks".
