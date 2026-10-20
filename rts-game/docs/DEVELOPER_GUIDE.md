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

- `category`: `infantry` (built at barracks) or `vehicle` (war factory).
- `speed`: cells per second. `sight`: cells. `radius`: pixels (for collision and range).
- `move`: `foot`, `wheel`, `track` (and `naval` later) - matched against terrain costs.
- `armor`: `none`, `light`, `heavy`, `wood`, `concrete`, `aircraft`, `ship`.
- `prereq`: tech tags provided by buildings (see `provides`).
- Optional: `harvester: {capacity, scoop_time, unload_time}`, `deploys_to: "<building>"`.

### buildings.json

- `footprint`: rows of `x` (solid) and `.` (passable, e.g. the refinery dock).
- `produces`: production categories (`building`, `defense`, `infantry`, `vehicle`).
- `provides`: tech tags unlocked while the building stands.
- `power`: positive produces, negative consumes. `requires_power`: goes offline on low power.
- `storage`, `free_unit`, `dock`, `exit`, `weapons`, `turret` as needed.

### weapons.json and warheads.json

Weapons define `damage` ([min, max]), `range` (cells), `rof` (seconds between shots),
`warhead`, `projectile` (`bullet`, `shell`, `rocket`, `flame`, `zap`), `speed`, `splash` (cells),
`accuracy`, `targets` (`ground`, `air`), optional `burst`, `min_range`.
Warheads multiply damage by the target's armor class (`vs`).

### terrain.json

Each terrain has movement `cost` per movement class (0 = impassable), `buildable`,
`blocks_los` and `cover` (infantry damage reduction).

### ai.json

Per-difficulty behaviour (think interval, reaction time, attack thresholds, harvesters,
defenses, scouting, counter-building), the build order (by tech tag), army mixes per faction
and counter-unit lists.

## Adding content

**A new unit**: add an entry to `units.json`. If it needs new art, add a case to
`Sprites.draw_unit()`. It appears in the sidebar automatically for the listed factions.

**A new building**: add to `buildings.json` and a case in `Sprites.draw_building()`.

**A new faction**: add it to `factions.json`, list it in the `factions` arrays of the units and
buildings it may use, and add an `army` entry in `ai.json`.

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
