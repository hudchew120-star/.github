class_name Specials
extends RefCounted
## Faction special abilities in the spirit of the classic RTS games:
## - Support powers that recharge for free: Coalition paratroopers, Dominion bomber strike.
## - Fly-over aircraft that deliver them (not controllable, drawn by the renderer).
## - Timed bombs planted by the Commando (C4) and the Demolition Trooper.
## - Hidden mines laid by the Dominion Minelayer.

const POWERS := {
	"paradrop": {"name": "Paratroopers", "faction": "coalition", "prereq": ["airfield"], "cooldown": 180.0,
		"desc": "A transport drops six riflemen anywhere you can see or have explored.", "drop": "e1", "count": 6},
	"bomber": {"name": "Bomber Strike", "faction": "dominion", "prereq": ["airfield"], "cooldown": 240.0,
		"desc": "Three bombers carpet-bomb a line through the target.", "planes": 3, "damage": 140.0, "radius": 1.1},
}
const PLANE_SPEED := 300.0          # pixels per second (10 cells/s)

var game = null
var powers := {}                    # pid -> {power id -> ready_at sim time, or -1.0 while unavailable}
var flyovers: Array = []            # active delivery planes
var bombs: Array = []               # planted charges
var mines := {}                     # map cell index -> owner pid

func _init(g) -> void:
	game = g

# ---------------------------------------------------------------- support powers

func powers_for(pid: int) -> Array:
	var out := []
	var f: String = game.players[pid].faction
	for id in POWERS:
		if POWERS[id].faction == f:
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
		return "Not available to your faction."
	var st := power_state(pid, id)
	if not st.available:
		return "Requires an Airfield."
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
	if id == "paradrop":
		flyovers.append({"kind": "transport", "power": id, "pid": pid, "pos": start, "dir": dir, "target": target, "dropped": false, "faction": p.faction})
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
	return {"powers": pw, "flyovers": fl, "bombs": bm, "mines": mn}

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
