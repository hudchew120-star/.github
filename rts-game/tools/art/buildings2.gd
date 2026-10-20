extends RefCounted
## Phase-3 structures: airfield, naval yard (built on water), repair facility, SAM site and
## flak cannon. Footprint spans (0,0)-(sx,sz); the camera sees the +X and +Z faces.
## Coalition buildings are clean steel-and-glass; Dominion ones are brutalist concrete
## with rust, hazard paint and red stars.

const K := preload("res://tools/art/kit.gd")
const M := preload("res://tools/art/hd_models.gd")
const B := preload("res://tools/art/hd_buildings.gd")
const V := preload("res://tools/art/vehicles.gd")

static func _helipad(r: Node3D, c: Vector3, rad: float, P: Dictionary) -> void:
	K.add(r, K.cylinder(rad, 0.02, 28), K.paint(Color(0.3, 0.31, 0.31), 0.0, 0.9, {"noise_amt": 0.3}), c + Vector3(0, 0.07, 0))
	var ring := K.lathe([Vector2(rad * 0.86, 0.0), Vector2(rad * 0.86, 0.004), Vector2(rad * 0.78, 0.004), Vector2(rad * 0.78, 0.0)], 28, true, false, false)
	K.add(r, ring, M.yellow(), c + Vector3(0, 0.081, 0))
	var w := K.paint(Color(0.92, 0.92, 0.88), 0.0, 0.7)
	K.add(r, K.bevel_box(Vector3(rad * 0.12, 0.004, rad * 0.8), 0.002), w, c + Vector3(-rad * 0.25, 0.082, 0))
	K.add(r, K.bevel_box(Vector3(rad * 0.12, 0.004, rad * 0.8), 0.002), w, c + Vector3(rad * 0.25, 0.082, 0))
	K.add(r, K.bevel_box(Vector3(rad * 0.5, 0.004, rad * 0.12), 0.002), w, c + Vector3(0, 0.082, 0))
	for k in 8:
		var a := TAU * k / 8.0
		K.add(r, K.cylinder(0.012, 0.01, 8), M.light(Color(0.4, 0.8, 1.0) if P.get("f", "") == "coalition" else Color(1, 0.5, 0.2)), c + Vector3(cos(a) * rad * 0.95, 0.085, sin(a) * rad * 0.95))

# ---------------------------------------------------------------- airfield

static func airfield(P: Dictionary, f: String) -> Dictionary:
	var r := Node3D.new()
	P["f"] = f
	B.pad(r, 3.0, 3.0, P)
	for i in 6:
		K.add(r, K.bevel_box(Vector3(0.2, 0.004, 0.04), 0.002), K.paint(Color(0.9, 0.9, 0.86), 0.0, 0.7), Vector3(0.3 + i * 0.45, 0.062, 2.75))
	_helipad(r, Vector3(0.75, 0, 1.95), 0.5, P)
	_helipad(r, Vector3(2.2, 0, 1.95), 0.5, P)
	if f == "coalition":
		# Curved steel hangar and a glass-topped control tower.
		var arch := K.loft([[0.0, 0.0, 0.0, 0.0], [0.02, 0.62, 0.55, -0.0, 2.0], [1.55, 0.62, 0.55, 0.0, 2.0], [1.57, 0.0, 0.0, 0.0]], 24, 2.0)
		K.add(r, arch, P.roof, Vector3(0.12, 0.06, 0.62), Vector3(0, 0, 0))
		K.add(r, K.bevel_box(Vector3(0.02, 0.4, 1.0), 0.006), K.paint(Color(0.24, 0.26, 0.28), 0.5, 0.4, {"stripes": 30.0}), Vector3(1.7, 0.26, 0.62))
		K.add(r, K.bevel_box(Vector3(0.03, 0.04, 1.1), 0.008), P.team_plain, Vector3(1.69, 0.5, 0.62), Vector3.ZERO, true)
		var tw := Vector3(2.55, 0.06, 0.45)
		K.add(r, K.lathe([Vector2(0.18, 0.0), Vector2(0.16, 0.1), Vector2(0.11, 0.2), Vector2(0.1, 0.9)], 16), P.conc, tw)
		K.add(r, K.lathe([Vector2(0.2, 0.0), Vector2(0.24, 0.12), Vector2(0.22, 0.2), Vector2(0.0, 0.22)], 16), M.glass(), tw + Vector3(0, 0.9, 0))
		K.add(r, K.lathe([Vector2(0.25, 0.0), Vector2(0.25, 0.03), Vector2(0.0, 0.04)], 16), P.team_plain, tw + Vector3(0, 1.12, 0), Vector3.ZERO, true)
		K.tube(r, tw + Vector3(0, 1.16, 0), tw + Vector3(0, 1.45, 0), 0.008, M.steel(), 6)
		B.beacon(r, tw + Vector3(0, 1.45, 0))
		var dome := K.lathe([Vector2(0.1, 0.0), Vector2(0.09, 0.06), Vector2(0.05, 0.11), Vector2(0.0, 0.12)], 14)
		K.add(r, dome, K.paint(Color(0.92, 0.92, 0.9), 0.1, 0.5), tw + Vector3(0.14, 1.16, 0.0))
		B.emblem(r, "x", Vector3(1.72, 0.48, 1.0), 0.09, f)
	else:
		# Hardened aircraft shelter (thick concrete arch) and a brutalist tower.
		var arch := K.loft([[0.0, 0.0, 0.0, 0.0], [0.04, 0.66, 0.58, 0.0, 2.6], [1.5, 0.66, 0.58, 0.0, 2.6], [1.56, 0.0, 0.0, 0.0]], 24)
		K.add(r, arch, P.conc, Vector3(0.12, 0.06, 0.62))
		K.add(r, K.bevel_box(Vector3(0.05, 0.42, 0.9), 0.01), K.paint(Color(0.3, 0.29, 0.26), 0.6, 0.5, {"rivets": 18.0}), Vector3(1.67, 0.27, 0.62))
		K.add(r, K.bevel_box(Vector3(0.06, 0.06, 1.05), 0.01), M.hazard(), Vector3(1.69, 0.06, 0.62))
		B.block(r, Vector3(2.5, 0.06, 0.5), Vector3(0.5, 0.55, 0.5), P.conc2, P.roof)
		B.block(r, Vector3(2.5, 0.61, 0.5), Vector3(0.38, 0.3, 0.38), P.conc, P.roof)
		B.win_row(r, "z", Vector3(2.36, 0.78, 0.695), 3, 0.13, Vector2(0.08, 0.07))
		B.win_row(r, "x", Vector3(2.695, 0.78, 0.36), 3, 0.13, Vector2(0.08, 0.07))
		K.add(r, K.bevel_box(Vector3(0.52, 0.04, 0.52), 0.01), P.team_plain, Vector3(2.5, 0.5, 0.5), Vector3.ZERO, true)
		var dish := K.lathe([Vector2(0.0, 0.0), Vector2(0.08, 0.01), Vector2(0.14, 0.04)], 18, true, false, false)
		K.add(r, dish, K.paint(Color(0.75, 0.76, 0.7), 0.4, 0.4), Vector3(2.5, 1.02, 0.5), Vector3(0, 0, -50))
		V.red_star(r, Vector3(1.68, 0.5, 0.62), 0.11, Vector3(0, 90, 0))
	# Windsock, fuel truck, light posts.
	K.tube(r, Vector3(2.85, 0.06, 2.85), Vector3(2.85, 0.4, 2.85), 0.006, M.steel(), 4)
	K.add(r, K.lathe([Vector2(0.03, 0.0), Vector2(0.018, 0.14)], 10, true, false, false), K.paint(Color(1, 0.45, 0.1), 0.0, 0.6, {"stripes": 10.0}), Vector3(2.85, 0.39, 2.85), Vector3(0, 30, -90))
	B.barrels(r, Vector3(0.15, 0.06, 2.75), 4, Color(0.6, 0.15, 0.1) if f == "dominion" else Color(0.3, 0.45, 0.3))
	B.light_post(r, Vector3(1.48, 0.06, 2.9))
	return {"root": r, "height": 1.5}

# ---------------------------------------------------------------- naval yard (on water)

static func naval_yard(P: Dictionary, f: String) -> Dictionary:
	var r := Node3D.new()
	var deck := K.paint(Color(0.42, 0.43, 0.42) if f == "coalition" else Color(0.38, 0.35, 0.31), 0.2, 0.85, {"panel": 5.0, "panel_dark": 0.18, "grime": 0.4})
	var pile := K.paint(Color(0.2, 0.2, 0.19), 0.4, 0.6)
	# U-shaped pier around an open basin (water shows through the middle).
	for p in [[Vector3(1.5, 0.0, 0.3), Vector3(2.9, 0.12, 0.5)], [Vector3(0.3, 0.0, 1.6), Vector3(0.5, 0.12, 2.3)], [Vector3(2.7, 0.0, 1.6), Vector3(0.5, 0.12, 2.3)]]:
		var c: Vector3 = p[0]
		var s: Vector3 = p[1]
		K.add(r, K.bevel_box(s, 0.02), deck, c + Vector3(0, 0.08, 0))
		var nx := int(s.x / 0.3)
		var nz := int(s.z / 0.3)
		for i in nx + 1:
			for k in [-1.0, 1.0]:
				K.add(r, K.cylinder(0.03, 0.08, 8), pile, c + Vector3(-s.x * 0.5 + i * s.x / maxf(nx, 1), 0.03, k * s.z * 0.45))
		for i in nz + 1:
			for k in [-1.0, 1.0]:
				K.add(r, K.cylinder(0.03, 0.08, 8), pile, c + Vector3(k * s.x * 0.45, 0.03, -s.z * 0.5 + i * s.z / maxf(nz, 1)))
	# Hazard edges and bollards along the basin.
	for x in [0.55, 2.45]:
		K.add(r, K.bevel_box(Vector3(0.03, 0.01, 2.2), 0.003), M.hazard(), Vector3(x, 0.145, 1.65))
		for i in 6:
			K.add(r, K.lathe([Vector2(0.025, 0.0), Vector2(0.02, 0.03), Vector2(0.03, 0.04), Vector2(0.0, 0.045)], 8), M.dark(), Vector3(x - 0.06 * signf(x - 1.5), 0.14, 0.75 + i * 0.4))
	if f == "coalition":
		# Gantry crane spanning the basin, control building, team stripe.
		for x in [0.4, 2.6]:
			K.add(r, K.bevel_box(Vector3(0.08, 0.9, 0.08), 0.01), M.yellow(), Vector3(x, 0.59, 1.7))
		K.add(r, K.bevel_box(Vector3(2.4, 0.1, 0.12), 0.012), M.yellow(), Vector3(1.5, 1.08, 1.7))
		K.add(r, K.bevel_box(Vector3(0.2, 0.12, 0.18), 0.015), P.team_plain, Vector3(1.2, 1.0, 1.7), Vector3.ZERO, true)
		K.tube(r, Vector3(1.2, 0.94, 1.7), Vector3(1.2, 0.55, 1.7), 0.004, M.dark(), 4)
		K.add(r, K.bevel_box(Vector3(0.1, 0.04, 0.06), 0.006), M.dark(), Vector3(1.2, 0.54, 1.7))
		B.block(r, Vector3(2.3, 0.14, 0.35), Vector3(0.9, 0.42, 0.45), P.conc, P.roof)
		B.win_row(r, "z", Vector3(1.95, 0.4, 0.578), 6, 0.14)
		B.win_row(r, "x", Vector3(2.753, 0.4, 0.2), 2, 0.14)
		K.add(r, K.bevel_box(Vector3(0.92, 0.05, 0.47), 0.008), P.team_plain, Vector3(2.3, 0.53, 0.35), Vector3.ZERO, true)
		K.tube(r, Vector3(2.6, 0.58, 0.3), Vector3(2.6, 0.95, 0.3), 0.01, M.steel(), 6)
		K.add(r, K.bevel_box(Vector3(0.03, 0.02, 0.2), 0.004), M.dark(), Vector3(2.6, 0.9, 0.3))
		B.emblem(r, "z", Vector3(1.0, 0.4, 0.57), 0.1, f)
	else:
		# Armoured submarine pen with a concrete roof and a heavy jib crane.
		B.block(r, Vector3(1.5, 0.14, 0.42), Vector3(2.7, 0.5, 0.6), P.conc, P.roof)
		K.add(r, K.bevel_box(Vector3(1.0, 0.36, 0.04), 0.008), K.paint(Color(0.08, 0.09, 0.1), 0.0, 1.0), Vector3(1.5, 0.32, 0.72))
		K.add(r, K.bevel_box(Vector3(1.06, 0.05, 0.06), 0.008), M.hazard(), Vector3(1.5, 0.52, 0.73))
		K.add(r, K.bevel_box(Vector3(2.72, 0.05, 0.62), 0.01), P.team_plain, Vector3(1.5, 0.66, 0.42), Vector3.ZERO, true)
		B.win_row(r, "z", Vector3(0.3, 0.45, 0.722), 3, 0.15)
		var crane := K.pivot(r, Vector3(2.7, 0.14, 2.4))
		K.add(crane, K.lathe([Vector2(0.12, 0.0), Vector2(0.1, 0.1)], 12), K.paint(Color(0.55, 0.15, 0.1), 0.4, 0.6), Vector3.ZERO)
		K.add(crane, K.bevel_box(Vector3(0.1, 0.8, 0.1), 0.01), K.paint(Color(0.55, 0.15, 0.1), 0.4, 0.6, {"rivets": 20.0}), Vector3(0, 0.5, 0))
		K.add(crane, K.bevel_box(Vector3(1.1, 0.07, 0.07), 0.01), K.paint(Color(0.55, 0.15, 0.1), 0.4, 0.6), Vector3(-0.45, 0.9, -0.2), Vector3(0, 25, 8))
		K.tube(crane, Vector3(-0.92, 0.95, -0.42), Vector3(-0.92, 0.5, -0.42), 0.004, M.dark(), 4)
		V.red_star(r, Vector3(2.2, 0.38, 0.725), 0.11, Vector3.ZERO)
		B.barrels(r, Vector3(0.2, 0.2, 2.4), 5, Color(0.5, 0.2, 0.1))
	B.light_post(r, Vector3(0.3, 0.14, 2.65))
	B.light_post(r, Vector3(2.7, 0.14, 2.65))
	B.crates(r, Vector3(0.18, 0.14, 1.0), 3)
	return {"root": r, "height": 1.2}

# ---------------------------------------------------------------- repair facility

static func repair(P: Dictionary, f: String) -> Dictionary:
	var r := Node3D.new()
	B.pad(r, 3.0, 3.0, P)
	# Central service bay with drive-in arrows.
	K.add(r, K.bevel_box(Vector3(1.6, 0.03, 1.6), 0.01), K.paint(Color(0.26, 0.27, 0.28), 0.4, 0.7, {"panel": 6.0, "panel_dark": 0.3}), Vector3(1.5, 0.075, 1.5))
	var stripe := K.bevel_box(Vector3(1.7, 0.006, 0.06), 0.002)
	for z in [0.68, 2.32]:
		K.add(r, stripe, M.hazard(), Vector3(1.5, 0.09, z))
	for i in 3:
		var arrow := K.extrude(PackedVector2Array([Vector2(-0.1, -0.06), Vector2(0.04, -0.06), Vector2(0.04, -0.12), Vector2(0.14, 0.0), Vector2(0.04, 0.12), Vector2(0.04, 0.06), Vector2(-0.1, 0.06)]), 0.006)
		K.add(r, arrow, K.paint(Color(0.9, 0.9, 0.85), 0.0, 0.7), Vector3(0.9 + i * 0.6, 0.093, 1.5), Vector3(90, 0, 0))
	var col := M.yellow() if f == "coalition" else K.paint(Color(0.55, 0.15, 0.1), 0.4, 0.6, {"rivets": 20.0})
	# Four corner pylons (the footprint's solid cells) carrying an overhead gantry.
	for c in [Vector2(0.5, 0.5), Vector2(2.5, 0.5), Vector2(0.5, 2.5), Vector2(2.5, 2.5)]:
		B.block(r, Vector3(c.x, 0.06, c.y), Vector3(0.6, 0.22, 0.6), P.conc2, P.roof)
		K.add(r, K.bevel_box(Vector3(0.14, 0.75, 0.14), 0.015), col, Vector3(c.x, 0.65, c.y))
		K.add(r, K.bevel_box(Vector3(0.62, 0.03, 0.62), 0.008), P.team_plain, Vector3(c.x, 0.3, c.y), Vector3.ZERO, true)
	for z in [0.5, 2.5]:
		K.add(r, K.bevel_box(Vector3(2.15, 0.1, 0.12), 0.012), col, Vector3(1.5, 1.05, z))
	for x in [0.5, 2.5]:
		K.add(r, K.bevel_box(Vector3(0.12, 0.1, 2.15), 0.012), col, Vector3(x, 1.05, 1.5))
	# Two robotic service arms (coalition) or chain hoists (dominion) hanging over the bay.
	if f == "coalition":
		for z in [1.15, 1.85]:
			var base := Vector3(1.5, 1.0, z)
			K.add(r, K.bevel_box(Vector3(0.16, 0.08, 0.16), 0.012), M.steel(), base)
			var elbow := base + Vector3(0.18, -0.28, 0.0)
			var tip := elbow + Vector3(-0.08, -0.26, 0.0)
			K.limb(r, base, elbow, 0.035, 0.03, M.yellow())
			K.limb(r, elbow, tip, 0.03, 0.022, M.yellow())
			K.add(r, K.cylinder(0.02, 0.05, 10), M.dark(), tip)
			K.add(r, K.cylinder(0.012, 0.01, 8), M.light(Color(0.4, 0.85, 1.0)), tip + Vector3(0, -0.03, 0))
		B.block(r, Vector3(2.5, 0.28, 2.5), Vector3(0.4, 0.2, 0.4), P.conc, P.roof)
		B.emblem(r, "z", Vector3(2.5, 0.38, 2.705), 0.08, f)
	else:
		for z in [1.15, 1.85]:
			var top := Vector3(1.5, 1.0, z)
			K.add(r, K.bevel_box(Vector3(0.18, 0.1, 0.14), 0.012), M.dark(), top)
			K.tube(r, top, top + Vector3(0, -0.45, 0), 0.008, M.steel(), 6)
			K.add(r, K.lathe([Vector2(0.0, 0.0), Vector2(0.04, 0.02), Vector2(0.03, 0.06), Vector2(0.0, 0.08)], 10), M.dark(), top + Vector3(0, -0.53, 0))
		V.red_star(r, Vector3(2.5, 0.2, 2.805), 0.08, Vector3.ZERO)
	B.light_post(r, Vector3(1.5, 0.06, 0.15))
	B.beacon(r, Vector3(0.5, 1.1, 0.5), Color(1, 0.6, 0.1))
	B.beacon(r, Vector3(2.5, 1.1, 2.5), Color(1, 0.6, 0.1))
	return {"root": r, "height": 1.2}

# ---------------------------------------------------------------- anti-air defences

static func sam_base(P: Dictionary, f: String) -> Dictionary:
	var r := Node3D.new()
	K.add(r, K.lathe([Vector2(0.46, 0.0), Vector2(0.45, 0.06), Vector2(0.4, 0.12), Vector2(0.0, 0.13)], 12), P.conc2, Vector3(0.5, 0, 0.5))
	var sand := K.paint(Color(0.66, 0.58, 0.42), 0.0, 1.0, {"noise_amt": 0.4})
	for i in 10:
		var a := TAU * i / 10.0
		K.ellipsoid(r, Vector3(0.5 + cos(a) * 0.43, 0.06, 0.5 + sin(a) * 0.43), Vector3(0.05, 0.04, 0.11), sand, Vector3(0, -rad_to_deg(a), 0))
	K.add(r, K.cylinder(0.2, 0.04, 20), M.dark(), Vector3(0.5, 0.15, 0.5))
	return {"root": r, "height": 0.6, "pivot": Vector3(0.5, 0.17, 0.5), "top": sam_top}

static func sam_top(P: Dictionary, f: String) -> Node3D:
	var t := Node3D.new()
	K.add(t, K.cylinder(0.17, 0.06, 20), P.team, Vector3(0, 0.03, 0), Vector3.ZERO, true)
	var box := Node3D.new()
	box.position = Vector3(-0.02, 0.12, 0)
	box.rotation.z = 0.6
	t.add_child(box)
	K.add(box, K.bevel_box(Vector3(0.42, 0.16, 0.24), 0.015), K.paint(Color(0.6, 0.57, 0.46), 0.2, 0.6, {"panel": 10.0}), Vector3.ZERO)
	for i in 4:
		K.add(box, K.cylinder(0.04, 0.006, 14), K.paint(Color(0.9, 0.9, 0.86), 0.1, 0.5), Vector3(0.211, -0.04 + (i / 2) * 0.08, -0.055 + (i % 2) * 0.11), Vector3(0, 0, 90))
	for side in [-1.0, 1.0]:
		K.add(t, K.bevel_box(Vector3(0.12, 0.14, 0.03), 0.008), P.team, Vector3(-0.02, 0.1, side * 0.13), Vector3.ZERO, true)
	K.tube(t, Vector3(-0.12, 0.06, 0.0), Vector3(-0.14, 0.32, 0.0), 0.012, M.steel(), 6)
	K.add(t, K.bevel_box(Vector3(0.03, 0.1, 0.16), 0.008), K.paint(Color(0.85, 0.85, 0.82), 0.2, 0.5, {"panel": 24.0}), Vector3(-0.13, 0.34, 0), Vector3(0, 0, -15))
	return t

static func flak_base(P: Dictionary, f: String) -> Dictionary:
	var r := Node3D.new()
	K.add(r, K.lathe([Vector2(0.47, 0.0), Vector2(0.47, 0.1), Vector2(0.43, 0.2), Vector2(0.28, 0.21), Vector2(0.0, 0.21)], 8, false), P.conc, Vector3(0.5, 0, 0.5), Vector3(0, 22.5, 0))
	K.add(r, K.lathe([Vector2(0.44, 0.17), Vector2(0.44, 0.2)], 8, false), M.hazard(), Vector3(0.5, 0, 0.5), Vector3(0, 22.5, 0))
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		K.add(r, K.bevel_box(Vector3(0.1, 0.08, 0.08), 0.01), K.paint(Color(0.3, 0.29, 0.22), 0.3, 0.6), Vector3(0.5 + cos(a) * 0.36, 0.25, 0.5 + sin(a) * 0.36))
	K.add(r, K.cylinder(0.22, 0.04, 20), M.dark(), Vector3(0.5, 0.23, 0.5))
	return {"root": r, "height": 0.75, "pivot": Vector3(0.5, 0.25, 0.5), "top": flak_top}

static func flak_top(P: Dictionary, f: String) -> Node3D:
	var t := Node3D.new()
	var C := V.mats("dominion")
	K.add(t, K.cylinder(0.2, 0.05, 20), C.sec_rivet, Vector3(0, 0.025, 0))
	var shield := K.loft([[-0.12, 0.0, 0.2, 0.05], [-0.1, 0.17, 0.24, 0.05, 3.0], [0.1, 0.18, 0.22, 0.05, 3.0], [0.16, 0.15, 0.16, 0.05, 3.0]], 18)
	K.add(t, shield, C.team_rivet, Vector3.ZERO, Vector3.ZERO, true)
	var cradle := Node3D.new()
	cradle.position = Vector3(0.08, 0.17, 0)
	cradle.rotation.z = 0.5
	t.add_child(cradle)
	K.add(cradle, K.bevel_box(Vector3(0.22, 0.08, 0.16), 0.012), C.sec, Vector3.ZERO)
	for z in [-0.045, 0.045]:
		V.barrel(cradle, Vector3(0.08, 0.0, z), 0.42, 0.014, C.sec, false, true)
	K.add(t, K.bevel_box(Vector3(0.1, 0.12, 0.08), 0.01), K.paint(Color(0.35, 0.38, 0.27), 0.3, 0.6), Vector3(-0.12, 0.12, 0.13))
	V.red_star(t, Vector3(0.0, 0.16, 0.181), 0.035, Vector3.ZERO)
	return t
