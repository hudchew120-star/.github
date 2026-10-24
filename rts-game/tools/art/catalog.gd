extends RefCounted
## Named model sets for tools/showcase.gd (design previews and the catalogue sheet).

const H := preload("res://tools/art/humans.gd")
const V := preload("res://tools/art/vehicles.gd")
const HB := preload("res://tools/art/hd_buildings.gd")
const HM := preload("res://tools/art/hd_models.gd")
const CU := preload("res://tools/art/country_units.gd")
const K := preload("res://tools/art/kit.gd")
const DF := preload("res://tools/art/defenses.gd")
const AN := preload("res://tools/art/air_naval2.gd")

## Model id for a unit sprite (see data/units.json) and faction.
static func unit_model(sprite: String, f: String) -> Node3D:
	match sprite:
		"infantry", "rocket_inf", "heavy_inf", "flame_inf", "engineer", "rocketeer", "commando", "demolition":
			return H.soldier(sprite, f, {})
		"dog": return H.dog(f, {})
		"sniper": return H.soldier("sniper", "uk", {})
		"ranger": return H.soldier("ranger", "thailand", {})
		"guerrilla": return H.soldier("guerrilla", "cuba", {})
		"tank_destroyer": return _veh(CU.tank_destroyer(), 0.0)
		"mecha": return _veh(CU.mecha(-1.0), 0.0)
		"jet_eagle": return _veh(CU.black_eagle(), 0.0)
		"tank_tsar": return _veh(CU.tsar_tank(), 0.0)
		"tank_gatling": return _veh(CU.gatling_tank(), 0.0)
		"strat_bomber": return _veh(AN.strat_bomber(), 0.0)
		"airship": return _veh(AN.airship(), 0.0)
		"dolphin": return _veh(AN.dolphin(), 0.0)
		"aegis": return _veh(AN.aegis(), 0.0)
		"squid": return _veh(AN.squid(), 0.0)
		"sea_scorpion": return _veh(AN.sea_scorpion(), 0.0)
		"minelayer": return _veh(V.minelayer(), 0.0)
		"tank_light": return _veh(V.light_tank(), 0.0)
		"tank_medium": return _veh(V.medium_tank(), 0.0)
		"tank_heavy": return _veh(V.heavy_tank(), 0.0)
		"jeep": return _veh(V.jeep(), 0.0)
		"harvester": return _veh(V.harvester(f, 1.0), 0.0)
		"mcv": return _veh(V.mcv(f), 0.0)
		"aa": return _veh(V.aa_coalition() if f == "coalition" else V.aa_dominion(), 0.0)
		"heli": return _veh(V.heli_coalition() if f == "coalition" else V.heli_dominion(), 0.0)
		"jet": return _veh(V.jet_coalition() if f == "coalition" else V.jet_dominion(), 0.0)
		"gunboat": return _veh(V.boat_coalition(), 0.0)
		"destroyer": return _veh(V.destroyer_coalition(), 0.0)
		"submarine": return _veh(V.sub_dominion(), 0.0)
		"cruiser": return _veh(V.cruiser_dominion(), 0.0)
	return Node3D.new()

static func building_model(sprite: String, f: String) -> Node3D:
	var d: Dictionary = HB.build(sprite, f)
	var root: Node3D = d.root
	if d.has("pivot"):
		var P := HM.pal(f)
		var t: Node3D
		if d.has("top"):
			t = d.top.call(P, f)
		elif sprite == "gun_turret":
			t = HB.gun_turret_top(P, f)
		else:
			t = HB.flame_turret_top(P, f)
		t.position = d.pivot
		t.rotation_degrees.y = -20.0
		root.add_child(t)
	return root

static func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

static func _veh(d: Dictionary, deg: float) -> Node3D:
	var root: Node3D = d.root
	if d.turret != null:
		d.turret.position = d.pivot
		root.add_child(d.turret)
	return _rot(root, deg)

const VEHICLES := [
	["light_tank", "coalition", "Lynx light tank", 1.0], ["medium_tank", "coalition", "Paladin battle tank", 1.0], ["jeep", "coalition", "Ranger utility vehicle", 0.8],
	["aa_coalition", "coalition", "Skyguard AA", 1.0], ["harv_c", "coalition", "Mining truck", 1.1], ["mcv_c", "coalition", "Construction vehicle", 1.2],
	["heavy_tank", "dominion", "Mammoth heavy tank", 1.2], ["aa_dominion", "dominion", "Volga SAM carrier", 1.1], ["harv_d", "dominion", "Strip miner", 1.1], ["mcv_d", "dominion", "Construction crawler", 1.2],
]
const AIR := [
	["heli_coalition", "coalition", "Hawk attack helicopter", 1.4], ["jet_coalition", "coalition", "Falcon stealth fighter", 1.2],
	["heli_dominion", "dominion", "Krait gunship", 1.6], ["jet_dominion", "dominion", "Sokol strike fighter", 1.3],
]
const SHIPS := [
	["boat_coalition", "coalition", "Patrol gunboat", 1.0], ["destroyer_coalition", "coalition", "Guardian destroyer", 2.0],
	["sub_dominion", "dominion", "Akula submarine", 1.5], ["cruiser_dominion", "dominion", "Kirov battlecruiser", 2.2],
]

static func vehicle_model(id: String) -> Dictionary:
	match id:
		"harv_c": return V.harvester("coalition", 1.0)
		"harv_d": return V.harvester("dominion", 1.0)
		"mcv_c": return V.mcv("coalition")
		"mcv_d": return V.mcv("dominion")
		"light_tank": return V.light_tank()
		"medium_tank": return V.medium_tank()
		"jeep": return V.jeep()
		"aa_coalition": return V.aa_coalition()
		"heavy_tank": return V.heavy_tank()
		"aa_dominion": return V.aa_dominion()
		"heli_coalition": return V.heli_coalition()
		"heli_dominion": return V.heli_dominion()
		"jet_coalition": return V.jet_coalition()
		"jet_dominion": return V.jet_dominion()
		"boat_coalition": return V.boat_coalition()
		"destroyer_coalition": return V.destroyer_coalition()
		"sub_dominion": return V.sub_dominion()
		"cruiser_dominion": return V.cruiser_dominion()
	return {}

static func showcase_cols(set_name: String) -> int:
	return {"infantry": 7, "poses": 7, "closeup": 5, "new": 4, "style": 4, "dug": 5, "countries": 5, "country_units": 3, "mock_cameos": 7, "defenses": 4, "wave2": 4, "vehicles": 5, "air": 4, "ships": 4}.get(set_name, 6)

static func _rot(n: Node3D, deg: float) -> Node3D:
	var w := Node3D.new()
	n.rotation_degrees.y = deg
	w.add_child(n)
	return w

static func showcase_set(set_name: String) -> Array:
	var out := []
	var BLUE := Color(0.25, 0.48, 0.85)
	var RED := Color(0.78, 0.2, 0.15)
	match set_name:
		"infantry":
			for e in [["infantry", "coalition", "Rifleman"], ["rocket_inf", "coalition", "Rocket trooper"], ["engineer", "coalition", "Engineer"],
					["infantry", "dominion", "Conscript"], ["heavy_inf", "dominion", "RPG trooper"], ["flame_inf", "dominion", "Flame trooper"], ["engineer", "dominion", "Combat engineer"]]:
				var k: String = e[0]
				var f: String = e[1]
				out.append({"label": e[2], "w": 0.5, "h": 0.6, "focus": Vector3(0, 0.2, 0), "team": BLUE if f == "coalition" else RED,
					"build": func(): return _rot(H.soldier(k, f, {}), -60.0)})
		"vehicles", "air", "ships":
			var lst: Array = VEHICLES if set_name == "vehicles" else (AIR if set_name == "air" else SHIPS)
			for e in lst:
				var id: String = e[0]
				var sz: float = e[3]
				out.append({"label": e[2], "w": sz * 1.2, "h": sz * 0.9, "focus": Vector3(0, 0.15, 0), "team": BLUE if e[1] == "coalition" else RED,
					"build": func(): return _veh(vehicle_model(id), -20.0)})
		"cameos":
			var units := _json("res://data/units.json")
			var blds := _json("res://data/buildings.json")
			for f in ["coalition", "dominion"]:
				for t in units:
					if not units[t].factions.has(f):
						continue
					var sp: String = units[t].sprite
					var ff: String = f
					var inf: bool = units[t].category == "infantry"
					out.append({"label": "%s_%s" % [t, f], "w": 0.96, "h": 0.76, "fit": true, "margin": 1.0 if inf else 1.08, "team": BLUE if f == "coalition" else RED,
						"build": func(): return _rot(unit_model(sp, ff), -70.0 if inf else -25.0)})
				for t in blds:
					if not blds[t].factions.has(f):
						continue
					var sp: String = blds[t].sprite
					var ff: String = f
					out.append({"label": "%s_%s" % [t, f], "w": 0.96, "h": 0.76, "fit": true, "margin": 1.04, "team": BLUE if f == "coalition" else RED,
						"build": func(): return building_model(sp, ff)})
		"new":
			for e in [["rocketeer", "coalition", "Rocketeer", 0.6], ["commando", "coalition", "Commando", 0.6], ["demolition", "dominion", "Demolition Trooper", 0.6],
					["dog", "dominion", "Attack Dog", 0.6], ["minelayer", "dominion", "Minelayer", 1.0], ["transport", "coalition", "Paratrooper transport", 1.8], ["bomber", "dominion", "Bomber", 1.9]]:
				var sp: String = e[0]
				var ff: String = e[1]
				out.append({"label": e[2], "w": 1.0, "h": 0.8, "fit": true, "margin": 1.06, "team": BLUE if ff == "coalition" else RED,
					"build": func():
						if sp == "transport": return _veh(V.transport_plane(), -25.0)
						if sp == "bomber": return _veh(V.bomber_plane(), -25.0)
						return _rot(unit_model(sp, ff), -60.0 if sp != "minelayer" else -25.0)})
		"style":
			for e in [["infantry", "coalition", "Rifleman", 0], ["infantry", "dominion", "Conscript", 0], ["commando", "coalition", "Commando", 0], ["demolition", "dominion", "Demolition Trooper", 0],
					["tank_medium", "coalition", "Warden Battle Tank", 1], ["tank_heavy", "dominion", "Mammoth Tank", 1], ["heli", "coalition", "Hornet Gunship", 1], ["dog", "dominion", "Attack Dog", 0]]:
				var sp: String = e[0]
				var ff: String = e[1]
				var veh: bool = e[3] == 1
				out.append({"label": e[2], "w": 1.0, "h": 1.0, "fit": true, "margin": 1.05, "team": BLUE if ff == "coalition" else RED,
					"build": func(): return _rot(unit_model(sp, ff), -25.0 if veh else -60.0)})
		"countries":
			for c in ["usa", "uk", "germany", "france", "thailand", "korea", "japan", "russia", "china", "cuba"]:
				var cc: String = c
				var side: String = H.side_of(c)
				out.append({"label": c, "w": 0.5, "h": 0.6, "focus": Vector3(0, 0.2, 0), "team": BLUE if side == "coalition" else RED,
					"build": func(): return _rot(H.soldier("infantry", "coalition" if cc == "usa" else ("dominion" if cc == "russia" else cc), {}), -60.0)})
		"country_units":
			for e in [["sniper", "coalition", 0], ["ranger", "coalition", 0], ["guerrilla", "dominion", 0], ["tank_destroyer", "coalition", 1], ["mecha", "coalition", 1],
					["jet_eagle", "coalition", 1], ["tank_tsar", "dominion", 1], ["tank_gatling", "dominion", 1], ["grand_cannon", "coalition", 2]]:
				var sp: String = e[0]
				var ff: String = e[1]
				var kind: int = e[2]
				out.append({"label": sp, "w": 1.0, "h": 0.8, "fit": true, "margin": 1.06, "team": BLUE if ff == "coalition" else RED,
					"build": func():
						if kind == 2: return building_model(sp, ff)
						return _rot(unit_model(sp, ff), -60.0 if kind == 0 else -25.0)})
		"mock_cameos":
			# Sidebar mock-up: Thai infantry and naval icons.
			for e in [["e1", "infantry", 0], ["e3", "rocket_inf", 0], ["eng", "engineer", 0], ["cmdo", "commando", 0], ["rngr", "ranger", 0],
					["boat_c", "gunboat", 1], ["dest_c", "destroyer", 1]]:
				var kind: String = e[1]
				var veh: bool = e[2] == 1
				out.append({"label": e[0], "w": 0.96, "h": 0.76, "fit": true, "margin": 1.0 if not veh else 1.06, "team": BLUE,
					"build": func():
						if veh: return _veh(V.boat_coalition() if kind == "gunboat" else V.destroyer_coalition(), -25.0)
						var c := "coalition" if kind == "engineer" or kind == "commando" else "thailand"
						return _rot(H.soldier(kind, c, {"fire": 1} if kind != "engineer" else {}), -60.0)})
		"defenses":
			for e in [["guard_tower", "coalition"], ["mortar_pit", "coalition"], ["missile_bunker", "coalition"], ["pillbox", "coalition"],
					["bunker", "dominion"], ["twin_cannon", "dominion"], ["rocket_battery", "dominion"], ["flame_tower", "dominion"]]:
				var sp: String = e[0]
				var ff: String = e[1]
				out.append({"label": sp, "w": 1.0, "h": 1.0, "fit": true, "margin": 1.08, "team": BLUE if ff == "coalition" else RED,
					"build": func(): return building_model(sp, ff)})
			for ff in ["coalition", "dominion"]:
				var f2: String = ff
				out.append({"label": "wall_" + ff, "w": 1.0, "h": 1.0, "fit": true, "margin": 1.05, "team": BLUE if ff == "coalition" else RED,
					"build": func():
						var r := Node3D.new()
						# An L-shaped run with a T junction: shows how sections join.
						var cells := [[0, 0, 2 | 4], [1, 0, 8 | 2], [2, 0, 8 | 4], [0, 1, 1 | 4 | 2], [1, 1, 8], [0, 2, 1 | 2], [1, 2, 8], [2, 1, 1]]
						for c in cells:
							var w: Node3D = DF.concrete_wall(c[2], false) if f2 == "coalition" else DF.iron_wall(c[2], false)
							w.position = Vector3(c[0], 0, c[1])
							r.add_child(w)
						return r})
		"wave2":
			for e in [["strat_bomber", "coalition", 0], ["airship", "dominion", 0], ["dolphin", "coalition", 0], ["aegis", "coalition", 0],
					["squid", "dominion", 0], ["sea_scorpion", "dominion", 0], ["weather_control", "coalition", 1], ["missile_silo", "dominion", 1]]:
				var sp: String = e[0]
				var ff: String = e[1]
				var bld: bool = e[2] == 1
				out.append({"label": sp, "w": 1.0, "h": 0.8, "fit": true, "margin": 1.06, "team": BLUE if ff == "coalition" else RED,
					"build": func(): return building_model(sp, ff) if bld else _rot(unit_model(sp, ff), -25.0)})
		"mock_scene_infantry":
			out.append({"label": "infantry", "w": 3.4, "h": 4.0, "focus": Vector3(1.7, 0.0, 1.5), "team": BLUE, "build": func(): return _scene_infantry()})
		"mock_scene_naval":
			out.append({"label": "naval", "w": 3.4, "h": 4.0, "focus": Vector3(1.8, 0.0, 1.6), "team": BLUE, "build": func(): return _scene_naval()})
		"dug":
			for d in [0.0, -45.0, -90.0, -135.0]:
				var dd: float = d
				out.append({"label": "", "w": 0.8, "h": 0.8, "fit": true, "margin": 1.1, "team": BLUE,
					"build": func(): return _rot(H.soldier("infantry", "coalition", {"kneel": true, "sandbags": true}), dd)})
			out.append({"label": "", "w": 0.8, "h": 0.8, "fit": true, "margin": 1.1, "team": BLUE,
				"build": func(): return _rot(H.soldier("infantry", "coalition", {"kneel": true, "sandbags": true, "fire": 2}), -60.0)})
		"closeup":
			for f in ["coalition", "dominion"]:
				for ang in [0.0, -45.0, -90.0, -135.0, 180.0]:
					var ff: String = f
					var a: float = ang
					out.append({"label": "", "w": 0.32, "h": 0.5, "focus": Vector3(0, 0.2, 0), "team": BLUE if f == "coalition" else RED,
						"build": func(): return _rot(H.soldier("infantry", ff, {}), a)})
		"poses":
			for f in ["coalition", "dominion"]:
				for p in [{}, {"walk": 0.0}, {"walk": 0.17}, {"walk": 0.5}, {"fire": 1}, {"fire": 2}, {"dead": 1.0}]:
					var pp: Dictionary = p
					var ff: String = f
					out.append({"label": str(p), "w": 0.5, "h": 0.6, "focus": Vector3(0, 0.2, 0), "team": BLUE if f == "coalition" else RED,
						"build": func(): return _rot(H.soldier("infantry", ff, pp), -90.0)})
	return out

# ---------------------------------------------------------------- sidebar backdrop scenes

static func _thai_flag(r: Node3D, at: Vector3) -> void:
	K.add(r, K.cylinder(0.012, 1.0, 8), HM.steel(), at + Vector3(0, 0.5, 0))
	var cols := [Color(0.65, 0.1, 0.19), Color(0.95, 0.95, 0.95), Color(0.18, 0.16, 0.3), Color(0.18, 0.16, 0.3), Color(0.95, 0.95, 0.95), Color(0.65, 0.1, 0.19)]
	for i in 6:
		K.add(r, K.bevel_box(Vector3(0.36, 0.04, 0.008), 0.002), K.paint(cols[i], 0.0, 0.8), at + Vector3(0.19, 0.97 - i * 0.04, 0))

static func _scene_infantry() -> Node3D:
	var r := Node3D.new()
	K.add(r, K.bevel_box(Vector3(16.0, 0.05, 16.0), 0.01), K.paint(Color(0.52, 0.5, 0.42), 0.0, 0.95, {"noise_amt": 0.35, "panel": 1.0, "panel_dark": 0.15}), Vector3(1.6, -0.025, 1.6))
	var bk: Dictionary = HB.build("barracks", "coalition")
	bk.root.position = Vector3(0.0, 0.0, -0.4)
	r.add_child(bk.root)
	for i in 8:
		var sold := H.soldier("infantry" if i % 3 else "rocket_inf", "thailand", {})
		sold.position = Vector3(1.0 + (i % 4) * 0.28, 0.0, 1.9 + (i / 4) * 0.3)
		sold.rotation_degrees.y = -45.0
		r.add_child(sold)
	for i in 2:
		var rg := H.soldier("ranger", "thailand", {"fire": 1})
		rg.position = Vector3(2.3 + i * 0.3, 0.0, 1.2 + i * 0.2)
		rg.rotation_degrees.y = -20.0
		r.add_child(rg)
	var jeep := _veh(V.jeep(), 30.0)
	jeep.position = Vector3(2.9, 0.0, 2.5)
	r.add_child(jeep)
	for k in ["crates", "barrels", "sandbags"]:
		var pr := HB.prop(k, 1)
		pr.position = Vector3(2.6 if k != "sandbags" else 0.6, 0.0, 0.5 + ["crates", "barrels", "sandbags"].find(k) * 0.5)
		r.add_child(pr)
	_thai_flag(r, Vector3(2.3, 0.0, 0.2))
	for i in 3:
		var t := HB.tree(i % 2, 5 + i)
		t.position = Vector3(3.6 + i * 0.4, 0.0, -0.4 + i * 0.7)
		r.add_child(t)
	return r

static func _scene_naval() -> Node3D:
	var r := Node3D.new()
	K.add(r, K.bevel_box(Vector3(16.0, 0.04, 16.0), 0.01), K.paint(Color(0.14, 0.36, 0.5), 0.0, 0.95, {"noise_amt": 0.4}), Vector3(1.8, -0.06, 1.8))
	K.add(r, K.bevel_box(Vector3(16.0, 0.08, 1.4), 0.02), K.paint(Color(0.5, 0.5, 0.46), 0.0, 0.9, {"panel": 2.0}), Vector3(1.8, 0.0, -0.6))
	var yd: Dictionary = HB.build("naval_yard", "coalition")
	yd.root.position = Vector3(-0.6, 0.0, 0.1)
	r.add_child(yd.root)
	var d1 := _veh(V.destroyer_coalition(), -35.0)
	d1.position = Vector3(2.6, 0.0, 2.0)
	r.add_child(d1)
	var d2 := _veh(V.destroyer_coalition(), -35.0)
	d2.position = Vector3(3.8, 0.0, 0.7)
	r.add_child(d2)
	for i in 2:
		var b := _veh(V.boat_coalition(), -50.0)
		b.position = Vector3(1.2 + i * 0.7, 0.0, 3.0 + i * 0.3)
		r.add_child(b)
	_thai_flag(r, Vector3(3.0, 0.04, -0.6))
	return r
