extends RefCounted
## Every sprite sheet the baker produces (art resolution 2x: a map cell is 128x64 px).
## Directional sheets index frames as state * DIRS + direction; direction 0 faces +X
## (screen lower-right) and increases clockwise in world space, matching Unit.facing.

const M := preload("res://tools/art/hd_models.gd")
const B := preload("res://tools/art/hd_buildings.gd")
const DIRS := 32
const PXU := 90.509668      # pixels per world unit at 2x
const COS30 := 0.8660254

static func _rot(node: Node3D, dir: int, n: int = DIRS) -> Node3D:
	node.rotation.y = -TAU * dir / n
	return node

static func _wrap(n: Node3D) -> Node3D:
	var h := Node3D.new()
	h.add_child(n)
	return h

static func vehicle(name: String, builder: Callable, scale: float, states: int = 1) -> Array:
	var probe: Dictionary = builder.call(0)
	var fw := 192
	var fh := 160
	var piv: Vector3 = probe.pivot * scale
	var out := [{"name": name, "fw": fw, "fh": fh, "anchor": Vector2(96, 100), "count": DIRS * states, "scale": scale,
		"extra": {"pivot": [piv.x, piv.y, piv.z], "dirs": DIRS, "states": states},
		"build": func(i):
			var d: Dictionary = builder.call(i / DIRS)
			return _rot(_wrap(d.root), i % DIRS)}]
	if probe.turret != null:
		out.append({"name": name + "_turret", "fw": fw, "fh": fh, "anchor": Vector2(96, 100), "count": DIRS, "scale": scale, "shadow": false,
			"extra": {"dirs": DIRS},
			"build": func(i):
				var d: Dictionary = builder.call(0)
				return _rot(_wrap(d.turret), i)})
	return out

static func infantry(name: String, kind: String, faction: String) -> Array:
	# 9 frames x 8 directions: idle, walk 1-6, fire 1-2. Plus a 5-frame death sheet.
	return [{"name": name, "fw": 112, "fh": 112, "anchor": Vector2(56, 80), "count": 72, "scale": 1.45, "extra": {"dirs": 8, "frames": 9},
		"build": func(i):
			var fr: int = i / 8
			var pose := {}
			if fr >= 1 and fr <= 6:
				pose["walk"] = float(fr - 1) / 6.0
			elif fr >= 7:
				pose["fire"] = true
			return _rot(M.infantry(kind, faction, pose), (i % 8) * 4)},
		{"name": name + "_die", "fw": 112, "fh": 112, "anchor": Vector2(56, 80), "count": 5, "scale": 1.45, "extra": {"frames": 5},
		"build": func(i):
			return _rot(M.infantry(kind, faction, {"dead": float(i) / 4.0}), 12)}]

static func building_frame(sx: int, sz: int, h: float) -> Dictionary:
	var top := int(h * PXU * COS30) + 70
	var left := sz * 64 + 120
	return {"fw": (sx + sz) * 64 + 170, "fh": (sx + sz) * 32 + top + 50, "anchor": Vector2(left, top)}

static func building(sprite: String, faction: String, sx: int, sz: int) -> Array:
	var probe: Dictionary = B.build(sprite, faction)
	var h: float = probe.height
	var fr := building_frame(sx, sz, h)
	var cuts := [0.12, 0.3, 0.5, 0.7, 0.88]
	var smoke := []
	for sp in probe.get("smoke", []):
		smoke.append([sp.x, sp.y, sp.z])
	var key := "b_%s_%s" % [sprite, faction]
	var out := [{"name": key, "fw": fr.fw, "fh": fr.fh, "anchor": fr.anchor, "count": 7, "scale": 1.0,
		"extra": {"frames": ["normal", "damaged", "build1", "build2", "build3", "build4", "build5"], "smoke": smoke, "height": h, "size": [sx, sz]},
		"cut": func(i): return h * cuts[i - 2] if i >= 2 else 99.0,
		"burn": func(i): return 0.9 if i == 1 else 0.0,
		"build": func(i):
			var d: Dictionary = B.build(sprite, faction)
			if i >= 2:
				B.scaffold(d.root, sx, sz, h * cuts[i - 2] + 0.12)
			return _wrap(d.root)}]
	if sprite == "conyard" or sprite == "radar":
		out.append({"name": key + "_anim", "fw": fr.fw, "fh": fr.fh, "anchor": fr.anchor, "count": 16, "scale": 1.0, "extra": {"frames": 16},
			"build": func(i): return _wrap(B.build(sprite, faction, float(i) / 16.0).root)})
	if sprite == "arc_coil":
		out.append({"name": key + "_anim", "fw": fr.fw, "fh": fr.fh, "anchor": fr.anchor, "count": 4, "scale": 1.0, "extra": {"frames": 4},
			"build": func(i): return _wrap(B.build(sprite, faction, float(i) / 3.0).root)})
	if probe.has("pivot"):
		var P := M.pal(faction)
		var pv: Vector3 = probe.pivot
		out.append({"name": key + "_turret", "fw": 192, "fh": 160, "anchor": Vector2(96, 100), "count": DIRS, "scale": 1.0, "shadow": false,
			"extra": {"dirs": DIRS, "pivot": [pv.x, pv.y, pv.z]},
			"build": func(i):
				var t: Node3D = B.gun_turret_top(P, faction) if sprite == "gun_turret" else B.flame_turret_top(P, faction)
				return _rot(_wrap(t), i)})
	return out

static func decor(name: String, count: int, fw: int, fh: int, anchor: Vector2, builder: Callable) -> Dictionary:
	return {"name": name, "fw": fw, "fh": fh, "anchor": anchor, "count": count, "scale": 1.0, "mask": false,
		"build": func(i): return _wrap(builder.call(i))}

const BUILDINGS := {
	"coalition": [["conyard", 3, 3], ["power", 2, 2], ["adv_power", 3, 3], ["refinery", 3, 3], ["silo", 1, 1], ["barracks", 2, 2],
		["factory", 3, 3], ["radar", 2, 2], ["pillbox", 1, 1], ["gun_turret", 1, 1]],
	"dominion": [["conyard", 3, 3], ["power", 2, 2], ["adv_power", 3, 3], ["refinery", 3, 3], ["silo", 1, 1], ["barracks_dom", 2, 2],
		["factory", 3, 3], ["radar", 2, 2], ["flame_tower", 1, 1], ["arc_coil", 1, 2]],
}

static func all() -> Array:
	var out := []
	out += vehicle("u_tank_light_coalition", func(_s): return M.tank("light", "coalition"), 1.3)
	out += vehicle("u_tank_medium_coalition", func(_s): return M.tank("medium", "coalition"), 1.3)
	out += vehicle("u_tank_heavy_dominion", func(_s): return M.tank("heavy", "dominion"), 1.3)
	out += vehicle("u_jeep_coalition", func(_s): return M.jeep("coalition"), 1.35)
	for f in ["coalition", "dominion"]:
		out += vehicle("u_harvester_" + f, func(s): return M.harvester(f, float(s)), 1.25, 2)
		out += vehicle("u_mcv_" + f, func(_s): return M.mcv(f), 1.25)
		out += infantry("i_infantry_" + f, "infantry", f)
	out += infantry("i_rocket_inf_coalition", "rocket_inf", "coalition")
	out += infantry("i_heavy_inf_dominion", "heavy_inf", "dominion")
	out += infantry("i_flame_inf_dominion", "flame_inf", "dominion")
	for f in BUILDINGS:
		for b in BUILDINGS[f]:
			out += building(b[0], f, b[1], b[2])
	out.append(decor("d_tree_broad", 4, 192, 224, Vector2(96, 180), func(i): return B.tree(0, 11 + i)))
	out.append(decor("d_tree_pine", 4, 192, 224, Vector2(96, 180), func(i): return B.tree(1, 31 + i)))
	out.append(decor("d_bush", 4, 128, 112, Vector2(64, 80), func(i): return B.tree(2, 51 + i)))
	out.append(decor("d_rock", 4, 160, 128, Vector2(80, 88), func(i): return B.rock(false, 71 + i)))
	out.append(decor("d_cliff", 4, 256, 224, Vector2(128, 150), func(i): return B.rock(true, 91 + i)))
	for p in [["crates", 2], ["barrels", 3], ["fence", 1], ["sandbags", 1], ["wreck", 1], ["lamp", 1]]:
		var kind: String = p[0]
		out.append(decor("d_" + kind, p[1], 160, 160, Vector2(80, 110), func(i): return B.prop(kind, i)))
	return out
