class_name AirNavalModels2
extends RefCounted
## Second wave of aircraft, sea units and the superweapon structures.
##   Coalition: Thunderbolt strategic bomber, Dolphin, Aegis cruiser, Weather Controller
##   Dominion:  Krepost bomber airship, Giant Squid, Sea Scorpion hydrofoil, Missile Silo
## Units face +X with the waterline / ground at y = 0. Structures span x, z in 0..size.

const K := preload("res://tools/art/kit.gd")
const V := preload("res://tools/art/vehicles.gd")
const M := preload("res://tools/art/hd_models.gd")

# ---------------------------------------------------------------- aircraft

static func strat_bomber() -> Dictionary:
	var C := V.mats("coalition")
	var root := Node3D.new()
	var y0 := 0.14
	var body := K.loft([[-0.62, 0.05, y0 + 0.07, y0 - 0.02, 3.0], [-0.4, 0.1, y0 + 0.09, y0 - 0.05, 3.0], [0.2, 0.1, y0 + 0.1, y0 - 0.05, 3.0],
		[0.45, 0.07, y0 + 0.07, y0 - 0.03, 2.5], [0.62, 0.0, y0 + 0.02, y0 + 0.0]], 22)
	K.add(root, body, C.team, Vector3.ZERO, Vector3.ZERO, true)
	# Long swept wings with four podded engines.
	var wing := PackedVector2Array([Vector2(0.12, 0.0), Vector2(-0.2, 0.72), Vector2(-0.3, 0.72), Vector2(-0.22, 0.0)])
	for side in [-1.0, 1.0]:
		K.add(root, K.extrude(V.mirror(wing, side), 0.016), C.team_panel, Vector3(0, y0 + 0.03, 0), Vector3(90, 0, 0), true)
		for k in 2:
			var z: float = side * (0.24 + k * 0.22)
			var x := 0.02 - (0.24 + k * 0.22) * 0.42
			K.add(root, K.lathe([Vector2(0.032, 0.0), Vector2(0.036, 0.04), Vector2(0.034, 0.18), Vector2(0.022, 0.2)], 12), V.dark(), Vector3(x + 0.1, y0 - 0.01, z), Vector3(0, 0, -90))
			K.add(root, K.cylinder(0.028, 0.01, 12), V.lamp(Color(1, 0.6, 0.3)), Vector3(x - 0.1, y0 - 0.01, z), Vector3(0, 0, 90))
		var tail := PackedVector2Array([Vector2(-0.48, 0.0), Vector2(-0.6, 0.24), Vector2(-0.67, 0.24), Vector2(-0.64, 0.0)])
		K.add(root, K.extrude(V.mirror(tail, side), 0.012), C.team_panel, Vector3(0, y0 + 0.05, 0), Vector3(90, 0, 0), true)
	K.add(root, K.extrude(PackedVector2Array([Vector2(-0.46, 0.0), Vector2(-0.58, 0.24), Vector2(-0.66, 0.24), Vector2(-0.62, 0.0)]), 0.014), C.team, Vector3(0, y0 + 0.07, 0), Vector3.ZERO, true)
	K.add(root, K.loft([[0.34, 0.0, y0 + 0.08, y0 + 0.08], [0.4, 0.05, y0 + 0.12, y0 + 0.06, 2.5], [0.5, 0.04, y0 + 0.1, y0 + 0.05, 2.5], [0.55, 0.0, y0 + 0.06, y0 + 0.06]], 14), C.glass, Vector3.ZERO)
	K.add(root, K.bevel_box(Vector3(0.3, 0.012, 0.1), 0.004), K.paint(Color(0.1, 0.1, 0.1), 0.2, 0.7, {"stripes": 20.0}), Vector3(0.0, y0 - 0.05, 0))   # bomb bay
	V.roundel(root, Vector3(-0.15, y0 + 0.048, 0.5), 0.045, Vector3.ZERO)
	V.roundel(root, Vector3(-0.15, y0 + 0.048, -0.5), 0.045, Vector3.ZERO)
	return {"root": root, "turret": null, "pivot": Vector3.ZERO}

static func airship() -> Dictionary:
	var C := V.mats("dominion")
	var root := Node3D.new()
	# Huge armoured envelope with riveted bands, tail fins, gondola and bomb bay.
	var env := K.loft([[-0.78, 0.0, 0.42, 0.42], [-0.7, 0.14, 0.56, 0.28], [-0.4, 0.26, 0.68, 0.16], [0.1, 0.29, 0.71, 0.13], [0.45, 0.25, 0.67, 0.17], [0.7, 0.14, 0.56, 0.28], [0.8, 0.0, 0.42, 0.42]], 28, 2.0)
	K.add(root, env, K.paint(Color(0.42, 0.43, 0.36), 0.3, 0.55, {"panel": 6.0, "panel_dark": 0.18, "rivets": 18.0}), Vector3.ZERO)
	for x in [-0.45, -0.1, 0.25, 0.55]:
		var rr := 0.29 * sqrt(maxf(0.05, 1.0 - pow(x / 0.8, 2.0)))
		K.add(root, K.lathe([Vector2(rr + 0.005, -0.012), Vector2(rr + 0.008, 0.0), Vector2(rr + 0.005, 0.012)], 26, true, false, false), C.team, Vector3(x, 0.42, 0), Vector3(0, 0, 90), true)
	for a in [0.0, 90.0, 180.0, 270.0]:
		var fin := K.extrude(PackedVector2Array([Vector2(-0.55, 0.0), Vector2(-0.82, 0.24), Vector2(-0.9, 0.24), Vector2(-0.78, 0.0)]), 0.014)
		var piv := Node3D.new()
		piv.position = Vector3(0, 0.42, 0)
		piv.rotation_degrees = Vector3(a, 0, 0)
		root.add_child(piv)
		K.add(piv, fin, C.team_rivet, Vector3(0, 0.12, 0), Vector3.ZERO, true)
	var gond := K.loft([[-0.3, 0.0, 0.14, 0.1], [-0.25, 0.08, 0.14, 0.03, 4.0], [0.25, 0.08, 0.14, 0.03, 4.0], [0.32, 0.0, 0.12, 0.08]], 16)
	K.add(root, gond, C.sec_rivet, Vector3.ZERO)
	for i in 6:
		K.add(root, K.bevel_box(Vector3(0.03, 0.025, 0.004), 0.003), M.glass_lit(), Vector3(-0.18 + i * 0.07, 0.1, 0.081))
	for side in [-1.0, 1.0]:
		K.add(root, K.cylinder(0.035, 0.07, 12), V.dark(), Vector3(-0.32, 0.36, side * 0.3), Vector3(0, 0, 90))
		K.add(root, K.cylinder(0.08, 0.006, 3), V.steel(), Vector3(-0.37, 0.36, side * 0.3), Vector3(0, 0, 90))   # propellers
	V.red_star(root, Vector3(0.2, 0.52, 0.255), 0.09, Vector3.ZERO)
	V.red_star(root, Vector3(0.2, 0.52, -0.255), 0.09, Vector3(0, 180, 0))
	return {"root": root, "turret": null, "pivot": Vector3.ZERO}

# ---------------------------------------------------------------- sea units

static func dolphin(phase: float = 0.0) -> Dictionary:
	var root := Node3D.new()
	var grey := K.paint(Color(0.52, 0.58, 0.64), 0.2, 0.35, {"noise_amt": 0.1})
	var belly := K.paint(Color(0.85, 0.87, 0.86), 0.1, 0.4)
	var y := 0.04
	var body := K.loft([[-0.3, 0.0, y + 0.03, y + 0.02], [-0.22, 0.04, y + 0.06, y - 0.02], [0.0, 0.07, y + 0.1, y - 0.04], [0.16, 0.06, y + 0.09, y - 0.03], [0.26, 0.03, y + 0.05, y - 0.01], [0.34, 0.012, y + 0.03, y + 0.01]], 18)
	K.add(root, body, grey, Vector3.ZERO)
	K.ellipsoid(root, Vector3(0.05, y - 0.02, 0), Vector3(0.16, 0.025, 0.05), belly)
	K.add(root, K.extrude(PackedVector2Array([Vector2(-0.04, 0.0), Vector2(-0.1, 0.09), Vector2(-0.14, 0.09), Vector2(-0.1, 0.0)]), 0.012), grey, Vector3(0.0, y + 0.08, 0))   # dorsal fin
	K.add(root, K.extrude(PackedVector2Array([Vector2(0.0, 0.0), Vector2(-0.08, 0.1), Vector2(-0.05, 0.0), Vector2(-0.08, -0.1)]), 0.01), grey, Vector3(-0.29, y + 0.025, 0), Vector3(90, 0, 0))   # flukes
	for side in [-1.0, 1.0]:
		K.ellipsoid(root, Vector3(0.24, y + 0.05, side * 0.035), Vector3(0.008, 0.008, 0.006), K.paint(Color(0.05, 0.05, 0.05), 0.0, 0.3))
	# Team-coloured harness band.
	K.add(root, K.lathe([Vector2(0.072, -0.012), Vector2(0.075, 0.0), Vector2(0.072, 0.012)], 18, true, false, false), V.mats("coalition").team, Vector3(0.06, y + 0.03, 0), Vector3(0, 0, 90), true)
	return {"root": root, "turret": null, "pivot": Vector3.ZERO, "naval": true}

static func aegis() -> Dictionary:
	var C := V.mats("coalition")
	var root := Node3D.new()
	var L := 1.6
	K.add(root, V._hull(L, 0.36, 0.1, 0.06), C.team, Vector3.ZERO, Vector3.ZERO, true)
	K.add(root, K.bevel_box(Vector3(L * 0.62, 0.01, 0.33), 0.003), K.paint(Color(0.34, 0.36, 0.37), 0.3, 0.7, {"panel": 10.0}), Vector3(-L * 0.18, 0.103, 0))
	# Tall block superstructure with four phased-array radar faces.
	K.add(root, K.bevel_box(Vector3(0.36, 0.22, 0.24), 0.02), C.team_panel, Vector3(0.05, 0.21, 0), Vector3.ZERO, true)
	for a in [0.0, 90.0, 180.0, 270.0]:
		var d := Vector3(cos(deg_to_rad(a)), 0, sin(deg_to_rad(a)))
		var off := Vector3(d.x * 0.181, 0, d.z * 0.121)
		K.add(root, K.bevel_box(Vector3(0.006, 0.09, 0.09), 0.003), K.paint(Color(0.3, 0.33, 0.36), 0.6, 0.3, {"panel": 30.0}), Vector3(0.05, 0.25, 0) + off, Vector3(0, -a, 0))
	K.tube(root, Vector3(0.05, 0.32, 0), Vector3(0.02, 0.55, 0), 0.012, V.steel(), 6)
	K.add(root, K.bevel_box(Vector3(0.025, 0.012, 0.16), 0.003), V.dark(), Vector3(0.025, 0.47, 0))
	K.add(root, K.cylinder(0.022, 0.04, 10), K.paint(Color(0.85, 0.85, 0.82), 0.1, 0.5), Vector3(0.02, 0.57, 0))
	# Fore and aft vertical launch cell blocks.
	for base_x in [0.42, -0.42]:
		for r in 3:
			for c in 4:
				K.add(root, K.bevel_box(Vector3(0.045, 0.012, 0.045), 0.003), K.paint(Color(0.24, 0.25, 0.26), 0.4, 0.6), Vector3(base_x + (r - 1) * 0.055, 0.112, -0.09 + c * 0.06))
	K.add(root, K.loft([[0.62, 0.05, 0.17, 0.1, 3.0], [0.72, 0.04, 0.16, 0.1, 3.0]], 12), C.team, Vector3.ZERO, Vector3.ZERO, true)
	V.barrel(root, Vector3(0.7, 0.14, 0), 0.16, 0.01, V.dark(), false, false)
	V.roundel(root, Vector3(0.0, 0.08, 0.181), 0.03, Vector3(90, 0, 0))
	return {"root": root, "turret": null, "pivot": Vector3.ZERO, "naval": true}

static func squid(phase: float = 0.0) -> Dictionary:
	var root := Node3D.new()
	var skin := K.paint(Color(0.62, 0.2, 0.26), 0.1, 0.45, {"noise_amt": 0.45})
	var under := K.paint(Color(0.82, 0.55, 0.5), 0.1, 0.5)
	# Mantle breaking the surface, big eyes, tentacles arching out of the water.
	var mantle := K.loft([[-0.34, 0.0, 0.05, 0.03], [-0.3, 0.07, 0.12, -0.02], [-0.05, 0.11, 0.16, -0.04], [0.12, 0.1, 0.14, -0.04], [0.2, 0.06, 0.08, -0.02]], 18)
	K.add(root, mantle, skin, Vector3.ZERO)
	K.add(root, K.extrude(PackedVector2Array([Vector2(-0.3, 0.0), Vector2(-0.42, 0.12), Vector2(-0.38, 0.0), Vector2(-0.42, -0.12)]), 0.01), skin, Vector3(0, 0.07, 0), Vector3(90, 0, 0))
	for side in [-1.0, 1.0]:
		K.ellipsoid(root, Vector3(0.15, 0.08, side * 0.08), Vector3(0.035, 0.035, 0.02), K.paint(Color(0.95, 0.85, 0.3), 0.2, 0.3, {"emit": 0.3}))
		K.ellipsoid(root, Vector3(0.17, 0.08, side * 0.088), Vector3(0.012, 0.022, 0.01), K.paint(Color(0.05, 0.05, 0.05), 0.0, 0.3))
	for i in 8:
		var a := -0.9 + i * (1.8 / 7.0)
		var dir := Vector3(cos(a), 0, sin(a))
		var p0 := Vector3(0.2, 0.02, 0) + dir * 0.05
		var p1 := p0 + dir * 0.14 + Vector3(0, 0.12 + 0.04 * sin(phase * TAU + i), 0)
		var p2 := p1 + dir * 0.12 + Vector3(0, -0.08, 0)
		var p3 := p2 + dir * 0.06 + Vector3(0, -0.06, 0)
		K.limb(root, p0, p1, 0.026, 0.02, skin, 10)
		K.limb(root, p1, p2, 0.02, 0.014, skin, 10)
		K.limb(root, p2, p3, 0.014, 0.006, under, 8)
	# Team-coloured tag on the mantle (trained beast).
	K.ellipsoid(root, Vector3(-0.12, 0.155, 0), Vector3(0.05, 0.012, 0.035), V.mats("dominion").team, Vector3.ZERO, true)
	return {"root": root, "turret": null, "pivot": Vector3.ZERO, "naval": true}

static func sea_scorpion() -> Dictionary:
	var C := V.mats("dominion")
	var root := Node3D.new()
	# Hydrofoil: hull lifted on struts above foils at the waterline.
	K.add(root, V._hull(0.86, 0.26, 0.09, 0.05), C.team_rivet, Vector3(0, 0.05, 0), Vector3.ZERO, true)
	for x in [0.25, -0.28]:
		K.add(root, K.bevel_box(Vector3(0.08, 0.008, 0.36), 0.003), V.dark(), Vector3(x, 0.01, 0))
		for side in [-1.0, 1.0]:
			K.tube(root, Vector3(x, 0.01, side * 0.15), Vector3(x, 0.07, side * 0.1), 0.008, V.dark(), 4)
	K.add(root, K.bevel_box(Vector3(0.26, 0.09, 0.18), 0.015), C.team_rivet, Vector3(-0.05, 0.2, 0), Vector3.ZERO, true)
	K.add(root, K.bevel_box(Vector3(0.006, 0.03, 0.15), 0.003), C.glass, Vector3(0.081, 0.22, 0), Vector3(0, 0, -25))
	K.tube(root, Vector3(-0.1, 0.25, 0), Vector3(-0.12, 0.38, 0), 0.008, V.steel(), 6)
	# Twin flak mount on the foredeck, angled up.
	var mount := Node3D.new()
	mount.position = Vector3(0.24, 0.17, 0)
	mount.rotation.z = 0.5
	root.add_child(mount)
	K.add(mount, K.bevel_box(Vector3(0.12, 0.06, 0.1), 0.01), C.sec_rivet, Vector3.ZERO)
	for z in [-0.025, 0.025]:
		V.barrel(mount, Vector3(0.05, 0.0, z), 0.18, 0.009, C.sec, false, true)
	V.red_star(root, Vector3(0.05, 0.12, 0.131), 0.03, Vector3.ZERO)
	return {"root": root, "turret": null, "pivot": Vector3.ZERO, "naval": true}

# ---------------------------------------------------------------- superweapon structures

static func weather_control(P: Dictionary, f: String, t: float = 0.0) -> Dictionary:
	var r := Node3D.new()
	M.pad(r, 2.0, 2.0, P)
	# Control block, four lightning-rod pylons and a central tower with a spinning coil cage.
	K.add(r, K.bevel_box(Vector3(0.7, 0.28, 0.5), 0.02), P.conc, Vector3(0.45, 0.2, 1.55))
	K.add(r, K.bevel_box(Vector3(0.72, 0.03, 0.52), 0.008), P.team_plain, Vector3(0.45, 0.35, 1.55), Vector3.ZERO, true)
	for i in 5:
		K.add(r, K.bevel_box(Vector3(0.08, 0.05, 0.004), 0.003), M.glass_lit(), Vector3(0.18 + i * 0.13, 0.22, 1.302))
	for c in [Vector2(0.3, 0.3), Vector2(1.7, 0.3), Vector2(1.7, 1.7), Vector2(1.15, 1.75)]:
		K.add(r, K.cylinder(0.05, 0.08, 10), P.conc2, Vector3(c.x, 0.1, c.y))
		K.tube(r, Vector3(c.x, 0.1, c.y), Vector3(c.x, 0.85, c.y), 0.012, M.steel(), 6)
		K.add(r, K.lathe([Vector2(0.03, 0.0), Vector2(0.0, 0.08)], 8), M.light(Color(0.6, 0.85, 1.0)), Vector3(c.x, 0.85, c.y))
	K.add(r, K.lathe([Vector2(0.32, 0.0), Vector2(0.3, 0.12), Vector2(0.18, 0.2), Vector2(0.14, 0.9), Vector2(0.2, 0.96), Vector2(0.0, 0.98)], 20), P.team, Vector3(1.05, 0.06, 0.95), Vector3.ZERO, true)
	var cage := Node3D.new()
	cage.position = Vector3(1.05, 1.2, 0.95)
	cage.rotation.y = t * TAU
	r.add_child(cage)
	for k in 6:
		var a := TAU * k / 6.0
		K.tube(cage, Vector3(cos(a) * 0.12, -0.2, sin(a) * 0.12), Vector3(cos(a + 0.8) * 0.18, 0.15, sin(a + 0.8) * 0.18), 0.01, M.steel(), 5)
	K.add(cage, K.lathe([Vector2(0.2, -0.015), Vector2(0.21, 0.0), Vector2(0.2, 0.015)], 24, true, false, false), M.steel(), Vector3(0, 0.15, 0))
	K.ellipsoid(cage, Vector3(0, 0.0, 0), Vector3(0.09, 0.09, 0.09), K.paint(Color(0.5, 0.8, 1.0), 0.0, 0.2, {"emit": 3.0}))
	return {"root": r, "height": 1.5}

static func missile_silo(P: Dictionary, f: String) -> Dictionary:
	var r := Node3D.new()
	M.pad(r, 2.0, 2.0, P)
	# Armoured launch pad: two half-open blast doors over a lit shaft with a missile nose cone.
	K.add(r, K.bevel_box(Vector3(1.3, 0.18, 1.3), 0.03), P.conc, Vector3(1.0, 0.12, 1.0))
	K.add(r, K.cylinder(0.32, 0.03, 24), K.paint(Color(0.05, 0.05, 0.05), 0.0, 1.0), Vector3(1.0, 0.215, 1.0))
	K.add(r, K.lathe([Vector2(0.17, 0.0), Vector2(0.16, 0.3), Vector2(0.1, 0.48), Vector2(0.0, 0.58)], 18), K.paint(Color(0.85, 0.85, 0.82), 0.3, 0.4), Vector3(1.0, 0.1, 1.0))
	K.add(r, K.lathe([Vector2(0.105, 0.0), Vector2(0.06, 0.08), Vector2(0.0, 0.1)], 18), K.paint(Color(0.75, 0.12, 0.08), 0.2, 0.5), Vector3(1.0, 0.58, 1.0))
	for side in [-1.0, 1.0]:
		K.add(r, K.bevel_box(Vector3(0.62, 0.07, 0.32), 0.012), V.mats("dominion").team_rivet, Vector3(1.0, 0.25, 1.0 + side * 0.52), Vector3(side * 12.0, 0, 0), true)
	for k in 8:
		var a := TAU * k / 8.0
		K.add(r, K.bevel_box(Vector3(0.1, 0.015, 0.03), 0.003), M.hazard(), Vector3(1.0 + cos(a) * 0.4, 0.215, 1.0 + sin(a) * 0.4), Vector3(0, -rad_to_deg(a), 0))
	K.add(r, K.bevel_box(Vector3(0.4, 0.3, 0.35), 0.02), P.conc2, Vector3(0.3, 0.15, 1.68))
	K.tube(r, Vector3(1.7, 0.2, 0.3), Vector3(1.7, 0.9, 0.3), 0.012, M.steel(), 6)
	K.add(r, K.bevel_box(Vector3(0.03, 0.12, 0.22), 0.006), K.paint(Color(0.65, 0.65, 0.6), 0.3, 0.5, {"panel": 20.0}), Vector3(1.7, 0.85, 0.3))
	return {"root": r, "height": 1.0}
