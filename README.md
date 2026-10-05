# Put the Flies in the Bag

*(working title — the repository is still `spoolunky`)*

A farming game in Godot 4.6. You are a magic spider with an empty field and a few
coins, and you turn it into a fly farm. Fence off pens, put in troughs, ponds and a
compost heap, buy a brood of flies and raise them — fed, watered and with room to
move they grow to market weight and their grade climbs from A1 to A5, the way a
herd is raised for marbling rather than just for weight. Then you harvest: a ball
of silk wraps a fly on the spot, a line drags the bundle to a prep table, and your
spells cook it — the water spiral washes it, the gust dries it, lightning
tenderises it, clay seals it in a crust, fire cooks it and the pullback pulls it.
Into the bag it goes, and the market buys the bag. Expand the empire.

The game used to be a dungeon crawler about hunting with webs and a spell tree;
that is all still on the `claude/eager-gauss-g1mosx` branch. This branch kept the
spider — its climbing, its grapple, its body and camera — the insect bodies and
skeletons, the spell visuals, the tether and the HUD's bones, and threw the rest
away. The design notes are in [`docs/DESIGN.md`](docs/DESIGN.md).

## The loop

```
  BUILD                 STOCK              KEEP                  HARVEST
 fence a pen,      →   a brood of     →   flies eat, drink,  →  silk wraps one,
 trough, pond,         flies in it        grow, breed in the     a line drags it
 compost heap                             compost heap           to a prep table
      ↑                                                                │
      │                     SELL                   COOK                ↓
      └──────────────  the market buys  ←  each spell is one step: wash, dry,
                       the bag             tenderise, crust, cook, pull — F
                                           takes the dish into the bag
```

## Controls

| Input | Action |
|-------|--------|
| WASD / Space / Shift | move, jump, sprint |
| *walk into a wall* | climb it — walls, fences and ceilings are floors to a spider |
| **Left mouse** | **grapple** to wherever the cross is — or, on a wrapped fly, put a line on it and drag it |
| **Q** | let go of the line |
| **Right mouse** | cast the spell in hand |
| **1–7**, wheel, hold **Tab** | pick a spell (Tab brings up the spell disc and slows the world while you choose) |
| **F** | open/shut a gate · take the dish off a prep table · sell at the market · cut a plain bundle free · put the bundle on your line onto a table |
| **E** | the shop: build, and buy flies |
| *while building* | left mouse puts it down, **R** turns it, right mouse puts it away |
| **X** | take down whatever built thing the cross is on, for half back |
| **L** / **O** | camera: third or first person / the spider's look |
| **H** / **T** / **Esc** | help / free the mouse / back out of a menu or free the mouse |

## The farm

The land is a grid of 24 × 24 squares, two metres each. **Fence** goes up a run at
a time — click a corner, then the opposite corner, and the outline between them
goes up. A patch of ground closed in on every side is a **pen**; flies keep to the
pen they are in, fliers or not. A **gate** goes into a fence and F opens it — and a
pen with its gate open is open ground, so the flies wander out.

| Structure | Cost | What it does |
|-----------|------|--------------|
| Fence | 5 a length | makes pens |
| Gate | 20 | a way in and out; open, the pen is not a pen |
| Fruit Trough | 30 | feeds the pen — six meals, refilling slowly |
| Pond (2×2) | 45 | water for the pen, never runs dry |
| Sugar Bowl | 25 | flies keep better: grade climbs half again as fast |
| Shade Tree | 35 | flies keep better, and it is something to climb |
| Compost Heap | 60 | two grown flies and room to spare: a new fly now and then |
| Prep Table | 40 | where a catch is made into a dish |

A fly is kept well when it is in a pen and neither starving nor parched. Kept well
it grows (slower if the pen is crowded) and its grade climbs; let it go hungry or
thirsty and its grade slips back. The readout under the cross says how any fly or
pen is doing.

## The kitchen

| Spell | Step | Rules |
|-------|------|-------|
| Silk | wraps a fly on the spot | — |
| Water Spiral | wash | before it is crusted or cooked |
| Gust | dry | after washing |
| Summon Lightning | tenderise | before it is crusted or cooked |
| Clay Crust | crust | before cooking; nothing else gets in after |
| Fire Breath | cook | makes it a dish |
| Pullback | pull | only once it is cooked |

The name says what was done — *Roast Fly*, *Gritty Roast Fly* (cooked unwashed),
*Pulled Tender Crispy Clay-baked Fly*. A dish's worth is the fly's value × how far
it grew × its grade (A1 ×1 to A5 ×2.8) × what the kitchen did; anything taken off
the table uncooked sells for half.

## Where things are

```
game/
  data/        spells, the fly, and the structures (plain resources — edit the
               numbers), the catalogue that loads them, and the rig's bodies
  farm/        the farm: its grid and pens, the insects, the structures, the
               market, and the kitchen's rules and dishes
  player/      the spider, one node per job: climbing, the grapple, the camera,
               the body and gait, the tether, the bag, the spells, the disc and
               the builder
  spells/      what spells look like when they go off
  rig/         bodies: bones, meshes skinned to them, the motion that poses them
  ui/          HUD, shop, spell disc, crosshair
  web/         drawing silk, and the thrown ball of silk
  world/       the farm's land, the sky and ground every place has, paints, and
               the kit the pieces in Pieces/ are placed by
Pieces/        a kit of pieces, as .fbx
tools/         the import that makes each piece solid, the bake that turns the farm
               into a scene, and the tab check
tests/         five headless suites and a screenshot tool
```

The game opens on `game/world/farm.tscn`, baked from `game/world/farm_land.gd`:

    godot --headless --path . --script res://tools/bake_level.gd -- --force farm

## Checks

    python3 tools/check_tabs.py
    godot --headless --path . --script res://tests/movement_smoke_test.gd
    godot --headless --path . --script res://tests/creature_smoke_test.gd
    godot --headless --path . --script res://tests/farm_smoke_test.gd
    godot --headless --path . --script res://tests/kitchen_smoke_test.gd
    godot --headless --path . --script res://tests/world_smoke_test.gd

To look at it without playing:

    xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 \
        --path . --script res://tests/screenshot_farm.gd -- stocked
