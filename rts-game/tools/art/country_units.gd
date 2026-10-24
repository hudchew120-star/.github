class_name CountryUnitModels
extends RefCounted
## Models for the country-specific units (units face +X, ground at y = 0):
##   Germany  - "Jagd" tank destroyer: low casemate with a long fixed gun.
##   Japan    - "Tengu" walking mecha: reverse-jointed legs, cockpit pod, twin rapid guns.
##   Korea    - "Black Eagle" strike jet: black paint, canards, team-coloured stripes.
##   Russia   - "Tsar" super-heavy tank: double tracks, twin 155 mm guns, missile pods.
##   China    - Gatling tank: rotary cannon turret with an ammunition drum.
##   France   - Grand Cannon: concrete fortress with a huge long-barrelled gun (a building).
## Builders return {root, turret (Node3D or null), pivot} like VehicleModels.

const K := preload("res://tools/art/kit.gd")
const V := preload("res://tools/art/vehicles.gd")
const M := preload("res://tools/art/hd_models.gd")

# ---------------------------------------------------------------- Germany

static func tank_destroyer() -> Dictionary:
	var C := V.mats("coalition")
	var grey := K.paint(Color(0.45, 0.47, 0.44), 0.25, 0.55, {"noise_amt": 0.2})
	var root := Node3D.new()
	var L := 0.92
	var W := 0.6
	V.tracks(root, L, W, 0.14, 6, 0.045, "coalition", C.team_rivet)
	# Low hull and a sloped casemate that carries the gun.
	K.add(root, V.armor_hull(L * 1.02, W * 0.86, 0.1, 0.2, 1.4), C.team_panel, Vector3.ZERO, Vector3.ZERO, true)
	var cp := [K.plane_at(Vector3.DOWN, Vector3(0, 0.19, 0)), K.plane_at(Vector3.UP, Vector3(0, 0.33, 0)),
		K.plane_at(Vector3(1, 0.9, 0), Vector3(0.24, 0.26, 0)), K.plane_at(Vector3(-1, 0.35, 0), Vector3(-0.36, 0.26, 0)),
		K.plane_at(Vector3(0, 0.55, 1), Vector3(0, 0.26, 0.24)), K.plane_at(Vector3(0, 0.55, -1), Vector3(0, 0.26, -0.24))]
	K.add(root, K.convex(cp), C.team_panel, Vector3.ZERO, Vector3.ZERO, true)
	# Gun mantlet (pig's head) and the long 128 mm barrel with a muzzle brake.
	K.ellipsoid(root, Vector3(0.27, 0.265, 0.03), Vector3(0.07, 0.065, 0.075), grey)
	V.barrel(root, Vector3(0.3, 0.27, 0.03), 0.62, 0.02, grey, true, true)
	# Commander's cupola, periscopes, spare track links, jerry cans and an exhaust.
	K.add(root, K.lathe([Vector2(0.05, 0.0), Vector2(0.05, 0.035), Vector2(0.04, 0.05), Vector2(0.0, 0.055)], 14), grey, Vector3(-0.14, 0.33, -0.1))
	for z in [-0.05, 0.12]:
		K.add(root, K.bevel_box(Vector3(0.03, 0.025, 0.04), 0.005), V.dark(), Vector3(0.05, 0.335, z))
	for k in 4:
		K.add(root, K.bevel_box(Vector3(0.05, 0.012, 0.13), 0.003), V.track(), Vector3(0.12 + k * 0.055, 0.215, 0.0), Vector3(0, 0, -28))
	for z in [-0.18, -0.1]:
		K.add(root, K.bevel_box(Vector3(0.07, 0.08, 0.05), 0.008), K.paint(Color(0.3, 0.33, 0.24), 0.1, 0.6), Vector3(-0.42, 0.24, z))
	K.add(root, K.cylinder(0.025, 0.1, 10), V.dark(), Vector3(-0.47, 0.2, 0.17), Vector3(0, 0, 90))
	mg_ring(root, Vector3(-0.2, 0.34, 0.12))
	# Black cross insignia on both sides.
	for side in [-1.0, 1.0]:
		iron_cross(root, Vector3(-0.08, 0.25, side * 0.245))
	V.antenna(root, Vector3(-0.3, 0.33, 0.16), 0.3)
	return {"root": root, "turret": null, "pivot": Vector3.ZERO}

static func mg_ring(p: Node3D, at: Vector3) -> void:
	K.add(p, K.bevel_box(Vector3(0.07, 0.03, 0.025), 0.005), V.dark(), at)
	K.add(p, K.cylinder(0.006, 0.13, 6), V.dark(), at + Vector3(0.09, 0.0, 0), Vector3(0, 0, 90))

static func iron_cross(p: Node3D, at: Vector3) -> void:
	var white := K.paint(Color(0.92, 0.92, 0.9), 0.0, 0.5)
	var black := K.paint(Color(0.08, 0.08, 0.08), 0.0, 0.5)
	K.add(p, K.bevel_box(Vector3(0.075, 0.025, 0.004), 0.002), white, at)
	K.add(p, K.bevel_box(Vector3(0.025, 0.075, 0.004), 0.002), white, at)
	K.add(p, K.bevel_box(Vector3(0.06, 0.014, 0.006), 0.002), black, at)
	K.add(p, K.bevel_box(Vector3(0.014, 0.06, 0.006), 0.002), black, at)

# ---------------------------------------------------------------- Japan

## Walking mecha. phase < 0: standing; 0..1: walk cycle.
static func mecha(phase: float) -> Dictionary:
	var C := V.mats("coalition")
	var white := K.paint(Color(0.86, 0.86, 0.84), 0.2, 0.45, {"panel": 9.0, "panel_dark": 0.2})
	var joint := K.paint(Color(0.2, 0.21, 0.23), 0.6, 0.4)
	var root := Node3D.new()
	var walking := phase >= 0.0
	var hip_y := 0.36
	var bob := absf(sin(phase * TAU)) * 0.025 if walking else 0.0
	var body := Node3D.new()
	body.position = Vector3(0, hip_y + bob, 0)
	root.add_child(body)
	# Reverse-jointed ("chicken") legs: thigh forward, shin back, long foot with toes.
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var ph := phase + (0.5 if i == 1 else 0.0)
		var swing := sin(ph * TAU) * 0.12 if walking else 0.0
		var lift := maxf(0.0, cos(ph * TAU)) * 0.06 if walking else 0.0
		var hip := Vector3(0.0, hip_y + bob, side * 0.12)
		var foot := Vector3(swing, 0.03 + lift, side * 0.15)
		var knee := Vector3((hip.x + foot.x) * 0.5 + 0.11, (hip.y + foot.y) * 0.5 + 0.03, side * 0.14)
		K.limb(root, hip, knee, 0.05, 0.04, white, 12, true)
		K.limb(root, knee, foot + Vector3(-0.02, 0.04, 0), 0.035, 0.03, joint, 10)
		K.ellipsoid(root, knee, Vector3(0.04, 0.04, 0.045), joint)
		var f := Node3D.new()
		f.position = foot
		root.add_child(f)
		K.add(f, K.bevel_box(Vector3(0.16, 0.035, 0.07), 0.01), joint, Vector3(0.03, 0.0, 0))
		for z in [-0.025, 0.025]:
			K.add(f, K.bevel_box(Vector3(0.05, 0.025, 0.025), 0.006), white, Vector3(0.12, -0.003, z), Vector3(0, z * 400.0, -10))
	# Cockpit pod: rounded hull with a visor and team-coloured shoulder plates.
	K.ellipsoid(body, Vector3(0.0, 0.07, 0), Vector3(0.17, 0.11, 0.15), white, Vector3.ZERO, false, 20)
	K.add(body, K.bevel_box(Vector3(0.05, 0.05, 0.16), 0.015), K.paint(Color(0.95, 0.5, 0.15), 0.8, 0.1, {"emit": 0.6}), Vector3(0.15, 0.09, 0))
	K.ellipsoid(body, Vector3(-0.05, 0.14, 0), Vector3(0.12, 0.05, 0.12), C.team, Vector3.ZERO, true)
	for side in [-1.0, 1.0]:
		K.ellipsoid(body, Vector3(0.0, 0.12, side * 0.17), Vector3(0.08, 0.05, 0.06), C.team, Vector3(side * 20.0, 0, 0), true)
		# Twin rapid-fire guns on the forearms.
		K.add(body, K.bevel_box(Vector3(0.14, 0.05, 0.05), 0.01), joint, Vector3(0.08, 0.04, side * 0.2))
		K.add(body, K.cylinder(0.012, 0.18, 8), V.dark(), Vector3(0.23, 0.04, side * 0.2), Vector3(0, 0, 90))
		K.add(body, K.cylinder(0.018, 0.03, 8), V.dark(), Vector3(0.32, 0.04, side * 0.2), Vector3(0, 0, 90))
	# Rising-sun disc on the back, antenna fins.
	K.add(body, K.cylinder(0.04, 0.006, 16), K.paint(Color(0.85, 0.1, 0.1), 0.0, 0.5, {"emit": 0.1}), Vector3(-0.17, 0.08, 0), Vector3(0, 0, 90))
	for side in [-1.0, 1.0]:
		K.tube(body, Vector3(-0.05, 0.17, side * 0.05), Vector3(-0.16, 0.28, side * 0.09), 0.006, V.dark(), 4)
	return {"root": root, "turret": null, "pivot": Vector3.ZERO}

# ---------------------------------------------------------------- Korea

static func black_eagle() -> Dictionary:
	var C := V.mats("coalition")
	var black := K.paint(Color(0.13, 0.13, 0.14), 0.1, 0.95, {"panel": 8.0, "panel_dark": 0.25})
	var root := Node3D.new()
	var y0 := 0.12
	var body := K.loft([[-0.46, 0.08, y0 + 0.07, y0 - 0.02, 4.0], [-0.2, 0.12, y0 + 0.09, y0 - 0.035, 4.0], [0.12, 0.085, y0 + 0.1, y0 - 0.03, 3.5], [0.34, 0.045, y0 + 0.065, y0 - 0.015, 2.6], [0.52, 0.0, y0 + 0.02, y0 + 0.01]], 20)
	K.add(root, body, black, Vector3.ZERO)
	var wing := PackedVector2Array([Vector2(0.08, 0.0), Vector2(-0.2, 0.44), Vector2(-0.3, 0.44), Vector2(-0.32, 0.0)])
	for side in [-1.0, 1.0]:
		K.add(root, K.extrude(V.mirror(wing, side), 0.014), black, Vector3(0, y0 + 0.02, 0), Vector3(90, 0, 0))
		# Team-coloured wing tip stripes.
		K.add(root, K.extrude(V.mirror(PackedVector2Array([Vector2(-0.17, 0.38), Vector2(-0.2, 0.44), Vector2(-0.3, 0.44), Vector2(-0.29, 0.38)]), side), 0.018), C.team, Vector3(0, y0 + 0.02, 0), Vector3(90, 0, 0), true)
		var canard := PackedVector2Array([Vector2(0.3, 0.0), Vector2(0.2, 0.13), Vector2(0.16, 0.13), Vector2(0.18, 0.0)])
		K.add(root, K.extrude(V.mirror(canard, side), 0.01), black, Vector3(0, y0 + 0.05, 0), Vector3(90, 0, 0))
		var fin := K.extrude(PackedVector2Array([Vector2(-0.3, 0.0), Vector2(-0.4, 0.17), Vector2(-0.46, 0.17), Vector2(-0.44, 0.0)]), 0.01)
		K.add(root, fin, C.team, Vector3(0, y0 + 0.07, side * 0.075), Vector3(side * 18.0, 0, 0), true)
		K.add(root, K.loft([[0.0, 0.0, y0 + 0.03, y0 + 0.03], [0.12, 0.045, y0 + 0.06, y0 - 0.025, 4.0], [0.22, 0.045, y0 + 0.06, y0 - 0.025, 4.0]], 12), V.dark(), Vector3(0, 0, side * 0.09))
		# Underwing missiles.
		K.add(root, K.cylinder(0.014, 0.2, 8), K.paint(Color(0.85, 0.85, 0.82), 0.2, 0.5), Vector3(-0.1, y0 - 0.01, side * 0.26), Vector3(0, 0, 90))
	K.add(root, K.loft([[0.14, 0.0, y0 + 0.1, y0 + 0.1], [0.2, 0.036, y0 + 0.145, y0 + 0.08, 2.5], [0.33, 0.032, y0 + 0.13, y0 + 0.07, 2.5], [0.4, 0.0, y0 + 0.08, y0 + 0.08]], 14), K.paint(Color(0.85, 0.65, 0.2), 0.9, 0.08), Vector3.ZERO)
	for z in [-0.04, 0.04]:
		K.add(root, K.lathe([Vector2(0.04, 0.0), Vector2(0.037, 0.06), Vector2(0.03, 0.08)], 14, true, false, false), V.dark(), Vector3(-0.46, y0 + 0.03, z), Vector3(0, 0, 90))
		K.add(root, K.cylinder(0.03, 0.01, 14), V.lamp(Color(0.5, 0.7, 1.0)), Vector3(-0.53, y0 + 0.03, z), Vector3(0, 0, 90))
	# Taegeuk roundels.
	for side in [-1.0, 1.0]:
		K.add(root, K.cylinder(0.035, 0.004, 18), K.paint(Color(0.92, 0.92, 0.9), 0.0, 0.5), Vector3(-0.12, y0 + 0.031, side * 0.28))
		K.add(root, K.cylinder(0.022, 0.006, 18), K.paint(Color(0.8, 0.15, 0.2), 0.0, 0.5), Vector3(-0.12, y0 + 0.032, side * 0.28))
	return {"root": root, "turret": null, "pivot": Vector3.ZERO}

# ---------------------------------------------------------------- Russia

static func tsar_tank() -> Dictionary:
	var C := V.mats("dominion")
	var root := Node3D.new()
	var L := 1.16
	var W := 0.84
	# Double track units per side, like the old super-heavies.
	for side in [-1.0, 1.0]:
		var pair := Node3D.new()
		pair.position = Vector3(0, 0, side * (W * 0.5 - 0.17))
		root.add_child(pair)
		V.tracks(pair, L, 0.34, 0.15, 7, 0.05, "dominion", null)
		K.add(root, K.bevel_box(Vector3(L * 1.03, 0.02, 0.36), 0.006), C.sec_rivet, Vector3(0, 0.15, side * (W * 0.5 - 0.17)))
	K.add(root, V.armor_hull(L * 1.02, W * 0.6, 0.13, 0.3, 1.4, 0.06), C.team_rivet, Vector3.ZERO, Vector3.ZERO, true)
	for r in 2:
		for c in 6:
			K.add(root, K.bevel_box(Vector3(0.06, 0.03, 0.07), 0.006), C.era, Vector3(L * 0.42 + r * 0.045, 0.26 - r * 0.04, -0.2 + c * 0.08), Vector3(0, 0, -40))
	for z in [-0.16, 0.0, 0.16]:
		K.add(root, K.cylinder(0.05, 0.15, 16), C.rust, Vector3(-L * 0.53, 0.31, z), Vector3(90, 0, 0))
	K.add(root, K.bevel_box(Vector3(0.22, 0.014, W * 0.4), 0.004), K.paint(Color(0.12, 0.12, 0.11), 0.4, 0.6, {"stripes": 46.0}), Vector3(-L * 0.34, 0.3, 0))
	for side in [-1.0, 1.0]:
		V.red_star(root, Vector3(0.05, 0.2, side * W * 0.5), 0.05, Vector3.ZERO)
	var tur := Node3D.new()
	var dome := K.loft([[-0.33, 0.0, 0.08, 0.08], [-0.3, 0.16, 0.14, 0.0], [-0.14, 0.25, 0.2, 0.0], [0.06, 0.26, 0.21, 0.0], [0.2, 0.22, 0.17, 0.0], [0.29, 0.12, 0.11, 0.0], [0.31, 0.0, 0.05, 0.05]], 26, 2.2)
	K.add(tur, dome, C.team_rivet, Vector3.ZERO, Vector3.ZERO, true)
	K.add(tur, K.bevel_box(Vector3(0.12, 0.13, 0.3), 0.02), C.sec_rivet, Vector3(0.27, 0.09, 0))
	for z in [-0.075, 0.075]:
		V.barrel(tur, Vector3(0.32, 0.095, z), 0.64, 0.024, C.sec, true, true)
	# Missile pods ("Tusks") on both turret cheeks.
	for side in [-1.0, 1.0]:
		var pod := Node3D.new()
		pod.position = Vector3(-0.02, 0.17, side * 0.3)
		pod.rotation.z = 0.2
		tur.add_child(pod)
		K.add(pod, K.bevel_box(Vector3(0.3, 0.1, 0.1), 0.012), C.sec_rivet, Vector3.ZERO)
		for k in 4:
			K.add(pod, K.cylinder(0.018, 0.01, 10), K.paint(Color(0.8, 0.78, 0.7), 0.2, 0.5), Vector3(0.152, -0.022 + (k / 2) * 0.045, -0.022 + (k % 2) * 0.045), Vector3(0, 0, 90))
		K.add(tur, K.bevel_box(Vector3(0.06, 0.04, 0.06), 0.008), V.dark(), Vector3(-0.02, 0.13, side * 0.24))
	K.add(tur, K.lathe([Vector2(0.06, 0.0), Vector2(0.06, 0.04), Vector2(0.05, 0.065), Vector2(0.0, 0.07)], 16), C.sec_rivet, Vector3(-0.1, 0.2, 0.1))
	V.mg(tur, Vector3(-0.07, 0.28, 0.1), "dominion")
	K.add(tur, K.bevel_box(Vector3(0.16, 0.07, 0.26), 0.012), C.sec_rivet, Vector3(-0.36, 0.09, 0))
	V.antenna(tur, Vector3(-0.26, 0.15, -0.14), 0.42)
	V.red_star(tur, Vector3(-0.05, 0.14, 0.235), 0.04, Vector3.ZERO)
	return {"root": root, "turret": tur, "pivot": Vector3(-0.08, 0.3, 0)}

# ---------------------------------------------------------------- China

static func gatling_tank() -> Dictionary:
	var C := V.mats("dominion")
	var green := K.paint(Color(0.32, 0.36, 0.26), 0.3, 0.6, {"noise_amt": 0.3})
	var root := Node3D.new()
	var L := 0.84
	var W := 0.6
	V.tracks(root, L, W, 0.14, 6, 0.045, "dominion", null)
	K.add(root, V.armor_hull(L * 1.03, W * 0.8, 0.1, 0.24, 1.6, 0.045), C.team_rivet, Vector3.ZERO, Vector3.ZERO, true)
	for side in [-1.0, 1.0]:
		K.add(root, K.bevel_box(Vector3(L * 1.02, 0.016, 0.15), 0.005), C.sec_rivet, Vector3(0, 0.135, side * (W * 0.5 - 0.07)))
		gold_star(root, Vector3(0.0, 0.18, side * (W * 0.4 + 0.002)))
	for z in [-0.12, 0.12]:
		K.add(root, K.cylinder(0.045, 0.14, 14), C.rust, Vector3(-L * 0.52, 0.26, z), Vector3(90, 0, 0))
	var tur := Node3D.new()
	var tp := [K.plane_at(Vector3.DOWN, Vector3.ZERO), K.plane_at(Vector3.UP, Vector3(0, 0.12, 0)),
		K.plane_at(Vector3(1, 0.5, 0), Vector3(0.16, 0.06, 0)), K.plane_at(Vector3(-1, 0.1, 0), Vector3(-0.22, 0.06, 0)),
		K.plane_at(Vector3(0, 0.3, 1), Vector3(0, 0.06, 0.16)), K.plane_at(Vector3(0, 0.3, -1), Vector3(0, 0.06, -0.16)),
		K.plane_at(Vector3(1, 0.2, 1.4), Vector3(0.1, 0.06, 0.13)), K.plane_at(Vector3(1, 0.2, -1.4), Vector3(0.1, 0.06, -0.13))]
	K.add(tur, K.convex(tp), C.team_rivet, Vector3.ZERO, Vector3.ZERO, true)
	# Six-barrel rotary cannon in a cradle, with a big side ammunition drum.
	var gun := Node3D.new()
	gun.position = Vector3(0.18, 0.07, 0.0)
	tur.add_child(gun)
	K.add(gun, K.cylinder(0.05, 0.1, 14), green, Vector3(0.02, 0, 0), Vector3(0, 0, 90))
	for k in 6:
		var a := TAU * k / 6.0
		K.add(gun, K.cylinder(0.011, 0.42, 8), V.dark(), Vector3(0.26, cos(a) * 0.028, sin(a) * 0.028), Vector3(0, 0, 90))
	for x in [0.2, 0.44]:
		K.add(gun, K.cylinder(0.042, 0.02, 14), green, Vector3(x, 0, 0), Vector3(0, 0, 90))
	K.add(tur, K.cylinder(0.08, 0.12, 18), green, Vector3(-0.05, 0.08, -0.2), Vector3(90, 0, 0))
	K.tube(tur, Vector3(0.0, 0.08, -0.15), Vector3(0.16, 0.07, -0.05), 0.016, V.dark(), 6)
	K.add(tur, K.lathe([Vector2(0.045, 0.0), Vector2(0.045, 0.035), Vector2(0.0, 0.04)], 14), C.sec_rivet, Vector3(-0.1, 0.12, 0.08))
	V.antenna(tur, Vector3(-0.18, 0.12, 0.1), 0.34)
	return {"root": root, "turret": tur, "pivot": Vector3(-0.03, 0.24, 0)}

static func gold_star(p: Node3D, at: Vector3) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := PI * 0.5 + TAU * i / 10.0
		var rr := 0.045 if i % 2 == 0 else 0.019
		pts.append(Vector2(cos(a) * rr, sin(a) * rr))
	K.add(p, K.extrude(pts, 0.004), K.paint(Color(0.95, 0.8, 0.15), 0.3, 0.4, {"emit": 0.15}), at)

# ---------------------------------------------------------------- France

## 2x2 fortress base; the gun itself is the "top" (turret) sheet.
static func grand_cannon_base(P: Dictionary, f: String) -> Dictionary:
	var r := Node3D.new()
	K.add(r, K.bevel_box(Vector3(1.94, 0.06, 1.94), 0.02), P.conc2, Vector3(1.0, 0.03, 1.0))
	K.add(r, K.lathe([Vector2(0.9, 0.0), Vector2(0.88, 0.14), Vector2(0.78, 0.3), Vector2(0.0, 0.31)], 8, false), P.conc, Vector3(1.0, 0.04, 1.0), Vector3(0, 22.5, 0))
	K.add(r, K.lathe([Vector2(0.86, 0.12), Vector2(0.86, 0.17)], 8, false), K.paint(Color(0.15, 0.22, 0.45), 0.1, 0.55), Vector3(1.0, 0.04, 1.0), Vector3(0, 22.5, 0))
	# Tricolour band on the front faces.
	var cols := [Color(0.1, 0.2, 0.55), Color(0.92, 0.92, 0.9), Color(0.85, 0.12, 0.15)]
	for i in 3:
		K.add(r, K.bevel_box(Vector3(0.12, 0.08, 0.01), 0.003), K.paint(cols[i], 0.0, 0.5), Vector3(0.88 + i * 0.12, 0.2, 1.84))
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		K.add(r, K.bevel_box(Vector3(0.2, 0.1, 0.12), 0.015), P.conc2, Vector3(1.0 + cos(a) * 0.74, 0.32, 1.0 + sin(a) * 0.74), Vector3(0, -rad_to_deg(a), 0))
	K.add(r, K.cylinder(0.5, 0.05, 24), M.dark(), Vector3(1.0, 0.36, 1.0))
	for c in [Vector3(0.2, 0.06, 0.2), Vector3(1.8, 0.06, 1.8)]:
		K.add(r, K.cylinder(0.05, 0.03, 10), M.light(Color(1, 0.7, 0.3)), c + Vector3(0, 0.02, 0))
	return {"root": r, "height": 0.6, "pivot": Vector3(1.0, 0.38, 1.0), "top": grand_cannon_top, "top_frame": Vector2i(320, 240)}

static func grand_cannon_top(P: Dictionary, f: String) -> Node3D:
	var t := Node3D.new()
	var dome := K.loft([[-0.45, 0.0, 0.1, 0.1], [-0.42, 0.3, 0.22, 0.0], [-0.2, 0.42, 0.32, 0.0], [0.1, 0.42, 0.33, 0.0], [0.3, 0.34, 0.27, 0.0], [0.42, 0.18, 0.16, 0.0], [0.45, 0.0, 0.08, 0.08]], 28, 2.4)
	K.add(t, dome, P.team, Vector3.ZERO, Vector3.ZERO, true)
	K.add(t, K.bevel_box(Vector3(0.2, 0.2, 0.32), 0.03), P.sec, Vector3(0.42, 0.17, 0))
	var gun := Node3D.new()
	gun.position = Vector3(0.5, 0.18, 0)
	gun.rotation.z = 0.12
	t.add_child(gun)
	K.add(gun, K.lathe([Vector2(0.075, 0.0), Vector2(0.07, 0.25), Vector2(0.05, 0.35), Vector2(0.045, 1.05), Vector2(0.0, 1.05)], 16), P.sec_plain, Vector3.ZERO, Vector3(0, 0, -90))
	K.add(gun, K.lathe([Vector2(0.07, 0.0), Vector2(0.075, 0.04), Vector2(0.075, 0.12), Vector2(0.065, 0.14), Vector2(0.03, 0.141)], 16), M.dark(), Vector3(1.0, 0, 0), Vector3(0, 0, -90))
	for x in [0.3, 0.62]:
		K.add(gun, K.lathe([Vector2(0.055, 0.0), Vector2(0.065, 0.02), Vector2(0.065, 0.05), Vector2(0.055, 0.07)], 16, true, false, false), P.sec, Vector3(x, 0, 0), Vector3(0, 0, -90))
	K.add(t, K.lathe([Vector2(0.07, 0.0), Vector2(0.07, 0.05), Vector2(0.0, 0.06)], 14), P.sec, Vector3(-0.15, 0.32, 0.14))
	K.add(t, K.bevel_box(Vector3(0.18, 0.08, 0.3), 0.015), P.sec, Vector3(-0.42, 0.14, 0))
	V.antenna(t, Vector3(-0.3, 0.26, -0.18), 0.4)
	return t
