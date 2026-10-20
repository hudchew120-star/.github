class_name Building
extends Entity
## Structure: footprint occupancy, construction, per-category production queues,
## rally points, repair/sell, power effects and defensive weapons.

const MAKE_TIME := 1.6           # seconds for the "rise from the ground" deploy animation
const DEFAULT_QUEUE_LIMIT := 5

var cell0 := Vector2i.ZERO        # top-left footprint cell
var size := Vector2i.ONE
var completed: bool = false
var make_progress: float = 0.0
var queues := {}                  # category -> Array of {type, progress, paid, state}
var rally := Vector2.INF
var repairing: bool = false
var anim: float = 0.0
var turret_facing: float = PI * 0.5
var weapons: Array = []
var target = null
var scan_t: float = 0.0
var dock_busy_uid: int = 0
var unload_anim: float = 0.0
var charge: float = 0.0
var smoke_t: float = 0.0

func _ready() -> void:
	z_index = 1

func is_building() -> bool:
	return true

func setup_building(c: Vector2i, instant: bool) -> void:
	cell0 = c
	size = def.get("size", Vector2i.ONE)
	pos = Vector2(c.x + size.x * 0.5, c.y + size.y * 0.5) * MapGrid.T
	radius = maxf(size.x, size.y) * MapGrid.T * 0.5
	position = Vector2(c) * MapGrid.T
	for cat in def.get("produces", []):
		queues[cat] = []
	for wid in def.get("weapons", []):
		var wd := Data.weapon(wid)
		if not wd.is_empty():
			weapons.append({"id": wid, "def": wd, "cd": 0.0})
	if instant:
		make_progress = 1.0
		completed = true

func footprint_cells() -> Array:
	var out := []
	var fp: Array = def.get("footprint", ["x"])
	for y in fp.size():
		var row := String(fp[y])
		for x in row.length():
			if row[x] == "x":
				out.append(cell0 + Vector2i(x, y))
	return out

func all_cells() -> Array:
	var out := []
	for y in size.y:
		for x in size.x:
			out.append(cell0 + Vector2i(x, y))
	return out

func dock_cell() -> Vector2i:
	var d: Array = def.get("dock", [0, size.y])
	return cell0 + Vector2i(int(d[0]), int(d[1]))

func exit_cell() -> Vector2i:
	var e: Array = def.get("exit", [size.x / 2, size.y])
	return cell0 + Vector2i(int(e[0]), int(e[1]))

func rect_px() -> Rect2:
	return Rect2(Vector2(cell0) * MapGrid.T, Vector2(size) * MapGrid.T)

func edge_distance(p: Vector2) -> float:
	var r := rect_px()
	var cx := clampf(p.x, r.position.x, r.end.x)
	var cy := clampf(p.y, r.position.y, r.end.y)
	return p.distance_to(Vector2(cx, cy))

func hp_ratio_power() -> float:
	# Damaged power plants produce less electricity.
	return clampf(0.25 + 0.75 * hp_ratio(), 0.25, 1.0) if hp_ratio() < 1.0 else 1.0

func requires_power() -> bool:
	return bool(def.get("requires_power", false))

func powered() -> bool:
	return not requires_power() or not player().low_power()

func operational() -> bool:
	return completed and not dead

func produces(cat: String) -> bool:
	return queues.has(cat)

# ---------------------------------------------------------------- production queues

func queue_limit() -> int:
	return 999 if game.cheats.flag(pid, "unlimited_queue") else DEFAULT_QUEUE_LIMIT

func queue_count(cat: String) -> int:
	return queues.get(cat, []).size()

func enqueue(cat: String, t: String) -> String:
	if not queues.has(cat):
		return "This building cannot produce that."
	if queues[cat].size() >= queue_limit():
		return "Queue is full."
	queues[cat].append({"type": t, "progress": 0.0, "paid": 0, "state": "queued"})
	return ""

func cancel_item(cat: String, index: int) -> void:
	var q: Array = queues.get(cat, [])
	if index < 0 or index >= q.size():
		return
	var it: Dictionary = q[index]
	var refund := int(round(int(it.paid) * float(game.settings.get("refund_ratio", 1.0))))
	if refund > 0:
		player().add_cash(refund)
	q.remove_at(index)

func move_item(cat: String, index: int, delta: int) -> void:
	var q: Array = queues.get(cat, [])
	var ni := index + delta
	if index < 0 or index >= q.size() or ni < 0 or ni >= q.size():
		return
	var it = q[index]
	q.remove_at(index)
	q.insert(ni, it)

func ready_item(cat: String):
	var q: Array = queues.get(cat, [])
	if q.size() > 0 and q[0].state == "ready":
		return q[0]
	return null

func _production_speed(cat: String) -> float:
	var p = player()
	var spd := 1.0
	if game.power_enabled(pid):
		var ratio: float = p.power_ratio()
		if ratio < 1.0:
			spd *= maxf(0.25, ratio)
	# Several facilities of the same kind speed production up (classic behaviour).
	var tag := "construction" if cat == "building" or cat == "defense" else ("barracks" if cat == "infantry" else "factory")
	var n := int(p.tech.get(tag, 1))
	spd *= 1.0 + 0.25 * float(maxi(n - 1, 0))
	return spd * float(game.settings.get("build_speed", 1.0))

func _process_queue(cat: String, dt: float) -> void:
	var q: Array = queues[cat]
	if q.is_empty():
		return
	var it: Dictionary = q[0]
	if it.state == "ready":
		return
	var d := Data.def(it.type)
	var is_struct := cat == "building" or cat == "defense"
	var cost := 0 if game.cheats.flag(pid, "free_build" if is_struct else "free_units") else int(d.get("cost", 0))
	var instant: bool = game.cheats.flag(pid, "instant_build" if is_struct else "instant_units")
	var new_prog: float = 1.0
	if not instant:
		var t := maxf(0.1, float(d.get("build_time", 5)))
		new_prog = minf(1.0, float(it.progress) + dt / t * _production_speed(cat))
	var target_paid := int(round(cost * new_prog)) if cost > 0 else int(it.paid)
	var delta := target_paid - int(it.paid)
	if delta > 0:
		if not player().spend(delta, "build" if is_struct else "units"):
			it.state = "hold"
			return
		it.paid = target_paid
	it.state = "building"
	it.progress = new_prog
	if new_prog >= 1.0:
		if is_struct:
			it.state = "ready"
			game.notify(pid, "%s ready to place." % d.get("name", it.type), "build")
		else:
			if game.spawn_from_factory(self, it.type):
				q.remove_at(0)
			else:
				it.state = "ready"   # exit blocked, retry next tick

# ---------------------------------------------------------------- simulation

func tick(dt: float) -> void:
	anim += dt
	if hit_flash > 0.0:
		hit_flash -= dt
	if unload_anim > 0.0:
		unload_anim -= dt
	if not completed:
		var spd := 999.0 if game.cheats.flag(pid, "instant_deploy") else 1.0
		make_progress = minf(1.0, make_progress + dt / MAKE_TIME * spd)
		if make_progress >= 1.0:
			completed = true
			game.on_building_completed(self)
		queue_redraw()
		return
	for cat in queues:
		# Retry spawning a unit whose exit was blocked.
		var q: Array = queues[cat]
		if not q.is_empty() and q[0].state == "ready" and cat != "building" and cat != "defense":
			if game.spawn_from_factory(self, q[0].type):
				q.remove_at(0)
			continue
		_process_queue(cat, dt)
	if repairing or game.cheats.flag(pid, "auto_repair_buildings"):
		_tick_repair(dt)
	if not weapons.is_empty() and not game.cheats.frozen(pid):
		_tick_defense(dt)
	if hp_ratio() < 0.5 and not game.headless:
		smoke_t -= dt
		if smoke_t <= 0.0:
			smoke_t = 0.5 + randf() * 0.6
			var p := Vector2(randf_range(0.2, 0.8) * size.x, randf_range(0.2, 0.7) * size.y) * MapGrid.T + position
			game.spawn_effect("fire" if hp_ratio() < 0.25 else "smoke", p)
	queue_redraw()

func _tick_repair(dt: float) -> void:
	if hp >= max_hp:
		repairing = false
		return
	var instant: bool = game.cheats.flag(pid, "instant_repair")
	var free_r: bool = game.cheats.flag(pid, "auto_repair_buildings") and not repairing
	var amount := max_hp if instant else max_hp * 0.06 * dt
	amount = minf(amount, max_hp - hp)
	var cost := int(ceil(amount / max_hp * float(def.get("cost", 0)) * 0.25))
	if not free_r and cost > 0 and not player().spend(cost, "build"):
		repairing = false
		game.notify(pid, "Repair stopped: insufficient funds.", "warn")
		return
	heal(amount)

func _tick_defense(dt: float) -> void:
	var w: Dictionary = weapons[0]
	var rf: float = game.rof_factor(pid)
	if not powered():
		charge = 0.0
		return
	if w.cd > 0.0:
		w.cd -= dt * rf
	charge = 1.0 - clampf(w.cd / float(w.def.rof), 0.0, 1.0)
	if target == null or not is_instance_valid(target) or target.dead or target.edge_distance(pos) > float(w.def.range) * MapGrid.T:
		target = null
		scan_t -= dt
		if scan_t <= 0.0:
			scan_t = 0.3
			target = game.find_target(self, float(w.def.range) * MapGrid.T)
		if target == null:
			return
	var desired = (target.pos - pos).angle()
	if def.get("turret", false) or def.get("sprite", "") == "flame_tower":
		turret_facing = rotate_toward(turret_facing, desired, 5.0 * dt)
		if absf(angle_difference(turret_facing, desired)) > 0.15:
			return
	if w.cd <= 0.0:
		Combat.fire(game, self, w.def, target)
		w.cd = float(w.def.rof)

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if not visible:
		return
	var extra := 0.0
	if def.get("sprite", "") == "refinery":
		extra = 1.0 if unload_anim > 0.0 else 0.0
	elif def.get("sprite", "") == "silo":
		var p = player()
		extra = float(p.stored_resources()) / float(maxi(p.storage_cap, 1))
	elif def.get("sprite", "") == "arc_coil":
		extra = charge
	var col := team_color()
	Sprites.draw_building(self, def.get("sprite", ""), size, col, player().faction, make_progress, anim, turret_facing, 1.0 - hp_ratio(), extra)
	if hit_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(size) * MapGrid.T), Color(1, 1, 1, 0.18))
	if not powered() and completed:
		draw_string(ThemeDB.fallback_font, Vector2(4, 14), "OFFLINE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.3, 0.2))
	if repairing:
		var c := Vector2(size) * MapGrid.T * 0.5
		var a := 0.5 + 0.5 * sin(anim * 6.0)
		draw_circle(c, 8, Color(0.1, 0.4, 0.1, 0.6 * a + 0.2))
		draw_line(c - Vector2(5, 0), c + Vector2(5, 0), Color(1, 1, 1), 2.0)
		draw_line(c - Vector2(0, 5), c + Vector2(0, 5), Color(1, 1, 1), 2.0)
	var W := size.x * MapGrid.T
	if selected:
		var c := Color(0.95, 0.95, 0.95, 0.9)
		var L := 8.0
		var H := size.y * MapGrid.T
		for corner in [Vector2(0, 0), Vector2(W, 0), Vector2(0, H), Vector2(W, H)]:
			var sx := 1.0 if corner.x == 0 else -1.0
			var sy := 1.0 if corner.y == 0 else -1.0
			draw_line(corner, corner + Vector2(L * sx, 0), c, 2.0)
			draw_line(corner, corner + Vector2(0, L * sy), c, 2.0)
		if rally != Vector2.INF and pid == game.human_pid:
			draw_line(Vector2(size) * MapGrid.T * 0.5, rally - position, Color(1, 1, 1, 0.5), 1.0)
			draw_circle(rally - position, 4, Color(1, 1, 1, 0.7))
	if selected or hovered or hp_ratio() < 0.999:
		draw_set_transform(Vector2(W * 0.5, 0), 0.0, Vector2.ONE)
		draw_health_bar(W - 8.0, -6.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------- save / load

func to_dict() -> Dictionary:
	var d := base_dict()
	var qs := {}
	for cat in queues:
		qs[cat] = []
		for it in queues[cat]:
			qs[cat].append(it.duplicate())
	d.merge({
		"cell": [cell0.x, cell0.y], "completed": completed, "make": make_progress,
		"queues": qs, "rally": [rally.x, rally.y] if rally != Vector2.INF else null,
		"repairing": repairing, "turret": turret_facing,
		"cd": weapons.map(func(w): return w.cd),
	})
	return d

func apply_dict(d: Dictionary) -> void:
	apply_base_dict(d)
	completed = bool(d.completed)
	make_progress = float(d.make)
	repairing = bool(d.get("repairing", false))
	turret_facing = float(d.get("turret", PI * 0.5))
	var r = d.get("rally")
	rally = Vector2(r[0], r[1]) if r != null else Vector2.INF
	for cat in d.get("queues", {}):
		queues[cat] = []
		for it in d.queues[cat]:
			queues[cat].append({"type": it.type, "progress": float(it.progress), "paid": int(it.paid), "state": it.state})
	var cds: Array = d.get("cd", [])
	for i in mini(cds.size(), weapons.size()):
		weapons[i].cd = float(cds[i])
	pos = Vector2(cell0.x + size.x * 0.5, cell0.y + size.y * 0.5) * MapGrid.T
