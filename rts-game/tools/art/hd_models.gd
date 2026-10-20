class_name HDModels
extends RefCounted
## Detailed models for pre-rendering sprites. Units face +X, origin at ground centre.
## Buildings span (0,0)-(size.x,size.y) in XZ. Parts flagged team=true are recoloured
## per player at runtime through the baked team mask.

const K := preload("res://tools/art/kit.gd")

static func pal(faction: String) -> Dictionary:
	if faction == "dominion":
		return {
			"team": K.paint(Color(0.66, 0.66, 0.66), 0.25, 0.55, {"panel": 6.0, "panel_dark": 0.25}),
			"team_plain": K.paint(Color(0.66, 0.66, 0.66), 0.25, 0.55),
			"sec": K.paint(Color(0.34, 0.31, 0.28), 0.45, 0.5, {"panel": 5.0}),
			"sec_plain": K.paint(Color(0.34, 0.31, 0.28), 0.45, 0.5),
			"conc": K.paint(Color(0.6, 0.55, 0.5), 0.0, 0.9, {"panel": 2.0, "panel_dark": 0.22, "grime": 0.5}),
			"conc2": K.paint(Color(0.5, 0.46, 0.42), 0.0, 0.9, {"panel": 3.0, "grime": 0.5}),
			"roof": K.paint(Color(0.4, 0.36, 0.33), 0.3, 0.6, {"corrugate": 90.0}),
			"trim": K.paint(Color(0.55, 0.16, 0.12), 0.2, 0.6),
		}
	return {
		"team": K.paint(Color(0.66, 0.66, 0.66), 0.25, 0.55, {"panel": 6.0, "panel_dark": 0.25}),
		"team_plain": K.paint(Color(0.66, 0.66, 0.66), 0.25, 0.55),
		"sec": K.paint(Color(0.47, 0.5, 0.48), 0.45, 0.5, {"panel": 5.0}),
		"sec_plain": K.paint(Color(0.47, 0.5, 0.48), 0.45, 0.5),
		"conc": K.paint(Color(0.68, 0.68, 0.66), 0.0, 0.9, {"panel": 2.0, "panel_dark": 0.22, "grime": 0.5}),
		"conc2": K.paint(Color(0.56, 0.57, 0.56), 0.0, 0.9, {"panel": 3.0, "grime": 0.5}),
		"roof": K.paint(Color(0.44, 0.47, 0.5), 0.35, 0.55, {"corrugate": 90.0}),
		"trim": K.paint(Color(0.85, 0.7, 0.2), 0.2, 0.6),
	}

static func dark() -> ShaderMaterial: return K.paint(Color(0.16, 0.16, 0.17), 0.6, 0.45)
static func steel() -> ShaderMaterial: return K.paint(Color(0.58, 0.6, 0.62), 0.7, 0.35)
static func track() -> ShaderMaterial: return K.paint(Color(0.14, 0.13, 0.12), 0.3, 0.8, {"tread": 70.0, "noise_amt": 0.1})
static func rubber() -> ShaderMaterial: return K.paint(Color(0.1, 0.1, 0.1), 0.0, 0.9)
static func glass_lit() -> ShaderMaterial: return K.paint(Color(1.0, 0.82, 0.45), 0.0, 0.3, {"emit": 1.4, "noise_amt": 0.05})
static func glass() -> ShaderMaterial: return K.paint(Color(0.22, 0.36, 0.48), 0.6, 0.15, {"noise_amt": 0.05})
static func hazard() -> ShaderMaterial: return K.paint(Color(0.92, 0.72, 0.15), 0.1, 0.6, {"stripes": 9.0})
static func yellow() -> ShaderMaterial: return K.paint(Color(0.9, 0.7, 0.16), 0.2, 0.55)
static func light(col: Color) -> ShaderMaterial: return K.paint(col, 0.0, 0.4, {"emit": 3.0, "noise_amt": 0.0})

# ---------------------------------------------------------------- vehicles

## Returns {root, turret (Node3D or null), turret_pivot (Vector3)}.
static func tank(kind: String, faction: String) -> Dictionary:
	var P := pal(faction)
	var spec = {"light": [0.64, 0.48, 0.25, 0.42, 1], "medium": [0.78, 0.56, 0.3, 0.5, 1], "heavy": [0.9, 0.66, 0.34, 0.54, 2]}[kind]
	var L: float = spec[0]
	var W: float = spec[1]
	var TL: float = spec[2]
	var BL: float = spec[3]
	var barrels: int = spec[4]
	var root := Node3D.new()
	var tw := W * 0.24
	for side in [-1.0, 1.0]:
		var z: float = side * (W * 0.5 - tw * 0.5)
		K.add(root, K.extrude(K.stadium(-L * 0.5, L * 0.5, 0.012, 0.17, 6), tw), track(), Vector3(0, 0, z))
		var n := 5 if kind != "light" else 4
		for i in n:
			var x := -L * 0.36 + i * (L * 0.72) / (n - 1)
			K.add(root, K.cylinder(0.05, 0.022, 14), dark(), Vector3(x, 0.07, z + side * tw * 0.5), Vector3(90, 0, 0))
			K.add(root, K.cylinder(0.022, 0.026, 8), steel(), Vector3(x, 0.07, z + side * tw * 0.52), Vector3(90, 0, 0))
		K.add(root, K.cylinder(0.06, 0.03, 10), steel(), Vector3(L * 0.44, 0.1, z + side * tw * 0.45), Vector3(90, 0, 0))
		K.add(root, K.bevel_box(Vector3(L * 1.03, 0.022, tw * 1.12), 0.008), P.team, Vector3(0, 0.178, z), Vector3.ZERO, true)
		K.add(root, K.bevel_box(Vector3(L * 0.82, 0.055, 0.014), 0.005), P.sec, Vector3(-0.01, 0.14, z + side * tw * 0.58))
		K.add(root, K.bevel_box(Vector3(0.12, 0.04, tw * 0.7), 0.01), P.sec, Vector3(-L * 0.18, 0.205, z))
	var hh := 0.24
	var hw := W * 0.47
	var planes := [
		K.plane_at(Vector3.DOWN, Vector3(0, 0.1, 0)), K.plane_at(Vector3.UP, Vector3(0, hh, 0)),
		K.plane_at(Vector3(0, 0, 1), Vector3(0, 0, hw)), K.plane_at(Vector3(0, 0, -1), Vector3(0, 0, -hw)),
		K.plane_at(Vector3(1, 0, 0), Vector3(L * 0.5, 0, 0)), K.plane_at(Vector3(-1, 0, 0), Vector3(-L * 0.5, 0, 0)),
		K.plane_at(Vector3(0.62, 1, 0), Vector3(L * 0.5 - 0.11, hh, 0)), K.plane_at(Vector3(-0.8, 1, 0), Vector3(-L * 0.5 + 0.05, hh, 0)),
		K.plane_at(Vector3(0, 1, 1.1), Vector3(0, hh, hw - 0.035)), K.plane_at(Vector3(0, 1, -1.1), Vector3(0, hh, -hw + 0.035)),
		K.plane_at(Vector3(1, 0, 1), Vector3(L * 0.5, 0, hw - 0.04)), K.plane_at(Vector3(1, 0, -1), Vector3(L * 0.5, 0, -hw + 0.04)),
	]
	K.add(root, K.convex(planes), P.team, Vector3.ZERO, Vector3.ZERO, true)
	# Engine deck details.
	K.add(root, K.bevel_box(Vector3(L * 0.24, 0.014, W * 0.46), 0.004), K.paint(Color(0.15, 0.15, 0.15), 0.5, 0.5, {"stripes": 40.0}), Vector3(-L * 0.33, hh + 0.004, 0))
	for z2 in [-W * 0.2, W * 0.2]:
		K.add(root, K.cylinder(0.018, 0.06, 8), dark(), Vector3(-L * 0.5 - 0.01, 0.2, z2), Vector3(0, 0, 90))
	for z2 in [-W * 0.3, W * 0.3]:
		K.add(root, K.lathe([Vector2(0.018, 0), Vector2(0.022, 0.01), Vector2(0.0, 0.02)], 10), light(Color(1, 0.9, 0.7)), Vector3(L * 0.47, 0.2, z2), Vector3(0, 0, -90))
	# Turret.
	var piv := Vector3(-L * 0.04, hh, 0)
	var tur := Node3D.new()
	var tw2 := TL * 0.48
	var th := 0.11 if kind != "heavy" else 0.13
	var tp := [
		K.plane_at(Vector3.DOWN, Vector3(0, 0, 0)), K.plane_at(Vector3.UP, Vector3(0, th, 0)),
		K.plane_at(Vector3(1, 0.9, 0), Vector3(TL * 0.48, th * 0.5, 0)), K.plane_at(Vector3(-1, 0.3, 0), Vector3(-TL * 0.6, th * 0.5, 0)),
		K.plane_at(Vector3(0, 0.4, 1), Vector3(0, th * 0.5, tw2)), K.plane_at(Vector3(0, 0.4, -1), Vector3(0, th * 0.5, -tw2)),
		K.plane_at(Vector3(0.75, 0.35, 0.75), Vector3(TL * 0.3, th * 0.5, tw2 * 0.75)), K.plane_at(Vector3(0.75, 0.35, -0.75), Vector3(TL * 0.3, th * 0.5, -tw2 * 0.75)),
		K.plane_at(Vector3(-0.7, 0.3, 0.7), Vector3(-TL * 0.45, th * 0.5, tw2 * 0.8)), K.plane_at(Vector3(-0.7, 0.3, -0.7), Vector3(-TL * 0.45, th * 0.5, -tw2 * 0.8)),
	]
	K.add(tur, K.convex(tp), P.team, Vector3.ZERO, Vector3.ZERO, true)
	K.add(tur, K.bevel_box(Vector3(0.06, th * 0.75, tw2 * (1.2 if barrels == 2 else 0.9)), 0.012), P.sec, Vector3(TL * 0.5, th * 0.5, 0))
	var zs := [0.0] if barrels == 1 else [-0.055, 0.055]
	for z3 in zs:
		K.add(tur, K.cylinder(0.022, BL, 10), P.sec_plain, Vector3(TL * 0.5 + BL * 0.5, th * 0.5, z3), Vector3(0, 0, 90))
		K.add(tur, K.cylinder(0.032, 0.06, 10), P.sec_plain, Vector3(TL * 0.5 + BL * 0.45, th * 0.5, z3), Vector3(0, 0, 90))
		K.add(tur, K.lathe([Vector2(0.03, 0), Vector2(0.034, 0.02), Vector2(0.03, 0.05), Vector2(0.0, 0.05)], 10), dark(), Vector3(TL * 0.5 + BL - 0.01, th * 0.5, z3), Vector3(0, 0, -90))
	K.add(tur, K.lathe([Vector2(0.045, 0), Vector2(0.045, 0.035), Vector2(0.035, 0.05), Vector2(0.0, 0.052)], 12), P.sec_plain, Vector3(-TL * 0.12, th, tw2 * 0.4))
	K.tube(tur, Vector3(-TL * 0.12, th + 0.05, tw2 * 0.4), Vector3(-TL * 0.12 + 0.1, th + 0.06, tw2 * 0.4), 0.007, dark())
	K.add(tur, K.bevel_box(Vector3(0.05, 0.01, 0.06), 0.003), P.sec, Vector3(0.03, th + 0.005, -tw2 * 0.4))
	K.tube(tur, Vector3(-TL * 0.5, th, -tw2 * 0.6), Vector3(-TL * 0.55, th + 0.38, -tw2 * 0.6), 0.0035, dark(), 4)
	K.add(tur, K.bevel_box(Vector3(0.07, 0.05, tw2 * 1.5), 0.008), P.sec, Vector3(-TL * 0.62, th * 0.55, 0))
	return {"root": root, "turret": tur, "pivot": piv}

static func jeep(faction: String) -> Dictionary:
	var P := pal(faction)
	var root := Node3D.new()
	for p in [Vector2(-0.17, -0.16), Vector2(0.17, -0.16), Vector2(-0.17, 0.16), Vector2(0.17, 0.16)]:
		K.add(root, K.lathe([Vector2(0.06, -0.035), Vector2(0.078, -0.025), Vector2(0.078, 0.025), Vector2(0.06, 0.035)], 14), rubber(), Vector3(p.x, 0.078, p.y), Vector3(90, 0, 0))
		K.add(root, K.cylinder(0.035, 0.074, 10), steel(), Vector3(p.x, 0.078, p.y), Vector3(90, 0, 0))
	var planes := [K.plane_at(Vector3.DOWN, Vector3(0, 0.09, 0)), K.plane_at(Vector3.UP, Vector3(0, 0.19, 0)),
		K.plane_at(Vector3.BACK, Vector3(0, 0, 0.15)), K.plane_at(Vector3.FORWARD, Vector3(0, 0, -0.15)),
		K.plane_at(Vector3(1, 0.6, 0), Vector3(0.28, 0.16, 0)), K.plane_at(Vector3(-1, 0.2, 0), Vector3(-0.28, 0.14, 0)),
		K.plane_at(Vector3(0, 1, 1), Vector3(0, 0.19, 0.13)), K.plane_at(Vector3(0, 1, -1), Vector3(0, 0.19, -0.13))]
	K.add(root, K.convex(planes), P.team, Vector3.ZERO, Vector3.ZERO, true)
	for side in [-1.0, 1.0]:
		K.add(root, K.bevel_box(Vector3(0.12, 0.02, 0.06), 0.006), P.sec, Vector3(0.17, 0.17, side * 0.16))
		K.add(root, K.bevel_box(Vector3(0.12, 0.02, 0.06), 0.006), P.sec, Vector3(-0.17, 0.17, side * 0.16))
	K.add(root, K.bevel_box(Vector3(0.02, 0.07, 0.26), 0.004), glass(), Vector3(0.12, 0.23, 0), Vector3(0, 0, -20))
	K.tube(root, Vector3(0.05, 0.19, 0.13), Vector3(0.05, 0.3, 0.12), 0.006, dark())
	K.tube(root, Vector3(0.05, 0.19, -0.13), Vector3(0.05, 0.3, -0.12), 0.006, dark())
	K.add(root, K.bevel_box(Vector3(0.08, 0.05, 0.22), 0.01), P.sec, Vector3(-0.22, 0.21, 0))
	for z2 in [-0.1, 0.1]:
		K.add(root, K.cylinder(0.014, 0.01, 8), light(Color(1, 0.9, 0.7)), Vector3(0.285, 0.16, z2), Vector3(0, 0, 90))
	var tur := Node3D.new()
	K.add(tur, K.lathe([Vector2(0.05, 0), Vector2(0.05, 0.03), Vector2(0.03, 0.05)], 12), P.sec_plain, Vector3.ZERO)
	K.add(tur, K.bevel_box(Vector3(0.08, 0.05, 0.04), 0.006), dark(), Vector3(0.04, 0.06, 0))
	K.add(tur, K.cylinder(0.009, 0.22, 6), dark(), Vector3(0.16, 0.065, 0), Vector3(0, 0, 90))
	K.add(tur, K.bevel_box(Vector3(0.012, 0.06, 0.1), 0.003), P.sec, Vector3(0.07, 0.07, 0))
	return {"root": root, "turret": tur, "pivot": Vector3(-0.06, 0.19, 0)}

static func harvester(faction: String, load: float) -> Dictionary:
	var P := pal(faction)
	var root := Node3D.new()
	var L := 0.88
	var W := 0.64
	var tw := W * 0.24
	for side in [-1.0, 1.0]:
		var z: float = side * (W * 0.5 - tw * 0.5)
		K.add(root, K.extrude(K.stadium(-L * 0.5, L * 0.5, 0.012, 0.17, 6), tw), track(), Vector3(0, 0, z))
		for i in 5:
			K.add(root, K.cylinder(0.05, 0.022, 12), dark(), Vector3(-L * 0.36 + i * L * 0.18, 0.07, z + side * tw * 0.5), Vector3(90, 0, 0))
		K.add(root, K.bevel_box(Vector3(L * 1.02, 0.022, tw * 1.1), 0.008), P.sec, Vector3(0, 0.178, z))
	K.add(root, K.bevel_box(Vector3(L * 0.95, 0.07, W * 0.72), 0.02), P.sec, Vector3(0, 0.2, 0))
	# Ore bin with sloped walls.
	var bp := [K.plane_at(Vector3.DOWN, Vector3(0, 0.22, 0)), K.plane_at(Vector3.UP, Vector3(0, 0.42, 0)),
		K.plane_at(Vector3(-1, 0.25, 0), Vector3(-0.42, 0.3, 0)), K.plane_at(Vector3(1, 0.25, 0), Vector3(0.18, 0.3, 0)),
		K.plane_at(Vector3(0, 0.3, 1), Vector3(0, 0.3, W * 0.4)), K.plane_at(Vector3(0, 0.3, -1), Vector3(0, 0.3, -W * 0.4))]
	K.add(root, K.convex(bp), P.team, Vector3.ZERO, Vector3.ZERO, true)
	K.add(root, K.bevel_box(Vector3(0.56, 0.01, W * 0.7), 0.003), dark(), Vector3(-0.12, 0.425, 0))
	if load > 0.0:
		var ore := K.paint(Color(0.92, 0.7, 0.22), 0.7, 0.35, {"noise_amt": 0.6})
		for i in int(14 * load):
			var rx := -0.36 + fmod(i * 0.137, 0.5)
			var rz := -W * 0.3 + fmod(i * 0.093, W * 0.6)
			K.add(root, K.lathe([Vector2(0.0, 0), Vector2(0.05, 0.02), Vector2(0.03, 0.05), Vector2(0, 0.06)], 6, false), ore, Vector3(rx, 0.39 + 0.02 * load, rz))
	# Cab.
	var cp := [K.plane_at(Vector3.DOWN, Vector3(0, 0.22, 0)), K.plane_at(Vector3.UP, Vector3(0, 0.44, 0)),
		K.plane_at(Vector3(1, 0.5, 0), Vector3(0.42, 0.33, 0)), K.plane_at(Vector3(-1, 0, 0), Vector3(0.2, 0.3, 0)),
		K.plane_at(Vector3.BACK, Vector3(0, 0.3, W * 0.36)), K.plane_at(Vector3.FORWARD, Vector3(0, 0.3, -W * 0.36))]
	K.add(root, K.convex(cp), P.team, Vector3.ZERO, Vector3.ZERO, true)
	K.add(root, K.bevel_box(Vector3(0.02, 0.07, W * 0.6), 0.004), glass(), Vector3(0.41, 0.37, 0), Vector3(0, 0, -27))
	K.add(root, K.cylinder(0.08, W * 0.8, 12), steel(), Vector3(0.49, 0.1, 0), Vector3(90, 0, 0))
	for i in 5:
		K.add(root, K.bevel_box(Vector3(0.025, 0.17, 0.02), 0.004), yellow(), Vector3(0.49, 0.1, -W * 0.32 + i * W * 0.16), Vector3(0, 0, i * 36))
	K.tube(root, Vector3(0.3, 0.44, -0.2), Vector3(0.3, 0.6, -0.2), 0.018, dark())
	K.add(root, K.cylinder(0.02, 0.02, 8), light(Color(1, 0.55, 0.15)), Vector3(0.3, 0.46, 0.15))
	return {"root": root, "turret": null, "pivot": Vector3.ZERO}

static func mcv(faction: String) -> Dictionary:
	var P := pal(faction)
	var root := Node3D.new()
	var L := 0.96
	var W := 0.64
	var tw := W * 0.24
	for side in [-1.0, 1.0]:
		var z: float = side * (W * 0.5 - tw * 0.5)
		K.add(root, K.extrude(K.stadium(-L * 0.5, L * 0.5, 0.012, 0.17, 6), tw), track(), Vector3(0, 0, z))
		for i in 6:
			K.add(root, K.cylinder(0.048, 0.022, 12), dark(), Vector3(-L * 0.38 + i * L * 0.152, 0.07, z + side * tw * 0.5), Vector3(90, 0, 0))
		K.add(root, K.bevel_box(Vector3(L * 1.02, 0.022, tw * 1.1), 0.008), P.team, Vector3(0, 0.178, z), Vector3.ZERO, true)
	K.add(root, K.bevel_box(Vector3(L * 0.95, 0.09, W * 0.72), 0.02), P.team, Vector3(0, 0.21, 0), Vector3.ZERO, true)
	var cp := [K.plane_at(Vector3.DOWN, Vector3(0, 0.25, 0)), K.plane_at(Vector3.UP, Vector3(0, 0.46, 0)),
		K.plane_at(Vector3(1, 0.45, 0), Vector3(0.47, 0.35, 0)), K.plane_at(Vector3(-1, 0, 0), Vector3(0.26, 0.3, 0)),
		K.plane_at(Vector3.BACK, Vector3(0, 0.3, W * 0.36)), K.plane_at(Vector3.FORWARD, Vector3(0, 0.3, -W * 0.36))]
	K.add(root, K.convex(cp), P.team, Vector3.ZERO, Vector3.ZERO, true)
	K.add(root, K.bevel_box(Vector3(0.02, 0.08, W * 0.6), 0.004), glass(), Vector3(0.455, 0.39, 0), Vector3(0, 0, -24))
	K.add(root, K.bevel_box(Vector3(0.6, 0.18, W * 0.62), 0.02), P.conc, Vector3(-0.16, 0.34, 0))
	K.add(root, K.bevel_box(Vector3(0.6, 0.02, 0.06), 0.004), P.trim, Vector3(-0.16, 0.44, W * 0.2))
	var arm := K.pivot(root, Vector3(-0.4, 0.44, -0.12))
	K.add(arm, K.cylinder(0.05, 0.06, 10), yellow(), Vector3.ZERO)
	K.add(arm, K.bevel_box(Vector3(0.7, 0.045, 0.045), 0.008), yellow(), Vector3(0.33, 0.03, 0), Vector3(0, 0, 4))
	K.add(arm, K.bevel_box(Vector3(0.06, 0.05, 0.06), 0.01), dark(), Vector3(0.66, 0.0, 0))
	K.add(root, K.cylinder(0.025, 0.03, 8), light(Color(1, 0.55, 0.15)), Vector3(0.36, 0.48, 0))
	return {"root": root, "turret": null, "pivot": Vector3.ZERO}

# ---------------------------------------------------------------- infantry

## pose: {"walk": phase 0..1 or -1, "fire": bool, "dead": 0..1}
static func infantry(kind: String, faction: String, pose: Dictionary) -> Node3D:
	var P := pal(faction)
	var root := Node3D.new()
	var s := 1.12 if kind == "heavy_inf" else 1.0
	var uni := K.paint(Color(0.38, 0.42, 0.32) if faction == "coalition" else Color(0.42, 0.36, 0.3), 0.0, 0.85, {"noise_amt": 0.35})
	var skin := K.paint(Color(0.86, 0.68, 0.54), 0.0, 0.7)
	var boot := K.paint(Color(0.12, 0.1, 0.09), 0.0, 0.8)
	var body := K.pivot(root, Vector3.ZERO, "body")
	var dead: float = pose.get("dead", 0.0)
	var phase: float = pose.get("walk", -1.0)
	var swing := sin(phase * TAU) * 0.55 if phase >= 0.0 else 0.0
	for side in [-1.0, 1.0]:
		var hip := K.pivot(body, Vector3(0, 0.16 * s, side * 0.035 * s))
		hip.rotation.z = swing * side
		K.add(hip, K.lathe([Vector2(0.024, -0.15), Vector2(0.028, -0.07), Vector2(0.03, 0.0)], 8).duplicate(), uni, Vector3(0, 0, 0), Vector3.ZERO, false, Vector3(s, s, s))
		K.add(hip, K.bevel_box(Vector3(0.06, 0.03, 0.04), 0.008), boot, Vector3(0.012, -0.155 * s, 0))
	K.add(body, K.bevel_box(Vector3(0.085, 0.13, 0.12), 0.025), P.team_plain, Vector3(0, 0.235 * s, 0), Vector3.ZERO, true, Vector3(s, s, s))
	K.add(body, K.bevel_box(Vector3(0.06, 0.09, 0.09), 0.015), uni, Vector3(-0.065 * s, 0.24 * s, 0))
	K.add(body, K.lathe([Vector2(0.0, -0.045), Vector2(0.04, -0.035), Vector2(0.046, 0.0), Vector2(0.04, 0.035), Vector2(0.0, 0.045)], 10), skin, Vector3(0.005, 0.345 * s, 0), Vector3.ZERO, false, Vector3(s, s, s))
	K.add(body, K.lathe([Vector2(0.056, 0.0), Vector2(0.052, 0.025), Vector2(0.03, 0.045), Vector2(0.0, 0.05)], 12), uni, Vector3(0, 0.355 * s, 0), Vector3.ZERO, false, Vector3(s, s, s))
	var arms := K.pivot(body, Vector3(0.0, 0.28 * s, 0))
	arms.rotation.z = -0.25 if pose.get("fire", false) else -swing * 0.3
	for side in [-1.0, 1.0]:
		K.tube(arms, Vector3(0, 0, side * 0.07 * s), Vector3(0.08 * s, -0.04 * s, side * 0.035 * s), 0.018 * s, uni, 6)
	match kind:
		"infantry":
			K.add(arms, K.bevel_box(Vector3(0.22, 0.025, 0.022), 0.006), dark(), Vector3(0.12 * s, -0.04 * s, 0.02))
		"rocket_inf":
			K.add(body, K.cylinder(0.03, 0.32, 10), K.paint(Color(0.34, 0.38, 0.3), 0.2, 0.6), Vector3(0.03, 0.33 * s, 0.075), Vector3(0, 0, 90))
			K.add(body, K.lathe([Vector2(0.03, 0), Vector2(0.025, 0.04), Vector2(0, 0.06)], 8), yellow(), Vector3(0.19, 0.33 * s, 0.075), Vector3(0, 0, -90))
		"heavy_inf":
			K.add(body, K.cylinder(0.038, 0.34, 10), dark(), Vector3(0.04, 0.34 * s, 0.085), Vector3(0, 0, 90))
			K.add(body, K.lathe([Vector2(0.04, 0), Vector2(0.06, 0.05), Vector2(0, 0.1)], 8), K.paint(Color(0.45, 0.4, 0.3), 0.3, 0.6), Vector3(0.21, 0.34 * s, 0.085), Vector3(0, 0, -90))
		"flame_inf":
			K.add(body, K.cylinder(0.045, 0.14, 10), K.paint(Color(0.62, 0.22, 0.14), 0.4, 0.5), Vector3(-0.08, 0.25, -0.025))
			K.add(body, K.cylinder(0.045, 0.14, 10), K.paint(Color(0.62, 0.22, 0.14), 0.4, 0.5), Vector3(-0.08, 0.25, 0.025))
			K.add(arms, K.bevel_box(Vector3(0.2, 0.025, 0.025), 0.006), dark(), Vector3(0.11, -0.04, 0.02))
			K.add(arms, K.cylinder(0.012, 0.012, 6), light(Color(1, 0.5, 0.1)), Vector3(0.21, -0.04, 0.02), Vector3(0, 0, 90))
	if dead > 0.0:
		body.rotation.z = -dead * PI * 0.47
		body.position.y = dead * 0.04
	return root

# ---------------------------------------------------------------- buildings

static func windows(parent: Node3D, start: Vector3, axis: Vector3, n: int, step: float, size: Vector2, lit_ratio: float = 0.6) -> void:
	for i in n:
		var p := start + axis * (i * step)
		var s3 := Vector3(size.x, size.y, 0.012) if absf(axis.x) > 0.5 else Vector3(0.012, size.y, size.x)
		var lit := fmod(i * 0.618 + start.x * 3.1 + start.z * 1.7, 1.0) < lit_ratio
		K.add(parent, K.bevel_box(s3, 0.003), glass_lit() if lit else glass(), p)

static func vent(parent: Node3D, pos: Vector3, w: float = 0.18) -> void:
	K.add(parent, K.bevel_box(Vector3(w, 0.08, w), 0.012), steel(), pos + Vector3(0, 0.04, 0))
	K.add(parent, K.cylinder(w * 0.36, 0.02, 12), K.paint(Color(0.12, 0.12, 0.12), 0.5, 0.5, {"stripes": 30.0}), pos + Vector3(0, 0.09, 0))

static func pad(parent: Node3D, sx: float, sz: float, P: Dictionary) -> void:
	K.add(parent, K.bevel_box(Vector3(sx - 0.04, 0.07, sz - 0.04), 0.02), P.conc, Vector3(sx * 0.5, 0.035, sz * 0.5))

static func power(faction: String, towers: int, sx: float, sz: float) -> Dictionary:
	var P := pal(faction)
	var root := Node3D.new()
	pad(root, sx, sz, P)
	var smoke := []
	for i in towers:
		var x := sx * (i + 0.5) / towers
		var z := sz * 0.36 if towers == 2 else (sz * 0.3 if i != 1 else sz * 0.42)
		var r: float = minf(0.4, sx / towers * 0.43)
		var prof := [Vector2(r, 0.07), Vector2(r * 0.86, 0.3), Vector2(r * 0.7, 0.62), Vector2(r * 0.74, 0.9), Vector2(r * 0.78, 0.98)]
		K.add(root, K.lathe(prof, 28, true, false, true), P.conc, Vector3(x, 0, z))
		K.add(root, K.lathe([Vector2(r * 0.79, 0.97), Vector2(r * 0.79, 1.0), Vector2(r * 0.7, 1.0)], 28), P.conc2, Vector3(x, 0, z))
		K.add(root, K.cylinder(r * 0.68, 0.02, 24), K.paint(Color(0.07, 0.07, 0.07), 0.0, 1.0), Vector3(x, 0.96, z))
		K.add(root, K.lathe([Vector2(r * 1.02, 0.07), Vector2(r * 1.02, 0.12), Vector2(r * 0.96, 0.14)], 28), P.team_plain, Vector3(x, 0, z), Vector3.ZERO, true)
		for k in 6:
			var a := TAU * k / 6.0
			K.tube(root, Vector3(x + cos(a) * r * 1.05, 0.07, z + sin(a) * r * 1.05), Vector3(x + cos(a) * r * 0.95, 0.2, z + sin(a) * r * 0.95), 0.015, P.conc2, 6)
		smoke.append(Vector3(x, 1.0, z))
	var hall_z := sz * 0.78
	K.add(root, K.bevel_box(Vector3(sx - 0.25, 0.34, sz * 0.32), 0.03), P.conc2, Vector3(sx * 0.5, 0.24, hall_z))
	K.add(root, K.bevel_box(Vector3(sx - 0.22, 0.04, sz * 0.34), 0.012), P.roof, Vector3(sx * 0.5, 0.42, hall_z))
	K.add(root, K.bevel_box(Vector3(sx - 0.24, 0.05, 0.02), 0.005), P.team_plain, Vector3(sx * 0.5, 0.36, hall_z + sz * 0.16 + 0.004), Vector3.ZERO, true)
	windows(root, Vector3(0.28, 0.22, hall_z + sz * 0.16 + 0.006), Vector3.RIGHT, int((sx - 0.5) / 0.2) + 1, 0.2, Vector2(0.1, 0.06))
	K.add(root, K.bevel_box(Vector3(0.16, 0.2, 0.02), 0.005), K.paint(Color(0.2, 0.2, 0.2), 0.5, 0.5, {"stripes": 25.0}), Vector3(sx - 0.3, 0.17, hall_z + sz * 0.16 + 0.008))
	vent(root, Vector3(0.4, 0.44, hall_z), 0.14)
	vent(root, Vector3(sx - 0.45, 0.44, hall_z), 0.14)
	# Transformer yard.
	for k in 2:
		var tp := Vector3(sx - 0.18, 0.07, sz * 0.48 + k * 0.18)
		K.add(root, K.bevel_box(Vector3(0.14, 0.12, 0.12), 0.015), K.paint(Color(0.35, 0.4, 0.36), 0.4, 0.5, {"panel": 12.0}), tp + Vector3(0, 0.06, 0))
		for j in 3:
			K.add(root, K.lathe([Vector2(0.012, 0), Vector2(0.02, 0.01), Vector2(0.012, 0.02), Vector2(0.02, 0.03), Vector2(0.012, 0.04), Vector2(0.0, 0.05)], 8), K.paint(Color(0.85, 0.75, 0.6), 0.0, 0.4), tp + Vector3(-0.04 + j * 0.04, 0.12, 0))
	for i in towers:
		var x := sx * (i + 0.5) / towers
		K.tube(root, Vector3(x, 0.22, hall_z - sz * 0.16), Vector3(x, 0.22, sz * 0.36 + 0.3), 0.04, steel())
		K.add(root, K.cylinder(0.055, 0.03, 12), dark(), Vector3(x, 0.22, hall_z - sz * 0.16 - 0.02), Vector3(90, 0, 0))
	return {"root": root, "smoke": smoke}
