class_name MapGrid
extends RefCounted
## Tile grid: terrain, ore, building occupancy and per-movement-class A* navigation.

const MOVE_CLASSES := ["foot", "wheel", "track", "naval"]
const T := 32

var w: int = 0
var h: int = 0
var name: String = ""
var terrain := PackedByteArray()
var ore := PackedInt32Array()        # resource value stored in each cell
var ore_kind := PackedByteArray()    # 0 none, 1 ore, 2 gems
var occupied := PackedInt32Array()   # building uid occupying the cell, 0 if free
var starts: Array = []               # Array[Vector2i]
var astar := {}                      # move class -> AStarGrid2D
var _cost_cache := {}                # move class -> PackedFloat32Array per terrain index
var ore_dirty_cells: Dictionary = {} # cells whose ore graphic must be refreshed

func setup(width: int, height: int) -> void:
	w = width
	h = height
	var n := w * h
	terrain.resize(n)
	terrain.fill(Data.terrain_index.get("grass", 0))
	ore.resize(n)
	ore.fill(0)
	ore_kind.resize(n)
	ore_kind.fill(0)
	occupied.resize(n)
	occupied.fill(0)
	for mc in MOVE_CLASSES:
		var arr := PackedFloat32Array()
		arr.resize(Data.terrain_ids.size())
		for i in Data.terrain_ids.size():
			arr[i] = float(Data.terrain_def_by_index(i)["cost"].get(mc, 0))
		_cost_cache[mc] = arr

func idx(c: Vector2i) -> int:
	return c.y * w + c.x

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h

static func to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / T), floori(p.y / T))

static func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * T + T * 0.5, c.y * T + T * 0.5)

func terrain_id(c: Vector2i) -> String:
	return Data.terrain_ids[terrain[idx(c)]]

func terrain_def(c: Vector2i) -> Dictionary:
	return Data.terrain_def_by_index(terrain[idx(c)])

func move_cost(c: Vector2i, mc: String) -> float:
	if not in_bounds(c):
		return 0.0
	return _cost_cache[mc][terrain[idx(c)]]

func terrain_passable(c: Vector2i, mc: String) -> bool:
	return move_cost(c, mc) > 0.0

func passable(c: Vector2i, mc: String) -> bool:
	return in_bounds(c) and move_cost(c, mc) > 0.0 and occupied[idx(c)] == 0

func buildable(c: Vector2i) -> bool:
	return in_bounds(c) and bool(terrain_def(c).get("buildable", false)) and occupied[idx(c)] == 0 and ore[idx(c)] == 0

func set_terrain(c: Vector2i, id: String) -> void:
	terrain[idx(c)] = Data.terrain_index.get(id, 0)

func build_navigation() -> void:
	for mc in MOVE_CLASSES:
		var a := AStarGrid2D.new()
		a.region = Rect2i(0, 0, w, h)
		a.cell_size = Vector2(1, 1)
		a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		a.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		a.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		a.update()
		astar[mc] = a
		for y in h:
			for x in w:
				_refresh_nav_cell(mc, Vector2i(x, y))

func _refresh_nav_cell(mc: String, c: Vector2i) -> void:
	var a: AStarGrid2D = astar[mc]
	var cost := move_cost(c, mc)
	var solid := cost <= 0.0 or occupied[idx(c)] != 0
	a.set_point_solid(c, solid)
	if not solid:
		a.set_point_weight_scale(c, cost)

func set_occupied(c: Vector2i, uid: int) -> void:
	if not in_bounds(c):
		return
	occupied[idx(c)] = uid
	for mc in MOVE_CLASSES:
		if astar.has(mc):
			_refresh_nav_cell(mc, c)

## Nearest passable cell to `c` for a movement class (spiral search).
func nearest_passable(c: Vector2i, mc: String, max_r: int = 12) -> Vector2i:
	if passable(c, mc):
		return c
	for r in range(1, max_r + 1):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if passable(n, mc):
					var d := Vector2(dx, dy).length_squared()
					if d < best_d:
						best_d = d
						best = n
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)

## Returns a list of cells from start to goal (inclusive). Uses partial paths when goal is unreachable.
func find_path(from: Vector2i, to: Vector2i, mc: String) -> Array:
	if not astar.has(mc):
		return []
	var a: AStarGrid2D = astar[mc]
	var start := from
	if not passable(start, mc):
		start = nearest_passable(from, mc, 4)
		if start.x < 0:
			return []
	var goal := to
	if not in_bounds(goal):
		goal = Vector2i(clampi(to.x, 0, w - 1), clampi(to.y, 0, h - 1))
	if not passable(goal, mc):
		var g2 := nearest_passable(goal, mc, 6)
		if g2.x >= 0:
			goal = g2
	var ids: Array[Vector2i] = a.get_id_path(start, goal, true)
	var out: Array = []
	for p in ids:
		out.append(p)
	if out.is_empty() and start == goal:
		out.append(start)
	return out

func ore_stage(c: Vector2i) -> int:
	var v := ore[idx(c)]
	if v <= 0:
		return 0
	var kind := ore_kind[idx(c)]
	var maxv: float = float(Data.resources["gems" if kind == 2 else "ore"]["cell_max"])
	return clampi(int(ceil(v / maxv * 4.0)), 1, 4)

func take_ore(c: Vector2i, amount: int, deplete: bool) -> Dictionary:
	var i := idx(c)
	var have := ore[i]
	var kind := ore_kind[i]
	if have <= 0:
		return {"amount": 0, "kind": 0}
	var taken := mini(amount, have)
	if deplete:
		var before := ore_stage(c)
		ore[i] = have - taken
		if ore[i] <= 0:
			ore[i] = 0
			ore_kind[i] = 0
		if ore_stage(c) != before:
			ore_dirty_cells[c] = true
	return {"amount": taken, "kind": kind}

func total_ore() -> int:
	var t := 0
	for v in ore:
		t += v
	return t

func to_dict() -> Dictionary:
	var starts_out := []
	for s in starts:
		starts_out.append([s.x, s.y])
	return {
		"w": w, "h": h, "name": name,
		"terrain": Marshalls.raw_to_base64(terrain),
		"ore": Marshalls.raw_to_base64(ore.to_byte_array()),
		"ore_kind": Marshalls.raw_to_base64(ore_kind),
		"starts": starts_out,
	}

func from_dict(d: Dictionary) -> void:
	setup(int(d.w), int(d.h))
	name = d.get("name", "")
	terrain = Marshalls.base64_to_raw(d.terrain)
	ore = Marshalls.base64_to_raw(d.ore).to_int32_array()
	ore_kind = Marshalls.base64_to_raw(d.ore_kind)
	starts.clear()
	for s in d.get("starts", []):
		starts.append(Vector2i(int(s[0]), int(s[1])))
