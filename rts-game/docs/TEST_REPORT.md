# Test Report - Phases 1-3, graphics overhaul, faction specials and countries

Environment: Godot 4.3 stable, Linux, headless run and software-rendered (Mesa llvmpipe)
screenshots. Command: `godot --headless --path . res://tests/test_runner.tscn`

**Result: 41 tests, 409 checks passed, 0 failed.**

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
| test_iso_view | Isometric renderer: pre-rendered sprite sheets for units and structures, hull frame follows facing, screen/world round trip, picking units and tall structures, box selection, sprite explosions, zoom; helicopters drawn at altitude with a ground shadow and rotor, picking flying units, engineer sprites |
| test_coastal_map | Coastal maps put water near every start, keep bases connected by land/bridges; dry maps have no water |
| test_naval | Naval yard refuses land and is built entirely on water; ships launch onto water and stay on it; land units never spawn in the sea |
| test_submarine_detection | Submerged submarines are invisible to enemies and immune to tank fire; destroyer sonar reveals and attacks them |
| test_aircraft | Airfield pad assignment, take-off to altitude, attacking, ammunition use, returning to the pad and rearming; tanks cannot hit flying aircraft |
| test_anti_air | Tanks cannot target aircraft; anti-air vehicles can and shoot a helicopter down |
| test_engineer | Engineer captures an enemy structure (consumed, ownership and power change) and fully repairs a friendly one |
| test_repair_facility | Damaged tank is repaired at the repair facility and repairs cost credits |
| test_view3d_picking | 3D view builds models; screen/world round trip; clicking units and the top of tall structures; box selection; 3D effects; zoom |
| test_map_presets | Every named map generates with its water layout, start positions and connected bases |
| test_paratroopers | US paratroopers need an Airfield, recharge, drop six riflemen near the target |
| test_bomber_strike | Russian bomber strike sends three bombers that damage the target and leave the map |
| test_dig_in | Dug-in riflemen hit harder, take less damage and cannot move until packed up |
| test_jetpack_and_dog | Rocketeers fly over water and are hit by anti-air; attack dogs kill infantry |
| test_charges | Commando C4 destroys structures; demolition charges damage an area |
| test_mines | Minelayer mines stay hidden from enemies and blow up enemy vehicles |
| test_countries | Ten countries with valid sides, unique items and powers; country picks set the side; unique units only for their country; Chinese infantry discount; German vehicle armour; default countries; country saved and loaded |
| test_thai_rangers_stealth | Thai infantry speed bonus; rangers cloak when still, cannot be targeted from range, are spotted up close |
| test_country_powers | UK spy plane reveals the enemy base for 30 s, then the fog returns; Cuban revolution raises five guerrillas |
| test_new_defenses | Each side has at least six defenses; the rocket battery fires a multi-rocket salvo that damages a tank; bunker built with its machine gun |
| test_walls | One wall purchase gives eight sections that can be placed one by one; walls block ground units; a player with only walls left is defeated |
| test_country_units | Tsar tank repairs itself and carries anti-air missiles; Gatling spin-up and reset; sniper rifle hits infantry only |

Manual checks (1920x1080 screenshots, Forward+ renderer on a software Vulkan driver): isometric
battle and base views with painted terrain, ore, decorations, shroud, sprite effects, metallic HUD
and cameo icons; 3D main menu background, 3D base with every structure type, fog of war on 3D terrain, a tank/infantry
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
- All art is generated procedurally (pre-rendered models and painted textures). It follows the
  classic style but is not hand-painted by an artist; tools/ makes it easy to replace or refine.
- Roads are textured gravel without painted lane markings (roads are not straight on generated maps).
- The real-time 3D view still uses its simpler low-poly models. Performance was checked only with a software renderer here; real GPUs are
  much faster.
- In the 3D view the minimap shows the map top-down (not rotated like the camera).
- Windows export has not been built in this environment; export steps are in the README.
