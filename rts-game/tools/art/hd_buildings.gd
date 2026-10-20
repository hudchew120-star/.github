class_name HDBuildings
extends RefCounted
## Detailed structures for sprite baking. Footprint spans (0,0)-(sx,sz); the camera
## sees the +X and +Z faces, so entrances, windows and signage face that way.

const K := preload("res://tools/art/kit.gd")
const M := preload("res://tools/art/hd_models.gd")
const B2 := preload("res://tools/art/buildings2.gd")

# ---------------------------------------------------------------- shared details

static func pad(root: Node3D, sx: float, sz: float, P: Dictionary, curb: bool = true) -> void:
	K.add(root, K.bevel_box(Vector3(sx - 0.03, 0.06, sz - 0.03), 0.02), P.conc, Vector3(sx * 0.5, 0.03, sz * 0.5))
	if curb:
		var cm: Material = P.conc2
		K.add(root, K.bevel_box(Vector3(sx - 0.03, 0.035, 0.05), 0.01), cm, Vector3(sx * 0.5, 0.075, sz - 0.04))
		K.add(root, K.bevel_box(Vector3(0.05, 0.035, sz - 0.03), 0.01), cm, Vector3(sx - 0.04, 0.075, sz * 0.5))
	for c in [Vector3(0.12, 0.062, sz - 0.12), Vector3(sx - 0.12, 0.062, 0.12), Vector3(sx - 0.12, 0.062, sz - 0.12)]:
		K.add(root, K.bevel_box(Vector3(0.12, 0.004, 0.03), 0.002), M.yellow(), c)
		K.add(root, K.bevel_box(Vector3(0.03, 0.004, 0.12), 0.002), M.yellow(), c)

static func block(root: Node3D, pos: Vector3, size: Vector3, wall: Material, roof: Material, parapet: Material = null) -> void:
	K.add(root, K.bevel_box(size, 0.025), wall, pos + Vector3(0, size.y * 0.5, 0))
	K.add(root, K.bevel_box(Vector3(size.x - 0.04, 0.025, size.z - 0.04), 0.008), roof, pos + Vector3(0, size.y + 0.006, 0))
	if parapet != null:
		var y := pos.y + size.y + 0.02
		K.add(root, K.bevel_box(Vector3(size.x, 0.04, 0.03), 0.006), parapet, Vector3(pos.x, y, pos.z + size.z * 0.5 - 0.015))
		K.add(root, K.bevel_box(Vector3(size.x, 0.04, 0.03), 0.006), parapet, Vector3(pos.x, y, pos.z - size.z * 0.5 + 0.015))
		K.add(root, K.bevel_box(Vector3(0.03, 0.04, size.z), 0.006), parapet, Vector3(pos.x + size.x * 0.5 - 0.015, y, pos.z))
		K.add(root, K.bevel_box(Vector3(0.03, 0.04, size.z), 0.006), parapet, Vector3(pos.x - size.x * 0.5 + 0.015, y, pos.z))

## Windows along a face. face: "z" (+Z wall) or "x" (+X wall).
static func win_row(root: Node3D, face: String, origin: Vector3, n: int, step: float, size: Vector2 = Vector2(0.09, 0.065), lit: float = 0.6) -> void:
	for i in n:
		var p := origin + (Vector3(step * i, 0, 0) if face == "z" else Vector3(0, 0, step * i))
		var s3 := Vector3(size.x, size.y, 0.014) if face == "z" else Vector3(0.014, size.y, size.x)
		var on := fmod(i * 0.618 + origin.x * 2.3 + origin.z * 1.7 + origin.y * 5.1, 1.0) < lit
		K.add(root, K.bevel_box(s3 + Vector3(0.012, 0.012, 0.0) if face == "z" else s3 + Vector3(0.0, 0.012, 0.012), 0.003), M.dark(), p - (Vector3(0, 0, 0.002) if face == "z" else Vector3(0.002, 0, 0)))
		K.add(root, K.bevel_box(s3, 0.002), M.glass_lit() if on else M.glass(), p)

static func door(root: Node3D, face: String, pos: Vector3, w: float, h: float, shutter: bool = false) -> void:
	var s3 := Vector3(w, h, 0.02) if face == "z" else Vector3(0.02, h, w)
	var fr := Vector3(w + 0.04, h + 0.03, 0.025) if face == "z" else Vector3(0.025, h + 0.03, w + 0.04)
	K.add(root, K.bevel_box(fr, 0.006), M.yellow() if shutter else M.dark(), pos + Vector3(0, h * 0.5, 0))
	var m: Material = K.paint(Color(0.32, 0.33, 0.33), 0.5, 0.5, {"stripes": 28.0, "noise_amt": 0.1}) if shutter else K.paint(Color(0.2, 0.22, 0.24), 0.5, 0.4)
	K.add(root, K.bevel_box(s3, 0.004), m, pos + Vector3(0, h * 0.5, 0) + (Vector3(0, 0, 0.004) if face == "z" else Vector3(0.004, 0, 0)))

static func vent(root: Node3D, pos: Vector3, w: float = 0.14) -> void:
	M.vent(root, pos, w)

static func ladder(root: Node3D, face: String, pos: Vector3, h: float) -> void:
	var off := Vector3(0.06, 0, 0) if face == "z" else Vector3(0, 0, 0.06)
	K.tube(root, pos - off, pos - off + Vector3(0, h, 0), 0.006, M.steel(), 4)
	K.tube(root, pos + off, pos + off + Vector3(0, h, 0), 0.006, M.steel(), 4)
	var n := int(h / 0.05)
	for i in n:
		K.tube(root, pos - off + Vector3(0, 0.03 + i * 0.05, 0), pos + off + Vector3(0, 0.03 + i * 0.05, 0), 0.004, M.steel(), 4)

static func railing(root: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var n := maxi(2, int(d.length() / 0.12))
	for i in n + 1:
		var p := a + d * (float(i) / n)
		K.tube(root, p, p + Vector3(0, 0.07, 0), 0.004, M.steel(), 4)
	K.tube(root, a + Vector3(0, 0.07, 0), b + Vector3(0, 0.07, 0), 0.005, M.steel(), 4)
	K.tube(root, a + Vector3(0, 0.04, 0), b + Vector3(0, 0.04, 0), 0.004, M.steel(), 4)

static func pipe_run(root: Node3D, pts: Array, r: float, m: Material) -> void:
	for i in pts.size() - 1:
		K.tube(root, pts[i], pts[i + 1], r, m, 10)
		if i > 0:
			K.add(root, K.lathe([Vector2(r * 1.35, -r), Vector2(r * 1.35, r)], 10), m, pts[i])
	for p in [pts[0], pts[-1]]:
		K.add(root, K.lathe([Vector2(r * 1.5, -r * 0.6), Vector2(r * 1.5, r * 0.6)], 10), M.dark(), p)

static func barrels(root: Node3D, pos: Vector3, n: int, col: Color) -> void:
	var m := K.paint(col, 0.4, 0.5, {"noise_amt": 0.3})
	for i in n:
		var p := pos + Vector3(fmod(i * 0.071, 0.14), 0, fmod(i * 0.053, 0.12))
		K.add(root, K.lathe([Vector2(0.03, 0), Vector2(0.033, 0.01), Vector2(0.033, 0.07), Vector2(0.03, 0.08)], 10), m, p)

static func crates(root: Node3D, pos: Vector3, n: int) -> void:
	var m := K.paint(Color(0.52, 0.4, 0.25), 0.0, 0.85, {"panel": 14.0, "panel_dark": 0.4})
	for i in n:
		var s := 0.07 + 0.02 * (i % 2)
		var p := pos + Vector3(fmod(i * 0.09, 0.2), s * 0.5 + (0.09 if i >= 3 else 0.0), fmod(i * 0.07, 0.15))
		K.add(root, K.bevel_box(Vector3(s, s, s), 0.008), m, p, Vector3(0, i * 17, 0))

static func light_post(root: Node3D, pos: Vector3, col: Color = Color(1, 0.85, 0.55)) -> void:
	K.tube(root, pos, pos + Vector3(0, 0.36, 0), 0.008, M.dark(), 6)
	K.tube(root, pos + Vector3(0, 0.36, 0), pos + Vector3(0.06, 0.36, 0.06), 0.006, M.dark(), 6)
	K.add(root, K.cylinder(0.018, 0.01, 8), M.light(col), pos + Vector3(0.06, 0.35, 0.06))

static func beacon(root: Node3D, pos: Vector3, col: Color = Color(1, 0.2, 0.1)) -> void:
	K.add(root, K.lathe([Vector2(0.018, 0), Vector2(0.018, 0.02), Vector2(0.0, 0.035)], 8), M.light(col), pos)

static func emblem(root: Node3D, face: String, pos: Vector3, r: float, faction: String) -> void:
	var rot := Vector3(90, 0, 0) if face == "z" else Vector3(0, 0, 90)
	K.add(root, K.cylinder(r, 0.012, 20), K.paint(Color(0.12, 0.12, 0.12), 0.4, 0.5), pos, rot)
	var mp := pos + (Vector3(0, 0, 0.008) if face == "z" else Vector3(0.008, 0, 0))
	K.add(root, K.cylinder(r * 0.82, 0.012, 20), K.paint(Color(0.66, 0.66, 0.66), 0.3, 0.5), mp, rot, true)
	var star := PackedVector2Array()
	var pts := 5 if faction == "coalition" else 4
	for i in pts * 2:
		var a := -PI * 0.5 + PI * i / pts
		var rr := r * (0.62 if i % 2 == 0 else (0.26 if faction == "coalition" else 0.2))
		star.append(Vector2(cos(a) * rr, -sin(a) * rr))
	var sm := K.paint(Color(0.95, 0.92, 0.85), 0.2, 0.5)
	if face == "z":
		K.add(root, K.extrude(star, 0.01), sm, mp + Vector3(0, 0, 0.008))
	else:
		K.add(root, K.extrude(star, 0.01), sm, mp + Vector3(0.008, 0, 0), Vector3(0, 90, 0))

static func scaffold(root: Node3D, sx: float, sz: float, h: float) -> void:
	var m := M.yellow()
	var step := 0.33
	for x in range(0, int(sx / step) + 1):
		for zz in [0.04, sz - 0.04]:
			K.tube(root, Vector3(x * step + 0.04, 0.06, zz), Vector3(x * step + 0.04, h, zz), 0.008, m, 4)
	for z in range(0, int(sz / step) + 1):
		for xx in [0.04, sx - 0.04]:
			K.tube(root, Vector3(xx, 0.06, z * step + 0.04), Vector3(xx, h, z * step + 0.04), 0.008, m, 4)
	var y := 0.25
	while y < h:
		K.tube(root, Vector3(0.04, y, sz - 0.04), Vector3(sx - 0.04, y, sz - 0.04), 0.006, m, 4)
		K.tube(root, Vector3(sx - 0.04, y, 0.04), Vector3(sx - 0.04, y, sz - 0.04), 0.006, m, 4)
		K.tube(root, Vector3(0.04, y, 0.04), Vector3(sx - 0.04, y, 0.04), 0.006, m, 4)
		K.tube(root, Vector3(0.04, y, 0.04), Vector3(0.04, y, sz - 0.04), 0.006, m, 4)
		y += 0.25

# ---------------------------------------------------------------- structures

## Returns {root, height, anim (Node3D or null), anim_axis}
static func build(sprite: String, faction: String, anim_t: float = 0.0) -> Dictionary:
	var P := M.pal(faction)
	match sprite:
		"conyard": return conyard(P, faction, anim_t)
		"power": return power(P, faction, 2, 2.0, 2.0)
		"adv_power": return adv_power(P, faction)
		"refinery": return refinery(P, faction)
		"silo": return silo(P, faction)
		"barracks": return barracks(P, faction)
		"barracks_dom": return barracks_dom(P, faction)
		"factory": return factory(P, faction)
		"radar": return radar(P, faction, anim_t)
		"pillbox": return pillbox(P, faction)
		"gun_turret": return gun_base(P, faction)
		"flame_tower": return flame_base(P, faction)
		"arc_coil": return arc_coil(P, faction, anim_t)
		"airfield": return B2.airfield(P, faction)
		"naval_yard": return B2.naval_yard(P, faction)
		"repair": return B2.repair(P, faction)
		"sam_site": return B2.sam_base(P, faction)
		"flak_cannon": return B2.flak_base(P, faction)
	return {"root": Node3D.new(), "height": 0.5}

static func conyard(P: Dictionary, f: String, t: float) -> Dictionary:
	var r := Node3D.new()
	pad(r, 3.0, 3.0, P)
	# Main hall and stepped command tower.
	block(r, Vector3(1.25, 0.06, 1.15), Vector3(2.2, 0.46, 1.7), P.conc2, P.roof, P.conc)
	K.add(r, K.bevel_box(Vector3(2.22, 0.06, 0.03), 0.008), P.team_plain, Vector3(1.25, 0.42, 2.005), Vector3.ZERO, true)
	K.add(r, K.bevel_box(Vector3(0.03, 0.06, 1.72), 0.008), P.team_plain, Vector3(2.355, 0.42, 1.15), Vector3.ZERO, true)
	win_row(r, "z", Vector3(0.3, 0.26, 2.008), 6, 0.16)
	win_row(r, "x", Vector3(2.358, 0.26, 0.45), 8, 0.17)
	door(r, "z", Vector3(1.75, 0.06, 2.006), 0.5, 0.3, true)
	block(r, Vector3(0.7, 0.53, 0.75), Vector3(0.8, 0.42, 0.8), P.conc, P.team_plain, P.conc2)
	var gp := [K.plane_at(Vector3.DOWN, Vector3(0, 0.95, 0)), K.plane_at(Vector3.UP, Vector3(0, 1.12, 0)),
		K.plane_at(Vector3(1, -0.35, 0), Vector3(1.13, 1.0, 0)), K.plane_at(Vector3(-1, -0.35, 0), Vector3(0.27, 1.0, 0)),
		K.plane_at(Vector3(0, -0.35, 1), Vector3(0, 1.0, 1.18)), K.plane_at(Vector3(0, -0.35, -1), Vector3(0, 1.0, 0.32))]
	K.add(r, K.convex(gp), K.paint(Color(0.22, 0.42, 0.55), 0.7, 0.15, {"panel": 9.0, "panel_dark": 0.5, "emit": 0.25}), Vector3.ZERO)
	K.add(r, K.bevel_box(Vector3(0.9, 0.05, 0.9), 0.012), P.conc2, Vector3(0.7, 1.14, 0.75))
	K.add(r, K.cylinder(0.012, 0.6, 6), M.dark(), Vector3(0.95, 1.45, 0.55))
	beacon(r, Vector3(0.95, 1.75, 0.55))
	K.add(r, K.lathe([Vector2(0.0, 0.0), Vector2(0.13, 0.04), Vector2(0.15, 0.06)], 16), M.steel(), Vector3(0.45, 1.2, 0.95), Vector3(-20, 0, 15))
	vent(r, Vector3(1.6, 0.53, 0.6))
	vent(r, Vector3(2.0, 0.53, 0.6))
	vent(r, Vector3(1.6, 0.53, 1.4), 0.12)
	railing(r, Vector3(1.25, 0.55, 1.98), Vector3(2.32, 0.55, 1.98))
	emblem(r, "x", Vector3(1.111, 0.75, 0.75), 0.13, f)
	pipe_run(r, [Vector3(2.37, 0.2, 1.7), Vector3(2.6, 0.2, 1.7), Vector3(2.6, 0.2, 2.6)], 0.035, M.steel())
	# Crane on a rail along the north edge.
	K.add(r, K.bevel_box(Vector3(2.8, 0.03, 0.08), 0.01), M.dark(), Vector3(1.5, 0.075, 0.25))
	var mast := K.pivot(r, Vector3(2.55, 0.06, 0.28))
	for c in [Vector2(-0.06, -0.06), Vector2(0.06, -0.06), Vector2(-0.06, 0.06), Vector2(0.06, 0.06)]:
		K.tube(mast, Vector3(c.x, 0, c.y), Vector3(c.x * 0.6, 1.25, c.y * 0.6), 0.012, M.yellow(), 4)
	for i in 6:
		K.tube(mast, Vector3(-0.055 + i * 0.0, i * 0.2, -0.055), Vector3(0.05, i * 0.2 + 0.2, 0.05), 0.006, M.yellow(), 4)
	var jib := K.pivot(mast, Vector3(0, 1.28, 0))
	jib.rotation.y = sin(t * TAU) * 1.2 + 0.6
	K.add(jib, K.bevel_box(Vector3(1.7, 0.07, 0.08), 0.01), M.yellow(), Vector3(-0.6, 0, 0))
	K.add(jib, K.bevel_box(Vector3(0.35, 0.16, 0.18), 0.02), P.sec, Vector3(0.38, 0.0, 0))
	K.add(jib, K.bevel_box(Vector3(0.14, 0.12, 0.14), 0.015), M.glass(), Vector3(0.0, -0.1, 0.0))
	K.tube(jib, Vector3(-1.3, 0, 0), Vector3(-1.3, -0.65, 0), 0.004, M.dark(), 4)
	K.add(jib, K.bevel_box(Vector3(0.1, 0.06, 0.1), 0.01), M.yellow(), Vector3(-1.3, -0.68, 0))
	barrels(r, Vector3(0.15, 0.06, 2.55), 5, Color(0.25, 0.4, 0.3))
	crates(r, Vector3(2.55, 0.06, 2.45), 4)
	light_post(r, Vector3(0.2, 0.06, 2.2))
	return {"root": r, "height": 1.8}

static func power(P: Dictionary, f: String, towers: int, sx: float, sz: float) -> Dictionary:
	var r := Node3D.new()
	pad(r, sx, sz, P)
	for i in towers:
		var x := sx * (i + 0.5) / towers
		var z := sz * 0.34
		var rad: float = minf(0.4, sx / towers * 0.43)
		var prof := [Vector2(rad, 0.06), Vector2(rad * 0.88, 0.26), Vector2(rad * 0.72, 0.6), Vector2(rad * 0.74, 0.88), Vector2(rad * 0.79, 1.0)]
		K.add(r, K.lathe(prof, 32, true, false, true), K.paint(Color(0.72, 0.72, 0.7) if f == "coalition" else Color(0.62, 0.57, 0.52), 0.0, 0.9, {"panel": 9.0, "panel_dark": 0.12, "grime": 0.6}), Vector3(x, 0, z))
		K.add(r, K.lathe([Vector2(rad * 0.75, 0.86), Vector2(rad * 0.8, 1.0), Vector2(rad * 0.8, 1.01)], 32, true, false, false), K.paint(Color(0.32, 0.3, 0.28), 0.0, 0.9), Vector3(x, 0, z))
		K.add(r, K.cylinder(rad * 0.72, 0.01, 28), K.paint(Color(0.05, 0.05, 0.05), 0.0, 1.0), Vector3(x, 0.98, z))
		K.add(r, K.lathe([Vector2(rad * 1.04, 0.06), Vector2(rad * 1.04, 0.13), Vector2(rad * 0.98, 0.15)], 32), P.team_plain, Vector3(x, 0, z), Vector3.ZERO, true)
		for k in 8:
			var a := TAU * k / 8.0
			K.tube(r, Vector3(x + cos(a) * rad * 1.08, 0.06, z + sin(a) * rad * 1.08), Vector3(x + cos(a) * rad * 0.97, 0.22, z + sin(a) * rad * 0.97), 0.014, P.conc2, 6)
		ladder(r, "x", Vector3(x + rad * 0.9, 0.06, z + 0.1), 0.55)
		beacon(r, Vector3(x + rad * 0.55, 1.0, z + rad * 0.55))
	var hz := sz * 0.79
	block(r, Vector3(sx * 0.5, 0.06, hz), Vector3(sx - 0.24, 0.34, sz * 0.3), P.conc2, P.roof, P.conc)
	K.add(r, K.bevel_box(Vector3(sx - 0.24, 0.05, 0.02), 0.005), P.team_plain, Vector3(sx * 0.5, 0.33, hz + sz * 0.15 + 0.005), Vector3.ZERO, true)
	win_row(r, "z", Vector3(0.25, 0.2, hz + sz * 0.15 + 0.008), int((sx - 0.55) / 0.17) + 1, 0.17)
	door(r, "x", Vector3(sx - 0.115, 0.06, hz), 0.18, 0.2)
	vent(r, Vector3(0.4, 0.41, hz), 0.12)
	vent(r, Vector3(sx - 0.45, 0.41, hz), 0.12)
	for i in towers:
		var x := sx * (i + 0.5) / towers
		pipe_run(r, [Vector3(x, 0.24, hz - sz * 0.15), Vector3(x, 0.24, sz * 0.34 + 0.32)], 0.04, M.steel())
	for k in 2:
		var tp := Vector3(sx - 0.16, 0.06, sz * 0.5 + k * 0.17)
		K.add(r, K.bevel_box(Vector3(0.13, 0.12, 0.12), 0.015), K.paint(Color(0.33, 0.38, 0.34), 0.4, 0.5, {"panel": 12.0}), tp + Vector3(0, 0.06, 0))
		for j in 3:
			K.add(r, K.lathe([Vector2(0.01, 0), Vector2(0.018, 0.01), Vector2(0.01, 0.02), Vector2(0.018, 0.03), Vector2(0.01, 0.04), Vector2(0.0, 0.05)], 8), K.paint(Color(0.86, 0.78, 0.62), 0.0, 0.4), tp + Vector3(-0.035 + j * 0.035, 0.12, 0))
	return {"root": r, "height": 1.2, "smoke": [Vector3(sx * 0.25, 1.0, sz * 0.34), Vector3(sx * 0.75, 1.0, sz * 0.34)]}

static func adv_power(P: Dictionary, f: String) -> Dictionary:
	var r := Node3D.new()
	pad(r, 3.0, 3.0, P)
	K.add(r, K.lathe([Vector2(0.75, 0.06), Vector2(0.75, 0.3), Vector2(0.68, 0.55), Vector2(0.5, 0.78), Vector2(0.25, 0.9), Vector2(0.0, 0.93)], 32), K.paint(Color(0.74, 0.74, 0.72) if f == "coalition" else Color(0.6, 0.55, 0.5), 0.1, 0.7, {"panel": 6.0, "panel_dark": 0.18}), Vector3(1.3, 0, 1.25))
	K.add(r, K.lathe([Vector2(0.77, 0.25), Vector2(0.77, 0.32)], 32), P.team_plain, Vector3(1.3, 0, 1.25), Vector3.ZERO, true)
	K.add(r, K.lathe([Vector2(0.12, 0.9), Vector2(0.12, 1.0), Vector2(0.0, 1.02)], 16), M.steel(), Vector3(1.3, 0, 1.25))
	beacon(r, Vector3(1.3, 1.02, 1.25), Color(0.4, 0.9, 1.0))
	for zx in [Vector2(2.45, 0.6), Vector2(2.45, 1.55)]:
		var rad := 0.33
		K.add(r, K.lathe([Vector2(rad, 0.06), Vector2(rad * 0.86, 0.3), Vector2(rad * 0.72, 0.6), Vector2(rad * 0.78, 0.92)], 28, true, false, true), K.paint(Color(0.7, 0.7, 0.68), 0.0, 0.9, {"panel": 9.0, "panel_dark": 0.12, "grime": 0.6}), Vector3(zx.x, 0, zx.y))
		K.add(r, K.cylinder(rad * 0.72, 0.01, 24), K.paint(Color(0.05, 0.05, 0.05), 0.0, 1.0), Vector3(zx.x, 0.9, zx.y))
	block(r, Vector3(1.5, 0.06, 2.6), Vector3(2.6, 0.3, 0.6), P.conc2, P.roof, P.conc)
	win_row(r, "z", Vector3(0.35, 0.2, 2.908), 13, 0.18)
	K.add(r, K.bevel_box(Vector3(2.6, 0.05, 0.02), 0.005), P.team_plain, Vector3(1.5, 0.3, 2.905), Vector3.ZERO, true)
	emblem(r, "z", Vector3(2.55, 0.22, 2.91), 0.09, f)
	pipe_run(r, [Vector3(2.05, 0.25, 1.25), Vector3(2.45, 0.25, 1.25), Vector3(2.45, 0.25, 0.95)], 0.045, M.steel())
	pipe_run(r, [Vector3(2.45, 0.2, 1.25), Vector3(2.45, 0.2, 1.3)], 0.045, M.steel())
	return {"root": r, "height": 1.15, "smoke": [Vector3(2.45, 0.92, 0.6), Vector3(2.45, 0.92, 1.55)]}

static func refinery(P: Dictionary, f: String) -> Dictionary:
	var r := Node3D.new()
	pad(r, 3.0, 3.0, P)
	block(r, Vector3(0.95, 0.06, 0.9), Vector3(1.7, 0.6, 1.6), P.conc2, P.roof, P.conc)
	K.add(r, K.bevel_box(Vector3(1.72, 0.06, 0.03), 0.008), P.team_plain, Vector3(0.95, 0.56, 1.705), Vector3.ZERO, true)
	win_row(r, "z", Vector3(0.22, 0.4, 1.708), 4, 0.15)
	door(r, "z", Vector3(1.3, 0.06, 1.706), 0.55, 0.36, true)
	win_row(r, "x", Vector3(1.808, 0.4, 0.25), 7, 0.18)
	vent(r, Vector3(0.45, 0.67, 0.5))
	vent(r, Vector3(0.95, 0.67, 0.5))
	vent(r, Vector3(1.45, 0.67, 0.5))
	K.add(r, K.lathe([Vector2(0.11, 0.66), Vector2(0.09, 1.4), Vector2(0.1, 1.45)], 12), P.conc, Vector3(0.35, 0, 1.3))
	K.add(r, K.lathe([Vector2(0.1, 1.38), Vector2(0.1, 1.42)], 12), P.trim, Vector3(0.35, 0, 1.3))
	# Twin ore tanks.
	var tank_m := K.paint(Color(0.76, 0.64, 0.36), 0.65, 0.35, {"panel": 7.0, "panel_dark": 0.15})
	for z in [0.55, 1.35]:
		K.add(r, K.lathe([Vector2(0.36, 0.06), Vector2(0.36, 0.95), Vector2(0.32, 1.06), Vector2(0.18, 1.14), Vector2(0.0, 1.16)], 24), tank_m, Vector3(2.45, 0, z))
		K.add(r, K.lathe([Vector2(0.37, 0.7), Vector2(0.37, 0.78)], 24, true, false, false), P.team_plain, Vector3(2.45, 0, z), Vector3.ZERO, true)
		for a in 4:
			var d := Vector3(cos(a * PI * 0.5 + 0.785), 0, sin(a * PI * 0.5 + 0.785)) * 0.34
			K.add(r, K.bevel_box(Vector3(0.05, 0.3, 0.05), 0.008), M.dark(), Vector3(2.45, 0.21, z) + d)
		ladder(r, "x", Vector3(2.81, 0.06, z), 0.9)
	pipe_run(r, [Vector3(1.81, 0.45, 0.55), Vector3(2.1, 0.45, 0.55)], 0.05, M.steel())
	pipe_run(r, [Vector3(1.81, 0.3, 1.35), Vector3(2.1, 0.3, 1.35)], 0.05, M.steel())
	# Dock with conveyor gantry over the collector bay.
	K.add(r, K.bevel_box(Vector3(0.96, 0.03, 0.96), 0.01), K.paint(Color(0.24, 0.24, 0.23), 0.3, 0.8, {"panel": 4.0}), Vector3(1.5, 0.075, 2.5))
	for i in 5:
		K.add(r, K.bevel_box(Vector3(0.9, 0.006, 0.06), 0.002), M.hazard(), Vector3(1.5, 0.093, 2.1 + i * 0.2))
	for x in [1.05, 1.95]:
		K.add(r, K.bevel_box(Vector3(0.07, 0.7, 0.07), 0.01), M.yellow(), Vector3(x, 0.41, 2.15))
	K.add(r, K.bevel_box(Vector3(1.0, 0.12, 0.2), 0.02), M.yellow(), Vector3(1.5, 0.78, 2.15))
	K.add(r, K.bevel_box(Vector3(0.3, 0.12, 1.0), 0.02), M.steel(), Vector3(1.5, 0.72, 1.85), Vector3(22, 0, 0))
	K.add(r, K.bevel_box(Vector3(0.24, 0.02, 0.96), 0.006), K.paint(Color(0.15, 0.15, 0.15), 0.3, 0.6, {"stripes": 35.0}), Vector3(1.5, 0.79, 1.85), Vector3(22, 0, 0))
	beacon(r, Vector3(1.05, 0.77, 2.15), Color(1, 0.6, 0.1))
	beacon(r, Vector3(1.95, 0.77, 2.15), Color(1, 0.6, 0.1))
	barrels(r, Vector3(0.12, 0.06, 2.5), 6, Color(0.55, 0.42, 0.18))
	crates(r, Vector3(2.35, 0.06, 2.45), 5)
	light_post(r, Vector3(0.6, 0.06, 2.75))
	emblem(r, "x", Vector3(1.81, 0.42, 1.55), 0.1, f)
	return {"root": r, "height": 1.5, "smoke": [Vector3(0.35, 1.45, 1.3)]}

static func silo(P: Dictionary, f: String) -> Dictionary:
	var r := Node3D.new()
	pad(r, 1.0, 1.0, P, false)
	var tm := K.paint(Color(0.74, 0.74, 0.72) if f == "coalition" else Color(0.6, 0.55, 0.5), 0.5, 0.45, {"panel": 10.0, "panel_dark": 0.15})
	K.add(r, K.lathe([Vector2(0.34, 0.06), Vector2(0.34, 0.55), Vector2(0.3, 0.64), Vector2(0.15, 0.7), Vector2(0.0, 0.71)], 24), tm, Vector3(0.5, 0, 0.5))
	K.add(r, K.lathe([Vector2(0.35, 0.42), Vector2(0.35, 0.48)], 24), P.team_plain, Vector3(0.5, 0, 0.5), Vector3.ZERO, true)
	K.add(r, K.bevel_box(Vector3(0.03, 0.34, 0.06), 0.006), M.dark(), Vector3(0.84, 0.25, 0.5))
	K.add(r, K.bevel_box(Vector3(0.032, 0.2, 0.04), 0.004), K.paint(Color(0.9, 0.7, 0.2), 0.3, 0.4, {"emit": 0.5}), Vector3(0.85, 0.2, 0.5))
	ladder(r, "z", Vector3(0.5, 0.06, 0.84), 0.55)
	K.add(r, K.cylinder(0.05, 0.05, 10), M.steel(), Vector3(0.5, 0.73, 0.5))
	return {"root": r, "height": 0.8}

static func barracks(P: Dictionary, f: String) -> Dictionary:
	var r := Node3D.new()
	pad(r, 2.0, 2.0, P)
	var wall := K.paint(Color(0.6, 0.56, 0.46), 0.0, 0.9, {"panel": 5.0, "panel_dark": 0.18})
	var roofm := K.paint(Color(0.36, 0.42, 0.28), 0.1, 0.8, {"corrugate": 70.0})
	for z in [0.55, 1.35]:
		K.add(r, K.bevel_box(Vector3(1.6, 0.26, 0.62), 0.02), wall, Vector3(0.95, 0.19, z))
		var rp := [K.plane_at(Vector3.DOWN, Vector3(0, 0.32, 0)), K.plane_at(Vector3(0, 1, 1.3), Vector3(0, 0.32, z + 0.36)),
			K.plane_at(Vector3(0, 1, -1.3), Vector3(0, 0.32, z - 0.36)), K.plane_at(Vector3.RIGHT, Vector3(1.8, 0, 0)), K.plane_at(Vector3.LEFT, Vector3(0.1, 0, 0))]
		K.add(r, K.convex(rp), roofm, Vector3.ZERO)
		win_row(r, "z", Vector3(0.35, 0.22, z + 0.318), 5, 0.3, Vector2(0.09, 0.06), 0.7)
		door(r, "x", Vector3(1.758, 0.06, z), 0.16, 0.2)
		K.add(r, K.bevel_box(Vector3(0.06, 0.02, 0.24), 0.004), P.team_plain, Vector3(1.8, 0.3, z), Vector3.ZERO, true)
	var sand := K.paint(Color(0.66, 0.58, 0.42), 0.0, 1.0, {"noise_amt": 0.4})
	for i in 9:
		K.add(r, K.lathe([Vector2(0.0, 0), Vector2(0.06, 0.02), Vector2(0.065, 0.04), Vector2(0.0, 0.07)], 8), sand, Vector3(0.15 + i * 0.12, 0.06, 1.88), Vector3(0, 0, 90))
	K.tube(r, Vector3(1.88, 0.06, 1.88), Vector3(1.88, 0.95, 1.88), 0.012, M.steel(), 6)
	K.add(r, K.bevel_box(Vector3(0.22, 0.14, 0.008), 0.002), K.paint(Color(0.66, 0.66, 0.66), 0.0, 0.8), Vector3(1.77, 0.86, 1.88), Vector3(0, 0, 0), true)
	crates(r, Vector3(1.6, 0.06, 0.05), 4)
	K.add(r, K.lathe([Vector2(0.0, 0.0), Vector2(0.09, 0.03), Vector2(0.1, 0.05)], 14), M.steel(), Vector3(0.4, 0.5, 0.55), Vector3(-25, 0, 20))
	return {"root": r, "height": 1.0}

static func barracks_dom(P: Dictionary, f: String) -> Dictionary:
	var r := Node3D.new()
	pad(r, 2.0, 2.0, P)
	var bp := [K.plane_at(Vector3.DOWN, Vector3(0, 0.06, 0)), K.plane_at(Vector3.UP, Vector3(0, 0.6, 0)),
		K.plane_at(Vector3(1, 0.35, 0), Vector3(1.82, 0.3, 0)), K.plane_at(Vector3(-1, 0.35, 0), Vector3(0.15, 0.3, 0)),
		K.plane_at(Vector3(0, 0.35, 1), Vector3(0, 0.3, 1.7)), K.plane_at(Vector3(0, 0.35, -1), Vector3(0, 0.3, 0.2))]
	K.add(r, K.convex(bp), P.conc2, Vector3.ZERO)
	K.add(r, K.bevel_box(Vector3(1.3, 0.05, 1.1), 0.01), P.roof, Vector3(0.98, 0.62, 0.95))
	K.add(r, K.bevel_box(Vector3(0.5, 0.35, 0.02), 0.006), P.team_plain, Vector3(1.0, 0.36, 1.752), Vector3(-19, 0, 0), true)
	door(r, "z", Vector3(1.0, 0.06, 1.74), 0.3, 0.24, true)
	for z in [0.55, 1.05, 1.45]:
		K.add(r, K.bevel_box(Vector3(0.016, 0.04, 0.14), 0.003), M.dark(), Vector3(1.86, 0.3, z), Vector3(0, 0, 19))
	var tw := Vector3(0.35, 0.06, 1.6)
	K.add(r, K.bevel_box(Vector3(0.3, 0.75, 0.3), 0.02), P.conc, tw + Vector3(0, 0.375, 0))
	K.add(r, K.bevel_box(Vector3(0.38, 0.06, 0.38), 0.01), P.sec, tw + Vector3(0, 0.78, 0))
	K.add(r, K.bevel_box(Vector3(0.32, 0.1, 0.32), 0.01), M.dark(), tw + Vector3(0, 0.86, 0))
	K.add(r, K.bevel_box(Vector3(0.4, 0.04, 0.4), 0.01), P.trim, tw + Vector3(0, 0.93, 0))
	beacon(r, tw + Vector3(0, 0.95, 0))
	vent(r, Vector3(0.7, 0.64, 0.7))
	vent(r, Vector3(1.3, 0.64, 0.7))
	emblem(r, "x", Vector3(1.75, 0.38, 0.85), 0.11, f)
	barrels(r, Vector3(1.75, 0.06, 0.1), 4, Color(0.4, 0.15, 0.1))
	return {"root": r, "height": 1.1}

static func factory(P: Dictionary, f: String) -> Dictionary:
	var r := Node3D.new()
	pad(r, 3.0, 3.0, P)
	# Barrel-vaulted hangar running along X.
	var arch := PackedVector2Array()
	var hw := 1.0
	arch.append(Vector2(-hw, 0.0))
	for i in 13:
		var a := PI - PI * i / 12.0
		arch.append(Vector2(cos(a) * hw, 0.62 + sin(a) * 0.38))
	arch.append(Vector2(hw, 0.0))
	var hangar := K.extrude(arch, 2.5)
	K.add(r, hangar, K.paint(Color(0.7, 0.73, 0.76) if f == "coalition" else Color(0.62, 0.56, 0.5), 0.2, 0.6, {"corrugate": 120.0, "grime": 0.4}), Vector3(1.45, 0.06, 1.3))
	for k in 5:
		var z := 0.15 + k * 0.6
		K.add(r, K.lathe([Vector2(0.98, -0.02), Vector2(1.03, -0.02), Vector2(1.03, 0.02), Vector2(0.98, 0.02)], 32, false, false, false), P.conc2, Vector3(1.45, 0.68, z), Vector3(90, 0, 0), false, Vector3(1, 1, 0.38))
	for k in 4:
		K.add(r, K.bevel_box(Vector3(0.16, 0.02, 0.36), 0.004), K.paint(Color(0.3, 0.5, 0.62), 0.6, 0.2, {"emit": 0.3}), Vector3(1.45, 1.07, 0.45 + k * 0.6))
	# Front wall with the vehicle door facing +Z (exit at cell 1,3).
	K.add(r, K.extrude(arch, 0.06), P.conc2, Vector3(1.45, 0.06, 2.56))
	door(r, "z", Vector3(1.5, 0.06, 2.595), 0.95, 0.6, true)
	K.add(r, K.bevel_box(Vector3(2.0, 0.07, 0.04), 0.01), P.team_plain, Vector3(1.45, 0.72, 2.6), Vector3.ZERO, true)
	emblem(r, "z", Vector3(0.75, 0.42, 2.6), 0.1, f)
	win_row(r, "z", Vector3(2.08, 0.45, 2.6), 2, 0.16)
	# Side annex offices.
	block(r, Vector3(2.72, 0.06, 1.2), Vector3(0.5, 0.5, 1.8), P.conc, P.roof, P.conc2)
	win_row(r, "x", Vector3(2.978, 0.36, 0.42), 9, 0.18)
	win_row(r, "x", Vector3(2.978, 0.18, 0.42), 9, 0.18, Vector2(0.09, 0.065), 0.4)
	vent(r, Vector3(2.75, 0.57, 0.6), 0.12)
	vent(r, Vector3(2.75, 0.57, 1.4), 0.12)
	for x in [0.3, 2.6]:
		K.add(r, K.lathe([Vector2(0.09, 0.0), Vector2(0.075, 0.9), Vector2(0.085, 0.95)], 12), P.conc2, Vector3(x, 0.06, 0.25))
		K.add(r, K.lathe([Vector2(0.085, 0.82), Vector2(0.085, 0.86)], 12), P.trim, Vector3(x, 0.06, 0.25))
	K.add(r, K.bevel_box(Vector3(1.4, 0.04, 0.5), 0.01), M.hazard(), Vector3(1.5, 0.08, 2.75))
	light_post(r, Vector3(0.75, 0.06, 2.8))
	light_post(r, Vector3(2.25, 0.06, 2.8))
	beacon(r, Vector3(1.0, 0.68, 2.55), Color(1, 0.55, 0.1))
	beacon(r, Vector3(2.0, 0.68, 2.55), Color(1, 0.55, 0.1))
	return {"root": r, "height": 1.4, "smoke": [Vector3(0.3, 1.02, 0.25), Vector3(2.6, 1.02, 0.25)]}

static func radar(P: Dictionary, f: String, t: float) -> Dictionary:
	var r := Node3D.new()
	pad(r, 2.0, 2.0, P)
	block(r, Vector3(1.0, 0.06, 1.4), Vector3(1.7, 0.38, 0.85), P.conc2, P.roof, P.conc)
	win_row(r, "z", Vector3(0.3, 0.25, 1.828), 8, 0.2)
	K.add(r, K.bevel_box(Vector3(1.7, 0.05, 0.02), 0.005), P.team_plain, Vector3(1.0, 0.38, 1.826), Vector3.ZERO, true)
	door(r, "x", Vector3(1.855, 0.06, 1.4), 0.18, 0.22)
	vent(r, Vector3(0.45, 0.45, 1.4), 0.12)
	vent(r, Vector3(1.5, 0.45, 1.4), 0.12)
	var base := Vector3(0.95, 0.06, 0.65)
	for c in [Vector2(-0.12, -0.12), Vector2(0.12, -0.12), Vector2(-0.12, 0.12), Vector2(0.12, 0.12)]:
		K.tube(r, base + Vector3(c.x, 0, c.y), base + Vector3(c.x * 0.35, 0.95, c.y * 0.35), 0.014, M.steel(), 4)
	for i in 5:
		var y := i * 0.19
		var s := 1.0 - y / 1.1
		K.tube(r, base + Vector3(-0.12 * s, y, -0.12 * s), base + Vector3(0.12 * s, y + 0.19, 0.12 * s), 0.006, M.steel(), 4)
		K.tube(r, base + Vector3(0.12 * s, y, -0.12 * s), base + Vector3(-0.12 * s, y + 0.19, 0.12 * s), 0.006, M.steel(), 4)
	K.add(r, K.bevel_box(Vector3(0.18, 0.08, 0.18), 0.015), P.sec, base + Vector3(0, 0.97, 0))
	var dish := K.pivot(r, base + Vector3(0, 1.05, 0))
	dish.rotation.y = -t * TAU
	var holder := K.pivot(dish, Vector3(0.0, 0.18, 0))
	holder.rotation_degrees = Vector3(0, 0, -55)
	var prof := []
	for i in 9:
		var rr := 0.55 * i / 8.0
		prof.append(Vector2(rr, rr * rr * 0.55))
	K.add(holder, K.lathe(prof, 28, true, false, false), K.paint(Color(0.86, 0.88, 0.9), 0.45, 0.4, {"panel": 7.0, "panel_dark": 0.12}), Vector3.ZERO)
	K.add(holder, K.lathe([Vector2(0.553, 0.16), Vector2(0.56, 0.18)], 28, true, false, false), P.team_plain, Vector3.ZERO, Vector3.ZERO, true)
	for a in 3:
		var p := Vector3(cos(a * TAU / 3) * 0.4, 0.09, sin(a * TAU / 3) * 0.4)
		K.tube(holder, p, Vector3(0, 0.35, 0), 0.005, M.dark(), 4)
	K.add(holder, K.cylinder(0.035, 0.06, 10), M.dark(), Vector3(0, 0.36, 0))
	K.tube(dish, Vector3(0, -0.05, 0), Vector3(0, 0.15, 0), 0.03, M.steel(), 8)
	beacon(r, base + Vector3(0.1, 1.02, 0.1))
	for x in [1.55, 1.75]:
		K.tube(r, Vector3(x, 0.44, 1.2), Vector3(x, 0.85, 1.2), 0.005, M.dark(), 4)
	return {"root": r, "height": 1.7}

static func pillbox(P: Dictionary, f: String) -> Dictionary:
	var r := Node3D.new()
	K.add(r, K.lathe([Vector2(0.44, 0.0), Vector2(0.42, 0.18), Vector2(0.34, 0.28), Vector2(0.0, 0.3)], 6, false), P.conc, Vector3(0.5, 0, 0.5), Vector3(0, 30, 0))
	K.add(r, K.lathe([Vector2(0.2, 0.28), Vector2(0.18, 0.34), Vector2(0.0, 0.35)], 12), P.team_plain, Vector3(0.5, 0, 0.5), Vector3.ZERO, true)
	for a in [0.0, 60.0, -60.0]:
		var d := Vector3(cos(deg_to_rad(a)) * 0.37, 0.17, sin(deg_to_rad(a)) * 0.37)
		K.add(r, K.bevel_box(Vector3(0.03, 0.04, 0.18), 0.005), K.paint(Color(0.05, 0.05, 0.05), 0.0, 1.0), Vector3(0.5, 0, 0.5) + d, Vector3(0, -a, 0))
	K.tube(r, Vector3(0.87, 0.17, 0.5), Vector3(1.0, 0.17, 0.5), 0.01, M.dark(), 6)
	var sand := K.paint(Color(0.66, 0.58, 0.42), 0.0, 1.0, {"noise_amt": 0.4})
	for i in 5:
		K.add(r, K.lathe([Vector2(0.0, 0), Vector2(0.05, 0.02), Vector2(0.055, 0.035), Vector2(0.0, 0.06)], 8), sand, Vector3(0.1 + i * 0.1, 0.03, 0.95), Vector3(0, 0, 90))
	return {"root": r, "height": 0.45}

static func gun_base(P: Dictionary, f: String) -> Dictionary:
	var r := Node3D.new()
	K.add(r, K.lathe([Vector2(0.46, 0.0), Vector2(0.46, 0.08), Vector2(0.4, 0.2), Vector2(0.0, 0.21)], 8, false), P.conc2, Vector3(0.5, 0, 0.5), Vector3(0, 22.5, 0))
	K.add(r, K.cylinder(0.3, 0.03, 20), M.dark(), Vector3(0.5, 0.22, 0.5))
	return {"root": r, "height": 0.25, "pivot": Vector3(0.5, 0.22, 0.5)}

static func gun_turret_top(P: Dictionary, f: String) -> Node3D:
	var t := Node3D.new()
	var tp := [K.plane_at(Vector3.DOWN, Vector3(0, 0, 0)), K.plane_at(Vector3.UP, Vector3(0, 0.2, 0)),
		K.plane_at(Vector3(1, 0.7, 0), Vector3(0.2, 0.1, 0)), K.plane_at(Vector3(-1, 0.1, 0), Vector3(-0.24, 0.1, 0)),
		K.plane_at(Vector3(0, 0.3, 1), Vector3(0, 0.1, 0.2)), K.plane_at(Vector3(0, 0.3, -1), Vector3(0, 0.1, -0.2)),
		K.plane_at(Vector3(0.7, 0.3, 0.7), Vector3(0.12, 0.1, 0.15)), K.plane_at(Vector3(0.7, 0.3, -0.7), Vector3(0.12, 0.1, -0.15))]
	K.add(t, K.convex(tp), P.team, Vector3.ZERO, Vector3.ZERO, true)
	K.add(t, K.bevel_box(Vector3(0.08, 0.12, 0.18), 0.015), P.sec, Vector3(0.22, 0.1, 0))
	K.add(t, K.cylinder(0.03, 0.55, 10), P.sec_plain, Vector3(0.5, 0.1, 0), Vector3(0, 0, 90))
	K.add(t, K.lathe([Vector2(0.04, 0), Vector2(0.045, 0.03), Vector2(0.04, 0.07), Vector2(0, 0.07)], 10), M.dark(), Vector3(0.76, 0.1, 0), Vector3(0, 0, -90))
	K.add(t, K.bevel_box(Vector3(0.12, 0.02, 0.12), 0.004), P.sec, Vector3(-0.08, 0.205, 0.06))
	return t

static func flame_base(P: Dictionary, f: String) -> Dictionary:
	var r := Node3D.new()
	K.add(r, K.lathe([Vector2(0.42, 0.0), Vector2(0.4, 0.1), Vector2(0.3, 0.16), Vector2(0.28, 0.6), Vector2(0.32, 0.64), Vector2(0.0, 0.66)], 10, false), P.conc, Vector3(0.5, 0, 0.5))
	K.add(r, K.lathe([Vector2(0.33, 0.5), Vector2(0.33, 0.56)], 10, false), P.team_plain, Vector3(0.5, 0, 0.5), Vector3.ZERO, true)
	var fm := K.paint(Color(0.62, 0.22, 0.14), 0.5, 0.45)
	for z in [0.25, 0.75]:
		K.add(r, K.lathe([Vector2(0.07, 0), Vector2(0.07, 0.28), Vector2(0.05, 0.32), Vector2(0, 0.33)], 12), fm, Vector3(0.12, 0.0, z))
	pipe_run(r, [Vector3(0.12, 0.3, 0.25), Vector3(0.3, 0.45, 0.4)], 0.015, M.dark())
	return {"root": r, "height": 0.8, "pivot": Vector3(0.5, 0.66, 0.5)}

static func flame_turret_top(P: Dictionary, f: String) -> Node3D:
	var t := Node3D.new()
	K.add(t, K.lathe([Vector2(0.16, 0), Vector2(0.15, 0.08), Vector2(0.08, 0.12), Vector2(0, 0.13)], 12), P.sec_plain, Vector3.ZERO)
	K.add(t, K.cylinder(0.035, 0.32, 10), M.dark(), Vector3(0.2, 0.06, 0), Vector3(0, 0, 90))
	K.add(t, K.lathe([Vector2(0.03, 0), Vector2(0.05, 0.05), Vector2(0, 0.05)], 10), M.dark(), Vector3(0.36, 0.06, 0), Vector3(0, 0, -90))
	K.add(t, K.cylinder(0.014, 0.01, 6), M.light(Color(1, 0.5, 0.1)), Vector3(0.41, 0.06, 0), Vector3(0, 0, 90))
	return t

static func arc_coil(P: Dictionary, f: String, charge: float) -> Dictionary:
	var r := Node3D.new()
	K.add(r, K.bevel_box(Vector3(0.9, 0.22, 1.8), 0.03), P.conc2, Vector3(0.5, 0.11, 1.0))
	K.add(r, K.lathe([Vector2(0.36, 0.22), Vector2(0.32, 0.4), Vector2(0.18, 0.5)], 12), P.conc, Vector3(0.5, 0, 1.25))
	K.add(r, K.lathe([Vector2(0.14, 0.45), Vector2(0.1, 1.9), Vector2(0.0, 1.95)], 12), M.dark(), Vector3(0.5, 0, 1.25))
	var copper := K.paint(Color(0.82, 0.5, 0.26), 0.9, 0.3)
	for i in 8:
		var tor := TorusMesh.new()
		tor.inner_radius = 0.12
		tor.outer_radius = 0.24 - i * 0.012
		tor.rings = 24
		tor.ring_segments = 8
		K.add(r, tor, copper, Vector3(0.5, 0.62 + i * 0.16, 1.25))
	K.add(r, K.lathe([Vector2(0.0, -0.18), Vector2(0.15, -0.12), Vector2(0.18, 0.0), Vector2(0.15, 0.12), Vector2(0.0, 0.18)], 16), M.steel(), Vector3(0.5, 2.0, 1.25))
	K.add(r, K.lathe([Vector2(0.0, -0.12), Vector2(0.11, -0.08), Vector2(0.13, 0.0), Vector2(0.11, 0.08), Vector2(0.0, 0.12)], 14),
		K.paint(Color(0.55, 0.82, 1.0), 0.0, 0.3, {"emit": 0.4 + 3.5 * charge}), Vector3(0.5, 2.0, 1.25), Vector3.ZERO, false, Vector3(1.25, 1.25, 1.25))
	block(r, Vector3(0.5, 0.22, 0.4), Vector3(0.6, 0.2, 0.5), P.conc, P.team_plain)
	K.add(r, K.bevel_box(Vector3(0.62, 0.03, 0.52), 0.006), P.team_plain, Vector3(0.5, 0.44, 0.4), Vector3.ZERO, true)
	door(r, "z", Vector3(0.5, 0.22, 0.655), 0.18, 0.14)
	for z in [0.75, 1.75]:
		pipe_run(r, [Vector3(0.12, 0.25, z), Vector3(0.12, 0.25, 1.25), Vector3(0.36, 0.3, 1.25)], 0.025, copper)
	return {"root": r, "height": 2.3}

# ---------------------------------------------------------------- decorations

static func tree(kind: int, seed_v: int) -> Node3D:
	var r := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var bark := K.paint(Color(0.34, 0.25, 0.16), 0.0, 0.9, {"noise_amt": 0.4})
	if kind == 0:
		K.add(r, K.lathe([Vector2(0.05, 0), Vector2(0.035, 0.3), Vector2(0.02, 0.45)], 8), bark, Vector3.ZERO)
		for i in 7:
			var g := Color(0.2, 0.36, 0.12).lightened(rng.randf_range(-0.08, 0.14))
			var leaf := K.paint(g, 0.0, 0.85, {"noise_amt": 0.7, "grime": 0.0})
			var p := Vector3(rng.randf_range(-0.16, 0.16), rng.randf_range(0.42, 0.66), rng.randf_range(-0.16, 0.16))
			var s := rng.randf_range(0.17, 0.26)
			K.add(r, K.lathe([Vector2(0.0, -s), Vector2(s * 0.75, -s * 0.6), Vector2(s, 0), Vector2(s * 0.8, s * 0.55), Vector2(0, s * 0.9)], 9, true), leaf, p, Vector3(rng.randf() * 30, rng.randf() * 360, 0))
	elif kind == 1:
		K.add(r, K.lathe([Vector2(0.04, 0), Vector2(0.03, 0.2)], 8), bark, Vector3.ZERO)
		for i in 4:
			var g := Color(0.12, 0.27, 0.13).lightened(i * 0.04 + rng.randf_range(-0.03, 0.03))
			var y := 0.14 + i * 0.17
			var rr := 0.3 - i * 0.06
			K.add(r, K.lathe([Vector2(rr, 0), Vector2(rr * 0.7, 0.08), Vector2(0.0, 0.3)], 10), K.paint(g, 0.0, 0.85, {"noise_amt": 0.6, "grime": 0.0}), Vector3(0, y, 0), Vector3(0, rng.randf() * 360, 0))
	else:
		for i in 5:
			var g := Color(0.26, 0.38, 0.15).lightened(rng.randf_range(-0.08, 0.1))
			var s := rng.randf_range(0.08, 0.13)
			K.add(r, K.lathe([Vector2(0.0, -s * 0.5), Vector2(s, 0), Vector2(s * 0.7, s * 0.6), Vector2(0, s)], 8), K.paint(g, 0.0, 0.9, {"noise_amt": 0.6, "grime": 0.0}), Vector3(rng.randf_range(-0.12, 0.12), s * 0.6, rng.randf_range(-0.12, 0.12)))
	return r

static func rock(big: bool, seed_v: int) -> Node3D:
	var r := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n := 4 if big else 2
	for i in n:
		var s := rng.randf_range(0.12, 0.22) * (1.8 if big else 1.0)
		var planes := []
		for k in 14:
			var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 1), rng.randf_range(-1, 1)).normalized()
			planes.append(K.plane_at(d, d * s * rng.randf_range(0.75, 1.0)))
		planes.append(K.plane_at(Vector3.DOWN, Vector3(0, 0, 0)))
		var c := Color(0.5, 0.47, 0.42).lightened(rng.randf_range(-0.1, 0.08))
		K.add(r, K.convex(planes), K.paint(c, 0.0, 0.9, {"noise_amt": 0.5, "grime": 0.2}), Vector3(rng.randf_range(-0.2, 0.2) * (1.6 if big else 1.0), 0, rng.randf_range(-0.2, 0.2) * (1.6 if big else 1.0)))
	return r

static func prop(kind: String, seed_v: int) -> Node3D:
	var r := Node3D.new()
	match kind:
		"crates":
			crates(r, Vector3(-0.1, 0, -0.08), 5)
		"barrels":
			barrels(r, Vector3(-0.07, 0, -0.06), 6, [Color(0.55, 0.2, 0.12), Color(0.3, 0.42, 0.3), Color(0.55, 0.45, 0.18)][seed_v % 3])
		"fence":
			for i in 5:
				K.tube(r, Vector3(-0.4 + i * 0.2, 0, 0), Vector3(-0.4 + i * 0.2, 0.2, 0), 0.008, M.steel(), 4)
			K.add(r, K.bevel_box(Vector3(0.8, 0.18, 0.005), 0.001), K.paint(Color(0.5, 0.52, 0.52), 0.6, 0.5, {"stripes": 60.0}), Vector3(0, 0.1, 0))
		"sandbags":
			var sand := K.paint(Color(0.66, 0.58, 0.42), 0.0, 1.0, {"noise_amt": 0.4})
			for row in 2:
				for i in 5 - row:
					K.add(r, K.lathe([Vector2(0.0, 0), Vector2(0.05, 0.02), Vector2(0.055, 0.035), Vector2(0.0, 0.06)], 8), sand, Vector3(-0.2 + i * 0.1 + row * 0.05, 0.03 + row * 0.05, 0), Vector3(0, 0, 90))
		"wreck":
			var d: Dictionary = M.jeep("coalition")
			r.add_child(d.root)
			d.root.rotation_degrees = Vector3(8, 40, 12)
			for mi in d.root.find_children("*", "MeshInstance3D", true, false):
				mi.material_override = K.paint(Color(0.2, 0.18, 0.16), 0.3, 0.8, {"noise_amt": 0.6, "burn": 1.0})
				mi.set_meta("team", false)
		"lamp":
			light_post(r, Vector3.ZERO)
	return r
