# Spoolunky — Design Document

> You are a spider. You start the size of a coin in the corner of somebody's
> bedroom. You end the size of a car, hanging a web between two skyscrapers.
> The only way up is to eat.

---

## 1. The pitch

A first-person predator sim about **building traps, not chasing prey**.

You do not fight. You engineer. Your one verb is *silk*: you use it to build
webs, bridges, triplines and snares, and you get it back by eating whatever
those webs catch. Every meal makes you bigger, and being bigger is what opens
the way out — not because the room rejects you, but because the drain lid is
sprung for something heavier than you currently are.

The fantasy is **scale creep**. The rat that was a boss at size 3 is food at
size 5. The world never changes; you do — and the world is full of things
built for a body that is not yours, which start responding to you once your
body is enough.

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
there, **wrap** it (stops the struggling, preserves the web) and then
**drain** it (turns it into biomass, and takes the web with it if that was the
last thing in there — §5). Leave it too long and it
tears free and the web with it — so the race back is real.

Securing a catch should ask something of the player rather than being one
keypress. Wrapping is the beat that wants it: something to fight against while
the thing under you thrashes, harder the bigger it is. Not built yet.

**Grow.** Biomass raises your size tier. Size is the single stat that gates
everything: span length, what you can bite, what you can lift,
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

### Growth is the key, and never the lock

Growth only ever opens things. It is tempting to make some gates want you
*small* — squeeze under the door, through the vent grille — so that eating
becomes a decision. **Rejected, deliberately**, and it is worth writing down
why, because it is an idea that keeps coming back:

* It makes the player *avoid the core loop*. A game whose progression is eating
  must never give a reason to stop eating.
* It turns the escalation fantasy ambivalent. "I am enormous now" is the whole
  pitch, and it does not survive "…which is a problem".
* It forces backtracking into a world that is physically one-way (see §4).

So every gate reads the same direction: you could not do this before, you can
now. A door you are too big for is never the design; a door that needs more of
you than you have yet, always is.

### 3.1 The tree — what you spend the eating on

The rejection above has one real cost, and it took a while to see it: if the
only thing eating does is move you up a fixed ladder, there is **no decision in
the game at all**. You eat, you get bigger, the next door opens. That is a
progress bar with a spider on it.

So eating pays twice. A drained creature gives **biomass**, which still carries
you up the ladder exactly as before — and it also goes into the **larder**, a
tally of what you have eaten, by species. The larder is a currency, and it is
spent on the tree.

That keeps the one thing the rejection was protecting. Eating is never the
wrong move, because every creature is both growth *and* currency; there is no
build that wants you to stop. What changes is that **what you become** is a
choice, and a beetle spent on Broad Back is a beetle not spent on Hunting
Fangs.

Three branches, three deep:

| | **Bulk** | **Flight** | **Venom** |
|---|---|---|---|
| I | Heavy Frame — bigger, stronger silk | Wing Buds — a fall becomes a glide | Paralytic Bite — subdue one class up |
| II | Broad Back — bigger still, harder bite | Hollow Frame — **smaller**, faster, longer reach | Digestive Flood — far more out of a kill |
| III | Girder Legs — rope for silk | Storm Rider — ride a draught | Hunting Fangs — kill with no web behind it |

**Size is one branch, not the trunk.** Bulk *is* the old ladder, made into a
decision instead of a consequence. Flight is the other end of the same ruler:
Hollow Frame makes you 28% shorter than your tier, so you are not a smaller
spider, you are a **lean** one — a Huntsman that fits where Huntsmen do not.

This is how "being small is sometimes good" gets in without reopening the
argument above. You never *avoid* eating to stay small; you eat exactly as much
and spend it differently. The escalation fantasy survives intact for anyone who
wants it, because Bulk is right there and it is the straight road.

**A trait is a body, not a stat line.** Mechanically the whole tree is one
function: the size tier the game reads is the ladder's tier with every owned
trait multiplied into it. That is why almost nothing else in the code had to
learn traits exist — the climb component, the web builder, the thresholds and
the HUD were all already asking how tall the spider is and how far its silk
goes, and they now get an answer with the traits folded in. Buying one is
announced down the same channel as growing a tier, so the body resizes through
the code that already did that.

**Gates take either key.** A threshold names a size *and* may name a trait, and
either opens it — the vent flap gives to a House Spider or to a Hollow Frame
that folds between the slats; the dust cap gives to weight or to a Digestive
Flood; the storm grate gives to a Gutter Spider or to a Storm Rider riding the
draught through the slots. The gate never says which key you are missing. It
dips and settles back, the same as always, and the answer is what you go and
try.

**The screen.** Opened on **E**, which frees the mouse — so the same act that
lets you click the tree is what stops you firing silk into it. Locked traits
are shown rather than hidden, with what they stand on and what they cost,
because "you can always see the next thing and what you are short of" is the
one property of the genre this game is not that was worth keeping.

**What is deliberately not in it:** no respec, no points, no levels, and no
trait that is a flat number with no body behind it. If a trait cannot be
described as a change to the animal, it does not belong on the tree.

---

## 4. The world

Five zones, each a handful of hand-built rooms plus connective crawlspace.
A zone is fully explorable and you choose your own route through it; zones
come in order, and the order is your own body.

### The shape: a sequence of sandboxes, not a Metroidvania

Worth naming, because "Metroidvania" is the nearest genre word and it is the
wrong one. That genre's core pleasure is *returning* — you gain the ability,
you go back to the room you could not reach. Physical size escalation is a
**one-way ratchet**: once you are park-sized you will never fit up that
downpipe again, and no amount of design will make you.

So this is a **sequence of sandboxes**, each ended by outgrowing it. Katamari's
structure rather than Hollow Knight's. Two properties of the genre are worth
keeping and the rest is let go:

* **Legible gates.** You can always see the next place, and you always know
  what you are short of.
* **No timer.** Inside a zone there is total freedom and nothing is owed. No
  daily quota, no global clock — those would turn a game about making a place
  yours into a game about hitting a number.

What is given up is backtracking. What replaces it is **scale**: standing in
the park and looking back down the drain you came out of. That is the better
trade for this game, and it is the stronger pitch.

**The cost, stated plainly so nobody is surprised by it later:** each zone is
played *once*. There is no revisiting to stretch content over. So zones should
be **short** — the size jump is the reward, not the acreage. Build all five
fast and thin, then thicken whichever turns out to be fun.

### How a zone ends: the body is the key

A threshold is a **physical thing that responds to your body**, not a locked
door with a message. The model is the drain lid between the shed and the
sewer: it is a pressure lid, and it opens when something heavy enough stands
on it. Early on you stand on it and nothing happens. Later you stand on it and
it gives.

This is the whole direction system, and it needs no quest marker, no objective
text and no gate dialogue — not even a readout. The feedback is the thing
itself: stand on the lid too small and it **shifts slightly and settles back**.
That tells you it is a lid, that it is yours to open, and that you are not
enough yet, in one motion and no words.

**Built on size, not on weight.** It is tempting to give the spider a mass and
have the lid read it. Do not: mass would be derived from `body_height` and
nothing else, so it is a monotonic function of a number already in hand — "is
it heavy enough" and "is it big enough" become the same comparison in different
units, and the only thing gained is a second number to keep in sync. `body_height`
is already the one value everything physical hangs off. A gate names a size and
compares.

**Size is one key and not the only one.** A gate may also name a trait that
opens it (§3.1), so a spider that went up Flight or Venom instead of Bulk is
never stuck behind a door it can only grow into. Both keys open the same gate
and the gate still says nothing about which one you are missing — it dips and
settles back, and the answer is what you go and try.

And most gates should not even be that. **A gap you fit through or you do not
is the collider's business**, not a rule's — the spider's own shape against the
hole's, decided by the physics that is already running. Reserve explicit size
checks for things that *react* to you, like the lid; let geometry handle
everything that simply is or is not wide enough. The cheapest gate in the game
is a hole that was always that size.

It also solves push versus pull in one move. Nothing ever *expels* you: you can
live in the attic as long as you like, and it stays valuable because it is
where your network is. You leave because you can, and because the sewer has
things in it worth twice what the attic holds.

**You carry your belongings.** Moving on does not mean hauling your larder
through a pipe — the bag comes with you. What stays behind is the silk: the
network you built is the thing you cannot take, which is what makes each move
cost something without making it a chore.

### Each zone taxes silk differently

A zone is not a new mechanic, it is a **new pressure on the one mechanic**. The
question each zone asks is *how does this place erase silk?* — and the answer
is usually one multiplier on something that already exists.

| Zone | How it fights you | What it taxes |
|------|-------------------|---------------|
| Attic / Room | nothing — it is dry, still and cluttered | *learn here* |
| Walls & Crawlspace | dark, vertical, a wasp nest | anchors, and a predator |
| Gutter & Sewer | floods on a cycle you can read | spans — build above the water |
| Park | wind, rain, open space with no anchors | `durability`, and frames of your own |
| City | swept, cleaned, trafficked | persistence — nothing unattended survives |

The pressure a global clock would have provided belongs **inside one zone**,
not over the whole game. The city gets cleaned on a schedule; that is the
city's clock, not your life's. It is a place you raid rather than a life you
live, and the contrast is what makes the attic feel like home.

### 4.1 The Room (tier 1–2) — *tutorial*
A child's bedroom, seen from skirting-board height. Dust, a radiator, a
lightbulb with a moth orbiting it, a spilled juice box drawing ants.
Teaches: anchors, strands, first sheet web, feeding.
**Exit:** the wall vent — a flap on a weak spring, which stays shut until
there is enough of you to lean on it.

### 4.2 The Walls & Crawlspace (tier 2–3)
Inside the house's skeleton: joists, pipe runs, insulation, a wasp nest as a
mid-zone threat. Vertical, dark, made for orb webs across pipe gaps.
Teaches: 3D web building, verticality, avoiding a predator (the wasps).
**Exit:** the downpipe. A cap of matted dust and old web seals it; you go
through when you are heavy enough to fall through.

### 4.3 The Gutter & Sewer (tier 3–4)
Wet, flowing, hostile. Running water destroys webs, so you build high and dry.
Rats travel in packs — your first prey that fights back and your first real
use of the pressure snare.
**Exit:** the storm grate. A hinged pressure lid, sprung for a rat — stand on
it light and nothing happens, stand on it heavy and daylight.

### 4.4 The Park (tier 4–6)
The first open space. Trees, a pond, bins, a playground, dog walkers at dawn
and dusk. Wind now matters: webs sway and long spans need more anchors.
Day/night cycle begins — birds by day, bats and moths by night.
**Exit:** none needed. By now you are large enough that the park's edge stops
being a boundary and the street is simply the next thing you walk into.

### 4.5 The City (tier 6–8) — *endgame*
Alleys, fire escapes, scaffolding, the underground station, and eventually
rooftops. People notice you. Pest control, then police, then something worse.
Territory webs: permanent installations that passively harvest prey while you
are elsewhere.

---

### The interface scales, and is laid out once

The HUD is laid out in a **1920x1080 space and scaled** to whatever the window
is (`canvas_items` stretch, `expand` aspect). Every size in `hud.gd` is
therefore a fraction of the screen rather than a count of pixels, which is the
only way a size can be chosen once. Without it the bar and the text keep their
pixel size at every resolution: half the size they should be on a 4K panel,
half the width of a small one.

The default font is drawn as a **multichannel distance field**, so it stays
sharp at whatever scale the stretch lands on instead of being rasterised once at
the design size and then magnified. That magnification was the pixelisation.

Sizes live in one block at the top of `hud.gd` and are applied in code, not left
as per-label overrides in the scene — a size that lives in nine places is a size
nobody adjusts.

---

### 4.6 The testbed — a gym, not a place

`game/world/testbed.tscn` is the workshop, and it is what the project opens.
Nine stations on one flat floor, fifty-two metres by forty, all in sight of the
middle: corners for web fitting, three slots wide to narrow, a wall-overhang-
ceiling run with slopes at twenty through eighty degrees, grapple anchors at
one/three/seven/thirteen metres, a roof with a hole for draglines, two posts of
different heights for a zipline, the three size gates side by side, a prey pen,
and a hole in the floor for falling out of the world.

It exists because the real world (§4.1–4.5) is two hundred and eighty metres
across and mostly corridor, so checking whether a web fits a corner meant a
walk, and checking a *different* corner meant another one.

**The rule for adding to it:** a station tests one thing and says on it what
that thing is — the signs are the documentation, because a gym you have to read
a file to use is a gym nobody uses. If you cannot tell what a station is for by
standing in front of it, it needs a better shape, not a longer sign.

---

## 5. What is actually scarce

**There is no silk economy.** There was one, and it was the wrong instrument.
A budget makes the player afraid to spend, and the fear is worst exactly when
they have just missed — the moment the game most needs them to try again. It
also has to be *explained*: a number on screen, a regeneration rate, a refund
percentage, a quote before every web. All of that to answer one question the
player never asked.

Three things are scarce instead, and none of them is a number you save up.

### Lines: three at a time

Grappling leaves a line behind. You may have **three**, and a fourth takes the
oldest down. The question stops being "can I afford another" — which has a
boring answer, yes, eventually — and becomes **"which three do I want"**, which
is a question about the room you are standing in.

Three is small enough to hold in your head while moving, which is the only time
it matters. The line currently **holding you up is never the one that goes**:
it is skipped however old it is and the next one goes instead. Dropping the
floor out from under the player is the game taking the controls off them, and
that is the one thing it must not do.

### Webs: a wait, not a bill

Shooting a web starts a short cooldown, and that is its whole cost. A wait
costs you nothing you were saving, it comes back on its own, and a miss is over
in a few seconds rather than in however long it takes to refill.

It also killed a whole class of bug. Pricing a web before it exists means
quoting a number for a shape the bolt has not reached yet, which produced two
separate failures: one quoting 49 and charging 167, another quoting 89 and
charging 91. A wait is the same length whatever the web turns out to be.

### Webs end with their catch

A web is a **larder while it holds something and nothing once it does not**.
Take the last catch out and the web comes down with it; put another one up if
you want one there.

This keeps the larder (§6) exactly as it was — leaving a web to fill is still
the plan, and walking away still pays — while making the reward the moment you
spend. That is the right moment for a cost: you pay when you are being
rewarded, not when you are trying something.

**Escaping is not harvesting.** Something tearing loose leaves the web
standing. Losing a catch is the web losing; taking the web as well would be
losing twice for one mistake.

### Silk types (unlocked by tier)

Not a currency, and never was — a list of what silk can *be*, which is still
the plan. Only the first two exist today.

| Type | Unlock | Property |
|------|--------|----------|
| Dragline | 1 | structural, non-sticky — bridges, safety lines |
| Capture silk | 1 | sticky, holds prey |
| Sheet silk | 2 | cheap area coverage, weak hold |
| Tension silk | 3 | stores energy — powers snares and trapdoors |
| Cable silk | 5 | heavy structural, long spans, needs deep anchors |

### What this cost

Stated plainly: draining prey no longer returns anything but biomass, webs have
no refund, and the dragline, the tether and wrapping a catch are all simply
abilities now. Devices (§6) were designed as "the thing that isn't silk, and is
limited by the bag instead" — that contrast is gone, and they are now one
finite thing among several rather than the only one.

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
| **Pressure Snare** | 3+ anchors | 3 | Built under tension. Triggers on contact: yanks the prey off the ground and holds it rigid for several seconds — long enough to cross a room. Must be set again after each catch. |
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

### What the game turned out to be

After the building controls were rebuilt around placing rather than enclosing,
the loop settled into something the earlier drafts had been circling without
naming:

> **Grapple wherever you want, and spit webs onto surfaces and corners.**

Both halves of that are one button each, both work anywhere, and between them
they cover the two things a web is ever for:

* **Thrown at something that is right there.** Silk spun over a moth wraps it
  where it stood and the bundle drops to the floor, to be collected whenever
  you get round to it. The web goes with it — the silk *was* the wrap, so
  there is nothing left hanging on the wall afterwards. A throw that only
  half connected, catching something it could not wrap, leaves the web up,
  because then there is something in it. That makes silk a way of dealing with a thing in front
  of you and not only a thing you leave behind.

  Aiming at a thing puts the web over *that thing*, not on the wall behind it.
  A catch volume is a thin slab around the web's own plane, so a throw that
  lands where the crosshair's ray finally stopped would sail straight past the
  moth it was aimed at. The ghost centres on whatever is under the crosshair
  and the HUD names it, so the throw is visibly locked on before you let go.

  It is not a free kill, because it is the same number as everything else:
  a web only takes something outright if it can out-hold the whole fight that
  thing would have put up. Throw a sheet web at a wasp and you do not get a
  bundle — you get a wasp hanging in a sheet web, fighting, exactly as if it
  had flown into one. So which web you bring is the decision, and throwing is
  a *use* of a web rather than a way round needing a good one.
* **Left somewhere to work.** Pick a corner prey walks past, fit a web to it,
  and put a **Scent Lure** on the far side so traffic comes through the web to
  reach it. Wire a **Signal Bell** in and go somewhere else.

The second is the reason the devices exist and the reason the larder exists.
The first is what stops the game being all setup and no moment. A trap you
prepared and a web you threw are the same object under the same rules — which
is why the size tiers gate both at once: whether a web *holds* what hits it
comes from hold strength either way, so a sheet web thrown at a wasp loses it
exactly as a sheet web left for one would.

#### Two ways the web gets there

"Thrown" above is a figure of speech in the default mode: the web appears under
the crosshair the moment the key comes up, and the only thing between you and
it is aim. **M** switches that for a literal throw — a bolt of silk leaves the
spider, travels, drops a little on the way, and opens out to the size it was
charged to wherever it lands.

The two sit side by side on a toggle because they are different skills rather
than different numbers. Placing is a pointing problem and resolves instantly;
throwing is a leading problem, and a moth that was under the crosshair when you
let go may not be where the silk arrives. Nothing is spent until the bolt
lands, so a miss costs you the throw rather than the web.

Everything downstream is shared. The bolt hands its landing point and the
surface normal it found to the same fitting a placed web gets, so a thrown web
runs its rim out into the room it landed in exactly as a placed one does — and
a bolt that lands on a moth centres on the moth rather than on the skin of it,
for the same reason the placed ghost does.

### What kind of game this is

The mechanics settled before the genre did, so it is worth writing down what
they turned out to want.

Look at what is in here: catches persist while you are gone, webs have
capacity, a bell exists solely to tell you something fired while you were
elsewhere, lures reroute traffic through a spot you picked. Every one of those
only pays off if you set something up and walk away. **This is a trap-building
game**, not a character action game.

(For a while the nearest comparison looked like Schedule 1 — a daily quota
against a clock. That is settled the other way now: see §4. The trap-building
thesis below is unaffected; what changed is where the pressure comes from.)

That rules out one thing and sharpens another. It rules out a boss *fight*:
combat wants health, dodging and telegraphs, none of which exist, and the
spider's only offensive verb is wrapping something already held. Building that
would be building a second game, and the webs would shrink to scenery.

But a boss does not have to be a fight, and here it should not be. `ESCAPE_MARGIN`
already compares a creature's *entire* fight against one web's hold, so "a boss"
is already expressible as **something no single web can hold**. That makes it a
construction problem in the language the game already speaks: venom to weaken
it, a lure to put it where you want it, several webs rigged together, the road
network to move around it while it thrashes. An exam, not a duel.

### Creatures are resources

The first version had one creature with thirteen exported numbers on it, and
seven web patterns, three devices, tuning dials and two mesh gates pointed at
it. All of that is machinery for deciding *which* web goes *where*, and none of
it could decide anything, because every catch was the same catch.

So a creature is a [PreySpecies] resource now, exactly as a web is a
[WebPattern] and a device is a [DeviceKind], and one scene builds its body from
whatever the resource says. A new thing to catch is a .tres.

The five that exist are picked to switch on the machinery that was already
built, one gate each:

* **Fight** — what a web has to out-hold — is the ladder `ESCAPE_MARGIN` always
  claimed: a sheet web keeps a fly, an orb web keeps a moth and a beetle, a
  pressure snare keeps a wasp. Silk quality rises with size, so growing moves
  every one of those lines rather than just the numbers.
* **Where** is the beetle. It walks, so no web strung in the air will ever see
  one, and a moth lives near the ceiling where you have to go and put a web.
  Placement stops being cosmetic the moment two creatures live in two places.
* **Size** is bite power, which is what makes a venom spur worth carrying
  before you are big enough to eat a wasp. It is also the mesh, though the
  mesh stays a *dial* rather than something baked into a pattern: giving the
  pressure snare a size floor read well until it met the snare's other job,
  which is being triggered from across the room to drag in something that
  never touched it. A trap that refuses half of what it is pointed at is a
  worse trap, and the dial already lets you choose coarse and cheap over fine
  and dear.
* **Lures** are the wasp: the one thing that will not come when called, so the
  device that trivialises everything else has something it cannot solve.

The midge earns its place by being nearly worthless and very common — it is
what fills a web you left out, which is the thing the larder is for.

### A catch you can carry

Catching and moving were separate problems, and the gap between them was
quietly shaping the game. You could take something anywhere but only *use* it
where it fell, so a bundle on a floor across the level was a thing you walked
back to, and a larder could only ever be the web it was caught in.

A tether closes that. Hook a bundle and it comes with you, which makes a catch
into cargo and makes "carry it home" a verb the game has. Everything the
direction needs — a nest, a day you come back from, a catalogue you hand things
to — needs that verb first.

**Left mouse does it**, which is the part worth keeping. The button already
means "silk connects me to that", and what it does has always depended on what
you pointed at rather than on a mode you were in: a surface pulls you over to
it, a line puts you on it. Something you have already caught is the third
reading, and the only sensible one — hauling yourself across a room to stand
next to a thing that is wrapped up and going nowhere is not what the click
meant. A long shot pays out the whole distance and then winds back in, so
firing at something across the room harpoons it rather than yanking it to your
feet. The aim is deliberately tight, and capped the same way the line pick is,
because a click that merely passed a bundle on its way to a wall is a grapple
and has to stay one.

It is a **rope, not a rod**, and that is the whole feel of it. Slack does
nothing at all: walk towards the thing you are towing and the line sags onto
the floor and the bundle sits where it is. Only past the length of the line
does it pull, and then it *pulls* rather than snapping the cargo to a fixed
distance, so the weight swings in behind you and is still swinging when you
stop. The line is simulated as a real chain of points rather than drawn as a
straight segment, because a straight line between two points would say "rod" no
matter what the numbers did.

Weight is the cost, and it is the decision. Dragging a wasp home is genuinely
slower than dragging a fly, so hauling something back is weighed against eating
it where it lies — which is the first time in the game that *where* you deal
with a catch has been a choice at all.

Only finished business can be hooked: a bundle, a wrapped catch, something that
has worn itself out. A catch still fighting refuses the line, which gives
wrapping a second reason to exist beyond preservation.

That rule has a corollary the code was getting wrong in two places: **wrapped
is finished business, and finished business obeys gravity.** Venom set the
wrapped state without recording anywhere to hang from, and the stuck handler
drags a body towards that point every frame — so anything poisoned in open air
sailed off across the level towards the world origin wearing a cocoon. And a
wrapped catch whose web came down stayed exactly where the web had been,
hanging in the air. Both now become bundles the moment nothing is holding them
up, which is what a bundle already was: dead weight that falls.

### Silk is the road network

Every line is walkable, not only the ones spun as bridges — a bridge is simply
wide enough to be comfortable, and anything else is a tightrope, which is what
a spider is for. Silk is about half again quicker underfoot than the floor, so
a route you built beats walking round.

**Silk is sticky, and you leave it by jumping.** This took two goes to get
right, and the second one is the one worth keeping.

The first version gave every strand a thin collider and left you standing on
it, which meant falling off constantly. A rope you fall off is not somewhere
you can live, and the whole point of the network is that it is somewhere you
live. So the second version clipped you onto the line on contact and railed
you along it. That fixed falling off and introduced something worse: the game
grabbing hold of you. Walk near your own silk and it took the controls away.

What was wrong was not the holding, it was who asked for it. A spider does not
balance on its thread and it does not get railed along it either — it is
simply *stuck to it*, and it lets go when it decides to. So silk is sticky
now, as an ordinary surface: land on a thread and you are standing on it, and
it keeps hold of you until you jump, exactly like the wall and the ceiling
already did. A thread only runs one way, so that is the way you walk on it —
pushing across a line does nothing instead of walking you off the side — but
you set your own pace, face either way, and stop when you stop.

Riding is still there and is now something you *ask* for: press for it and you
clip onto the line proper, gravity feeds you down the slope, and letting go
throws you off carrying everything you built up. Two different things that
were briefly the same thing.

The key press is the *only* way into one. Grappling at a line still takes you
to the line rather than stringing a second line to reach it — that is the
difference between joining the network and extending it, and it is worth
keeping — but it now leaves you standing on it. It used to start the ride, and
because the pick is deliberately forgiving about aim, a click meant for the
wall behind a line would be quietly stolen by the line and turned into a ride
nobody asked for. Forgiving aim is only affordable when being wrong is cheap;
arriving somewhere you can stand is cheap, and losing the controls is not.

A *web* gets none of the one-way rule, because a web is a floor, and a floor
you can only cross in one direction is not a floor.

Grappling at a line you already have puts you *on* it rather than stringing a
second line to it. That is the difference between extending the network and
joining it, and it is what makes a web of lines feel like somewhere to get
about rather than a pile of rope.

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

The verbs are *move*, *go there*, and *make a web*. The bindings had grown to
twenty-five for those three things, so they were cut back to what a player can
hold in their head on the first screen.

| Input | Action |
|-------|--------|
| **WASD** | Move — on whatever surface you are stuck to |
| **Mouse** | Look |
| **Space** | Jump. Also the only way off silk, which is sticky |
| **Shift** | Sprint |
| *walk into a wall* | Climb it. Keep going for the ceiling. |
| **Left Mouse** | **Go there, trailing a line.** A surface pulls you over; a line puts you on it; something you already caught comes to you instead. Three lines at a time — a fourth takes the oldest down (§5) |
| **Right Mouse** *(tap)* | **Shoot a web.** A surface gets one built against it, something alive gets wrapped where it stands, a miss expires after two seconds. Then a short wait before the next (§5) |
| **Right Mouse** *(hold)* | **Wind up a ball of silk**, held over the spider's back where you can see it. Hold a creature in the cross for a second and the throw cannot miss it |
| **1–9 / wheel** | Pick a pocket on the bar |
| **E** | The tree — spend what you have eaten |
| **F** | Wrap the prey you are looking at, then drain it |
| **X** | Pull down the web or line you are looking at |
| **L** | Camera: third person or first person |
| **H** | Toggle help · **T** Release mouse · **Esc** Quit |

### Parked, not deleted

The hold-to-size placer, the tuning dials, the weave modes, saved designs,
trigger wiring, the bag mode and the tether all still exist, still compile and
are still tested — their input actions are simply bound to nothing. Each is one
line in `project.godot` to bring back once the simpler feel is proven, and
nothing that works was thrown away to find out.

There is deliberately **no glide key**. A spider with wings glides, the same
way a spider with legs walks: the trait changes how you come down, and holding
something down is not part of it.

### Shooting has to be catchable

The bolt is a **ball of silk with a width**, not a ray. The world is still hit
exactly — a web has to land on the surface it is built against, and a wall
deserves no forgiveness — but anything alive is hit with a swept ball a good
deal wider than the web being thrown. A fly is five centimetres across and
wandering; asking a player to put a hairline through one is asking for a
precision no amount of practice reaches, and for a while the honest report was
"I spent a few minutes shooting and could not catch anything".

The **one-second lock** is the other half of the same problem, and it is a
choice rather than a fix. A tap is the fast, fallible shot and is unchanged.
Holding winds up a ball of silk over the spider's back — a wizard with a
fireball — and a second spent holding a creature buys certainty. The bolt then
steers all the way in, because a promise kept by the arithmetic at the trigger
is a promise broken by the first gust of wandering.

**The camera does not move for it.** Aiming used to drop to first person, on
the reasoning that third person has the cross and the silk leaving from
different places. That is true and it turns out not to matter: a thrown ball
leaves the spider *toward whatever the cross is over*, which is exactly what
the third-person aim already works out. What the flip cost was the one thing
worth having — watching the spider wind up. The ball grows as the second fills
and brightens when the lock takes, so the charge has a reading in the world as
well as on the HUD, and you never have to look away from the fly to read it.

The cone that *acquires* a target is tighter than the cone that *keeps* one.
Holding a cross exactly on a wandering fly for a whole second is not a thing
anyone can do, and it is not what the second is for: the second is for
choosing, not for steadiness.

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
  player outward is wasted. A web holds what it caught — and only ends when
  *you* empty it, never when something gets away.
* **Never chase, either.** Running after prey on foot means the trap did not
  do its job. Riding across the level because a trap went off is not chasing,
  it is answering.
* **Size must be felt, not read.** No stat screen moment should be needed to
  notice you grew — the camera, the geometry and the webs should say it.
* **Cheap to experiment.** Nothing is saved up, so nothing can be wasted. The
  limits are a count and a wait (§5), both of which come back on their own —
  a player who has just missed must never be poorer for it.
* **Never a budget.** A resource bar makes the player afraid to spend, and the
  fear is worst exactly when the game most needs them to try again. Limit by
  *how many at once* or *how soon again*, never by *how much is left*.
* **Readable lanes.** Prey movement must be legible from a distance; the player
  should be able to point at a spot and say "that's where it walks".
* **Growth only ever opens.** No gate wants the player smaller, and nothing
  ever rewards not eating. A game whose progression is eating must never give
  a reason to stop. The tree (§3.1) is how a small body became possible without
  breaking this: you spend the eating differently, you never do less of it.
* **A trait is a change to the animal.** If it cannot be described as something
  the spider grew, it does not belong on the tree. No flat percentages with
  nothing behind them, no respec, no points — and nothing that is only a number
  on a screen the player has to go and read.
* **Gates are physical, and say nothing.** A threshold is a thing in the world
  that responds to your body — a sprung lid, a weak flap, a drop you can now
  survive. If it needs a line of dialogue or an objective marker to be
  understood, it is the wrong gate. Prefer a shape the collider decides over a
  rule that compares; prefer a rule that compares `body_height` over inventing
  a second number to compare instead.
* **Nothing expels the player.** Zones are left because somewhere else is
  better, never because this one stopped working. The first place must stay
  worth having, because it is where the network is.
* **No clock over the whole game.** Time pressure belongs to *one place* — the
  city gets cleaned; your life does not have a deadline. A global quota would
  make this a game about a number.
* **Zones are played once, so keep them short.** There is no backtracking to
  stretch content over. The size jump is the reward; acreage is not.
