# Developer Guide

## Architecture

The simulation is plain GDScript running on a **fixed 30 Hz timestep** (`Game.step()`), driven
from `_physics_process`. Game speed runs 0.25-8 steps per physics frame. Rendering is decoupled:
entities update their `pos` in the simulation and Godot's physics interpolation smooths drawing.

```
scripts/
  autoload/data.gd        Loads every balance file in data/ (units, buildings, weapons...)
  autoload/config.gd      Settings, remappable key bindings, saved cheat preferences
  core/game.gd            Match manager: players, entities, simulation loop, placement,
                          production hooks, fog of war, victory, save/load, commands
  core/map_grid.gd        Terrain grid, ore, building occupancy, AStarGrid2D per movement class
  core/map_gen.gd         Procedural map generator + JSON map loader/exporter
  core/player.gd          Credits (cash + stored resources), storage, power, tech, vision
  core/spatial_hash.gd    Grid partition for fast neighbour/target queries
  core/terrain_art.gd     Procedural terrain and ore tile textures
  core/terrain_blend.gd   Soft transitions between terrain types
  entities/entity.gd      Health, armor, damage, death
  entities/unit.gd        Orders, path following, targeting, weapons, harvesting, deploying
  entities/building.gd    Construction, production queues, power, repair, defenses
  entities/projectile.gd  Travelling munitions; entities/effect.gd cosmetic effects
  entities/sprites.gd     Procedural artwork for all units and buildings
  systems/combat.gd       Firing, warhead-vs-armor damage, splash
  systems/ai_controller.gd  Computer opponent (same functions as the human)
  systems/cheats.gd       Developer console commands and cheat flags
  systems/audio_fx.gd     Procedural sound effects and music, Music/SFX/UI buses
  ui/                     Main HUD, sidebar buttons, minimap, input controller, cheat panel
  view3d/view3d.gd        3D presentation: camera, light/environment, entity models, effects,
                          placement ghost, selection/health overlay, screen picking
  view3d/terrain3d.gd     Height-mapped terrain mesh, water shader, instanced props and ore, fog shading
  view3d/models.gd        Procedural 3D models for all units and structures
  view3d/fx3d.gd          3D explosions, muzzle flashes, tracers, arcs, scorch marks
  ui/view2d.gd            Classic 2D camera with the same API as View3D
  main.gd                 Menus, skirmish/sandbox setup, settings, save files, match lifecycle
tests/test_runner.gd      Automated headless gameplay tests
```

Key rules:

- **The AI uses the same API as the player**: `Game.queue_item`, `Game.place_structure`,
  `Game.command_group`, `Unit.cmd_*`. It receives no hidden resources.
- **Cheats change the real state**: `Cheats.execute()` edits `Player.cash`, `Player.resources`,
  queue timers and entity health directly; the GUI panel only builds command strings.
- **Credits** = `cash` + stored `resources` (ore, gems). Harvested resources are limited by
  storage (refineries + silos); spending uses stored resources first, like the classic games.
  All balances clamp at `Player.MAX_VALUE`.
- **Production** is paid gradually while building. If money runs out the item goes "on hold".
  Cancelling refunds `paid * refund_ratio` (Settings).

## Art pipeline (pre-rendered sprites)

```
tools/art/kit.gd          Mesh kit: chamfered/convex solids from planes, lathe, extrude, tubes;
                          painted bake shader (panel lines, grime, stripes, burn, cut-away)
tools/art/kit.gd (cont.)  loft() streamlined bodies, limb() tapered capsules, ellipsoid(), ik()
tools/art/humans.gd       Soldiers in metres (1.8 m, ~7.5 heads), FK legs + two-bone IK arms,
                          per-faction uniforms (camouflage shader), weapons, poses
tools/art/vehicles.gd     Faction-specific armour, logistics, aircraft (rotor info) and ships
tools/art/hd_models.gd    Shared palettes/materials (older vehicle models kept for reference)
tools/art/hd_buildings.gd Structures, scaffolding, trees, rocks and props
tools/art/buildings2.gd   Airfield, naval yard (on water), repair facility, SAM site, flak cannon
tools/art/catalog.gd      Named model sets for previews, cameos and the catalogue posters
tools/showcase.gd/.tscn   High-resolution model renderer (auto-framing, one PNG per item or a grid)
tools/make_catalog.py     Faction catalogue posters -> docs/screenshots/catalog_<faction>.png
tools/bake_specs.gd       List of every sprite sheet: frame size, anchor, frame count, states
tools/bake.gd/.tscn       Renders each frame 3x supersampled + team mask + projected shadow pass
tools/finalize_sprites.py Downsamples, composites soft shadows, finishes edges -> assets/sprites
tools/paint_assets.py     Painted terrain textures, ore, effects, HUD metal and emblems
tools/make_cameos.py      Sidebar build icons (from showcase renders, else from baked sprites)
```

Rebuild everything (needs a GPU or a software Vulkan driver):

```
# Infantry, aircraft, ships, effects and decor: hand-drawn style
godot --path . res://tools/bake.tscn -- "i_,u_heli,u_jet,u_transport,u_bomber,u_gunboat,u_destroyer_coalition,u_submarine,u_cruiser,d_" --toon
# Structures, defenses, walls and land vehicles: realistic (no --toon)
godot --path . res://tools/bake.tscn -- "b_,u_tank,u_jeep,u_aa_,u_harvester,u_mcv,u_minelayer,u_mecha"
python3 tools/finalize_sprites.py
python3 tools/paint_assets.py
godot --path . res://tools/showcase.tscn -- cameos <absolute path>/tools/_bake_out/cameos/ 400 --toon
for f in tools/_bake_out/cameos/*.png; do python3 tools/stylize.py "$f" "$f" 3; done
godot --path . res://tools/showcase.tscn -- cameos <absolute path>/tools/_bake_out/cameos_real/ 400
python3 tools/make_cameos.py
python3 tools/make_catalog.py
godot --headless --path . --import               # refresh imported textures
```

Sheet conventions: art resolution is 2x (a cell is 128x64 px, 90.5 px per world unit, a unit of
height is 78.4 px). Directional sheets store frame `state * dirs + dir`; direction 0 faces world +X
(screen lower-right) and increases with `Unit.facing`. Each sheet has a JSON file with frame size,
anchor (the model's ground origin; for structures the footprint's top corner), grid columns,
frame count and extras (turret pivot, smoke points, structure height). `_mask.png` holds the
team-colour mask that `SpriteLib.team_material()` uses to recolour per player.

Painted cameos (made with an image generator) live in `tools/ai_cameos/<type>_<faction>.png`
and override the rendered ones; a file named after a country (`e1_thailand.png`) becomes a
country-specific cameo that `BuildButton.cameo_for()` prefers. `make_cameos.py` takes building,
defense and vehicle cameos from `cameos_real` and the rest from
the inked `cameos` renders, on a navy card plate; `BuildButton` draws the price tag, name bar and
border on top. Walls use one sheet per side (`b_wall_<faction>`) with 32 frames: the neighbour
mask (N=1, E=2, S=4, W=8) picks frames 0-15, damaged sections add 16 (`IsoView._wall_mask`).

**Hand-drawn style** (infantry, aircraft, ships): `--toon` switches the paint shader to cel shading
(`ArtKit.toon_mode`, three flat light bands and a crisp highlight) and marks the sheets;
`finalize_sprites.py` then runs `tools/stylize.py` on the 3x supersampled frames: an ink line
around each silhouette, thinner ink where colour bands meet (computed on a median-smoothed copy
so camouflage and panel texture stay clean), slightly richer colours and pencil grain.

Aircraft sheets set `extra.air` and write a separate `_shadow.png` (drawn on the ground while the
body is lifted by `Unit.altitude_now`); helicopters carry `extra.rotor` (hub position, radius,
blade count) and `IsoView` draws the spinning rotor disc. Ships bob slightly and leave a wake;
own submerged submarines are drawn translucent and enemy ones are hidden unless detected.

**Adding art for a new unit**: build its model in `vehicles.gd` / `humans.gd`, add a `vehicle()`/`infantry()`
entry in `bake_specs.gd` named `u_<sprite>_<faction>` (or `i_...`), bake, finalize, and add a
cameo mapping in `make_cameos.py`. Structures use `building()` and are named `b_<sprite>_<faction>`.

## Presentation layers (isometric, 3D and 2D)

`IsoView` (scripts/iso) is the default: `IsoTerrain` draws the splat-shaded ground, ore and
decorations; entity sprites live in one Y-sorted layer (structures sort by their front corner);
`IsoFx` plays effect sheets; a fog polygon with a shader darkens explored/unexplored areas.

The simulation never depends on graphics. `Game` keeps entities as lightweight `Node2D`s holding
logic state. A presentation is attached afterwards:

- **View3D** (default) reads `game.entities` every frame, creates a 3D model per entity
  (`Models.build_unit` / `Models.build_building`) and interpolates position, facing and turret
  rotation. Effects requested by the simulation through `Game.spawn_effect()` are turned into
  `Fx3D` nodes. Projectiles are mirrored from `game.projectiles`. Health bars and selection
  brackets are drawn in screen space on top of the 3D view.
- **View2D** uses the original top-down sprites (`Sprites`) and a `Camera2D`.

Both expose the same API used by `PlayerController`, `Minimap` and `AudioFX`:
`set_focus`, `get_focus`, `mouse_world`, `world_to_screen`, `ground_from_screen`, `pan_screen`,
`scroll`, `zoom_by`, `visible_ground_quad`, `view_radius_px`, `screen_has`, `pick`.

World mapping in 3D: one map cell = one 3D unit; simulation pixel `(x, y)` maps to `(x/32, h, y/32)`.
The camera looks down at 42 degrees with a 45-degree yaw, so the square grid appears as a diamond.

**Adding 3D art for a new unit or building**: add a case to `Models.build_unit()` or
`Models.build_building()` keyed by the `sprite` value in the data file. Name animated parts with
metadata (`turret`, `dish`, `crane`, `glow`, `blink`, `fill`, `legs`) and list chimney points in the
`smoke` metadata; `View3D` animates them automatically. Also add its height to `Models.height_of()`
so clicks on the upper part of the model select it.

## Data files (data/*.json)

All balance numbers live here and can be edited without touching code.

### units.json

```json
"mtank": {
  "name": "Warden Battle Tank", "factions": ["coalition"], "category": "vehicle",
  "role": "Main battle tank.", "cost": 900, "build_time": 11, "hp": 420, "armor": "heavy",
  "speed": 1.9, "move": "track", "sight": 5, "radius": 13, "weapons": ["cannon_90"],
  "prereq": ["factory", "radar"], "sprite": "tank_medium", "turret": true, "turn_rate": 3.2
}
```

- `category`: `infantry` (barracks), `vehicle` (war factory), `aircraft` (airfield) or `naval` (naval yard).
- `speed`: cells per second. `sight`: cells. `radius`: pixels (for collision and range).
- `move`: `foot`, `wheel`, `track`, `naval` (water and bridges) or `air` - matched against terrain costs.
- `armor`: `none`, `light`, `heavy`, `wood`, `concrete`, `aircraft`, `ship`.
- `prereq`: tech tags provided by buildings (see `provides`).
- Optional: `harvester: {capacity, scoop_time, unload_time}`, `deploys_to: "<building>"`.
- Aircraft: `altitude` (world units), `hover` (helicopters hover and turn in place; jets keep
  flying and strafe), `ammo` (shots before returning to an airfield pad to rearm), `rearm_time`.
- Ships: `submarine` (invisible to enemies while submerged unless inside a `detector` radius;
  surfaces briefly after firing), `detector` (sonar radius in cells).
- Engineers: `engineer: true` (right-click captures enemy / fully repairs friendly structures).

### buildings.json

- `footprint`: rows of `x` (solid) and `.` (passable, e.g. the refinery dock).
- `produces`: production categories (`building`, `defense`, `infantry`, `vehicle`).
- `provides`: tech tags unlocked while the building stands.
- `power`: positive produces, negative consumes. `requires_power`: goes offline on low power.
- `storage`, `free_unit`, `dock`, `exit`, `weapons`, `turret` as needed.
- `placement: "water"`: every footprint cell must be water (naval yard).
- `pads`: landing pad positions in cells relative to the footprint (airfield).
- `repair_rate`: fraction of max HP per second restored to units standing on it (repair facility);
  costs 40% of the unit's price for a full repair.

### weapons.json and warheads.json

Weapons define `damage` ([min, max]), `range` (cells), `rof` (seconds between shots),
`warhead`, `projectile` (`bullet`, `shell`, `rocket`, `flame`, `zap`), `speed`, `splash` (cells),
`accuracy`, `targets` (`ground`, `air`, `naval`, `sub`), optional `burst`, `min_range`.
Target classes: aircraft are `air`; ships are `naval` (also hit by `ground` weapons); submerged
submarines are `sub` and can only be hit by weapons that list it (torpedoes, depth charges).
Warheads multiply damage by the target's armor class (`vs`).

### terrain.json

Each terrain has movement `cost` per movement class (0 = impassable), `buildable`,
`blocks_los` and `cover` (infantry damage reduction).

### ai.json

Per-difficulty behaviour (think interval, reaction time, attack thresholds, harvesters,
defenses, scouting, counter-building), the build order (by tech tag), army mixes per faction
and counter-unit lists.

## Adding content

**A new unit**: add an entry to `units.json`. For art, add a model to `tools/art/vehicles.gd` or
`humans.gd`, a sheet in `tools/bake_specs.gd` and a case in `tools/art/catalog.gd`, then bake
(see Art pipeline). It appears in the sidebar automatically for the listed factions.

**A new building**: add to `buildings.json`, a model in `tools/art/buildings2.gd` (dispatched
from `hd_buildings.gd build()`) and an entry in `BUILDINGS` in `bake_specs.gd`.

**A new faction**: add it to `factions.json`, list it in the `factions` arrays of the units and
buildings it may use, and add an `army` entry in `ai.json`.

**A new country** (sub-faction): add it to `data/countries.json` with its `side`, the
`units` it unlocks, its `powers` and a `bonus` table (`armor` / `speed` / `cost` / `build_time`
multipliers per category, e.g. `{"armor": {"vehicle": 0.9}}`). Mark country-only units and
buildings with `"countries": ["<id>"]` next to their `factions`; `Data.allowed()` and
`Game.availability()` filter on both. Support powers live in `Specials.POWERS` (`countries` list).
Draw a flag in `tools/make_flags.py` (output `assets/ui/flags/<id>.png`), an emblem in
`tools/make_insignia.py` (`assets/ui/insignia/<id>.png`; `IsoView._add_emblems` paints it on
vehicles, aircraft, ships and structure pads at runtime) and, for a uniform, a
`CAMO` row in `humans.gd` plus a `COUNTRY_INFANTRY` entry in `bake_specs.gd`: infantry sheets
named `i_<sprite>_<country>` are picked before the side's `i_<sprite>_<faction>` sheet.

Unit mechanics available from data: `regen` (hp/s after 3 s without damage), `stealth`
(`{"radius", "delay"}`: hidden while still and not firing, spotted by enemies within radius),
`walker` (stride frames from vehicle sheet states), weapon `spinup` (`{"max", "gain", "decay"}`),
weapon `infantry_only`.

**A new weapon**: add to `weapons.json` and reference it from a unit or building.

## Maps

Random maps come from `MapGen.generate()` (size, players, seed, resource abundance). Hand-made
maps are JSON files placed in `maps/` and appear in the skirmish map list:

```json
{
  "name": "Twin Fords",
  "rows": ["....ffff....", "..dd==....ww", "..."],
  "legend": {".": "grass", "d": "dirt", "s": "sand", "w": "water", "~": "shore",
             "=": "road", "r": "rock", "#": "cliff", "b": "bridge", "f": "forest"},
  "ore": [{"x": 20, "y": 14, "r": 4, "kind": "ore", "richness": 1.0}],
  "starts": [[8, 8], [56, 56]]
}
```

`MapGen.to_text_dict()` exports any map (including exact `ore_cells`) to this format.

## Performance

- Benchmark: `godot --path . -- --iso --bench=20` stages a 175-unit battle with AI, warms up
  4 s, then prints FPS, worst frame, draw calls and the cost of each simulation stage per tick
  (`Game.profiling` / `Game.profile`).
- Sprite sheets for both factions are preloaded when a match starts (`IsoView._preload_sheets`);
  loading them mid-battle froze the game whenever a new unit type appeared.
- The terrain shader renders into a smaller `SubViewport` (`Config.terrain_scale()`, 50/70/100%
  per quality preset) that is stretched over the screen.
- Fog of war updates incrementally (`Game._vis_lists`, row spans instead of per-cell offsets);
  unit separation runs every second tick; hidden simulation nodes skip transform updates and
  physics interpolation; hover picking is throttled; the minimap is built from byte arrays.
- Textures import with mipmaps (`[importer_defaults]` in project.godot) and 2D uses
  linear-mipmap filtering, since sprites are drawn at 35-60% of their 2x art size.

## Testing

`tests/test_runner.gd` builds headless matches and drives them through the real systems.
Run a single test with the `RTS_TEST` environment variable:

```
RTS_TEST=test_harvest_loop godot --headless --path . res://tests/test_runner.tscn
```

Screenshots for visual checks:

```
godot --path . -- --quickstart --shot=out.png --shot-at=10 --speed=2 "--cheats=reveal_on;money_set_50000"
```
