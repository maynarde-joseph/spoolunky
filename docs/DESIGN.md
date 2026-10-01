# Spoolunky — Design Document

> You are a spider. You start the size of a coin in a hollow stump at the edge
> of a wild valley. You end the biggest thing in it, with the wyvern that hunts
> the whole valley hanging in your web. The only way up is to eat.

---

## 1. The pitch

A first-person predator sim about **building traps, not chasing prey**.

You do not fight. You engineer. Your one verb is *silk*: you use it to build
webs, bridges, triplines and snares, and you get it back by eating whatever
those webs catch. Every meal makes you bigger, and being bigger is what opens
the valley — not because anything shuts you in, but because everything past the
ferns is bigger than you, and eats spiders.

The fantasy is **scale creep**. The rat that was a boss at size 3 is food at
size 5. The world never changes; you do — and the world is full of things
built for a body that is not yours, which start responding to you once your
body is enough. Nor does it wait for you: everything in it is eating something,
and it breeds, rests and roams whether you are watching or not (§8.1).

And you become what you eat. Any meal can change you — wings from the things
that fly, venom from the things that sting — and the bigger it was next to you,
the likelier. Take down something you had no business taking on, and it always
does (§3.1). What you become is what you can cast: the thrown web is the first
spell, and venom, water and lightning follow, each working off the others and
off the silk (§3.2).

**A second shape is being tried: the Hollows** (§12), and it is what the project
opens now. Dungeons pressed together into one world the way a souls-like's are,
everything in them hostile and fighting back with attacks you learn to read, the
spider one size the whole way through, and shrines to come back to. The valley
is still there, and still the game this document mostly describes; the Hollows
are a prototype of where the game is meant to go, built to see whether the shape
works before anything is made to look good.

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

### The hunt loop, and why a web is worth building

The loop above is the *trap* loop. There is a second one that runs faster, and
for a long time it made the first one pointless:

```
  HUNT             HAUL                HOME               DRINK
 shoot or bite  →  tether it and   →  your own web,   →  hold the key.
 something         run for it          which catches      A few seconds
 out in the open                       what follows you   you are standing still
```

The problem it fixes: eating used to be one keypress and instantly over, and the
biomass was identical whether the creature had been caught in a web you built or
wrapped by a bolt you threw at it. So the fastest way to eat was to walk up to
something and click, and the entire trap layer — tuning, triggers, saved designs,
devices — was decoration. **A web has to be worth building, and paying more for
one only makes it a better lottery ticket.**

Three changes, and they only work together:

* **A meal takes a few seconds.** Hold the key and biomass flows; let go and you
  got part of it, with the rest still on the end of your line. So eating is time
  spent standing still, which is the first thing in the game that has ever made
  *where* you are matter.
* **Things bite back.** A creature inside your bite power is food; one outside it
  and aggressive comes looking for you. Being bitten costs you the mouthful, and
  running out of stamina drives you off — you drop what you were carrying and get
  thrown clear.
* **But a hunt runs out.** A hunter moves at `CHASE_DASH` (1.5×) its own speed,
  and it only bothers with you while you are *under* its size — so the thing
  chasing you is always faster than you are. Giving up was distance-only
  (`hunt_range * 1.8`), which is a gap something faster than you never lets you
  open, so the only real answers were silk and outgrowing it. That is one answer
  too few: it reads from in front as a creature that simply will not stop, which
  is what a fresh spiderling meets first. So the sprint is finite — `CHASE_STAMINA`
  seconds, the last 40% of it at `CHASE_SPENT` (0.45×, deliberately slower than
  any spider, so the window is *visible* from in front) — and then it breaks off
  and leaves you alone for `CHASE_COOLDOWN`. Running buys you the end of a chase,
  not safety, so silk stays the good answer rather than the only one.
* **Your web is somewhere to stand and eat.** Anything that comes at you through
  silk goes into the silk first. Not a fortress: whether it *holds* is the same
  `hold_strength × ESCAPE_MARGIN` sum every other catch uses, so a wasp sticks in
  a sheet web for about two seconds and then tears out, wearing the web down as
  it goes. What a web buys is those seconds, and it spends itself buying them.

* **Silk accumulates.** Wrapping used to be all or nothing: either the silk was up
  to the whole fight a creature would put up, or it did nothing. A bolt that cannot
  take something outright now leaves `bound` on it — a share of the way, worked out
  from the same two numbers that decide a clean take, so "how many hits does this
  need" answers itself. Binding saps what the creature can thrash with, which means
  **the way to take something no web could hold is to put silk on it first**, and
  the shot and the web stop being alternatives. It comes off again at 0.025 a
  second while the creature is loose, which has to lose to the shot cooldown or
  there is no loop at all — the first cut lost that race and netted four points a
  shot.
* **Silk costs legs as well as fight.** Binding scales what a creature can move at
  by the same factor it scales what the creature can thrash with — one number
  meaning one thing. This is what makes softening worth doing before a *chase*
  rather than only before a web: a fleeing wasp runs at 4.7 and the fastest tier
  on the ladder is 4.8, so without it the only answer to "it is faster than me"
  was to grow. Half wrapped, that wasp comes down to 2.3 and a spiderling can walk
  after it. Never quite stopped, though — something held still where it stands
  without being wrapped is a pin, and a pin is a different mechanic.
* **Sprinting is a pool, and hauling drains it faster.** A few seconds of it,
  refilled by walking, and spent at `1 + tow_effort * (weight - 1)` per second —
  so a size-3 wasp on the line costs a sprint 2.1x its own length. Weight already
  made a haul *slower* (`haul_drag`), and on its own that only makes the slow way
  worse than the fast way, with nothing to weigh against it. This is the half that
  makes walking a catch home a choice.

  It is deliberately **not** the pool a bite takes. `SpiderVitals` holds both and
  they answer different questions: **condition** is what you cannot get back by
  waiting and what being driven off costs; **wind** is a tax on running and
  nothing else. Running out of it bars a sprint until `second_wind` of it is back,
  rather than letting an empty tank buy a frame of sprint per frame of recovery —
  which reads on screen as a stutter rather than as being out of breath.

  `max_wind()` does not scale with the tier on purpose. A bigger spider gets a
  sprint of the same *length* that covers more ground because it is faster;
  scaling the seconds as well would be paying the ladder twice.
* **A click on something alive does nothing special.** `LiveLine.move` ships as
  `NOTHING`: the aim reads straight through the creature to the wall behind it,
  exactly as it would with no creature there. One meaning for the button.

  This is where a bail lived for a while — throw the spider backwards off what it
  was facing — and it came off the mouse for being unsure of itself: a creature
  standing in front of a wall is a creature *and* a wall, so the click was a bail
  or a grapple depending on a couple of pixels, and the cost of that is that the
  *grapple* stops being trustworthy. Moved to Shift it was dependable and still
  did not earn the key, so Shift is sprint again.

  The **HITCH** is parked behind the same switch and off by default — it ties the
  creature to the ground you were standing on, so it keeps its legs but only
  inside a radius and the *level* is what beats it, and what spends the silk is
  the creature's own `thrash_power()`, the number binding already eats into. It is
  a good mechanic sharing a bad button, and it is kept for when there is a way to
  be sure which you meant.
* **What a click on it is *not* is a pounce.** This was tried — a lunge that threw
  the spider at the thing and bit it on landing, softening it over the seconds
  that followed — and it was cut, because it failed on three counts that only
  showed up once it was
  playable. It spent `bound` from a second place, so it was the bolt again with
  the range and the wait swapped out rather than a different idea. It overloaded
  the fangs, which are how you *drain* something already caught, so "bite" stopped
  having one meaning. And a spider that charges its prey is a wolf: everything
  else in here is set-up-and-wait, and this was the single move that said go get
  it. The fangs keep their real job — halving what counts as "much bigger than
  me", so a fanged spider takes anything inside its bite where it stands — and the
  **Venom Spur** keeps the outright kill, which is `envenom()` and was never the
  lunge's. What is left with no producer is the *timed* venom: `Prey.poison()`,
  which works `VENOM_BIND` worth of silk in per second while it lasts. The lunge
  was the only thing that called it. It is deliberately still there, tuned and
  tested, because "a dose that softens something over the next several seconds" is
  a shape a spur mode, a thrown flask or a trait could all want — but until
  something calls it, nothing in the game is ever poisoned, and the training
  dummy's venom line (it only prints while a dose is running) shows up nowhere but
  `tests/shot_dummies.gd`, which pokes `poison()` by hand to draw it.
* **A bolt that reaches a creature is about the creature.** It used to also open a
  web where the thing happened to be standing, which plants one on the floor every
  time you shoot something low — a web nobody chose to put there, in a game where
  three lines and a wait are the whole cost of one. A hit is silk on the creature
  and nothing else: enough wraps it where it stands and the bundle drops, short of
  enough costs it fight and legs and the next bolt starts from there. What a
  heavier pattern buys is fewer shots, not a catch — an orb web lands 61% of a
  wasp where a sheet web lands 25%.
* **Silk has to start on something.** Firing with nothing under you still takes you
  where you aimed, because taking that away mid-fall would be taking the controls
  off the player, but no line is left behind: the near end would be tied to a point
  in empty air. Hanging from a line and riding one both count as having hold.
* **A direct hit is not a free catch.** The bolt used to wrap whatever it touched,
  with no size check anywhere, so a spiderling's first shot took a wasp and both of
  the slower ways of catching things had nothing to do. All three paths — a web left
  standing, a web thrown over something, a bolt square on — now ask the creature the
  same question, and all three see the silk already on it.

* **A web can be taken home.** Click a net and it comes down, with everything in
  it arriving at the spider's feet as **bundles** — the state something wrapped
  and cut loose is already in, so they keep their silk and go nowhere. A larder
  stops being somewhere you have to go and stand in the open; you cash it in from
  where you are. It costs the web, which is the same bargain `on_prey_taken` makes
  one catch at a time, paid for the whole shelf at once. Lines are not collected;
  a road is the floor you walk on.

  Everything comes, a catch still fighting included. The alternative — it gets
  loose if it was mid-struggle — reads as a coin flip rather than a decision, and
  it makes the outcome of a trap depend on the frame you happened to click on.

  This replaced hauling the web home on a rope. The rope was fiddly, and worse, it
  made the catch depend on the *trip*: walk it through a corner and half of it
  spilled. The thing the player wanted was the contents, not a web that was no
  longer usable anyway. What went with it: `reel()`, `spill()`, and the rule that
  a catch inside a web on your line is in fang reach — a bundle at your feet is in
  reach by the ordinary rule, so that case had nothing left to cover.

* **A snagged line pays out and lifts, rather than parting.** A rope pulls in a
  straight line and the world is not straight: haul a catch home with a wall in
  between and the pull is *into* the wall, so the catch cannot follow, you keep
  walking, and the line breaks. That is a real thing for a rope to do and a
  stupid way to lose a catch you had already won — there was nothing you could
  have done differently short of not going that way.

  A line that is pulling and getting nowhere now lifts as well, and pays out so
  the breaking point moves with it. Both halves were wrong first time and both
  are worth recording. Progress has to be measured **along the pull**, not as
  plain movement: plain movement oscillates, because the lift is its own undoing
  — the catch rises, rising counts as moving, moving cancels the lift, the catch
  drops back, and over a 1.2m wall it got 0.44m up and then lost the catch. And
  the lift alone is not enough on anything tall: with the old fixed breaking
  point the catch crested a 3m wall at the exact moment the span passed the
  limit. The climb is a governed *rate*, so a taller wall takes longer rather
  than the catch being thrown further.

  The payout is bounded, not infinite. Past it the catch really is somewhere the
  line cannot get it out of, and a leash with no end is worse than a break.
* **Webs have a cap too, and it is not the lines' cap.** Three lines is a number
  you hold in your head while moving; webs are *sites*, one fills up and a full
  one catches nothing, so running several is the play and capping them at three
  would argue with the thing the game asks for. `MAX_WEBS` is six, and it only
  ever takes down a web that is **empty** — a web you filled is what you went
  away and came back for, and clearing it to make room loses you the catch
  rather than the silk. If all six are working, none goes.

  Measured before this existed: ten shots at a wall left ten webs standing. The
  line cap was fine all along — ten grapples left three lines, as designed —
  which is worth writing down, because "old silk is not cleaned up" pointed at
  the wrong mechanic.

So the web stops competing with the gun. It is not a better way to acquire food —
it is **the place you can eat what you acquired**, which is a job nothing else in
the game does. That is §8's old line, *"your web is your cover, not just your
larder,"* finally holding a mechanism.

Eating also works **down your own line**, at any length. Silk is a straw: a catch
on your tether can be drunk while you run with it. That is what keeps the haul
from being dead time, and it means the choice is never "wait or don't" but *how
exposed you are willing to be while you drink*.

**Being driven off is not death.** No reload, no lost tier: you lose the catch and
the trip, and your stamina creeps back after a few quiet seconds. A sandbox with
no save has no business killing the player, and the cost of losing a fight — the
journey home, done again — is enough. Stamina is the one bar in the game, and it
is deliberately not a *budget* in the §11 sense: you never spend it, and being
careful with it never makes you poorer for having tried something.

Growing mends you completely, which is what makes a tier read as relief rather
than as a bigger number: the thing that was hunting you last tier is dinner now.

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
once. Eight tiers, each standing about two-thirds again as tall as the last —
heights in the world's units, where a metre is about fourteen.

| # | Name | Stands | Eats | Silk | New capability |
|---|------|------|------|------|----------------|
| 1 | Spiderling | 0.25 | midges, mosquitoes, flies, fireflies, ants | tiny | single strands, tripline |
| 2 | Fern Spinner | 0.4 | moths, bees, butterflies | small | sheet web, wall climbing |
| 3 | Huntsman | 0.7 | beetles, wasps, roaches | medium | orb web, silk bridge, pressure snare |
| 4 | Root Weaver | 1.2 | frogs, lizards, bats, songbirds | large | funnel lure, silk winch (drag prey) |
| 5 | Glade Widow | 2.0 | rats | big | venom sacs, web tunnels, trapdoors |
| 6 | Ruin Stalker | 3.4 | hares, ravens, fish | huge | anchored canopy webs, ambush burrows |
| 7 | Elder Weaver | 5.6 | foxes, the kraken | vast | structural webs across the ruins |
| 8 | The Architect | 9.0 | stags, boars, wolves, the leviathan | — | permanent territory webs |

What each eats is what it is built for: the creature whose size class the
tier's bite power reaches. Anything bigger is still food if you can hold it,
and the best meal in the game — it is how you evolve fastest (§3.1); the wyvern
is past every tier's bite, and only ever that kind of meal. The names are the
places: each place in the hunting ground is built for a stretch of tiers (§4),
the fern floor for the first three, the Rootways for the third to the fifth, the
glade for the fourth to the sixth, the ruins for the fifth to the seventh, the
Mere for the sixth up, and the crag for the Architect.

Growth is **visible and physical**: the camera rises, your stride lengthens,
your webs get coarser and stronger, the level geometry shrinks around you. The
fern you hid under on the first night becomes something you step over.

### Growth is the key, and never the lock

Growth only ever opens things. It is tempting to make some gates want you
*small* — squeeze under the door, through the vent grille — so that eating
becomes a decision. **Rejected, deliberately**, and it is worth writing down
why, because it is an idea that keeps coming back:

* It makes the player *avoid the core loop*. A game whose progression is eating
  must never give a reason to stop eating.
* It turns the escalation fantasy ambivalent. "I am enormous now" is the whole
  pitch, and it does not survive "…which is a problem".
* It turns going back into a chore. A place you have outgrown is worth passing
  back through for a meal (§4); it should never be somewhere you are sent
  because you got too big.

So every gate reads the same direction: you could not do this before, you can
now. A door you are too big for is never the design; a door that needs more of
you than you have yet, always is.

### 3.1 Evolution — what eating turns you into

The rejection above has one real cost, and it took a while to see it: if the
only thing eating does is move you up a fixed ladder, there is **no decision in
the game at all**. You eat, you get bigger, the next door opens. That is a
progress bar with a spider on it.

So a meal does two things. A drained creature gives **biomass**, which still
carries you up the ladder exactly as before — and it may **change you**. Every
creature carries a few traits, and every one you drink to the end is a chance
that one of them passes to you. What you become is decided by what you hunt:
wings come from things that fly, a heavy frame from things with armour, venom
from things that sting.

**How the odds are made.** One function, `SpiderTraits.odds`, and four things
go into it:

| | |
|---|---|
| **The trait** | Its own chance a meal, for a spiderling: 12% for the first of a branch, 8% for the second, 5% for the third |
| **The ladder** | Every rung past the first adds a quarter of that. A Glade Widow, on the fifth, has twice a spiderling's odds; The Architect nearly three times |
| **Bad luck** | Every meal that could have passed a trait on and did not adds half its chance to the next roll, until it is certain. A one-in-eight trait always comes by the sixteenth meal. Luck can slow you down; it cannot lock you out |
| **The size of it** | One size past your bite doubles the odds. Two or more past it is a **sure thing** — and if the creature carries nothing you could take, it pays in something else you could |

At most one trait a meal. Traits still stand on each other — no lean frame
before the wings it grows from — so a meal only rolls for what the creature
carries that you could take *now*, and the rest waits.

**Why chance, and why the big ones always pay.** The tree used to be a shop.
The larder was a currency, and a beetle spent on Broad Back was a beetle not
spent on Hunting Fangs. That made eating a decision, but a bookkeeping one,
made on a menu. Chance moves the decision into the world: what you choose is
*what to hunt*, which is the game. And the sure thing gives growth its second
meaning. Growing is how you come to take on creatures you had no business
taking on before — but a spider that manages it early, softening a wasp shot by
shot until a spiderling's web can hold it, has done the thing the game is
about, and that must never come up empty.

**Anything you can hold, you can eat.** The other half of the same change. Size
used to refuse a meal outright — *too big for you, grow first*. Now it decides
only how you get hold of one: a creature past your bite has to be beaten by the
silk before it can be wrapped — held in a web until it has fought itself out,
bundled by silk that out-holds it, or killed by venom — and no fangs take it
loose. While it is still fighting, it is not yours yet.

Three branches, three deep:

| | **Bulk** | **Flight** | **Venom** |
|---|---|---|---|
| I | Heavy Frame — bigger, stronger silk | Wing Buds — a fall becomes a glide | Paralytic Bite — subdue one class up |
| II | Broad Back — bigger still, harder bite | Hollow Frame — **smaller**, faster, longer reach | Digestive Flood — far more out of a kill |
| III | Girder Legs — rope for silk | Storm Rider — ride a draught | Hunting Fangs — kill with no web behind it |

And what carries each:

| Trait | Carried by |
|---|---|
| Heavy Frame | ant, beetle, cockroach, rat, boar, stag |
| Broad Back | beetle, cockroach, rat, boar, wolf |
| Girder Legs | beetle, rat, hare, stag, wolf, kraken, leviathan |
| Wing Buds | midge, mosquito, fly, firefly, moth, butterfly, bee, bat, songbird, raven, wyvern |
| Hollow Frame | midge, moth, butterfly, bat, songbird, raven |
| Storm Rider | wasp, bee, firefly, bat, raven, wyvern |
| Paralytic Bite | mosquito, ant, wasp, bee, frog |
| Digestive Flood | fly, moth, cockroach, rat, raven, fish, boar, kraken |
| Hunting Fangs | wasp, beetle, lizard, fox, wolf, kraken, leviathan, wyvern |

Every creature carries at least one, and the smallest things on the fern floor
carry all three roots, so a spiderling can start down any branch.

**Size is one branch, not the trunk.** Bulk *is* the old ladder, made into
something you grow into instead of a consequence. Flight is the other end of
the same ruler: Hollow Frame makes you 28% shorter than your tier, so you are
not a smaller spider, you are a **lean** one — a Huntsman that fits where
Huntsmen do not.

This is how "being small is sometimes good" gets in without reopening the
argument above. You never *avoid* eating to stay small; you eat exactly as much
and hunt different things. The escalation fantasy survives intact for anyone
who wants it, because Bulk is right there and it is the straight road.

**A trait is a body, not a stat line.** Mechanically the whole tree is one
function: the size tier the game reads is the ladder's tier with every owned
trait multiplied into it. That is why almost nothing else in the code had to
learn traits exist — the climb component, the web builder, the thresholds and
the HUD were all already asking how tall the spider is and how far its silk
goes, and they now get an answer with the traits folded in. Taking one is
announced down the same channel as growing a tier, so the body resizes through
the code that already did that.

**Gates take either key.** A threshold names a size *and* may name a trait, and
either opens it — a lid that gives to a Huntsman, or to a Hollow Frame that
folds through its slots. The hunting ground has none: its creatures are its
gates (§4). But the gym keeps three, and a level that wants one has it. With
traits coming by chance, the size is the key you can always count on and the
trait is the shortcut luck may hand you early. The gate never says which key you
are missing. It dips and settles back, the same as always, and the answer is
what you go and try.

**The screen.** Opened on **E**. Nothing on it is bought any more, so it is a
map rather than a shop: every trait you do not have says what carries it and
your odds from a meal of each, as you are now, grouped and least likely first
so the end of the line is where to go hunting — `Ant 12% · Beetle, Cockroach
24% · Rat, Bristleback Boar, Glade Stag sure`. Locked traits are shown rather than hidden, with what they
stand on, because "you can always see the next thing" is the one property of
the genre this game is not that was worth keeping. Opening it frees the mouse,
which is what stops you firing silk into the page you are reading.

**What is deliberately not in it:** no respec, no points, no levels, and no
trait that is a flat number with no body behind it. If a trait cannot be
described as a change to the animal, it does not belong on the tree.

### 3.2 Spells — what you can cast

The thrown web was the first spell before there was a word for it: point,
press, and something leaves the spider and does its work where it lands. The
rest are the same verb with other things behind it, so they share the web's
keys, its reach, its wind-up and its kind of limit.

**Right mouse casts whatever is in hand, and Q takes the next one in hand.** A
tap casts at once; holding winds it up — a bigger web, a bigger glob, a wider
whirl, a longer stun — over the same second the web always took. While it winds
up it glows over the spider's back in its own colour, and a spell that lands on
an area puts a ring where it will land, as wide as it will be.

| Spell | Opens at | Or with | What it does | Wait |
|---|---|---|---|---|
| **Silk** | the start | — | the thrown web: it sticks where it lands and wraps what it lands on | 3.5 s |
| **Venom Spit** | Fern Spinner | Paralytic Bite | a glob thrown like silk; what it hits is dosed, and softens from the inside for 6–10 s | 4 s |
| **Water Spiral** | Huntsman | Digestive Flood | a whirl on the floor where you point, for 5–8 s: it carries anything loose round and in, soaks it and holds it turning. Wet wings do not lift | 9 s |
| **Summon Lightning** | Root Weaver | Wing Buds | strikes where you point, and stuns what it reaches for 2.5–4 s: going nowhere, biting nothing, fighting nothing. A hunter gives up the chase, a flier falls, and anything a web holds loses a third of its fight | 7 s |

**Opening is the gates' rule.** A spell opens at a rung of the ladder, which is
the key you can always count on, or sooner with a trait it names, which is the
shortcut luck can hand you. What eating turns you into is what you can cast. The
strip down the right-hand side of the HUD shows every spell, what is waiting and
for how long, and what opens the ones you do not have yet — shown, not hidden,
the same as locked traits.

**They work off each other.** This is the part that makes four spells more than
four buttons:

* **Lightning runs through silk.** A strike that reaches a web runs through it,
  into every web whose silk touches it and down every wire from it, and stuns
  everything they hold. Silk was already the road network (§6); it is the wiring
  too. Strike the web you are standing next to and the wasp fighting a web across
  the room stops fighting.
* **Water carries lightning.** A strike on a whirl reaches everything the whirl
  holds, and anything wet takes it twice as hard — twice as long stunned, twice
  the fight gone — and passes it on to anything wet near it.
* **Venom goes into water.** A glob that lands in a whirl doses everything the
  whirl holds, for as long as it turns.
* **A whirl fills a web.** It carries what it holds round and in, and anything it
  carries through a web is caught by the web the ordinary way.

**And off what you have become.** A trait is a change to the animal (§3.1), and
some of those changes reach the spells:

| Trait | What it does to spells |
|---|---|
| Hollow Frame | every wait a fifth shorter, silk's included |
| Paralytic Bite | every stun lasts half as long again |
| Digestive Flood | acid water: a whirl doses what it holds with no venom spat in |
| Storm Rider | a strike jumps on twice more, to whatever is nearest, wet or dry |
| Hunting Fangs | every dose is fanged, over twice as strong |

Bulk needs no line of its own: every spell is sized in body heights, so a bigger
spider casts bigger.

**Why a wait, and one each.** For the reason webs have one (§5): a budget makes
the player afraid to spend, and the fear is worst just after a miss. Each spell
waits on its own, so casting one never costs you another — lightning spent is
not a web you cannot throw.

**What is deliberately not in it:** no mana, no spell points and no damage
numbers. A spell changes what a creature can do — move, fly, fight a web — which
is what the rest of the game already reads, so a spell is only ever a new way of
winning the fight the silk was already having.

---

## 4. The world

One wild valley — the hunting ground — laid out the way a hunting ground is in
the games it is named for: a camp to set out from, and round it the places things
live, each its own country with its own creatures and its own danger. Seven
places in one continuous space, all open to one another. Places still come in an
order, and the order is still your own body.

The first cut was five zones — an attic, the walls and crawlspace, the gutter
and sewer, the park and the city — greyboxed in white. It was scrapped for three
built to look like what they were — a garden shed, the sewers under a park, and
the park with its lake — and those were scrapped in turn for the valley, when the
game became a hunting ground: a shed and a sewer are rooms, and what the game
needed was somewhere alive. Everything is to one scale, the scale of the props —
a metre is about fourteen of the world's units — so a fern is a fern and a stag
is a stag. The places are the size they would be; what they are built for is how
big the spider is by the time it gets there.

### The shape: a hunting ground, not a sequence

The shed and the sewers were a **sequence of sandboxes**, each ended by
outgrowing it — the drain lid in the shed floor, the grate at the top of the
sewer — and size is a one-way ratchet, so each was played once and left behind.

The valley keeps the ratchet and drops the sequence. Nothing shuts the way to any
of it: there is no door between the fern floor and the crag. The order is kept by
what lives in each place — the glade's foxes eat spiderlings, the ruins' wolves
eat anything a fox would, and the wyvern eats wolves. What keeps a spiderling out
of the crag is that the crag would eat it. The two properties of the old shape
worth keeping survive:

* **Legible danger.** You can always see the next place, and what lives there
  tells you what you are short of: a stag grazing the glade is a size you are not
  yet.
* **No timer.** Inside the valley there is total freedom and nothing is owed.
  The day goes round, and changes what is out, but nothing falls due when it
  does — no quota, no deadline.

And it adds what the sequence never could: **going back**. A place you have
outgrown is still there and still alive, still full of what you used to eat —
worth less to you now, but a meal on the way somewhere, and the camp is always at
the south edge of it. Nor do the big things keep to their places: a stag turns up
in the ruins, the wyvern over the glade, a boar rooting through the ferns. The map
is a ladder you climb, and also somewhere things happen to you on the way up.

### The creatures are the gates

A threshold — a **physical thing that responds to your body**, not a locked door
with a message — is still how a place shuts when it has to. The model is a
pressure lid: stand on it too small and it **shifts slightly and settles back**,
which tells you it is a lid, that it is yours to open, and that you are not
enough yet, in one motion and no words. It is built on size, not weight — mass
would be derived from `body_height` and nothing else, so "heavy enough" and "big
enough" would be the same comparison in different units — and it may name a
trait as a second key (§3.1), so a spider that went up Flight instead of Bulk is
never stuck behind a door it can only grow into.

The gym keeps three. The hunting ground has none, and needs none. **A gap you fit
through or you do not is the collider's business**, not a rule's — the spider's
own shape against the hole's, decided by the physics that is already running.
And a place you are not ready for is the business of what lives in it. The
cheapest gate in the game is a hole that was always that size; the next cheapest
is a wolf.

It also solves push versus pull in one move. Nothing ever *expels* you: you can
live on the fern floor as long as you like, and it stays valuable because it is
where your network is. You move on because you can, and because the Rootways
have things in them worth twice what the fern floor holds.

**You carry your belongings.** Moving on does not mean hauling your larder
across the valley — the bag comes with you. What stays behind is the silk: the
network you built is the thing you cannot take, which is what makes each move
cost something without making it a chore.

### Each place taxes silk differently

A place is not a new mechanic, it is a **new pressure on the one mechanic**. The
question each place asks is *how does this place erase silk?* — and the answer
is usually one multiplier on something that already exists.

| Place | How it fights you | What it taxes |
|------|-------------------|---------------|
| The Fern Floor | nothing much — it is sheltered, still and cluttered | *learn here* |
| The Rootways | the dark, and rats that fight back | *timing* — what lives here is out at night, so a web is strung by day and fills after dark |
| The Bloom Glade | open ground, foxes, and the wyvern overhead | *anchors* — they are far apart, and a web between two trees is a long one |
| The Old Ruins | wolves and boars, and bare stone | *spans* — walls with gaps between them, little to tie to, and what walks through fights |
| The Mere | deep water, and what is in it | *where you stand* — no web crosses water, and a spider in it is swimming with the leviathan |
| Wyrm's Crag | height, and the wyvern | *everything* — one thing up there is worth hunting, and it is hunting you |

The valley does have a clock — the day — but it is the valley's clock, not your
life's: it changes what is out, never what you owe.

### 4.1 The Camp — *where you start*
A hollow stump at the south edge of the valley: a ring of bark open on the north
side, toward everything, with moss on its floor and a glowcap for a lamp.
Nothing lives here and nothing comes looking. It is where a new spider starts,
and where one that falls out of the world is put back.

### 4.2 The Fern Floor (tier 1–3) — *tutorial*
The forest floor between the camp and the glade, seen from a spiderling's
height: ferns overhead, toadstools whose caps are roofs, pebbles that are
boulders, fallen leaves and acorns to cross, an anthill, and a puddle. Old trees
stand over it, so the floor is in their shade.
Lives here: midges and flies, beetles grazing the moss, the ants, moths and
fireflies at night, and mosquitoes over the puddle. Teaches: anchors, strands,
first sheet web, feeding.

### 4.3 The Rootways (tier 3–5)
The great tree of the west side and what is under it: a trunk three and a half
metres through, its roots arching out over the hollow it stands in so that under
each is a cave, shelf fungus up the bark to climb by, and a hollow log lying on
the floor to walk the length of. Glowcaps light the caves at night.
What lives here comes out in the dark: roaches, rats bigger than a Huntsman that
come for you, moths, beetles, and bats that hang under the roots by day.

### 4.4 The Bloom Glade (tier 4–6)
The open middle of the valley: a meadow in flower, with tall grass and
wildflowers to climb and string silk between, brambles of berries, a few trees,
a ring of standing stones at its heart, a wild hive in a stump and a wasps' nest
on a dead tree. The busiest place in the valley by day: bees and butterflies over
the flowers and wasps hunting them, hares in the grass and a fox after the hares,
songbirds in the trees, and the stags grazing all of it. Wolves cross it at
night, and the wyvern hunts it from the air.

### 4.5 The Old Ruins (tier 5–7)
A keep nobody remembers, up on its shelf of ground in the north-west: broken
walls round a courtyard of flagstones, a gateway arch toward the glade, a row of
columns and fallen ones, a tower still standing at one corner with its top
broken away, and in the middle of the courtyard a statue of a spider — a great
one, older than the stones round it. Whoever built the keep knew what the largest
of them become.
Lizards sun on the walls and live in their cracks, ravens roost on the tower,
boars root in the rubble, rats and cockroaches come out of it at night, and the
wolves den at the tower's foot.

### 4.6 The Mere (tier 6–8)
A round lake in the east of the valley, deep in its middle, with an island out in
it, lily pads on the water, reeds all round its edge and driftwood on the shore.
It is built for the biggest sizes because of what is in it: shoals of fish
grazing the weed on the bottom, the Mire Kraken in its lair in the deepest part,
and the Mere Leviathan, which nothing in the valley hunts. Frogs sit on the
banks, mosquitoes and midges rise off the shallows, and stags and wolves come
down to the shore. None of what lives in the water comes out of it — but the
leviathan follows a spider round underneath until the spider is the biggest
thing in the valley.

### 4.7 Wyrm's Crag (tier 8) — *endgame*
The rock tower in the north of the valley, weathered into ledges with cliffs
between, heaps of fallen rock on its shelves and spires standing up off it, and
in the bowl at its top the wyvern's nest: a ring of branches it carried up,
bones, and its eggs. Nothing lives up here but ravens on the spires. The wyvern
hunts the whole valley — stags, boars, wolves — and nothing hunts it. It is the
reason to grow.

**Not yet:** wind and rain; running water that takes silk back; a creature that
remembers a web it has been caught in once.

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

### 4.8 The testbed — a gym, not a place

`game/world/testbed.tscn` is the workshop; the project opens the hunting ground.
Nine stations on one flat floor, fifty-two metres by forty, all in sight of the
middle: corners for web fitting, three slots wide to narrow, a wall-overhang-
ceiling run with slopes at twenty through eighty degrees, grapple anchors at
one/three/seven/thirteen metres, a roof with a hole for draglines, two posts of
different heights for a zipline, the three size gates side by side, a prey pen,
and a hole in the floor for falling out of the world.

It exists because the hunting ground (§4.1–4.7) is the best part of eight
hundred metres across, so checking whether a web fits a corner meant a walk,
and checking a *different* corner meant another one.

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

Shooting a web starts a short cooldown, and that is its whole cost. Every spell
is limited the same way, each with a wait of its own (§3.2). A wait
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
  and the HUD names it, so you can see what the throw is lined up on before you
  let go.

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

Binding is the piece that was missing from that. "No single web can hold it" used
to be a flat no, with nothing to do about it but grow; now it is a number you can
work at, because silk you land costs the creature fight it does not get back
inside the window. A boss becomes a question of getting enough silk onto something
faster than it shrugs it off — which is exactly the kind of problem the lure, the
venom spur and the road network are already answers to.

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
it. *(Since parked; Q takes the next spell in hand now, §3.2.)*

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
moves up as you grow — an Elder Weaver's sheet web keeps things a Spiderling's
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

The spur was the one that changed a rule. When it was written, prey above your
bite power was a wall you could only pass by growing, and a spur turned that
wall into a **problem with a cost**: you could take the thing that was too big
for you, but it cost you the spur, and you had to have already got it into a
trap. The wall has since come down for everything — anything you can hold, you
can eat (§3.1) — and the spur is now simply the fastest way to win the fight
the silk would otherwise have to.

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
  along a skirting board without being flung onto the wall. And only onto a
  surface standing on this side of the one underfoot: an inside corner is the only
  kind there is to push into. The far face of an edge you have just walked over is
  behind you, and walking away from the edge points into it just as squarely.
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
frame, and the rig is placed rather than eased — and the camera defaults to third
person, with first person on a key.**

The look frame took three tries. *Taking the view from the body* came first: yaw
turned you around whatever surface you were stuck to. On the floor that is
identical to normal mouse look, so it seemed fine, but it rebuilt the frame from
the body every time the body rolled, which yanked the view sideways mid-stride.

Then we tried a *frame that rolls onto the surface*, carried across by parallel
transport so the axes stayed consistent on a wall or a ceiling. It did make the
axes consistent and it was horrible to look through. The whole world turning over
underneath you as you crawl about is far more movement than anyone wants from a
camera, and it is movement the player did not ask for. Same verdict on easing the
arm across the frames between physics ticks: a camera that lags is a camera you
can feel, and what the easing was hiding was a step of a few centimetres.

So the rig is the plain one. **World yaw and pitch, a level horizon, placed
exactly where it belongs every frame, and it does not roll for surfaces.** The
only thing that moves it is the mouse.

What a wall does to the *controls* is then fixed where the controls are, in the
mover — see **Walking on a wall** below. The camera and the walking agree without
the camera having to move.

**The pivot is measured off the surface, not off world up.** This is the whole
of the ceiling bug. The arm orbits a point lifted from the spider, and lifting it
along world up puts that point *inside* the ceiling when the spider is hanging
under one — and a ray that starts inside a solid does not report hitting it, so
the arm found nothing in the way and placed the camera through the roof. Measured
along `climb.body_up()` the pivot is in open air whichever way up the spider is.
Measured: on a ceiling the pivot used to land at y=3.98 inside a slab spanning
3.75–4.25, and now sits at 3.27, in the room.

The arm also sweeps a ball down its length rather than casting a line, so a
doorframe inside the frustum but off the centre ray pulls it in. Worth recording
what that is *not*: the clearance it keeps is the larger of the near plane's
corner and the old share of body height, because the corner turns out to be about
a centimetre for a spiderling against the old margin's nine — so the old margin
was never what was letting the camera through a wall, and dropping to the strictly
correct number would have quietly pulled the camera much tighter into walls.

**Corners: the pivot rides the body, the boom starts inside it, and the arm comes
back out slowly.** The report was that the camera jittered at every edge and
corner, and measured it did — up to half a metre in a single frame, twenty-odd
reversals a second. Four things, and the biggest was not the camera at all (see
*Across an edge* under **Walking on a wall**: the spider itself was bouncing
between the two surfaces). The camera's own three:

* The pivot was lifted along `body_up()`, which is a *decision* and jumps the
  instant the spider takes a new surface — a quarter turn moved the pivot two body
  lengths in one frame. It is lifted along `view_up()` now, the body's back as far
  as the body has rolled, so it swings round a corner with the spider.
* The boom is swept, leg by leg, from the middle of the body: out to the pivot,
  then down the arm. It used to start at a pivot set down beside the spider, and
  Jolt **ignores anything a cast starts inside** — measured, a ball a millimetre
  into a wall passes straight through it in every direction, while one merely
  touching is stopped dead. Pressed into a corner the arm's ball began a hair
  inside one wall or a hair outside it, so the camera went through the wall or
  collapsed onto the spider depending on which. The body is the one place the
  physics already keeps out of every wall, so the ball is capped just under the
  body's own radius and every leg starts clear by construction.
* In at once, out at a rate. Anything coming between is dealt with the frame it
  arrives, as before; what changed is the *going*. An edge sliding off the arm used
  to throw the camera most of a metre back in one frame, and an arm grazing a wall
  flicked in and out. The arm and the pivot's lift now pay back out at
  `arm_let_out` body heights a second. This is not the easing that was rejected
  above — the camera still sits exactly on the spider every frame and never trails
  it; only how fast it recovers room it was denied is limited. A spider *put*
  somewhere (a respawn, a test setting a scene) calls `settle()`, because easing
  out from under a ledge that is not there any more is drift for no reason.

What is left is honest: walk in under a ledge lower than the pivot and the camera
drops the frame it has to, once, because the room over the spider really is gone.

**The crosshair is cast, and the spider aims at what it finds.** Third person puts
the camera behind and above, so "fire along the camera's direction" and "fire at
what the camera is looking at" are two different shots, and only the second goes
where the cross is. Against a wasp three metres off the first one landed 0.45m
away from it — on a creature 0.05m across. So `aim_focus()` casts the cross's own
ray (which passes through the pivot, since the camera sits at `pivot - look *
distance`) and `aim_forward()` runs from the spider to whatever it finds; the same
shot now lands 0.03m off. What the cross can land on is deliberately wider than
what stops the camera: prey and webs count, or the cross reads straight through a
wasp to the floor behind it and the silk goes where the floor is.

The second half reverses an earlier call, twice reversed now, so here is the
reasoning rather than a quiet edit. Third person wins because **the size ladder
is the whole progression** and you cannot judge your own size from inside your
own head. A game about being a coin that becomes a car has to let you see the
coin. It also suits a goofy register: eight legs scuttling up a wall is funny to
look at and invisible in first person.

First person stays, on **L**, because it is better for lining up an anchor and
for the sensation of speed on a line.

The world does not flip upside down on a ceiling, and there is no toggle for it,
because under a world-space look model there is nothing to flip. That sensation
is gone and it was a real one. It cost less than a camera that rolls.

### Walking on a wall

**Decided: the walk is the camera's own screen axes, flattened onto whatever is
underfoot.**

This is where a wall or a ceiling is actually dealt with. The rig keeps a level
horizon and never rolls, so on a wall "screen-right" and "along the wall" are two
different directions and *something* has to reconcile them.

The old answer took forward from the camera, flattened it onto the surface, and
then built right as `forward × up`. Flattening forward is right — it is what makes
walking at a wall climb it, since looking into a surface leaves nothing to flatten
and it falls back to the camera's own up. Deriving right from it is not. On a wall
with its face toward you that gave **down the wall** for D, and on a ceiling it
came out **mirrored**, so D walked you left while the world was still drawn the
right way up. Neither was written down anywhere. They were just how it felt, which
is the worst kind of bug to have in a control scheme.

Flattening the screen axes *themselves* gets all three surfaces right:

* **Floor** — identical to the old construction, so nothing about walking on the
  flat moved.
* **Wall** — D runs along the face the way the screen says it should, and W, with
  nothing left of forward once the wall's normal is taken out of it, climbs.
* **Ceiling** — D is still the way the camera calls right, because the camera
  never turned over.

The one degenerate case is looking *along* a wall's face, where screen-right
points into it and there is honestly no right to go to. That falls back to the old
cross product, which is always square to the walk and always somewhere. The view
is a sliver of wall at that angle and the player is about to turn it.

**Across an edge, the keys keep going the way they were going.** The screen-axis
walk is right on any one surface and wrong *between* two, because at the edge the
reading jumps. Walk into a wall with the camera tipped down even a little — which
in third person is most of the time — and W on the wall means *down* it: straight
back into the floor. So the spider took the floor, then the wall, then the floor,
a swap every three tenths of a second for as long as the key was held, and never
climbed. Nothing said so, because the one check that walked into a wall did it
with the camera dead level, where the two readings happen to agree. A ceiling did
the same from the wall, and a silk line did it against whatever it was tied to,
which is what "I cannot get off the rope" was.

`SpiderClimb._carry_over` turns the keys' own two directions by exactly the turn
the surface made — forward on the floor becomes up the wall, up the wall becomes
on across the ceiling, forward over a ledge becomes down its face — and keeps them
while the keys that were down stay down. It hands back to the camera the moment
they are let go or the camera swings well away (`carry_release_angle`), because
both of those are the player asking again. On the gym's climbing station the
wall-to-overhang run went from eleven bounces and forty-six camera reversals to
none.

### Framing a throw

**Decided: the pivot lifts and the view widens. Nothing travels.**

Winding a throw up used to drop you into first person, which cost the sight of the
spider — the one thing worth watching while it winds up. Then it brought the arm
in and swung it round the shoulder, which kept the spider on screen and was a lot
of camera motion for a framing.

It needs neither. The camera orbits a point **above** the spider instead of the
spider itself, which drops it down the screen and opens the room out over its
back, which is where the silk is going. The arm keeps its length, the horizon
stays put, and the only other change is that the **view widens** by about nine
degrees at a full wind-up. The field of view has one owner, because the speed rush
writes it too and two things easing one number is two things fighting over it.

### How far silk goes

**Decided: one reach for grappling and throwing alike, four times what a single
thread can span — so it is the body's, and it grows.**

Both verbs were effectively unlimited: grapple to anything you could see, throw
a web wherever you were pointing. The report back was that the whole game felt
too long ranged, and that is what happens when nothing is out of reach — there is
no distance left for growing to close, and a room you *cannot* cross is the only
thing that makes crossing it a reward.

The hard part is not shortening it. It is shortening it without making getting
about a chore, which is exactly what the old per-tier anchor range did and why it
was taken out. Three things keep it from turning back into that:

* **It is one number, for both verbs.** Two ways of putting silk over there, each
  with its own invisible limit, is the fastest way to make a reach unreadable.
* **It is generous, and it is the body's.** Four times `max_strand_length`: about
  ten metres for a spiderling, a hundred and twenty for the Architect, and
  roughly three times what a scripted build run may span at any tier. So a click
  still crosses a room; the rooms just get bigger than you for a while.
* **The refusal names the distance.** "No surface in reach" reads as a broken
  click. "Nothing within 10m — grow to reach further" reads as somewhere to come
  back to, which is the whole point of hanging it off the body.

And distance costs something *inside* the reach too, because a hard edge only
says where you may not throw. A thrown web's quality falls off across the reach
to 55% at the far end — so long shots land, they land thinner. That is the part
that can be played around: close the distance for a web that will hold, or take
the cheap shot from here and accept a weak one. It never reaches zero, because a
throw that builds nothing reads as broken rather than as expensive.

### Two grapples, played back to back

The pull is strong, and the strength is the problem: it costs nothing, waits for
nothing, and is the fastest way anywhere by a long way — fast enough that
anything chasing you is simply left behind, which makes it an escape you can
always take. So there is a second grapple, one key (**G**) away from the first,
to play against it:

* **The line** lays silk from your feet to where you point and stands you on its
  near end, facing along it. Nothing takes you anywhere. Getting there is walking
  the line.
* **Walking a line is fast** — `line_speed`, three and a half times a walk — and
  the same speed up it as down it and whatever its slope. It is a road you laid,
  not a hill, and the spider is casting magic, not obeying it.
* **You stay on until you jump.** Silk is sticky, and the spider sticks to it the
  way it sticks to a wall, so there is no hanging and no falling off. Fired from
  the air, the line starts where you are and catches you on it.

What changes is that going somewhere is two things — putting the road down, and
walking it — and the second is where you can be caught. The line is still one of
your three (§5), and still a wire a spell can run down.

### A grapple keeps what it was carrying

Arriving used to zero the velocity, which made every grapple a **full stop** and
every journey a series of them. Three things had to change together, and any one
alone is invisible:

* **On arrival** the part of the travel running *along* the surface is kept (at
  80%); the part running *into* it is dropped. So a glancing arrival lands you
  running and a head-on one still stops — head-on into stone is a stop, and the
  honest momentum to keep is the part the wall is not in the way of.
* **Above a walk, speed bleeds rather than being clamped.** `deceleration` is
  18/s because it exists to stop you the moment you release a key; applied to a
  landing that erases the arrival in 0.12s. A skid at 1.6/s lasts 1.4s, which is
  long enough to be a thing you use. Steering *against* it still brakes hard.
* **A jump carries what you already had.** `_leap` built its velocity from
  scratch, which threw away the half of chaining that matters: grapple, land
  running, jump, grapple again.

**Why not swinging instead.** The obvious alternative — click an anchor and swing
from it — is already in the game twice: `Ctrl` drops you onto a dragline and you
swing on it, and `F` rides any line and throws you off the end with your speed.
What the grapple has that a swing does not is that **every click leaves a road**
(§5). A swing anchored at one end leaves silk dangling from nothing, which turns
the best property of the traversal into litter. The grapple's problem was never
its shape; it was that it ended in a full stop.

### Ziplines
Any strand marked ridable can be clipped onto and slid along. Gravity does most
of the work — a line strung downhill builds real speed — the movement keys push
you along a level one, and letting go throws you off carrying everything you
had built up, with a small kick to clear the edge. Arriving on a line with
speed keeps it, so dropping onto one from a height flings you along it.

This is the traversal answer to a world built vertically, and the reason to
string silk somewhere you have no intention of catching anything. A line is
cheap, permanent and yours.

### The body

**Decided: a skeleton posed in code every frame, with no animation clips, and
feet that find their own footholds.**

The body used to be a stand-in built from primitives, with legs that swung in two
sets whether or not anything was under them. It showed the spider's size and
which way it faced, which is what third person needed first, and nothing more.

Clips could not do better. A spider walks on a floor, a wall, a ceiling, a thread
and into an inside corner, at every size from a coin to a car, and a walk cycle
made for one of those is wrong on the rest. So the body is a skeleton of 45 bones
(`SpiderRig`): thorax, head, jaws and fangs, two-part palps, abdomen and
spinnerets, and eight legs of four segments each. A `SkeletonModifier3D`
(`SpiderGait`) poses it after everything else has run for the frame:

* **Footholds are looked for, not assumed.** Each foot casts out from its hip
  toward where it would rest and then down, so a wall beside or ahead is found
  before the floor under it. In an inside corner the front feet land on the wall
  before the body has turned to it, and that is most of what makes climbing read
  as climbing.
* **A planted foot does not move.** It stays where it was put in the world until
  the body is half a stride past it. Then it lifts, swings on an arc and lands half
  a stride ahead. Nothing on the ground ever moves, and that is what stops a walk
  looking like a slide. Strides get longer and steps quicker with speed, until the
  legs are a blur.
* **Four feet down, always.** The legs step in two sets of four, the tetrapod
  gait real spiders use: L1 R2 L3 R4, then R1 L2 R3 L4. A set only lifts once the
  other has landed. A leg that has fallen behind to full stretch waits for its
  turn and makes the set in the air land sooner. It does not break the rule.
* **Every other state is a pose.** In a fall the legs spread and feel about, wider
  with wings. On a grapple they tuck and the front pair reaches ahead. On a
  dragline the front legs reach up the line. On a ride three pairs grip the line
  overhead. On top of any of these, the front pair lifts to hold the ball while a
  throw winds up, the front legs and jaws work at a meal, the abdomen breathes and
  swings round toward whatever is being towed, and the whole body flinches from a
  bite.

Each leg is solved directly, with no iteration. The coxa turns the leg to face its
foot, the tarsus comes down onto the surface at a slant, and the femur and tibia
are a two-bone solve bent so the knees ride high over the carapace. That
silhouette is what makes it read as a spider rather than a table.

Every bone points along its own +Y, the way imported rigs do, so a modelled spider
can later be put on the same bone names and the gait will drive it unchanged. The
meshes that ship are built in code and stand in for that model. Each is one skinned
surface with every vertex on exactly one bone, because an exoskeleton turns in
pieces at its joints rather than bending.

**Three looks, one skeleton, and O to switch between them.** Which one the game
settles on is still open, so all three are kept and can be tried in play:

* **Detailed**: banded legs, a marked carapace and abdomen, jaws, palps and eight
  glossy eyes, all smooth-shaded.
* **Low poly**: the same parts cut into flat faces, about a ninth of the
  triangles. Legs are four-sided and come to a point at every joint, and each face
  has one normal and one colour, so the markings survive as whole faces picked out
  in the paler colour.
* **Minimal**: two smooth blobs on eight thin legs with round joints, two pale
  eyes, and one colour for everything else. It uses no bones but the thorax, the
  abdomen and the legs.

Changing look swaps the mesh and nothing else. The skin, the gait and every foot
stay exactly where they were. That is also the working proof of the claim above:
a mesh built by anyone, on these bone names, is driven the same way.

A trap for anything that reads the bones back: once the frame is drawn, the
skeleton hands back its *unmodified* pose, so `get_bone_global_pose` answers with
the rest pose every time. The gait records where it drew each foot
(`drawn_feet()`), and the checks measure that. The gait also only runs while the
body can be seen. First person hides the body and switches the gait off, and the
feet go down fresh when it comes back into view.

---

## 8. Prey and threats

| Class | Examples | Behaviour |
|-------|----------|-----------|
| **Drifters** | midges, moths, flies, fireflies | wander, drawn to light; tiny biomass, easy |
| **Trailers** | ants, beetles, roaches | walk the ground; predictable, good for triplines |
| **Fliers** | wasps, bats, songbirds, ravens | fast, 3D routes; need strong webs and high anchors |
| **Grazers** | hares, stags, fish | never come for you; run from anything that could eat them, you included |
| **Fighters** | rats, boars, the kraken | will attack you if you are small; damage webs badly |
| **Hunters** | foxes, wolves, the leviathan, the wyvern | hunt *you*, and everything else; your web is your cover, not just your larder |

Everything you can eat can also eat you at the wrong size. The tension curve
is: each new place opens with you as the smallest thing in it.

**How that is actually decided:** one comparison. A creature whose `size_class`
is inside the spider's `bite_power` is easy food; one outside it, with
`aggression` above zero, hunts instead — and is still food if the silk can beat
it (§3.1), which is the meal that always changes you. So there is no separate
bestiary of predators — the wasp that drives a spiderling off a corpse is a
Huntsman's dinner, and growing *flips the relationship* rather than swapping
the cast. Wasps hunt hard and fast; beetles hunt slowly and on the ground;
midges never hunt anything.

**Where they live.** The insects turn up anywhere. Everything else has a
`habitat` of `"wilds"` and is only put down where a den or a spawner names it, so
a room built for something else never fills with wolves. In the hunting ground
every species has dens, in the places built for the size it is food for (§4):
ants, beetles and fireflies on the fern floor; roaches, rats and bats under the
great tree; hares, foxes, songbirds and stags in the glade; lizards, ravens, boars
and wolves in the ruins; frogs on the banks of the Mere and fish, the kraken and
the leviathan in it; and the wyvern on its crag. They are built to the tier they
are food for — a rat is as big as a Glade Widow — and a big one bites from the
edge of its body, not from a wasp's margin scaled up to a leviathan's. Something
that swims keeps all of itself under the top of the water it is in: steering at
a spider on the bank, it follows along underneath.

**What spells do to them.** Three things a creature can be besides caught, each
read by the rest of the game rather than counted against a number (§3.2).
*Dosed*: venom works silk into it from the inside while the dose lasts.
*Wet*: it carries a charge to anything wet near it, and a wet flier cannot climb
until it dries. *Stunned*: it steers nowhere and bites nothing, a flier falls,
a hunter gives up the chase, and in a web it stops pulling on the silk while its
fight runs down — it hangs limp, the pose of something that has fought itself
out. And while a whirl has hold of it, the whirl decides where it goes.

### 8.1 The valley is alive

A hunting ground is only worth the name if its creatures are doing something
when you are not looking. So none of what they do is scripted: no spawn waves, no
patrol routes, no encounter tables. Each creature has a mind (`CreatureMind`) and
a few needs, and what the valley looks like on any given evening is what those
needs added up to.

* **Hunger.** Every creature gets hungry at its species' own rate and goes to
  find what its `diet` names: forage — moss, toadstools, flowers, grass, berries,
  growing in patches that are eaten down and grow back slowly — or other
  creatures, or carrion. Meat first: a fox that can see a hare and a bramble goes
  for the hare. Something it can take, it hunts down, kills and eats where it
  fell. Something hungry that can see nothing it eats goes looking, a little
  further out each time, and gives up on an errand it cannot finish.
* **Fear.** Anything that would eat it, and could, it runs from — from as far as
  it can see the thing if it is hunting, and only up close if it is not, so a
  glade can go on grazing with a fox at its edge that is not hunting. A wary creature counts the
  spider as one of those once the spider is big enough to eat it, which is the
  moment the hares stop letting you near.
* **Dens.** A species lives somewhere — a burrow, a hive, a roost, a nest — and its
  den is the whole population model. It breeds on meals: each one its creatures
  finish is put by, and a new one is born when enough has been. Nothing is told to
  keep the balance. Too many hares eat the grass down and stop breeding; foxes
  eating hares breed, and then there are fewer hares, and the foxes go hungry. A
  den hunted out is found again by a stray of its kind in the end, so a species
  can be hunted out of a place but never out of the world.
* **Hours.** A creature is out by day, by night, or always, and out of its hours
  it goes home and rests — out of sight, for a burrow. The clock is the
  `Ecosystem`'s, a day every twelve minutes, and the `DayNight` puts the sun and
  the moon where it says. The valley at night is a different place: the bees, the
  songbirds and the stags are gone from the glade, the wolves come out of the
  ruins, and the fireflies and the glowcaps are what a spider sees by.
* **Roaming.** The big things do not keep to the country round their den. Every
  so often one leaves for another of its haunts and wanders about that instead,
  which is how a stag turns up in the ruins and why the wyvern is sometimes over
  the glade and sometimes not.
* **Turf.** Two big territorial creatures that meet, neither able to take the
  other, square up and fight over the ground. The stronger usually wins — size,
  how hard it fights, what has already hurt it, and some luck — and both come out
  of it hurt, the loser running. A hurt creature is slower and weaker in a web,
  and one hurt badly enough limps home and rests until it has mended.

That last pair is where the hunting-ground fantasy lives for a spider. A stag is
too much for a Ruin Stalker's silk — until it has lost a fight with a boar and is
limping home across the glade, past the web you strung there. Watching is a way of
hunting: what is out, where it is going, what just hurt it.

Without an `Ecosystem` in a level none of this runs. The sandbox, the gym and the
test arenas have creatures that wander as they always did, hungry for nothing and
afraid of nothing, which is what every check written before the ecosystem was
written against.

### Bodies

**Decided: every creature is drawn the minimal way, on a skeleton, with a few
simple poses. The spider is the only thing with a gait.**

Of the spider's three looks, minimal is the one the game is taking forward, and
its creatures follow it: smooth parts, thin limbs of one width with round joints,
a few flat colours and clear wings. A creature is small on screen and on screen
briefly, so what it needs is a silhouette you can name at a glance and a pose that
says what it is doing. It does not need detail.

* **A body is a resource.** Each kind of animal is a script (`InsectBody` for
  insects, `BeastBody` for anything furry on four legs, `WingedBody` for anything
  on two wings with an arm and a hand in each, `FishBody` for anything that swims
  with its tail, `OctopusBody` for the one thing built like nothing else) and
  each species is a
  `.tres` of it, in `game/data/bodies/`, holding every size, colour and part as a
  number — the stripes on a wasp, the length of a mosquito's proboscis, whether a
  rat's ears are round or a fox's pointed. A `PreySpecies` points at one; without
  one it is still the placeholder ball. So a new creature is still files, never a
  scene.
* **A body can come before its species.** A body says what a creature looks like
  and how it moves; everything else — how big, how strong, where it lives — is the
  species. The first creatures past the insects were drawn before there was
  anywhere for them to live, and until they had species the checks and
  the pictures put them on a stand-in (`tests/support/stand_in.gd`) that makes up
  just enough to walk one, fly it and catch it. Every body has its species now;
  the stand-in is there for the next one drawn ahead of its place.
* **One mesh for every creature of a species.** The bones are each creature's
  own, but the mesh and the skin are built once and shared. A room holding a dozen
  flies builds one fly.
* **Five poses, eased between.** *Flying*: wings beating, legs tucked up.
  *Walking*: legs three at a time, the tripod gait real insects use, wings folded.
  *Struggling*: in a web and fighting, legs and wings thrashing as hard as it has
  fight left. *Spent*: fought out, hanging slack. *Curled*: wrapped, head down in
  the bundle, legs drawn in. The creature itself decides nothing — the view reads
  the prey's own state, so behaviour and body cannot disagree. Each kind holds
  the same five its own way: a beast trots two legs at a time, stretches out in
  a leap, scrabbles at the air and shakes its head when caught, and curls up
  small with its tail round it; a winged thing beats its wings with the hands a
  moment behind the arms, folds them down its sides to walk on two legs, flaps
  in bursts when caught and wraps them round itself at the end; a fish swims in
  a wave from nose to tail, and out of water lies on its side and flops; an octopus ripples its arms sitting, pulses them like a jet
  swimming, and coils them up at the end. Swimming is flying: a swimmer keeps
  itself up in water the way a fly does in air, and where the water is is a
  place, not a pose — its species says it swims, and it stays in the water.
* **The same look for everything, not just insects.** A rat, a raven or a leviathan
  is drawn by the rules a fly is: smooth parts, limbs of one width bent at round
  joints — a beast's legs, a bat's finger bones, an octopus's arms tapering to a
  point — wings and fins flat with a rim round them, a few flat colours, and two
  small eyes that shine a little. A goofier look was tried and dropped: staring
  eyes with whites and a glint, buck teeth, whiskers, tongues, lips, fangs and
  patches made them cartoons rather than creatures. A mouth is a jaw bone that
  moves, drawn only where the head's shape needs it — the underside of a beast's
  snout, the lower half of a raven's beak — and, like the spider's jaws in its
  minimal look, a fish's is the bone and nothing more.
* **It faces where it is going.** The prey never turned: its collider is a ball,
  so it had no reason to. The body turns to its heading instead, and pitches nose
  up when it climbs.
* **What you see is what you hit.** Each body is laid out so that from the front
  of its head to the tip of its abdomen it is centred on the creature's middle,
  about the length of its hitbox. Legs, feelers and wings reach past it, the way
  the spider's legs reach past its collider. A walker's body drops until its feet
  reach the bottom of that collider, which is where the floor is.

No foot is planted and nothing looks at the world. That is the spider's gait and
it is expensive; on something a centimetre long, a leg that swings in the right
rhythm is indistinguishable from one that grips.

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
| **Shift** | **Sprint**, out of a pool of a few seconds that fills back up while you walk. It costs more per size class of whatever is on your line, which is what makes hauling something home at a run a decision rather than the obvious move (§2) |
| *walk into a wall* | Climb it. Keep going for the ceiling. |
| **Left Mouse** | **Go there, trailing a line.** A surface pulls you over; a line puts you on it; something you already caught comes to you instead. A creature still on its feet is none of those, so the aim reads straight through it to whatever is behind (§2). As far as silk reaches, which grows with you (§7). Three lines at a time — a fourth takes the oldest down (§5) |
| **G** | **Grapple style**: the pull above, or the line — a line from your feet to where you point, with you standing on it; walking it is fast (*Two grapples*, §7) |
| **Right Mouse** | **Cast what is in hand** — the web, to start with (§3.2). With the web in hand: |
| **Right Mouse** *(tap)* | **Shoot a web.** A surface gets one built against it, something alive gets wrapped where it stands, a miss runs out at the end of its reach. The same reach the grapple has, and a web thrown near the end of it is thinner (§7). With the cross on a creature, the silk is thrown at where it will be (*Leading what the cross is on*, below). Then a short wait before the next (§5) |
| **Right Mouse** *(hold)* | **Wind up a ball of silk**, held over the spider's back where you can see it. The longer you hold, the bigger the web and the wider the ball's catch — up to the biggest this body can spin, in about a second. The view lifts above the spider and widens while you hold |
| **Q** | The next spell you have — growing, and what you eat, opens more (§3.2) |
| **1–9 / wheel** | Pick a pocket on the bar |
| **E** | Evolution — what you are, and your odds on what eating could make you |
| **F** | Wrap the prey you are looking at, then drain it. At a shrine in the Hollows, rest (§12) |
| **X** | Pull down the web or line you are looking at |
| **L** | Camera: third person or first person |
| **O** | The spider's look: detailed, low poly or minimal (§7, *The body*) |
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
deserves no forgiveness — but anything alive is hit with a swept ball: the ball
you can see, touching the creature's own hitbox. A fly is five centimetres
across and wandering; asking a player to put a hairline through one is asking
for a precision no amount of practice reaches, and for a while the honest report
was "I spent a few minutes shooting and could not catch anything".

The first answer to that overshot, and the report came back the other way:
*shooting always hits*. The catch ball was a good deal wider than the web being
thrown and never less than two and a half body lengths — sixty centimetres either
side of the line on a spiderling's tap, a metre and a half wound up — so every
shot anywhere near a creature took it and where you aimed stopped mattering. The
catch is now the ball itself, `WebBuilder.held_bodies` from 0.12 to 0.4 body
heights, plus `Prey.hit_radius()`: the bead in flight is drawn at exactly that
size, so a miss is a miss you could see happen.

It also turned up a test that had been passing for the wrong reason. The web
suite put the spider back between sections without putting it the right way up,
so a section that followed one ending on a ceiling aimed from a spider still
rolling off its back — half a metre wide at three metres, which the old catch
simply swallowed.

The **wind-up** is the other half of the same problem, and it is a choice
rather than a fix. A tap is the fast, fallible shot and is unchanged. Holding
winds a ball of silk up over the spider's back — a wizard with a fireball — and
what the second buys is **size**: the web grows from the smallest this body can
spin to the biggest, and the ball carrying it more than triples. A bigger ball is
easier to hit with, which is the help that was wanted, and the throw is still
yours to aim.

This replaced a one-second lock-on. Holding the cross on a creature for a second
used to *guarantee* the catch, with the bolt steering itself all the way in.
That worked and it was no fun: a promise removes the shot, and the reply when we
tried it was that it was too easy. Nothing homes now. The wind-up is the whole
of the help, it is legible — the thing you watch grow is the thing that got
easier to hit with — and one rule covers web size everywhere, because it is the
same span a held place grows through.

### Leading what the cross is on

**Decided: a shot at a creature is thrown at where it will be, and the bolt still
flies dead straight.**

The ball and the wind-up made a *still* creature fair to hit. A moving one was
still out of reach, and the reason is arithmetic. A spiderling's silk flies at
under eight metres a second, so it takes most of a second to cross a room, and a
fly covers a metre in that time: twenty times its own width. Aimed at where a fly
*is*, a shot can never catch one that's moving. We fired perfect taps at wandering
creatures, forty each, with the cross dead on:

| Creature | Aimed where it is | Aimed where it will be |
|---|---|---|
| Fly, 3m | 0% | 98% |
| Fly, 6m | 0% | 90% |
| Mosquito, 5m | 5% | 80% |
| Wasp, 5m | 0% | 62% |
| Midge, 5m | 0% | 58% |
| Butterfly, 5m | 5% | 100% |

So leading was never a skill the player could learn. The screen never shows how
long the silk will take, and without that there's nothing to judge a lead by.
The game does the sum instead, and the crosshair shows the result:

* **Picking.** A shot goes for the creature nearest the cross whose outline comes
  within two degrees of it (`WebBuilder.shot_pick_angle`), measured as the camera
  sees it, in reach, and in plain sight of the spider. A fly five metres off is
  about a degree across, and asking for that exactly is the hairline problem again.
* **Leading.** The bolt is thrown at the point where it and the creature arrive
  together, if the creature keeps going as it is (`SilkShot.intercept`).
* **Showing.** Brackets close round the picked creature and a dot marks where the
  shot will meet it, so you can see the lead being taken and judge it.

This is not the lock-on come back. That one steered the bolt all the way in and
promised the catch. This promises nothing. The bolt flies straight, so a creature
that changes course while the silk is in the air has changed course away from
it. Those are the midges and the wasps, which is right: the ladder of what is
hard to catch comes from how creatures fly, not from how well the player can
guess flight times. You still have to put the cross on the creature, the pick is
a small ring rather than a cone a third of the screen wide, and a wind-up still
buys a bigger ball.

### The crosshair

**Decided: the crosshair shows what silk will do, and draws nothing it can't back
up.**

It was a four-pixel dot. It is drawn now, and everything in it comes from the
answers the grapple and the shot act on:

* **A ring the size of the pick.** A creature whose outline reaches inside it is
  what a shot will be thrown at.
* **Three states.** Bright when there is something in reach for silk to land on,
  faint when there isn't, amber when a creature is picked.
* **A red ring where the grapple will really land**, whenever that isn't the
  middle. The camera sits above the spider and sees over things the spider can't,
  so silk can stop short on a ledge the cross is looking past. Before, the only
  sign of that was a grapple going somewhere unexpected.
* **An arc round the ring** that fills while the next shot is spun, and fills
  amber while a throw is wound up.

The readout beside it changed for the same reason. It used to name whatever the
fangs would pick, a cone a third of the screen wide, so it could promise catches
that a shot at the cross would never make. It names what the shot will pick now.

**The camera frames the wind-up instead of hiding it.** Aiming used to drop to
first person, on the reasoning that third person has the cross and the silk
leaving from different places. That is true and it turns out not to matter: a
thrown ball leaves the spider *toward whatever the cross is over*, which is
exactly what the third-person aim already works out. What the flip cost was the
one thing worth having — watching the spider wind up. So the pivot **lifts above
the spider** and the view **widens** as the charge fills, and both ease back
after; nothing travels. See *Framing a throw* in §7. The ball grows and brightens
with it, so the charge has a reading in the world as well as on the HUD, and you
never have to look away from the fly to read it.

---

## 10. Build order

**Milestone 1 — Web building** ✅ *(this commit)*
Anchor-based web construction, procedural web meshes, silk economy, size
tiers that rescale the player, snaring prey, wrap/drain feeding, HUD.
Playable in the character-controller example level as a sandbox.

**Milestone 2 — Being a spider** *(nearly done)*
Done: wall and ceiling climbing with surface-aligned movement, a levelled
horizon, the dragline — drop, pay out, reel in, swing, let go — ziplines, and an
eight-legged rigged body whose feet find whatever is underfoot (§7, *The body*).
Left: the legs in first person, reaching for the surface at the edges of the
frame. First person hides the body for now. The camera defaults to third person
and never rolls; that is settled, see section 7.

**Milestone 3 — The world** *(built)*
Done: the hunting ground — a camp and six places in one wild valley, to one
scale, furnished from a kit of props, each built for a stretch of sizes and
stocked by dens with what lives there (§4); water you swim in; a day and a
night. Before it came a shed, the sewers under a park and the park with its
lake, with a drain lid and a grate between them and boats that went round the
lake; they were retired for the valley.
Left: real prey lanes, running water that takes silk back, wind and weather,
and the first "you are too big for this" moment made to land.

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

**Milestone 5 — The loop at scale** *(started)*
Done: the valley lives (§8.1) — hunger, fear, dens that breed on what is eaten,
hours kept by day and by night, the big things roaming between haunts, turf
wars and the wounds they leave — and with it a reason to go back through the
places you have outgrown.
Left: packs that hunt together, creatures that learn a web they have been
caught in, and the valley remembering what you did to it.

**Milestone 6 — Evolution and magic** *(started)*
Done: traits come from what you eat, by chance — likelier up the ladder, never
locked out by bad luck, and certain from anything two sizes past your bite —
and anything you can hold, you can eat (§3.1). Spells: the thrown web is the
first, then Venom Spit, Water Spiral and Summon Lightning, opened by growing or
by traits, working off each other and off the silk, and changed by what you
have become (§3.2).
Left: more spells and more traits to feed them — a water line to go with the
spiral, for a start.

**Milestone 7 — The Hollows** *(prototype)*
Done: creatures that fight back — every attack a tell, a strike and an opening,
seven kinds of strike, six hostile species and two bosses (§12); a second
grapple, the line; the spider held at one size; shrines, waking and resting;
shortcut gates opened from the far side; a sealed lair with something kept in it;
a boss that walks a beat; and the Hollows themselves, a hub and five places
joined in loops.
Left: the skill tree that size is meant to come from (a "Big Body" that buys
stamina with size), spells and web interactions built for fights rather than
hunts, more bosses, and everything about how it looks.

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
  breaking this: you hunt differently, you never eat less.
* **A trait is a change to the animal.** If it cannot be described as something
  the spider grew, it does not belong on the tree. No flat percentages with
  nothing behind them, no respec, no points — and nothing that is only a number
  on a screen the player has to go and read.
* **Gates are physical, and say nothing.** A threshold is a thing in the world
  that responds to your body — a sprung lid, a weak flap, a drop you can now
  survive, or more often what lives past it. If it needs a line of dialogue or an
  objective marker to be understood, it is the wrong gate. Prefer a shape the collider decides over a
  rule that compares; prefer a rule that compares `body_height` over inventing
  a second number to compare instead.
* **Nothing expels the player.** Places are left because somewhere else is
  better, never because this one stopped working. The first place must stay
  worth having, because it is where the network is.
* **No deadline over the whole game.** The valley's day goes round and changes
  what is out, but nothing falls due when it does. Time pressure belongs to *one
  place* or one hunt; your life does not have a deadline. A global quota would
  make this a game about a number.
* **Places are rungs, so keep them small and dense.** Each is built for a
  stretch of sizes and passed back through on the way up, not played out. The
  size jump is the reward; acreage is not.


---

## 12. The Hollows — a souls-like prototype

The valley is a hunting ground: nothing in it means you harm, it simply eats
things your size, and growing is how you stop being one of them. The Hollows ask
a different question: what if the creatures fought like the spider does — with
moves of their own — and the world were **a handful of
dungeons pressed together into one place**, the way a souls-like's world is,
rather than a valley or a sequence of levels? Compact, so it is never too much
world. Open, so nothing is locked behind a power you do not have. And looped, so
the deeper you go the shorter the way home becomes.

It is a greybox on purpose. Every place is a colour and a light of its own and
the shapes are enough to read and to string silk between; the creatures are the
valley's bodies, skeletons and all, with no new animation. What is being tested
is whether the *shape* is fun.

### The decisions it rests on

* **The spider stays silk.** It does not get claws or a sword. What it learns are
  spells, and the interesting fights are the ones where a spell and a web meet.
  Binding is still the only way a fight ends: a hostile's health *is* how much
  silk it can shrug off, and a boss is a creature with a lot of it.
* **One size, the whole way.** In the Hollows the spider is a Huntsman and stays
  one: it does not grow by eating, and a meal passes no trait on either, since
  some traits are size (`grows_by_eating`, `evolves_by_eating` and `start_stage`
  on the spider). Size is meant to come from a skill tree instead — a "Big Body"
  that buys stamina at the cost of being bigger is the example — which is not
  built yet. The one trait to be had is the one a boss keeps.
* **Everything is hostile.** No size rule and no aggression roll: a hostile thing
  comes for you whatever either of you is, as long as it can see you (walls block
  sight; silk does not), and only gives up when you are well out of its range.
* **Mending is a decision.** Condition does not come back on its own here. A
  shrine makes you whole, and so does a meal — every mouthful of something you
  wrapped and drained gives some back. That is what ties fighting to the hunt: the
  thing you beat is the thing that heals you.
* **The grapple is tamed by choice, not by nerfing.** G switches to the line
  grapple (§7, *Two grapples*): it lays a road and you walk it, fast, so escaping
  is two things and the second is where you can be caught.

### The shape

```
                        the Tower ── the Belfry (shrine)
                            │
   the Library ──── the Ruined Courtyard ──── the Graveyard (shrine)
   (gallery shrine)         │      ╲             │
       ║ gate ┄┄┄┄┄┄ the Shrine Hall ┄┄┄┄┄┄┄┄┄┄┄┄┘
       ║ (opened from   (shrine, lit)
       ║  the library)      ┆ hatch (opened from below)
       ▼ stair              ┆
   the Ossuary ── the Crypt Way ── the Sunken Cells ── the Rat King's Hall ── the Undergate
                                   (shrine)            (sealed lair)          (the hatch's lever)
```

* **The Shrine Hall** is the hub, and the only place with nothing hostile in it.
  It opens north into the courtyard and east into the graveyard, and the two of
  those are joined — the first loop, open from the start.
* **The Ruined Courtyard** is the big open room: a dry fountain, a broken
  colonnade, fallen walls to put between you and a charge. Blade rats, charger
  beetles, a mosquito, and the wyrm on its rounds.
* **The Graveyard**: rows of stones and two crypts, frogs among the stones and
  mosquitoes over them, a shrine in the far corner. The wyrm's other ground.
* **The Library**, west of the courtyard: tall shelves in aisles, a gallery down
  the west wall with a shrine on it, bats in the aisles and wasps on the shelves.
  Its gate back to the hall opens from the library side only — the first
  shortcut, reached the long way round.
* **The Tower**, north of the courtyard: four floors, each with a hole in a
  different corner, so the way up winds, and fliers on every floor. The belfry at
  the top is safe, and has a shrine.
* **The Undercroft**, down the stair under the library's gallery: the ossuary you
  land in, the crypt way, the sunken cells with a shrine before the boss, and the
  Rat King's hall. Past the hall is the undergate, a room under the Shrine Hall
  whose lever opens the hatch in the hall's floor: the second shortcut, and the
  way home from the deepest place.

Every room is shut on all six sides. A spider climbs whatever it is given, so the
only way out of a room is a door, a gate spans its passage wall to wall and floor
to ceiling, and a lever is touched rather than shot.

### Shrines, waking, resting

* **Touch a shrine and it is lit**, and it is where you wake from then on.
* **Driven off** — condition at nothing — you wake at the last shrine you lit, whole
  and with nothing in your hands, and every hostile is back on its feet at its
  mark (`HostileSpawn`). Silk you put up stays: it is the one thing you keep, and
  what makes scouting a lair worth a trip.
* **Rest (F) at a shrine** and you are whole, and the Hollows stir the same way.
  Not with something coming for you.
* **A boss that beat you** is back at its post as though you never came. **One you
  have beaten** stays beaten, through every rest and every waking.
* **Shortcuts stay open.** A gate once found is yours.

### Creatures that fight back

Every attack is three beats, because that is what makes being on the end of one
fair (`CreatureAttack`, `CreatureFighter`):

1. **A wind-up you can see**: the creature stops, turns to you, and a tell in the
   attack's colour shows where it will land — a ring round it, as wide as a burst
   or a sweep, and a line along the ground to you for a lunge or a tongue —
   brightening as the moment comes.
2. **The strike.**
3. **An opening**: it stands there for a moment, which is when to put silk on it.

Anything that takes it out of the fight mid-attack — a web, a stun — ends the
attack there, tell and all. There are seven kinds of strike:

| Kind | What it does | Answer |
|---|---|---|
| **Bite** | the last step, and a bite, if you are still in reach when it closes | step back during the tell |
| **Lunge** | a straight dash at where you were when it committed; a drill that hits a wall instead sticks there | step aside once it goes; a web across its path catches it |
| **Spit** | a glob that flies straight at where you were | step aside; silk between you stops it |
| **Tongue** | a line out to you that drags you in to be bitten | anything between you — a web, a wall — takes the tongue |
| **Burst** | everything round it at once: thrown, hurt, dazed | be outside the ring |
| **Sweep** | an arc in front of it; it can cut every line and web it passes | do not be in front of it, and do not trust your silk |
| **Summon** | calls more of a kind, up to a limit | deal with the caller |

**Holding ground and giving it.** A creature closes on you only for a move it would
come after you for; a spitter's sting or a squatting frog's bite is kept for when
you come to it. Something too close for the move it would rather use backs off
until it has room — a spitter gives ground, a beetle backs up for a run-up — and
something in reach and waiting holds its ground rather than walking into your web.

### The hostiles

All of them in `game/data/hostiles/`, each with a bite of some kind and one move
of its own. Shots are orb-web shots from close range by a Huntsman.

| Hostile | Its own move | What it does | Shots |
|---|---|---|---|
| **Drill Mosquito** | Drill Dive — lunge, 2 to 7 m | hangs back and comes straight at you: 6 and a throw. Missing, it goes into whatever is behind you and sticks | 2 |
| **Blade Rat** | Slash — 150° sweep | 5, and cuts every line and web in front of it | 3 |
| **Charger Beetle** | Horn Charge — lunge, 2.5 to 9 m | a second of scraping, then 7 and a long throw. A web across its path catches it outright | 3–4 |
| **Spitter Wasp** | Venom Spit — 2.5 to 10 m | 4 a glob, from well off; it never comes in, and backs away if you do | 2 |
| **Tongue Frog** | Tongue Lash — 2 to 7 m | squats and waits, then drags you to its mouth | 3 |
| **Screech Bat** | Screech — a 2.6 m ring | throws you and dazes you for a second: no moving, no casting | 2–3 |

### Bosses

A boss is a species marked `boss`: while it is coming for you its name is across
the foot of the screen with a bar of the fight it has left.

* **The Rat King** is the miniboss, and keeps to a structure: its hall at the far
  end of the Undercroft, a lair you can look into and scout first. Step over the
  threshold with it alive and veils of old silk drop over the way in. It whirls
  where it stands and cuts every thread round it, calls two blade rats out of the
  walls, pounces across the room and bites hard. About five shots. Beat it and
  the veils are gone for good, the way on to the undergate opens, and what it
  kept is yours — Wing Buds, which is a glide and the key to Summon Lightning.
* **The Hollow Wyrm** is the main boss, and keeps to no room: it walks a beat
  through the courtyard and the graveyard, moving on from each point after a
  while, so wherever you are on its rounds is where you fight it. It dives, spits
  fire from across a room, throws a gust that dazes you and tears silk down, and
  sweeps with its tail. About seven shots.

The two could swap — the main boss in the structure, the miniboss roaming — and
nothing in the code cares which: a lair takes any keeper and a beat any mark.

### Open questions

* Whether binding as the only way to win a fight holds up against a boss, or
  whether spells need to do more than soften.
* How strong a web should be against a boss. A boss walking into a sheet web is
  stuck in it like anything else, which may be the best fight in the game or a
  cheese; the whirl and the gust that tear silk down are the first answer.
* What the skill tree is, and whether size from it changes the rooms the way
  size from eating changed the valley.

