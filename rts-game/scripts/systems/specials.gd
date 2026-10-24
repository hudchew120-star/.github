class_name Specials
extends RefCounted
## Faction special abilities in the spirit of the classic RTS games:
## - Country support powers that recharge for free: US paratroopers, UK spy plane,
##   Russian bomber strike, Cuban revolution.
## - Fly-over aircraft that deliver them (not controllable, drawn by the renderer).
## - Timed bombs planted by the Commando (C4) and the Demolition Trooper.
## - Hidden mines laid by the Dominion Minelayer.

const POWERS := {
	"paradrop": {"name": "Paratroopers", "faction": "coalition", "countries": ["usa"], "prereq": ["airfield"], "cooldown": 180.0,
		"desc": "A transport drops six riflemen anywhere you can see or have explored.", "drop": "e1", "count": 6},
	"spyplane": {"name": "Spy Plane", "faction": "coalition", "countries": ["uk"], "prereq": ["radar"], "cooldown": 120.0,
		"desc": "A reconnaissance jet reveals a wide area for 30 seconds.", "radius": 8, "duration": 30.0},
	"bomber": {"name": "Bomber Strike", "faction": "dominion", "countries": ["russia"], "prereq": ["airfield"], "cooldown": 240.0,
		"desc": "Three bombers carpet-bomb a line through the target.", "planes": 3, "damage": 140.0, "radius": 1.1},
	"lightning": {"name": "Lightning Storm", "faction": "coalition", "prereq": ["superweapon"], "cooldown": 420.0, "superweapon": true,
		"desc": "A thunderstorm gathers over the target and strikes it with lightning for 12 seconds.", "radius": 3.5, "duration": 12.0,
		"bolt_every": 0.35, "bolt_damage": 130.0, "bolt_radius": 0.9, "delay": 3.0},
	"nuke": {"name": "Nuclear Missile", "faction": "dominion", "prereq": ["superweapon"], "cooldown": 480.0, "superweapon": true,
		"desc": "A nuclear missile flattens a large area after a short flight.", "radius": 3.5, "damage": 1100.0, "delay": 4.0},
	"revolution": {"name": "Revolution", "faction": "dominion", "countries": ["cuba"], "prereq": ["barracks"], "cooldown": 200.0,
		"desc": "A band of five guerrillas rises up anywhere you can see or have explored.", "drop": "guer", "count": 5},
}
const PLANE_SPEED := 300.0          # pixels per second (10 cells/s)

var game = null
var powers := {}                    # pid -> {power id -> ready_at sim time, or -1.0 while unavailable}
var flyovers: Array = []            # active delivery planes
var bombs: Array = []               # planted charges
var mines := {}                     # map cell index -> owner pid
var reveals: Array = []             # spy plane vision: {pid, pos, r (cells), until}
var storms: Array = []              # lightning storms: {pid, pos, t (time left, negative while gathering), bolt_t}
var nukes: Array = []               # incoming missiles: {pid, pos, t}

func _init(g) -> void:
	game = g

# ---------------------------------------------------------------- support powers

func powers_for(pid: int) -> Array:
	var out := []
	var p = game.players[pid]
	for id in POWERS:
		# Superweapons belong to the whole side; other powers to one country.
		if POWERS[id].faction == p.faction and (not POWERS[id].has("countries") or POWERS[id].countries.has(p.country)):
			out.append(id)
	return out

## {"available", "ready", "remaining", "progress"} for the sidebar button.
func power_state(pid: int, id: String) -> Dictionary:
	var ready_at: float = float(powers.get(pid, {}).get(id, -1.0))
	if ready_at < 0.0:
		return {"available": false, "ready": false, "remaining": 0.0, "progress": 0.0}
	var cd: float = POWERS[id].cooldown
	var rem := maxf(0.0, ready_at - game.sim_time)
	return {"available": true, "ready": rem <= 0.0, "remaining": rem, "progress": clampf(1.0 - rem / cd, 0.0, 1.0)}

func use_power(pid: int, id: String, target: Vector2) -> String:
	if not POWERS.has(id) or not powers_for(pid).has(id):
		return "Not available to your country."
	var st := power_state(pid, id)
	if not st.available:
		return "Requires: " + ", ".join(POWERS[id].prereq.map(func(t): return Data.def(Data.building_for_tag(game.players[pid].faction, t)).get("name", t)))
	if not st.ready:
		return "Recharging: %d s left." % int(ceil(st.remaining))
	target = Vector2(clampf(target.x, 16.0, game.map.w * MapGrid.T - 16.0), clampf(target.y, 16.0, game.map.h * MapGrid.T - 16.0))
	powers[pid][id] = game.sim_time + float(POWERS[id].cooldown)
	if game.cheats.flag(pid, "instant_build"):
		powers[pid][id] = game.sim_time + 2.0
	var p = game.players[pid]
	var home: Vector2 = MapGrid.cell_center(game.map.starts[pid % game.map.starts.size()])
	var dir: Vector2 = (target - home).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var start: Vector2 = target - dir * (game.map.w * MapGrid.T * 0.75)
	if id == "lightning":
		storms.append({"pid": pid, "pos": target, "t": float(POWERS.lightning.duration) + float(POWERS.lightning.delay), "bolt_t": float(POWERS.lightning.delay)})
		_warn_all(pid, "Lightning Storm", target)
		return ""
	if id == "nuke":
		nukes.append({"pid": pid, "pos": target, "t": float(POWERS.nuke.delay)})
		_warn_all(pid, "Nuclear missile launched", target)
		return ""
	if id == "revolution":
		_raise_guerrillas(pid, target)
		game.notify(pid, "The people rise up!", "unit")
		return ""
	if id == "paradrop":
		flyovers.append({"kind": "transport", "power": id, "pid": pid, "pos": start, "dir": dir, "target": target, "dropped": false, "faction": p.faction})
	elif id == "spyplane":
		flyovers.append({"kind": "spy", "power": id, "pid": pid, "pos": start, "dir": dir, "target": target, "dropped": false, "faction": p.faction})
		game.notify(pid, "Spy Plane on the way.", "unit")
		return ""
	else:
		var side := Vector2(-dir.y, dir.x)
		for i in int(POWERS[id].planes):
			var off: Vector2 = side * (i - 1) * 40.0 - dir * absf(i - 1) * 50.0
			flyovers.append({"kind": "bomber", "power": id, "pid": pid, "pos": start + off, "dir": dir, "target": target + off,
				"dropped": false, "faction": p.faction, "bomb_t": 0.0})
	game.notify(pid, "%s on the way." % POWERS[id].name, "unit")
	for other in game.players:
		if other.id != pid:
			game.notify(other.id, "Warning: enemy aircraft approaching!", "alert")
	return ""

func _tick_powers() -> void:
	for p in game.players:
		if not powers.has(p.id):
			powers[p.id] = {}
		for id in powers_for(p.id):
			var have: bool = p.has_tech(POWERS[id].prereq) or game.cheats.flag(p.id, "no_prereq")
			var cur: float = float(powers[p.id].get(id, -1.0))
			if have and cur < 0.0:
				powers[p.id][id] = game.sim_time + float(POWERS[id].cooldown) * (0.15 if game.cheats.flag(p.id, "instant_build") else 1.0)
			elif not have and cur >= 0.0:
				powers[p.id][id] = -1.0

func _tick_flyovers(dt: float) -> void:
	var w: float = game.map.w * MapGrid.T
	var h: float = game.map.h * MapGrid.T
	for f in flyovers.duplicate():
		f.pos += f.dir * PLANE_SPEED * dt
		var to: Vector2 = f.target - f.pos
		var along: float = to.dot(f.dir)
		if f.kind == "transport" and not f.dropped and along <= 0.0:
			f.dropped = true
			_drop_paratroopers(f)
		elif f.kind == "spy" and not f.dropped and along <= 0.0:
			f.dropped = true
			var pd: Dictionary = POWERS[f.power]
			reveals.append({"pid": f.pid, "pos": f.target, "r": int(pd.radius), "until": game.sim_time + float(pd.duration)})
			game.update_fog()
		elif f.kind == "bomber" and absf(along) < MapGrid.T * 3.0:
			f.bomb_t -= dt
			if f.bomb_t <= 0.0:
				f.bomb_t = 0.14
				_bomb_at(f.pos + Vector2(randf_range(-8, 8), randf_range(-8, 8)), f.pid)
			f.dropped = true
		var margin := MapGrid.T * 24.0
		if f.dropped and along < -MapGrid.T * 4.0 and (f.pos.x < -margin or f.pos.y < -margin or f.pos.x > w + margin or f.pos.y > h + margin or along < -w):
			flyovers.erase(f)

func _drop_paratroopers(f: Dictionary) -> void:
	var def: Dictionary = POWERS[f.power]
	var c: Vector2i = MapGrid.to_cell(f.target)
	var placed := 0
	for k in 40:
		if placed >= int(def.count):
			break
		var cc: Vector2i = game.map.nearest_passable(c + Vector2i(k % 4 - 1, (k / 4) % 4 - 1), "foot", 6)
		if cc.x < 0:
			continue
		var u = game.spawn_unit(f.pid, def.drop, MapGrid.cell_center(cc) + Vector2(randf_range(-8, 8), randf_range(-8, 8)))
		if u == null:
			break
		u.para_t = 2.2 + placed * 0.15
		u.altitude_now = 1.6
		placed += 1
	game.play_sound("unit_ready", f.target)

func _warn_all(pid: int, what: String, target: Vector2) -> void:
	game.notify(pid, "%s on its way." % what, "unit")
	for other in game.players:
		if other.id != pid:
			game.notify(other.id, "Warning: %s detected!" % what.to_lower(), "alert")
	game.play_sound("alert", target)

## Lightning storm: after the clouds gather, bolts strike random points in the radius.
func _tick_storms(dt: float) -> void:
	var d: Dictionary = POWERS.lightning
	for st in storms.duplicate():
		st.t -= dt
		st.bolt_t -= dt
		if st.t <= 0.0:
			storms.erase(st)
			continue
		if st.bolt_t <= 0.0:
			st.bolt_t = float(d.bolt_every) * randf_range(0.6, 1.4)
			var r: float = float(d.radius) * MapGrid.T * sqrt(randf())
			var p: Vector2 = st.pos + Vector2.RIGHT.rotated(randf() * TAU) * r
			game.spawn_effect("zap", p, {"to": p, "h": 7.0, "th": 0.0, "bolt": true})
			game.spawn_effect("explosion", p)
			game.spawn_effect("spark", p)
			game.play_sound("zap", p)
			_area_damage(p, float(d.bolt_radius) * MapGrid.T, float(d.bolt_damage), st.pid, true)

func _tick_nukes(dt: float) -> void:
	var d: Dictionary = POWERS.nuke
	for nk in nukes.duplicate():
		nk.t -= dt
		if nk.t > 0.0:
			continue
		nukes.erase(nk)
		var p: Vector2 = nk.pos
		game.spawn_effect("explosion_big", p)
		for i in 10:
			var q: Vector2 = p + Vector2.RIGHT.rotated(i * TAU / 10.0) * MapGrid.T * randf_range(0.8, 2.6)
			game.spawn_effect("explosion_big" if i % 2 == 0 else "explosion", q)
			game.spawn_effect("fire", q)
		game.spawn_effect("crater", p, {"r": 46.0})
		game.play_sound("explode_big", p)
		_area_damage(p, float(d.radius) * MapGrid.T, float(d.damage), nk.pid, false)

## Damage with linear falloff to everything hostile on the ground (and low flyers for lightning).
func _area_damage(p: Vector2, r: float, dmg: float, pid: int, hit_air: bool) -> void:
	for e in game.entities_near(p, r + 48.0):
		if e.dead or not game.are_enemies(pid, e.pid):
			continue
		if e.is_unit() and e.is_air_unit and e.altitude_now > 0.3 and not hit_air:
			continue
		var dd: float = e.edge_distance(p)
		if dd <= r:
			e.take_damage(dmg * (1.0 - 0.6 * dd / r), null)

## Cuban Revolution: guerrillas spring up around the target point.
func _raise_guerrillas(pid: int, target: Vector2) -> void:
	var def: Dictionary = POWERS.revolution
	var c: Vector2i = MapGrid.to_cell(target)
	var placed := 0
	for k in 40:
		if placed >= int(def.count):
			break
		var cc: Vector2i = game.map.nearest_passable(c + Vector2i(k % 3 - 1, (k / 3) % 3 - 1), "foot", 6)
		if cc.x < 0:
			continue
		var p := MapGrid.cell_center(cc) + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		var u = game.spawn_unit(pid, def.drop, p)
		if u == null:
			break
		game.spawn_effect("smoke", p)
		placed += 1
	game.play_sound("unit_ready", target)

## Spy plane vision sources for a player: [[cell, radius], ...].
func reveal_sources(pid: int) -> Array:
	var out := []
	for r in reveals:
		if int(r.pid) == pid:
			out.append([MapGrid.to_cell(r.pos), int(r.r)])
	return out

func _bomb_at(p: Vector2, pid: int) -> void:
	var def: Dictionary = POWERS.bomber
	game.spawn_effect("explosion", p)
	game.spawn_effect("crater", p, {"r": 10.0})
	game.play_sound("explode", p)
	var r: float = float(def.radius) * MapGrid.T
	var shooter = null
	for e in game.entities_near(p, r + 24.0):
		if e.dead or e.pid == pid or not game.are_enemies(pid, e.pid):
			continue
		if e.is_unit() and e.is_air_unit and e.altitude_now > 0.3:
			continue
		var d: float = e.edge_distance(p)
		if d <= r:
			e.take_damage(float(def.damage) * (1.0 - 0.5 * d / r), shooter)

# ---------------------------------------------------------------- bombs (C4 and demolition charges)

func plant_bomb(planter, target) -> void:
	var pl: Dictionary = planter.def.get("planter", {})
	bombs.append({"target": target.uid, "pos": target.pos, "t": float(pl.get("delay", 5.0)), "max_t": float(pl.get("delay", 5.0)),
		"damage": float(pl.get("damage", 500.0)), "splash": float(pl.get("splash", 1.0)), "c4": bool(pl.get("c4", false)),
		"pid": planter.pid, "planter": planter.uid})
	game.notify(planter.pid, "Charge planted.", "info")
	game.play_sound("click", target.pos)

func _tick_bombs(dt: float) -> void:
	for b in bombs.duplicate():
		var t = game.entities.get(int(b.target))
		if t != null and not t.dead:
			b.pos = t.pos if t.is_unit() else t.rect_px().get_center()
		b.t -= dt
		if b.t > 0.0:
			continue
		bombs.erase(b)
		var shooter = game.entities.get(int(b.planter))
		if b.c4:
			if t != null and not t.dead:
				game.spawn_effect("explosion_big", b.pos)
				t.take_damage(t.hp + 1.0, shooter)
			continue
		game.spawn_effect("explosion_big", b.pos)
		game.spawn_effect("crater", b.pos, {"r": 16.0})
		game.play_sound("explode_big", b.pos)
		var r: float = float(b.splash) * MapGrid.T
		for e in game.entities_near(b.pos, r + 32.0):
			if e.dead:
				continue
			if e.is_unit() and e.is_air_unit and e.altitude_now > 0.3:
				continue
			var d: float = e.edge_distance(b.pos)
			if e == t or d <= r:
				var k: float = 1.0 if e == t else (1.0 - 0.6 * d / r)
				e.take_damage(float(b.damage) * k, shooter)

func bombs_on(e) -> Array:
	return bombs.filter(func(b): return int(b.target) == e.uid)

# ---------------------------------------------------------------- mines

func lay_mine(u) -> bool:
	if u.mines_left <= 0:
		game.notify(u.pid, "Out of mines. New ones are being made.", "warn")
		return false
	var c: Vector2i = u.cell()
	var i: int = game.map.idx(c)
	if mines.has(i):
		return false
	mines[i] = u.pid
	u.mines_left -= 1
	game.play_sound("click", u.pos)
	return true

func _tick_mines() -> void:
	if mines.is_empty():
		return
	for u in game.units:
		if u.dead or u.is_air_unit or u.para_t > 0.0:
			continue
		var i: int = game.map.idx(u.cell())
		if not mines.has(i):
			continue
		var owner: int = int(mines[i])
		if not game.are_enemies(owner, u.pid):
			continue
		mines.erase(i)
		var p: Vector2 = MapGrid.cell_center(u.cell())
		game.spawn_effect("explosion", p)
		game.spawn_effect("crater", p, {"r": 12.0})
		game.play_sound("explode", p)
		var dmg := 380.0
		var r := 0.9 * MapGrid.T
		for e in game.entities_near(p, r + 16.0):
			if not e.dead and e.is_unit() and not e.is_air_unit and e.edge_distance(p) <= r:
				e.take_damage(dmg, null)

## Mines visible to a viewer: their own (and allies'); enemy mines stay hidden.
func visible_mines(viewer: int) -> Array:
	var out := []
	for i in mines:
		if not game.are_enemies(int(mines[i]), viewer):
			out.append(Vector2i(int(i) % game.map.w, int(i) / game.map.w))
	return out

# ---------------------------------------------------------------- loop and saves

func tick(dt: float) -> void:
	if game.tick_count % 15 == 0:
		_tick_powers()
	_tick_flyovers(dt)
	_tick_bombs(dt)
	if not storms.is_empty():
		_tick_storms(dt)
	if not nukes.is_empty():
		_tick_nukes(dt)
	if not reveals.is_empty() and game.tick_count % 15 == 0:
		reveals = reveals.filter(func(r): return game.sim_time < float(r.until))
	if game.tick_count % 3 == 0:
		_tick_mines()

func to_dict() -> Dictionary:
	var fl := []
	for f in flyovers:
		var d: Dictionary = f.duplicate()
		d.pos = [f.pos.x, f.pos.y]
		d.dir = [f.dir.x, f.dir.y]
		d.target = [f.target.x, f.target.y]
		fl.append(d)
	var bm := []
	for b in bombs:
		var d: Dictionary = b.duplicate()
		d.pos = [b.pos.x, b.pos.y]
		bm.append(d)
	var pw := {}
	for pid in powers:
		pw[str(pid)] = powers[pid].duplicate()
	var mn := {}
	for i in mines:
		mn[str(i)] = mines[i]
	var rv := []
	for r in reveals:
		rv.append({"pid": r.pid, "pos": [r.pos.x, r.pos.y], "r": r.r, "until": r.until})
	var sw := []
	for st in storms:
		sw.append({"pid": st.pid, "pos": [st.pos.x, st.pos.y], "t": st.t, "bolt_t": st.bolt_t})
	var nk := []
	for n in nukes:
		nk.append({"pid": n.pid, "pos": [n.pos.x, n.pos.y], "t": n.t})
	return {"powers": pw, "flyovers": fl, "bombs": bm, "mines": mn, "reveals": rv, "storms": sw, "nukes": nk}

func from_dict(d: Dictionary) -> void:
	powers = {}
	for k in d.get("powers", {}):
		powers[int(k)] = {}
		for id in d.powers[k]:
			powers[int(k)][id] = float(d.powers[k][id])
	flyovers = []
	for f in d.get("flyovers", []):
		var x: Dictionary = f.duplicate()
		x.pos = Vector2(f.pos[0], f.pos[1])
		x.dir = Vector2(f.dir[0], f.dir[1])
		x.target = Vector2(f.target[0], f.target[1])
		flyovers.append(x)
	bombs = []
	for b in d.get("bombs", []):
		var x: Dictionary = b.duplicate()
		x.pos = Vector2(b.pos[0], b.pos[1])
		bombs.append(x)
	mines = {}
	for k in d.get("mines", {}):
		mines[int(k)] = int(d.mines[k])
	storms = []
	for st in d.get("storms", []):
		storms.append({"pid": int(st.pid), "pos": Vector2(st.pos[0], st.pos[1]), "t": float(st.t), "bolt_t": float(st.bolt_t)})
	nukes = []
	for n in d.get("nukes", []):
		nukes.append({"pid": int(n.pid), "pos": Vector2(n.pos[0], n.pos[1]), "t": float(n.t)})
	reveals = []
	for r in d.get("reveals", []):
		reveals.append({"pid": int(r.pid), "pos": Vector2(r.pos[0], r.pos[1]), "r": int(r.r), "until": float(r.until)})
