# Test Report - Phases 1-2 and 3D graphics

Environment: Godot 4.3 stable, Linux, headless run and software-rendered (Mesa llvmpipe)
screenshots. Command: `godot --headless --path . res://tests/test_runner.tscn`

**Result: 20 tests, 153 checks passed, 0 failed.**

| Test | What it verifies |
| --- | --- |
| test_starting_credits | Starting credits, players and construction vehicle are created |
| test_deploy_and_build | MCV deploys; cost is deducted progressively; full cost charged; placed plant produces power |
| test_placement_rules | Overlap, off-map, far-from-base and water placements are rejected |
| test_prerequisites | Tech requirements enforced; "no prerequisites" cheat unlocks them |
| test_cancel_refund | Full refund by default; 50% refund policy works |
| test_power | Power use is summed; destroying a plant causes low power; power can be disabled |
| test_harvest_loop | Refinery gives a free collector; ore is mined, delivered and the field depletes |
| test_unit_movement | A tank pathfinds to a distant cell and stays on passable terrain |
| test_combat | Units auto-acquire and kill targets; tank duels resolve |
| test_splash_and_armor | Warhead/armor multipliers; splash damage hits groups |
| test_production_queue | Queueing, reordering, rally points, parallel spawn, queue limit of 5 |
| test_cheats_money | money set/add/subtract, resources, power, storage; invalid input rejected; destructive confirmation; cheat money is spendable |
| test_cheats_instant | Instant and free construction; cheats inactive when disabled |
| test_cheat_spawn_and_destroy | Spawning units/enemies/structures; large spawns capped; invulnerability; health set/full; destroy; remove enemies |
| test_large_values | Huge numbers clamp at the maximum without overflow |
| test_save_load | Credits, units, positions, health, buildings, production progress, cheat flags and ore survive a JSON round trip; loaded game keeps running |
| test_fog | Unexplored/visible states; enemies hidden; reveal cheat |
| test_ai_match | Two Hard AIs play 9 minutes (fixed random seed): both build bases, harvest, build armies, fight and damage each other's structures |
| test_victory | Victory when enemies are eliminated; defeat when your forces are gone |
| test_view3d_picking | 3D view builds models; screen/world round trip; clicking units and the top of tall structures; box selection; 3D effects; zoom |

Manual checks (1920x1080 screenshots, Forward+ renderer on a software Vulkan driver): 3D main
menu background, 3D base with every structure type, fog of war on 3D terrain, a tank/infantry
battle with explosions, water and shore foam, ore fields, the classic 2D mode, the HUD and the
developer tools panel.

Everything runs offline; no network code exists in the project.

## Known limitations (planned for later phases)

- Aircraft and naval units/structures are not implemented yet (phase 3).
- Engineers, service depot, anti-air and some advanced units/defenses are not in yet (phase 3).
- Missions, mission scripting and the in-game map editor are not implemented (phase 4).
  The skirmish map format and JSON loading already work.
- Terrain line-of-sight blocking (`blocks_los`) is defined in data but not yet applied to vision.
- Formation movement is basic (spread slots around the target); no rigid formations yet.
- 3D models are assembled in code from simple shapes, so they are clean and stylised rather
  than hand-painted. Performance was checked only with a software renderer here; real GPUs are
  much faster.
- In the 3D view the minimap shows the map top-down (not rotated like the camera).
- Windows export has not been built in this environment; export steps are in the README.
