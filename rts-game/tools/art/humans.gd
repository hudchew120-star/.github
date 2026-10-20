class_name HumanModels
extends RefCounted
## Anatomically proportioned soldiers for the sprite baker. Bodies are built in metres
## (1.8 m tall, about 7.5 heads) from tapered capsules and lofted torsos, posed with
## forward kinematics for legs and two-bone IK so both hands stay on the weapon.
## Uniforms follow each side's real-world inspiration:
##   Coalition - modern western: multi-tone camouflage, plate carrier, rounded combat
##               helmet with NVG mount, tan boots and gloves, carbine with optic.
##   Dominion  - eastern bloc: olive-khaki field uniform, steel helmet with red star,
##               chest rig, tall black boots, assault rifle with wooden furniture.
## Team colour lives on load-bearing gear (vest / chest rig, shoulder patches, helmet band).

const K := preload("res://tools/art/kit.gd")
const HEIGHT := 0.40          # world units for a 1.8 m soldier (before the sheet scale)

const L_THIGH := 0.45
const L_SHIN := 0.44
const L_UPPER := 0.29
const L_FORE := 0.27
const ANKLE_H := 0.085

static func _m(col: Color, rough: float = 0.85, extra: Dictionary = {}) -> ShaderMaterial:
	return K.paint(col, 0.0, rough, extra)

static func kit(faction: String, kind: String) -> Dictionary:
	if faction == "dominion":
		var uni := _m(Color(0.45, 0.43, 0.3), 0.9, {"noise_amt": 0.3, "fabric": 0.0})
		if kind == "engineer":
			uni = _m(Color(0.33, 0.35, 0.27), 0.95, {"noise_amt": 0.3, "fabric": 0.0})
		return {
			"uni": uni,
			"uni_dark": _m(Color(0.36, 0.34, 0.24), 0.9, {"noise_amt": 0.3}),
			"gear": K.paint(Color(0.62, 0.62, 0.62), 0.0, 0.8, {"noise_amt": 0.25}),
			"gear2": _m(Color(0.3, 0.27, 0.2), 0.85),
			"boot": _m(Color(0.07, 0.065, 0.06), 0.45),
			"glove": _m(Color(0.78, 0.6, 0.48), 0.7),
			"skin": _m(Color(0.84, 0.66, 0.53), 0.7, {"noise_amt": 0.12}),
			"helmet": K.paint(Color(0.29, 0.33, 0.22), 0.2, 0.55, {"noise_amt": 0.2}),
			"metal": K.paint(Color(0.13, 0.13, 0.14), 0.7, 0.4),
			"wood": _m(Color(0.42, 0.2, 0.09), 0.5, {"noise_amt": 0.4, "corrugate": 400.0}),
			"star": K.paint(Color(0.85, 0.08, 0.06), 0.0, 0.5, {"emit": 0.25}),
			"strap": _m(Color(0.22, 0.2, 0.15)),
		}
	return {
		"uni": _m(Color(0.6, 0.55, 0.42), 0.9, {"camo": 13.0, "camo_a": Color(0.42, 0.4, 0.28), "camo_b": Color(0.33, 0.27, 0.19), "camo_c": Color(0.72, 0.66, 0.52), "noise_amt": 0.18, "fabric": 0.0}),
		"uni_dark": _m(Color(0.46, 0.42, 0.32), 0.9, {"camo": 13.0, "camo_a": Color(0.34, 0.33, 0.24), "camo_b": Color(0.27, 0.22, 0.16), "camo_c": Color(0.56, 0.52, 0.4)}),
		"gear": K.paint(Color(0.62, 0.62, 0.62), 0.0, 0.8, {"noise_amt": 0.25}),
		"gear2": _m(Color(0.52, 0.45, 0.33), 0.85),
		"boot": _m(Color(0.6, 0.5, 0.36), 0.8),
		"glove": _m(Color(0.5, 0.43, 0.32), 0.8),
		"skin": _m(Color(0.8, 0.6, 0.46), 0.7, {"noise_amt": 0.12}),
		"helmet": K.paint(Color(0.55, 0.5, 0.38), 0.1, 0.75, {"camo": 15.0, "camo_a": Color(0.42, 0.4, 0.28), "camo_b": Color(0.36, 0.3, 0.21), "camo_c": Color(0.66, 0.6, 0.47)}),
		"metal": K.paint(Color(0.1, 0.1, 0.11), 0.6, 0.45),
		"wood": K.paint(Color(0.16, 0.16, 0.15), 0.3, 0.6),
		"star": K.paint(Color(0.1, 0.1, 0.1), 0.0, 0.5),
		"strap": _m(Color(0.4, 0.35, 0.26)),
	}

## pose: {"walk": 0..1 phase or -1, "fire": 0 none / 1 aim / 2 recoil, "dead": 0..1}
static func soldier(kind: String, faction: String, pose: Dictionary) -> Node3D:
	var C := kit(faction, kind)
	var root := Node3D.new()
	var body := Node3D.new()
	body.scale = Vector3.ONE * (HEIGHT / 1.8)
	root.add_child(body)
	var heavy := kind == "heavy_inf"
	var wide := 1.1 if heavy else 1.0
	var phase: float = pose.get("walk", -1.0)
	var fire: int = int(pose.get("fire", 0))
	var dead: float = pose.get("dead", 0.0)
	var walking := phase >= 0.0
	var unarmed := kind == "engineer"
	# ---- legs (FK in the sagittal plane)
	var th_l := 0.03
	var th_r := 0.03
	var kn_l := 0.06
	var kn_r := 0.06
	var lean := 0.04
	if walking:
		var s := sin(phase * TAU)
		var c := cos(phase * TAU)
		th_l = 0.44 * s
		th_r = -0.44 * s
		kn_l = 0.1 + 0.85 * maxf(0.0, c) * (0.6 + 0.4 * maxf(0.0, s))
		kn_r = 0.1 + 0.85 * maxf(0.0, -c) * (0.6 + 0.4 * maxf(0.0, -s))
		lean = 0.12
	elif fire > 0:
		th_l = 0.3
		th_r = -0.22
		kn_l = 0.32
		kn_r = 0.08
		lean = 0.1
	var hips := [Vector3(0, 0.95, -0.095 * wide), Vector3(0, 0.95, 0.095 * wide)]
	var legs := [[th_l, kn_l], [th_r, kn_r]]
	var ankles := []
	var knees := []
	var low := 99.0
	for i in 2:
		var th: float = legs[i][0]
		var kn: float = legs[i][1]
		var knee: Vector3 = hips[i] + Vector3(sin(th), -cos(th), 0) * L_THIGH
		var ank: Vector3 = knee + Vector3(sin(th - kn), -cos(th - kn), 0) * L_SHIN
		knees.append(knee)
		ankles.append(ank)
		low = minf(low, ank.y)
	var drop := low - ANKLE_H
	var pel_y := 0.95 - drop
	for i in 2:
		hips[i].y -= drop
		knees[i].y -= drop
		ankles[i].y -= drop
	for i in 2:
		var thigh_r := 0.105 * wide
		K.limb(body, hips[i] + Vector3(0, 0.05, 0), knees[i], thigh_r, 0.07, C.uni_dark if i == 0 else C.uni, 14)
		K.limb(body, knees[i], ankles[i] + Vector3(0, 0.05, 0), 0.068, 0.05, C.uni, 14)
		# Calf muscle and a cargo pocket give the legs a human silhouette.
		K.ellipsoid(body, knees[i] + (ankles[i] - knees[i]) * 0.3 + Vector3(-0.02, 0, 0), Vector3(0.06, 0.12, 0.065), C.uni)
		K.add(body, K.bevel_box(Vector3(0.05, 0.12, 0.05), 0.015), C.uni_dark, hips[i] + (knees[i] - hips[i]) * 0.45 + Vector3(0.0, 0, (0.09 if i == 1 else -0.09) * wide), Vector3(0, 0, -legs[i][0] * 57.3))
		# Knee pads (coalition) / tall boots (dominion).
		if faction == "coalition":
			K.ellipsoid(body, knees[i] + Vector3(0.045, 0.0, 0), Vector3(0.045, 0.06, 0.05), C.gear2)
		else:
			K.limb(body, ankles[i] + Vector3(0, -0.03, 0), ankles[i] + (knees[i] - ankles[i]) * 0.62, 0.058, 0.064, C.boot, 12)
		var foot_th: float = (legs[i][0] - legs[i][1]) * 0.35 if walking else 0.0
		_boot(body, ankles[i], foot_th, C.boot)
	# ---- torso (leans from the pelvis)
	var torso := Node3D.new()
	torso.position = Vector3(0, pel_y, 0)
	torso.rotation.z = -lean
	body.add_child(torso)
	var tw := wide
	var torso_st := [[-0.12, 0.16 * tw, 0.11, -0.1], [0.03, 0.19 * tw, 0.12, -0.11], [0.15, 0.165 * tw, 0.11, -0.105],
		[0.3, 0.18 * tw, 0.12, -0.12], [0.43, 0.2 * tw, 0.12, -0.125], [0.51, 0.19 * tw, 0.1, -0.09], [0.57, 0.08, 0.055, -0.055]]
	K.add(torso, K.loft(torso_st, 18, 2.6), C.uni, Vector3.ZERO, Vector3(0, 0, 90))
	# Belt with pouches.
	K.add(torso, K.loft([[0.0, 0.18 * tw, 0.12, -0.115], [0.07, 0.178 * tw, 0.118, -0.113]], 18, 2.6), C.strap, Vector3.ZERO, Vector3(0, 0, 90))
	for z in [-0.12, 0.12]:
		K.add(torso, K.bevel_box(Vector3(0.07, 0.08, 0.06), 0.015), C.gear2, Vector3(0.1, 0.03, z * tw))
	K.add(torso, K.bevel_box(Vector3(0.07, 0.09, 0.08), 0.02), C.gear2, Vector3(-0.11, 0.02, 0.1 * tw))
	_upper_gear(torso, kind, faction, C, tw)
	# ---- head
	var neck := Vector3(0.01, 0.57, 0)
	K.limb(torso, neck, neck + Vector3(0.01, 0.08, 0), 0.05, 0.048, C.skin, 10)
	var head_c := Vector3(0.02, 0.73, 0)
	_head(torso, head_c, kind, faction, C)
	# ---- arms and weapon
	var sh := [Vector3(0.0, 0.47, -0.2 * tw), Vector3(0.0, 0.47, 0.2 * tw)]
	if unarmed:
		_engineer_arms(torso, sh, phase, fire, C, faction)
	else:
		_armed(torso, sh, kind, faction, C, fire, walking, phase)
	if dead > 0.0:
		# Knees give way, then the body falls backwards.
		var fall := clampf(dead * 1.25, 0.0, 1.0)
		body.rotation.z = fall * 1.42
		body.position = Vector3(-0.12 * fall, 0.03 * fall, 0)
		torso.rotation.z = -lean + fall * 0.25
	return root

static func _boot(parent: Node3D, ankle: Vector3, tilt: float, mat: Material) -> void:
	var b := Node3D.new()
	b.position = ankle + Vector3(0, -ANKLE_H, 0)
	b.rotation.z = tilt
	parent.add_child(b)
	var st := [[-0.075, 0.04, 0.12, 0.0], [-0.05, 0.052, 0.14, 0.0], [0.04, 0.05, 0.1, 0.0], [0.13, 0.052, 0.065, 0.0], [0.19, 0.04, 0.05, 0.0], [0.205, 0.02, 0.035, 0.005]]
	K.add(b, K.loft(st, 14, 3.0), mat, Vector3.ZERO)
	K.add(b, K.bevel_box(Vector3(0.28, 0.02, 0.105), 0.008), K.paint(Color(0.08, 0.07, 0.06), 0.0, 0.9), Vector3(0.065, 0.01, 0))

static func _upper_gear(torso: Node3D, kind: String, faction: String, C: Dictionary, tw: float) -> void:
	if faction == "coalition":
		# Plate carrier with cummerbund, magazine pouches and shoulder straps.
		var st := [[0.13, 0.19 * tw, 0.135, -0.14, 4.0], [0.25, 0.195 * tw, 0.14, -0.15, 4.0], [0.4, 0.2 * tw, 0.135, -0.145, 4.0], [0.46, 0.17 * tw, 0.12, -0.12, 4.0]]
		K.add(torso, K.loft(st, 18), C.gear, Vector3.ZERO, Vector3(0, 0, 90), true)
		for i in 3:
			K.add(torso, K.bevel_box(Vector3(0.05, 0.11, 0.075), 0.012), C.gear, Vector3(0.165, 0.22, (-0.085 + i * 0.085) * tw), Vector3.ZERO, true)
		K.add(torso, K.bevel_box(Vector3(0.04, 0.06, 0.14), 0.01), C.gear2, Vector3(0.16, 0.36, 0.0))
		for z in [-0.11, 0.11]:
			K.add(torso, K.bevel_box(Vector3(0.24, 0.025, 0.07), 0.01), C.gear, Vector3(0.0, 0.5, z * tw), Vector3.ZERO, true)
		# Radio and hydration pack on the back.
		K.add(torso, K.bevel_box(Vector3(0.07, 0.24, 0.2), 0.03), C.gear2, Vector3(-0.17, 0.3, 0))
		K.add(torso, K.bevel_box(Vector3(0.05, 0.12, 0.05), 0.012), C.metal, Vector3(-0.17, 0.42, 0.13))
		K.tube(torso, Vector3(-0.17, 0.48, 0.13), Vector3(-0.2, 0.75, 0.15), 0.006, C.metal, 4)
	else:
		# Collar, chest rig ("lifchik") with four magazine pouches, shoulder harness.
		K.add(torso, K.loft([[0.5, 0.11, 0.08, -0.07], [0.56, 0.09, 0.07, -0.065]], 14, 2.2), C.uni_dark, Vector3.ZERO, Vector3(0, 0, 90))
		var st := [[0.12, 0.18 * tw, 0.125, -0.13, 3.0], [0.3, 0.19 * tw, 0.125, -0.14, 3.0], [0.36, 0.18 * tw, 0.12, -0.135, 3.0]]
		K.add(torso, K.loft(st, 18), C.gear, Vector3.ZERO, Vector3(0, 0, 90), true)
		for i in 4:
			K.add(torso, K.bevel_box(Vector3(0.055, 0.12, 0.065), 0.014), C.gear, Vector3(0.15, 0.22, (-0.105 + i * 0.07) * tw), Vector3.ZERO, true)
		for z in [-0.1, 0.1]:
			K.tube(torso, Vector3(0.12, 0.36, z * tw), Vector3(-0.1, 0.36, z * tw * 0.9), 0.016, C.strap, 6)
			K.tube(torso, Vector3(0.12, 0.36, z * tw), Vector3(0.02, 0.52, z * tw * 1.05), 0.016, C.strap, 6)
		# Rolled bedroll / satchel on the back.
		K.add(torso, K.bevel_box(Vector3(0.1, 0.2, 0.22), 0.035), C.gear2, Vector3(-0.17, 0.28, 0))
		K.add(torso, K.cylinder(0.045, 0.26, 12), C.uni_dark, Vector3(-0.19, 0.41, 0), Vector3(90, 0, 0))
	if kind == "heavy_inf":
		# Heavy flak vest with groin plate and shoulder armour.
		K.add(torso, K.loft([[0.08, 0.2 * tw, 0.14, -0.15, 3.0], [0.28, 0.205 * tw, 0.145, -0.16, 3.0], [0.46, 0.19 * tw, 0.13, -0.14, 3.0]], 18), C.gear, Vector3.ZERO, Vector3(0, 0, 90), true)
		K.add(torso, K.bevel_box(Vector3(0.03, 0.14, 0.17), 0.012), C.gear, Vector3(0.155, -0.02, 0), Vector3(0, 0, 8), true)
		for z in [-1.0, 1.0]:
			K.ellipsoid(torso, Vector3(0.0, 0.47, z * 0.24 * tw), Vector3(0.08, 0.045, 0.07), C.gear, Vector3.ZERO, true)
	if kind == "flame_inf":
		for z in [-0.075, 0.075]:
			K.add(torso, K.lathe([Vector2(0.0, -0.2), Vector2(0.07, -0.18), Vector2(0.075, 0.15), Vector2(0.05, 0.2), Vector2(0.0, 0.21)], 16), K.paint(Color(0.62, 0.24, 0.12), 0.35, 0.45), Vector3(-0.22, 0.3, z))
		K.add(torso, K.bevel_box(Vector3(0.04, 0.4, 0.24), 0.01), C.strap, Vector3(-0.16, 0.3, 0))
		K.add(torso, K.cylinder(0.03, 0.05, 10), C.metal, Vector3(-0.22, 0.53, 0))
	if kind == "engineer":
		# Large tool pack with a coiled cable and a hi-vis band.
		K.add(torso, K.bevel_box(Vector3(0.18, 0.36, 0.3), 0.04), C.gear2, Vector3(-0.22, 0.3, 0))
		K.add(torso, K.bevel_box(Vector3(0.02, 0.05, 0.31), 0.006), K.paint(Color(0.95, 0.75, 0.1), 0.0, 0.5, {"emit": 0.15}), Vector3(-0.13, 0.36, 0))
		K.add(torso, K.lathe([Vector2(0.06, -0.02), Vector2(0.08, 0.0), Vector2(0.06, 0.02)], 14, true, false, false), K.paint(Color(0.85, 0.35, 0.08), 0.0, 0.6), Vector3(-0.32, 0.35, 0), Vector3(0, 0, 90))
		K.add(torso, K.bevel_box(Vector3(0.05, 0.03, 0.4), 0.01), K.paint(Color(0.95, 0.75, 0.1), 0.0, 0.5, {"emit": 0.15}), Vector3(0.0, 0.31, 0))

static func _head(torso: Node3D, c: Vector3, kind: String, faction: String, C: Dictionary) -> void:
	K.ellipsoid(torso, c, Vector3(0.1, 0.12, 0.085), C.skin)
	K.ellipsoid(torso, c + Vector3(0.095, -0.015, 0), Vector3(0.02, 0.03, 0.018), C.skin)      # nose
	K.ellipsoid(torso, c + Vector3(0.06, -0.075, 0), Vector3(0.045, 0.035, 0.06), C.skin)     # jaw
	for z in [-1.0, 1.0]:
		K.ellipsoid(torso, c + Vector3(0.0, 0.0, z * 0.085), Vector3(0.022, 0.03, 0.012), C.skin)  # ears
	if kind == "flame_inf":
		K.ellipsoid(torso, c + Vector3(0.06, -0.01, 0), Vector3(0.06, 0.09, 0.08), K.paint(Color(0.12, 0.13, 0.12), 0.1, 0.5))
		for z in [-0.035, 0.035]:
			K.add(torso, K.cylinder(0.025, 0.012, 12), K.paint(Color(0.3, 0.42, 0.45), 0.6, 0.2), c + Vector3(0.11, 0.015, z), Vector3(0, 0, 90))
		K.add(torso, K.cylinder(0.035, 0.06, 12), K.paint(Color(0.2, 0.22, 0.2), 0.4, 0.5), c + Vector3(0.13, -0.07, 0), Vector3(0, 0, 70))
	if faction == "coalition":
		if kind == "engineer":
			# Bump cap with head lamp and safety glasses.
			_helmet(torso, c, K.paint(Color(0.9, 0.82, 0.62), 0.0, 0.5), 1.0, 0.0)
			K.add(torso, K.cylinder(0.022, 0.025, 10), K.paint(Color(1, 0.95, 0.7), 0.0, 0.3, {"emit": 2.0}), c + Vector3(0.1, 0.08, 0), Vector3(0, 0, 90))
		else:
			_helmet(torso, c, C.helmet, 1.0, 0.0)
			# NVG shroud, goggles strap, side rails and team band.
			K.add(torso, K.bevel_box(Vector3(0.03, 0.04, 0.05), 0.008), C.metal, c + Vector3(0.105, 0.085, 0))
			K.add(torso, K.lathe([Vector2(0.123, -0.012), Vector2(0.125, 0.0), Vector2(0.123, 0.012)], 20, true, false, false), C.gear, c + Vector3(0.0, 0.075, 0), Vector3(0, 0, -6), true)
			for z in [-1.0, 1.0]:
				K.add(torso, K.bevel_box(Vector3(0.08, 0.018, 0.012), 0.004), C.metal, c + Vector3(0.0, 0.06, z * 0.115))
		# Ballistic glasses.
		K.add(torso, K.bevel_box(Vector3(0.012, 0.025, 0.13), 0.006), K.paint(Color(0.08, 0.1, 0.12), 0.8, 0.15), c + Vector3(0.098, 0.015, 0))
	else:
		if kind == "engineer":
			# Fur-lined ushanka with folded ear flaps.
			K.ellipsoid(torso, c + Vector3(-0.005, 0.07, 0), Vector3(0.115, 0.075, 0.1), K.paint(Color(0.32, 0.3, 0.24), 0.0, 0.95, {"noise_amt": 0.6}))
			K.ellipsoid(torso, c + Vector3(0.0, 0.04, 0), Vector3(0.12, 0.05, 0.11), K.paint(Color(0.44, 0.36, 0.28), 0.0, 1.0, {"noise_amt": 0.9}))
			K.add(torso, K.cylinder(0.015, 0.005, 8), C.star, c + Vector3(0.115, 0.06, 0), Vector3(0, 0, 90))
		elif kind != "flame_inf":
			_helmet(torso, c, C.helmet, 1.05, 0.03)
			K.add(torso, K.cylinder(0.018, 0.004, 5), C.star, c + Vector3(0.122, 0.07, 0), Vector3(0, 0, 80))
			K.add(torso, K.lathe([Vector2(0.128, -0.01), Vector2(0.13, 0.0), Vector2(0.128, 0.01)], 20, true, false, false), C.gear, c + Vector3(0, 0.05, 0), Vector3.ZERO, true)
			for z in [-1.0, 1.0]:
				K.tube(torso, c + Vector3(0.0, 0.03, z * 0.1), c + Vector3(0.04, -0.09, z * 0.06), 0.006, C.strap, 4)
		else:
			_helmet(torso, c, C.helmet, 1.02, 0.0)

## Rounded combat helmet: domed shell with a slight brim. flare > 0 widens the rim (steel helmet look).
static func _helmet(parent: Node3D, c: Vector3, mat: Material, s: float, flare: float) -> void:
	var prof := [Vector2(0.128 * s + flare, -0.02), Vector2(0.126 * s + flare * 0.6, 0.0), Vector2(0.122 * s, 0.03), Vector2(0.112 * s, 0.07), Vector2(0.09 * s, 0.11), Vector2(0.055 * s, 0.135), Vector2(0.0, 0.145)]
	var m := K.add(parent, K.lathe(prof, 22, true, false, false), mat, c + Vector3(-0.005, 0.02, 0))
	m.scale = Vector3(1.06, 1.0, 0.95)

static func _hand(parent: Node3D, p: Vector3, mat: Material) -> void:
	K.ellipsoid(parent, p, Vector3(0.045, 0.04, 0.035), mat)

static func _arm(parent: Node3D, shoulder: Vector3, hand: Vector3, pole: Vector3, C: Dictionary, heavy: bool = false) -> void:
	var elbow := K.ik(shoulder, hand, L_UPPER, L_FORE, pole)
	var r := 0.06 if heavy else 0.054
	K.limb(parent, shoulder, elbow, r * 1.25, r * 0.85, C.uni, 12)
	K.limb(parent, elbow, hand, r * 0.95, r * 0.66, C.uni, 12)
	_hand(parent, hand, C.glove)

## Weapon carriers: the gun is posed as a rigid frame, then hands are solved onto its grips.
static func _armed(torso: Node3D, sh: Array, kind: String, faction: String, C: Dictionary, fire: int, walking: bool, phase: float) -> void:
	var g := Node3D.new()
	torso.add_child(g)
	var shoulder_fired := kind == "rocket_inf" or kind == "heavy_inf"
	var grip := Vector3.ZERO
	var support := Vector3.ZERO
	if shoulder_fired:
		# Launcher rests on the right shoulder, aimed forward.
		g.position = Vector3(0.0, 0.56, 0.2)
		g.rotation.z = 0.04 if fire == 0 else 0.0
		if fire == 2:
			g.position.x -= 0.02
		grip = Vector3(0.18, -0.08, 0)
		support = Vector3(0.38, -0.07, 0)
		if kind == "rocket_inf":
			_launcher_tube(g, C)
		else:
			_rpg(g, C)
	else:
		if fire > 0:
			g.position = Vector3(0.12, 0.45, 0.13)
			g.rotation = Vector3(0.0, 0.08, 0.0)
			if fire == 2:
				g.position.x -= 0.03
				g.rotation.z = 0.06
		else:
			# Low ready: muzzle angled down across the body.
			var bob := sin(phase * TAU * 2.0) * 0.01 if walking else 0.0
			g.position = Vector3(0.2, 0.33 + bob, 0.08)
			g.rotation = Vector3(0.0, 0.5, -0.3)
		grip = Vector3(0.0, -0.06, 0)
		support = Vector3(0.27, -0.035, 0)
		if kind == "flame_inf":
			_flamer(g, C)
			K.tube(torso, Vector3(-0.2, 0.15, 0.08), g.position + Vector3(0.0, -0.08, 0.0), 0.016, K.paint(Color(0.1, 0.1, 0.1), 0.0, 0.7), 6)
		elif faction == "dominion":
			_ak(g, C)
		else:
			_carbine(g, C)
	var gx := g.transform
	_arm(torso, sh[1], gx * grip, Vector3(-0.3, -1.0, 0.6), C, kind == "heavy_inf")
	_arm(torso, sh[0], gx * support, Vector3(-0.2, -1.0, -0.8), C, kind == "heavy_inf")

static func _carbine(g: Node3D, C: Dictionary) -> void:
	var m: Material = C.metal
	K.add(g, K.bevel_box(Vector3(0.22, 0.065, 0.04), 0.008), m, Vector3(0.06, 0.0, 0))                # receiver
	K.add(g, K.loft([[0.17, 0.026, 0.03, -0.03, 4.0], [0.38, 0.024, 0.028, -0.028, 4.0]], 10), m, Vector3.ZERO)  # rail handguard
	K.add(g, K.cylinder(0.009, 0.16, 8), m, Vector3(0.46, 0.0, 0), Vector3(0, 0, 90))                 # barrel
	K.add(g, K.cylinder(0.014, 0.04, 8), m, Vector3(0.53, 0.0, 0), Vector3(0, 0, 90))                 # flash hider
	K.add(g, K.bevel_box(Vector3(0.05, 0.13, 0.03), 0.01), m, Vector3(0.09, -0.09, 0), Vector3(0, 0, -12))  # magazine
	K.add(g, K.bevel_box(Vector3(0.035, 0.09, 0.03), 0.01), m, Vector3(-0.005, -0.065, 0), Vector3(0, 0, 18))  # pistol grip
	K.add(g, K.loft([[-0.26, 0.02, 0.03, -0.07, 3.0], [-0.12, 0.018, 0.03, -0.03, 3.0], [-0.06, 0.015, 0.02, -0.02]], 10), C.wood, Vector3.ZERO)  # stock
	K.add(g, K.cylinder(0.022, 0.1, 12), m, Vector3(0.07, 0.065, 0), Vector3(0, 0, 90))                # optic
	K.add(g, K.cylinder(0.018, 0.004, 12), K.paint(Color(0.5, 0.15, 0.1), 0.6, 0.1, {"emit": 0.6}), Vector3(0.122, 0.065, 0), Vector3(0, 0, 90))
	K.add(g, K.bevel_box(Vector3(0.04, 0.02, 0.025), 0.006), K.paint(Color(0.5, 0.45, 0.33), 0.0, 0.7), Vector3(0.3, -0.035, 0))  # foregrip

static func _ak(g: Node3D, C: Dictionary) -> void:
	var m: Material = C.metal
	K.add(g, K.bevel_box(Vector3(0.24, 0.06, 0.04), 0.008), m, Vector3(0.06, 0.0, 0))
	K.add(g, K.loft([[0.17, 0.028, 0.025, -0.035, 2.5], [0.34, 0.024, 0.022, -0.03, 2.5]], 10), C.wood, Vector3.ZERO)      # wooden handguard
	K.add(g, K.cylinder(0.008, 0.2, 8), m, Vector3(0.43, 0.0, 0), Vector3(0, 0, 90))
	K.add(g, K.cylinder(0.006, 0.18, 6), m, Vector3(0.36, 0.03, 0), Vector3(0, 0, 90))                 # gas tube
	K.add(g, K.bevel_box(Vector3(0.016, 0.04, 0.012), 0.004), m, Vector3(0.52, 0.02, 0))              # front sight
	# Curved "banana" magazine from three segments.
	for i in 3:
		K.add(g, K.bevel_box(Vector3(0.05, 0.055, 0.03), 0.008), K.paint(Color(0.32, 0.17, 0.08), 0.2, 0.55), Vector3(0.12 + i * 0.015, -0.06 - i * 0.045, 0), Vector3(0, 0, -10 - i * 14))
	K.add(g, K.bevel_box(Vector3(0.035, 0.085, 0.03), 0.01), C.wood, Vector3(-0.005, -0.06, 0), Vector3(0, 0, 20))
	K.add(g, K.loft([[-0.28, 0.02, 0.01, -0.075, 3.0], [-0.1, 0.018, 0.025, -0.035, 3.0], [-0.06, 0.016, 0.02, -0.02]], 10), C.wood, Vector3.ZERO)

static func _launcher_tube(g: Node3D, C: Dictionary) -> void:
	var tube := K.paint(Color(0.32, 0.36, 0.27), 0.15, 0.6, {"noise_amt": 0.3})
	K.add(g, K.lathe([Vector2(0.065, -0.45), Vector2(0.07, -0.42), Vector2(0.06, -0.38), Vector2(0.06, 0.4), Vector2(0.07, 0.44), Vector2(0.065, 0.5)], 16, true, false, false), tube, Vector3(0.12, 0, 0), Vector3(0, 0, -90))
	K.add(g, K.cylinder(0.05, 0.005, 14), K.paint(Color(0.05, 0.05, 0.05), 0.0, 1.0), Vector3(0.62, 0, 0), Vector3(0, 0, 90))
	K.add(g, K.bevel_box(Vector3(0.16, 0.09, 0.1), 0.02), K.paint(Color(0.24, 0.26, 0.2), 0.2, 0.6), Vector3(0.12, 0.0, -0.11))  # sight unit
	K.add(g, K.cylinder(0.025, 0.06, 10), C.metal, Vector3(0.21, 0.02, -0.11), Vector3(0, 0, 90))
	K.add(g, K.bevel_box(Vector3(0.03, 0.08, 0.03), 0.008), C.metal, Vector3(0.18, -0.07, 0))
	K.add(g, K.bevel_box(Vector3(0.03, 0.08, 0.03), 0.008), C.metal, Vector3(0.38, -0.07, 0))

static func _rpg(g: Node3D, C: Dictionary) -> void:
	K.add(g, K.cylinder(0.035, 0.95, 12), K.paint(Color(0.22, 0.24, 0.2), 0.4, 0.5), Vector3(0.05, 0, 0), Vector3(0, 0, 90))
	K.add(g, K.lathe([Vector2(0.035, 0), Vector2(0.05, 0.04), Vector2(0.05, 0.08)], 12, true, false, false), K.paint(Color(0.22, 0.24, 0.2), 0.4, 0.5), Vector3(-0.42, 0, 0), Vector3(0, 0, 90))
	K.add(g, K.cylinder(0.04, 0.2, 12), C.wood, Vector3(0.18, 0, 0), Vector3(0, 0, 90))
	# Warhead: the iconic double cone.
	K.add(g, K.lathe([Vector2(0.025, 0.0), Vector2(0.075, 0.1), Vector2(0.075, 0.13), Vector2(0.02, 0.24), Vector2(0.0, 0.26)], 16), K.paint(Color(0.34, 0.38, 0.27), 0.3, 0.5), Vector3(0.52, 0, 0), Vector3(0, 0, -90))
	K.add(g, K.bevel_box(Vector3(0.05, 0.05, 0.03), 0.008), C.metal, Vector3(0.12, 0.06, -0.03))
	K.add(g, K.bevel_box(Vector3(0.03, 0.08, 0.03), 0.008), C.metal, Vector3(0.18, -0.07, 0))
	K.add(g, K.bevel_box(Vector3(0.03, 0.08, 0.03), 0.008), C.metal, Vector3(0.36, -0.07, 0))

static func _flamer(g: Node3D, C: Dictionary) -> void:
	K.add(g, K.cylinder(0.025, 0.5, 10), K.paint(Color(0.2, 0.2, 0.2), 0.6, 0.4), Vector3(0.2, 0, 0), Vector3(0, 0, 90))
	K.add(g, K.cylinder(0.04, 0.12, 12), K.paint(Color(0.55, 0.25, 0.12), 0.4, 0.5), Vector3(0.12, 0.0, 0), Vector3(0, 0, 90))
	K.add(g, K.lathe([Vector2(0.025, 0), Vector2(0.035, 0.05), Vector2(0.032, 0.07)], 10, true, false, false), C.metal, Vector3(0.45, 0, 0), Vector3(0, 0, -90))
	K.add(g, K.cylinder(0.012, 0.012, 6), K.paint(Color(1, 0.55, 0.15), 0.0, 0.4, {"emit": 3.0}), Vector3(0.53, -0.025, 0), Vector3(0, 0, 90))
	K.add(g, K.bevel_box(Vector3(0.035, 0.09, 0.03), 0.01), C.metal, Vector3(0.0, -0.06, 0), Vector3(0, 0, 15))
	K.add(g, K.bevel_box(Vector3(0.03, 0.08, 0.03), 0.008), C.metal, Vector3(0.27, -0.05, 0))

static func _engineer_arms(torso: Node3D, sh: Array, phase: float, work: int, C: Dictionary, faction: String) -> void:
	var swing := sin(phase * TAU) * 0.5 if phase >= 0.0 else 0.0
	var r_hand: Vector3 = sh[1] + Vector3(sin(swing) * 0.5, -0.5 * cos(swing) + 0.02, 0.06)
	var l_hand: Vector3 = sh[0] + Vector3(sin(-swing) * 0.48, -0.5 * cos(swing) + 0.03, -0.04)
	if work > 0:
		r_hand = sh[1] + Vector3(0.38, 0.05 if work == 1 else -0.12, -0.08)
		l_hand = sh[0] + Vector3(0.4, -0.16, 0.12)
	_arm(torso, sh[1], r_hand, Vector3(-0.4, -1.0, 0.5), C)
	_arm(torso, sh[0], l_hand, Vector3(-0.4, -1.0, -0.5), C)
	# Toolbox in the left hand, heavy wrench in the right.
	var box_col := K.paint(Color(0.75, 0.15, 0.1) if faction == "dominion" else Color(0.85, 0.6, 0.12), 0.3, 0.5)
	K.add(torso, K.bevel_box(Vector3(0.22, 0.12, 0.09), 0.015), box_col, l_hand + Vector3(0.0, -0.09, 0))
	K.add(torso, K.bevel_box(Vector3(0.12, 0.02, 0.02), 0.006), C.metal, l_hand + Vector3(0.0, -0.02, 0))
	var w := Node3D.new()
	w.position = r_hand
	w.rotation.z = -1.2 if work == 0 else 0.3
	torso.add_child(w)
	K.add(w, K.bevel_box(Vector3(0.3, 0.025, 0.018), 0.006), K.paint(Color(0.6, 0.62, 0.64), 0.8, 0.3), Vector3(0.1, 0, 0))
	K.add(w, K.lathe([Vector2(0.035, -0.01), Vector2(0.04, 0.0), Vector2(0.035, 0.01)], 10), K.paint(Color(0.6, 0.62, 0.64), 0.8, 0.3), Vector3(0.26, 0, 0), Vector3(90, 0, 0))
