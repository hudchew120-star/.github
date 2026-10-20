extends Node
## Automated gameplay tests. Run headless:
##   godot --headless --path . res://tests/test_runner.tscn
## Exit code 0 = all passed.

var passed = 0
var failed = 0
var results: Array = []

func _ready() -> void:
	await get_tree().process_frame
	var tests = [
		"test_starting_credits", "test_deploy_and_build", "test_placement_rules", "test_prerequisites",
		"test_cancel_refund", "test_power", "test_harvest_loop", "test_unit_movement", "test_combat",
		"test_splash_and_armor", "test_production_queue", "test_cheats_money", "test_cheats_instant",
		"test_cheat_spawn_and_destroy", "test_large_values", "test_save_load", "test_fog", "test_ai_match",
		"test_victory", "test_view3d_picking",
	]
	var only = OS.get_environment("RTS_TEST")
	for t in tests:
		if only != "" and t != only:
			continue
		var before = failed
		var t0 = Time.get_ticks_msec()
		await call(t)
		var ok = failed == before
		results.append("%s %s (%d ms)" % ["PASS" if ok else "FAIL", t, Time.get_ticks_msec() - t0])
		print(results[-1])
	print("\n==== %d checks passed, %d failed ====" % [passed, failed])
	var f = FileAccess.open("user://test_report.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(results) + "\n%d checks passed, %d failed\n" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

func check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("   FAILED: " + what)

func make_game(extra: Dictionary = {}) -> Game:
	var s = {"map_size": "small", "seed": 7, "ai_count": 1, "start_credits": 10000, "start_units": "mcv", "cheats_allowed": true}
	s.merge(extra, true)
	var g = Game.new()
	add_child(g)
	g.setup(s, true)
	g.cheats.set_flag("ai_disabled", not extra.get("ai", false))
	return g

func run(g: Game, seconds: float) -> void:
	var n = int(seconds * 30.0)
	for i in n:
		g.step()
		if g.over:
			break

func free_game(g: Game) -> void:
	g.queue_free()
	await get_tree().process_frame

func human_mcv(g: Game) -> Unit:
	for u in g.units:
		if u.pid == 0 and u.type == "mcv":
			return u
	return null

func deploy(g: Game) -> Building:
	var m = human_mcv(g)
	check(m != null, "human starts with an MCV")
	check(m.cmd_deploy(), "MCV deploys at start position")
	run(g, 2.0)
	for b in g.buildings:
		if b.pid == 0 and b.type == "fact":
			return b
	return null

func build_now(g: Game, t: String) -> Building:
	# Builds through the real queue + placement path (with instant cheats on).
	var err = g.queue_item(0, t)
	check(err == "", "queue %s: %s" % [t, err])
	run(g, 0.2)
	var cat: String = Data.def(t).category
	var cy = g.producer_for(0, cat)
	var spot: Vector2i = AIController.new(g, g.players[0])._find_spot(t)
	check(spot.x >= 0, "found a spot for " + t)
	var r = g.place_structure(0, cat, spot)
	check(r == "", "place %s: %s" % [t, r])
	run(g, 2.0)
	for b in g.buildings:
		if b.pid == 0 and b.type == t and b.cell0 == spot:
			return b
	return null

# ---------------------------------------------------------------- tests

func test_starting_credits() -> void:
	var g = make_game({"start_credits": 7500})
	check(g.players[0].credits() == 7500, "starting credits 7500")
	check(g.players.size() == 2, "two players")
	check(human_mcv(g) != null, "MCV spawned")
	await free_game(g)

func test_deploy_and_build() -> void:
	var g = make_game()
	var cy = deploy(g)
	check(cy != null and cy.completed, "construction yard completed")
	check(g.players[0].has_tech(["construction"]), "construction tech provided")
	var c0 = g.players[0].credits()
	check(g.queue_item(0, "powr") == "", "queue power plant")
	run(g, 3.0)
	var c1 = g.players[0].credits()
	check(c1 < c0 and c1 > c0 - 300, "cost deducted progressively (%d -> %d)" % [c0, c1])
	run(g, 6.0)
	check(cy.ready_item("building") != null, "power plant ready after build time")
	check(g.players[0].credits() == c0 - 300, "full cost 300 deducted")
	var spot: Vector2i = AIController.new(g, g.players[0])._find_spot("powr")
	check(g.place_structure(0, "building", spot) == "", "place power plant")
	run(g, 2.0)
	check(g.players[0].power_prod == 100, "power plant produces 100")
	await free_game(g)

func test_placement_rules() -> void:
	var g = make_game()
	var cy = deploy(g)
	check(g.can_place(0, "powr", cy.cell0) != "", "cannot overlap construction yard")
	check(g.can_place(0, "powr", Vector2i(-1, 0)) != "", "cannot place outside the map")
	var far = Vector2i(g.map.w - 3, 2) if cy.cell0.x < g.map.w / 2 else Vector2i(2, g.map.h - 3)
	var r = g.can_place(0, "powr", far)
	check(r != "", "cannot place far from base (%s)" % r)
	var water = Vector2i(-1, -1)
	for y in g.map.h:
		for x in g.map.w:
			if g.map.terrain_id(Vector2i(x, y)) == "water":
				water = Vector2i(x, y)
	if water.x >= 0:
		check(g.can_place(0, "silo", water, true) != "", "cannot build on water")
	await free_game(g)

func test_prerequisites() -> void:
	var g = make_game()
	deploy(g)
	check(g.availability(0, "weap") != "", "war factory locked without refinery")
	check(g.availability(0, "e1") != "", "infantry locked without barracks")
	g.cheats.set_flag("no_prereq", true)
	check(g.availability(0, "weap") == "", "no_prereq cheat unlocks war factory")
	await free_game(g)

func test_cancel_refund() -> void:
	var g = make_game()
	var cy = deploy(g)
	var c0 = g.players[0].credits()
	check(g.queue_item(0, "powr") == "", "queue power plant")
	run(g, 3.0)
	var spent = c0 - g.players[0].credits()
	check(spent > 0, "power plant partially paid (%d)" % spent)
	cy.cancel_item("building", 0)
	check(g.players[0].credits() == c0, "full refund on cancel (default policy)")
	g.settings.refund_ratio = 0.5
	g.queue_item(0, "powr")
	run(g, 3.0)
	var spent2 = c0 - g.players[0].credits()
	cy.cancel_item("building", 0)
	check(g.players[0].credits() == c0 - spent2 + int(round(spent2 * 0.5)), "50% refund policy")
	await free_game(g)

func test_power() -> void:
	var g = make_game()
	deploy(g)
	g.cheats.set_flag("instant_build", true)
	g.cheats.set_flag("instant_deploy", true)
	var pp = build_now(g, "powr")
	build_now(g, "proc")
	build_now(g, "tent")
	g.cheats.set_flag("no_prereq", true)
	build_now(g, "dome")
	var p = g.players[0]
	check(p.power_use == 90, "power consumption 90 (%d)" % p.power_use)
	check(not p.low_power(), "enough power")
	pp.take_damage(9999, null)
	run(g, 0.5)
	check(p.power_prod == 0 and p.low_power(), "destroyed plant -> low power")
	g.settings.power_enabled = false
	check(not p.low_power(), "power constraints can be disabled")
	await free_game(g)

func test_harvest_loop() -> void:
	var g = make_game()
	deploy(g)
	g.cheats.set_flag("instant_build", true)
	g.cheats.set_flag("instant_deploy", true)
	build_now(g, "powr")
	var ref = build_now(g, "proc")
	check(ref != null, "refinery built")
	var harvs = g.units.filter(func(u): return u.pid == 0 and u.is_harvester)
	check(harvs.size() == 1, "refinery came with a free collector")
	var ore0 = g.map.total_ore()
	var p = g.players[0]
	var stored0: int = p.stored_resources()
	run(g, 90.0)
	check(p.stats.harvested > 0, "collector delivered ore (%d)" % p.stats.harvested)
	check(p.stored_resources() > stored0, "stored resources increased")
	check(g.map.total_ore() < ore0, "ore field depleted")
	await free_game(g)

func test_unit_movement() -> void:
	var g = make_game()
	var m = human_mcv(g)
	var u = g.spawn_unit(0, "ltank", m.pos + Vector2(64, 0))
	var dest = g.map.nearest_passable(m.cell() + Vector2i(12, 10), "track", 10)
	u.cmd_move(MapGrid.cell_center(dest))
	run(g, 25.0)
	check(u.cell().distance_to(dest) <= 1.5, "tank reached destination (%s vs %s)" % [u.cell(), dest])
	check(g.map.terrain_passable(u.cell(), "track"), "tank stands on passable terrain")
	await free_game(g)

func test_combat() -> void:
	var g = make_game()
	var m = human_mcv(g)
	var p = m.pos + Vector2(0, 96)
	var a = g.spawn_unit(0, "mtank", p)
	var b = g.spawn_unit(1, "e1", p + Vector2(96, 0))
	run(g, 15.0)
	check(b.dead, "tank killed enemy rifleman automatically")
	check(not a.dead, "tank survived")
	var c = g.spawn_unit(1, "htank", p + Vector2(110, 0))
	a.cmd_attack(c)
	run(g, 40.0)
	check(a.dead or c.dead, "tank duel resolved")
	await free_game(g)

func test_splash_and_armor() -> void:
	var rifle = Data.weapon("rifle")
	var ap = Data.weapon("cannon_90")
	check(Data.warhead_mult(rifle.warhead, "heavy") < Data.warhead_mult(rifle.warhead, "none"), "small arms weak vs heavy armor")
	check(Data.warhead_mult(ap.warhead, "heavy") > Data.warhead_mult(ap.warhead, "none"), "AP strong vs heavy armor")
	var g = make_game()
	var m = human_mcv(g)
	var p = m.pos + Vector2(0, 128)
	var victims = []
	for i in 3:
		victims.append(g.spawn_unit(1, "e1", p + Vector2(i * 6, 0)))
	var flame = Data.weapon("flamer")
	var shooter = g.spawn_unit(0, "e1", p - Vector2(60, 0))
	g.unit_hash.rebuild(g.units)
	Combat.detonate(g, p + Vector2(6, 0), flame, shooter, victims[1])
	var hurt = 0
	for v in victims:
		if v.hp < v.max_hp:
			hurt += 1
	check(hurt == 3, "splash damage hit all three infantry (%d)" % hurt)
	await free_game(g)

func test_production_queue() -> void:
	var g = make_game()
	deploy(g)
	g.cheats.set_flag("instant_build", true)
	g.cheats.set_flag("instant_deploy", true)
	build_now(g, "powr")
	var bar = build_now(g, "tent")
	g.cheats.set_flag("instant_build", false)
	var n0 = g.units.filter(func(u): return u.pid == 0 and u.type == "e1").size()
	for i in 3:
		check(g.queue_item(0, "e1") == "", "queue rifleman %d" % i)
	g.queue_item(0, "e3")
	check(bar.queue_count("infantry") == 4, "4 items queued")
	bar.move_item("infantry", 3, -3)
	check(bar.queues.infantry[0].type == "e3", "reorder moved Lancer to the front")
	bar.rally = bar.pos + Vector2(0, 160)
	run(g, 25.0)
	var n1 = g.units.filter(func(u): return u.pid == 0 and u.type == "e1").size()
	check(n1 - n0 == 3, "three riflemen produced (%d)" % (n1 - n0))
	check(g.units.filter(func(u): return u.pid == 0 and u.type == "e3").size() == 1, "lancer produced")
	for i in 6:
		g.queue_item(0, "e1")
	check(bar.queue_count("infantry") == 5, "queue limited to 5")
	await free_game(g)

func test_cheats_money() -> void:
	var g = make_game()
	var r = g.cheats.execute("money set 1000000")
	check(r.ok and g.players[0].credits() == 1000000, "money set 1000000")
	g.cheats.execute("money add 500000")
	check(g.players[0].credits() == 1500000, "money add")
	g.cheats.execute("money subtract 10000")
	check(g.players[0].credits() == 1490000, "money subtract")
	g.cheats.execute("resources set ore 50000")
	check(g.players[0].resources.ore == 50000, "resources set ore")
	g.cheats.execute("resources set all 999999")
	check(g.players[0].resources.gems == 999999, "resources set all")
	r = g.cheats.execute("money set banana")
	check(not r.ok, "invalid amount rejected with message")
	r = g.cheats.execute("power set 999999")
	check(r.ok and g.players[0].power_total() == 999999, "power set")
	g.cheats.execute("storage unlimited on")
	check(g.players[0].unlimited_storage(), "storage unlimited on")
	r = g.cheats.execute("remove enemies")
	check(not r.ok, "destructive command asks for confirmation")
	var cy = deploy(g)
	g.cheats.execute("money set 1000000")
	check(g.queue_item(0, "powr") == "", "spend cheat money")
	run(g, 8.0)
	check(g.players[0].credits() == 1000000 - 300, "cheat credits are real spendable credits")
	await free_game(g)

func test_cheats_instant() -> void:
	var g = make_game()
	var cy = deploy(g)
	g.cheats.execute("build instant on")
	g.queue_item(0, "powr")
	g.step()
	g.step()
	check(cy.ready_item("building") != null, "instant build completes immediately")
	g.cheats.execute("build free on")
	var c = g.players[0].credits()
	cy.cancel_item("building", 0)
	g.queue_item(0, "proc")
	run(g, 0.2)
	check(g.players[0].credits() >= c, "free building costs nothing")
	g.cheats.set_flag("enabled", true)
	g.cheats.enabled = false
	check(not g.cheats.flag(0, "instant_build"), "cheats inactive when disabled")
	var r = g.cheats.execute("money set 5")
	check(not r.ok, "console refuses when cheats are disabled")
	await free_game(g)

func test_cheat_spawn_and_destroy() -> void:
	var g = make_game()
	var m = human_mcv(g)
	g.cursor_cell = m.cell() + Vector2i(3, 3)
	var n0 = g.units.size()
	var r = g.cheats.execute("spawn mtank 5")
	check(r.ok and g.units.size() == n0 + 5, "spawned 5 tanks: " + r.msg)
	r = g.cheats.execute("spawn htank 2 enemy at %d %d" % [m.cell().x + 6, m.cell().y + 6])
	check(r.ok, "spawn enemy tanks: " + r.msg)
	r = g.cheats.execute("spawn proc")
	check(r.ok, "spawn structure: " + r.msg)
	r = g.cheats.execute("spawn e1 300")
	check(r.ok and g.units.size() <= g.max_units(), "large spawn is capped safely")
	var t = g.units.filter(func(u): return u.type == "mtank")[0]
	g.selection = [t]
	g.cheats.execute("invulnerable on")
	t.take_damage(10000, null)
	check(not t.dead, "invulnerable unit survives")
	g.cheats.execute("health set 50")
	check(int(t.hp) == 50, "health set 50")
	g.cheats.execute("health full")
	check(t.hp == t.max_hp, "health full")
	g.cheats.execute("destroy selected confirm")
	check(t.dead, "destroy selected")
	r = g.cheats.execute("remove enemies confirm")
	check(r.ok and g.units.filter(func(u): return u.pid == 1 and not u.dead).size() == 0, "remove enemies")
	run(g, 1.0)
	check(g.units.size() > 0, "spawned units keep simulating normally")
	await free_game(g)

func test_large_values() -> void:
	var g = make_game()
	g.cheats.execute("money set 99999999999999999999")
	var c = g.players[0].credits()
	check(c == Player.MAX_VALUE and c > 0, "huge value clamps to max without overflow (%d)" % c)
	g.cheats.execute("money add 999999999999")
	check(g.players[0].credits() == Player.MAX_VALUE, "adding past max stays at max")
	g.cheats.execute("resources add all 999999999999")
	check(g.players[0].credits() > 0 and g.players[0].credits() <= Player.MAX_VALUE, "credits stay valid with huge resources")
	await free_game(g)

func test_save_load() -> void:
	var g = make_game()
	var cy = deploy(g)
	g.cheats.set_flag("instant_build", true)
	g.cheats.set_flag("instant_deploy", true)
	build_now(g, "powr")
	build_now(g, "proc")
	g.cheats.set_flag("instant_build", false)
	g.queue_item(0, "tent")
	run(g, 3.0)
	var t = g.spawn_unit(0, "ltank", cy.pos + Vector2(0, 140))
	t.hp = 123
	run(g, 1.0)
	var save = g.to_save()
	var text = JSON.stringify(save)
	var g2 = Game.new()
	add_child(g2)
	g2.load_save(JSON.parse_string(text), true)
	check(g2.players[0].credits() == g.players[0].credits(), "credits preserved")
	check(g2.units.size() == g.units.size(), "unit count preserved")
	check(g2.buildings.size() == g.buildings.size(), "building count preserved")
	var t2 = g2.entities.get(t.uid)
	check(t2 != null and t2.pos.distance_to(t.pos) < 0.01 and absf(t2.hp - 123) < 0.01, "unit position and health preserved")
	var cy2 = g2.entities.get(cy.uid)
	check(cy2 != null and cy2.queues.building.size() == 1 and absf(cy2.queues.building[0].progress - cy.queues.building[0].progress) < 0.0001, "production progress preserved")
	check(g2.cheats.flags.instant_deploy == true, "cheat settings preserved")
	check(g2.map.total_ore() == g.map.total_ore(), "ore preserved")
	run(g2, 5.0)
	check(not g2.over, "loaded game keeps running")
	await free_game(g)
	await free_game(g2)

func test_fog() -> void:
	var g = make_game()
	var p = g.players[0]
	var m = human_mcv(g)
	check(p.vis[g.map.idx(m.cell())] == 2, "own position visible")
	var enemy_start: Vector2i = g.map.starts[1]
	check(p.vis[g.map.idx(enemy_start)] == 0, "enemy base unexplored")
	var e = g.units.filter(func(u): return u.pid == 1)[0]
	check(not e.visible, "enemy hidden in fog")
	g.cheats.execute("reveal on")
	check(e.visible, "reveal cheat shows enemy")
	await free_game(g)

func test_ai_match() -> void:
	# Two AIs (human slot driven by an AI controller) play for 9 minutes.
	seed(20261020)
	var g = make_game({"ai": true, "difficulty": "hard", "map_size": "small", "seed": 3})
	g.cheats.enabled = false
	var bot = AIController.new(g, g.players[0])
	g.players[0].difficulty = "hard"
	bot.cfg = Data.ai.difficulty.hard
	var max_army = [0, 0]
	var attacked = false
	for i in int(540 * 30):
		g.step()
		if i % 15 == 0:
			bot.tick(0.5)
		if i % 300 == 0:
			for pid in 2:
				var n = g.units.filter(func(u): return u.pid == pid and u.can_attack()).size()
				max_army[pid] = maxi(max_army[pid], n)
		if not attacked and i % 30 == 0:
			for b in g.buildings:
				if b.hp < b.max_hp and b.last_attacker_uid != 0:
					attacked = true
					break
		if g.over:
			break
	for pid in 2:
		var p = g.players[pid]
		var bs = g.buildings.filter(func(b): return b.pid == pid).size()
		print("   AI%d: buildings %d, harvested %d, max army %d, killed %d, lost %d, credits %d" % [pid, bs, p.stats.harvested, max_army[pid], p.stats.units_killed, p.stats.units_lost, p.credits()])
		check(p.stats.harvested > 0 or p.defeated, "AI %d gathered resources" % pid)
		check(max_army[pid] >= 4 or p.defeated, "AI %d produced an army" % pid)
	var total_kills: int = g.players[0].stats.units_killed + g.players[1].stats.units_killed
	check(total_kills > 0, "AIs fought each other (%d kills)" % total_kills)
	check(attacked or g.over, "an AI attacked the other's base (structures damaged)")
	await free_game(g)

func test_victory() -> void:
	var g = make_game()
	var r = g.cheats.execute("remove enemies confirm")
	run(g, 2.0)
	check(g.over and g.won, "victory when all enemies are destroyed")
	var g2 = make_game()
	g2.cheats.execute("remove friendly confirm")
	run(g2, 2.0)
	check(g2.over and not g2.won, "defeat when all own forces are gone")
	await free_game(g)
	await free_game(g2)

func test_view3d_picking() -> void:
	# Builds the real 3D presentation (dummy renderer when headless) and checks the
	# screen <-> world mapping, picking of units and structures, and box selection.
	var g = Game.new()
	add_child(g)
	g.setup({"map_size": "small", "seed": 7, "ai_count": 1, "start_units": "base", "use_3d": true, "cheats_allowed": true}, false)
	var v = View3D.new()
	add_child(v)
	v.setup(g)
	var pc = PlayerController.new()
	g.add_child(pc)
	pc.setup(g, v)
	var cy = null
	for b in g.buildings:
		if b.pid == 0 and b.type == "fact":
			cy = b
	check(cy != null, "starting construction yard exists")
	v.set_focus(cy.pos)
	var p: Vector2 = cy.pos + Vector2(40, 30)
	var back: Vector2 = v.ground_from_screen(v.world_to_screen(p))
	check(back.distance_to(p) < 1.0, "screen/world round trip (%s vs %s)" % [back, p])
	var u = g.spawn_unit(0, "mtank", cy.pos + Vector2(0, 150))
	g.unit_hash.rebuild(g.units)
	var picked = v.pick(v.world_to_screen(u.pos, 0.2))
	check(picked == u, "clicking a unit on screen picks it")
	picked = v.pick(v.world_to_screen(cy.rect_px().get_center(), 1.0))
	check(picked == cy, "clicking the upper part of a tall structure picks it")
	var s0: Vector2 = v.world_to_screen(u.pos) - Vector2(30, 30)
	pc._box_select(s0, s0 + Vector2(60, 60), false)
	check(pc.selection.has(u), "box selection in 3D selects the tank")
	await get_tree().process_frame
	check(v.visuals.has(u.uid) and v.visuals.has(cy.uid), "3D models created for entities")
	g.spawn_effect("explosion", u.pos)
	check(v.fx_root.get_child_count() > 0, "3D explosion effect spawned")
	v.zoom_by(1.5, Vector2(800, 400))
	check(absf(v.zoom - 1.5) < 0.01, "zoom works")
	v.queue_free()
	await free_game(g)
