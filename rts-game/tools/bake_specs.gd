extends RefCounted
## Every sprite sheet the baker produces (art resolution 2x: a map cell is 128x64 px).
## Directional sheets index frames as state * DIRS + direction; direction 0 faces +X
## (screen lower-right) and increases clockwise in world space, matching Unit.facing.

const M := preload("res://tools/art/hd_models.gd")
const B := preload("res://tools/art/hd_buildings.gd")
const H := preload("res://tools/art/humans.gd")
const V := preload("res://tools/art/vehicles.gd")
const CU := preload("res://tools/art/country_units.gd")
## Country uniforms: extra infantry sheets per country (the side's default country keeps the base sheet).
const COUNTRY_INFANTRY := {
	"uk": ["infantry", "rocket_inf"], "germany": ["infantry", "rocket_inf"], "france": ["infantry", "rocket_inf"],
	"thailand": ["infantry", "rocket_inf"], "korea": ["infantry", "rocket_inf"], "japan": ["infantry", "rocket_inf"],
	"china": ["infantry", "heavy_inf", "flame_inf"], "cuba": ["infantry", "heavy_inf", "flame_inf"],
}
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

static func vehicle(name: String, builder: Callable, scale: float, states: int = 1, frame: Vector2i = Vector2i(192, 160), air: bool = false) -> Array:
	var probe: Dictionary = builder.call(0)
	var fw := frame.x
	var fh := frame.y
	var anchor := Vector2(fw * 0.5, fh * 0.62)
	var piv: Vector3 = probe.pivot * scale
	var extra := {"pivot": [piv.x, piv.y, piv.z], "dirs": DIRS, "states": states}
	if probe.has("rotor"):
		var rp: Array = probe.rotor.pos
		extra["rotor"] = {"pos": [rp[0] * scale, rp[1] * scale, rp[2] * scale], "r": probe.rotor.r * scale, "blades": probe.rotor.blades}
	if air:
		extra["air"] = true
	var out := [{"name": name, "fw": fw, "fh": fh, "anchor": anchor, "count": DIRS * states, "scale": scale,
		"extra": extra, "separate_shadow": air,
		"build": func(i):
			var d: Dictionary = builder.call(i / DIRS)
			return _rot(_wrap(d.root), i % DIRS)}]
	if probe.turret != null:
		out.append({"name": name + "_turret", "fw": fw, "fh": fh, "anchor": anchor, "count": DIRS, "scale": scale, "shadow": false,
			"extra": {"dirs": DIRS},
			"build": func(i):
				var d: Dictionary = builder.call(0)
				return _rot(_wrap(d.turret), i)})
	return out

static func _person(kind: String, faction: String, pose: Dictionary) -> Node3D:
	return H.dog(faction, pose) if kind == "dog" else H.soldier(kind, faction, pose)

static func infantry(name: String, kind: String, faction: String, air: bool = false) -> Array:
	# 9 frames x 8 directions: idle, walk 1-6, fire 1-2. Plus a 5-frame death sheet.
	var extra := {"dirs": 8, "frames": 9}
	if air:
		extra["air"] = true
	return [{"name": name, "fw": 112, "fh": 112, "anchor": Vector2(56, 80), "count": 72, "scale": 1.45, "extra": extra, "separate_shadow": air,
		"build": func(i):
			var fr: int = i / 8
			var pose := {}
			if fr >= 1 and fr <= 6:
				pose["walk"] = float(fr - 1) / 6.0
			elif fr >= 7:
				pose["fire"] = fr - 6
			return _rot(_person(kind, faction, pose), (i % 8) * 4)},
		{"name": name + "_die", "fw": 112, "fh": 112, "anchor": Vector2(56, 80), "count": 5, "scale": 1.45, "extra": {"frames": 5},
		"build": func(i):
			return _rot(_person(kind, faction, {"dead": float(i) / 4.0}), 12)}]

## Dug-in emplacement (Coalition riflemen): 8 directions x 3 frames (aim, fire 1, fire 2).
static func dug_in(name: String, kind: String, faction: String) -> Dictionary:
	return {"name": name + "_dug", "fw": 112, "fh": 112, "anchor": Vector2(56, 80), "count": 24, "scale": 1.45, "extra": {"dirs": 8, "frames": 3},
		"build": func(i):
			var fr: int = i / 8
			return _rot(H.soldier(kind, faction, {"kneel": true, "sandbags": true, "fire": fr}), (i % 8) * 4)}

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
		var tf: Vector2i = probe.get("top_frame", Vector2i(192, 160))
		out.append({"name": key + "_turret", "fw": tf.x, "fh": tf.y, "anchor": Vector2(tf.x * 0.5, tf.y * 0.625), "count": DIRS, "scale": 1.0, "shadow": false,
			"extra": {"dirs": DIRS, "pivot": [pv.x, pv.y, pv.z]},
			"build": func(i):
				var t: Node3D
				if probe.has("top"):
					t = probe.top.call(P, faction)
				else:
					t = B.gun_turret_top(P, faction) if sprite == "gun_turret" else B.flame_turret_top(P, faction)
				return _rot(_wrap(t), i)})
	return out

static func decor(name: String, count: int, fw: int, fh: int, anchor: Vector2, builder: Callable) -> Dictionary:
	return {"name": name, "fw": fw, "fh": fh, "anchor": anchor, "count": count, "scale": 1.0, "mask": false,
		"build": func(i): return _wrap(builder.call(i))}

const BUILDINGS := {
	"coalition": [["conyard", 3, 3], ["power", 2, 2], ["adv_power", 3, 3], ["refinery", 3, 3], ["silo", 1, 1], ["barracks", 2, 2],
		["factory", 3, 3], ["radar", 2, 2], ["pillbox", 1, 1], ["gun_turret", 1, 1],
		["airfield", 3, 3], ["naval_yard", 3, 3], ["repair", 3, 3], ["sam_site", 1, 1], ["grand_cannon", 2, 2]],
	"dominion": [["conyard", 3, 3], ["power", 2, 2], ["adv_power", 3, 3], ["refinery", 3, 3], ["silo", 1, 1], ["barracks_dom", 2, 2],
		["factory", 3, 3], ["radar", 2, 2], ["flame_tower", 1, 1], ["arc_coil", 1, 2],
		["airfield", 3, 3], ["naval_yard", 3, 3], ["repair", 3, 3], ["flak_cannon", 1, 1]],
}

static func all() -> Array:
	var out := []
	out += vehicle("u_tank_light_coalition", func(_s): return V.light_tank(), 1.3)
	out += vehicle("u_tank_medium_coalition", func(_s): return V.medium_tank(), 1.3)
	out += vehicle("u_tank_heavy_dominion", func(_s): return V.heavy_tank(), 1.25, 1, Vector2i(224, 176))
	out += vehicle("u_jeep_coalition", func(_s): return V.jeep(), 1.35)
	out += vehicle("u_aa_coalition", func(_s): return V.aa_coalition(), 1.3)
	out += vehicle("u_aa_dominion", func(_s): return V.aa_dominion(), 1.25)
	out += vehicle("u_heli_coalition", func(_s): return V.heli_coalition(), 1.0, 1, Vector2i(224, 192), true)
	out += vehicle("u_heli_dominion", func(_s): return V.heli_dominion(), 1.0, 1, Vector2i(240, 200), true)
	out += vehicle("u_jet_coalition", func(_s): return V.jet_coalition(), 1.0, 1, Vector2i(224, 176), true)
	out += vehicle("u_jet_dominion", func(_s): return V.jet_dominion(), 1.0, 1, Vector2i(240, 176), true)
	out += vehicle("u_gunboat_coalition", func(_s): return V.boat_coalition(), 1.15, 1, Vector2i(208, 160))
	out += vehicle("u_destroyer_coalition", func(_s): return V.destroyer_coalition(), 1.0, 1, Vector2i(336, 224))
	out += vehicle("u_submarine_dominion", func(_s): return V.sub_dominion(), 1.0, 1, Vector2i(288, 176))
	out += vehicle("u_cruiser_dominion", func(_s): return V.cruiser_dominion(), 1.0, 1, Vector2i(368, 240))
	for f in ["coalition", "dominion"]:
		out += vehicle("u_harvester_" + f, func(s): return V.harvester(f, float(s)), 1.2, 2, Vector2i(208, 176))
		out += vehicle("u_mcv_" + f, func(_s): return V.mcv(f), 1.15, 1, Vector2i(224, 192))
		out += infantry("i_infantry_" + f, "infantry", f)
		if f == "coalition":
			out.append(dug_in("i_infantry_" + f, "infantry", f))
		out += infantry("i_engineer_" + f, "engineer", f)
	out += infantry("i_rocket_inf_coalition", "rocket_inf", "coalition")
	out += infantry("i_rocketeer_coalition", "rocketeer", "coalition", true)
	out += infantry("i_commando_coalition", "commando", "coalition")
	out += infantry("i_demolition_dominion", "demolition", "dominion")
	out += infantry("i_dog_dominion", "dog", "dominion")
	out += vehicle("u_minelayer_dominion", func(_s): return V.minelayer(), 1.25)
	out += vehicle("u_transport_coalition", func(_s): return V.transport_plane(), 1.0, 1, Vector2i(320, 240), true)
	out += vehicle("u_bomber_dominion", func(_s): return V.bomber_plane(), 1.0, 1, Vector2i(336, 240), true)
	out += infantry("i_heavy_inf_dominion", "heavy_inf", "dominion")
	out += infantry("i_flame_inf_dominion", "flame_inf", "dominion")
	# Country units.
	out += infantry("i_sniper_coalition", "sniper", "uk")
	out += infantry("i_ranger_coalition", "ranger", "thailand")
	out += infantry("i_guerrilla_dominion", "guerrilla", "cuba")
	out += vehicle("u_tank_destroyer_coalition", func(_s): return CU.tank_destroyer(), 1.3, 1, Vector2i(208, 176))
	out += vehicle("u_mecha_coalition", func(s): return CU.mecha(-1.0 if s == 0 else float(s - 1) / 4.0), 1.3, 5, Vector2i(192, 176))
	out += vehicle("u_jet_eagle_coalition", func(_s): return CU.black_eagle(), 1.0, 1, Vector2i(240, 176), true)
	out += vehicle("u_tank_tsar_dominion", func(_s): return CU.tsar_tank(), 1.25, 1, Vector2i(272, 224))
	out += vehicle("u_tank_gatling_dominion", func(_s): return CU.gatling_tank(), 1.3, 1, Vector2i(208, 176))
	for c in COUNTRY_INFANTRY:
		for kind in COUNTRY_INFANTRY[c]:
			out += infantry("i_%s_%s" % [kind, c], kind, c)
			if kind == "infantry" and H.side_of(c) == "coalition":
				out.append(dug_in("i_%s_%s" % [kind, c], kind, c))
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
