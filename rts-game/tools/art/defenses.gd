class_name DefenseModels
extends RefCounted
## Extra base defenses and walls (all on one 1x1 cell spanning x, z in 0..1):
##   Coalition - Guard Tower, Mortar Pit, Missile Bunker, Concrete Wall
##   Dominion  - Bunker, Twin Cannon, Rocket Battery, Iron Wall
## Turreted defenses return {root, height, pivot, top}; top(P, faction) builds the rotating part.

const K := preload("res://tools/art/kit.gd")
const M := preload("res://tools/art/hd_models.gd")
const V := preload("res://tools/art/vehicles.gd")

static func sand() -> ShaderMaterial: return K.paint(Color(0.66, 0.58, 0.42), 0.0, 1.0, {"noise_amt": 0.4})

## Ring of sandbags around (cx, cz) with radius r, n bags, rows high.
static func sandbag_ring(r: Node3D, c: Vector3, rad: float, n: int, rows: int, gap_from: float = 99.0, gap_to: float = 99.0) -> void:
	var mat := sand()
	for row in rows:
		for i in n:
			var a := TAU * (i + row * 0.5) / n
			if a > gap_from and a < gap_to:
				continue
			K.ellipsoid(r, c + Vector3(cos(a) * rad, 0.035 + row * 0.055, sin(a) * rad), Vector3(0.05, 0.032, 0.085), mat, Vector3(0, -rad_to_deg(a), 0))

# ---------------------------------------------------------------- Coalition

static func guard_tower(P: Dictionary, f: String) -> Dictionary:
	var r := Node3D.new()
	K.add(r, K.bevel_box(Vector3(0.8, 0.05, 0.8), 0.02), P.conc2, Vector3(0.5, 0.025, 0.5))
	var steel := M.steel()
	var h := 0.72
	# Four splayed steel legs with cross bracing.
	var foot := [Vector3(0.18, 0.05, 0.18), Vector3(0.82, 0.05, 0.18), Vector3(0.82, 0.05, 0.82), Vector3(0.18, 0.05, 0.82)]
	var top := [Vector3(0.3, h, 0.3), Vector3(0.7, h, 0.3), Vector3(0.7, h, 0.7), Vector3(0.3, h, 0.7)]
	for i in 4:
		K.tube(r, foot[i], top[i], 0.018, steel, 6)
		var j := (i + 1) % 4
		K.tube(r, foot[i].lerp(top[i], 0.3), foot[j].lerp(top[j], 0.62), 0.007, steel, 4)
		K.tube(r, foot[j].lerp(top[j], 0.3), foot[i].lerp(top[i], 0.62), 0.007, steel, 4)
	# Ladder.
	for k in 2:
		K.tube(r, Vector3(0.66 + k * 0.08, 0.05, 0.86), Vector3(0.62 + k * 0.08, h, 0.7), 0.006, M.dark(), 4)
	# Cabin: plank floor, sandbag parapet, corner posts and a sloped tin roof in team colour.
	K.add(r, K.bevel_box(Vector3(0.52, 0.04, 0.52), 0.01), K.paint(Color(0.45, 0.36, 0.25), 0.0, 0.9, {"corrugate": 60.0}), Vector3(0.5, h, 0.5))
	var mat := sand()
	for side in 4:
		for i in 4:
			var t := -0.18 + i * 0.12
			var p: Vector3 = [Vector3(t, 0, -0.24), Vector3(0.24, 0, t), Vector3(-t, 0, 0.24), Vector3(-0.24, 0, -t)][side]
			for row in 2:
				K.ellipsoid(r, Vector3(0.5, h + 0.05 + row * 0.05, 0.5) + p, Vector3(0.065, 0.03, 0.045) if side % 2 == 0 else Vector3(0.045, 0.03, 0.065), mat)
	for c in [Vector3(0.27, 0, 0.27), Vector3(0.73, 0, 0.27), Vector3(0.73, 0, 0.73), Vector3(0.27, 0, 0.73)]:
		K.add(r, K.cylinder(0.012, 0.22, 6), M.dark(), Vector3(c.x, h + 0.13, c.z))
	var roof := K.convex([K.plane_at(Vector3.DOWN, Vector3(0, h + 0.24, 0)), K.plane_at(Vector3(0, 1, 0.25), Vector3(0, h + 0.3, 0.5)),
		K.plane_at(Vector3(1, 0, 0), Vector3(0.82, 0, 0)), K.plane_at(Vector3(-1, 0, 0), Vector3(0.18, 0, 0)),
		K.plane_at(Vector3(0, 0, 1), Vector3(0, 0, 0.82)), K.plane_at(Vector3(0, 0, -1), Vector3(0, 0, 0.18))])
	K.add(r, roof, P.team, Vector3.ZERO, Vector3.ZERO, true)
	# Machine gun on the parapet and a searchlight.
	K.add(r, K.bevel_box(Vector3(0.1, 0.035, 0.03), 0.006), M.dark(), Vector3(0.78, h + 0.13, 0.5))
	K.add(r, K.cylinder(0.008, 0.16, 6), M.dark(), Vector3(0.88, h + 0.135, 0.5), Vector3(0, 0, 90))
	K.add(r, K.cylinder(0.035, 0.06, 12), M.dark(), Vector3(0.5, h + 0.14, 0.78), Vector3(90, 0, 0))
	K.add(r, K.cylinder(0.03, 0.005, 12), M.light(Color(1, 0.95, 0.75)), Vector3(0.5, h + 0.14, 0.812), Vector3(90, 0, 0))
	return {"root": r, "height": h + 0.36}

static func mortar_base(P: Dictionary, f: String) -> Dictionary:
	var r := Node3D.new()
	K.add(r, K.lathe([Vector2(0.44, 0.0), Vector2(0.42, 0.04), Vector2(0.3, 0.05), Vector2(0.0, 0.03)], 20), K.paint(Color(0.45, 0.4, 0.31), 0.0, 1.0, {"noise_amt": 0.5}), Vector3(0.5, 0, 0.5))
	sandbag_ring(r, Vector3(0.5, 0, 0.5), 0.37, 14, 2, 0.9, 1.5)
	# Ammunition crates and shells.
	for i in 3:
		K.add(r, K.bevel_box(Vector3(0.1, 0.05, 0.06), 0.008), K.paint(Color(0.32, 0.36, 0.24), 0.0, 0.8), Vector3(0.32 + i * 0.02, 0.06 + i * 0.05, 0.3), Vector3(0, i * 15.0, 0))
	for i in 4:
		K.add(r, K.cylinder(0.012, 0.07, 8), K.paint(Color(0.55, 0.5, 0.2), 0.6, 0.4), Vector3(0.66 + i * 0.03, 0.06, 0.28), Vector3(0, 0, 0))
	K.add(r, K.cylinder(0.12, 0.02, 16), M.dark(), Vector3(0.5, 0.05, 0.5))
	return {"root": r, "height": 0.4, "pivot": Vector3(0.5, 0.06, 0.5), "top": mortar_top}

static func mortar_top(P: Dictionary, f: String) -> Node3D:
	var t := Node3D.new()
	K.add(t, K.cylinder(0.08, 0.02, 14), M.dark(), Vector3(-0.04, 0.01, 0))           # base plate
	var tube := Node3D.new()
	tube.position = Vector3(-0.04, 0.03, 0)
	tube.rotation.z = deg_to_rad(-38)
	t.add_child(tube)
	K.add(tube, K.lathe([Vector2(0.03, 0.0), Vector2(0.026, 0.02), Vector2(0.024, 0.36), Vector2(0.03, 0.37), Vector2(0.0, 0.371)], 12), P.sec_plain, Vector3.ZERO)
	K.add(tube, K.lathe([Vector2(0.034, 0.0), Vector2(0.034, 0.03)], 12, true, false, false), P.team, Vector3(0, 0.2, 0), Vector3.ZERO, true)
	for z in [-0.06, 0.06]:
		K.tube(t, Vector3(0.12, 0.22, 0.0), Vector3(0.18, 0.0, z), 0.007, M.dark(), 4)   # bipod
	K.add(t, K.bevel_box(Vector3(0.04, 0.03, 0.06), 0.006), M.dark(), Vector3(0.1, 0.18, 0.04))   # sight
	return t

static func missile_bunker_base(P: Dictionary, f: String) -> Dictionary:
	var r := Node3D.new()
	var bp := [K.plane_at(Vector3.DOWN, Vector3(0, 0, 0)), K.plane_at(Vector3.UP, Vector3(0, 0.26, 0)),
		K.plane_at(Vector3(1, 0.8, 0), Vector3(0.92, 0.1, 0)), K.plane_at(Vector3(-1, 0.8, 0), Vector3(0.08, 0.1, 0)),
		K.plane_at(Vector3(0, 0.8, 1), Vector3(0, 0.1, 0.92)), K.plane_at(Vector3(0, 0.8, -1), Vector3(0, 0.1, 0.08)),
		K.plane_at(Vector3(1, 0.6, 1), Vector3(0.86, 0.1, 0.86)), K.plane_at(Vector3(-1, 0.6, -1), Vector3(0.14, 0.1, 0.14)),
		K.plane_at(Vector3(1, 0.6, -1), Vector3(0.86, 0.1, 0.14)), K.plane_at(Vector3(-1, 0.6, 1), Vector3(0.14, 0.1, 0.86))]
	K.add(r, K.convex(bp), P.conc, Vector3.ZERO)
	# Firing slits, hazard band and a team-coloured hatch ring.
	for a in [0.0, 90.0, 180.0, 270.0]:
		var d := Vector3(cos(deg_to_rad(a)), 0, sin(deg_to_rad(a)))
		K.add(r, K.bevel_box(Vector3(0.025, 0.03, 0.2), 0.004), K.paint(Color(0.04, 0.04, 0.04), 0.0, 1.0), Vector3(0.5, 0.15, 0.5) + d * 0.38, Vector3(0, -a, 0))
	K.add(r, K.lathe([Vector2(0.24, 0.0), Vector2(0.24, 0.025)], 20, true, false, false), M.hazard(), Vector3(0.5, 0.25, 0.5))
	K.add(r, K.cylinder(0.2, 0.03, 20), P.team_plain, Vector3(0.5, 0.265, 0.5), Vector3.ZERO, true)
	return {"root": r, "height": 0.55, "pivot": Vector3(0.5, 0.28, 0.5), "top": missile_bunker_top}

static func missile_bunker_top(P: Dictionary, f: String) -> Node3D:
	var t := Node3D.new()
	K.add(t, K.cylinder(0.05, 0.1, 12), P.sec_plain, Vector3(0, 0.05, 0))
	var box := Node3D.new()
	box.position = Vector3(0.0, 0.14, 0)
	box.rotation.z = 0.12
	t.add_child(box)
	for z in [-0.075, 0.075]:
		K.add(box, K.bevel_box(Vector3(0.36, 0.08, 0.08), 0.012), K.paint(Color(0.58, 0.56, 0.47), 0.2, 0.6, {"panel": 12.0}), Vector3(0.04, 0, z))
		K.add(box, K.cylinder(0.03, 0.006, 12), K.paint(Color(0.9, 0.9, 0.86), 0.1, 0.5), Vector3(0.222, 0, z), Vector3(0, 0, 90))
	K.add(box, K.bevel_box(Vector3(0.12, 0.09, 0.06), 0.01), P.team, Vector3(-0.06, 0.0, 0.0), Vector3.ZERO, true)
	K.add(box, K.cylinder(0.025, 0.04, 10), M.dark(), Vector3(0.1, 0.07, 0.0), Vector3(0, 0, 90))   # thermal sight
	K.add(box, K.cylinder(0.02, 0.004, 10), K.paint(Color(0.3, 0.5, 0.6), 0.9, 0.1), Vector3(0.122, 0.07, 0.0), Vector3(0, 0, 90))
	return t

static func concrete_wall(mask: int, damaged: bool) -> Node3D:
	var r := Node3D.new()
	var conc := K.paint(Color(0.68, 0.67, 0.63), 0.0, 0.9, {"noise_amt": 0.35, "grime": 0.6})
	var stripe := K.paint(Color(0.92, 0.72, 0.15), 0.1, 0.6, {"stripes": 18.0})
	var h := 0.32 if not damaged else 0.2
	# Central post plus a jersey-barrier arm towards each connected neighbour (N, E, S, W).
	K.add(r, K.bevel_box(Vector3(0.24, h + 0.05, 0.24), 0.02), conc, Vector3(0.5, (h + 0.05) * 0.5, 0.5))
	K.add(r, K.bevel_box(Vector3(0.25, 0.03, 0.25), 0.008), stripe, Vector3(0.5, h + 0.05, 0.5))
	# Arms run from the post to the cell edge, so neighbouring sections meet.
	var arms := [Vector3(0.5, 0, 0.19), Vector3(0.81, 0, 0.5), Vector3(0.5, 0, 0.81), Vector3(0.19, 0, 0.5)]
	for k in 4:
		if mask & (1 << k) == 0:
			continue
		var c: Vector3 = arms[k]
		var along_x := k % 2 == 1
		var L := 0.4
		# Wide base, narrow top: the classic barrier profile.
		K.add(r, K.bevel_box(Vector3(L if along_x else 0.17, 0.08, 0.17 if along_x else L), 0.012), conc, Vector3(c.x, 0.04, c.z))
		K.add(r, K.bevel_box(Vector3(L if along_x else 0.1, h, 0.1 if along_x else L), 0.012), conc, Vector3(c.x, h * 0.5 + 0.02, c.z))
	if damaged:
		for i in 5:
			K.add(r, K.bevel_box(Vector3(0.06, 0.04, 0.05), 0.01), conc, Vector3(0.3 + fmod(i * 0.37, 0.4), 0.02, 0.3 + fmod(i * 0.53, 0.4)), Vector3(i * 20.0, i * 47.0, i * 13.0))
	return r

# ---------------------------------------------------------------- Dominion

static func bunker(P: Dictionary, f: String) -> Dictionary:
	var r := Node3D.new()
	# Half-buried dome with an earth berm, firing slits and protruding MG barrels.
	K.add(r, K.lathe([Vector2(0.48, 0.0), Vector2(0.44, 0.08), Vector2(0.38, 0.12), Vector2(0.0, 0.13)], 18), K.paint(Color(0.42, 0.36, 0.27), 0.0, 1.0, {"noise_amt": 0.6}), Vector3(0.5, 0, 0.5))
	K.add(r, K.lathe([Vector2(0.36, 0.0), Vector2(0.35, 0.1), Vector2(0.3, 0.2), Vector2(0.2, 0.27), Vector2(0.0, 0.3)], 8, false), P.conc, Vector3(0.5, 0.06, 0.5), Vector3(0, 22.5, 0))
	for a in [0.0, 90.0, 180.0, 270.0]:
		var d := Vector3(cos(deg_to_rad(a)), 0, sin(deg_to_rad(a)))
		K.add(r, K.bevel_box(Vector3(0.03, 0.035, 0.14), 0.004), K.paint(Color(0.04, 0.04, 0.04), 0.0, 1.0), Vector3(0.5, 0.2, 0.5) + d * 0.33, Vector3(0, -a, 0))
		K.tube(r, Vector3(0.5, 0.2, 0.5) + d * 0.3, Vector3(0.5, 0.2, 0.5) + d * 0.45, 0.01, M.dark(), 6)
	K.add(r, K.cylinder(0.12, 0.04, 16), P.team_plain, Vector3(0.5, 0.36, 0.5), Vector3.ZERO, true)
	K.add(r, K.cylinder(0.06, 0.02, 12), P.sec_plain, Vector3(0.5, 0.39, 0.5))
	V.red_star(r, Vector3(0.5, 0.37, 0.5), 0.06, Vector3(90, 0, 0))
	return {"root": r, "height": 0.45}

static func twin_cannon_base(P: Dictionary, f: String) -> Dictionary:
	var r := Node3D.new()
	K.add(r, K.lathe([Vector2(0.47, 0.0), Vector2(0.47, 0.1), Vector2(0.42, 0.2), Vector2(0.0, 0.21)], 8, false), P.conc, Vector3(0.5, 0, 0.5), Vector3(0, 22.5, 0))
	K.add(r, K.lathe([Vector2(0.44, 0.14), Vector2(0.44, 0.18)], 8, false), K.paint(Color(0.72, 0.12, 0.08), 0.1, 0.6), Vector3(0.5, 0, 0.5), Vector3(0, 22.5, 0))
	K.add(r, K.cylinder(0.28, 0.03, 20), M.dark(), Vector3(0.5, 0.22, 0.5))
	return {"root": r, "height": 0.6, "pivot": Vector3(0.5, 0.23, 0.5), "top": twin_cannon_top}

static func twin_cannon_top(P: Dictionary, f: String) -> Node3D:
	var C := V.mats("dominion")
	var t := Node3D.new()
	var dome := K.loft([[-0.24, 0.0, 0.06, 0.06], [-0.22, 0.13, 0.12, 0.0], [-0.08, 0.19, 0.17, 0.0], [0.08, 0.19, 0.17, 0.0], [0.19, 0.14, 0.13, 0.0], [0.24, 0.0, 0.05, 0.05]], 24, 2.2)
	K.add(t, dome, C.team_rivet, Vector3.ZERO, Vector3.ZERO, true)
	K.add(t, K.bevel_box(Vector3(0.1, 0.11, 0.24), 0.02), C.sec_rivet, Vector3(0.22, 0.08, 0))
	for z in [-0.06, 0.06]:
		V.barrel(t, Vector3(0.26, 0.085, z), 0.55, 0.021, C.sec, true, true)
	K.add(t, K.lathe([Vector2(0.05, 0.0), Vector2(0.05, 0.035), Vector2(0.0, 0.04)], 14), C.sec_rivet, Vector3(-0.06, 0.17, 0.07))
	V.red_star(t, Vector3(0.0, 0.11, 0.175), 0.035, Vector3.ZERO)
	return t

static func rocket_battery_base(P: Dictionary, f: String) -> Dictionary:
	var r := Node3D.new()
	K.add(r, K.bevel_box(Vector3(0.9, 0.08, 0.9), 0.02), P.conc2, Vector3(0.5, 0.04, 0.5))
	for i in 3:
		K.add(r, K.bevel_box(Vector3(0.14, 0.07, 0.08), 0.01), K.paint(Color(0.3, 0.32, 0.22), 0.0, 0.8), Vector3(0.16, 0.115 + i * 0.07, 0.82 - i * 0.02), Vector3(0, i * 10.0, 0))
	for i in 2:
		K.add(r, K.cylinder(0.05, 0.13, 14), V.mats("dominion").rust, Vector3(0.84, 0.15, 0.2 + i * 0.12))
	K.add(r, K.cylinder(0.24, 0.04, 20), M.dark(), Vector3(0.5, 0.1, 0.5))
	return {"root": r, "height": 0.6, "pivot": Vector3(0.5, 0.12, 0.5), "top": rocket_battery_top}

static func rocket_battery_top(P: Dictionary, f: String) -> Node3D:
	var C := V.mats("dominion")
	var t := Node3D.new()
	K.add(t, K.cylinder(0.2, 0.05, 18), C.team_rivet, Vector3(0, 0.025, 0), Vector3.ZERO, true)
	for side in [-1.0, 1.0]:
		K.add(t, K.bevel_box(Vector3(0.16, 0.14, 0.03), 0.008), C.sec_rivet, Vector3(-0.02, 0.11, side * 0.16))
	var rack := Node3D.new()
	rack.position = Vector3(-0.02, 0.17, 0)
	rack.rotation.z = deg_to_rad(28)
	t.add_child(rack)
	# 4 x 3 launch rails with rockets.
	K.add(rack, K.bevel_box(Vector3(0.5, 0.025, 0.3), 0.006), C.sec, Vector3(0.04, -0.03, 0))
	for row in 2:
		for col in 4:
			var z := -0.105 + col * 0.07
			var y := row * 0.055
			K.add(rack, K.bevel_box(Vector3(0.48, 0.012, 0.05), 0.003), M.dark(), Vector3(0.04, y - 0.01, z))
			K.add(rack, K.cylinder(0.018, 0.4, 8), K.paint(Color(0.36, 0.38, 0.28), 0.3, 0.6), Vector3(0.06, y + 0.012, z), Vector3(0, 0, 90))
			K.add(rack, K.lathe([Vector2(0.018, 0.0), Vector2(0.0, 0.05)], 8), C.accent, Vector3(0.26, y + 0.012, z), Vector3(0, 0, -90))
	V.red_star(t, Vector3(-0.02, 0.12, 0.177), 0.03, Vector3.ZERO)
	return t

static func iron_wall(mask: int, damaged: bool) -> Node3D:
	var r := Node3D.new()
	var C := V.mats("dominion")
	var h := 0.36 if not damaged else 0.22
	var steel := K.paint(Color(0.34, 0.33, 0.3), 0.5, 0.55, {"rivets": 30.0, "noise_amt": 0.35, "grime": 0.6})
	# Riveted steel plates between thick concrete-filled posts, topped with spikes.
	K.add(r, K.bevel_box(Vector3(0.22, h + 0.08, 0.22), 0.015), C.sec_rivet, Vector3(0.5, (h + 0.08) * 0.5, 0.5))
	K.add(r, K.bevel_box(Vector3(0.24, 0.035, 0.24), 0.008), C.accent, Vector3(0.5, h + 0.08, 0.5))
	var arms := [Vector3(0.5, 0, 0.19), Vector3(0.81, 0, 0.5), Vector3(0.5, 0, 0.81), Vector3(0.19, 0, 0.5)]
	for k in 4:
		if mask & (1 << k) == 0:
			continue
		var c: Vector3 = arms[k]
		var along_x := k % 2 == 1
		K.add(r, K.bevel_box(Vector3(0.4 if along_x else 0.07, h, 0.07 if along_x else 0.4), 0.008), steel, Vector3(c.x, h * 0.5, c.z))
		if not damaged:
			for s in 3:
				var o := -0.09 + s * 0.09
				var p := Vector3(c.x + (o if along_x else 0.0), h + 0.03, c.z + (0.0 if along_x else o))
				K.add(r, K.lathe([Vector2(0.015, 0.0), Vector2(0.0, 0.06)], 6), M.dark(), p)
	if damaged:
		for i in 5:
			K.add(r, K.bevel_box(Vector3(0.07, 0.015, 0.05), 0.004), steel, Vector3(0.3 + fmod(i * 0.37, 0.4), 0.01, 0.3 + fmod(i * 0.53, 0.4)), Vector3(i * 9.0, i * 47.0, i * 21.0))
	return r
