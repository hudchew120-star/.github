class_name AIController
extends RefCounted
## Computer opponent. Uses exactly the same production, placement and command
## functions as the human player; difficulty changes decision speed and quality.

var game = null
var player = null
var cfg: Dictionary = {}
var think_t: float = 2.0
var attack_wave: int = 0
var threshold: int = 8
var next_attack_time: float = 300.0
var attack_group: Array = []        # unit uids currently attacking
var gathering: bool = false
var gather_started: float = 0.0
var scouted: bool = false
var scout_uid: int = 0
var threat_pos := Vector2.INF
var threat_time: float = -100.0
var respond_at: float = -1.0
var seen_armor := {"none": 0, "light": 0, "heavy": 0}
var seen_air: int = 0                # times enemy aircraft hurt us: drives AA production
var water_spot := Vector2i(-2, -2)   # cached naval yard site check (-2 = unknown, -1 = none)
var navy_group: Array = []
var next_navy_attack: float = 420.0

func _init(g, p) -> void:
	game = g
	player = p
	cfg = Data.ai.get("difficulty", {}).get(p.difficulty, Data.ai.difficulty.normal)
	threshold = int(cfg.attack_threshold)
	next_attack_time = float(cfg.first_attack)
	think_t = 1.0 + randf()

func tick(dt: float) -> void:
	think_t -= dt
	if think_t > 0.0:
		return
	think_t = float(cfg.think_interval) * randf_range(0.8, 1.2)
	_think()

func _my_units() -> Array:
	return game.units.filter(func(u): return u.pid == player.id and not u.dead)

func _my_buildings() -> Array:
	return game.buildings.filter(func(b): return b.pid == player.id and not b.dead)

func _base_center() -> Vector2i:
	for b in _my_buildings():
		if b.type == "fact":
			return b.cell0 + Vector2i(1, 1)
	var bs := _my_buildings()
	if bs.size() > 0:
		return bs[0].cell0
	return game.map.starts[player.id % game.map.starts.size()]

func _enemy_start() -> Vector2i:
	var e: int = game.first_enemy_of(player.id)
	if e < 0:
		return game.map.starts[0]
	return game.map.starts[e % game.map.starts.size()]

func _think() -> void:
	_deploy_mcv()
	_manage_construction()
	_manage_production()
	_manage_harvesters()
	_manage_army()
	_manage_navy()
	_manage_air()
	_manage_specials()
	if cfg.repair:
		_manage_repairs()

# ---------------------------------------------------------------- base building

func _deploy_mcv() -> void:
	if player.has_tech(["construction"]):
		return
	for u in _my_units():
		if not u.def.has("deploys_to"):
			continue
		if u.moving:
			return
		if u.cmd_deploy():
			return
		var c: Vector2i = game._find_build_spot(player.id, "fact", u.cell(), 8)
		if c.x >= 0:
			u.cmd_move(MapGrid.cell_center(c + Vector2i(1, 1)))
		return

func _count_tag(tag: String, include_queued: bool = true) -> int:
	var n := 0
	for b in _my_buildings():
		if b.def.get("provides", []).has(tag):
			n += 1
		if include_queued:
			for cat in b.queues:
				for it in b.queues[cat]:
					if Data.def(it.type).get("provides", []).has(tag):
						n += 1
	return n

func _next_build_tag() -> String:
	var order: Array = Data.ai.build_order
	var seen := {}
	for tag in order:
		seen[tag] = int(seen.get(tag, 0)) + 1
		if tag == "defense":
			continue
		if tag == "refinery" and int(seen[tag]) > int(cfg.max_refineries):
			continue
		if tag == "airfield" and not cfg.get("air", false):
			continue
		if tag == "naval_yard" and not _has_water_site():
			continue
		if _count_tag(tag) < int(seen[tag]):
			return tag
	return ""

func _manage_construction() -> void:
	var cy = game.producer_for(player.id, "building")
	if cy == null:
		return
	# Place anything that is ready.
	for cat in ["building", "defense"]:
		var it = cy.ready_item(cat)
		if it != null:
			var spot := _find_spot(it.type)
			if spot.x >= 0:
				game.place_structure(player.id, cat, spot)
			else:
				cy.cancel_item(cat, 0)
	var q: Array = cy.queues.get("building", [])
	if q.is_empty():
		var t := ""
		if game.power_enabled(player.id) and player.power_total() - player.power_use < 30 and player.has_tech(["construction"]):
			t = "apwr" if game.availability(player.id, "apwr") == "" and player.credits() > 1500 else "powr"
		else:
			var tag := _next_build_tag()
			if tag != "":
				t = Data.building_for_tag(player.faction, tag)
		if t != "" and game.availability(player.id, t) == "" and player.credits() >= int(Data.def(t).cost) * 0.25:
			game.queue_item(player.id, t)
	var dq: Array = cy.queues.get("defense", [])
	if dq.is_empty() and int(cfg.defenses) > 0 and _count_tag("defense") < int(cfg.defenses) and _count_tag("factory", false) > 0 and (_count_tag("refinery", false) >= mini(2, int(cfg.max_refineries)) or threat_time > 0.0):
		if cfg.parallel or q.is_empty():
			var options := Data.types_in_category("defense", player.faction).filter(func(t): return game.availability(player.id, t) == "")
			var aa := options.filter(func(t): return _hits_air(Data.def(t)))
			if seen_air >= 2 and aa.size() > 0 and _count_aa_defenses() < 2 + seen_air / 6:
				options = aa
			elif aa.size() < options.size():
				options = options.filter(func(t): return not aa.has(t))
			if options.size() > 0 and player.credits() > 800:
				game.queue_item(player.id, options[randi() % options.size()])
	# Extra anti-air defenses once enemy aircraft have shown up (beyond the normal defense cap).
	if dq.is_empty() and seen_air >= 4 and _count_aa_defenses() < mini(1 + seen_air / 4, 4) and player.credits() > 1000:
		for t in Data.types_in_category("defense", player.faction):
			if _hits_air(Data.def(t)) and game.availability(player.id, t) == "":
				game.queue_item(player.id, t)
				break

## Searches for a placement near the base, leaving a one-cell gap between structures.
func _find_spot(t: String) -> Vector2i:
	var origin := _base_center()
	var d := Data.def(t)
	if d.get("provides", []).has("refinery"):
		var ore := _nearest_ore(origin, 14)
		if ore.x >= 0:
			origin = Vector2i((origin + ore) / 2)
	elif d.get("category", "") == "defense":
		var dir := Vector2(_enemy_start() - origin).normalized()
		origin += Vector2i((dir * randf_range(4.0, 7.0)).round()) + Vector2i(randi_range(-3, 3), randi_range(-3, 3))
	if d.get("placement", "") == "water":
		var ws := _water_site(t)
		return ws
	var size: Vector2i = d.size
	for r in range(0, 16):
		var cands := []
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue
				cands.append(origin + Vector2i(dx, dy))
		cands.shuffle()
		for c in cands:
			if game.can_place(player.id, t, c) != "":
				continue
			if _has_gap(c, size):
				return c
	return Vector2i(-1, -1)

## Nearest valid naval yard site to the base, or (-1,-1).
func _water_site(t: String) -> Vector2i:
	var origin := _base_center()
	for r in range(2, 22):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue
				var c := origin + Vector2i(dx, dy)
				if game.map.in_bounds(c) and game.can_place(player.id, t, c) == "":
					return c
	return Vector2i(-1, -1)

func _has_water_site() -> bool:
	var t := Data.building_for_tag(player.faction, "naval_yard")
	if t == "":
		return false
	if _count_tag("naval_yard") > 0:
		return true
	# Re-check now and then: the build radius grows as the base expands.
	if water_spot.x == -2 or (water_spot.x == -1 and randf() < 0.05):
		water_spot = _water_site(t) if player.has_tech(["construction"]) else Vector2i(-1, -1)
		if water_spot.x < 0 and _has_any_water_near():
			water_spot = Vector2i(-1, -1)
	return water_spot.x >= 0

func _has_any_water_near() -> bool:
	var o := _base_center()
	for dy in range(-14, 15, 2):
		for dx in range(-14, 15, 2):
			var c := o + Vector2i(dx, dy)
			if game.map.in_bounds(c) and game.map.terrain_id(c) == "water":
				return true
	return false

func _hits_air(d: Dictionary) -> bool:
	for wid in d.get("weapons", []):
		if Data.weapon(wid).get("targets", ["ground"]).has("air"):
			return true
	return false

func _count_aa_defenses() -> int:
	var n := 0
	for b in _my_buildings():
		if b.def.get("category", "") == "defense" and _hits_air(b.def):
			n += 1
	return n

func _has_gap(c: Vector2i, size: Vector2i) -> bool:
	for y in range(-1, size.y + 1):
		for x in range(-1, size.x + 1):
			if x >= 0 and y >= 0 and x < size.x and y < size.y:
				continue
			var cc := c + Vector2i(x, y)
			if game.map.in_bounds(cc) and game.map.occupied[game.map.idx(cc)] != 0:
				return false
	return true

func _nearest_ore(origin: Vector2i, max_r: int) -> Vector2i:
	for r in range(0, max_r + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue
				var c := origin + Vector2i(dx, dy)
				if game.map.in_bounds(c) and game.map.ore[game.map.idx(c)] > 0:
					return c
	return Vector2i(-1, -1)

# ---------------------------------------------------------------- production

func _harvester_count() -> int:
	var n := 0
	for u in _my_units():
		if u.is_harvester:
			n += 1
	for b in _my_buildings():
		for it in b.queues.get("vehicle", []):
			if it.type == "harv":
				n += 1
	return n

func _pick_unit(cat: String) -> String:
	var weights: Dictionary = Data.ai.army.get(player.faction, {})
	var options := []
	var total := 0.0
	for t in weights:
		if Data.def(t).get("category", "") != cat or game.availability(player.id, t) != "":
			continue
		var wgt := float(weights[t])
		if seen_air > 0 and _hits_air(Data.def(t)) and Data.def(t).get("category", "") != "aircraft":
			wgt *= 1.0 + minf(float(seen_air) * 0.5, 6.0)
		if cfg.counter:
			var tot := float(seen_armor.none + seen_armor.light + seen_armor.heavy)
			if tot > 4:
				for armor in seen_armor:
					if Data.ai.counters.get(armor, []).has(t):
						wgt *= 1.0 + 2.0 * float(seen_armor[armor]) / tot
		options.append([t, wgt])
		total += wgt
	if options.is_empty():
		return ""
	var r := randf() * total
	for o in options:
		r -= o[1]
		if r <= 0.0:
			return o[0]
	return options[-1][0]

func _manage_production() -> void:
	var refineries := _count_tag("refinery", false)
	var fac = game.producer_for(player.id, "vehicle")
	var bar = game.producer_for(player.id, "infantry")
	if fac != null and _harvester_count() < refineries * int(cfg.harvesters_per_refinery) and game.availability(player.id, "harv") == "":
		if fac.queue_count("vehicle") == 0:
			game.queue_item(player.id, "harv")
		return
	var lanes_busy := 0
	var reserve := 300 if player.difficulty == "hard" else 600
	if bar != null:
		if bar.queue_count("infantry") < (2 if cfg.parallel else 1):
			var t := _pick_unit("infantry")
			if t != "" and player.credits() > int(Data.def(t).cost) + reserve * 0.5:
				game.queue_item(player.id, t)
		lanes_busy += bar.queue_count("infantry")
	if fac != null and (cfg.parallel or lanes_busy == 0):
		if fac.queue_count("vehicle") < (2 if cfg.parallel else 1):
			var t := _pick_unit("vehicle")
			if t != "" and player.credits() > int(Data.def(t).cost) + reserve:
				game.queue_item(player.id, t)
	var air = game.producer_for(player.id, "aircraft")
	if air != null and cfg.get("air", false) and air.queue_count("aircraft") == 0:
		# One aircraft per landing pad.
		var pads := 0
		for b in _my_buildings():
			if b.completed and b.produces("aircraft"):
				pads += maxi(b.def.get("pads", []).size(), 1)
		var flyers := _my_units().filter(func(u): return u.is_air_unit and not u.def.get("jetpack", false)).size()
		if flyers < pads:
			var t := _pick_unit("aircraft")
			if t != "" and player.credits() > int(Data.def(t).cost) + reserve * 1.5:
				game.queue_item(player.id, t)
	var yard = game.producer_for(player.id, "naval")
	if yard != null and yard.queue_count("naval") == 0:
		var ships := _my_units().filter(func(u): return u.is_naval).size()
		if ships < 10:
			var t := _pick_unit("naval")
			if t != "" and player.credits() > int(Data.def(t).cost) + reserve * 1.5:
				game.queue_item(player.id, t)

func _manage_harvesters() -> void:
	for u in _my_units():
		if u.is_harvester and u.order != "harvest":
			u.cmd_harvest()

func _manage_repairs() -> void:
	if player.credits() < 800:
		return
	for b in _my_buildings():
		if b.completed and b.hp_ratio() < 0.6:
			b.repairing = true

# ---------------------------------------------------------------- army

func _combat_units() -> Array:
	return _my_units().filter(func(u): return u.can_attack() and not u.is_harvester and not u.is_naval and (not u.is_air_unit or u.def.get("jetpack", false)))

func on_unit_built(u) -> void:
	if (u.is_air_unit and not u.def.get("jetpack", false)) or u.is_naval:
		return
	if u.can_attack():
		var rp := _rally_point()
		u.cmd_attack_move(rp + Vector2(randf_range(-40, 40), randf_range(-40, 40)))

func _rally_point() -> Vector2:
	var base := MapGrid.cell_center(_base_center())
	var dir := (MapGrid.cell_center(_enemy_start()) - base).normalized()
	return base + dir * MapGrid.T * 7.0

func on_damaged(e, attacker) -> void:
	if attacker == null or not is_instance_valid(attacker):
		return
	if attacker.is_unit() and attacker.is_air_unit:
		seen_air += 1
	elif attacker.is_unit():
		var a: String = attacker.armor
		if seen_armor.has(a):
			seen_armor[a] += 1
	var base := MapGrid.cell_center(_base_center())
	var important: bool = e.is_building() or e.pos.distance_to(base) < MapGrid.T * 16 or (e.is_unit() and e.is_harvester)
	if important:
		threat_pos = attacker.pos
		if game.sim_time - threat_time > 8.0:
			respond_at = game.sim_time + float(cfg.reaction)
		threat_time = game.sim_time

func _known_target() -> Vector2:
	# Prefer enemy structures we have actually seen; otherwise the enemy start position.
	var best = null
	var best_d := INF
	var base := MapGrid.cell_center(_base_center())
	for b in game.buildings:
		if b.dead or not game.are_enemies(player.id, b.pid):
			continue
		var c: Vector2i = b.cell0
		if player.vis.size() > 0 and player.vis[game.map.idx(c)] == 0 and not cfg.counter:
			continue
		var d: float = b.pos.distance_to(base)
		if d < best_d:
			best_d = d
			best = b
	if best != null:
		return best.pos
	return MapGrid.cell_center(_enemy_start())

func _manage_army() -> void:
	attack_group = attack_group.filter(func(uid): return game.entities.has(uid))
	var army := _combat_units()
	_dig_in_defenders(army)
	army = army.filter(func(u): return not u.deployed)
	var idle := army.filter(func(u): return not attack_group.has(u.uid) and u.uid != scout_uid)
	# Defend the base.
	if threat_pos != Vector2.INF and game.sim_time - threat_time < 12.0 and game.sim_time >= respond_at:
		var defenders := idle
		if game.sim_time - threat_time < 3.0 and idle.size() < 3:
			defenders = army
		for u in defenders:
			if u.order != "attack" and u.order != "attack_move" or u.pos.distance_to(threat_pos) > MapGrid.T * 12:
				u.cmd_attack_move(threat_pos)
		return
	# Scouting.
	if cfg.scout and not scouted and game.sim_time > 70.0 and idle.size() > 0:
		var s = idle[0]
		for u in idle:
			if u.speed_px > s.speed_px:
				s = u
		scout_uid = s.uid
		s.cmd_attack_move(MapGrid.cell_center(_enemy_start()))
		scouted = true
	# Attack waves.
	if gathering:
		var rp := _rally_point()
		var members := attack_group.map(func(uid): return game.entities.get(uid)).filter(func(u): return u != null)
		var near := members.filter(func(u): return u.pos.distance_to(rp) < MapGrid.T * 7).size()
		if near >= members.size() * 0.7 or game.sim_time - gather_started > 35.0:
			gathering = false
			var tgt := _known_target()
			game.command_group(members, "attack_move", tgt)
		return
	if game.sim_time >= next_attack_time and idle.size() >= threshold:
		attack_wave += 1
		threshold += int(cfg.wave_growth)
		next_attack_time = game.sim_time + randf_range(80.0, 140.0) * (1.4 if player.difficulty == "easy" else 1.0)
		for u in idle:
			attack_group.append(u.uid)
		if cfg.group_up:
			gathering = true
			gather_started = game.sim_time
			game.command_group(idle, "attack_move", _rally_point())
		else:
			game.command_group(idle, "attack_move", _known_target())
		return
	# Keep attackers moving once they finish their current objective.
	var tgt := _known_target()
	for uid in attack_group:
		var u = game.entities.get(uid)
		if u != null and (u.order == "guard" or u.order == "idle") and u.target == null:
			u.cmd_attack_move(tgt + Vector2(randf_range(-48, 48), randf_range(-48, 48)))

## Coalition AI keeps a few riflemen dug in behind sandbags between its base and the enemy.
func _dig_in_defenders(army: Array) -> void:
	var dug := army.filter(func(u): return u.deployed).size()
	if dug >= 4:
		return
	var rp := _rally_point()
	for u in army:
		if dug >= 4:
			break
		if u.deployed or not u.can_dig_in() or attack_group.has(u.uid) or u.uid == scout_uid:
			continue
		if (u.order == "guard" or u.order == "idle") and not u.moving and u.pos.distance_to(rp) < MapGrid.T * 6.0:
			u.cmd_deploy()
			dug += 1

# ---------------------------------------------------------------- navy and air force

func _nearest_water(origin: Vector2i, max_r: int) -> Vector2i:
	for r in range(0, max_r + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue
				var c := origin + Vector2i(dx, dy)
				if game.map.in_bounds(c) and game.map.passable(c, "naval"):
					return c
	return Vector2i(-1, -1)

func _manage_navy() -> void:
	navy_group = navy_group.filter(func(uid): return game.entities.has(uid))
	var ships := _my_units().filter(func(u): return u.is_naval and u.can_attack())
	if ships.is_empty():
		return
	# Defend: ships near the base hunt anything hurting it from the water.
	if threat_pos != Vector2.INF and game.sim_time - threat_time < 10.0:
		var tc := _nearest_water(MapGrid.to_cell(threat_pos), 6)
		if tc.x >= 0:
			for u in ships:
				if not navy_group.has(u.uid) and u.order != "attack":
					u.cmd_attack_move(MapGrid.cell_center(tc))
	var idle := ships.filter(func(u): return not navy_group.has(u.uid))
	if game.sim_time >= next_navy_attack and idle.size() >= 4:
		next_navy_attack = game.sim_time + randf_range(90.0, 150.0)
		var goal := _naval_target()
		if goal != Vector2.INF:
			for u in idle:
				navy_group.append(u.uid)
			game.command_group(idle, "attack_move", goal)
	for uid in navy_group:
		var u = game.entities.get(uid)
		if u != null and (u.order == "guard" or u.order == "idle") and u.target == null:
			var g := _naval_target()
			if g != Vector2.INF:
				u.cmd_attack_move(g + Vector2(randf_range(-40, 40), randf_range(-40, 40)))

## Enemy naval yard if known, otherwise the water closest to the enemy base.
func _naval_target() -> Vector2:
	for b in game.buildings:
		if not b.dead and game.are_enemies(player.id, b.pid) and b.produces("naval"):
			if cfg.counter or player.vis.size() == 0 or player.vis[game.map.idx(b.cell0)] != 0:
				var c := _nearest_water(b.cell0, 5)
				if c.x >= 0:
					return MapGrid.cell_center(c)
	var c := _nearest_water(_enemy_start(), 18)
	return MapGrid.cell_center(c) if c.x >= 0 else Vector2.INF

func _manage_air() -> void:
	if not cfg.get("air", false):
		return
	var flyers := _my_units().filter(func(u): return u.is_air_unit and u.can_attack() and not u.def.get("jetpack", false))
	var ready := flyers.filter(func(u): return (u.order == "guard" or u.order == "idle") and (u.max_ammo < 0 or u.ammo == u.max_ammo))
	# Defend the base against attackers first.
	if threat_pos != Vector2.INF and game.sim_time - threat_time < 6.0 and ready.size() > 0:
		game.command_group(ready, "attack_move", threat_pos)
		return
	# Strike in pairs or more once the land army has started attacking.
	if ready.size() >= 2 and attack_wave > 0:
		game.command_group(ready, "attack_move", _known_target())

# ---------------------------------------------------------------- special abilities

func _manage_specials() -> void:
	var sp = game.specials
	for id in sp.powers_for(player.id):
		if sp.power_state(player.id, id).ready and game.sim_time > float(cfg.first_attack) * 0.6:
			var t := _power_target(id)
			if t != Vector2.INF:
				sp.use_power(player.id, id, t)
	# Commandos and demolition troopers go after nearby enemy structures (and units for charges).
	for u in _my_units():
		if not u.def.has("planter") or u.plant_cd > 0.0 or u.order == "plant":
			continue
		if u.order != "guard" and u.order != "idle" and not (u.order == "attack_move" and u.target == null):
			continue
		var best = null
		var best_d := MapGrid.T * 22.0
		for e in game.entities_near(u.pos, best_d):
			if e.dead or not game.are_enemies(player.id, e.pid):
				continue
			if u.def.planter.get("buildings_only", false) and not e.is_building():
				continue
			if e.is_unit() and e.is_air_unit:
				continue
			var d: float = e.edge_distance(u.pos) - (60.0 if e.is_building() else 0.0)
			if d < best_d:
				best_d = d
				best = e
		if best != null:
			u.cmd_plant(best)

## Paratroopers land next to an enemy refinery or power plant; bombers hit the densest cluster of structures.
func _power_target(id: String) -> Vector2:
	var enemy_b: Array = game.buildings.filter(func(b): return not b.dead and game.are_enemies(player.id, b.pid) and (cfg.counter or player.vis.size() == 0 or player.vis[game.map.idx(b.cell0)] != 0))
	if enemy_b.is_empty():
		return Vector2.INF
	if id == "paradrop":
		for b in enemy_b:
			var prov: Array = b.def.get("provides", [])
			if prov.has("refinery") or prov.has("power"):
				return b.pos + Vector2(randf_range(-64, 64), randf_range(64, 110))
		return enemy_b[0].pos + Vector2(0, 96)
	var best = enemy_b[0]
	var best_n := -1
	for b in enemy_b:
		var n := 0
		for o in enemy_b:
			if o.pos.distance_to(b.pos) < MapGrid.T * 4.0:
				n += 1
		if n > best_n:
			best_n = n
			best = b
	return best.pos

func to_dict() -> Dictionary:
	return {"wave": attack_wave, "threshold": threshold, "next_attack": next_attack_time, "group": attack_group.duplicate(),
		"gathering": gathering, "scouted": scouted, "scout": scout_uid, "seen_armor": seen_armor.duplicate(),
		"seen_air": seen_air, "navy": navy_group.duplicate(), "next_navy": next_navy_attack}

func from_dict(d: Dictionary) -> void:
	attack_wave = int(d.get("wave", 0))
	threshold = int(d.get("threshold", threshold))
	next_attack_time = float(d.get("next_attack", next_attack_time))
	attack_group = d.get("group", []).map(func(x): return int(x))
	gathering = bool(d.get("gathering", false))
	scouted = bool(d.get("scouted", false))
	scout_uid = int(d.get("scout", 0))
	seen_air = int(d.get("seen_air", 0))
	navy_group = d.get("navy", []).map(func(x): return int(x))
	next_navy_attack = float(d.get("next_navy", next_navy_attack))
	for k in d.get("seen_armor", {}):
		seen_armor[k] = int(d.seen_armor[k])
