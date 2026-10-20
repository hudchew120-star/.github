class_name MapGen
extends RefCounted
## Procedural skirmish map generator and loader for the text-based map format (see docs/DEVELOPER_GUIDE.md).

const SIZES := {"small": 64, "medium": 96, "large": 128, "xlarge": 176}
const LEGEND := {".": "grass", "d": "dirt", "s": "sand", "w": "water", "~": "shore", "=": "road", "r": "rock", "#": "cliff", "b": "bridge", "f": "forest"}

## opts: size (key of SIZES or int), players (2-4), seed, resources ("low","normal","high"),
## water ("none", "lakes", "coastal": a sea ring along the map edges plus a central lake, so every base has a shore for a naval yard)
static func generate(opts: Dictionary) -> MapGrid:
	var size_v = opts.get("size", "medium")
	var n: int = SIZES.get(size_v, 96) if typeof(size_v) == TYPE_STRING else int(size_v)
	var players: int = clampi(int(opts.get("players", 2)), 2, 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(opts.get("seed", 1))
	var m := MapGrid.new()
	m.setup(n, n)
	m.name = "Generated %s (%d)" % [str(size_v), int(opts.get("seed", 1))]

	var elev := FastNoiseLite.new()
	elev.seed = rng.randi()
	elev.frequency = 0.045
	elev.fractal_octaves = 4
	var moist := FastNoiseLite.new()
	moist.seed = rng.randi()
	moist.frequency = 0.07
	var water_mode: String = str(opts.get("water", "lakes"))
	var shore_noise := FastNoiseLite.new()
	shore_noise.seed = rng.randi()
	shore_noise.frequency = 0.09
	for y in n:
		for x in n:
			var e := elev.get_noise_2d(x, y)
			if water_mode == "none":
				e = maxf(e, -0.24)
			elif water_mode == "coastal":
				# Sea along the edges: sink elevation near the border, wobbled by noise.
				var edge := float(mini(mini(x, y), mini(n - 1 - x, n - 1 - y)))
				var band := float(n) * 0.075 + shore_noise.get_noise_2d(x, y) * float(n) * 0.04
				if edge < band:
					e = minf(e, -0.4 - (band - edge) * 0.02)
				elif edge < band + 3.0:
					e = minf(e, -0.33 + (edge - band) * 0.03)
				else:
					e = maxf(e, -0.24) if edge < band + 6.0 else e
				# Central lake.
				var dc := Vector2(x - n / 2, y - n / 2).length()
				var lake_r := float(n) * 0.09 + shore_noise.get_noise_2d(x * 2, y * 2) * 3.0
				if dc < lake_r:
					e = minf(e, -0.42)
			var mo := moist.get_noise_2d(x, y)
			var id := "grass"
			if e < -0.38:
				id = "water"
			elif e < -0.31:
				id = "shore"
			elif e < -0.25:
				id = "sand"
			elif e > 0.47:
				id = "cliff"
			elif e > 0.36:
				id = "rock"
			elif mo > 0.38 and rng.randf() < 0.75:
				id = "forest"
			elif mo < -0.32:
				id = "dirt"
			m.set_terrain(Vector2i(x, y), id)

	# Start positions in corners (inset), ordered so player 1 and 2 are opposite.
	var inset := maxi(8, n / 8)
	var corners := [Vector2i(inset, inset), Vector2i(n - 1 - inset, n - 1 - inset), Vector2i(n - 1 - inset, inset), Vector2i(inset, n - 1 - inset)]
	m.starts = corners.slice(0, players)
	var center := Vector2i(n / 2, n / 2)

	# Clear start areas.
	for s in m.starts:
		_paint_disc(m, s, 9, "grass", true)
		_paint_disc(m, s, 3, "dirt", false)

	# Roads from every start to the centre and around (guarantees land connectivity).
	for s in m.starts:
		_carve_road(m, s, center, rng)
	for i in m.starts.size():
		_carve_road(m, m.starts[i], m.starts[(i + 1) % m.starts.size()], rng)

	# Ore fields: one rich field near every start, plus contested fields.
	var richness: float = {"low": 0.6, "normal": 1.0, "high": 1.6}.get(opts.get("resources", "normal"), 1.0)
	for s in m.starts:
		var dir := Vector2(center - s).normalized()
		var p: Vector2i = s + Vector2i((dir * 10.0).round()) + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
		_place_ore_field(m, p, 4, richness, 1, rng)
	var contested := 2 + players
	for i in contested:
		var ang := TAU * float(i) / float(contested) + rng.randf() * 0.4
		var dist := n * rng.randf_range(0.12, 0.3)
		var p := center + Vector2i(int(cos(ang) * dist), int(sin(ang) * dist))
		_place_ore_field(m, p, 3, richness, 2 if i == 0 else 1, rng)
	m.build_navigation()
	return m

static func _paint_disc(m: MapGrid, c: Vector2i, r: int, id: String, keep_water: bool) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var p := c + Vector2i(dx, dy)
			if not m.in_bounds(p) or dx * dx + dy * dy > r * r:
				continue
			var cur := m.terrain_id(p)
			if keep_water and cur == "water" and dx * dx + dy * dy > (r - 3) * (r - 3):
				continue
			m.set_terrain(p, id)

static func _carve_road(m: MapGrid, a: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> void:
	var p := Vector2(a)
	var target := Vector2(b)
	var wobble := rng.randf_range(-1.0, 1.0)
	var steps := int(p.distance_to(target) * 1.5) + 4
	for i in steps:
		var to := target - p
		if to.length() < 1.0:
			break
		var dir := to.normalized().rotated(sin(i * 0.15 + wobble) * 0.35)
		p += dir
		var c := Vector2i(p.round())
		for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var q: Vector2i = c + o
			if not m.in_bounds(q):
				continue
			var cur := m.terrain_id(q)
			if cur == "water":
				m.set_terrain(q, "bridge")
			elif cur != "bridge":
				m.set_terrain(q, "road")

static func _place_ore_field(m: MapGrid, c: Vector2i, r: int, richness: float, kind: int, rng: RandomNumberGenerator) -> void:
	var res_key := "gems" if kind == 2 else "ore"
	var maxv := int(Data.resources[res_key]["cell_max"])
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var p := c + Vector2i(dx, dy)
			if not m.in_bounds(p):
				continue
			var d := Vector2(dx, dy).length()
			if d > r + rng.randf_range(-0.8, 0.4):
				continue
			var tid := m.terrain_id(p)
			if tid == "water" or tid == "cliff" or tid == "bridge" or tid == "forest" or tid == "road":
				continue
			if tid == "rock":
				m.set_terrain(p, "dirt")
			var amt := int(maxv * richness * clampf(1.15 - d / (r + 1.0), 0.25, 1.0))
			amt = clampi(amt, 50, int(maxv * 1.6))
			m.ore[m.idx(p)] = amt
			m.ore_kind[m.idx(p)] = kind

## Load a hand-authored map JSON file (text rows + legend). Returns null on failure.
static func load_file(path: String) -> MapGrid:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return null
	return from_text_dict(d)

static func from_text_dict(d: Dictionary) -> MapGrid:
	var rows: Array = d.get("rows", [])
	if rows.is_empty():
		return null
	var legend: Dictionary = LEGEND.duplicate()
	legend.merge(d.get("legend", {}), true)
	var m := MapGrid.new()
	m.setup(String(rows[0]).length(), rows.size())
	m.name = d.get("name", "Custom map")
	for y in rows.size():
		var row := String(rows[y])
		for x in mini(row.length(), m.w):
			m.set_terrain(Vector2i(x, y), legend.get(row[x], "grass"))
	for o in d.get("ore", []):
		var rng := RandomNumberGenerator.new()
		rng.seed = int(o.get("x", 0)) * 977 + int(o.get("y", 0))
		_place_ore_field(m, Vector2i(int(o.x), int(o.y)), int(o.get("r", 3)), float(o.get("richness", 1.0)), 2 if o.get("kind", "ore") == "gems" else 1, rng)
	for oc in d.get("ore_cells", []):
		var c := Vector2i(int(oc[0]), int(oc[1]))
		if m.in_bounds(c):
			m.ore[m.idx(c)] = int(oc[2])
			m.ore_kind[m.idx(c)] = int(oc[3])
	for s in d.get("starts", []):
		m.starts.append(Vector2i(int(s[0]), int(s[1])))
	m.build_navigation()
	return m

## Export a map to the text format (used by the map editor).
static func to_text_dict(m: MapGrid) -> Dictionary:
	var inv := {}
	for k in LEGEND:
		inv[LEGEND[k]] = k
	var rows := []
	for y in m.h:
		var s := ""
		for x in m.w:
			s += inv.get(m.terrain_id(Vector2i(x, y)), ".")
		rows.append(s)
	var starts := []
	for s in m.starts:
		starts.append([s.x, s.y])
	var ore_cells := []
	for y in m.h:
		for x in m.w:
			var i := m.idx(Vector2i(x, y))
			if m.ore[i] > 0:
				ore_cells.append([x, y, m.ore[i], m.ore_kind[i]])
	return {"name": m.name, "rows": rows, "starts": starts, "ore_cells": ore_cells}
