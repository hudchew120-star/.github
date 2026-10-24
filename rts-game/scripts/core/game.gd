class_name Game
extends Node2D
## Match manager: owns the map, players and entities, and runs the fixed-timestep simulation.

signal message(text: String, kind: String)
signal game_over(won: bool)
signal entity_removed(e)

const T := MapGrid.T
const DT := 1.0 / 30.0
const PHYS_HZ := 30.0
const PATH_BUDGET := 60
const PLAYER_COLORS := ["#3f7fd9", "#c8352c", "#d9b43f", "#4fae4f"]

var settings: Dictionary = {}
var map: MapGrid
var players: Array = []
var human_pid: int = 0
var entities := {}
var units: Array = []
var buildings: Array = []
var projectiles: Array = []
var next_uid: int = 1
var tick_count: int = 0
var sim_time: float = 0.0
var speed: float = 1.0
var paused: bool = false
var accumulator: float = 0.0
var over: bool = false
var won: bool = false
var cheats: Cheats
var specials: Specials
var ais: Array = []
var unit_hash := SpatialHash.new(128.0)
var building_hash := SpatialHash.new(192.0)
var headless: bool = false
var selection: Array = []          # set by the player controller (used by cheats)
var cursor_cell := Vector2i(-1, -1)
var ore_claims := {}               # cell -> harvester uid
var _path_cursor: int = 0
var _attack_msg_t: float = -100.0
var _circle_cache := {}
var audio = null
var objectives: Array = []
var view3d = null                  # external presentation (isometric or 3D view)
var sub_detected := {}             # player id -> {submarine uid: true}

var terrain_layer: TileMapLayer
var ore_layer: TileMapLayer
var building_layer: Node2D
var unit_layer: Node2D
var fx_layer: Node2D
var fog_sprite: Sprite2D
var fog_image: Image
var sim_nodes_visible := true    # false when a separate view (iso/3D) draws the battlefield
var fog_texture: ImageTexture

# ---------------------------------------------------------------- setup

func setup(s: Dictionary, is_headless: bool = false) -> void:
	settings = default_settings()
	settings.merge(s, true)
	headless = is_headless
	cheats = Cheats.new(self)
	specials = Specials.new(self)
	cheats.enabled = bool(settings.cheats_allowed) or settings.mode == "sandbox"
	if cheats.enabled:
		cheats.load_persisted()
	if settings.has("map_data"):
		map = MapGen.from_text_dict(settings.map_data)
	elif String(settings.get("map_preset", "")) != "":
		map = MapGen.generate(MapGen.preset_opts(settings.map_preset, 1 + int(settings.ai_count), settings.resources))
	elif String(settings.get("map_file", "")) != "":
		map = MapGen.load_file(settings.map_file)
	if map == null:
		map = MapGen.generate({"size": settings.map_size, "players": 1 + int(settings.ai_count), "seed": int(settings.seed), "resources": settings.resources, "water": settings.get("water", "lakes")})
	_build_layers()
	_create_players()
	_spawn_start_forces()
	for p in players:
		p.recompute(buildings)
	speed = float(settings.speed)
	objectives = [{"text": _victory_text(), "done": false, "optional": false}]
	update_fog(true)

static func default_settings() -> Dictionary:
	return {
		"mode": "skirmish", "map_size": "medium", "seed": 1, "map_file": "",
		"player_faction": "coalition", "enemy_factions": ["dominion"], "ai_count": 1,
		"difficulty": "normal", "start_credits": 10000, "start_units": "mcv", "resources": "normal",
		"speed": 1.0, "fog": true, "victory": "structures", "cheats_allowed": false,
		"power_enabled": true, "build_speed": 1.0, "refund_ratio": 1.0, "max_units": 600,
		"start_power_bonus": 0, "start_structures": false,
	}

func _victory_text() -> String:
	match settings.victory:
		"annihilation":
			return "Destroy every enemy unit and structure."
		"none":
			return "No victory condition (free play)."
	return "Destroy all enemy structures and construction vehicles."

func _create_players() -> void:
	var pf: String = settings.player_faction
	# A map has a fixed number of start positions; extra AI opponents are dropped.
	settings.ai_count = clampi(int(settings.ai_count), 0, maxi(map.starts.size() - 1, 0))
	var n := 1 + int(settings.ai_count)
	var efs: Array = settings.enemy_factions
	var used_colors := []
	for i in n:
		var p := Player.new()
		p.game = self
		p.id = i
		p.is_human = i == 0
		p.faction = pf if i == 0 else String(efs[(i - 1) % maxi(efs.size(), 1)] if efs.size() > 0 else "dominion")
		if p.faction == "random":
			p.faction = ["coalition", "dominion"][randi() % 2]
		var col := Data.faction_color(p.faction).to_html()
		if used_colors.has(col):
			for c in PLAYER_COLORS:
				if not used_colors.has(c):
					col = c
					break
		used_colors.append(col)
		p.color = Color(col)
		p.team = i                      # free-for-all; human is team 0
		if settings.get("ai_teamed", false) and i > 0:
			p.team = 1
		p.name = "Commander" if i == 0 else "AI %d (%s)" % [i, String(settings.difficulty).capitalize()]
		p.difficulty = settings.difficulty
		p.cash = int(settings.start_credits)
		p.power_bonus = int(settings.start_power_bonus)
		p.vis = PackedByteArray()
		p.vis.resize(map.w * map.h)
		p.vis.fill(0)
		players.append(p)
		if i > 0:
			var ai := AIController.new(self, p)
			ais.append(ai)
	human_pid = 0

func _spawn_start_forces() -> void:
	for p in players:
		var s: Vector2i = map.starts[p.id % map.starts.size()]
		var mode: String = settings.start_units
		if mode == "base" or settings.get("start_structures", false):
			_spawn_start_base(p, s)
		else:
			spawn_unit(p.id, "mcv", MapGrid.cell_center(s))
		if mode == "mcv_army" or mode == "base":
			var army := ["e1", "e1", "e1", "e1"]
			army.append("e3" if p.faction == "coalition" else "e4")
			army.append("ltank" if p.faction == "coalition" else "htank")
			army.append("ltank" if p.faction == "coalition" else "htank")
			var k := 0
			for t in army:
				var c := map.nearest_passable(s + Vector2i(-3 + k % 4, 3 + k / 4), Data.units[t].move, 6)
				if c.x >= 0:
					spawn_unit(p.id, t, MapGrid.cell_center(c))
				k += 1

func _spawn_start_base(p, s: Vector2i) -> void:
	create_building(p.id, "fact", s - Vector2i(1, 1), true)
	var plan := [["powr", Vector2i(3, -1)], ["proc", Vector2i(-5, -1)], [Data.building_for_tag(p.faction, "barracks"), Vector2i(3, 2)]]
	for item in plan:
		var c: Vector2i = s + item[1]
		if can_place(p.id, item[0], c, true) == "":
			create_building(p.id, item[0], c, true)

func _build_layers() -> void:
	terrain_layer = TileMapLayer.new()
	ore_layer = TileMapLayer.new()
	building_layer = Node2D.new()
	unit_layer = Node2D.new()
	unit_layer.y_sort_enabled = true
	fx_layer = Node2D.new()
	add_child(terrain_layer)
	add_child(ore_layer)
	add_child(building_layer)
	add_child(unit_layer)
	add_child(fx_layer)
	if headless:
		sim_nodes_visible = false
		return
	if bool(settings.get("use_3d", false)):
		# The 3D view draws everything; keep the 2D nodes for logic only.
		sim_nodes_visible = false
		building_layer.visible = false
		unit_layer.visible = false
		fx_layer.visible = false
		fog_image = Image.create(map.w, map.h, false, Image.FORMAT_L8)
		fog_texture = ImageTexture.create_from_image(fog_image)
		return
	terrain_layer.tile_set = TerrainArt.build_terrain_tileset()
	ore_layer.tile_set = TerrainArt.build_ore_tileset()
	for y in map.h:
		for x in map.w:
			var c := Vector2i(x, y)
			terrain_layer.set_cell(c, 0, Vector2i((x * 7 + y * 13) % TerrainArt.VARIANTS, map.terrain[map.idx(c)]))
			_refresh_ore_cell(c)
	var blend := Node2D.new()
	add_child(blend)
	move_child(blend, terrain_layer.get_index() + 1)
	TerrainBlend.build(blend, map)
	fog_image = Image.create(map.w, map.h, false, Image.FORMAT_L8)
	fog_texture = ImageTexture.create_from_image(fog_image)
	fog_sprite = Sprite2D.new()
	fog_sprite.texture = fog_texture
	fog_sprite.centered = false
	fog_sprite.scale = Vector2(T, T)
	fog_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fog_sprite.z_index = 20
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){ float v = texture(TEXTURE, UV).r; COLOR = vec4(0.02,0.025,0.03, v); }"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	fog_sprite.material = mat
	add_child(fog_sprite)

func _refresh_ore_cell(c: Vector2i) -> void:
	if headless:
		return
	var st := map.ore_stage(c)
	if st <= 0:
		ore_layer.erase_cell(c)
	else:
		var kind := map.ore_kind[map.idx(c)]
		ore_layer.set_cell(c, 0, Vector2i((c.x * 3 + c.y * 5) % TerrainArt.VARIANTS, (kind - 1) * 4 + st - 1))

# ---------------------------------------------------------------- entity management

func _register(e) -> void:
	if e.uid == 0:
		e.uid = next_uid
		next_uid += 1
	else:
		next_uid = maxi(next_uid, e.uid + 1)
	entities[e.uid] = e

func unit_count() -> int:
	return units.size()

func max_units() -> int:
	return int(settings.get("max_units", 600))

func spawn_unit(pid: int, t: String, p: Vector2, uid: int = 0) -> Unit:
	if units.size() >= max_units():
		notify(human_pid, "Unit limit (%d) reached. Raise it in settings to create more." % max_units(), "warn")
		return null
	if units.size() == int(max_units() * 0.9):
		notify(human_pid, "Warning: approaching the unit limit (%d/%d)." % [units.size(), max_units()], "warn")
	var u := Unit.new()
	u.init_entity(self, t, pid)
	u.uid = uid
	u.pos = p
	u.setup_unit()
	# Never drop ground units into the sea or ships onto land.
	if not u.is_air_unit and map != null and not map.terrain_passable(u.cell(), u.move_class):
		var c: Vector2i = map.nearest_passable(u.cell(), u.move_class, 12)
		if c.x >= 0:
			u.pos = MapGrid.cell_center(c)
	_register(u)
	units.append(u)
	if not sim_nodes_visible:
		u.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	unit_layer.add_child(u)
	u.reset_physics_interpolation()
	if u.is_harvester:
		u.cmd_harvest()
	return u

func create_building(pid: int, t: String, c: Vector2i, instant: bool, uid: int = 0) -> Building:
	var b := Building.new()
	b.init_entity(self, t, pid)
	b.uid = uid
	b.setup_building(c, instant)
	_register(b)
	buildings.append(b)
	building_layer.add_child(b)
	b.reset_physics_interpolation()
	for cc in b.footprint_cells():
		map.set_occupied(cc, b.uid)
	building_hash.rebuild(buildings)
	_push_units_out_of(b)
	if instant:
		on_building_completed(b, true)
	else:
		play_sound("build", b.pos)
	return b

func _push_units_out_of(b) -> void:
	var cells: Array = b.footprint_cells()
	for u in units:
		if u.dead:
			continue
		if cells.has(u.cell()):
			var dest: Vector2i = map.nearest_passable(u.cell(), u.move_class, 6)
			if dest.x >= 0:
				u.pos = MapGrid.cell_center(dest)
				u.position = u.pos
				u.reset_physics_interpolation()
				if u.order == "harvest":
					u.harv_state = "seek"
				else:
					u.cmd_stop()

func remove_entity(e) -> void:
	entities.erase(e.uid)
	if e.is_unit() and e.is_air_unit:
		release_pad(e)
	if e.is_unit():
		units.erase(e)
		for c in ore_claims.keys():
			if ore_claims[c] == e.uid:
				ore_claims.erase(c)
	else:
		buildings.erase(e)
		for c in e.footprint_cells():
			if map.occupied[map.idx(c)] == e.uid:
				map.set_occupied(c, 0)
		building_hash.rebuild(buildings)
	selection.erase(e)
	entity_removed.emit(e)
	e.queue_free()

func on_building_completed(b, silent: bool = false) -> void:
	var p = players[b.pid]
	p.recompute(buildings)
	for cat in b.queues:
		if not p.primary.has(cat) or not entities.has(int(p.primary[cat])):
			p.primary[cat] = b.uid
	if b.def.has("free_unit"):
		var c := map.nearest_passable(b.dock_cell() + Vector2i(0, 1), "track", 6)
		if c.x >= 0:
			spawn_unit(b.pid, b.def.free_unit, MapGrid.cell_center(c))
	if not silent:
		notify(b.pid, "%s complete." % b.def.name, "build")
		play_sound("complete", b.pos)

func on_entity_damaged(e, attacker) -> void:
	if e.pid == human_pid and e.is_building() and sim_time - _attack_msg_t > 15.0:
		_attack_msg_t = sim_time
		notify(human_pid, "Our base is under attack!", "alert")
	for ai in ais:
		if ai.player.id == e.pid:
			ai.on_damaged(e, attacker)

func on_entity_died(e, killer) -> void:
	var p = players[e.pid]
	if killer != null and is_instance_valid(killer) and killer.pid != e.pid:
		players[killer.pid].stats.units_killed += 1
	if e.is_unit():
		p.stats.units_lost += 1
		var inf: bool = e.is_infantry()
		if e.is_air_unit and e.altitude_now > 0.1:
			# Shot down: burst in the air, then the wreck hits the ground.
			spawn_effect("explosion", e.pos, {"h": e.altitude_now})
			spawn_effect("explosion_big", e.pos + Vector2(randf_range(-10, 10), randf_range(-10, 10)))
		elif e.is_naval:
			spawn_effect("explosion", e.pos)
		else:
			spawn_effect("explosion_small" if inf else "explosion", e.pos)
		if not inf and not e.is_naval and map.terrain_id(e.cell()) != "water":
			spawn_effect("crater", e.pos, {"r": e.radius * 0.8})
		play_sound("die_inf" if inf else "explode", e.pos)
		if e.pid == human_pid and e.def.get("category", "") != "infantry":
			notify(human_pid, "%s lost." % e.def.name, "warn")
	else:
		p.stats.buildings_lost += 1
		var r: Rect2 = e.rect_px()
		for i in maxi(2, e.size.x * e.size.y):
			spawn_effect("explosion", r.position + Vector2(randf() * r.size.x, randf() * r.size.y))
		spawn_effect("explosion_big", r.get_center())
		spawn_effect("crater", r.get_center(), {"r": r.size.x * 0.45})
		play_sound("explode_big", e.pos)
		if e.pid == human_pid:
			notify(human_pid, "%s destroyed." % e.def.name, "alert")
		# Release docked harvesters.
		for u in units:
			if u.dock_uid == e.uid:
				u.dock_uid = 0
	remove_entity(e)
	if e.is_building():
		p.recompute(buildings)
		for cat in p.primary.keys():
			if int(p.primary[cat]) == e.uid:
				p.primary.erase(cat)
				for b in buildings:
					if b.pid == p.id and b.completed and b.produces(cat):
						p.primary[cat] = b.uid
						break

# ---------------------------------------------------------------- queries

func are_enemies(a: int, b: int) -> bool:
	if a == b or a < 0 or b < 0:
		return false
	return players[a].team != players[b].team

func first_enemy_of(pid: int) -> int:
	for p in players:
		if are_enemies(pid, p.id) and not p.defeated:
			return p.id
	for p in players:
		if are_enemies(pid, p.id):
			return p.id
	return -1

func power_enabled(_pid: int) -> bool:
	return bool(settings.power_enabled) and not cheats.flags.get("no_power", false) if cheats.enabled else bool(settings.power_enabled)

func rof_factor(pid: int) -> float:
	# Low power slows down powered defenses but never unit weapons.
	return 1.0

func entities_near(p: Vector2, r: float) -> Array:
	return unit_hash.query(p, r) + building_hash.query(p, r + 96.0)

func selection_entities() -> Array:
	var out := []
	for e in selection:
		if is_instance_valid(e) and not e.dead:
			out.append(e)
	return out

## Finds the best enemy for `e` to engage within radius (pixels).
func find_target(e, radius: float):
	var best = null
	var best_score := INF
	var weapons: Array = e.weapons
	for o in entities_near(e.pos, radius):
		if o.dead or not e.is_enemy(o) or is_hidden_from(o, e.pid):
			continue
		var d: float = o.edge_distance(e.pos)
		if d > radius:
			continue
		var usable := false
		for w in weapons:
			if Combat.can_target(w.def, o):
				usable = true
				break
		if not usable:
			continue
		var score := d
		if o.is_building():
			score += 160.0
			if o.weapons.size() > 0:
				score -= 120.0
		elif o.can_attack():
			score -= 48.0
		if score < best_score:
			best_score = score
			best = o
	return best

func find_ore_near(c: Vector2i, harv, max_r: int = 40) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for r in range(0, max_r + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if not map.in_bounds(n) or map.ore[map.idx(n)] <= 0:
					continue
				if not map.passable(n, harv.move_class):
					continue
				var claim = ore_claims.get(n, 0)
				var penalty := 0.0
				if claim != 0 and claim != harv.uid and entities.has(claim):
					penalty = 9.0
				var d := Vector2(dx, dy).length() + penalty
				if d < best_d:
					best_d = d
					best = n
		if best.x >= 0 and best_d <= r + 1.5:
			break
	if best.x >= 0:
		for k in ore_claims.keys():
			if ore_claims[k] == harv.uid:
				ore_claims.erase(k)
		ore_claims[best] = harv.uid
	return best

func find_refinery_for(harv):
	var best = null
	var best_d := INF
	for b in buildings:
		if b.dead or b.pid != harv.pid or not b.completed or not b.def.has("dock"):
			continue
		var d: float = b.pos.distance_to(harv.pos)
		if b.dock_busy_uid != 0 and b.dock_busy_uid != harv.uid:
			d += 400.0
		if d < best_d:
			best_d = d
			best = b
	return best

# ---------------------------------------------------------------- construction & production

func cost_of(pid: int, t: String) -> int:
	var is_struct := Data.is_building(t)
	if cheats.flag(pid, "free_build" if is_struct else "free_units"):
		return 0
	return int(Data.def(t).get("cost", 0))

## Returns "" when the player may build `t`, otherwise a human-readable reason.
func availability(pid: int, t: String) -> String:
	var p = players[pid]
	var d := Data.def(t)
	if d.is_empty():
		return "Unknown item."
	if not d.get("factions", []).has(p.faction):
		return "Not available to your faction."
	if not cheats.flag(pid, "no_prereq"):
		var miss: Array = p.missing_tech(d.get("prereq", []))
		if miss.size() > 0:
			var names := []
			for tag in miss:
				var bt := Data.building_for_tag(p.faction, tag)
				names.append(Data.def(bt).get("name", tag) if bt != "" else tag)
			return "Requires: " + ", ".join(names)
	if producer_for(pid, d.get("category", "")) == null:
		return "No production facility."
	if d.has("build_limit") and count_owned(pid, t) >= int(d.build_limit):
		return "Limit reached (%d at a time)." % int(d.build_limit)
	return ""

## Units of a type a player owns plus those queued.
func count_owned(pid: int, t: String) -> int:
	var n := 0
	for u in units:
		if u.pid == pid and not u.dead and u.type == t:
			n += 1
	for b in buildings:
		if b.pid == pid and not b.dead:
			for cat in b.queues:
				for it in b.queues[cat]:
					if it.type == t:
						n += 1
	return n

func producer_for(pid: int, cat: String):
	var p = players[pid]
	if p.primary.has(cat):
		var b = entities.get(int(p.primary[cat]))
		if b != null and not b.dead and b.completed:
			return b
	for b in buildings:
		if b.pid == pid and not b.dead and b.completed and b.produces(cat):
			p.primary[cat] = b.uid
			return b
	return null

func queue_item(pid: int, t: String) -> String:
	var reason := availability(pid, t)
	if reason != "":
		return reason
	var cat: String = Data.def(t).get("category", "")
	var b = producer_for(pid, cat)
	var r: String = b.enqueue(cat, t)
	if r == "" and pid == human_pid:
		play_sound("click", Vector2.INF)
	return r

func can_place(pid: int, t: String, c: Vector2i, ignore_radius: bool = false) -> String:
	var d := Data.def(t)
	if d.is_empty() or not Data.is_building(t):
		return "Not a structure."
	var fp: Array = d.get("footprint", ["x"])
	var on_water: bool = d.get("placement", "") == "water"
	for y in fp.size():
		var row := String(fp[y])
		for x in row.length():
			var cc := c + Vector2i(x, y)
			if not map.in_bounds(cc):
				return "Outside the map."
			if on_water:
				if map.terrain_id(cc) != "water" or map.occupied[map.idx(cc)] != 0:
					return "Must be built on open water."
				continue
			if row[x] == "x":
				if not map.buildable(cc):
					return "Blocked terrain or structure."
			elif not map.passable(cc, "track"):
				return "Dock area blocked."
			for u in unit_hash.query(MapGrid.cell_center(cc), T * 0.6):
				if u.dead or u.is_air_unit:
					continue
				if u.pid != pid and u.cell() == cc:
					return "Enemy units in the way."
	if ignore_radius or cheats.flag(pid, "build_anywhere"):
		return ""
	var size := Vector2i(String(fp[0]).length(), fp.size())
	var br := int(d.get("build_radius", 2))
	var rect := Rect2i(c - Vector2i(br, br), size + Vector2i(br * 2, br * 2))
	for b in buildings:
		if b.pid == pid and not b.dead and rect.intersects(Rect2i(b.cell0, b.size)):
			return ""
	return "Too far from your base."

func place_structure(pid: int, cat: String, c: Vector2i) -> String:
	var b = producer_for(pid, cat)
	if b == null:
		return "No construction yard."
	var it = b.ready_item(cat)
	if it == null:
		return "Nothing ready to place."
	var reason := can_place(pid, it.type, c)
	if reason != "":
		return reason
	b.queues[cat].remove_at(0)
	create_building(pid, it.type, c, false)
	return ""

func spawn_from_factory(b, t: String) -> bool:
	var d := Data.def(t)
	var mc: String = d.get("move", "foot")
	if mc == "air" and d.get("jetpack", false):
		mc = "foot"
	elif mc == "air":
		var au := spawn_unit(b.pid, t, b.pos)
		if au == null:
			return false
		var r := reserve_pad(au, b)
		if not r.is_empty():
			au.pos = pad_position(b, au.pad_index)
			au.air_state = "landed"
			au.altitude_now = 0.0
			au.facing = PI * 0.25
		au.position = au.pos
		au.reset_physics_interpolation()
		if b.rally != Vector2.INF:
			au.cmd_move(b.rally)
		notify(b.pid, "%s ready." % d.name, "unit")
		play_sound("unit_ready", au.pos)
		for ai in ais:
			if ai.player.id == b.pid:
				ai.on_unit_built(au)
		return true
	var ex: Vector2i = b.exit_cell()
	var c := map.nearest_passable(ex, mc, 5)
	if c.x < 0:
		return false
	var u := spawn_unit(b.pid, t, MapGrid.cell_center(c) + Vector2(randf_range(-4, 4), randf_range(-4, 4)))
	if u == null:
		return false
	u.facing = PI * 0.5
	u.turret_facing = PI * 0.5
	if b.rally != Vector2.INF and not u.is_harvester:
		u.cmd_move(b.rally)
	elif not u.is_harvester:
		u.cmd_move(MapGrid.cell_center(c) + Vector2(randf_range(-20, 20), T * 1.5))
	notify(b.pid, "%s ready." % d.name, "unit")
	play_sound("unit_ready", u.pos)
	for ai in ais:
		if ai.player.id == b.pid:
			ai.on_unit_built(u)
	return true

func try_deploy(u) -> bool:
	var t: String = u.def.deploys_to
	var c: Vector2i = u.cell() - Vector2i(1, 1)
	var old_pos: Vector2 = u.pos
	units.erase(u)
	unit_hash.rebuild(units)
	var reason := can_place(u.pid, t, c, true)
	units.append(u)
	if reason != "":
		notify(u.pid, "Cannot deploy here: " + reason, "warn")
		return false
	var pid: int = u.pid
	u.dead = true
	remove_entity(u)
	create_building(pid, t, c, false)
	unit_hash.rebuild(units)
	return true

func sell_building(b) -> void:
	if b.dead or not b.completed:
		return
	var refund := int(round(float(b.def.get("cost", 0)) * 0.5 * b.hp_ratio()))
	players[b.pid].add_cash(refund)
	notify(b.pid, "Sold %s for %d credits." % [b.def.name, refund], "build")
	for cat in b.queues:
		while b.queues[cat].size() > 0:
			b.cancel_item(cat, 0)
	b.dead = true
	spawn_effect("explosion_small", b.pos)
	var pid: int = b.pid
	remove_entity(b)
	players[pid].recompute(buildings)
	for cat in players[pid].primary.keys():
		if not entities.has(int(players[pid].primary[cat])):
			players[pid].primary.erase(cat)

# ---------------------------------------------------------------- commands (used by player controller and AI)

func formation_slots(center: Vector2, n: int, mc: String) -> Array:
	var out := []
	var c0 := map.nearest_passable(MapGrid.to_cell(center), mc, 10)
	if c0.x < 0:
		c0 = MapGrid.to_cell(center)
	var seen := {c0: true}
	var frontier := [c0]
	while out.size() < n and frontier.size() > 0:
		var c: Vector2i = frontier.pop_front()
		if map.passable(c, mc):
			out.append(c)
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			var nn: Vector2i = c + o
			if not seen.has(nn) and map.in_bounds(nn) and nn.distance_to(c0) < 12:
				seen[nn] = true
				frontier.append(nn)
	return out

func command_group(list: Array, kind: String, p: Vector2, tgt = null) -> void:
	var movers := []
	for u in list:
		if is_instance_valid(u) and not u.dead and u.is_unit():
			movers.append(u)
	if movers.is_empty():
		return
	if kind == "attack" and tgt != null:
		for u in movers:
			if u.can_attack():
				u.cmd_attack(tgt)
			else:
				u.cmd_move(tgt.pos)
		return
	# Aircraft fly directly with small offsets; on attack-move they strike the nearest enemy there.
	var air := movers.filter(func(u): return u.is_air_unit)
	for i in air.size():
		var u = air[i]
		var off := Vector2(cos(i * 2.4), sin(i * 2.4)) * (18.0 * sqrt(i))
		if kind == "attack_move" and u.can_attack():
			var t = _air_strike_target(u, p)
			if t != null:
				u.cmd_attack(t)
				continue
		if kind == "patrol":
			u.cmd_patrol(p + off)
		else:
			u.cmd_move(p + off)
	movers = movers.filter(func(u): return not u.is_air_unit)
	# Spread destinations so units do not fight over one cell.
	var by_class := {}
	for u in movers:
		if not by_class.has(u.move_class):
			by_class[u.move_class] = []
		by_class[u.move_class].append(u)
	for mc in by_class:
		var group: Array = by_class[mc]
		var inf = mc == "foot"
		var slots := formation_slots(p, int(ceil(group.size() / (3.0 if inf else 1.0))), mc)
		group.sort_custom(func(a, b): return a.pos.distance_squared_to(p) < b.pos.distance_squared_to(p))
		for i in group.size():
			var u = group[i]
			var dest := p
			if slots.size() > 0:
				var si: int = (i / 3 if inf else i) % slots.size()
				dest = MapGrid.cell_center(slots[si])
				if inf:
					dest += [Vector2(-8, -6), Vector2(8, -6), Vector2(0, 8)][i % 3]
			match kind:
				"move":
					if u.is_harvester and map.ore[map.idx(MapGrid.to_cell(p))] > 0:
						u.cmd_harvest(MapGrid.to_cell(p))
					else:
						u.cmd_move(dest)
				"attack_move":
					u.cmd_attack_move(dest)
				"patrol":
					u.cmd_patrol(dest)

func _air_strike_target(u, p: Vector2):
	var best = null
	var best_d := INF
	for e in entities_near(p, T * 8.0):
		if e.dead or not u.is_enemy(e) or is_hidden_from(e, u.pid):
			continue
		var ok := false
		for w in u.weapons:
			if Combat.can_target(w.def, e):
				ok = true
		if not ok:
			continue
		var d: float = e.pos.distance_to(p)
		if d < best_d:
			best_d = d
			best = e
	return best

# ---------------------------------------------------------------- aircraft pads, submarines, engineers, repair

func has_airfield(pid: int) -> bool:
	for b in buildings:
		if b.pid == pid and not b.dead and b.completed and b.def.has("pads"):
			return true
	return false

func pad_position(b, i: int) -> Vector2:
	var pads: Array = b.def.get("pads", [[1.5, 1.5]])
	var pp: Array = pads[clampi(i, 0, pads.size() - 1)]
	return (Vector2(b.cell0) + Vector2(pp[0], pp[1])) * T

## Reserves a free landing pad (optionally at a given airfield). Returns {} when none is free.
func reserve_pad(u, prefer = null) -> Dictionary:
	release_pad(u)
	var cands := []
	if prefer != null:
		cands.append(prefer)
	for b in buildings:
		if b.pid == u.pid and not b.dead and b.completed and b.def.has("pads") and b != prefer:
			cands.append(b)
	cands.sort_custom(func(a, c): return (a == prefer) or (c != prefer and a.pos.distance_squared_to(u.pos) < c.pos.distance_squared_to(u.pos)))
	for b in cands:
		for i in b.pad_uids.size():
			var occ: int = b.pad_uids[i]
			if occ == 0 or not entities.has(occ):
				b.pad_uids[i] = u.uid
				u.pad_uid = b.uid
				u.pad_index = i
				return {"b": b, "i": i}
	return {}

func release_pad(u) -> void:
	var b = entities.get(u.pad_uid)
	if b != null and b.is_building() and u.pad_index >= 0 and u.pad_index < b.pad_uids.size() and b.pad_uids[u.pad_index] == u.uid:
		b.pad_uids[u.pad_index] = 0
	u.pad_uid = 0
	u.pad_index = -1

## True when a submerged submarine cannot be seen by the viewer.
func is_hidden_from(e, viewer_pid: int) -> bool:
	if not e.is_unit() or not e.submarine or e.pid == viewer_pid or viewer_pid < 0:
		return false
	if not e.submerged():
		return false
	return not sub_detected.get(viewer_pid, {}).has(e.uid)

func _update_sub_detection() -> void:
	sub_detected.clear()
	var subs := units.filter(func(u): return u.submarine and not u.dead)
	if subs.is_empty():
		return
	var detectors := []
	for u in units:
		if not u.dead and u.detector_px > 0.0:
			detectors.append([u.pid, u.pos, u.detector_px])
	for b in buildings:
		if not b.dead and b.completed and b.def.has("detector"):
			detectors.append([b.pid, b.pos, float(b.def.detector) * T])
	for sub in subs:
		for d in detectors:
			if are_enemies(d[0], sub.pid) and sub.pos.distance_to(d[1]) <= d[2]:
				if not sub_detected.has(d[0]):
					sub_detected[d[0]] = {}
				sub_detected[d[0]][sub.uid] = true

func engineer_use(eng, b) -> void:
	if eng.dead or b.dead:
		return
	if are_enemies(eng.pid, b.pid):
		capture_building(b, eng.pid)
	elif b.pid == eng.pid:
		b.hp = b.max_hp
		notify(eng.pid, "%s repaired by engineer." % b.def.name, "build")
	eng.dead = true
	remove_entity(eng)

func capture_building(b, new_pid: int) -> void:
	var old_pid: int = b.pid
	for cat in b.queues:
		while b.queues[cat].size() > 0:
			b.cancel_item(cat, 0)
	for i in b.pad_uids.size():
		b.pad_uids[i] = 0
	b.pid = new_pid
	b.rally = Vector2.INF
	b.repairing = false
	b.target = null
	for p in [players[old_pid], players[new_pid]]:
		p.recompute(buildings)
		for cat in p.primary.keys():
			var pb = entities.get(int(p.primary[cat]))
			if pb == null or pb.pid != p.id:
				p.primary.erase(cat)
	notify(new_pid, "%s captured." % b.def.name, "build")
	notify(old_pid, "%s has been captured by the enemy!" % b.def.name, "alert")
	b.queue_redraw()

func _service_repairs() -> void:
	for b in buildings:
		if b.dead or not b.completed or not b.def.has("repair_rate") or not b.powered():
			continue
		var r: Rect2 = b.rect_px()
		for u in unit_hash.query(r.get_center(), r.size.x * 0.75):
			if u.dead or u.pid != b.pid or u.is_air_unit or u.hp >= u.max_hp or not r.has_point(u.pos):
				continue
			var amount: float = minf(u.max_hp * float(b.def.repair_rate) * DT * 4.0, u.max_hp - u.hp)
			var cost := int(ceil(amount / u.max_hp * float(u.def.get("cost", 0)) * 0.4))
			if players[b.pid].spend(cost, "units"):
				u.heal(amount)
				b.unload_anim = 0.2

# ---------------------------------------------------------------- simulation loop

const STEP_BUDGET_USEC := 9000

## The simulation runs at a fixed 30 ticks per second of game time. Ticks are spread over the
## rendered frames (instead of bursts on physics frames) and capped by a time budget, so a fast
## game speed stays smooth: if a PC cannot keep up, the game slows slightly instead of stuttering.
func _process(delta: float) -> void:
	if paused or over or headless:
		return
	accumulator = minf(accumulator + delta * PHYS_HZ * speed, 4.0)
	var t0 := Time.get_ticks_usec()
	while accumulator >= 1.0:
		accumulator -= 1.0
		step()
		if Time.get_ticks_usec() - t0 > STEP_BUDGET_USEC:
			accumulator = minf(accumulator, 1.0)
			break

func set_speed(v: float) -> void:
	speed = clampf(v, 0.25, 8.0)

var profile := {}   # section -> accumulated microseconds (filled when profiling is on)
var profiling := false

func _prof(section: String, t0: int) -> int:
	var t1 := Time.get_ticks_usec()
	profile[section] = int(profile.get(section, 0)) + (t1 - t0)
	return t1

func step() -> void:
	tick_count += 1
	sim_time += DT
	var t := Time.get_ticks_usec() if profiling else 0
	unit_hash.rebuild(units)
	if profiling: t = _prof("hash", t)
	if not cheats.flag(-1, "ai_disabled"):
		for ai in ais:
			if not ai.player.defeated:
				ai.tick(DT)
	if profiling: t = _prof("ai", t)
	for b in buildings.duplicate():
		if not b.dead:
			b.tick(DT)
	if profiling: t = _prof("buildings", t)
	_process_paths()
	if profiling: t = _prof("paths", t)
	for u in units.duplicate():
		if not u.dead:
			u.tick(DT)
			if cheats.flag(u.pid, "auto_repair_units") and u.hp < u.max_hp:
				u.heal(u.max_hp * 0.05 * DT)
	if profiling: t = _prof("units", t)
	if tick_count % 2 == 0:
		_separate()
	if profiling: t = _prof("separate", t)
	for pr in projectiles.duplicate():
		pr.tick(DT)
		if pr.dead:
			projectiles.erase(pr)
			pr.queue_free()
	specials.tick(DT)
	if profiling: t = _prof("projectiles", t)
	if tick_count % 4 == 0:
		_service_repairs()
	if tick_count % 8 == 0:
		_update_sub_detection()
		update_fog()
	if profiling: t = _prof("fog", t)
	if tick_count % 30 == 0:
		_check_victory()

func _process_paths() -> void:
	var budget := PATH_BUDGET
	var n := units.size()
	if n == 0:
		return
	for k in n:
		var u = units[(_path_cursor + k) % n]
		if u.need_path and not u.dead:
			u.compute_path()
			budget -= 1
			if budget <= 0:
				_path_cursor = (_path_cursor + k + 1) % n
				return
	_path_cursor = 0

func _separate() -> void:
	for u in units:
		if u.dead or u.harv_state == "unloading" or u.is_air_unit or u.deployed:
			continue
		for o in unit_hash.query(u.pos, u.radius * 2.0):
			if o == u or o.dead or o.uid < u.uid or o.harv_state == "unloading" or o.is_air_unit or o.deployed:
				continue
			var d: Vector2 = u.pos - o.pos
			var dist := d.length()
			var min_d: float = (u.radius + o.radius) * 0.75
			if dist >= min_d:
				continue
			if dist < 0.01:
				d = Vector2.RIGHT.rotated(randf() * TAU)
				dist = 1.0
			var push := (min_d - dist)
			var dir := d / dist
			# Moving units shove idle ones more than they are shoved.
			var wu := 0.3 if u.moving else 0.7
			var wo := 0.3 if o.moving else 0.7
			_try_push(u, dir * push * wu * 2.0)
			_try_push(o, -dir * push * wo * 2.0)

func _try_push(u, v: Vector2) -> void:
	var np: Vector2 = u.pos + v
	if map.passable(MapGrid.to_cell(np), u.move_class):
		u.pos = np

# ---------------------------------------------------------------- fog of war

var _span_cache := {}
## Half-width of each row of a sight circle (same shape as _circle).
func _circle_spans(r: int) -> PackedInt32Array:
	if _span_cache.has(r):
		return _span_cache[r]
	var out := PackedInt32Array()
	for dy in range(-r, r + 1):
		var half := 0
		while (half + 1) * (half + 1) + dy * dy <= r * r + r:
			half += 1
		out.append(half)
	_span_cache[r] = out
	return out

func _circle(r: int) -> Array:
	if _circle_cache.has(r):
		return _circle_cache[r]
	var out := []
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r + r:
				out.append(Vector2i(dx, dy))
	_circle_cache[r] = out
	return out

func fog_enabled() -> bool:
	return bool(settings.fog) and not cheats.flag(-1, "no_fog")

var _vis_lists := {}            # pid -> PackedInt32Array of cells marked visible at the last update
var _fog_data := PackedByteArray()
var _fog_reveal_last := -1

## Fog of war, updated incrementally: only cells that were visible last time are dimmed
## and only cells around units and structures are lit, instead of sweeping the whole map.
func update_fog(force_full: bool = false) -> void:
	var w := map.w
	var h := map.h
	var human_prev := PackedInt32Array()
	var human_now := PackedInt32Array()
	var full_human := force_full
	for p in players:
		var vis: PackedByteArray = p.vis
		var prev: PackedInt32Array = _vis_lists.get(p.id, PackedInt32Array())
		if force_full or not _vis_lists.has(p.id):
			for i in vis.size():
				if vis[i] == 2:
					vis[i] = 1
			if p.id == human_pid:
				full_human = true
		else:
			for i in prev:
				vis[i] = 1
		var now := PackedInt32Array()
		for list in [units, buildings]:
			for e in list:
				if e.dead or e.pid != p.id:
					continue
				var c: Vector2i = e.cell()
				var r: int = e.sight
				if e.is_building() and e.def.get("provides", []).has("radar") and not e.powered():
					r = 3
				var spans: PackedInt32Array = _circle_spans(r)
				for dy in range(-r, r + 1):
					var y: int = c.y + dy
					if y < 0 or y >= h:
						continue
					var half: int = spans[dy + r]
					var row: int = y * w
					for x in range(maxi(c.x - half, 0), mini(c.x + half, w - 1) + 1):
						var i: int = row + x
						if vis[i] != 2:
							vis[i] = 2
							now.append(i)
		p.vis = vis
		_vis_lists[p.id] = now
		if p.id == human_pid:
			human_prev = prev
			human_now = now
	_apply_human_visibility()
	for c in map.ore_dirty_cells:
		if view3d != null:
			view3d.terrain.mark_ore_dirty(c)
		elif terrain_layer.tile_set != null:
			_refresh_ore_cell(c)
	map.ore_dirty_cells.clear()
	if headless or fog_image == null:
		return
	var reveal := 1 if (not fog_enabled() or cheats.flag(-1, "reveal_map")) else 0
	var hv: PackedByteArray = players[human_pid].vis
	if _fog_data.size() != hv.size() or reveal != _fog_reveal_last:
		full_human = true
	_fog_reveal_last = reveal
	if reveal == 1:
		if not full_human:
			return
		_fog_data.resize(hv.size())
		_fog_data.fill(0)
	elif full_human:
		_fog_data.resize(hv.size())
		for i in hv.size():
			var v := hv[i]
			_fog_data[i] = 255 if v == 0 else (130 if v == 1 else 0)
	else:
		for i in human_prev:
			_fog_data[i] = 130
		for i in human_now:
			_fog_data[i] = 0
	fog_image.set_data(map.w, map.h, false, Image.FORMAT_L8, _fog_data)
	fog_texture.update(fog_image)

func cell_visible_to_human(c: Vector2i) -> bool:
	if not fog_enabled() or cheats.flag(-1, "reveal_map"):
		return true
	if not map.in_bounds(c):
		return false
	return players[human_pid].vis[map.idx(c)] == 2

func _apply_human_visibility() -> void:
	var reveal_all := not fog_enabled() or cheats.flag(-1, "reveal_map") or cheats.flag(-1, "reveal_enemies")
	var hv: PackedByteArray = players[human_pid].vis
	for u in units:
		if u.pid == human_pid:
			u.visible = true
			continue
		var c: Vector2i = u.cell()
		u.visible = (reveal_all or (map.in_bounds(c) and hv[map.idx(c)] == 2)) and not is_hidden_from(u, human_pid)
	for b in buildings:
		if b.pid == human_pid:
			b.visible = true
			b.seen_by_human = true
			continue
		if not b.seen_by_human:
			for c in b.all_cells():
				if hv[map.idx(c)] == 2:
					b.seen_by_human = true
					break
		b.visible = reveal_all or b.seen_by_human

# ---------------------------------------------------------------- victory

func _player_alive(p) -> bool:
	for b in buildings:
		if b.pid == p.id and not b.dead:
			return true
	for u in units:
		if u.pid == p.id and not u.dead:
			if settings.victory == "annihilation" or u.def.has("deploys_to"):
				return true
	return false

func _check_victory() -> void:
	if over or settings.victory == "none":
		return
	for p in players:
		if not p.defeated and not _player_alive(p):
			p.defeated = true
			if p.id != human_pid:
				notify(human_pid, "%s has been defeated." % p.name, "alert")
				for u in units.duplicate():
					if u.pid == p.id and not u.dead:
						u.take_damage(u.hp + 1, null)
	if players[human_pid].defeated:
		force_end(false)
		return
	var any_enemy := false
	for p in players:
		if are_enemies(human_pid, p.id) and not p.defeated:
			any_enemy = true
	if not any_enemy and players.size() > 1:
		force_end(true)

func force_end(victory: bool) -> void:
	if over:
		return
	over = true
	won = victory
	objectives[0].done = victory
	notify(human_pid, "MISSION ACCOMPLISHED" if victory else "MISSION FAILED", "alert")
	game_over.emit(victory)

# ---------------------------------------------------------------- messages, effects, audio

func notify(pid: int, text: String, kind: String = "info") -> void:
	if pid == human_pid:
		message.emit(text, kind)

func spawn_effect(kind: String, p: Vector2, opts: Dictionary = {}) -> void:
	if headless:
		return
	if view3d != null:
		view3d.spawn_fx(kind, p, opts)
		return
	if fx_layer.get_child_count() > 450 or not fx_layer.visible:
		return
	var fx := Effect.new()
	fx.setup(kind, p, opts)
	fx_layer.add_child(fx)

func spawn_projectile(shooter, w: Dictionary, tgt, start: Vector2, target_pos: Vector2) -> void:
	var pr := Projectile.new()
	pr.setup(self, shooter, w, tgt, start, target_pos)
	projectiles.append(pr)
	fx_layer.add_child(pr)

func play_sound(name: String, p: Vector2) -> void:
	if audio != null and name != "":
		audio.play(name, p)

# ---------------------------------------------------------------- cheats helpers

func cheat_spawn(t: String, count: int, owner: int, at: Vector2i) -> Dictionary:
	var origin := at
	if origin.x < 0:
		origin = cursor_cell if map.in_bounds(cursor_cell) else _base_center(owner)
	if not map.in_bounds(origin):
		return {"ok": false, "msg": "Location %s is outside the map (%dx%d)." % [str(origin), map.w, map.h]}
	var made := 0
	if Data.is_building(t):
		for i in count:
			var c := _find_build_spot(owner, t, origin, 14)
			if c.x < 0:
				break
			create_building(owner, t, c, true)
			made += 1
	else:
		var mc: String = Data.units[t].move
		var slots := formation_slots(MapGrid.cell_center(origin), count, mc)
		for i in count:
			if units.size() >= max_units():
				break
			var c: Vector2i = slots[i % slots.size()] if slots.size() > 0 else map.nearest_passable(origin, mc, 10)
			if c.x < 0:
				break
			var u := spawn_unit(owner, t, MapGrid.cell_center(c) + Vector2(randf_range(-6, 6), randf_range(-6, 6)))
			if u != null:
				made += 1
	if made == 0:
		return {"ok": false, "msg": "No valid location to spawn %s near %s." % [t, str(origin)]}
	var extra := "" if made == count else " (only %d fit / unit limit)" % made
	return {"ok": true, "msg": "Spawned %d x %s for %s at %s%s." % [made, Data.def(t).name, players[owner].name, str(origin), extra]}

func _base_center(pid: int) -> Vector2i:
	for b in buildings:
		if b.pid == pid and not b.dead:
			return b.cell0
	for u in units:
		if u.pid == pid and not u.dead:
			return u.cell()
	return map.starts[pid % map.starts.size()]

func _find_build_spot(pid: int, t: String, origin: Vector2i, max_r: int) -> Vector2i:
	for r in range(0, max_r):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue
				var c := origin + Vector2i(dx, dy)
				if can_place(pid, t, c, true) == "":
					return c
	return Vector2i(-1, -1)

# ---------------------------------------------------------------- save / load

func to_save() -> Dictionary:
	var ents := []
	for b in buildings:
		if not b.dead:
			var d: Dictionary = b.to_dict()
			d["kind"] = "building"
			ents.append(d)
	for u in units:
		if not u.dead:
			var d: Dictionary = u.to_dict()
			d["kind"] = "unit"
			ents.append(d)
	var s := settings.duplicate(true)
	s.erase("map_data")
	return {
		"version": 1, "settings": s, "map": map.to_dict(), "players": players.map(func(p): return p.to_dict()),
		"entities": ents, "next_uid": next_uid, "tick": tick_count, "time": sim_time, "speed": speed,
		"cheats": cheats.to_dict(), "specials": specials.to_dict(), "ai": ais.map(func(a): return a.to_dict()), "over": over, "objectives": objectives,
	}

func load_save(d: Dictionary, is_headless: bool = false) -> void:
	_vis_lists.clear()
	headless = is_headless
	settings = default_settings()
	settings.merge(d.settings, true)
	cheats = Cheats.new(self)
	cheats.from_dict(d.get("cheats", {}))
	specials = Specials.new(self)
	specials.from_dict(d.get("specials", {}))
	map = MapGrid.new()
	map.from_dict(d.map)
	map.build_navigation()
	_build_layers()
	players.clear()
	ais.clear()
	for pd in d.players:
		var p := Player.new()
		p.game = self
		p.from_dict(pd)
		if p.vis.size() != map.w * map.h:
			p.vis.resize(map.w * map.h)
		players.append(p)
		if not p.is_human:
			ais.append(AIController.new(self, p))
	human_pid = 0
	for i in mini(ais.size(), d.get("ai", []).size()):
		ais[i].from_dict(d.ai[i])
	for ed in d.entities:
		if ed.kind == "building":
			var b := create_building(int(ed.pid), ed.type, Vector2i(int(ed.cell[0]), int(ed.cell[1])), false, int(ed.uid))
			b.apply_dict(ed)
		else:
			var u := spawn_unit(int(ed.pid), ed.type, Vector2(float(ed.x), float(ed.y)), int(ed.uid))
			if u != null:
				u.apply_dict(ed)
	for u in units:
		if u.target_uid != 0:
			u.target = entities.get(u.target_uid)
		if u.is_air_unit and u.pad_uid != 0:
			var pb = entities.get(u.pad_uid)
			if pb != null and pb.is_building() and u.pad_index >= 0 and u.pad_index < pb.pad_uids.size():
				pb.pad_uids[u.pad_index] = u.uid
			else:
				u.pad_uid = 0
				u.pad_index = -1
	next_uid = maxi(next_uid, int(d.next_uid))
	tick_count = int(d.tick)
	sim_time = float(d.time)
	speed = float(d.get("speed", 1.0))
	over = bool(d.get("over", false))
	objectives = d.get("objectives", [{"text": _victory_text(), "done": false, "optional": false}])
	for p in players:
		p.recompute(buildings)
	building_hash.rebuild(buildings)
	unit_hash.rebuild(units)
	update_fog(true)
