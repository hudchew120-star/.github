class_name Unit
extends Entity
## Mobile unit: path following, orders (move/attack/attack-move/guard/patrol/hold/scatter),
## automatic target acquisition, weapons, harvesting and MCV deployment.

var move_class: String = "foot"
var speed_px: float = 30.0
var turn_rate: float = 0.0
var has_turret: bool = false
var facing: float = 0.0
var turret_facing: float = 0.0
var weapons: Array = []            # [{id, def, cd, burst_left, burst_cd}]
var max_range_px: float = 0.0

var order: String = "idle"         # idle, move, attack, attack_move, guard, patrol, hold, harvest, deploy
var goal: Vector2 = Vector2.ZERO
var target = null                  # Entity
var target_uid: int = 0
var forced_target: bool = false    # target chosen explicitly by the player
var patrol_a: Vector2 = Vector2.ZERO
var patrol_b: Vector2 = Vector2.ZERO
var guard_pos: Vector2 = Vector2.ZERO
var path: Array = []
var path_i: int = 0
var path_goal_cell := Vector2i(-1, -1)
var need_path: bool = false
var moving: bool = false
var stuck_t: float = 0.0
var stuck_count: int = 0
var last_pos: Vector2 = Vector2.ZERO
var scan_t: float = 0.0
var repath_t: float = 0.0
var anim: float = 0.0
var rally_after_spawn := Vector2.INF
var last_fire_time: float = -10.0   # used by the renderer for firing animations

# Aircraft
var is_air_unit: bool = false
var altitude: float = 0.0          # cruising height (world units)
var altitude_now: float = 0.0      # current height, used by renderers
var hover: bool = true
var ammo: int = -1                 # -1 = unlimited
var max_ammo: int = -1
var rearm_t: float = 0.0
var air_state: String = "flying"   # flying, landed
var pad_uid: int = 0
var pad_index: int = -1
var orbit_t: float = 0.0

# Naval / special
var is_naval: bool = false
var submarine: bool = false
var surfaced_until: float = -100.0
var detector_px: float = 0.0
var engineer: bool = false

# Harvester state
var is_harvester: bool = false
var cargo: int = 0
var cargo_kind := {"ore": 0, "gems": 0}
var capacity: int = 0
var harv_state: String = ""        # seek, to_field, mining, to_refinery, wait_dock, unloading
var harv_timer: float = 0.0
var harv_cell := Vector2i(-1, -1)
var dock_uid: int = 0
var last_field := Vector2i(-1, -1)

func _ready() -> void:
	z_index = 2

func is_unit() -> bool:
	return true

func is_air() -> bool:
	return is_air_unit

func submerged() -> bool:
	return submarine and game.sim_time > surfaced_until

func setup_unit() -> void:
	move_class = def.get("move", "foot")
	speed_px = float(def.get("speed", 1.0)) * MapGrid.T
	turn_rate = float(def.get("turn_rate", 0.0))
	has_turret = bool(def.get("turret", false))
	radius = float(def.get("radius", 8))
	weapons.clear()
	max_range_px = 0.0
	for wid in def.get("weapons", []):
		var wd := Data.weapon(wid)
		if wd.is_empty():
			continue
		weapons.append({"id": wid, "def": wd, "cd": 0.0, "burst_left": 0, "burst_cd": 0.0})
		max_range_px = maxf(max_range_px, float(wd.range) * MapGrid.T)
	if def.has("harvester"):
		is_harvester = true
		capacity = int(def.harvester.capacity)
	is_air_unit = move_class == "air"
	if is_air_unit:
		altitude = float(def.get("altitude", 1.4))
		altitude_now = altitude
		hover = bool(def.get("hover", true))
		max_ammo = int(def.get("ammo", -1))
		ammo = max_ammo
	is_naval = move_class == "naval"
	submarine = bool(def.get("submarine", false))
	detector_px = float(def.get("detector", 0)) * MapGrid.T
	engineer = bool(def.get("engineer", false))
	position = pos
	last_pos = pos
	guard_pos = pos

func is_infantry() -> bool:
	return def.get("category", "") == "infantry"

func can_attack() -> bool:
	return not weapons.is_empty()

# ---------------------------------------------------------------- orders

func clear_target() -> void:
	target = null
	target_uid = 0
	forced_target = false

func cmd_stop() -> void:
	order = "idle"
	clear_target()
	_stop_moving()
	guard_pos = pos
	if is_harvester:
		harv_state = ""

func cmd_move(p: Vector2, keep_order: bool = false) -> void:
	if is_air_unit:
		order = "move"
		clear_target()
		goal = p
		moving = true
		return
	if not keep_order:
		order = "move"
		clear_target()
		if is_harvester:
			harv_state = ""
	goal = p
	_request_path()

func cmd_attack(t) -> void:
	if t == null:
		return
	if engineer and t.is_building():
		cmd_capture(t)
		return
	if not can_attack():
		return
	order = "attack"
	target = t
	target_uid = t.uid
	forced_target = true
	repath_t = 0.0
	_request_path_to_target()

func cmd_attack_move(p: Vector2) -> void:
	order = "attack_move"
	clear_target()
	goal = p
	if is_air_unit:
		moving = true
		return
	_request_path()

## Engineers: walk to a structure, then capture it (enemy) or fully repair it (own).
func cmd_capture(b) -> void:
	order = "capture"
	target = b
	target_uid = b.uid
	forced_target = true
	goal = b.pos
	_request_path()

func cmd_return_to_base() -> void:
	if is_air_unit:
		_return_to_base()

func cmd_guard() -> void:
	order = "guard"
	clear_target()
	guard_pos = pos
	_stop_moving()

func cmd_hold() -> void:
	order = "hold"
	clear_target()
	_stop_moving()

func cmd_patrol(p: Vector2) -> void:
	order = "patrol"
	clear_target()
	patrol_a = pos
	patrol_b = p
	goal = p
	_request_path()

func cmd_scatter() -> void:
	var dir := Vector2.RIGHT.rotated(randf() * TAU)
	var dest := pos + dir * MapGrid.T * randf_range(1.5, 3.0)
	var prev := order
	cmd_move(dest)
	if prev == "hold" or prev == "guard":
		order = "move"

func cmd_harvest(c: Vector2i = Vector2i(-1, -1)) -> void:
	if not is_harvester:
		return
	order = "harvest"
	clear_target()
	harv_cell = c
	harv_state = "seek" if c.x < 0 else "to_field"
	if c.x >= 0:
		goal = MapGrid.cell_center(c)
		_request_path()

func cmd_deploy() -> bool:
	if not def.has("deploys_to"):
		return false
	return game.try_deploy(self)

# ---------------------------------------------------------------- pathing

func _request_path() -> void:
	need_path = true
	moving = true
	stuck_t = 0.0

func _request_path_to_target() -> void:
	if target == null:
		return
	goal = target.pos
	_request_path()

func _stop_moving() -> void:
	path.clear()
	path_i = 0
	need_path = false
	moving = false

func compute_path() -> void:
	need_path = false
	if is_air_unit:
		return
	if order == "capture" and target != null and is_instance_valid(target):
		goal = MapGrid.cell_center(game.map.nearest_passable(MapGrid.to_cell(target.pos), move_class, 4))
	var gc := MapGrid.to_cell(goal)
	path = game.map.find_path(cell(), gc, move_class)
	path_i = 0
	path_goal_cell = gc
	if path.size() > 0 and path[0] == cell():
		path_i = 1
	if path.is_empty():
		moving = false

## Advances along the current path. Returns true when the destination is reached.
func _follow_path(dt: float) -> bool:
	if need_path:
		return false
	if not moving:
		return true
	if path_i >= path.size():
		var to_goal := goal - pos
		var final_ok = game.map.passable(MapGrid.to_cell(goal), move_class) and MapGrid.to_cell(goal) == path_goal_cell
		if final_ok and to_goal.length() > 2.0 and to_goal.length() < MapGrid.T * 1.5:
			_step_towards(goal, dt)
			return false
		moving = false
		return true
	var c: Vector2i = path[path_i]
	if not game.map.passable(c, move_class):
		need_path = true
		return false
	var wp := MapGrid.cell_center(c)
	if path_i == path.size() - 1 and MapGrid.to_cell(goal) == c:
		wp = goal
	if pos.distance_to(wp) < maxf(3.0, speed_px * dt * 1.2):
		path_i += 1
		return false
	_step_towards(wp, dt)
	return false

func _step_towards(wp: Vector2, dt: float) -> void:
	var to := wp - pos
	var d := to.length()
	if d < 0.01:
		return
	var desired := to.angle()
	if turn_rate > 0.0:
		facing = rotate_toward(facing, desired, turn_rate * dt)
		if absf(angle_difference(facing, desired)) > 0.9:
			if not has_turret:
				turret_facing = facing
			return
	else:
		facing = desired
	if not has_turret:
		turret_facing = facing
	var cost = game.map.move_cost(cell(), move_class)
	var spd := speed_px / maxf(cost, 0.5)
	pos += to / d * minf(spd * dt, d)
	anim += dt

func _check_stuck(dt: float) -> void:
	if not moving or need_path:
		stuck_t = 0.0
		last_pos = pos
		return
	stuck_t += dt
	if stuck_t >= 1.2:
		if pos.distance_to(last_pos) < 4.0:
			stuck_count += 1
			if pos.distance_to(goal) < MapGrid.T * 1.6 or stuck_count > 4:
				moving = false
				path.clear()
				stuck_count = 0
			else:
				need_path = true
		else:
			stuck_count = 0
		stuck_t = 0.0
		last_pos = pos

# ---------------------------------------------------------------- simulation

func tick(dt: float) -> void:
	if hit_flash > 0.0:
		hit_flash -= dt
	if game.cheats.frozen(pid):
		return
	if is_air_unit:
		_tick_weapons_cd(dt)
		_tick_air(dt)
		if game.sim_nodes_visible:
			position = pos
		return
	for w in weapons:
		if w.cd > 0.0:
			w.cd -= dt * game.rof_factor(pid)
		if w.burst_left > 0:
			w.burst_cd -= dt
			if w.burst_cd <= 0.0 and target != null and _target_valid(target):
				_fire_weapon(w, target)
				w.burst_left -= 1
				w.burst_cd = float(w.def.get("burst_delay", 0.15))
			elif target == null:
				w.burst_left = 0
	if target != null and not _target_valid(target):
		var was_forced := forced_target
		clear_target()
		if order == "attack":
			order = "guard" if was_forced else "idle"
			guard_pos = pos
			_stop_moving()
	match order:
		"idle", "guard":
			_tick_guard(dt)
		"move":
			if _follow_path(dt):
				order = "idle"
				guard_pos = pos
			_opportunistic_fire(dt)
		"attack":
			_tick_attack(dt)
		"attack_move":
			_tick_attack_move(dt)
		"patrol":
			_tick_patrol(dt)
		"hold":
			_tick_hold(dt)
		"harvest":
			_tick_harvest(dt)
		"capture":
			_tick_capture(dt)
	_check_stuck(dt)
	if game.sim_nodes_visible:
		position = pos
		queue_redraw()

func _target_valid(t) -> bool:
	if t == null or not is_instance_valid(t) or t.dead:
		return false
	if game.is_hidden_from(t, pid):
		return false
	if not is_enemy(t) and not forced_target:
		return false
	return true

func _in_range(w: Dictionary, t) -> bool:
	var d: float = t.edge_distance(pos)
	var r := float(w.def.range) * MapGrid.T
	var mn := float(w.def.get("min_range", 0.0)) * MapGrid.T
	return d <= r and d >= mn

func _weapon_for(t):
	for w in weapons:
		if Combat.can_target(w.def, t):
			return w
	return null

## Aims and fires at the target if possible. Returns true when the target is within range.
func _engage(t, dt: float) -> bool:
	var w = _weapon_for(t)
	if w == null:
		return false
	if not _in_range(w, t):
		return false
	var desired = (t.pos - pos).angle()
	var aligned := false
	if has_turret:
		turret_facing = rotate_toward(turret_facing, desired, 7.0 * dt)
		aligned = absf(angle_difference(turret_facing, desired)) < 0.12
	elif turn_rate > 0.0:
		facing = rotate_toward(facing, desired, turn_rate * dt)
		turret_facing = facing
		aligned = absf(angle_difference(facing, desired)) < 0.15
	else:
		facing = desired
		turret_facing = desired
		aligned = true
	if aligned and w.cd <= 0.0:
		_fire_weapon(w, t)
		w.cd = float(w.def.rof)
		var burst := int(w.def.get("burst", 1))
		if burst > 1:
			w.burst_left = burst - 1
			w.burst_cd = float(w.def.get("burst_delay", 0.15))
	return true

func _fire_weapon(w: Dictionary, t) -> void:
	Combat.fire(game, self, w.def, t)
	last_fire_time = game.sim_time
	if max_ammo > 0:
		ammo -= 1
	if submarine:
		surfaced_until = game.sim_time + 3.0
	if is_infantry():
		anim += 0.05

func _scan(radius_px: float):
	scan_t -= 1.0
	return game.find_target(self, radius_px)

func _acquire(dt: float, radius_px: float) -> void:
	if not can_attack():
		return
	scan_t -= dt
	if scan_t > 0.0:
		return
	scan_t = 0.35 + randf() * 0.2
	var t = game.find_target(self, radius_px)
	if t != null:
		target = t
		target_uid = t.uid
		forced_target = false

func _tick_guard(dt: float) -> void:
	if moving:
		_follow_path(dt)
	if target == null:
		var r := max_range_px + (MapGrid.T * 2.0 if order == "guard" else MapGrid.T * 0.5)
		_acquire(dt, r)
		if target == null and not moving and pos.distance_to(guard_pos) > MapGrid.T * 2.0 and order == "guard":
			goal = guard_pos
			_request_path()
		return
	if _engage(target, dt):
		_stop_moving()
		return
	# Chase, but not too far from the guard position.
	var leash := float(sight + 3) * MapGrid.T
	if pos.distance_to(guard_pos) > leash or is_harvester:
		clear_target()
		goal = guard_pos
		_request_path()
		return
	_chase(dt)

func _chase(dt: float) -> void:
	repath_t -= dt
	if repath_t <= 0.0 or not moving:
		repath_t = 1.0
		goal = target.pos
		_request_path()
	_follow_path(dt)

func _tick_attack(dt: float) -> void:
	if target == null:
		order = "idle"
		return
	if _engage(target, dt):
		_stop_moving()
		return
	_chase(dt)

func _opportunistic_fire(dt: float) -> void:
	# Turreted vehicles fire at enemies in range while moving.
	if not has_turret or not can_attack():
		return
	if target == null or not _target_valid(target):
		_acquire(dt, max_range_px)
	if target != null and _target_valid(target):
		if not _engage(target, dt):
			clear_target()

func _tick_attack_move(dt: float) -> void:
	if target == null:
		_acquire(dt, float(sight) * MapGrid.T)
	if target != null:
		if _engage(target, dt):
			if not has_turret:
				_stop_moving()
			else:
				_stop_moving()
			return
		_chase(dt)
		if target != null and pos.distance_to(target.pos) > float(sight + 4) * MapGrid.T:
			clear_target()
			_request_path()
		return
	if not moving and not need_path:
		if pos.distance_to(goal) > MapGrid.T * 1.5 and stuck_count < 4:
			_request_path()
		else:
			order = "guard"
			guard_pos = pos
		return
	if _follow_path(dt):
		order = "guard"
		guard_pos = pos

func _tick_patrol(dt: float) -> void:
	if target == null:
		_acquire(dt, float(sight) * MapGrid.T)
	if target != null:
		if _engage(target, dt):
			_stop_moving()
			return
		_chase(dt)
		if target != null and pos.distance_to(target.pos) > float(sight + 4) * MapGrid.T:
			clear_target()
			_request_path()
		return
	if not moving and not need_path:
		var next := patrol_a if goal.distance_to(patrol_b) < 1.0 else patrol_b
		goal = next
		_request_path()
		return
	_follow_path(dt)

func _tick_hold(dt: float) -> void:
	if target == null:
		_acquire(dt, max_range_px)
	if target != null and not _engage(target, dt):
		clear_target()

# ---------------------------------------------------------------- harvesting

func _tick_harvest(dt: float) -> void:
	match harv_state:
		"", "seek":
			if cargo >= capacity:
				harv_state = "to_refinery"
				_go_to_refinery()
				return
			harv_timer -= dt
			if harv_timer > 0.0:
				return
			var c: Vector2i = game.find_ore_near(last_field if last_field.x >= 0 else cell(), self)
			if c.x < 0:
				harv_timer = 3.0
				if cargo > 0:
					harv_state = "to_refinery"
					_go_to_refinery()
				return
			harv_cell = c
			goal = MapGrid.cell_center(c)
			harv_state = "to_field"
			_request_path()
		"to_field":
			if game.map.ore[game.map.idx(harv_cell)] <= 0:
				harv_state = "seek"
				return
			if cell() == harv_cell or (_follow_path(dt) and pos.distance_to(goal) < MapGrid.T * 1.5):
				harv_state = "mining"
				harv_timer = float(def.harvester.scoop_time)
				_stop_moving()
				if cell() != harv_cell:
					harv_cell = cell() if game.map.ore[game.map.idx(cell())] > 0 else harv_cell
			elif not moving and not need_path:
				harv_state = "seek"
				harv_timer = 0.5
		"mining":
			harv_timer -= dt
			anim += dt
			if harv_timer > 0.0:
				return
			harv_timer = float(def.harvester.scoop_time)
			var c := harv_cell
			if game.map.ore[game.map.idx(c)] <= 0 and game.map.ore[game.map.idx(cell())] > 0:
				c = cell()
			var kind_id = game.map.ore_kind[game.map.idx(c)]
			var res_key := "gems" if kind_id == 2 else "ore"
			var scoop := int(Data.resources[res_key]["value_per_scoop"])
			var got: Dictionary = game.map.take_ore(c, mini(scoop, capacity - cargo), not game.cheats.flag(pid, "no_depletion"))
			if int(got.amount) > 0:
				cargo += int(got.amount)
				cargo_kind[res_key] = int(cargo_kind[res_key]) + int(got.amount)
				last_field = c
			if cargo >= capacity:
				harv_state = "to_refinery"
				_go_to_refinery()
			elif game.map.ore[game.map.idx(c)] <= 0:
				var n: Vector2i = game.find_ore_near(c, self, 3)
				if n.x < 0:
					harv_state = "to_refinery" if cargo > 0 else "seek"
					if cargo > 0:
						_go_to_refinery()
				else:
					harv_cell = n
					goal = MapGrid.cell_center(n)
					harv_state = "to_field"
					_request_path()
		"to_refinery":
			var r = game.entities.get(dock_uid)
			if r == null or r.dead:
				_go_to_refinery()
				return
			var dock: Vector2i = r.dock_cell()
			if cell() == dock:
				if r.dock_busy_uid == 0 or r.dock_busy_uid == uid:
					r.dock_busy_uid = uid
					harv_state = "unloading"
					harv_timer = float(def.harvester.unload_time)
					pos = MapGrid.cell_center(dock)
					facing = PI * 0.5
					_stop_moving()
				return
			if _follow_path(dt) or (not moving and not need_path):
				if pos.distance_to(MapGrid.cell_center(dock)) < MapGrid.T * 2.5:
					if r.dock_busy_uid == 0 or r.dock_busy_uid == uid:
						goal = MapGrid.cell_center(dock)
						_request_path()
						if cell() == dock or pos.distance_to(goal) < 6.0:
							pos = goal
					else:
						harv_state = "wait_dock"
						harv_timer = 1.0
				else:
					_go_to_refinery()
		"wait_dock":
			harv_timer -= dt
			if harv_timer <= 0.0:
				harv_state = "to_refinery"
				_go_to_refinery()
		"unloading":
			var r = game.entities.get(dock_uid)
			if r == null or r.dead:
				harv_state = "to_refinery"
				_go_to_refinery()
				return
			r.unload_anim = 0.3
			harv_timer -= dt
			if harv_timer <= 0.0:
				var p = player()
				for k in cargo_kind:
					if int(cargo_kind[k]) > 0:
						p.deposit(k, int(cargo_kind[k]))
						cargo_kind[k] = 0
				cargo = 0
				r.dock_busy_uid = 0
				harv_state = "seek"
				harv_timer = 0.0
				# Back out of the dock.
				goal = pos + Vector2(0, MapGrid.T * 1.5)
				_request_path()

func _go_to_refinery() -> void:
	var r = game.find_refinery_for(self)
	if r == null:
		dock_uid = 0
		harv_state = "wait_dock"
		harv_timer = 3.0
		_stop_moving()
		return
	dock_uid = r.uid
	harv_state = "to_refinery"
	goal = MapGrid.cell_center(r.dock_cell())
	_request_path()

# ---------------------------------------------------------------- engineers

func _tick_capture(dt: float) -> void:
	if target == null or not is_instance_valid(target) or target.dead:
		order = "idle"
		clear_target()
		_stop_moving()
		return
	if target.edge_distance(pos) <= MapGrid.T * 0.85:
		game.engineer_use(self, target)
		return
	repath_t -= dt
	if not moving and not need_path and repath_t <= 0.0:
		repath_t = 1.0
		_request_path()
	_follow_path(dt)

# ---------------------------------------------------------------- aircraft

func _tick_weapons_cd(dt: float) -> void:
	for w in weapons:
		if w.cd > 0.0:
			w.cd -= dt

func _tick_air(dt: float) -> void:
	var want_h := altitude if air_state == "flying" else 0.0
	altitude_now = move_toward(altitude_now, want_h, dt * 1.1)
	anim += dt
	if target != null and not _target_valid(target):
		clear_target()
		if order == "attack":
			order = "idle"
			guard_pos = pos
	if air_state == "landed":
		_rearm(dt)
		if order in ["move", "attack", "attack_move", "patrol"]:
			_take_off()
		else:
			moving = false
			return
	if max_ammo > 0 and ammo <= 0 and order != "return":
		_return_to_base()
	match order:
		"move":
			if _fly_to(goal, dt):
				order = "idle"
				guard_pos = pos
				moving = false
		"attack":
			_air_attack(dt)
		"attack_move", "patrol":
			if target == null and (max_ammo <= 0 or ammo > 0):
				_acquire(dt, float(sight) * MapGrid.T)
			if target != null:
				_air_attack(dt)
			elif _fly_to(goal, dt):
				order = "idle"
				guard_pos = pos
		"return":
			var b = game.entities.get(pad_uid)
			if b == null or b.dead:
				_return_to_base()
				return
			var pp: Vector2 = game.pad_position(b, pad_index)
			if _fly_to(pp, dt, true):
				pos = pp
				air_state = "landed"
				facing = PI * 0.25
				order = "idle"
				moving = false
		_:
			if hover:
				moving = false
				if max_ammo <= 0 or ammo > 0:
					if target == null:
						_acquire(dt, max_range_px)
					if target != null and not _air_engage_hover(target, dt):
						clear_target()
			else:
				if game.has_airfield(pid):
					_return_to_base()
				else:
					orbit_t += dt
					_fly_to(guard_pos + Vector2(cos(orbit_t * 0.8), sin(orbit_t * 0.8)) * 70.0, dt)

func _fly_to(p: Vector2, dt: float, precise: bool = false) -> bool:
	var to := p - pos
	var d := to.length()
	moving = true
	if hover or precise and d < 60.0:
		if d < 3.0:
			return true
		var desired := to.angle()
		facing = rotate_toward(facing, desired, turn_rate * dt)
		turret_facing = facing
		var step := speed_px * dt * (0.6 if precise and d < 60.0 else 1.0)
		pos += to / d * minf(step, d)
		return d < 4.0
	# Jets always fly forward and turn with a limited rate.
	var desired := to.angle()
	facing = rotate_toward(facing, desired, turn_rate * dt)
	turret_facing = facing
	pos += Vector2.RIGHT.rotated(facing) * speed_px * dt
	pos.x = clampf(pos.x, 0.0, game.map.w * MapGrid.T)
	pos.y = clampf(pos.y, 0.0, game.map.h * MapGrid.T)
	return d < maxf(40.0, speed_px * dt * 2.0)

func _air_engage_hover(t, dt: float) -> bool:
	var w = _weapon_for(t)
	if w == null or not _in_range(w, t):
		return false
	var desired: float = (t.pos - pos).angle()
	facing = rotate_toward(facing, desired, turn_rate * dt)
	turret_facing = facing
	if absf(angle_difference(facing, desired)) < 0.3 and w.cd <= 0.0 and (max_ammo <= 0 or ammo > 0):
		_fire_weapon(w, t)
		w.cd = float(w.def.rof)
	return true

func _air_attack(dt: float) -> void:
	if target == null:
		order = "idle"
		return
	var w = _weapon_for(target)
	if w == null:
		order = "idle"
		clear_target()
		return
	if hover:
		if not _air_engage_hover(target, dt):
			_fly_to(target.pos, dt)
		return
	# Strafing run: keep flying, fire whenever the target is ahead and in range.
	_fly_to(target.pos, dt)
	var desired: float = (target.pos - pos).angle()
	if _in_range(w, target) and absf(angle_difference(facing, desired)) < 0.6 and w.cd <= 0.0 and ammo > 0:
		_fire_weapon(w, target)
		w.cd = float(w.def.rof)

func _rearm(dt: float) -> void:
	if max_ammo > 0 and ammo < max_ammo:
		rearm_t += dt
		if rearm_t >= float(def.get("rearm_time", 1.0)):
			rearm_t = 0.0
			ammo += 1
	if hp < max_hp:
		heal(max_hp * 0.03 * dt)

func _take_off() -> void:
	air_state = "flying"
	game.release_pad(self)

func _return_to_base(prefer = null) -> void:
	var r: Dictionary = game.reserve_pad(self, prefer)
	clear_target()
	if r.is_empty():
		order = "idle"
		guard_pos = pos
		return
	order = "return"
	moving = true

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if not visible:
		return
	var extra := float(cargo) / float(capacity) if capacity > 0 else 0.0
	Sprites.draw_unit(self, def.get("sprite", ""), team_color(), player().faction, facing, turret_facing, anim, extra)
	if hit_flash > 0.0:
		draw_circle(Vector2.ZERO, radius * 0.8, Color(1, 1, 1, 0.35))
	if selected:
		var r := radius + 3.0
		var c := Color(0.95, 0.95, 0.95, 0.9)
		for i in 4:
			var a := i * PI * 0.5 + PI * 0.25
			draw_arc(Vector2.ZERO, r, a - 0.35, a + 0.35, 6, c, 1.5)
	if selected or hovered or hp_ratio() < 0.999:
		if selected or hovered or hp_ratio() < 0.5:
			draw_health_bar(maxf(radius * 2.0, 14.0), -radius - 8.0)
	if selected and is_harvester:
		draw_rect(Rect2(-radius, -radius - 3.5, radius * 2.0 * extra, 2), Color(0.95, 0.75, 0.25))

# ---------------------------------------------------------------- save / load

func to_dict() -> Dictionary:
	var d := base_dict()
	d.merge({
		"facing": facing, "turret": turret_facing, "order": order,
		"goal": [goal.x, goal.y], "target": target.uid if target != null and is_instance_valid(target) else 0,
		"forced": forced_target, "patrol": [patrol_a.x, patrol_a.y, patrol_b.x, patrol_b.y],
		"guard": [guard_pos.x, guard_pos.y], "moving": moving,
		"cargo": cargo, "cargo_kind": cargo_kind.duplicate(), "harv_state": harv_state,
		"harv_cell": [harv_cell.x, harv_cell.y], "last_field": [last_field.x, last_field.y],
		"cd": weapons.map(func(w): return w.cd),
		"ammo": ammo, "air_state": air_state, "alt": altitude_now, "pad": pad_uid, "pad_i": pad_index,
	})
	return d

func apply_dict(d: Dictionary) -> void:
	apply_base_dict(d)
	facing = float(d.get("facing", 0))
	turret_facing = float(d.get("turret", 0))
	order = d.get("order", "idle")
	goal = Vector2(d.goal[0], d.goal[1])
	target_uid = int(d.get("target", 0))
	forced_target = bool(d.get("forced", false))
	var pa: Array = d.get("patrol", [0, 0, 0, 0])
	patrol_a = Vector2(pa[0], pa[1])
	patrol_b = Vector2(pa[2], pa[3])
	guard_pos = Vector2(d.guard[0], d.guard[1])
	cargo = int(d.get("cargo", 0))
	for k in d.get("cargo_kind", {}):
		cargo_kind[k] = int(d.cargo_kind[k])
	harv_state = d.get("harv_state", "")
	harv_cell = Vector2i(int(d.harv_cell[0]), int(d.harv_cell[1]))
	last_field = Vector2i(int(d.last_field[0]), int(d.last_field[1]))
	var cds: Array = d.get("cd", [])
	for i in mini(cds.size(), weapons.size()):
		weapons[i].cd = float(cds[i])
	ammo = int(d.get("ammo", ammo))
	air_state = d.get("air_state", air_state)
	altitude_now = float(d.get("alt", altitude_now))
	pad_uid = int(d.get("pad", 0))
	pad_index = int(d.get("pad_i", -1))
	if bool(d.get("moving", false)) or order in ["move", "attack_move", "patrol"]:
		_request_path()
	if is_harvester and order == "harvest" and harv_state in ["to_refinery", "unloading", "wait_dock"]:
		harv_state = "to_refinery"
		dock_uid = 0
	position = pos
	last_pos = pos
