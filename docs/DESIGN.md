# Put the Flies in the Bag — Design Notes

> You are a magic spider with an empty field. Fence it, stock it with flies, keep
> them well, and cook them with spells. Every fly you sell builds the next pen.

**Where it stands now.** A first playable farm: one field, one crop (flies), the
structures to keep them, a kitchen of six spells, and a market. Frogs and other
creatures that use flies are the next layer (§7). The old hunting game — webs,
the spell tree, the ruins and the dungeon — is on `claude/eager-gauss-g1mosx`.

---

## 1. The pitch

A farm sim about **raising one thing very well**. Flies are the only stock, and
that is the point: one resource keeps the economy readable, and the depth is in
how well you keep them and what your kitchen does with them — the way a wagyu
farmer is not raising more kinds of cow, but better ones.

The spider does the work with what a spider has: it climbs everything, it
grapples anywhere it can see, its silk catches, and its magic cooks.

## 2. The loop

1. **Build.** Fence a pen (§3), put in a trough and a pond.
2. **Stock.** Buy a brood of flies into the pen.
3. **Keep.** Flies get hungry and thirsty; they go to the trough and the pond on
   their own. Kept well they grow and their grade climbs (§4). A compost heap
   breeds more.
4. **Harvest.** Silk wraps a fly instantly — no partial wraps — and left mouse on
   the bundle puts a line on it. Drag it to a prep table; it goes onto the table.
5. **Cook.** Each kitchen spell is one step on the bundle (§5). F takes the dish
   into the bag.
6. **Sell.** F at the market empties the bag into coins. Build more.

## 3. Land and pens

The land is a 24 × 24 grid of two-metre cells (`FarmGrid`). Things that take up
ground stand on cells; fences and gates stand on the edges between them, so four
of them close off a square without using any of it.

Pens are worked out, not drawn: every cell floods out to its neighbours across
any edge that lets things through, and a region the flood cannot leave the land
from is a pen. That is cheap enough to redo whenever a fence goes up or a gate
moves, and it makes the gate meaningful: open, its pen joins the open ground and
the flies can wander out.

Flies keep to their region — walkers are stopped by the fences themselves, fliers
by the rule that a step onto other ground is not taken. So a pen needs no roof.

## 4. Keeping

Per fly (`Insect`), all numbers in `game/data/insects/fly.tres`:

- **Hunger and thirst** creep from 0 to 1. Past ½ the fly goes to a trough or a
  pond in its pen. Past 0.85 it is suffering.
- **Content** = in a pen and not suffering. Content flies **grow** (hatchling to
  market weight in `grow_time`, slower when crowded) and their **grade** climbs
  (A1 → A5 over `grade_time`, faster with a sugar bowl or shade tree). Suffering
  flies' grade slips back.
- **Room**: each fly wants `space` m². A pen with more flies than room grows them
  all slower and keeps them worse.
- **Troughs** hold six meals and refill one every ten seconds, so a trough keeps a
  few flies fed and a crowd hungry.
- **Compost heaps** breed: every 30 s, if the pen has two grown, content flies,
  water, and room for one more, a hatchling crawls out.

## 5. The kitchen

Every spell but silk is exactly one step, done to the bundle on a prep table when
the spell is cast at the table or at the bundle (`Prep`):

| Spell | Step | × worth |
|-------|------|---------|
| Water Spiral | wash | 1.3 |
| Gust | dry | 1.15 |
| Lightning | tenderise | 1.25 |
| Clay Crust | crust | 1.3 |
| Fire Breath | cook | 1.6 |
| Pullback | pull | 1.2 |

Rules: dry only what is washed; a crust seals it (only fire gets in after); pull
only what is cooked; nothing is done twice. Cooked unwashed is *gritty* (×0.6);
taken off uncooked it is *raw* (×0.5). A dish is worth the fly's value × weight
(0.3 for a hatchling to 1 grown) × grade (A1 1.0, A2 1.25, A3 1.6, A4 2.1, A5 2.8)
× the steps. The best dish is about six times a plain roast.

The water spell is the water spiral — what used to need water and wind together
is now one spell. Spells no longer work off each other: what they work on is the
food.

## 6. The spider

Kept: walking, climbing any surface, jumping, sprinting, the grapple on left mouse
(no wait between grapples), the camera, the eight-legged gait, the spell disc.
Gone: hanging from silk, draglines, zip lines, web building, growing, traits,
health and stamina. The tether drags bundles over fences — a line caught on
something lifts what it holds up and over.

## 7. Next

- **Frogs.** They eat flies. Either a collector (frogs catch loose flies into a
  crate — automation) or a converter (fed flies, harvested for frog marinade that
  makes fly dishes worth more) — or both. The insect body code is generic, and the
  old branch has a frog body to start from.
- **Orders** at the market — "wanted: Crispy Roast Fly, A3 or better" — so the
  kitchen has reasons to cook more than one dish.
- **Saving** the farm between sessions.
- Fly breeds, or upgrades to the structures.
