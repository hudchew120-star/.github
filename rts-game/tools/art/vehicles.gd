class_name VehicleModels
extends RefCounted
## Faction-specific war machines for the sprite baker (units face +X, ground at y = 0).
## Coalition ("the good side"): clean modern western engineering - flat faceted armour,
##   side skirts, sand and blue-grey paint, sensors and optics everywhere.
## Dominion ("the evil side"): brutal eastern heavy metal - rounded cast turrets,
##   reactive armour bricks, rivets, fuel drums, red stars, dark olive and rust.
## Every builder returns {root, turret (Node3D or null), pivot (Vector3)}.

const K := preload("res://tools/art/kit.gd")
const M := preload("res://tools/art/hd_models.gd")

# ---------------------------------------------------------------- materials

static func mats(f: String) -> Dictionary:
	if f == "dominion":
		return {
			"team": K.paint(Color(0.64, 0.64, 0.64), 0.3, 0.5, {"noise_amt": 0.28, "grime": 0.5}),
			"team_panel": K.paint(Color(0.64, 0.64, 0.64), 0.3, 0.5, {"panel": 7.0, "panel_dark": 0.2, "noise_amt": 0.28}),
			"team_rivet": K.paint(Color(0.64, 0.64, 0.64), 0.3, 0.5, {"rivets": 26.0, "noise_amt": 0.3}),
			"sec": K.paint(Color(0.3, 0.31, 0.24), 0.35, 0.6, {"noise_amt": 0.35, "grime": 0.6}),
			"sec_rivet": K.paint(Color(0.3, 0.31, 0.24), 0.35, 0.6, {"rivets": 30.0, "noise_amt": 0.35}),
			"era": K.paint(Color(0.36, 0.37, 0.28), 0.3, 0.6, {"panel": 22.0, "panel_dark": 0.5}),
			"rust": K.paint(Color(0.42, 0.24, 0.14), 0.3, 0.75, {"noise_amt": 0.5}),
			"accent": K.paint(Color(0.72, 0.1, 0.08), 0.1, 0.55, {"emit": 0.1}),
			"glass": K.paint(Color(0.22, 0.34, 0.3), 0.75, 0.1, {"noise_amt": 0.04}),
		}
	return {
		"team": K.paint(Color(0.66, 0.66, 0.66), 0.25, 0.45, {"noise_amt": 0.16}),
		"team_panel": K.paint(Color(0.66, 0.66, 0.66), 0.25, 0.45, {"panel": 6.0, "panel_dark": 0.2, "noise_amt": 0.16}),
		"team_rivet": K.paint(Color(0.66, 0.66, 0.66), 0.25, 0.45, {"panel": 9.0, "panel_dark": 0.15, "noise_amt": 0.16}),
		"sec": K.paint(Color(0.62, 0.57, 0.45), 0.2, 0.6, {"noise_amt": 0.2}),
		"sec_rivet": K.paint(Color(0.62, 0.57, 0.45), 0.2, 0.6, {"panel": 8.0, "noise_amt": 0.2}),
		"era": K.paint(Color(0.55, 0.52, 0.42), 0.2, 0.6, {"panel": 14.0, "panel_dark": 0.3}),
		"rust": K.paint(Color(0.4, 0.42, 0.44), 0.4, 0.5),
		"accent": K.paint(Color(0.2, 0.55, 0.85), 0.2, 0.4, {"emit": 0.2}),
		"glass": K.paint(Color(0.2, 0.42, 0.52), 0.8, 0.08, {"noise_amt": 0.03}),
	}

static func dark() -> ShaderMaterial: return K.paint(Color(0.13, 0.13, 0.14), 0.6, 0.45)
static func steel() -> ShaderMaterial: return K.paint(Color(0.55, 0.57, 0.6), 0.75, 0.32)
static func rubber() -> ShaderMaterial: return K.paint(Color(0.09, 0.09, 0.09), 0.0, 0.92)
static func track() -> ShaderMaterial: return K.paint(Color(0.17, 0.16, 0.15), 0.5, 0.7, {"tread": 90.0, "noise_amt": 0.15})
static func lamp(c: Color = Color(1, 0.92, 0.7)) -> ShaderMaterial: return K.paint(c, 0.0, 0.3, {"emit": 2.6, "noise_amt": 0.0})

# ---------------------------------------------------------------- armour shapes

## Crisp faceted armoured hull: sloped glacis, lower nose plate, slanted sides with top
## chamfers and clipped front corners. hb/ht: bottom/top heights. g: glacis slope (higher = flatter).
static func armor_hull(L: float, W: float, hb: float, ht: float, g: float = 1.6, inset: float = 0.035) -> ArrayMesh:
	var mid := (hb + ht) * 0.5
	var planes := [
		K.plane_at(Vector3.DOWN, Vector3(0, hb, 0)), K.plane_at(Vector3.UP, Vector3(0, ht, 0)),
		K.plane_at(Vector3(0, 0.12, 1), Vector3(0, mid, W * 0.5)), K.plane_at(Vector3(0, 0.12, -1), Vector3(0, mid, -W * 0.5)),
		K.plane_at(Vector3(1, g, 0), Vector3(L * 0.5, hb + (ht - hb) * 0.4, 0)), K.plane_at(Vector3(1, -0.9, 0), Vector3(L * 0.5, hb + (ht - hb) * 0.4, 0)),
		K.plane_at(Vector3(-1, 0.25, 0), Vector3(-L * 0.5, mid, 0)), K.plane_at(Vector3(-1, 1.2, 0), Vector3(-L * 0.5 + inset, ht, 0)),
		K.plane_at(Vector3(0, 1, 1.5), Vector3(0, ht, W * 0.5 - inset)), K.plane_at(Vector3(0, 1, -1.5), Vector3(0, ht, -W * 0.5 + inset)),
		K.plane_at(Vector3(1, 0, 1), Vector3(L * 0.5 - inset, 0, W * 0.5)), K.plane_at(Vector3(1, 0, -1), Vector3(L * 0.5 - inset, 0, -W * 0.5)),
		K.plane_at(Vector3(-1, 0, 1), Vector3(-L * 0.5 + inset * 0.6, 0, W * 0.5)), K.plane_at(Vector3(-1, 0, -1), Vector3(-L * 0.5 + inset * 0.6, 0, -W * 0.5)),
	]
	return K.convex(planes)

static func mirror(poly: PackedVector2Array, side: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in poly:
		out.append(Vector2(q.x, q.y * side))
	return out

static func rocks(root: Node3D, center: Vector3, ext: Vector2, n: int) -> void:
	var ore := K.paint(Color(0.9, 0.68, 0.2), 0.75, 0.3, {"noise_amt": 0.7})
	var gem := K.paint(Color(0.95, 0.8, 0.35), 0.85, 0.2, {"noise_amt": 0.5})
	for i in n:
		var fx := fmod(sin(i * 12.9898) * 43758.5453, 1.0)
		var fz := fmod(sin(i * 78.233) * 12543.873, 1.0)
		fx = (fx if fx >= 0.0 else fx + 1.0) - 0.5
		fz = (fz if fz >= 0.0 else fz + 1.0) - 0.5
		var sz := 0.03 + fmod(i * 0.237, 0.03)
		K.add(root, K.lathe([Vector2(0.0, -0.6), Vector2(0.9, -0.3), Vector2(1.0, 0.2), Vector2(0.5, 0.7), Vector2(0.0, 0.8)], 5, false), ore if i % 3 else gem,
			center + Vector3(fx * ext.x, sz * 0.4, fz * ext.y), Vector3(fmod(i * 37.0, 40.0) - 20.0, i * 47.0, fmod(i * 23.0, 30.0) - 15.0), false, Vector3(sz, sz * 0.8, sz * 1.1))

# ---------------------------------------------------------------- running gear

## Track unit on both sides. wheels: number of road wheels, r: wheel radius.
static func tracks(root: Node3D, L: float, W: float, tw: float, n: int, r: float, f: String, skirt: Material = null) -> void:
	var hub := steel()
	for side in [-1.0, 1.0]:
		var z: float = side * (W * 0.5 - tw * 0.5)
		K.add(root, K.extrude(K.stadium(-L * 0.5, L * 0.5, 0.0, r * 2.0 + 0.03, 10), tw), track(), Vector3(0, 0, z))
		for i in n:
			var x := -L * 0.5 + r * 1.35 + i * (L - r * 2.7) / (n - 1)
			var wr := r * (1.12 if f == "dominion" else 1.0)
			K.add(root, K.lathe([Vector2(wr * 0.98, -tw * 0.42), Vector2(wr, -tw * 0.3), Vector2(wr, tw * 0.3), Vector2(wr * 0.98, tw * 0.42)], 18, true, true, true), rubber(), Vector3(x, r + 0.015, z), Vector3(90, 0, 0))
			K.add(root, K.lathe([Vector2(wr * 0.8, 0.0), Vector2(wr * 0.62, 0.012), Vector2(wr * 0.25, 0.016), Vector2(0.0, 0.022)], 16), hub, Vector3(x, r + 0.015, z + side * tw * 0.42), Vector3(side * 90.0, 0, 0))
		# Drive sprocket with teeth at the rear, idler at the front.
		var sp := Vector3(-L * 0.5 + r * 0.9, r * 1.35, z)
		K.add(root, K.cylinder(r * 0.82, tw * 0.9, 16), dark(), sp, Vector3(90, 0, 0))
		for k in 10:
			var a := TAU * k / 10.0
			K.add(root, K.bevel_box(Vector3(r * 0.25, r * 0.25, tw * 0.7), 0.003), dark(), sp + Vector3(cos(a), sin(a), 0) * r * 0.85, Vector3(0, 0, rad_to_deg(a)))
		K.add(root, K.cylinder(r * 0.7, tw * 0.88, 16), hub, Vector3(L * 0.5 - r * 0.85, r * 1.3, z), Vector3(90, 0, 0))
		if skirt != null:
			var sk := K.extrude(PackedVector2Array([Vector2(-L * 0.5, r * 2.0 + 0.04), Vector2(L * 0.5 + 0.02, r * 2.0 + 0.04), Vector2(L * 0.44, r * 0.95), Vector2(-L * 0.48, r * 0.95)]), 0.014)
			K.add(root, sk, skirt, Vector3(0, 0, z + side * (tw * 0.5 + 0.008)), Vector3.ZERO, skirt.get_meta("team", false) if skirt.has_meta("team") else false)

static func tyre(root: Node3D, p: Vector3, r: float, w: float, side: float) -> void:
	K.add(root, K.lathe([Vector2(r * 0.7, -w * 0.5), Vector2(r * 0.95, -w * 0.48), Vector2(r, -w * 0.3), Vector2(r, w * 0.3), Vector2(r * 0.95, w * 0.48), Vector2(r * 0.7, w * 0.5)], 18), K.paint(Color(0.1, 0.1, 0.1), 0.0, 0.9, {"tread": 160.0}), p, Vector3(90, 0, 0))
	K.add(root, K.lathe([Vector2(r * 0.62, 0.0), Vector2(r * 0.55, 0.01), Vector2(r * 0.2, 0.014), Vector2(0.0, 0.02)], 14), steel(), p + Vector3(0, 0, side * w * 0.45), Vector3(side * 90.0, 0, 0))

static func smoke_launchers(t: Node3D, p: Vector3, side: float, n: int = 3) -> void:
	for i in n:
		K.add(t, K.cylinder(0.012, 0.05, 8), dark(), p + Vector3(i * 0.022, 0.0, 0), Vector3(-side * 60.0, 0, 0))

static func barrel(t: Node3D, start: Vector3, length: float, r: float, mat: Material, sleeve: bool, brake: bool) -> void:
	K.add(t, K.lathe([Vector2(r * 1.6, 0.0), Vector2(r * 1.5, length * 0.12), Vector2(r * 1.05, length * 0.18), Vector2(r, length), Vector2(0.0, length)], 14), mat, start, Vector3(0, 0, -90))
	if sleeve:
		K.add(t, K.lathe([Vector2(r * 1.15, 0.0), Vector2(r * 1.6, 0.03), Vector2(r * 1.6, 0.12), Vector2(r * 1.15, 0.15)], 14, true, false, false), mat, start + Vector3(length * 0.48, 0, 0), Vector3(0, 0, -90))
	if brake:
		K.add(t, K.bevel_box(Vector3(0.07, r * 2.6, r * 3.2), 0.006), dark(), start + Vector3(length - 0.02, 0, 0))
	else:
		K.add(t, K.lathe([Vector2(r * 1.25, 0.0), Vector2(r * 1.3, 0.03), Vector2(r * 0.7, 0.031)], 12), dark(), start + Vector3(length - 0.028, 0, 0), Vector3(0, 0, -90))

static func mg(t: Node3D, p: Vector3, f: String) -> void:
	K.add(t, K.bevel_box(Vector3(0.07, 0.03, 0.025), 0.005), dark(), p)
	K.add(t, K.cylinder(0.006, 0.14, 6), dark(), p + Vector3(0.1, 0.005, 0), Vector3(0, 0, 90))
	if f == "coalition":
		K.add(t, K.bevel_box(Vector3(0.05, 0.04, 0.05), 0.006), dark(), p + Vector3(-0.02, 0.035, 0))   # remote weapon station optics
		K.add(t, K.cylinder(0.012, 0.004, 10), K.paint(Color(0.3, 0.5, 0.6), 0.9, 0.1), p + Vector3(0.006, 0.04, 0.0), Vector3(0, 0, 90))

static func antenna(t: Node3D, p: Vector3, h: float) -> void:
	K.add(t, K.cylinder(0.012, 0.02, 8), dark(), p)
	K.tube(t, p, p + Vector3(-0.04, h, 0), 0.0035, dark(), 4)

static func red_star(t: Node3D, p: Vector3, r: float, rot: Vector3) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := PI * 0.5 + TAU * i / 10.0
		var rr := r if i % 2 == 0 else r * 0.42
		pts.append(Vector2(cos(a) * rr, sin(a) * rr))
	K.add(t, K.extrude(pts, 0.004), K.paint(Color(0.8, 0.08, 0.06), 0.1, 0.5, {"emit": 0.15}), p, rot)

static func roundel(t: Node3D, p: Vector3, r: float, rot: Vector3) -> void:
	K.add(t, K.cylinder(r, 0.004, 18), K.paint(Color(0.92, 0.92, 0.9), 0.0, 0.5), p, rot)
	K.add(t, K.cylinder(r * 0.62, 0.006, 18), K.paint(Color(0.15, 0.32, 0.62), 0.1, 0.4), p, rot)

# ---------------------------------------------------------------- coalition armour

## "Lynx" light tank: low wedge hull, compact turret with an autocannon and twin missile box.
static func light_tank() -> Dictionary:
	var C := mats("coalition")
	var root := Node3D.new()
	var L := 0.66
	var W := 0.5
	tracks(root, L, W, 0.12, 5, 0.045, "coalition", C.sec)
	K.add(root, armor_hull(L * 1.04, W * 0.9, 0.1, 0.232, 2.4), C.team_panel, Vector3.ZERO, Vector3.ZERO, true)
	K.add(root, K.bevel_box(Vector3(0.16, 0.012, W * 0.5), 0.004), K.paint(Color(0.15, 0.15, 0.15), 0.4, 0.6, {"stripes": 40.0}), Vector3(-L * 0.33, 0.232, 0))
	for z in [-0.12, 0.12]:
		K.add(root, K.cylinder(0.014, 0.008, 10), lamp(), Vector3(L * 0.5, 0.17, z), Vector3(0, 0, 90))
	K.add(root, K.bevel_box(Vector3(0.06, 0.02, 0.07), 0.006), K.paint(Color(0.2, 0.42, 0.52), 0.8, 0.1), Vector3(L * 0.3, 0.232, -0.1))
	var tur := Node3D.new()
	var tp := [K.plane_at(Vector3.DOWN, Vector3.ZERO), K.plane_at(Vector3.UP, Vector3(0, 0.1, 0)),
		K.plane_at(Vector3(1, 0.7, 0), Vector3(0.13, 0.05, 0)), K.plane_at(Vector3(-1, 0.1, 0), Vector3(-0.16, 0.05, 0)),
		K.plane_at(Vector3(0, 0.25, 1), Vector3(0, 0.05, 0.13)), K.plane_at(Vector3(0, 0.25, -1), Vector3(0, 0.05, -0.13)),
		K.plane_at(Vector3(0.8, 0.3, 0.6), Vector3(0.08, 0.05, 0.11)), K.plane_at(Vector3(0.8, 0.3, -0.6), Vector3(0.08, 0.05, -0.11))]
	K.add(tur, K.convex(tp), C.team_panel, Vector3.ZERO, Vector3.ZERO, true)
	barrel(tur, Vector3(0.12, 0.05, 0.0), 0.34, 0.014, dark(), false, false)
	K.add(tur, K.bevel_box(Vector3(0.05, 0.05, 0.05), 0.01), C.sec, Vector3(0.13, 0.05, 0))
	# Twin missile launcher box on the left, panoramic sight on the right.
	K.add(tur, K.bevel_box(Vector3(0.2, 0.06, 0.06), 0.01), C.sec, Vector3(-0.02, 0.12, -0.14))
	for z in [-0.155, -0.125]:
		K.add(tur, K.cylinder(0.012, 0.005, 10), dark(), Vector3(0.081, 0.12, z), Vector3(0, 0, 90))
	K.add(tur, K.lathe([Vector2(0.03, 0.0), Vector2(0.03, 0.04), Vector2(0.024, 0.06)], 12), C.sec, Vector3(-0.03, 0.1, 0.07))
	K.add(tur, K.bevel_box(Vector3(0.035, 0.03, 0.05), 0.006), K.paint(Color(0.2, 0.42, 0.52), 0.8, 0.1), Vector3(-0.01, 0.175, 0.07))
	smoke_launchers(tur, Vector3(0.0, 0.09, 0.13), 1.0)
	smoke_launchers(tur, Vector3(0.0, 0.09, -0.13), -1.0)
	antenna(tur, Vector3(-0.13, 0.1, 0.09), 0.3)
	return {"root": root, "turret": tur, "pivot": Vector3(-0.03, 0.225, 0)}

## "Paladin" main battle tank: long flat hull with skirts, wide faceted turret, long 120 mm gun.
static func medium_tank() -> Dictionary:
	var C := mats("coalition")
	var root := Node3D.new()
	var L := 0.82
	var W := 0.56
	var sk: ShaderMaterial = C.team_rivet
	tracks(root, L, W, 0.13, 7, 0.042, "coalition", sk)
	K.add(root, armor_hull(L * 1.04, W * 0.88, 0.1, 0.24, 2.8), C.team_panel, Vector3.ZERO, Vector3.ZERO, true)
	K.add(root, K.bevel_box(Vector3(0.2, 0.012, W * 0.62), 0.004), K.paint(Color(0.15, 0.15, 0.15), 0.4, 0.6, {"stripes": 44.0}), Vector3(-L * 0.36, 0.24, 0))
	for z in [-0.17, 0.17]:
		K.add(root, K.cylinder(0.016, 0.008, 10), lamp(), Vector3(L * 0.49, 0.18, z), Vector3(0, 0, 90))
		K.add(root, K.bevel_box(Vector3(0.05, 0.03, 0.05), 0.006), C.sec, Vector3(L * 0.44, 0.215, z))
	K.add(root, K.bevel_box(Vector3(0.05, 0.015, 0.08), 0.004), K.paint(Color(0.2, 0.42, 0.52), 0.8, 0.1), Vector3(L * 0.36, 0.242, 0.0))
	# Tow cable along the side.
	K.tube(root, Vector3(-L * 0.4, 0.24, W * 0.4), Vector3(L * 0.3, 0.24, W * 0.4), 0.007, dark(), 6)
	var tur := Node3D.new()
	var tp := [K.plane_at(Vector3.DOWN, Vector3.ZERO), K.plane_at(Vector3.UP, Vector3(0, 0.1, 0)),
		K.plane_at(Vector3(1, 0.25, 0), Vector3(0.19, 0.05, 0)), K.plane_at(Vector3(-1, 0.0, 0), Vector3(-0.27, 0.05, 0)),
		K.plane_at(Vector3(0, 0.15, 1), Vector3(0, 0.05, 0.17)), K.plane_at(Vector3(0, 0.15, -1), Vector3(0, 0.05, -0.17)),
		K.plane_at(Vector3(1, 0.1, 1.6), Vector3(0.14, 0.05, 0.14)), K.plane_at(Vector3(1, 0.1, -1.6), Vector3(0.14, 0.05, -0.14)),
		K.plane_at(Vector3(-0.5, 0.2, 1), Vector3(-0.23, 0.05, 0.15)), K.plane_at(Vector3(-0.5, 0.2, -1), Vector3(-0.23, 0.05, -0.15))]
	K.add(tur, K.convex(tp), C.team_panel, Vector3.ZERO, Vector3.ZERO, true)
	K.add(tur, K.bevel_box(Vector3(0.07, 0.07, 0.1), 0.012), C.sec, Vector3(0.18, 0.045, 0))
	barrel(tur, Vector3(0.2, 0.05, 0.0), 0.5, 0.017, C.sec, true, false)
	# Bustle rack, commander's independent viewer, gunner's sight, remote weapon station.
	K.add(tur, K.bevel_box(Vector3(0.12, 0.05, 0.3), 0.01), K.paint(Color(0.15, 0.15, 0.15), 0.5, 0.6, {"panel": 30.0, "panel_dark": 0.6}), Vector3(-0.31, 0.06, 0))
	K.add(tur, K.bevel_box(Vector3(0.1, 0.04, 0.12), 0.01), C.sec, Vector3(-0.3, 0.08, 0.05))
	K.add(tur, K.bevel_box(Vector3(0.06, 0.035, 0.05), 0.008), C.sec, Vector3(0.1, 0.12, -0.1))
	K.add(tur, K.bevel_box(Vector3(0.006, 0.026, 0.04), 0.002), K.paint(Color(0.2, 0.42, 0.52), 0.8, 0.1), Vector3(0.132, 0.12, -0.1))
	K.add(tur, K.lathe([Vector2(0.045, 0.0), Vector2(0.045, 0.03), Vector2(0.035, 0.045)], 14), C.sec, Vector3(-0.08, 0.1, 0.08))
	mg(tur, Vector3(-0.07, 0.17, 0.08), "coalition")
	K.add(tur, K.cylinder(0.025, 0.06, 12), C.sec, Vector3(-0.03, 0.13, -0.05))
	K.add(tur, K.bevel_box(Vector3(0.04, 0.035, 0.04), 0.006), dark(), Vector3(-0.03, 0.17, -0.05))
	smoke_launchers(tur, Vector3(0.03, 0.09, 0.165), 1.0, 4)
	smoke_launchers(tur, Vector3(0.03, 0.09, -0.165), -1.0, 4)
	antenna(tur, Vector3(-0.22, 0.1, 0.13), 0.32)
	antenna(tur, Vector3(-0.22, 0.1, -0.13), 0.26)
	return {"root": root, "turret": tur, "pivot": Vector3(-0.04, 0.235, 0)}

## Coalition light utility vehicle with a gunner's shield and heavy machine gun.
static func jeep() -> Dictionary:
	var C := mats("coalition")
	var root := Node3D.new()
	for p in [Vector2(-0.17, -0.155), Vector2(0.17, -0.155), Vector2(-0.17, 0.155), Vector2(0.17, 0.155)]:
		tyre(root, Vector3(p.x, 0.07, p.y), 0.07, 0.07, signf(p.y))
	var body := K.loft([[-0.27, 0.15, 0.2, 0.08, 10.0], [-0.1, 0.16, 0.21, 0.08, 10.0], [0.12, 0.16, 0.19, 0.08, 10.0], [0.27, 0.15, 0.17, 0.09, 10.0], [0.29, 0.13, 0.15, 0.1, 10.0]], 18)
	K.add(root, body, C.team_panel, Vector3.ZERO, Vector3.ZERO, true)
	for side in [-1.0, 1.0]:
		for x in [-0.17, 0.17]:
			K.add(root, K.loft([[-0.075, 0.03, 0.155, 0.13, 4.0], [0.0, 0.034, 0.165, 0.13, 4.0], [0.075, 0.03, 0.155, 0.13, 4.0]], 10), C.sec, Vector3(x, 0.0, side * 0.155))
	# Cabin: rounded roof, sloped windscreen, door windows.
	var cab := K.loft([[-0.16, 0.135, 0.31, 0.19, 10.0], [0.0, 0.14, 0.32, 0.19, 10.0], [0.07, 0.14, 0.3, 0.19, 10.0], [0.12, 0.13, 0.22, 0.19, 10.0]], 18)
	K.add(root, cab, C.team, Vector3.ZERO, Vector3.ZERO, true)
	K.add(root, K.bevel_box(Vector3(0.008, 0.07, 0.24), 0.003), C.glass, Vector3(0.098, 0.26, 0), Vector3(0, 0, -40))
	for side in [-1.0, 1.0]:
		K.add(root, K.bevel_box(Vector3(0.18, 0.05, 0.006), 0.003), C.glass, Vector3(-0.03, 0.265, side * 0.142))
	K.add(root, K.bevel_box(Vector3(0.02, 0.06, 0.3), 0.006), dark(), Vector3(0.29, 0.13, 0))     # grille / bumper
	for z in [-0.1, 0.1]:
		K.add(root, K.cylinder(0.016, 0.008, 10), lamp(), Vector3(0.293, 0.165, z), Vector3(0, 0, 90))
	K.add(root, K.bevel_box(Vector3(0.1, 0.06, 0.12), 0.012), C.sec, Vector3(-0.23, 0.23, 0.0))   # rear stowage
	antenna(root, Vector3(-0.24, 0.2, 0.12), 0.3)
	var tur := Node3D.new()
	K.add(tur, K.lathe([Vector2(0.06, 0.0), Vector2(0.06, 0.02), Vector2(0.05, 0.03)], 14), dark(), Vector3.ZERO)
	var shield := K.extrude(PackedVector2Array([Vector2(-0.07, 0.0), Vector2(0.07, 0.0), Vector2(0.06, 0.08), Vector2(-0.06, 0.08)]), 0.012)
	K.add(tur, shield, C.team, Vector3(0.05, 0.03, 0), Vector3(0, 90, 0), true)
	for s2 in [-1.0, 1.0]:
		K.add(tur, shield, C.team, Vector3(0.025, 0.03, s2 * 0.065), Vector3(0, 90 - s2 * 50.0, 0), true)
	K.add(tur, K.bevel_box(Vector3(0.09, 0.035, 0.035), 0.006), dark(), Vector3(0.02, 0.07, 0))
	barrel(tur, Vector3(0.06, 0.07, 0), 0.16, 0.008, dark(), false, false)
	K.add(tur, K.bevel_box(Vector3(0.04, 0.04, 0.03), 0.006), K.paint(Color(0.35, 0.33, 0.2), 0.2, 0.6), Vector3(0.0, 0.06, 0.04))
	return {"root": root, "turret": tur, "pivot": Vector3(-0.05, 0.32, 0)}

## Coalition mobile air defence: tracked carrier, turret with two 4-round missile pods and a radar.
static func aa_coalition() -> Dictionary:
	var C := mats("coalition")
	var root := Node3D.new()
	var L := 0.74
	var W := 0.52
	tracks(root, L, W, 0.12, 6, 0.042, "coalition", C.sec)
	K.add(root, armor_hull(L * 1.04, W * 0.88, 0.1, 0.25, 1.8), C.team_panel, Vector3.ZERO, Vector3.ZERO, true)
	K.add(root, K.bevel_box(Vector3(0.14, 0.08, 0.16), 0.02), C.team, Vector3(L * 0.3, 0.28, -0.1), Vector3.ZERO, true)
	K.add(root, K.bevel_box(Vector3(0.008, 0.03, 0.12), 0.003), C.glass, Vector3(L * 0.37, 0.29, -0.1), Vector3(0, 0, -30))
	for z in [-0.15, 0.15]:
		K.add(root, K.cylinder(0.014, 0.008, 10), lamp(), Vector3(L * 0.5, 0.18, z), Vector3(0, 0, 90))
	var tur := Node3D.new()
	K.add(tur, K.lathe([Vector2(0.15, 0.0), Vector2(0.15, 0.05), Vector2(0.12, 0.09), Vector2(0.0, 0.1)], 22), C.team_panel, Vector3.ZERO, Vector3.ZERO, true)
	for side in [-1.0, 1.0]:
		var pod := Node3D.new()
		pod.position = Vector3(0.0, 0.11, side * 0.18)
		pod.rotation.z = 0.35
		tur.add_child(pod)
		K.add(pod, K.bevel_box(Vector3(0.3, 0.11, 0.1), 0.012), C.sec, Vector3.ZERO)
		for i in 4:
			K.add(pod, K.cylinder(0.02, 0.006, 12), K.paint(Color(0.92, 0.92, 0.88), 0.1, 0.5), Vector3(0.151, -0.025 + (i / 2) * 0.05, -0.022 + (i % 2) * 0.044), Vector3(0, 0, 90))
		K.add(tur, K.bevel_box(Vector3(0.06, 0.06, 0.05), 0.01), dark(), Vector3(0.0, 0.11, side * 0.12))
	# Search radar (folded flat panel on a mast) and electro-optical turret.
	K.tube(tur, Vector3(-0.08, 0.1, 0), Vector3(-0.08, 0.24, 0), 0.012, steel(), 8)
	K.add(tur, K.bevel_box(Vector3(0.03, 0.09, 0.2), 0.01), K.paint(Color(0.85, 0.85, 0.82), 0.2, 0.5, {"panel": 30.0, "panel_dark": 0.25}), Vector3(-0.07, 0.27, 0), Vector3(0, 0, -15))
	K.add(tur, K.lathe([Vector2(0.035, 0.0), Vector2(0.04, 0.03), Vector2(0.0, 0.06)], 14), dark(), Vector3(0.09, 0.09, 0))
	K.add(tur, K.cylinder(0.018, 0.005, 12), K.paint(Color(0.3, 0.55, 0.65), 0.9, 0.05), Vector3(0.12, 0.115, 0), Vector3(0, 0, 90))
	return {"root": root, "turret": tur, "pivot": Vector3(-0.06, 0.25, 0)}

# ---------------------------------------------------------------- dominion armour

## "Mammoth" super-heavy tank: massive riveted hull, cast dome turret, twin 125 mm guns,
## reactive armour bricks, rear fuel drums, searchlight and heavy machine gun.
static func heavy_tank() -> Dictionary:
	var C := mats("dominion")
	var root := Node3D.new()
	var L := 0.96
	var W := 0.68
	tracks(root, L, W, 0.17, 6, 0.052, "dominion", null)
	for side in [-1.0, 1.0]:
		# Twin track units with thin mudguards and spare links.
		K.add(root, K.bevel_box(Vector3(L * 1.02, 0.018, 0.18), 0.006), C.sec_rivet, Vector3(0, 0.15, side * (W * 0.5 - 0.085)))
		for k in 3:
			K.add(root, K.bevel_box(Vector3(0.04, 0.035, 0.12), 0.004), track(), Vector3(L * 0.15 + k * 0.05, 0.16, side * (W * 0.5 - 0.085)))
	K.add(root, armor_hull(L * 1.04, W * 0.76, 0.12, 0.275, 1.5, 0.05), C.team_rivet, Vector3.ZERO, Vector3.ZERO, true)
	# Reactive armour on the glacis.
	for r in 2:
		for c in 5:
			K.add(root, K.bevel_box(Vector3(0.06, 0.03, 0.075), 0.006), C.era, Vector3(L * 0.42 + r * 0.045, 0.235 - r * 0.04, -0.17 + c * 0.085), Vector3(0, 0, -40))
	# Rear fuel drums and exhaust grilles.
	for z in [-0.13, 0.13]:
		K.add(root, K.cylinder(0.05, 0.16, 16), C.rust, Vector3(-L * 0.52, 0.29, z), Vector3(90, 0, 0))
		K.add(root, K.cylinder(0.052, 0.012, 16), dark(), Vector3(-L * 0.52, 0.29, z - 0.05), Vector3(90, 0, 0))
	K.add(root, K.bevel_box(Vector3(0.18, 0.014, W * 0.5), 0.004), K.paint(Color(0.12, 0.12, 0.11), 0.4, 0.6, {"stripes": 46.0}), Vector3(-L * 0.33, 0.274, 0))
	for z in [-0.2, 0.2]:
		K.add(root, K.cylinder(0.022, 0.012, 12), lamp(Color(1, 0.85, 0.55)), Vector3(L * 0.5, 0.2, z), Vector3(0, 0, 90))
	red_star(root, Vector3(0.0, 0.2, W * 0.385), 0.045, Vector3.ZERO)
	red_star(root, Vector3(0.0, 0.2, -W * 0.385), 0.045, Vector3.ZERO)
	var tur := Node3D.new()
	var dome := K.loft([[-0.27, 0.0, 0.07, 0.07], [-0.25, 0.14, 0.12, 0.0], [-0.12, 0.21, 0.17, 0.0], [0.05, 0.22, 0.18, 0.0], [0.17, 0.18, 0.15, 0.0], [0.24, 0.1, 0.1, 0.0], [0.26, 0.0, 0.05, 0.05]], 26, 2.2)
	K.add(tur, dome, C.team_rivet, Vector3.ZERO, Vector3.ZERO, true)
	K.add(tur, K.bevel_box(Vector3(0.1, 0.11, 0.26), 0.02), C.sec_rivet, Vector3(0.22, 0.08, 0))
	for z in [-0.065, 0.065]:
		barrel(tur, Vector3(0.26, 0.085, z), 0.5, 0.019, C.sec, true, true)
	# Reactive armour chevrons on the turret front.
	for side in [-1.0, 1.0]:
		for k in 3:
			K.add(tur, K.bevel_box(Vector3(0.07, 0.035, 0.07), 0.006), C.era, Vector3(0.12 - k * 0.03, 0.15, side * (0.07 + k * 0.05)), Vector3(0, side * 25.0, -20))
	K.add(tur, K.lathe([Vector2(0.055, 0.0), Vector2(0.055, 0.04), Vector2(0.045, 0.06), Vector2(0.0, 0.065)], 16), C.sec_rivet, Vector3(-0.06, 0.17, 0.08))
	mg(tur, Vector3(-0.03, 0.25, 0.08), "dominion")
	K.add(tur, K.bevel_box(Vector3(0.025, 0.05, 0.04), 0.006), dark(), Vector3(0.0, 0.24, 0.1))
	K.add(tur, K.cylinder(0.022, 0.04, 12), C.sec, Vector3(0.14, 0.12, -0.17), Vector3(0, 0, 90))     # searchlight
	K.add(tur, K.cylinder(0.018, 0.005, 12), lamp(Color(1, 0.95, 0.75)), Vector3(0.161, 0.12, -0.17), Vector3(0, 0, 90))
	K.add(tur, K.bevel_box(Vector3(0.14, 0.06, 0.22), 0.012), C.sec_rivet, Vector3(-0.3, 0.08, 0))   # stowage box
	antenna(tur, Vector3(-0.22, 0.13, -0.12), 0.38)
	red_star(tur, Vector3(-0.05, 0.12, 0.2), 0.035, Vector3(0, 0, 0))
	return {"root": root, "turret": tur, "pivot": Vector3(-0.06, 0.27, 0)}

## Dominion SAM carrier: tracked chassis with three large missiles on a rotating rail launcher
## and a tall dish radar.
static func aa_dominion() -> Dictionary:
	var C := mats("dominion")
	var root := Node3D.new()
	var L := 0.8
	var W := 0.56
	tracks(root, L, W, 0.14, 6, 0.048, "dominion", null)
	K.add(root, armor_hull(L * 1.04, W * 0.8, 0.11, 0.24, 1.5, 0.05), C.team_rivet, Vector3.ZERO, Vector3.ZERO, true)
	K.add(root, K.loft([[0.2, 0.14, 0.31, 0.22, 9.0], [0.33, 0.14, 0.31, 0.22, 9.0], [0.39, 0.12, 0.26, 0.22, 9.0]], 16), C.team, Vector3(0, 0, -0.08), Vector3.ZERO, true)
	K.add(root, K.bevel_box(Vector3(0.006, 0.025, 0.12), 0.003), C.glass, Vector3(0.375, 0.27, -0.08), Vector3(0, 0, -35))
	for z in [-0.16, 0.16]:
		K.add(root, K.cylinder(0.018, 0.01, 12), lamp(Color(1, 0.85, 0.55)), Vector3(L * 0.5, 0.18, z), Vector3(0, 0, 90))
	for z in [-0.11, 0.11]:
		K.add(root, K.cylinder(0.045, 0.14, 14), C.rust, Vector3(-L * 0.52, 0.26, z), Vector3(90, 0, 0))
	red_star(root, Vector3(-0.05, 0.18, W * 0.4), 0.04, Vector3.ZERO)
	var tur := Node3D.new()
	K.add(tur, K.cylinder(0.13, 0.05, 20), C.sec_rivet, Vector3(0, 0.025, 0))
	K.add(tur, K.bevel_box(Vector3(0.24, 0.05, 0.3), 0.012), C.team_rivet, Vector3(0.0, 0.07, 0), Vector3.ZERO, true)
	for i in 3:
		var z := -0.1 + i * 0.1
		var m := Node3D.new()
		m.position = Vector3(-0.02, 0.13, z)
		m.rotation.z = 0.4
		tur.add_child(m)
		K.add(m, K.bevel_box(Vector3(0.36, 0.012, 0.03), 0.003), steel(), Vector3(0, -0.035, 0))
		K.add(m, K.lathe([Vector2(0.0, -0.2), Vector2(0.025, -0.19), Vector2(0.026, 0.12), Vector2(0.02, 0.17), Vector2(0.0, 0.21)], 14), K.paint(Color(0.85, 0.86, 0.82), 0.2, 0.5), Vector3.ZERO, Vector3(0, 0, -90))
		K.add(m, K.lathe([Vector2(0.018, 0.0), Vector2(0.0, 0.035)], 10), C.accent, Vector3(0.21, 0, 0), Vector3(0, 0, -90))
		for k in 4:
			var a := TAU * k / 4.0 + PI * 0.25
			K.add(m, K.bevel_box(Vector3(0.06, 0.004, 0.022), 0.001), K.paint(Color(0.85, 0.86, 0.82), 0.2, 0.5), Vector3(-0.16, cos(a) * 0.035, sin(a) * 0.035), Vector3(rad_to_deg(a), 0, 0))
	# Dish radar on a mast at the rear.
	K.tube(tur, Vector3(-0.14, 0.06, 0), Vector3(-0.14, 0.28, 0), 0.014, steel(), 8)
	var dish := K.lathe([Vector2(0.0, 0.0), Vector2(0.03, 0.002), Vector2(0.06, 0.01), Vector2(0.08, 0.022)], 22, true, false, false)
	K.add(tur, dish, K.paint(Color(0.62, 0.63, 0.58), 0.5, 0.4, {"panel": 40.0, "panel_dark": 0.2}), Vector3(-0.13, 0.3, 0), Vector3(0, 0, -75))
	K.tube(tur, Vector3(-0.13, 0.3, 0), Vector3(-0.06, 0.32, 0), 0.005, dark(), 4)
	K.add(tur, K.bevel_box(Vector3(0.05, 0.05, 0.06), 0.008), C.sec, Vector3(-0.15, 0.27, 0))
	return {"root": root, "turret": tur, "pivot": Vector3(-0.05, 0.24, 0)}

# ---------------------------------------------------------------- logistics

static func harvester(f: String, load: float) -> Dictionary:
	var C := mats(f)
	var root := Node3D.new()
	if f == "coalition":
		# Six-wheeled mining truck: cab-forward, rounded hopper, rotating collector drum.
		for x in [-0.3, -0.12, 0.25]:
			for side in [-1.0, 1.0]:
				tyre(root, Vector3(x, 0.085, side * 0.24), 0.085, 0.09, side)
		K.add(root, K.loft([[-0.44, 0.2, 0.2, 0.1, 6.0], [0.38, 0.2, 0.2, 0.1, 6.0]], 16), C.sec, Vector3.ZERO)
		var hop := K.loft([[-0.44, 0.24, 0.46, 0.2, 10.0], [-0.42, 0.26, 0.48, 0.2, 10.0], [0.06, 0.27, 0.48, 0.2, 10.0], [0.1, 0.25, 0.45, 0.2, 10.0]], 20)
		K.add(root, hop, C.team_panel, Vector3.ZERO, Vector3.ZERO, true)
		K.add(root, K.bevel_box(Vector3(0.44, 0.012, 0.44), 0.004), dark(), Vector3(-0.17, 0.481, 0))
		var cab := K.loft([[0.12, 0.2, 0.46, 0.2, 10.0], [0.3, 0.2, 0.46, 0.2, 10.0], [0.38, 0.19, 0.38, 0.2, 10.0], [0.42, 0.17, 0.3, 0.2, 10.0]], 18)
		K.add(root, cab, C.team, Vector3.ZERO, Vector3.ZERO, true)
		K.add(root, K.bevel_box(Vector3(0.006, 0.08, 0.32), 0.003), C.glass, Vector3(0.385, 0.39, 0), Vector3(0, 0, -45))
		K.add(root, K.cylinder(0.075, 0.5, 16), steel(), Vector3(0.5, 0.1, 0), Vector3(90, 0, 0))
		for i in 7:
			K.add(root, K.bevel_box(Vector3(0.02, 0.17, 0.015), 0.003), M.yellow(), Vector3(0.5, 0.1, -0.21 + i * 0.07), Vector3(0, 0, i * 26))
		K.add(root, K.cylinder(0.022, 0.02, 10), lamp(Color(1, 0.6, 0.15)), Vector3(0.24, 0.48, 0.12))
		if load > 0.0:
			rocks(root, Vector3(-0.17, 0.46, 0), Vector2(0.4, 0.4), int(40 * load))
	else:
		# Tracked strip-miner: brutal ribbed hopper, toothed scoop, riveted cab.
		tracks(root, 0.9, 0.66, 0.16, 5, 0.05, "dominion", null)
		K.add(root, K.bevel_box(Vector3(0.86, 0.08, 0.46), 0.02), C.sec_rivet, Vector3(0, 0.2, 0))
		var hop := [K.plane_at(Vector3.DOWN, Vector3(0, 0.22, 0)), K.plane_at(Vector3.UP, Vector3(0, 0.47, 0)),
			K.plane_at(Vector3(-1, 0.3, 0), Vector3(-0.44, 0.3, 0)), K.plane_at(Vector3(1, 0.3, 0), Vector3(0.12, 0.3, 0)),
			K.plane_at(Vector3(0, 0.35, 1), Vector3(0, 0.3, 0.29)), K.plane_at(Vector3(0, 0.35, -1), Vector3(0, 0.3, -0.29))]
		K.add(root, K.convex(hop), C.team_rivet, Vector3.ZERO, Vector3.ZERO, true)
		for i in 4:
			K.add(root, K.bevel_box(Vector3(0.025, 0.25, 0.62), 0.006), C.sec, Vector3(-0.38 + i * 0.15, 0.33, 0))
		K.add(root, K.bevel_box(Vector3(0.5, 0.012, 0.48), 0.004), dark(), Vector3(-0.16, 0.473, 0))
		K.add(root, armor_hull(0.26, 0.34, 0.22, 0.44, 0.9, 0.03), C.team_rivet, Vector3(0.28, 0, 0.1), Vector3.ZERO, true)
		K.add(root, K.bevel_box(Vector3(0.006, 0.05, 0.2), 0.003), C.glass, Vector3(0.395, 0.38, 0.1), Vector3(0, 0, -40))
		K.add(root, K.bevel_box(Vector3(0.12, 0.1, 0.56), 0.012), C.sec_rivet, Vector3(0.52, 0.09, 0), Vector3(0, 0, 20))
		for i in 8:
			K.add(root, K.lathe([Vector2(0.018, 0.0), Vector2(0.0, 0.06)], 6), steel(), Vector3(0.6, 0.04, -0.245 + i * 0.07), Vector3(0, 0, -100))
		K.tube(root, Vector3(0.25, 0.44, -0.18), Vector3(0.25, 0.62, -0.18), 0.022, dark())
		red_star(root, Vector3(0.28, 0.33, 0.281), 0.04, Vector3.ZERO)
		if load > 0.0:
			rocks(root, Vector3(-0.16, 0.45, 0), Vector2(0.46, 0.44), int(44 * load))
	return {"root": root, "turret": null, "pivot": Vector3.ZERO}

static func mcv(f: String) -> Dictionary:
	var C := mats(f)
	var root := Node3D.new()
	if f == "coalition":
		# Eight-wheeled transporter carrying a folded construction module and crane.
		for x in [-0.36, -0.2, 0.18, 0.34]:
			for side in [-1.0, 1.0]:
				tyre(root, Vector3(x, 0.08, side * 0.25), 0.08, 0.085, side)
		K.add(root, K.loft([[-0.52, 0.22, 0.22, 0.11, 6.0], [0.5, 0.22, 0.22, 0.11, 6.0]], 16), C.sec, Vector3.ZERO)
		var cab := K.loft([[0.26, 0.24, 0.42, 0.18, 10.0], [0.44, 0.24, 0.42, 0.18, 10.0], [0.52, 0.22, 0.34, 0.18, 10.0], [0.55, 0.2, 0.26, 0.18, 10.0]], 18)
		K.add(root, cab, C.team, Vector3.ZERO, Vector3.ZERO, true)
		K.add(root, K.bevel_box(Vector3(0.006, 0.08, 0.36), 0.003), C.glass, Vector3(0.525, 0.35, 0), Vector3(0, 0, -45))
		K.add(root, K.bevel_box(Vector3(0.7, 0.22, 0.46), 0.03), C.team_panel, Vector3(-0.15, 0.34, 0), Vector3.ZERO, true)
		K.add(root, K.bevel_box(Vector3(0.68, 0.03, 0.06), 0.006), C.accent, Vector3(-0.15, 0.4, 0.231))
		K.add(root, K.bevel_box(Vector3(0.16, 0.12, 0.16), 0.02), K.paint(Color(0.7, 0.7, 0.68), 0.0, 0.9, {"panel": 6.0}), Vector3(-0.32, 0.51, -0.1))
		var arm := K.pivot(root, Vector3(-0.4, 0.46, 0.12))
		K.add(arm, K.cylinder(0.05, 0.06, 12), M.yellow(), Vector3.ZERO)
		K.add(arm, K.bevel_box(Vector3(0.72, 0.045, 0.045), 0.008), M.yellow(), Vector3(0.34, 0.03, 0), Vector3(0, 0, 4))
		K.add(arm, K.bevel_box(Vector3(0.06, 0.06, 0.06), 0.01), dark(), Vector3(0.68, 0.0, 0))
		K.add(root, K.cylinder(0.022, 0.02, 10), lamp(Color(1, 0.6, 0.15)), Vector3(0.38, 0.44, 0.0))
		roundel(root, Vector3(-0.15, 0.34, 0.232), 0.05, Vector3(90, 0, 0))
	else:
		# Tracked crawler with an armoured folded factory block.
		tracks(root, 1.0, 0.7, 0.17, 6, 0.05, "dominion", null)
		K.add(root, K.bevel_box(Vector3(0.96, 0.1, 0.5), 0.02), C.sec_rivet, Vector3(0, 0.21, 0))
		K.add(root, armor_hull(0.24, 0.5, 0.24, 0.45, 0.9, 0.03), C.team_rivet, Vector3(0.41, 0, 0), Vector3.ZERO, true)
		K.add(root, K.bevel_box(Vector3(0.006, 0.05, 0.3), 0.003), C.glass, Vector3(0.51, 0.39, 0), Vector3(0, 0, -40))
		K.add(root, armor_hull(0.76, 0.52, 0.24, 0.52, 0.6, 0.06), C.team_rivet, Vector3(-0.12, 0, 0), Vector3.ZERO, true)
		for i in 5:
			K.add(root, K.bevel_box(Vector3(0.03, 0.3, 0.56), 0.006), C.sec, Vector3(-0.42 + i * 0.16, 0.38, 0))
		K.tube(root, Vector3(0.0, 0.5, 0.12), Vector3(0.0, 0.7, 0.12), 0.03, dark())
		K.tube(root, Vector3(-0.1, 0.5, 0.12), Vector3(-0.1, 0.66, 0.12), 0.024, dark())
		red_star(root, Vector3(-0.1, 0.4, 0.271), 0.06, Vector3.ZERO)
		K.add(root, K.cylinder(0.025, 0.02, 10), lamp(Color(1, 0.3, 0.15)), Vector3(0.4, 0.46, 0.0))
	return {"root": root, "turret": null, "pivot": Vector3.ZERO}

# ---------------------------------------------------------------- aircraft (modelled on the ground; renderer lifts them)

## Coalition attack helicopter (tandem seats, stepped canopy, stub wings with rocket pods).
static func heli_coalition() -> Dictionary:
	var C := mats("coalition")
	var root := Node3D.new()
	var body := K.loft([[-0.22, 0.04, 0.26, 0.16, 2.5], [-0.05, 0.075, 0.32, 0.1, 3.0], [0.15, 0.07, 0.33, 0.1, 3.0], [0.33, 0.05, 0.25, 0.11, 2.6], [0.42, 0.025, 0.19, 0.14, 2.2]], 20)
	K.add(root, body, C.team_panel, Vector3.ZERO, Vector3.ZERO, true)
	var canopy := K.loft([[0.06, 0.0, 0.33, 0.33], [0.1, 0.055, 0.38, 0.3, 2.5], [0.2, 0.055, 0.37, 0.28, 2.5], [0.24, 0.05, 0.34, 0.27, 2.5], [0.33, 0.04, 0.3, 0.25, 2.5], [0.37, 0.0, 0.26, 0.26]], 16)
	K.add(root, canopy, C.glass, Vector3.ZERO)
	K.add(root, K.loft([[-0.75, 0.012, 0.29, 0.25, 2.5], [-0.22, 0.035, 0.3, 0.2, 2.5]], 14), C.team, Vector3.ZERO, Vector3.ZERO, true)  # tail boom
	K.add(root, K.extrude(PackedVector2Array([Vector2(-0.8, 0.27), Vector2(-0.7, 0.27), Vector2(-0.73, 0.45), Vector2(-0.8, 0.46)]), 0.015), C.team, Vector3.ZERO, Vector3.ZERO, true)
	K.add(root, K.bevel_box(Vector3(0.07, 0.008, 0.24), 0.003), C.team, Vector3(-0.7, 0.27, 0), Vector3.ZERO, true)
	K.add(root, K.cylinder(0.075, 0.006, 20), K.paint(Color(0.2, 0.2, 0.2), 0.3, 0.6, {"stripes": 6.0}), Vector3(-0.76, 0.38, 0.018), Vector3(90, 0, 0))
	# Engine nacelles and rotor mast.
	for side in [-1.0, 1.0]:
		K.add(root, K.loft([[-0.12, 0.035, 0.37, 0.3], [0.08, 0.04, 0.38, 0.3], [0.12, 0.03, 0.37, 0.31]], 14), C.sec, Vector3(0, 0, side * 0.075))
		K.add(root, K.cylinder(0.022, 0.01, 12), dark(), Vector3(-0.125, 0.34, side * 0.075), Vector3(0, 0, 90))
	K.add(root, K.cylinder(0.02, 0.07, 10), dark(), Vector3(0.0, 0.4, 0))
	K.add(root, K.lathe([Vector2(0.05, 0.0), Vector2(0.05, 0.02), Vector2(0.0, 0.03)], 14), dark(), Vector3(0.0, 0.43, 0))
	# Stub wings with rocket pods and missile rails.
	for side in [-1.0, 1.0]:
		K.add(root, K.bevel_box(Vector3(0.1, 0.015, 0.16), 0.005), C.sec, Vector3(0.02, 0.24, side * 0.14), Vector3(side * 6.0, 0, 0))
		K.add(root, K.lathe([Vector2(0.0, -0.08), Vector2(0.03, -0.07), Vector2(0.032, 0.07), Vector2(0.028, 0.08)], 14), C.sec, Vector3(0.03, 0.2, side * 0.17), Vector3(0, 0, -90))
		K.add(root, K.cylinder(0.024, 0.005, 12), dark(), Vector3(0.112, 0.2, side * 0.17), Vector3(0, 0, 90))
		for k in 2:
			K.add(root, K.lathe([Vector2(0.0, -0.07), Vector2(0.012, -0.065), Vector2(0.012, 0.06), Vector2(0.0, 0.075)], 10), K.paint(Color(0.5, 0.52, 0.48), 0.3, 0.5), Vector3(0.03, 0.205 - k * 0.03, side * 0.22), Vector3(0, 0, -90))
	# Chin gun and sensor ball, landing gear.
	K.add(root, K.lathe([Vector2(0.035, 0.0), Vector2(0.04, 0.03), Vector2(0.0, 0.07)], 14), C.sec, Vector3(0.38, 0.17, 0), Vector3(0, 0, 90))
	K.add(root, K.cylinder(0.009, 0.12, 8), dark(), Vector3(0.28, 0.08, 0), Vector3(0, 0, 90))
	K.ellipsoid(root, Vector3(0.43, 0.15, 0), Vector3(0.025, 0.025, 0.025), dark())
	for side in [-1.0, 1.0]:
		K.tube(root, Vector3(0.12, 0.13, side * 0.06), Vector3(0.12, 0.05, side * 0.11), 0.007, dark(), 6)
		tyre(root, Vector3(0.12, 0.035, side * 0.12), 0.035, 0.025, side)
	tyre(root, Vector3(-0.68, 0.03, 0), 0.025, 0.02, 1.0)
	return {"root": root, "turret": null, "pivot": Vector3.ZERO, "rotor": {"pos": [0.0, 0.47, 0.0], "r": 0.5, "blades": 4}}

## Dominion gunship (twin bubble cockpits, troop cabin, stub wings with heavy pylons).
static func heli_dominion() -> Dictionary:
	var C := mats("dominion")
	var root := Node3D.new()
	var body := K.loft([[-0.3, 0.05, 0.33, 0.18, 2.4], [-0.1, 0.11, 0.38, 0.1, 2.8], [0.12, 0.11, 0.38, 0.1, 2.8], [0.3, 0.08, 0.3, 0.12, 2.4], [0.4, 0.04, 0.22, 0.15, 2.2]], 22)
	K.add(root, body, C.team_rivet, Vector3.ZERO, Vector3.ZERO, true)
	# Two separate bubble canopies: gunner front-low, pilot behind-high.
	K.ellipsoid(root, Vector3(0.36, 0.23, 0), Vector3(0.065, 0.06, 0.055), C.glass)
	K.ellipsoid(root, Vector3(0.24, 0.32, 0), Vector3(0.07, 0.065, 0.06), C.glass)
	for i in 3:
		for side in [-1.0, 1.0]:
			K.add(root, K.bevel_box(Vector3(0.04, 0.04, 0.006), 0.004), C.glass, Vector3(-0.05 + i * 0.07, 0.27, side * 0.11))
	K.add(root, K.loft([[-0.85, 0.015, 0.36, 0.31, 2.5], [-0.3, 0.05, 0.36, 0.22, 2.5]], 14), C.team_rivet, Vector3.ZERO, Vector3.ZERO, true)
	K.add(root, K.extrude(PackedVector2Array([Vector2(-0.9, 0.33), Vector2(-0.8, 0.33), Vector2(-0.84, 0.5), Vector2(-0.91, 0.52)]), 0.018), C.team, Vector3.ZERO, Vector3.ZERO, true)
	K.add(root, K.cylinder(0.08, 0.006, 20), K.paint(Color(0.2, 0.2, 0.2), 0.3, 0.6, {"stripes": 6.0}), Vector3(-0.86, 0.44, -0.02), Vector3(90, 0, 0))
	K.add(root, K.bevel_box(Vector3(0.08, 0.008, 0.26), 0.003), C.team, Vector3(-0.72, 0.34, 0), Vector3.ZERO, true)
	for side in [-1.0, 1.0]:
		K.add(root, K.loft([[-0.2, 0.04, 0.44, 0.36], [0.1, 0.048, 0.45, 0.36], [0.14, 0.04, 0.44, 0.37]], 14), C.sec_rivet, Vector3(0, 0, side * 0.07))
		K.add(root, K.cylinder(0.035, 0.012, 14), dark(), Vector3(0.145, 0.405, side * 0.07), Vector3(0, 0, 90))
		K.add(root, K.cylinder(0.03, 0.06, 12), C.rust, Vector3(-0.22, 0.4, side * 0.12), Vector3(0, 0, 70))
	K.add(root, K.cylinder(0.025, 0.06, 10), dark(), Vector3(0.0, 0.47, 0))
	K.add(root, K.lathe([Vector2(0.06, 0.0), Vector2(0.06, 0.02), Vector2(0.0, 0.035)], 14), dark(), Vector3(0.0, 0.5, 0))
	# Anhedral stub wings with rocket pods and anti-tank missiles on the tips.
	for side in [-1.0, 1.0]:
		K.add(root, K.bevel_box(Vector3(0.13, 0.016, 0.24), 0.005), C.sec, Vector3(0.0, 0.25, side * 0.22), Vector3(-side * 12.0, 0, 0))
		for k in 2:
			var z: float = side * (0.18 + k * 0.08)
			K.add(root, K.lathe([Vector2(0.0, -0.09), Vector2(0.035, -0.08), Vector2(0.036, 0.07), Vector2(0.03, 0.09)], 14), C.sec, Vector3(0.02, 0.2 - k * 0.02, z), Vector3(0, 0, -90))
			K.add(root, K.cylinder(0.027, 0.005, 12), dark(), Vector3(0.112, 0.2 - k * 0.02, z), Vector3(0, 0, 90))
		K.add(root, K.lathe([Vector2(0.0, -0.08), Vector2(0.014, -0.07), Vector2(0.014, 0.07), Vector2(0.0, 0.085)], 10), K.paint(Color(0.45, 0.48, 0.38), 0.3, 0.5), Vector3(0.0, 0.2, side * 0.35), Vector3(0, 0, -90))
	K.add(root, K.lathe([Vector2(0.04, 0.0), Vector2(0.045, 0.03), Vector2(0.0, 0.06)], 14), dark(), Vector3(0.42, 0.14, 0), Vector3(0, 0, 90))
	for b in 2:
		K.add(root, K.cylinder(0.009, 0.14, 8), dark(), Vector3(0.52, 0.13, -0.012 + b * 0.024), Vector3(0, 0, 90))
	for side in [-1.0, 1.0]:
		K.tube(root, Vector3(0.18, 0.13, side * 0.08), Vector3(0.18, 0.05, side * 0.14), 0.008, dark(), 6)
		tyre(root, Vector3(0.18, 0.035, side * 0.14), 0.035, 0.03, side)
	red_star(root, Vector3(-0.5, 0.33, 0.035), 0.045, Vector3.ZERO)
	red_star(root, Vector3(-0.5, 0.33, -0.035), 0.045, Vector3.ZERO)
	return {"root": root, "turret": null, "pivot": Vector3.ZERO, "rotor": {"pos": [0.0, 0.53, 0.0], "r": 0.6, "blades": 5}}

## Coalition stealth multirole fighter: blended diamond wing, twin canted fins, internal bays.
static func jet_coalition() -> Dictionary:
	var C := mats("coalition")
	var root := Node3D.new()
	var y0 := 0.12
	var body := K.loft([[-0.42, 0.07, y0 + 0.07, y0 - 0.02, 4.0], [-0.2, 0.11, y0 + 0.09, y0 - 0.03, 4.0], [0.1, 0.09, y0 + 0.1, y0 - 0.03, 3.5], [0.3, 0.05, y0 + 0.07, y0 - 0.02, 2.6], [0.48, 0.0, y0 + 0.02, y0 + 0.01]], 20)
	K.add(root, body, C.team, Vector3.ZERO, Vector3.ZERO, true)
	var wing := PackedVector2Array([Vector2(0.12, 0.0), Vector2(-0.16, 0.42), Vector2(-0.27, 0.42), Vector2(-0.3, 0.0)])
	for side in [-1.0, 1.0]:
		var w := K.extrude(mirror(wing, side), 0.014)
		K.add(root, w, C.team_panel, Vector3(0, y0 + 0.02, 0), Vector3(90, 0, 0), true)
		var tail := PackedVector2Array([Vector2(-0.3, 0.0), Vector2(-0.38, 0.16), Vector2(-0.45, 0.16), Vector2(-0.44, 0.0)])
		K.add(root, K.extrude(mirror(tail, side), 0.01), C.team_panel, Vector3(0, y0 + 0.03, 0), Vector3(90, 0, 0), true)
		var fin := K.extrude(PackedVector2Array([Vector2(-0.28, 0.0), Vector2(-0.36, 0.15), Vector2(-0.42, 0.15), Vector2(-0.4, 0.0)]), 0.01)
		K.add(root, fin, C.team, Vector3(0, y0 + 0.07, side * 0.07), Vector3(side * 25.0, 0, 0), true)
		K.add(root, K.loft([[0.0, 0.0, y0 + 0.03, y0 + 0.03], [0.12, 0.04, y0 + 0.06, y0 - 0.02, 4.0], [0.2, 0.04, y0 + 0.06, y0 - 0.02, 4.0]], 12), C.sec, Vector3(0, 0, side * 0.08))
	K.add(root, K.loft([[0.12, 0.0, y0 + 0.1, y0 + 0.1], [0.18, 0.035, y0 + 0.14, y0 + 0.08, 2.5], [0.3, 0.032, y0 + 0.13, y0 + 0.07, 2.5], [0.36, 0.0, y0 + 0.08, y0 + 0.08]], 14), K.paint(Color(0.8, 0.6, 0.2), 0.9, 0.08), Vector3.ZERO)
	K.add(root, K.lathe([Vector2(0.05, 0.0), Vector2(0.045, 0.06), Vector2(0.035, 0.08)], 14, true, false, false), dark(), Vector3(-0.42, y0 + 0.03, 0), Vector3(0, 0, 90))
	K.add(root, K.cylinder(0.035, 0.01, 14), lamp(Color(1, 0.6, 0.3)), Vector3(-0.49, y0 + 0.03, 0), Vector3(0, 0, 90))
	roundel(root, Vector3(-0.1, y0 + 0.031, 0.28), 0.035, Vector3.ZERO)
	roundel(root, Vector3(-0.1, y0 + 0.031, -0.28), 0.035, Vector3.ZERO)
	return {"root": root, "turret": null, "pivot": Vector3.ZERO}

## Dominion heavy strike fighter: long nose, big swept wings, twin vertical tails, twin engines, bombs.
static func jet_dominion() -> Dictionary:
	var C := mats("dominion")
	var root := Node3D.new()
	var y0 := 0.13
	var body := K.loft([[-0.4, 0.05, y0 + 0.06, y0 - 0.02, 3.0], [-0.15, 0.08, y0 + 0.08, y0 - 0.03, 3.0], [0.15, 0.06, y0 + 0.08, y0 - 0.03, 2.5], [0.4, 0.035, y0 + 0.05, y0 - 0.01, 2.2], [0.58, 0.0, y0 + 0.02, y0 + 0.02]], 20)
	K.add(root, body, C.team_rivet, Vector3.ZERO, Vector3.ZERO, true)
	for side in [-1.0, 1.0]:
		K.add(root, K.loft([[-0.46, 0.045, y0 + 0.02, y0 - 0.06, 2.2], [0.05, 0.05, y0 + 0.02, y0 - 0.07, 3.0], [0.12, 0.04, y0 + 0.0, y0 - 0.06, 4.0]], 14), C.sec_rivet, Vector3(0, 0, side * 0.08))
		K.add(root, K.cylinder(0.04, 0.01, 14), lamp(Color(1, 0.55, 0.25)), Vector3(-0.465, y0 - 0.02, side * 0.08), Vector3(0, 0, 90))
		var wing := PackedVector2Array([Vector2(0.15, 0.0), Vector2(-0.12, 0.48), Vector2(-0.2, 0.48), Vector2(-0.26, 0.0)])
		K.add(root, K.extrude(mirror(wing, side), 0.014), C.team_panel, Vector3(0, y0 + 0.0, 0), Vector3(90, 0, 0), true)
		var tail := PackedVector2Array([Vector2(-0.3, 0.0), Vector2(-0.4, 0.2), Vector2(-0.47, 0.2), Vector2(-0.46, 0.0)])
		K.add(root, K.extrude(mirror(tail, side), 0.01), C.team_panel, Vector3(0, y0 + 0.0, 0), Vector3(90, 0, 0), true)
		var fin := K.extrude(PackedVector2Array([Vector2(-0.24, 0.0), Vector2(-0.36, 0.18), Vector2(-0.43, 0.18), Vector2(-0.42, 0.0)]), 0.01)
		K.add(root, fin, C.team, Vector3(0, y0 + 0.05, side * 0.09), Vector3.ZERO, true)
		red_star(root, Vector3(-0.35, y0 + 0.15, side * 0.096), 0.03, Vector3.ZERO)
		# Two bombs per wing.
		for k in 2:
			var z: float = side * (0.18 + k * 0.1)
			K.add(root, K.lathe([Vector2(0.0, -0.08), Vector2(0.025, -0.06), Vector2(0.025, 0.04), Vector2(0.0, 0.08)], 12), K.paint(Color(0.35, 0.38, 0.3), 0.3, 0.5), Vector3(-0.04, y0 - 0.04, z), Vector3(0, 0, -90))
	K.add(root, K.loft([[0.18, 0.0, y0 + 0.08, y0 + 0.08], [0.24, 0.032, y0 + 0.12, y0 + 0.06, 2.5], [0.34, 0.03, y0 + 0.11, y0 + 0.05, 2.5], [0.4, 0.0, y0 + 0.06, y0 + 0.06]], 14), C.glass, Vector3.ZERO)
	red_star(root, Vector3(-0.08, y0 + 0.017, 0.33), 0.04, Vector3(90, 0, 0))
	red_star(root, Vector3(-0.08, y0 + 0.017, -0.33), 0.04, Vector3(90, 0, 0))
	return {"root": root, "turret": null, "pivot": Vector3.ZERO}

# ---------------------------------------------------------------- ships (waterline at y = 0)

static func _hull(L: float, W: float, deck: float, bow_rise: float) -> ArrayMesh:
	return K.loft([[-L * 0.5, W * 0.42, deck, 0.0, 6.0], [-L * 0.3, W * 0.5, deck, 0.0, 5.0], [L * 0.15, W * 0.5, deck + bow_rise * 0.3, 0.0, 4.0],
		[L * 0.35, W * 0.36, deck + bow_rise * 0.7, 0.0, 3.0], [L * 0.5, 0.0, deck + bow_rise, deck * 0.4]], 22)

## Coalition fast patrol gunboat.
static func boat_coalition() -> Dictionary:
	var C := mats("coalition")
	var root := Node3D.new()
	K.add(root, _hull(0.9, 0.24, 0.08, 0.05), C.team, Vector3.ZERO, Vector3.ZERO, true)
	var cab := K.loft([[-0.2, 0.085, 0.21, 0.09, 12.0], [0.05, 0.09, 0.22, 0.09, 12.0], [0.12, 0.075, 0.17, 0.09, 12.0]], 16)
	K.add(root, cab, C.team_panel, Vector3.ZERO, Vector3.ZERO, true)
	K.add(root, K.bevel_box(Vector3(0.006, 0.04, 0.17), 0.003), C.glass, Vector3(0.1, 0.19, 0), Vector3(0, 0, -40))
	K.tube(root, Vector3(-0.08, 0.23, 0), Vector3(-0.08, 0.36, 0), 0.008, steel(), 6)
	K.add(root, K.bevel_box(Vector3(0.03, 0.015, 0.12), 0.004), dark(), Vector3(-0.08, 0.35, 0))
	K.add(root, K.lathe([Vector2(0.04, 0.0), Vector2(0.04, 0.03), Vector2(0.0, 0.05)], 14), C.sec, Vector3(0.25, 0.1, 0))
	barrel(root, Vector3(0.27, 0.13, 0), 0.14, 0.01, dark(), false, false)
	mg(root, Vector3(-0.28, 0.12, 0), "coalition")
	return {"root": root, "turret": null, "pivot": Vector3.ZERO, "naval": true}

## Coalition guided-missile destroyer: faceted superstructure with phased-array panels.
static func destroyer_coalition() -> Dictionary:
	var C := mats("coalition")
	var root := Node3D.new()
	var L := 1.7
	K.add(root, _hull(L, 0.36, 0.1, 0.06), C.team, Vector3.ZERO, Vector3.ZERO, true)
	K.add(root, K.bevel_box(Vector3(L * 0.6, 0.01, 0.33), 0.003), K.paint(Color(0.34, 0.36, 0.37), 0.3, 0.7, {"panel": 10.0}), Vector3(-L * 0.18, 0.103, 0))
	var sp := [K.plane_at(Vector3.DOWN, Vector3(0, 0.1, 0)), K.plane_at(Vector3.UP, Vector3(0, 0.3, 0)),
		K.plane_at(Vector3(1, 0.35, 0), Vector3(0.2, 0.2, 0)), K.plane_at(Vector3(-1, 0.35, 0), Vector3(-0.25, 0.2, 0)),
		K.plane_at(Vector3(0, 0.3, 1), Vector3(0, 0.2, 0.13)), K.plane_at(Vector3(0, 0.3, -1), Vector3(0, 0.2, -0.13))]
	K.add(root, K.convex(sp), C.team_panel, Vector3(0.05, 0, 0), Vector3.ZERO, true)
	for side in [-1.0, 1.0]:
		K.add(root, K.bevel_box(Vector3(0.09, 0.08, 0.006), 0.003), K.paint(Color(0.32, 0.35, 0.38), 0.6, 0.3), Vector3(0.18, 0.22, side * 0.1), Vector3(0, side * -30.0, 0))
	K.add(root, K.bevel_box(Vector3(0.006, 0.03, 0.16), 0.003), C.glass, Vector3(0.27, 0.27, 0), Vector3(0, 0, -20))
	K.tube(root, Vector3(0.05, 0.3, 0), Vector3(0.0, 0.55, 0), 0.012, steel(), 6)
	K.add(root, K.bevel_box(Vector3(0.025, 0.012, 0.18), 0.003), dark(), Vector3(0.01, 0.48, 0))
	K.add(root, K.cylinder(0.02, 0.04, 10), K.paint(Color(0.85, 0.85, 0.82), 0.1, 0.5), Vector3(0.0, 0.57, 0))
	K.add(root, K.loft([[-0.42, 0.06, 0.28, 0.1, 3.0], [-0.3, 0.06, 0.3, 0.1, 3.0]], 12), C.team, Vector3.ZERO, Vector3.ZERO, true)  # funnel
	K.add(root, K.bevel_box(Vector3(0.1, 0.012, 0.1), 0.003), dark(), Vector3(-0.36, 0.302, 0))
	for i in 2:
		K.add(root, K.bevel_box(Vector3(0.16, 0.012, 0.16), 0.003), K.paint(Color(0.25, 0.27, 0.28), 0.4, 0.6, {"panel": 60.0, "panel_dark": 0.4}), Vector3(0.48 if i == 0 else -0.55, 0.11, 0))
	# Forward gun (fixed: ships turn their hull) and helipad at the stern.
	K.add(root, K.loft([[0.56, 0.06, 0.18, 0.1, 3.0], [0.68, 0.055, 0.17, 0.1, 3.0], [0.72, 0.03, 0.14, 0.1, 3.0]], 14), C.team, Vector3.ZERO, Vector3.ZERO, true)
	barrel(root, Vector3(0.7, 0.145, 0), 0.22, 0.012, dark(), false, false)
	K.add(root, K.cylinder(0.11, 0.006, 22), K.paint(Color(0.92, 0.9, 0.85), 0.0, 0.6), Vector3(-0.72, 0.104, 0))
	K.add(root, K.cylinder(0.1, 0.008, 22), K.paint(Color(0.3, 0.32, 0.33), 0.3, 0.7), Vector3(-0.72, 0.104, 0))
	roundel(root, Vector3(0.0, 0.08, 0.181), 0.03, Vector3(90, 0, 0))
	return {"root": root, "turret": null, "pivot": Vector3.ZERO, "naval": true}

## Dominion attack submarine (shown surfaced; the renderer fades it when submerged).
static func sub_dominion() -> Dictionary:
	var C := mats("dominion")
	var root := Node3D.new()
	var hull := K.loft([[-0.66, 0.0, 0.05, 0.05], [-0.6, 0.05, 0.09, 0.0], [-0.3, 0.1, 0.1, -0.02], [0.3, 0.1, 0.1, -0.02], [0.52, 0.08, 0.09, 0.0], [0.62, 0.0, 0.05, 0.05]], 22, 2.0)
	K.add(root, hull, K.paint(Color(0.15, 0.16, 0.17), 0.3, 0.55, {"panel": 12.0, "panel_dark": 0.15}), Vector3.ZERO)
	var sail := K.loft([[-0.04, 0.0, 0.2, 0.2], [0.0, 0.035, 0.26, 0.08, 2.5], [0.2, 0.035, 0.27, 0.08, 2.5], [0.26, 0.0, 0.22, 0.22]], 14)
	K.add(root, sail, C.team, Vector3(0.05, 0, 0), Vector3.ZERO, true)
	K.add(root, K.bevel_box(Vector3(0.08, 0.008, 0.2), 0.003), K.paint(Color(0.15, 0.16, 0.17), 0.3, 0.55), Vector3(0.17, 0.2, 0))
	for k in 3:
		K.add(root, K.cylinder(0.006, 0.07, 6), dark(), Vector3(0.12 + k * 0.03, 0.3, 0))
	K.add(root, K.extrude(PackedVector2Array([Vector2(-0.6, 0.0), Vector2(-0.52, 0.0), Vector2(-0.6, 0.16), Vector2(-0.66, 0.16)]), 0.012), K.paint(Color(0.15, 0.16, 0.17), 0.3, 0.55), Vector3.ZERO)
	K.add(root, K.bevel_box(Vector3(0.08, 0.008, 0.24), 0.003), K.paint(Color(0.15, 0.16, 0.17), 0.3, 0.55), Vector3(-0.58, 0.05, 0))
	K.add(root, K.bevel_box(Vector3(0.3, 0.004, 0.06), 0.002), C.team, Vector3(-0.2, 0.1, 0), Vector3.ZERO, true)
	red_star(root, Vector3(0.15, 0.2, 0.036), 0.03, Vector3.ZERO)
	red_star(root, Vector3(0.15, 0.2, -0.036), 0.03, Vector3.ZERO)
	return {"root": root, "turret": null, "pivot": Vector3.ZERO, "naval": true}

## Dominion battlecruiser: massive hull, stacked superstructure, missile silos and radar towers.
static func cruiser_dominion() -> Dictionary:
	var C := mats("dominion")
	var root := Node3D.new()
	var L := 1.9
	K.add(root, _hull(L, 0.44, 0.12, 0.07), C.team_rivet, Vector3.ZERO, Vector3.ZERO, true)
	K.add(root, K.bevel_box(Vector3(L * 0.6, 0.01, 0.41), 0.003), K.paint(Color(0.24, 0.24, 0.22), 0.3, 0.7, {"panel": 9.0}), Vector3(-L * 0.18, 0.123, 0))
	K.add(root, K.bevel_box(Vector3(0.6, 0.12, 0.3), 0.02), C.team_rivet, Vector3(-0.05, 0.18, 0), Vector3.ZERO, true)
	K.add(root, K.bevel_box(Vector3(0.3, 0.12, 0.22), 0.02), C.team_rivet, Vector3(0.05, 0.3, 0), Vector3.ZERO, true)
	K.add(root, K.bevel_box(Vector3(0.006, 0.03, 0.18), 0.003), C.glass, Vector3(0.2, 0.33, 0), Vector3(0, 0, -15))
	K.add(root, K.bevel_box(Vector3(0.14, 0.14, 0.14), 0.02), C.sec_rivet, Vector3(-0.02, 0.42, 0))
	K.tube(root, Vector3(-0.02, 0.48, 0), Vector3(-0.02, 0.7, 0), 0.014, steel(), 6)
	K.add(root, K.bevel_box(Vector3(0.03, 0.08, 0.26), 0.006), K.paint(Color(0.7, 0.7, 0.65), 0.3, 0.5, {"panel": 20.0}), Vector3(-0.02, 0.62, 0), Vector3(0, 0, -10))
	var dish := K.lathe([Vector2(0.0, 0.0), Vector2(0.04, 0.004), Vector2(0.07, 0.016)], 20, true, false, false)
	K.add(root, dish, K.paint(Color(0.55, 0.56, 0.52), 0.5, 0.4, {"panel": 40.0, "panel_dark": 0.2}), Vector3(-0.2, 0.36, 0.1), Vector3(0, 0, -75))
	K.add(root, K.loft([[-0.38, 0.07, 0.36, 0.2, 3.0], [-0.26, 0.07, 0.38, 0.2, 3.0]], 12), C.sec_rivet, Vector3.ZERO)
	K.add(root, K.bevel_box(Vector3(0.1, 0.012, 0.1), 0.003), dark(), Vector3(-0.32, 0.375, 0))
	# Forward missile silo field and rear twin gun.
	for r in 4:
		for c in 4:
			K.add(root, K.cylinder(0.025, 0.012, 12), K.paint(Color(0.3, 0.3, 0.28), 0.4, 0.5), Vector3(0.38 + r * 0.07, 0.13, -0.105 + c * 0.07))
			K.add(root, K.cylinder(0.018, 0.013, 12), C.accent, Vector3(0.38 + r * 0.07, 0.13, -0.105 + c * 0.07))
	K.add(root, K.loft([[-0.72, 0.07, 0.2, 0.12, 3.0], [-0.58, 0.07, 0.2, 0.12, 3.0], [-0.54, 0.05, 0.18, 0.12, 3.0]], 14), C.team_rivet, Vector3.ZERO, Vector3.ZERO, true)
	for z in [-0.025, 0.025]:
		barrel(root, Vector3(-0.56, 0.165, z), 0.22, 0.011, dark(), false, false)
	red_star(root, Vector3(0.6, 0.09, 0.2), 0.05, Vector3.ZERO)
	red_star(root, Vector3(0.6, 0.09, -0.2), 0.05, Vector3.ZERO)
	return {"root": root, "turret": null, "pivot": Vector3.ZERO, "naval": true}

# ---------------------------------------------------------------- special-ability vehicles

## Dominion minelayer: armoured tracked carrier with a mine hopper and rear dispenser chute.
static func minelayer() -> Dictionary:
	var C := mats("dominion")
	var root := Node3D.new()
	var L := 0.82
	var W := 0.56
	tracks(root, L, W, 0.14, 5, 0.05, "dominion", null)
	K.add(root, armor_hull(L * 1.02, W * 0.8, 0.11, 0.25, 1.4, 0.05), C.team_rivet, Vector3.ZERO, Vector3.ZERO, true)
	var hop := [K.plane_at(Vector3.DOWN, Vector3(0, 0.25, 0)), K.plane_at(Vector3.UP, Vector3(0, 0.42, 0)),
		K.plane_at(Vector3(-1, 0.4, 0), Vector3(-0.38, 0.3, 0)), K.plane_at(Vector3(1, 0.4, 0), Vector3(0.05, 0.3, 0)),
		K.plane_at(Vector3(0, 0.3, 1), Vector3(0, 0.3, 0.2)), K.plane_at(Vector3(0, 0.3, -1), Vector3(0, 0.3, -0.2))]
	K.add(root, K.convex(hop), C.sec_rivet, Vector3.ZERO)
	for i in 6:
		K.add(root, K.cylinder(0.035, 0.025, 12), K.paint(Color(0.2, 0.22, 0.18), 0.4, 0.5), Vector3(-0.3 + (i % 3) * 0.1, 0.43, -0.07 + (i / 3) * 0.14))
		K.add(root, K.cylinder(0.01, 0.01, 6), K.paint(Color(0.85, 0.15, 0.1), 0.0, 0.5, {"emit": 0.6}), Vector3(-0.3 + (i % 3) * 0.1, 0.45, -0.07 + (i / 3) * 0.14))
	K.add(root, K.bevel_box(Vector3(0.12, 0.08, 0.16), 0.01), M.hazard(), Vector3(-L * 0.52, 0.16, 0), Vector3(0, 0, -25))
	K.add(root, K.loft([[0.12, 0.16, 0.38, 0.24, 8.0], [0.3, 0.16, 0.38, 0.24, 8.0], [0.36, 0.13, 0.32, 0.24, 8.0]], 14), C.team_rivet, Vector3.ZERO, Vector3.ZERO, true)
	K.add(root, K.bevel_box(Vector3(0.006, 0.04, 0.2), 0.003), C.glass, Vector3(0.355, 0.33, 0), Vector3(0, 0, -35))
	for z in [-0.16, 0.16]:
		K.add(root, K.cylinder(0.018, 0.01, 12), lamp(Color(1, 0.85, 0.55)), Vector3(L * 0.5, 0.18, z), Vector3(0, 0, 90))
	antenna(root, Vector3(0.2, 0.38, 0.1), 0.3)
	red_star(root, Vector3(0.0, 0.19, W * 0.405), 0.04, Vector3.ZERO)
	return {"root": root, "turret": null, "pivot": Vector3.ZERO}

## Coalition four-engine transport (paratroopers), modelled at the ground; drawn high in the sky.
static func transport_plane() -> Dictionary:
	var C := mats("coalition")
	var root := Node3D.new()
	var y0 := 0.2
	K.add(root, K.loft([[-0.75, 0.03, y0 + 0.16, y0 + 0.1], [-0.45, 0.1, y0 + 0.17, y0 - 0.04], [0.35, 0.12, y0 + 0.14, y0 - 0.08, 2.4], [0.6, 0.08, y0 + 0.08, y0 - 0.06, 2.2], [0.72, 0.0, y0 + 0.02, y0 - 0.01]], 22), C.team, Vector3.ZERO, Vector3.ZERO, true)
	var wing := PackedVector2Array([Vector2(0.2, 0.0), Vector2(0.1, 0.85), Vector2(-0.02, 0.85), Vector2(-0.12, 0.0)])
	for side in [-1.0, 1.0]:
		K.add(root, K.extrude(mirror(wing, side), 0.02), C.team_panel, Vector3(0, y0 + 0.13, 0), Vector3(90, 0, 0), true)
		for k in 2:
			var z: float = side * (0.28 + k * 0.28)
			K.add(root, K.loft([[-0.02, 0.0, y0 + 0.1, y0 + 0.1], [0.05, 0.04, y0 + 0.13, y0 + 0.05], [0.25, 0.035, y0 + 0.12, y0 + 0.06]], 12), C.sec, Vector3(0, 0, z))
			K.add(root, K.cylinder(0.075, 0.004, 20), K.paint(Color(0.55, 0.56, 0.57), 0.3, 0.6, {"stripes": 7.0}), Vector3(0.27, y0 + 0.09, z), Vector3(0, 0, 90))
		var tail := PackedVector2Array([Vector2(-0.55, 0.0), Vector2(-0.66, 0.28), Vector2(-0.76, 0.28), Vector2(-0.74, 0.0)])
		K.add(root, K.extrude(mirror(tail, side), 0.012), C.team_panel, Vector3(0, y0 + 0.16, 0), Vector3(90, 0, 0), true)
	K.add(root, K.extrude(PackedVector2Array([Vector2(-0.5, 0.0), Vector2(-0.66, 0.3), Vector2(-0.76, 0.3), Vector2(-0.73, 0.0)]), 0.014), C.team, Vector3(0, y0 + 0.16, 0), Vector3.ZERO, true)
	K.add(root, K.loft([[0.5, 0.0, y0 + 0.11, y0 + 0.11], [0.54, 0.06, y0 + 0.14, y0 + 0.08, 2.5], [0.62, 0.0, y0 + 0.09, y0 + 0.09]], 12), C.glass, Vector3.ZERO)
	roundel(root, Vector3(-0.25, y0 + 0.05, 0.111), 0.05, Vector3(90, 0, 0))
	roundel(root, Vector3(-0.25, y0 + 0.05, -0.111), 0.05, Vector3(90, 0, 0))
	return {"root": root, "turret": null, "pivot": Vector3.ZERO}

## Dominion strategic bomber: long fuselage, swept wings, four turboprops with contra-rotating discs.
static func bomber_plane() -> Dictionary:
	var C := mats("dominion")
	var root := Node3D.new()
	var y0 := 0.2
	K.add(root, K.loft([[-0.8, 0.02, y0 + 0.08, y0 + 0.04], [-0.5, 0.075, y0 + 0.1, y0 - 0.04, 2.2], [0.4, 0.085, y0 + 0.1, y0 - 0.05, 2.2], [0.7, 0.05, y0 + 0.05, y0 - 0.03, 2.2], [0.82, 0.0, y0 + 0.01, y0 + 0.0]], 22), C.team_rivet, Vector3.ZERO, Vector3.ZERO, true)
	var wing := PackedVector2Array([Vector2(0.22, 0.0), Vector2(-0.18, 0.9), Vector2(-0.3, 0.9), Vector2(-0.18, 0.0)])
	for side in [-1.0, 1.0]:
		K.add(root, K.extrude(mirror(wing, side), 0.02), C.team_panel, Vector3(0, y0 + 0.04, 0), Vector3(90, 0, 0), true)
		for k in 2:
			var z: float = side * (0.3 + k * 0.3)
			var x: float = 0.12 - (0.3 + k * 0.3) * 0.44
			K.add(root, K.loft([[x - 0.18, 0.0, y0 + 0.02, y0 + 0.02], [x - 0.1, 0.04, y0 + 0.05, y0 - 0.03], [x + 0.12, 0.035, y0 + 0.04, y0 - 0.02]], 12), C.sec_rivet, Vector3(0, 0, z))
			K.add(root, K.cylinder(0.07, 0.004, 20), K.paint(Color(0.55, 0.56, 0.57), 0.3, 0.6, {"stripes": 7.0}), Vector3(x + 0.14, y0 + 0.01, z), Vector3(0, 0, 90))
		var tail := PackedVector2Array([Vector2(-0.58, 0.0), Vector2(-0.72, 0.26), Vector2(-0.8, 0.26), Vector2(-0.78, 0.0)])
		K.add(root, K.extrude(mirror(tail, side), 0.012), C.team_panel, Vector3(0, y0 + 0.08, 0), Vector3(90, 0, 0), true)
		red_star(root, Vector3(-0.1, y0 + 0.062, side * 0.6), 0.06, Vector3(90, 0, 0))
	K.add(root, K.extrude(PackedVector2Array([Vector2(-0.52, 0.0), Vector2(-0.7, 0.3), Vector2(-0.8, 0.3), Vector2(-0.77, 0.0)]), 0.014), C.team, Vector3(0, y0 + 0.08, 0), Vector3.ZERO, true)
	K.ellipsoid(root, Vector3(0.66, y0 + 0.05, 0), Vector3(0.1, 0.05, 0.05), C.glass)
	K.ellipsoid(root, Vector3(-0.78, y0 + 0.06, 0), Vector3(0.05, 0.04, 0.035), C.glass)
	return {"root": root, "turret": null, "pivot": Vector3.ZERO}
